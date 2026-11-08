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

var current_dimension: Dimension = Dimension.PHYSICAL
var is_unlocked: bool = true

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
	dimension_changed.emit(current_dimension)
	return OK

func apply_dimension_to_region(region: Node2D) -> void:
	if region == null or not is_instance_valid(region):
		return

	# Background palette modulation
	var bg: ColorRect = region.get_node_or_null("Background") as ColorRect
	if bg != null:
		bg.color = COLOR_SPIRIT_BG if current_dimension == Dimension.SPIRIT else COLOR_PHYSICAL_BG

	# Physical-only nodes
	var physical_nodes: Array[Node] = region.get_tree().get_nodes_in_group("physical_only") if region.get_tree() != null else []
	for node: Node in physical_nodes:
		if node is CanvasItem:
			(node as CanvasItem).visible = (current_dimension == Dimension.PHYSICAL)
		if node is CollisionShape2D:
			(node as CollisionShape2D).disabled = (current_dimension != Dimension.PHYSICAL)

	# Spirit-only nodes
	var spirit_nodes: Array[Node] = region.get_tree().get_nodes_in_group("spirit_only") if region.get_tree() != null else []
	for node: Node in spirit_nodes:
		if node is CanvasItem:
			(node as CanvasItem).visible = (current_dimension == Dimension.SPIRIT)
		if node is CollisionShape2D:
			(node as CollisionShape2D).disabled = (current_dimension != Dimension.SPIRIT)
