class_name WorldRouter
extends Node

signal region_transition_started(from_region_id: String, to_region_id: String)
signal region_transition_completed(region_id: String, spawn_id: String)
signal region_transition_failed(reason: String, from_region_id: String, attempted_region_id: String)

const REGION_REGISTRY: Dictionary = {
	"test_region_alpha": "res://scenes/world/test_region_alpha.tscn",
	"test_region_beta": "res://scenes/world/test_region_beta.tscn"
}

## Region availability table (simple policy usable by tests and future story hooks)
var available_regions: Dictionary = {
	"test_region_alpha": true,
	"test_region_beta": true
}

var active_region_id: String = ""
var active_region: BaseRegion = null
var is_transition_in_flight: bool = false

var world_container: Node2D = null
var player: PlayerCharacter = null

func setup(container: Node2D, player_node: PlayerCharacter) -> void:
	world_container = container
	player = player_node

func set_region_available(region_id: String, available: bool) -> void:
	available_regions[region_id] = available

func is_region_available(region_id: String) -> bool:
	return bool(available_regions.get(region_id, false))

func initialize_starting_region(region_id: String, spawn_id: String = "default") -> bool:
	if world_container == null or player == null:
		return false

	if active_region != null:
		return false

	if not REGION_REGISTRY.has(region_id):
		return false

	if not is_region_available(region_id):
		return false

	var scene_path: String = REGION_REGISTRY[region_id]
	var packed: PackedScene = load(scene_path) as PackedScene
	if not packed:
		return false

	var candidate: Node = packed.instantiate()
	if not (candidate is BaseRegion):
		if candidate != null:
			candidate.queue_free()
		return false

	var region_instance: BaseRegion = candidate as BaseRegion

	# Validate candidate spawn and clear footprint using shared validator
	var validation_error: String = _validate_candidate_spawn(region_instance, region_id, spawn_id)
	if validation_error != "":
		region_instance.queue_free()
		return false

	var spawn_world_pos: Vector2 = _get_spawn_world_pos(region_instance, spawn_id)

	world_container.add_child(region_instance)
	active_region = region_instance
	active_region_id = region_id

	# Connect region portal triggers
	active_region.portal_triggered.connect(_on_region_portal_triggered)

	# Position player
	if player != null:
		player.global_position = spawn_world_pos
		player.velocity = Vector2.ZERO

	return true

func _on_region_portal_triggered(portal: RegionPortal, target_region_id: String, target_spawn_id: String, body: PlayerCharacter) -> void:
	if body != player:
		return
	request_transition(portal, target_region_id, target_spawn_id)

func request_transition(portal_emitter: RegionPortal, target_region_id: String, target_spawn_id: String) -> void:
	# Guard: require valid setup
	if world_container == null or player == null:
		return

	if player.input_frozen:
		return

	# Guard: in-flight transition check immediately before deferring
	if is_transition_in_flight:
		return

	# Guard: require active region exists and is valid
	if active_region == null or not is_instance_valid(active_region):
		return

	# Guard: coalesce self-transition request (destination equals active region)
	if target_region_id == active_region_id:
		return

	# Guard: require emitter belongs directly or indirectly to currently active region
	if portal_emitter == null or not is_instance_valid(portal_emitter) or not active_region.is_ancestor_of(portal_emitter):
		return

	# Lock transition state BEFORE deferring so subsequent requests in same frame/flush are coalesced/blocked
	is_transition_in_flight = true

	# Deferred execution outside physics flush, binding emitter and active_region instance IDs to verify on dispatch
	call_deferred("_execute_transition", portal_emitter.get_instance_id(), active_region.get_instance_id(), target_region_id, target_spawn_id)

func _execute_transition(emitter_id: int, original_active_region_id: int, target_region_id: String, target_spawn_id: String) -> void:
	if player == null or not is_instance_valid(player) or player.input_frozen:
		is_transition_in_flight = false
		return

	# Recheck original active region validity upon dispatch
	if active_region == null or not is_instance_valid(active_region) or active_region.is_queued_for_deletion():
		is_transition_in_flight = false
		return

	if active_region.get_instance_id() != original_active_region_id:
		is_transition_in_flight = false
		return

	# Resolve and recheck original emitter validity upon dispatch
	var original_emitter: RegionPortal = instance_from_id(emitter_id) as RegionPortal
	if original_emitter == null or not is_instance_valid(original_emitter) or original_emitter.is_queued_for_deletion():
		is_transition_in_flight = false
		return

	if not active_region.is_ancestor_of(original_emitter):
		is_transition_in_flight = false
		return

	if target_region_id == active_region_id:
		is_transition_in_flight = false
		return

	var origin_region_id: String = active_region_id
	region_transition_started.emit(origin_region_id, target_region_id)

	# 1. Validate allowlisted destination identity
	if not REGION_REGISTRY.has(target_region_id):
		_handle_transition_abort("unknown_region", origin_region_id, target_region_id)
		return

	# 2. Validate availability policy (e.g. locked destination check)
	if not is_region_available(target_region_id):
		_handle_transition_abort("region_locked", origin_region_id, target_region_id)
		return

	# 3. Instantiate candidate stage
	var scene_path: String = REGION_REGISTRY[target_region_id]
	var packed: PackedScene = load(scene_path) as PackedScene
	if not packed:
		_handle_transition_abort("scene_load_failed", origin_region_id, target_region_id)
		return

	var raw_candidate: Node = packed.instantiate()
	if not (raw_candidate is BaseRegion):
		if raw_candidate != null:
			raw_candidate.queue_free()
		_handle_transition_abort("invalid_scene_type", origin_region_id, target_region_id)
		return

	var candidate_instance: BaseRegion = raw_candidate as BaseRegion

	# 4, 5, 6. Run shared candidate spawn validation (bounds, static collision clearance, portal clearance)
	var validation_error: String = _validate_candidate_spawn(candidate_instance, target_region_id, target_spawn_id)
	if validation_error != "":
		candidate_instance.queue_free()
		_handle_transition_abort(validation_error, origin_region_id, target_region_id)
		return

	var candidate_spawn_world_pos: Vector2 = _get_spawn_world_pos(candidate_instance, target_spawn_id)

	# Transition commit: candidate is valid!
	var old_region: BaseRegion = active_region
	if old_region != null and is_instance_valid(old_region):
		if old_region.portal_triggered.is_connected(_on_region_portal_triggered):
			old_region.portal_triggered.disconnect(_on_region_portal_triggered)
		world_container.remove_child(old_region)
		old_region.queue_free()

	active_region = candidate_instance
	active_region_id = target_region_id
	world_container.add_child(active_region)
	active_region.portal_triggered.connect(_on_region_portal_triggered)

	# Position player at committed spawn
	if player != null:
		player.global_position = candidate_spawn_world_pos
		player.velocity = Vector2.ZERO

	is_transition_in_flight = false
	region_transition_completed.emit(active_region_id, target_spawn_id)

func _get_spawn_world_pos(candidate: BaseRegion, spawn_id: String) -> Vector2:
	var marker: Marker2D = candidate.get_spawn_point(spawn_id)
	if marker == null:
		return Vector2.ZERO
	if world_container != null:
		return world_container.global_transform * marker.global_position
	return marker.global_position

func _validate_candidate_spawn(candidate: BaseRegion, expected_region_id: String, spawn_id: String) -> String:
	# Ensure candidate.region_id matches requested
	if candidate.region_id != expected_region_id:
		return "region_mismatch"

	# 1. Direct named Marker2D check
	var marker: Marker2D = candidate.get_spawn_point(spawn_id)
	if marker == null:
		return "spawn_not_found"

	# Fail closed if player shape missing/disabled
	if player == null or player.collision_shape == null or player.collision_shape.shape == null or player.collision_shape.disabled:
		return "player_collision_shape_invalid"

	var spawn_world_point: Vector2 = _get_spawn_world_pos(candidate, spawn_id)

	# Build destination_transform = player.global_transform then assign origin to spawn world point,
	# multiply by player.collision_shape.transform, convert into future WorldContainer space using world_container.global_transform.affine_inverse()
	var dest_transform: Transform2D = player.global_transform
	dest_transform.origin = spawn_world_point
	var shape_world_transform: Transform2D = dest_transform * player.collision_shape.transform

	var container_trans_inv: Transform2D = world_container.global_transform.affine_inverse() if world_container != null else Transform2D.IDENTITY
	var shape_transform_container: Transform2D = container_trans_inv * shape_world_transform

	# Test full shape bounds with candidate.global_transform.affine_inverse() * shape_transform then transformed player_shape.get_rect(), using candidate.bounds_rect.encloses(rect)
	var shape_local_to_candidate: Transform2D = candidate.global_transform.affine_inverse() * shape_transform_container
	var player_shape: Shape2D = player.collision_shape.shape
	var transformed_rect: Rect2 = _get_transformed_shape_rect(player_shape, shape_local_to_candidate)

	if not candidate.bounds_rect.encloses(transformed_rect):
		return "spawn_out_of_bounds"

	# Resolve collision shapes from Godot CollisionObject2D and check static obstacles
	if not _is_shape_clear_of_candidate_obstacles(candidate, player_shape, shape_transform_container, player.collision_mask):
		return "spawn_obstructed"

	# Check enabled monitoring RegionPortal overlap matching portal.collision_mask & player.collision_layer
	if _does_shape_overlap_candidate_portals(candidate, player_shape, shape_transform_container, player.collision_layer):
		return "spawn_overlaps_portal"

	return ""

func _get_transformed_shape_rect(shape: Shape2D, xform: Transform2D) -> Rect2:
	var local_rect: Rect2 = shape.get_rect()
	var p1: Vector2 = xform * local_rect.position
	var p2: Vector2 = xform * Vector2(local_rect.end.x, local_rect.position.y)
	var p3: Vector2 = xform * local_rect.end
	var p4: Vector2 = xform * Vector2(local_rect.position.x, local_rect.end.y)

	var min_pt: Vector2 = Vector2(minf(p1.x, minf(p2.x, minf(p3.x, p4.x))), minf(p1.y, minf(p2.y, minf(p3.y, p4.y))))
	var max_pt: Vector2 = Vector2(maxf(p1.x, maxf(p2.x, maxf(p3.x, p4.x))), maxf(p1.y, maxf(p2.y, maxf(p3.y, p4.y))))
	return Rect2(min_pt, max_pt - min_pt)

func _scan_candidate_colliders(candidate: Node, shape: Shape2D, shape_transform: Transform2D, check_obstacles: bool, check_portals: bool, layer_or_mask: int) -> bool:
	var stack: Array[Node] = [candidate]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if check_obstacles and (node is StaticBody2D):
			var body: StaticBody2D = node as StaticBody2D
			if (body.collision_layer & layer_or_mask) != 0:
				if _check_collision_object_overlap(body, shape, shape_transform):
					return true
		elif check_portals and (node is RegionPortal):
			var portal: RegionPortal = node as RegionPortal
			if portal.monitoring and ((portal.collision_mask & layer_or_mask) != 0):
				if _check_collision_object_overlap(portal, shape, shape_transform):
					return true
		for child in node.get_children():
			stack.append(child)
	return false

func _check_collision_object_overlap(col_obj: CollisionObject2D, shape: Shape2D, shape_transform: Transform2D) -> bool:
	var obj_owners: Array = col_obj.get_shape_owners()
	for owner_id in obj_owners:
		if col_obj.is_shape_owner_disabled(owner_id):
			continue
		var owner_xform: Transform2D = col_obj.shape_owner_get_transform(owner_id)
		var obstacle_transform: Transform2D = col_obj.global_transform * owner_xform
		var shape_count: int = col_obj.shape_owner_get_shape_count(owner_id)
		for s_idx in range(shape_count):
			var target_shape: Shape2D = col_obj.shape_owner_get_shape(owner_id, s_idx)
			if target_shape != null:
				if shape.collide(shape_transform, target_shape, obstacle_transform):
					return true
	return false

func _is_shape_clear_of_candidate_obstacles(candidate: Node, shape: Shape2D, shape_transform: Transform2D, player_mask: int) -> bool:
	return not _scan_candidate_colliders(candidate, shape, shape_transform, true, false, player_mask)

func _does_shape_overlap_candidate_portals(candidate: Node, shape: Shape2D, shape_transform: Transform2D, player_layer: int) -> bool:
	return _scan_candidate_colliders(candidate, shape, shape_transform, false, true, player_layer)

func _handle_transition_abort(reason: String, origin_id: String, target_id: String) -> void:
	is_transition_in_flight = false
	region_transition_failed.emit(reason, origin_id, target_id)
