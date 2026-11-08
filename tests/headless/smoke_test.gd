extends SceneTree

const EXPECTED_MAIN_SCENE: String = "res://scenes/main/game_root.tscn"
const EXPECTED_WIDTH: int = 960
const EXPECTED_HEIGHT: int = 540
const EXPECTED_RENDERER: String = "gl_compatibility"
const EXPECTED_ENGINE_MAJOR: int = 4
const EXPECTED_ENGINE_MINOR: int = 7

func _init() -> void:
	print("--- Running Soulbound Headless Smoke Test (SBL-M1-001) ---")
	var success: bool = true

	# 1. Check Godot Engine Version
	var version_info: Dictionary = Engine.get_version_info()
	print("Engine Version: %s.%s.%s (%s)" % [
		version_info.get("major", 0),
		version_info.get("minor", 0),
		version_info.get("patch", 0),
		version_info.get("status", "")
	])
	var major: int = int(version_info.get("major", 0))
	var minor: int = int(version_info.get("minor", 0))
	if major != EXPECTED_ENGINE_MAJOR or minor != EXPECTED_ENGINE_MINOR:
		printerr("FAIL: Engine version mismatch! Expected 4.7.x, got %s.%s" % [major, minor])
		success = false
	else:
		print("PASS: Engine version matches 4.7.x")

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

	# 4. Check Rendering Method (GDD-095)
	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	if renderer != EXPECTED_RENDERER:
		printerr("FAIL: Renderer mismatch! Expected %s, got %s" % [EXPECTED_RENDERER, renderer])
		success = false
	else:
		print("PASS: Renderer method is %s" % renderer)

	# 5. Check Main Scene Setting (GDD-093, GDD-096)
	var main_scene_path: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene_path != EXPECTED_MAIN_SCENE:
		printerr("FAIL: Main scene setting mismatch! Expected %s, got %s" % [EXPECTED_MAIN_SCENE, main_scene_path])
		success = false
	else:
		print("PASS: Main scene setting points to %s" % main_scene_path)

	# 6. Load Main Scene Resource
	if not ResourceLoader.exists(main_scene_path):
		printerr("FAIL: Main scene resource does not exist at %s" % main_scene_path)
		quit(1)
		return

	var packed_scene: PackedScene = load(main_scene_path) as PackedScene
	if not packed_scene or not packed_scene.can_instantiate():
		printerr("FAIL: Could not load or instantiate main scene %s" % main_scene_path)
		quit(1)
		return
	print("PASS: Successfully loaded PackedScene from %s" % main_scene_path)

	# 7. Instantiate Main Scene and Attach to Scene Tree
	var instance: Node = packed_scene.instantiate()
	if not instance:
		printerr("FAIL: Instantiation of main scene returned null")
		quit(1)
		return

	root.add_child(instance)
	print("PASS: Instantiated and attached %s to SceneTree root" % instance.name)

	# 8. Verify Scene Content Nodes and Types
	var title_node: Label = instance.get_node_or_null("VBoxContainer/TitleLabel") as Label
	var status_node: Label = instance.get_node_or_null("VBoxContainer/StatusLabel") as Label
	if title_node == null or status_node == null:
		printerr("FAIL: Required label nodes missing from GameRoot scene")
		success = false
	else:
		print("PASS: Verified TitleLabel ('%s') and StatusLabel ('%s')" % [title_node.text, status_node.text])

	instance.queue_free()

	if success:
		print("--- ALL SMOKE CHECKS PASSED SUCCESSFULLY ---")
		quit(0)
	else:
		printerr("--- SMOKE CHECKS FAILED ---")
		quit(1)
