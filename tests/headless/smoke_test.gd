extends SceneTree

class SmokeErrorCaptureLogger extends Logger:
	var _mutex: Mutex = Mutex.new()
	var error_count: int = 0

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		_code: String,
		_rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			_mutex.lock()
			error_count += 1
			_mutex.unlock()

	func get_error_count() -> int:
		_mutex.lock()
		var count: int = error_count
		_mutex.unlock()
		return count

const EXPECTED_MAIN_SCENE: String = "res://scenes/main/game_root.tscn"
const EXPECTED_WIDTH: int = 960
const EXPECTED_HEIGHT: int = 540
const EXPECTED_RENDERER: String = "gl_compatibility"
const EXPECTED_ENGINE_MAJOR: int = 4
const EXPECTED_ENGINE_MINOR: int = 7
const EXPECTED_ENGINE_PATCH: int = 2
const EXPECTED_ENGINE_STATUS: String = "stable"
const EXPECTED_TITLE_TEXT: String = "Soulbound"
const EXPECTED_STATUS_TEXT: String = "Overworld Active"

func _init() -> void:
	call_deferred("_run_smoke_test")

func _run_smoke_test() -> void:
	print("--- Running Soulbound Headless Smoke Test (SBL-M1-001 / SBL-W2-001 Regression) ---")
	var success: bool = true

	# 1. Enforce exact Godot 4.7.2 stable version
	var version_info: Dictionary = Engine.get_version_info()
	var major: int = int(version_info.get("major", 0))
	var minor: int = int(version_info.get("minor", 0))
	var patch: int = int(version_info.get("patch", 0))
	var status: String = str(version_info.get("status", ""))
	print("Engine Version: %s.%s.%s.%s" % [major, minor, patch, status])

	if major != EXPECTED_ENGINE_MAJOR or minor != EXPECTED_ENGINE_MINOR or patch != EXPECTED_ENGINE_PATCH or status != EXPECTED_ENGINE_STATUS:
		printerr("FAIL: Engine version mismatch! Expected %s.%s.%s.%s, got %s.%s.%s.%s" % [
			EXPECTED_ENGINE_MAJOR, EXPECTED_ENGINE_MINOR, EXPECTED_ENGINE_PATCH, EXPECTED_ENGINE_STATUS,
			major, minor, patch, status
		])
		success = false
	else:
		print("PASS: Engine version matches exact %s.%s.%s.%s" % [major, minor, patch, status])

	# 2. Check Project Settings: Display Resolution (GDD-103)
	var width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	if width != EXPECTED_WIDTH or height != EXPECTED_HEIGHT:
		printerr("FAIL: Resolution mismatch! Expected %sx%s, got %sx%s" % [EXPECTED_WIDTH, EXPECTED_HEIGHT, width, height])
		success = false
	else:
		print("PASS: Display resolution is %sx%s" % [width, height])

	# 3. Check Stretch Settings (GDD-103)
	var stretch_mode: String = str(ProjectSettings.get_setting("display/window/stretch/mode", ""))
	var stretch_aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect", ""))
	if stretch_mode != "canvas_items" or stretch_aspect != "keep":
		printerr("FAIL: Stretch mode/aspect mismatch! Got mode=%s, aspect=%s" % [stretch_mode, stretch_aspect])
		success = false
	else:
		print("PASS: Stretch configuration is canvas_items/keep")

	# 4. Check Renderer Settings: desktop and web (GDD-095)
	var desktop_renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var web_renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method.web", ""))
	if desktop_renderer != EXPECTED_RENDERER:
		printerr("FAIL: Desktop renderer mismatch! Expected %s, got %s" % [EXPECTED_RENDERER, desktop_renderer])
		success = false
	else:
		print("PASS: Desktop renderer method is %s" % desktop_renderer)

	if web_renderer != EXPECTED_RENDERER:
		printerr("FAIL: Web renderer mismatch! Expected %s, got %s" % [EXPECTED_RENDERER, web_renderer])
		success = false
	else:
		print("PASS: Web renderer method is %s" % web_renderer)

	# 5. Check Main Scene Setting (GDD-093, GDD-096)
	var main_scene_path: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene_path != EXPECTED_MAIN_SCENE:
		printerr("FAIL: Main scene setting mismatch! Expected %s, got %s" % [EXPECTED_MAIN_SCENE, main_scene_path])
		success = false
	else:
		print("PASS: Main scene setting points to %s" % main_scene_path)

	# 6. Load, instantiate, and attach Main Scene under scoped Logger capture
	var scene_check_passed: bool = _load_and_verify_main_scene(main_scene_path)
	if not scene_check_passed:
		success = false

	if success:
		print("--- ALL SMOKE CHECKS PASSED SUCCESSFULLY ---")
		quit(0)
	else:
		printerr("--- SMOKE CHECKS FAILED ---")
		quit(1)

func _load_and_verify_main_scene(scene_path: String) -> bool:
	var logger: SmokeErrorCaptureLogger = SmokeErrorCaptureLogger.new()
	OS.add_logger(logger)
	var check_success: bool = true
	var instance: Node = null

	if not ResourceLoader.exists(scene_path):
		printerr("FAIL: Main scene resource does not exist at %s" % scene_path)
		check_success = false
	else:
		var packed_scene: PackedScene = load(scene_path) as PackedScene
		if not packed_scene or not packed_scene.can_instantiate():
			printerr("FAIL: Could not load or instantiate main scene %s" % scene_path)
			check_success = false
		else:
			print("PASS: Successfully loaded PackedScene from %s" % scene_path)
			instance = packed_scene.instantiate()
			if not instance:
				printerr("FAIL: Instantiation of main scene returned null")
				check_success = false
			else:
				root.add_child(instance)

				if instance.name != "GameRoot":
					printerr("FAIL: Root instance name mismatch! Expected 'GameRoot', got '%s'" % instance.name)
					check_success = false
				else:
					print("PASS: Root instance name is 'GameRoot'")

				if not (instance is Control):
					printerr("FAIL: GameRoot is not of expected type Control")
					check_success = false
				else:
					print("PASS: GameRoot type is Control")

				if not instance.is_inside_tree():
					printerr("FAIL: GameRoot is not inside tree")
					check_success = false
				else:
					print("PASS: GameRoot is inside tree")

				if not instance.is_node_ready():
					printerr("FAIL: GameRoot is not ready")
					check_success = false
				else:
					print("PASS: GameRoot is ready")

				var title_node: Label = instance.get_node_or_null("UIOverlay/VBoxContainer/TitleLabel") as Label
				var status_node: Label = instance.get_node_or_null("UIOverlay/VBoxContainer/StatusLabel") as Label

				if title_node == null:
					printerr("FAIL: TitleLabel node missing from GameRoot scene")
					check_success = false
				elif title_node.text != EXPECTED_TITLE_TEXT:
					printerr("FAIL: TitleLabel text mismatch! Expected '%s', got '%s'" % [EXPECTED_TITLE_TEXT, title_node.text])
					check_success = false
				else:
					print("PASS: TitleLabel text matches '%s'" % EXPECTED_TITLE_TEXT)

				if status_node == null:
					printerr("FAIL: StatusLabel node missing from GameRoot scene")
					check_success = false
				elif status_node.text != EXPECTED_STATUS_TEXT:
					printerr("FAIL: StatusLabel text mismatch! Expected '%s', got '%s'" % [EXPECTED_STATUS_TEXT, status_node.text])
					check_success = false
				else:
					print("PASS: StatusLabel text matches '%s'" % EXPECTED_STATUS_TEXT)

				# Additional W2 check: Player and WorldRouter exist
				var player_node: Node = instance.get_node_or_null("Player")
				var router_node: Node = instance.get_node_or_null("WorldRouter")
				if player_node == null or not (player_node is PlayerCharacter):
					printerr("FAIL: PlayerCharacter node missing or invalid type under GameRoot")
					check_success = false
				else:
					print("PASS: PlayerCharacter node present and valid under GameRoot")

				if router_node == null or not (router_node is WorldRouter):
					printerr("FAIL: WorldRouter node missing or invalid type under GameRoot")
					check_success = false
				else:
					print("PASS: WorldRouter node present and valid under GameRoot")

	OS.remove_logger(logger)

	var captured_errors: int = logger.get_error_count()
	if captured_errors > 0:
		printerr("FAIL: Scoped logger captured %d engine/script error(s) during scene load/instantiate/ready" % captured_errors)
		check_success = false
	else:
		print("PASS: Scoped logger captured 0 engine/script errors during scene lifecycle")

	if instance != null and is_instance_valid(instance):
		instance.queue_free()

	return check_success
