extends SceneTree

# Scoped Logger for error capture
class TransitionTestLogger extends Logger:
	var _mutex: Mutex = Mutex.new()
	var error_count: int = 0
	var logged_errors: Array[String] = []

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			_mutex.lock()
			error_count += 1
			logged_errors.append("[%s:%d in %s] %s %s" % [file, line, function, code, rationale])
			_mutex.unlock()

	func get_error_count() -> int:
		_mutex.lock()
		var count: int = error_count
		_mutex.unlock()
		return count

var test_passed: bool = true
var current_step_name: String = ""

var game_root: Control = null
var world_router: WorldRouter = null
var player: PlayerCharacter = null

var logger: TransitionTestLogger = null

func _init() -> void:
	logger = TransitionTestLogger.new()
	OS.add_logger(logger)
	call_deferred("_start_suite")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		test_passed = false
		printerr("FAIL [%s]: %s" % [current_step_name, message])
	else:
		print("PASS [%s]: %s" % [current_step_name, message])

func _start_suite() -> void:
	print("=== Running SBL-W2-001 Overworld Transitions Test Suite ===")
	_step_setup()

func _step_setup() -> void:
	current_step_name = "Scene Setup & Normal Startup"
	var scene_path: String = "res://scenes/main/game_root.tscn"
	var packed: PackedScene = load(scene_path) as PackedScene
	_assert(packed != null, "PackedScene loaded from %s" % scene_path)
	
	game_root = packed.instantiate() as Control
	_assert(game_root != null, "Instantiated GameRoot")
	root.add_child(game_root)
	
	world_router = game_root.get_node_or_null("WorldRouter") as WorldRouter
	player = game_root.get_node_or_null("Player") as PlayerCharacter
	
	_assert(world_router != null, "WorldRouter exists")
	_assert(player != null, "PlayerCharacter exists")
	
	# Verify normal startup into test_region_alpha at default spawn
	_assert(world_router.active_region_id == "test_region_alpha", "Active region is test_region_alpha")
	_assert(world_router.active_region != null, "Active region instance is non-null")
	
	var default_marker_pos: Vector2 = world_router.active_region.get_spawn_position("default")
	_assert(player.global_position == default_marker_pos, "Player is at initial default marker position %s" % str(default_marker_pos))
	_assert(world_router.active_region.is_position_within_bounds(player.global_position), "Player is within bounds on startup")
	
	_run_physics_frames(2, _step_movement_and_speed)

func _step_movement_and_speed() -> void:
	current_step_name = "8-Direction Movement & Speed Invariant"
	var base_speed: float = player.fixture_move_speed
	_assert(base_speed > 0.0, "Player fixture move speed is tunable positive value (%f)" % base_speed)
	
	# Test cardinal movement
	Input.action_press("move_right")
	player._physics_process(1.0)
	var expected_cardinal: Vector2 = Vector2.RIGHT * base_speed
	_assert(player.velocity.is_equal_approx(expected_cardinal), "Cardinal velocity right equals fixture_move_speed: %s" % str(player.velocity))
	Input.action_release("move_right")
	
	# Test diagonal movement normalization
	Input.action_press("move_right")
	Input.action_press("move_down")
	player._physics_process(1.0)
	var diag_norm: Vector2 = Vector2(1, 1).normalized()
	var expected_diagonal: Vector2 = diag_norm * base_speed
	_assert(player.velocity.is_equal_approx(expected_diagonal), "Diagonal velocity normalized length equals fixture_move_speed: %s" % str(player.velocity.length()))
	_assert(is_equal_approx(player.velocity.length(), base_speed), "Diagonal speed strictly equals cardinal speed (no diagonal speed bug)")
	Input.action_release("move_right")
	Input.action_release("move_down")
	
	_run_physics_frames(2, _step_wall_collision)

func _step_wall_collision() -> void:
	current_step_name = "Wall & Obstacle Collision"
	# Position player near left perimeter wall (x = 16, normal = (1, 0))
	player.global_position = Vector2(30, 270)
	
	# Drive player left into wall
	for i in range(15):
		player.velocity = Vector2.LEFT * player.fixture_move_speed
		player.move_and_slide()
	
	# Player half-width is 12, wall is at 16, so player x cannot be <= 16
	_assert(player.global_position.x >= 28.0, "Player is stopped by perimeter collision wall at x >= 28, got %s" % str(player.global_position.x))
	
	_run_physics_frames(2, _step_transition_alpha_to_beta)

func _step_transition_alpha_to_beta() -> void:
	current_step_name = "Normal Transition Alpha -> Beta"
	var initial_player_instance: PlayerCharacter = player
	
	# Position player just outside PortalToBeta (portal is at (850, 270), player placed at (835, 270))
	player.global_position = Vector2(835, 270)
	
	var portal: RegionPortal = world_router.active_region.portals_container.get_node("PortalToBeta") as RegionPortal
	_assert(portal != null, "Found PortalToBeta in test_region_alpha")
	
	world_router.request_transition(portal, "test_region_beta", "from_alpha")
	
	_run_physics_frames(3, _verify_transition_alpha_to_beta.bind(initial_player_instance))

func _verify_transition_alpha_to_beta(initial_player: PlayerCharacter) -> void:
	_assert(player == initial_player, "Persistent player instance retained across transition")
	_assert(world_router.active_region_id == "test_region_beta", "Active region transitioned to test_region_beta")
	
	var expected_spawn_pos: Vector2 = world_router.active_region.get_spawn_position("from_alpha")
	_assert(player.global_position == expected_spawn_pos, "Player teleported to exact from_alpha spawn: %s" % str(player.global_position))
	_assert(world_router.active_region.is_position_within_bounds(player.global_position), "Inbound position is inside region bounds")
	_assert(not player.input_frozen, "Player input movement resumed after transition")
	
	_run_physics_frames(2, _step_duplicate_in_flight_guard)

func _step_duplicate_in_flight_guard() -> void:
	current_step_name = "Duplicate & In-Flight Request Guard"
	var portal: RegionPortal = world_router.active_region.portals_container.get_node("PortalToAlpha") as RegionPortal
	_assert(portal != null, "Found PortalToAlpha in test_region_beta")
	
	var signal_count: int = 0
	var on_started: Callable = func(_from: String, _to: String) -> void:
		signal_count += 1
	world_router.region_transition_started.connect(on_started)
	
	# Trigger multiple transitions simultaneously
	world_router.request_transition(portal, "test_region_alpha", "from_beta")
	world_router.request_transition(portal, "test_region_alpha", "from_beta")
	world_router.request_transition(portal, "test_region_alpha", "from_beta")
	
	_run_physics_frames(3, func() -> void:
		world_router.region_transition_started.disconnect(on_started)
		_assert(signal_count == 1, "Duplicate requests during transition were guarded; exactly 1 transition started, got %d" % signal_count)
		_assert(world_router.active_region_id == "test_region_alpha", "Transition back to Alpha completed")
		_run_physics_frames(2, _step_transition_beta_to_alpha_check)
	)

func _step_transition_beta_to_alpha_check() -> void:
	current_step_name = "Bidirectional Transition Verification"
	_assert(world_router.active_region_id == "test_region_alpha", "Region Alpha reached in reverse direction")
	var expected_pos: Vector2 = world_router.active_region.get_spawn_position("from_beta")
	_assert(player.global_position == expected_pos, "Player positioned at from_beta spawn: %s" % str(player.global_position))
	
	_run_physics_frames(2, _step_locked_region_guard)

func _step_locked_region_guard() -> void:
	current_step_name = "Locked & Unknown Region Guard"
	var portal: RegionPortal = world_router.active_region.portals_container.get_node("PortalToBeta") as RegionPortal
	var initial_pos: Vector2 = player.global_position
	var initial_region_id: String = world_router.active_region_id
	
	# 1. Test locked region
	world_router.set_region_available("test_region_beta", false)
	
	var failed_reason: String = ""
	var on_failed: Callable = func(reason: String, _from: String, _to: String) -> void:
		failed_reason = reason
	world_router.region_transition_failed.connect(on_failed)
	
	world_router.request_transition(portal, "test_region_beta", "from_alpha")
	
	_run_physics_frames(3, func() -> void:
		_assert(failed_reason == "region_locked", "Transition blocked with reason 'region_locked', got '%s'" % failed_reason)
		_assert(world_router.active_region_id == initial_region_id, "Region preserved on locked attempt: %s" % world_router.active_region_id)
		_assert(player.global_position == initial_pos, "Player position unchanged on locked attempt")
		_assert(not player.input_frozen, "Player movement resumed after failed transition")
		
		# 2. Test unknown region
		failed_reason = ""
		world_router.request_transition(portal, "nonexistent_secret_realm", "default")
		
		_run_physics_frames(3, func() -> void:
			world_router.region_transition_failed.disconnect(on_failed)
			_assert(failed_reason == "unknown_region", "Transition blocked with reason 'unknown_region', got '%s'" % failed_reason)
			_assert(world_router.active_region_id == initial_region_id, "Region preserved on unknown destination")
			world_router.set_region_available("test_region_beta", true)
			_run_physics_frames(2, _step_invalid_and_obstructed_spawn_rollback)
		)
	)

func _step_invalid_and_obstructed_spawn_rollback() -> void:
	current_step_name = "Invalid / Missing / Obstructed Spawn Rollback"
	var portal: RegionPortal = world_router.active_region.portals_container.get_node("PortalToBeta") as RegionPortal
	var initial_pos: Vector2 = player.global_position
	var initial_region: BaseRegion = world_router.active_region
	var initial_region_id: String = world_router.active_region_id
	
	var failed_reason: String = ""
	var on_failed: Callable = func(reason: String, _from: String, _to: String) -> void:
		failed_reason = reason
	world_router.region_transition_failed.connect(on_failed)
	
	# 1. Test missing spawn ID
	world_router.request_transition(portal, "test_region_beta", "nonexistent_spawn_node")
	
	_run_physics_frames(3, func() -> void:
		_assert(failed_reason == "spawn_not_found", "Transition rejected with 'spawn_not_found', got '%s'" % failed_reason)
		_assert(world_router.active_region == initial_region, "Active region instance preserved after rejected spawn")
		_assert(player.global_position == initial_pos, "Player position preserved after rejected spawn")
		
		# 2. Transition to Beta to test Alpha's out-of-bounds spawn and obstructed spawn
		world_router.region_transition_failed.disconnect(on_failed)
		world_router.request_transition(portal, "test_region_beta", "from_alpha")
		
		_run_physics_frames(3, func() -> void:
			_assert(world_router.active_region_id == "test_region_beta", "Arrived in Beta for candidate rollback tests")
			var beta_portal: RegionPortal = world_router.active_region.portals_container.get_node("PortalToAlpha") as RegionPortal
			var beta_pos: Vector2 = player.global_position
			var beta_region: BaseRegion = world_router.active_region
			
			world_router.region_transition_failed.connect(on_failed)
			
			# Test out of bounds spawn in Alpha
			failed_reason = ""
			world_router.request_transition(beta_portal, "test_region_alpha", "out_of_bounds_spawn")
			
			_run_physics_frames(3, func() -> void:
				_assert(failed_reason == "spawn_out_of_bounds", "Transition rejected with 'spawn_out_of_bounds', got '%s'" % failed_reason)
				_assert(world_router.active_region == beta_region, "Active region preserved on out-of-bounds spawn")
				_assert(player.global_position == beta_pos, "Player position preserved on out-of-bounds spawn")
				
				# Test obstructed spawn in Alpha (CentralPillar)
				failed_reason = ""
				world_router.request_transition(beta_portal, "test_region_alpha", "obstructed_spawn")
				
				_run_physics_frames(3, func() -> void:
					world_router.region_transition_failed.disconnect(on_failed)
					_assert(failed_reason == "spawn_obstructed", "Transition rejected with 'spawn_obstructed', got '%s'" % failed_reason)
					_assert(world_router.active_region == beta_region, "Active region preserved on obstructed spawn")
					_assert(player.global_position == beta_pos, "Player position preserved on obstructed spawn")
					_assert(not player.input_frozen, "Player input movement resumed after obstructed rollback")
					
					_finish_test_suite()
				)
			)
		)
	)

func _finish_test_suite() -> void:
	current_step_name = "Final Suite Completion"
	OS.remove_logger(logger)
	var captured_errors: int = logger.get_error_count()
	
	if captured_errors > 0:
		printerr("FAIL: Transition test captured %d error(s):" % captured_errors)
		for err_msg in logger.logged_errors:
			printerr("  - %s" % err_msg)
		test_passed = false
	else:
		print("PASS: 0 engine/script errors captured during transition suite")
	
	if test_passed:
		print("=== ALL SBL-W2-001 TRANSITION TESTS PASSED SUCCESSFULLY ===")
		quit(0)
	else:
		printerr("=== SBL-W2-001 TRANSITION TESTS FAILED ===")
		quit(1)

func _run_physics_frames(frames: int, callback: Callable) -> void:
	var counter: Dictionary = {"remaining": frames}
	var process_callable: Callable
	process_callable = func() -> void:
		counter["remaining"] -= 1
		if counter["remaining"] <= 0:
			root.disconnect("process_frame", process_callable)
			callback.call()
	root.connect("process_frame", process_callable)
