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
	if not REGION_REGISTRY.has(region_id):
		push_error("Cannot initialize starting region: Unknown region_id '%s'" % region_id)
		return false
	
	var scene_path: String = REGION_REGISTRY[region_id]
	var packed: PackedScene = load(scene_path) as PackedScene
	if not packed:
		push_error("Failed to load starting region scene: %s" % scene_path)
		return false
	
	var region_instance: BaseRegion = packed.instantiate() as BaseRegion
	if not region_instance:
		push_error("Instantiated starting region is not a BaseRegion: %s" % scene_path)
		return false
	
	world_container.add_child(region_instance)
	active_region = region_instance
	active_region_id = region_id
	
	# Connect region portal triggers
	active_region.portal_triggered.connect(_on_region_portal_triggered)
	
	# Position player
	var spawn_pos: Vector2 = active_region.get_spawn_position(spawn_id)
	if player != null:
		player.global_position = spawn_pos
		player.velocity = Vector2.ZERO
	
	return true

func _on_region_portal_triggered(portal: RegionPortal, target_region_id: String, target_spawn_id: String) -> void:
	request_transition(portal, target_region_id, target_spawn_id)

func request_transition(portal_emitter: RegionPortal, target_region_id: String, target_spawn_id: String) -> void:
	# Guard: in-flight transition check
	if is_transition_in_flight:
		return
	
	# Guard: require emitter belongs to currently active region
	if active_region == null or not is_instance_valid(active_region):
		return
	
	if portal_emitter != null and not active_region.is_ancestor_of(portal_emitter):
		return
	
	# Deferred execution outside physics flush
	call_deferred("_execute_transition", target_region_id, target_spawn_id)

func _execute_transition(target_region_id: String, target_spawn_id: String) -> void:
	if is_transition_in_flight:
		return
	
	is_transition_in_flight = true
	var origin_region_id: String = active_region_id
	region_transition_started.emit(origin_region_id, target_region_id)
	
	if player != null:
		player.freeze_movement()
	
	# 1. Validate allowlisted destination identity
	if not REGION_REGISTRY.has(target_region_id):
		_handle_transition_abort("unknown_region", origin_region_id, target_region_id)
		return
	
	# 2. Validate availability policy (e.g. locked destination check)
	if not is_region_available(target_region_id):
		_handle_transition_abort("region_locked", origin_region_id, target_region_id)
		return
	
	# 3. Instantiate candidate stage (off-tree or staged)
	var scene_path: String = REGION_REGISTRY[target_region_id]
	var packed: PackedScene = load(scene_path) as PackedScene
	if not packed:
		_handle_transition_abort("scene_load_failed", origin_region_id, target_region_id)
		return
	
	var candidate_instance: BaseRegion = packed.instantiate() as BaseRegion
	if not candidate_instance:
		_handle_transition_abort("invalid_scene_type", origin_region_id, target_region_id)
		return
	
	# 4. Validate spawn existence on candidate
	if not candidate_instance.has_spawn(target_spawn_id):
		candidate_instance.queue_free()
		_handle_transition_abort("spawn_not_found", origin_region_id, target_region_id)
		return
	
	var candidate_spawn_pos: Vector2 = candidate_instance.get_spawn_position(target_spawn_id)
	
	# 5. Validate spawn position within candidate bounds
	if not candidate_instance.is_position_within_bounds(candidate_spawn_pos):
		candidate_instance.queue_free()
		_handle_transition_abort("spawn_out_of_bounds", origin_region_id, target_region_id)
		return
	
	# 6. Physical collision validation: stage candidate into tree to sync physics colliders
	# Disable old region colliders while staging so they do not collide with candidate test
	if active_region != null and is_instance_valid(active_region):
		active_region.set_all_collisions_disabled(true)
	
	# Add candidate to world container
	world_container.add_child(candidate_instance)
	
	# Force physics space synchronization for accurate shape query
	var space_rid: RID = candidate_instance.get_world_2d().space
	PhysicsServer2D.space_step(space_rid, 0.0)
	
	# Validate full player collision footprint at candidate_spawn_pos
	var footprint_clear: bool = _validate_player_footprint_clear(candidate_spawn_pos, space_rid)
	
	if not footprint_clear:
		# Rollback: remove candidate, re-enable active region collisions
		world_container.remove_child(candidate_instance)
		candidate_instance.queue_free()
		if active_region != null and is_instance_valid(active_region):
			active_region.set_all_collisions_disabled(false)
		_handle_transition_abort("spawn_obstructed", origin_region_id, target_region_id)
		return
	
	# Transition commit: candidate is valid!
	var old_region: BaseRegion = active_region
	if old_region != null and is_instance_valid(old_region):
		if old_region.portal_triggered.is_connected(_on_region_portal_triggered):
			old_region.portal_triggered.disconnect(_on_region_portal_triggered)
		world_container.remove_child(old_region)
		old_region.queue_free()
	
	active_region = candidate_instance
	active_region_id = target_region_id
	active_region.set_all_collisions_disabled(false)
	active_region.portal_triggered.connect(_on_region_portal_triggered)
	
	# Position player at committed spawn
	if player != null:
		player.global_position = candidate_spawn_pos
		player.velocity = Vector2.ZERO
		player.resume_movement()
	
	is_transition_in_flight = false
	region_transition_completed.emit(active_region_id, target_spawn_id)

func _validate_player_footprint_clear(spawn_pos: Vector2, space_rid: RID) -> bool:
	if player == null or player.collision_shape == null or player.collision_shape.shape == null:
		return true
	
	var shape: Shape2D = player.collision_shape.shape
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape_rid = shape.get_rid()
	query.transform = Transform2D(0.0, spawn_pos)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	
	var direct_state: PhysicsDirectSpaceState2D = PhysicsServer2D.space_get_direct_state(space_rid)
	if direct_state == null:
		return true
	
	var results: Array[Dictionary] = direct_state.intersect_shape(query, 1)
	return results.is_empty()

func _handle_transition_abort(reason: String, origin_id: String, target_id: String) -> void:
	if player != null:
		player.resume_movement()
	is_transition_in_flight = false
	region_transition_failed.emit(reason, origin_id, target_id)
