class_name DimensionManager
extends RefCounted

## DimensionManager — SBL-W7-002 M3 spirit dimension shifting system.
## Requirements: GDD-042/043/076, FR-WLD-002, AGENTS.md Invariants.
##
## Core Invariants:
##   - Shift occurs only when unlocked and position-safe.
##   - Zero embed: Prohibits shifting if Ren's collision footprint collides with destination plane obstacles.
##   - Toggles visibility and collision layers of physical-only vs spirit-only world nodes.

signal dimension_changed(new_dim: Dimension)
signal dimension_shift_failed(reason: String)

enum Dimension {
	PHYSICAL,
	SPIRIT
}

const COLOR_PHYSICAL_BG: Color = Color(0.12, 0.16, 0.22, 1.0)
const COLOR_SPIRIT_BG: Color = Color(0.07, 0.10, 0.25, 1.0)

## Layer 1 = physical perimeter/obstacles, Layer 2 = spirit-only obstacles
const COLLISION_MASK_PHYSICAL: int = 1
const COLLISION_MASK_SPIRIT: int = 2

## Metadata key used to remember a shape owner's authored disabled state while hidden.
const DISABLED_META_PREFIX: String = "_dimension_disabled_owner_"

var current_dimension: Dimension = Dimension.PHYSICAL
var is_unlocked: bool = true

## Collision mask the player must use in the current dimension. Physical obstacles live on
## layer 1 and spirit obstacles on layer 2, so the player only collides with the active plane.
func player_collision_mask() -> int:
	return COLLISION_MASK_SPIRIT if current_dimension == Dimension.SPIRIT else COLLISION_MASK_PHYSICAL

## Applies the active plane's collision mask to the player. Safe to call on every travel/shift.
func apply_player_collision(player: PlayerCharacter) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.collision_mask = player_collision_mask()

func can_shift_to(
	target_dim: Dimension,
	player_pos: Vector2,
	footprint_shape: Shape2D,
	space_state: PhysicsDirectSpaceState2D
) -> bool:
	if not is_unlocked:
		return false
	if space_state == null or footprint_shape == null:
		return true

	# Test collision against target dimension's obstacle mask
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = footprint_shape
	query.transform = Transform2D(0.0, player_pos)
	query.collision_mask = COLLISION_MASK_SPIRIT if target_dim == Dimension.SPIRIT else COLLISION_MASK_PHYSICAL
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hits: Array[Dictionary] = space_state.intersect_shape(query, 1)
	return hits.is_empty()

func request_shift(
	player: PlayerCharacter,
	space_state: PhysicsDirectSpaceState2D
) -> Error:
	if not is_unlocked:
		dimension_shift_failed.emit("dimension_locked")
		return ERR_UNAVAILABLE

	var target_dim: Dimension = Dimension.SPIRIT if current_dimension == Dimension.PHYSICAL else Dimension.PHYSICAL

	if player != null and player.collision_shape != null and space_state != null:
		var safe: bool = can_shift_to(target_dim, player.global_position, player.collision_shape.shape, space_state)
		if not safe:
			dimension_shift_failed.emit("destination_obstructed")
			return ERR_ALREADY_EXISTS

	current_dimension = target_dim
	apply_player_collision(player)
	dimension_changed.emit(current_dimension)
	return OK

func apply_dimension_to_region(region: Node2D) -> void:
	if region == null or not is_instance_valid(region):
		return

	# Background palette modulation
	var bg: ColorRect = region.get_node_or_null("Background") as ColorRect
	if bg != null:
		bg.color = COLOR_SPIRIT_BG if current_dimension == Dimension.SPIRIT else COLOR_PHYSICAL_BG

	# Scope group lookups to this region so neighbouring/queued regions are never toggled.
	_apply_group_state(region, "physical_only", current_dimension == Dimension.PHYSICAL)
	_apply_group_state(region, "spirit_only", current_dimension == Dimension.SPIRIT)

## Toggles visibility and collision for every node in `group_name` beneath `region`.
func _apply_group_state(region: Node2D, group_name: StringName, active: bool) -> void:
	for node: Node in _nodes_in_group_under(region, group_name):
		if node is CanvasItem:
			(node as CanvasItem).visible = active
		_set_branch_collision_active(node, active)

## Recursively collects group members that are descendants of `root` (never siblings).
func _nodes_in_group_under(root: Node, group_name: StringName) -> Array[Node]:
	var found: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node != root and node.is_in_group(group_name):
			found.append(node)
		for child in node.get_children():
			stack.append(child)
	return found

## Disables (or restores) every collision shape owned by the node or its descendants.
## Group roots are often plain Node2D containers (e.g. a visual bridge), so the toggle
## must reach nested StaticBody2D/CollisionShape2D children as well as direct shapes.
func _set_branch_collision_active(root: Node, active: bool) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionObject2D:
			var body: CollisionObject2D = node as CollisionObject2D
			for owner_id in body.get_shape_owners():
				var meta_key: String = DISABLED_META_PREFIX + str(owner_id)
				if active:
					if body.has_meta(meta_key):
						body.shape_owner_set_disabled(owner_id, bool(body.get_meta(meta_key)))
						body.remove_meta(meta_key)
				else:
					body.set_meta(meta_key, body.is_shape_owner_disabled(owner_id))
					body.shape_owner_set_disabled(owner_id, true)
		for child in node.get_children():
			stack.append(child)
