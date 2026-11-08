extends SceneTree

## SBL-W10-003 Settings, Audio & Accessibility Test Suite
## Requirements: GDD-103, TC-ACC-001, AGENTS.md Invariants.

const GameRootScene: PackedScene = preload("res://scenes/main/game_root.tscn")
const SettingsSheetScene: PackedScene = preload("res://scenes/ui/settings_sheet.tscn")

var _failures: int = 0
var _test_root: String = ""
var _test_settings_path: String = ""

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("SETTINGS TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W10-003 Settings, Audio & Accessibility Test Suite ---")

	_test_root = "user://test_settings_profiles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_settings_path = "%s/test_settings.json" % _test_root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_test_root))

	# ==========================================================================
	# Part 1: SettingsManager Core Unit Verification
	# ==========================================================================
	var sm: SettingsManager = SettingsManager.new()
	_check(is_equal_approx(sm.master_volume, 1.0), "Default master volume is 1.0")
	_check(is_equal_approx(sm.music_volume, 0.8), "Default music volume is 0.8")
	_check(is_equal_approx(sm.sfx_volume, 0.9), "Default sfx volume is 0.9")
	_check(sm.reduced_motion == false, "Default reduced_motion is false")
	_check(sm.high_contrast == false, "Default high_contrast is false")
	_check(is_equal_approx(sm.text_scale, 1.0), "Default text_scale is 1.0")

	var changed_box: Array[bool] = [false]
	var on_changed := func() -> void: changed_box[0] = true
	sm.settings_changed.connect(on_changed)

	# Clamping and signals
	sm.set_master_volume(0.5)
	_check(is_equal_approx(sm.master_volume, 0.5), "Master volume set to 0.5")
	_check(changed_box[0], "settings_changed emitted on master volume set")
	changed_box[0] = false

	sm.set_master_volume(2.5)
	_check(is_equal_approx(sm.master_volume, 1.0), "Master volume clamped to upper 1.0")

	sm.set_master_volume(-0.5)
	_check(is_equal_approx(sm.master_volume, 0.0), "Master volume clamped to lower 0.0")

	sm.set_text_scale(0.5)
	_check(is_equal_approx(sm.text_scale, 0.8), "Text scale clamped to min 0.8")

	sm.set_text_scale(2.0)
	_check(is_equal_approx(sm.text_scale, 1.5), "Text scale clamped to max 1.5")

	sm.set_reduced_motion(true)
	_check(sm.reduced_motion == true, "Reduced motion set to true")

	sm.set_high_contrast(true)
	_check(sm.high_contrast == true, "High contrast set to true")

	sm.settings_changed.disconnect(on_changed)

	# Round-trip Save and Load
	var err_save: Error = sm.save_settings(_test_settings_path)
	_check(err_save == OK, "Settings successfully saved to disk")

	var sm_loaded: SettingsManager = SettingsManager.new()
	var err_load: Error = sm_loaded.load_settings(_test_settings_path)
	_check(err_load == OK, "Settings successfully loaded from disk")
	_check(sm_loaded.reduced_motion == true, "Loaded reduced_motion matches saved")
	_check(sm_loaded.high_contrast == true, "Loaded high_contrast matches saved")
	_check(is_equal_approx(sm_loaded.text_scale, 1.5), "Loaded text_scale matches saved")
	_check(is_equal_approx(sm_loaded.master_volume, 0.0), "Loaded master_volume matches saved")

	# ==========================================================================
	# Part 2: SettingsSheet UI Component Flow
	# ==========================================================================
	var sheet: SettingsSheet = SettingsSheetScene.instantiate() as SettingsSheet
	_check(sheet != null, "SettingsSheet instantiated")
	root.add_child(sheet)
	await process_frame

	var sm_ui: SettingsManager = SettingsManager.new()
	sheet.set_settings(sm_ui)
	await process_frame

	_check(is_equal_approx(sheet.master_slider.value, 100.0), "UI master slider initial value 100%")
	_check(sheet.reduced_motion_check.button_pressed == false, "UI reduced motion initial false")

	# Manipulate UI controls
	sheet.master_slider.value = 60.0
	sheet._on_master_slider_changed(60.0)
	_check(is_equal_approx(sm_ui.master_volume, 0.6), "Manager master volume updated from UI")

	sheet.reduced_motion_check.button_pressed = true
	sheet._on_reduced_motion_toggled(true)
	_check(sm_ui.reduced_motion == true, "Manager reduced motion updated from UI")

	sheet.high_contrast_check.button_pressed = true
	sheet._on_high_contrast_toggled(true)
	_check(sm_ui.high_contrast == true, "Manager high contrast updated from UI")

	var closed_box: Array[bool] = [false]
	sheet.closed.connect(func() -> void: closed_box[0] = true)
	sheet._on_close_pressed()
	_check(closed_box[0], "SettingsSheet emitted closed on close button")

	sheet.queue_free()
	await process_frame

	# ==========================================================================
	# Part 3: GameRoot Integration & Hotkey Toggling Flow
	# ==========================================================================
	var test_store: ProfileStore = ProfileStore.new(_test_root)
	var game_root: Control = GameRootScene.instantiate() as Control
	game_root.profile_store = test_store
	root.add_child(game_root)
	game_root._init_slice_progress(test_store, "profile_01")

	await process_frame
	await process_frame

	var player: PlayerCharacter = game_root.player
	_check(player != null, "GameRoot player present")
	_check(player.input_frozen == false, "Player unfrozen initially")

	# Toggle Settings ON
	game_root._toggle_settings_sheet()
	await process_frame

	_check(game_root._settings_sheet != null, "Settings sheet open in GameRoot")
	_check(player.input_frozen == true, "Player frozen while settings open")

	# Modify setting through opened sheet
	game_root._settings_sheet.sfx_slider.value = 40.0
	game_root._settings_sheet._on_sfx_slider_changed(40.0)
	_check(is_equal_approx(game_root.settings_manager.sfx_volume, 0.4), "GameRoot settings_manager sfx updated")

	# Toggle Settings OFF
	game_root._toggle_settings_sheet()
	await process_frame

	_check(game_root._settings_sheet == null, "Settings sheet closed in GameRoot")
	_check(player.input_frozen == false, "Player unfrozen after settings closed")

	game_root.queue_free()
	await process_frame

	# Clean up temporary test files
	_cleanup_dir(_test_root)

	print("--- Settings & Accessibility Test Complete. Failures: %d ---" % _failures)
	if _failures == 0:
		print("ALL SETTINGS & ACCESSIBILITY TESTS PASSED (100% SUCCESS)")
		quit(0)
	else:
		printerr("TESTS FAILED with %d error(s)" % _failures)
		quit(1)

func _cleanup_dir(path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(global_path):
		var dir := DirAccess.open(global_path)
		if dir != null:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(global_path)
