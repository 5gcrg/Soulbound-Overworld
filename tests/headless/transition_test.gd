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
var suite_completed: bool = false
var current_step_name: String = ""

var game_root: Control = null
var world_router: WorldRouter = null
var player: PlayerCharacter = null

var logger: TransitionTestLogger = null
var watchdog_timer: SceneTreeTimer = null

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

func _fail_immediate(message: String) -> void:
	test_passed = false
	printerr("FATAL [%s]: %s" % [current_step_name, message])
	_finish_test_suite()

func _start_suite() -> void:
	print("=== Running SBL-W2-001 Overworld Transitions Test Suite ===")
	_arm_watchdog()
	_step_setup()

func _arm_watchdog() -> void:
	watchdog_timer = create_timer(4.0, true, false, false)
	watchdog_timer.timeout.connect(_on_watchdog_timeout)

func _on_watchdog_timeout() -> void:
	if suite_completed:
		return
	printerr("WATCHDOG TIMEOUT: Test suite exceeded 4.0s execution limit without completing")
	_fail_immediate("Watchdog timer expired before suite completion")

func _step_setup() -> void:
	current_step_name = "Scene Setup & Normal Startup"
	var scene_path: String = "res://scenes/main/game_root.tscn"
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		_fail_immediate("PackedScene failed to load from %s" % scene_path)
		return

	game_root = packed.instantiate() as Control
	if game_root == null:
		_fail_immediate("Failed to instantiate GameRoot from %s" % scene_path)
		return
	root.add_child(game_root)

	world_router = game_root.get_node_or_null("WorldRouter") as WorldRouter
	player = game_root.get_node_or_null("Player") as PlayerCharacter

	if world_router == null:
		_fail_immediate("WorldRouter node missing or invalid under GameRoot")
		return
	if player == null:
		_fail_immediate("PlayerCharacter node missing or invalid under GameRoot")
		return

	# Verify normal startup into test_region_alpha at default spawn
	_assert(world_router.active_region_id == "test_region_alpha", "Active region is test_region_alpha")
	_assert(world_router.active_region != null, "Active region instance is non-null")

	if world_router.active_region == null:
		_fail_immediate("Cannot continue without active starting region")
		return

	var default_marker_pos: Vector2 = world_router.active_region.get_spawn_position("default")
	_assert(player.global_position == default_marker_pos, "Player is at initial default marker position %s" % str(default_marker_pos))
	_assert(world_router.active_region.is_position_within_bounds(player.global_position), "Player is within bounds on startup")

	var status_node: Label = game_root.get_node_or_null("UIOverlay/VBoxContainer/StatusLabel") as Label
	_assert(status_node != null and status_node.text == "Overworld Active", "Status label set to Overworld Active after startup")

	_run_physics_frames(2, _step_movement_and_speed)

func _step_movement_and_speed() -> void:
	current_step_name = "8-Direction Movement & Speed Invariant"
	var base_speed: float = player.fixture_move_speed
	_assert(base_speed > 0.0, "Player fixture move speed is tunable positive value (%f)" % base_speed)

	# Ensure player starts at clear Alpha spawn area (default marker position)
	var spawn_pos: Vector2 = world_router.active_region.get_spawn_position("default")
	player.global_position = spawn_pos
	player.velocity = Vector2.ZERO

	var initial_pos: Vector2 = player.global_position
	var ticks: int = 5

	# 1. Test cardinal movement across real physics ticks via actual input action presses
	Input.action_press("move_right")
	_run_physics_frames(ticks, func() -> void:
		var cardinal_disp: Vector2 = player.global_position - initial_pos
		var expected_cardinal_vel: Vector2 = Vector2.RIGHT * base_speed
		_assert(player.velocity.is_equal_approx(expected_cardinal_vel), "Cardinal velocity right equals fixture_move_speed: %s" % str(player.velocity))
		_assert(cardinal_disp.x > 0.0, "Cardinal movement produced actual positive x displacement: %f" % cardinal_disp.x)
		_assert(is_zero_approx(cardinal_disp.y), "Cardinal horizontal movement left y unchanged: dy=%f" % cardinal_disp.y)
		Input.action_release("move_right")

		# Reset position in clear Alpha spawn area before diagonal test
		player.global_position = spawn_pos
		player.velocity = Vector2.ZERO

		_run_physics_frames(1, func() -> void:
			var diag_start_pos: Vector2 = player.global_position
			var diag_norm: Vector2 = Vector2(1, 1).normalized()
			var expected_diag_vel: Vector2 = diag_norm * base_speed

			# 2. Test diagonal movement normalization across same number of physics ticks
			Input.action_press("move_right")
			Input.action_press("move_down")

			_run_physics_frames(ticks, func() -> void:
				var diag_disp: Vector2 = player.global_position - diag_start_pos
				_assert(player.velocity.is_equal_approx(expected_diag_vel), "Diagonal velocity matches normalized fixture speed: %s" % str(player.velocity))
				_assert(is_equal_approx(player.velocity.length(), base_speed), "Diagonal speed strictly equals cardinal speed (no diagonal speed bug)")
				_assert(diag_disp.x > 0.0, "Diagonal movement produced positive x displacement: %f" % diag_disp.x)
				_assert(diag_disp.y > 0.0, "Diagonal movement produced positive y displacement: %f" % diag_disp.y)

				# Verify normalized length vs cardinal displacement with tolerance
				_assert(absf(diag_disp.length() - cardinal_disp.length()) < 0.5, "Diagonal displacement magnitude (%f) matches cardinal displacement magnitude (%f)" % [diag_disp.length(), cardinal_disp.length()])

				# Release input keys before advancing to wall collision
				Input.action_release("move_right")
				Input.action_release("move_down")
				player.velocity = Vector2.ZERO

				_run_physics_frames(2, _step_wall_collision)
			)
		)
	)

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

	var portal: RegionPortal = world_router.active_region.portals_container.get_node_or_null("PortalToBeta") as RegionPortal
	if portal == null:
		_fail_immediate("Missing PortalToBeta in test_region_alpha")
		return

	# Drive real body_entered by placing player at portal.global_position after normal physics
	player.global_position = portal.global_position

	_run_physics_frames(5, _verify_transition_alpha_to_beta.bind(initial_player_instance))

func _verify_transition_alpha_to_beta(initial_player: PlayerCharacter) -> void:
	_assert(player == initial_player, "Persistent player instance retained across transition")
	_assert(world_router.active_region_id == "test_region_beta", "Active region transitioned to test_region_beta")

	var expected_spawn_pos: Vector2 = world_router.active_region.get_spawn_position("from_alpha")
	_assert(player.global_position == expected_spawn_pos, "Player teleported to exact from_alpha spawn: %s" % str(player.global_position))
	_assert(world_router.active_region.is_position_within_bounds(player.global_position), "Inbound position is inside region bounds")
	_assert(not player.input_frozen, "Player input movement resumed after transition")

	_run_physics_frames(2, _step_transition_beta_to_alpha)

func _step_transition_beta_to_alpha() -> void:
	current_step_name = "Normal Transition Beta -> Alpha"
	var initial_player_instance: PlayerCharacter = player

	var portal: RegionPortal = world_router.active_region.portals_container.get_node_or_null("PortalToAlpha") as RegionPortal
	if portal == null:
		_fail_immediate("Missing PortalToAlpha in test_region_beta")
		return

	# Drive real body_entered in reverse direction by placing player at portal.global_position after normal physics
	player.global_position = portal.global_position

	_run_physics_frames(5, _verify_transition_beta_to_alpha.bind(initial_player_instance))

func _verify_transition_beta_to_alpha(initial_player: PlayerCharacter) -> void:
	_assert(player == initial_player, "Persistent player instance retained across reverse transition")
	_assert(world_router.active_region_id == "test_region_alpha", "Region Alpha reached in reverse direction via portal body_entered")

	var expected_pos: Vector2 = world_router.active_region.get_spawn_position("from_beta")
	_assert(player.global_position == expected_pos, "Player positioned at exact from_beta spawn: %s" % str(player.global_position))
	_assert(world_router.active_region.is_position_within_bounds(player.global_position), "Inbound position is inside region bounds")
	_assert(not player.input_frozen, "Player input movement resumed after reverse transition")

	# Traverse one more time to Beta so duplicate guard can test direct calls on Beta's portal
	var portal_to_beta: RegionPortal = world_router.active_region.portals_container.get_node_or_null("PortalToBeta") as RegionPortal
	if portal_to_beta == null:
		_fail_immediate("Missing PortalToBeta in test_region_alpha for setup to duplicate guard")
		return

	player.global_position = portal_to_beta.global_position
	_run_physics_frames(5, _step_duplicate_in_flight_guard)

func _step_duplicate_in_flight_guard() -> void:
	current_step_name = "Duplicate & In-Flight Request Guard"
	_assert(world_router.active_region_id == "test_region_beta", "Arrived in Beta before duplicate direct call test")
	var initial_player_instance: PlayerCharacter = player

	var portal: RegionPortal = world_router.active_region.portals_container.get_node_or_null("PortalToAlpha") as RegionPortal
	if portal == null:
		_fail_immediate("Missing PortalToAlpha in test_region_beta")
		return

	var state: Dictionary = {"signal_count": 0}
	var on_started: Callable = func(_from: String, _to: String) -> void:
		state["signal_count"] = int(state["signal_count"]) + 1
	world_router.region_transition_started.connect(on_started)

	# Optional/simple non-player instance exercise on portal trigger to ensure foreign bodies are ignored
	var foreign_packed: PackedScene = load("res://scenes/player/player.tscn") as PackedScene
	if foreign_packed != null:
		var foreign_player: PlayerCharacter = foreign_packed.instantiate() as PlayerCharacter
		world_router.active_region.add_child(foreign_player)
		foreign_player.global_position = portal.global_position
		# Also explicitly test portal signal with foreign player instance
		world_router._on_region_portal_triggered(portal, "test_region_alpha", "from_beta", foreign_player)
		foreign_player.queue_free()

	# Trigger multiple transitions simultaneously via direct calls (including duplicate and self-transition)
	world_router.request_transition(portal, "test_region_alpha", "from_beta")
	world_router.request_transition(portal, "test_region_alpha", "from_beta")
	world_router.request_transition(portal, "test_region_beta", "default") # self-transition

	_run_physics_frames(5, func() -> void:
		world_router.region_transition_started.disconnect(on_started)
		var count: int = int(state["signal_count"])
		_assert(count == 1, "Duplicate requests during transition were guarded; exactly 1 transition started, got %d" % count)
		_assert(player == initial_player_instance, "Same player identity preserved through direct call transition")
		_assert(world_router.active_region_id == "test_region_alpha", "Transition back to Alpha completed")
		var expected_pos: Vector2 = world_router.active_region.get_spawn_position("from_beta")
		_assert(player.global_position == expected_pos, "Player positioned at exact from_beta spawn: %s" % str(player.global_position))
		_run_physics_frames(2, _step_locked_region_guard)
	)

func _step_locked_region_guard() -> void:
	current_step_name = "Locked & Unknown Region Guard"
	var portal: RegionPortal = world_router.active_region.portals_container.get_node_or_null("PortalToBeta") as RegionPortal
	if portal == null:
		_fail_immediate("Missing PortalToBeta in test_region_alpha")
		return

	var initial_pos: Vector2 = player.global_position
	var initial_region_id: String = world_router.active_region_id

	# 1. Test locked region
	world_router.set_region_available("test_region_beta", false)

	var state: Dictionary = {"failed_reason": ""}
	var on_failed: Callable = func(reason: String, _from: String, _to: String) -> void:
		state["failed_reason"] = reason
	world_router.region_transition_failed.connect(on_failed)

	world_router.request_transition(portal, "test_region_beta", "from_alpha")

	_run_physics_frames(3, func() -> void:
		var r1: String = str(state["failed_reason"])
		_assert(r1 == "region_locked", "Transition blocked with reason 'region_locked', got '%s'" % r1)
		_assert(world_router.active_region_id == initial_region_id, "Region preserved on locked attempt: %s" % world_router.active_region_id)
		_assert(player.global_position == initial_pos, "Player position unchanged on locked attempt")
		_assert(not player.input_frozen, "Player movement resumed after failed transition")

		# 2. Test unknown region
		state["failed_reason"] = ""
		world_router.request_transition(portal, "nonexistent_secret_realm", "default")

		_run_physics_frames(3, func() -> void:
			world_router.region_transition_failed.disconnect(on_failed)
			var r2: String = str(state["failed_reason"])
			_assert(r2 == "unknown_region", "Transition blocked with reason 'unknown_region', got '%s'" % r2)
			_assert(world_router.active_region_id == initial_region_id, "Region preserved on unknown destination")
			world_router.set_region_available("test_region_beta", true)
			_run_physics_frames(2, _step_invalid_and_obstructed_spawn_rollback)
		)
	)

func _step_invalid_and_obstructed_spawn_rollback() -> void:
	current_step_name = "Invalid / Missing / Obstructed Spawn Rollback"
	var portal: RegionPortal = world_router.active_region.portals_container.get_node_or_null("PortalToBeta") as RegionPortal
	if portal == null:
		_fail_immediate("Missing PortalToBeta in test_region_alpha")
		return

	var initial_pos: Vector2 = player.global_position
	var initial_region: BaseRegion = world_router.active_region
	var initial_region_id: String = world_router.active_region_id

	# Verify and record collision shape state in initial_region to prove preservation
	var old_col: CollisionShape2D = initial_region.get_node_or_null("Perimeter/WallTop") as CollisionShape2D
	if old_col != null:
		old_col.disabled = true
	var was_disabled: bool = old_col.disabled if old_col != null else false

	var state: Dictionary = {"failed_reason": ""}
	var on_failed: Callable = func(reason: String, _from: String, _to: String) -> void:
		state["failed_reason"] = reason
	world_router.region_transition_failed.connect(on_failed)

	# 1. Test missing spawn ID
	world_router.request_transition(portal, "test_region_beta", "nonexistent_spawn_node")

	_run_physics_frames(3, func() -> void:
		var r1: String = str(state["failed_reason"])
		_assert(r1 == "spawn_not_found", "Transition rejected with 'spawn_not_found', got '%s'" % r1)
		_assert(world_router.active_region == initial_region, "Active region instance preserved after rejected spawn")
		_assert(player.global_position == initial_pos, "Player position preserved after rejected spawn")
		if old_col != null:
			_assert(old_col.disabled == was_disabled and was_disabled == true, "Old region collider disabled state strictly preserved on rejection (%s)" % str(old_col.disabled))
			old_col.disabled = false

		# 2. Transition to Beta to test Alpha's out-of-bounds spawn and obstructed spawn
		world_router.region_transition_failed.disconnect(on_failed)
		world_router.request_transition(portal, "test_region_beta", "from_alpha")

		_run_physics_frames(3, func() -> void:
			_assert(world_router.active_region_id == "test_region_beta", "Arrived in Beta for candidate rollback tests")
			var beta_portal: RegionPortal = world_router.active_region.portals_container.get_node_or_null("PortalToAlpha") as RegionPortal
			if beta_portal == null:
				_fail_immediate("Missing PortalToAlpha in test_region_beta")
				return

			var beta_pos: Vector2 = player.global_position
			var beta_region: BaseRegion = world_router.active_region

			world_router.region_transition_failed.connect(on_failed)

			# Test out of bounds spawn in Alpha
			state["failed_reason"] = ""
			world_router.request_transition(beta_portal, "test_region_alpha", "out_of_bounds_spawn")

			_run_physics_frames(3, func() -> void:
				var r2: String = str(state["failed_reason"])
				_assert(r2 == "spawn_out_of_bounds", "Transition rejected with 'spawn_out_of_bounds', got '%s'" % r2)
				_assert(world_router.active_region == beta_region, "Active region preserved on out-of-bounds spawn")
				_assert(player.global_position == beta_pos, "Player position preserved on out-of-bounds spawn")

				# Test obstructed spawn in Alpha (CentralPillar)
				state["failed_reason"] = ""
				world_router.request_transition(beta_portal, "test_region_alpha", "obstructed_spawn")

				_run_physics_frames(3, func() -> void:
					world_router.region_transition_failed.disconnect(on_failed)
					var r3: String = str(state["failed_reason"])
					_assert(r3 == "spawn_obstructed", "Transition rejected with 'spawn_obstructed', got '%s'" % r3)
					_assert(world_router.active_region == beta_region, "Active region preserved on obstructed spawn")
					_assert(player.global_position == beta_pos, "Player position preserved on obstructed spawn")
					_assert(not player.input_frozen, "Player input movement resumed after obstructed rollback")

					_step_rejected_startup_check()
				)
			)
		)
	)

func _step_rejected_startup_check() -> void:
	current_step_name = "Rejected Invalid Startup Check"
	# Create an isolated WorldRouter to test startup rejection on invalid region and invalid spawn
	var isolated_router: WorldRouter = WorldRouter.new()
	var dummy_container: Node2D = Node2D.new()
	var player_packed: PackedScene = load("res://scenes/player/player.tscn") as PackedScene
	var test_player: PlayerCharacter = player_packed.instantiate() as PlayerCharacter
	root.add_child(dummy_container)
	root.add_child(test_player)
	root.add_child(isolated_router)
	isolated_router.setup(dummy_container, test_player)

	var initial_player_xform: Transform2D = test_player.global_transform
	var initial_player_vel: Vector2 = test_player.velocity

	var res_bad_region: bool = isolated_router.initialize_starting_region("nonexistent_region", "default")
	_assert(not res_bad_region, "Startup rejected for unknown region")
	_assert(isolated_router.active_region == null, "Isolated router active region remains null on unknown region startup")
	_assert(test_player.global_transform == initial_player_xform, "Player unchanged after bad region startup")

	var res_bad_spawn: bool = isolated_router.initialize_starting_region("test_region_alpha", "nonexistent_spawn")
	_assert(not res_bad_spawn, "Startup rejected for nonexistent spawn")
	_assert(isolated_router.active_region == null, "Isolated router active region remains null on missing spawn startup")
	_assert(test_player.global_transform == initial_player_xform, "Player unchanged after nonexistent spawn startup")

	var res_obstructed_spawn: bool = isolated_router.initialize_starting_region("test_region_alpha", "obstructed_spawn")
	_assert(not res_obstructed_spawn, "Startup rejected for obstructed spawn")
	_assert(isolated_router.active_region == null, "Isolated router active region remains null on obstructed spawn startup")
	_assert(test_player.global_transform == initial_player_xform, "Player unchanged after obstructed spawn startup")

	isolated_router.queue_free()
	test_player.queue_free()
	dummy_container.queue_free()

	_finish_test_suite()

func _finish_test_suite() -> void:
	if suite_completed:
		return
	suite_completed = true
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
	_await_physics_frames(frames, callback)

func _await_physics_frames(frames: int, callback: Callable) -> void:
	for _i in range(frames):
		await physics_frame
	await process_frame
	callback.call_deferred()
