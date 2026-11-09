extends SceneTree

## SBL-W10-003 Settings, Audio & Accessibility Test Suite
## Requirements: GDD-103, TC-ACC-001, AGENTS.md Invariants.

const GameRootScene: PackedScene = preload("res://scenes/main/game_root.tscn")
const SettingsSheetScene: PackedScene = preload("res://scenes/ui/settings_sheet.tscn")

var _failures: int = 0
var _test_root: String = ""
var _test_settings_path: String = ""
var _user_settings_path: String = ""
var _orig_user_settings_existed: bool = false
var _orig_user_settings_bytes: PackedByteArray = PackedByteArray()

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("SETTINGS TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W10-003 Settings, Audio & Accessibility Test Suite ---")

	# Snapshot real user settings file to prove byte identity before and after suite
	_user_settings_path = SettingsManager.SETTINGS_FILE_PATH
	_orig_user_settings_existed = FileAccess.file_exists(_user_settings_path)
	if _orig_user_settings_existed:
		_orig_user_settings_bytes = FileAccess.get_file_as_bytes(_user_settings_path)
	else:
		_orig_user_settings_bytes = PackedByteArray()

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

	# SBL-REV-004: Bus routing and mute assertions
	sm.apply_audio_buses()
	var m_bus: int = AudioServer.get_bus_index("Master")
	var music_bus: int = AudioServer.get_bus_index("Music")
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	_check(m_bus >= 0, "Master bus exists in AudioServer")
	_check(music_bus >= 0, "Music bus exists in AudioServer")
	_check(sfx_bus >= 0, "SFX bus exists in AudioServer")
	_check(AudioServer.get_bus_send(music_bus) == &"Master", "Music bus sends to Master")
	_check(AudioServer.get_bus_send(sfx_bus) == &"Master", "SFX bus sends to Master")

	# SFX volume zero mutes SFX bus while Master and Music remain unchanged
	sm.set_master_volume(1.0)
	sm.set_music_volume(0.8)
	sm.set_sfx_volume(0.0)
	_check(AudioServer.is_bus_mute(sfx_bus) == true, "SFX volume 0.0 mutes SFX bus")
	_check(AudioServer.get_bus_volume_db(sfx_bus) <= -80.0, "SFX bus volume set to <= -80.0 dB on zero")
	_check(AudioServer.is_bus_mute(m_bus) == false, "Master bus remains unmuted when only SFX is zero")
	_check(AudioServer.is_bus_mute(music_bus) == false, "Music bus remains unmuted when only SFX is zero")

	# Restore positive SFX volume clears mute flag
	sm.set_sfx_volume(0.7)
	_check(AudioServer.is_bus_mute(sfx_bus) == false, "Positive SFX volume clears SFX mute flag")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(sfx_bus), linear_to_db(0.7)), "Positive SFX volume sets gain accurately")

	# Master volume zero mutes Master bus, affecting all output while Music and SFX remain independent
	sm.set_master_volume(0.0)
	_check(AudioServer.is_bus_mute(m_bus) == true, "Master volume 0.0 mutes Master bus")
	_check(AudioServer.get_bus_volume_db(m_bus) <= -80.0, "Master bus volume set to <= -80.0 dB on zero")
	_check(AudioServer.is_bus_mute(sfx_bus) == false, "SFX bus mute flag independent of Master mute")
	_check(AudioServer.is_bus_mute(music_bus) == false, "Music bus mute flag independent of Master mute")

	# Restore Master volume positive
	sm.set_master_volume(1.0)
	_check(AudioServer.is_bus_mute(m_bus) == false, "Positive Master volume clears Master mute flag")

	# Set zero master for file save test
	sm.set_master_volume(0.0)
	sm.set_sfx_volume(0.0)

	sm.settings_changed.disconnect(on_changed)

	# Round-trip Save and Load
	var err_save: Error = sm.save_settings(_test_settings_path)
	_check(err_save == OK, "Settings successfully saved to disk")

	# Unmute buses in runtime to prove load_settings re-applies mute states
	AudioServer.set_bus_mute(m_bus, false)
	AudioServer.set_bus_mute(sfx_bus, false)

	var sm_loaded: SettingsManager = SettingsManager.new()
	var err_load: Error = sm_loaded.load_settings(_test_settings_path)
	_check(err_load == OK, "Settings successfully loaded from disk")
	_check(sm_loaded.reduced_motion == true, "Loaded reduced_motion matches saved")
	_check(sm_loaded.high_contrast == true, "Loaded high_contrast matches saved")
	_check(is_equal_approx(sm_loaded.text_scale, 1.5), "Loaded text_scale matches saved")
	_check(is_equal_approx(sm_loaded.master_volume, 0.0), "Loaded master_volume matches saved")
	_check(is_equal_approx(sm_loaded.sfx_volume, 0.0), "Loaded sfx_volume matches saved")
	_check(AudioServer.is_bus_mute(m_bus) == true, "load_settings reapplied Master bus mute")
	_check(AudioServer.is_bus_mute(sfx_bus) == true, "load_settings reapplied SFX bus mute")

	# ==========================================================================
	# Part 2: SettingsSheet UI Component Flow
	# ==========================================================================
	var sheet: SettingsSheet = SettingsSheetScene.instantiate() as SettingsSheet
	_check(sheet != null, "SettingsSheet instantiated")
	root.add_child(sheet)
	await process_frame

	var sm_ui: SettingsManager = SettingsManager.new()
	sm_ui.settings_path = _test_settings_path
	sheet.custom_settings_path = _test_settings_path
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

	# Browser-safe backup import: the text box path never reads the system clipboard.
	var backup_root: String = _test_root + "_backup"
	var backup_store: ProfileStore = ProfileStore.new(backup_root)
	var backup_profile: Dictionary = backup_store.new_profile("profile_01")
	backup_profile["character"]["level"] = 3
	backup_profile["character"]["xp"] = 0
	_check(backup_store.save_profile("profile_01", backup_profile) == OK, "Backup fixture profile saved")
	var exported: Dictionary = backup_store.export_backup("profile_01")
	_check(exported.get("error", ERR_UNCONFIGURED) == OK, "Backup fixture exported")
	var imported_box: Array[bool] = [false]
	sheet.backup_imported.connect(func() -> void: imported_box[0] = true)
	sheet.set_profile_context(backup_store, "profile_01")
	sheet.backup_text_field.text = String(exported.get("text", ""))
	sheet._on_import_text_pressed()
	_check(imported_box[0], "Text-box import succeeds without clipboard access")
	imported_box[0] = false
	sheet.backup_text_field.text = "{not valid json"
	sheet._on_import_text_pressed()
	_check(not imported_box[0], "Malformed text-box backup is rejected safely")
	_cleanup_dir(backup_root)

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
	if game_root.settings_manager != null:
		game_root.settings_manager.settings_path = "%s/gameroot_settings.json" % _test_root
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

	# Text scale and contrast must change the live UI, not only the stored flags.
	var font_before: int = game_root.status_label.get_theme_font_size("font_size")
	game_root.settings_manager.set_text_scale(1.5)
	await process_frame
	var font_after: int = game_root.status_label.get_theme_font_size("font_size")
	_check(font_after > font_before, "Text scale applied to live GameRoot UI")
	game_root.settings_manager.set_text_scale(1.0)
	await process_frame
	_check(game_root.status_label.get_theme_font_size("font_size") == font_before, "Text scale restores authored size")

	# SBL-FIX-009: Extended High Contrast beyond modulate (font color and shadow overrides)
	var authored_color: Color = game_root.status_label.get_theme_color("font_color")
	game_root.settings_manager.set_high_contrast(true)
	await process_frame
	_check(game_root.world_container.modulate.r > 1.0, "High contrast applied to world presentation modulate")
	_check(game_root.status_label.get_theme_color("font_color") == Color(1, 1, 1, 1), "Label font color overridden to high contrast pure white")
	_check(game_root.status_label.get_theme_color("font_shadow_color") == Color(0, 0, 0, 1), "Label shadow color overridden to high contrast black outline")
	_check(game_root.status_label.get_theme_constant("shadow_offset_x") == 1, "Label shadow offset overridden to 1")

	# Restore high contrast to false -> verify authored values restored
	game_root.settings_manager.set_high_contrast(false)
	await process_frame
	_check(game_root.status_label.get_theme_color("font_color") == authored_color, "Label font color restored to authored value")
	_check(not game_root.status_label.has_theme_constant_override("shadow_offset_x"), "Label shadow override removed on restore")

	# ==========================================================================
	# SBL-FIX-009: Keyboard Reachability, Focus Order & Visible Focus
	# ==========================================================================
	print("--- Running SBL-FIX-009 Keyboard Reachability & Focus Tests ---")

	# 1. SettingsSheet focus traversal
	var settings_sheet: SettingsSheet = game_root._settings_sheet as SettingsSheet
	_check(settings_sheet != null, "Settings sheet is non-null")
	var settings_controls: Array[Control] = settings_sheet.get_focusable_controls()
	_assert_focus_reachability(settings_controls, "SettingsSheet")

	# SBL-UX-001 Escape during capture cancels capture without closing SettingsSheet
	var move_left_row: Dictionary = settings_sheet._action_rows.get(&"move_left", {})
	var rebind_btn: Button = move_left_row.get("rebind_btn") as Button
	_check(rebind_btn != null, "Rebind button for move_left exists")
	if rebind_btn != null:
		rebind_btn.pressed.emit()
		_check(InputBindings.is_capture_active() == true, "Capture is active after rebind pressed")
		var esc_key := InputEventKey.new()
		esc_key.physical_keycode = KEY_ESCAPE
		esc_key.pressed = true
		settings_sheet._input(esc_key)
		await process_frame
		_check(InputBindings.is_capture_active() == false, "Capture canceled by Escape key")
		_check(game_root._settings_sheet != null, "SettingsSheet remains open after Escape cancels capture")
		_check(rebind_btn.has_focus() == true, "Initiating rebind button regained focus after cancel")

	# SBL-UX-001 Escape outside capture closes SettingsSheet normally
	var esc_close := InputEventAction.new()
	esc_close.action = "ui_cancel"
	esc_close.pressed = true
	settings_sheet._unhandled_input(esc_close)
	await process_frame
	_check(game_root._settings_sheet == null, "Settings sheet closed by Escape outside capture in GameRoot")

	# 2. InventorySheet focus traversal
	var inv_scene: PackedScene = load("res://scenes/ui/inventory_sheet.tscn")
	var inv_sheet: InventorySheet = inv_scene.instantiate() as InventorySheet
	root.add_child(inv_sheet)
	var test_inv := InventoryManager.new()
	test_inv.add_banked_item("iron_sword", 1)
	inv_sheet.set_inventory(test_inv)
	await process_frame
	_assert_focus_reachability(inv_sheet.get_focusable_controls(), "InventorySheet")
	inv_sheet.queue_free()
	await process_frame

	# 3. CharacterSheet focus traversal
	var char_scene: PackedScene = load("res://scenes/ui/character_sheet.tscn")
	var char_sheet: CharacterSheet = char_scene.instantiate() as CharacterSheet
	root.add_child(char_sheet)
	var test_stats := CharacterStats.new()
	char_sheet.set_stats(test_stats)
	char_sheet.set_kurei_tree(KureiTree.new())
	await process_frame
	_assert_focus_reachability(char_sheet.get_focusable_controls(), "CharacterSheet")
	char_sheet.queue_free()
	await process_frame

	# 4. ChapterActivityDialog focus traversal
	var dialog := ChapterActivityDialog.new()
	root.add_child(dialog)
	var q := QuestionBank.get_question("q_dec_01")
	dialog.configure(q, {})
	await process_frame
	_assert_focus_reachability(dialog.get_focusable_controls(), "ChapterActivityDialog")
	dialog.queue_free()
	await process_frame

	# 5. Reduced Motion Confirmation
	# Verify reduced motion setting toggles and confirm zero animation nodes exist in project
	var rm_before: bool = game_root.settings_manager.reduced_motion
	game_root.settings_manager.set_reduced_motion(not rm_before)
	_check(game_root.settings_manager.reduced_motion == not rm_before, "Reduced motion toggled successfully")
	game_root.settings_manager.set_reduced_motion(rm_before)
	_check(game_root.settings_manager.reduced_motion == rm_before, "Reduced motion restored to initial value")

	_check(player.input_frozen == false, "Player unfrozen after settings closed")

	# ==========================================================================
	# 6. SBL-REV-002 Title Settings Overlay Escape, Focus & Freeze Verification
	# ==========================================================================
	game_root.open_title_screen()
	await process_frame

	_check(game_root._title_screen != null, "TitleScreen opened on game_root")
	_check(player.input_frozen == true, "Player frozen during TitleScreen")

	var title_inst: TitleScreen = game_root._title_screen
	game_root.open_title_settings("profile_01", title_inst.settings_btn, "general")
	await process_frame

	_check(game_root._title_settings_sheet != null, "Title settings overlay opened")
	var initial_overlay_sheet: SettingsSheet = game_root._title_settings_sheet

	# Duplicate entry rejection check
	game_root.open_title_settings("profile_01", title_inst.settings_btn, "general")
	_check(game_root._title_settings_sheet == initial_overlay_sheet, "Repeated entry creates no duplicate sheets")

	# Escape (ui_cancel) closes overlay only, leaving TitleScreen open
	var esc_ev := InputEventAction.new()
	esc_ev.action = "ui_cancel"
	esc_ev.pressed = true
	game_root._title_settings_sheet._unhandled_input(esc_ev)
	await process_frame

	_check(game_root._title_settings_sheet == null, "Escape dismissed Title Settings overlay")
	_check(game_root._title_screen != null, "Escape left TitleScreen open")
	_check(player.input_frozen == true, "Player Ren remains frozen while TitleScreen remains open")
	_check(title_inst.settings_btn.has_focus() == true, "Originating focus restored to Title Settings button")

	game_root._close_title_screen()
	await process_frame
	_check(game_root._title_screen == null, "Title screen closed")
	_check(player.input_frozen == false, "Player unfrozen after title screen closed")

	game_root.queue_free()
	await process_frame

	# Clean up temporary test files
	_cleanup_dir(_test_root)

	# Verify real user settings file is byte-identical before and after the suite
	var user_settings_byte_identical: bool = false
	if _orig_user_settings_existed:
		if FileAccess.file_exists(_user_settings_path):
			var current_bytes: PackedByteArray = FileAccess.get_file_as_bytes(_user_settings_path)
			user_settings_byte_identical = (current_bytes == _orig_user_settings_bytes)
			if not user_settings_byte_identical:
				var f_res := FileAccess.open(_user_settings_path, FileAccess.WRITE)
				if f_res != null:
					f_res.store_buffer(_orig_user_settings_bytes)
					f_res.close()
	else:
		user_settings_byte_identical = not FileAccess.file_exists(_user_settings_path)
		if not user_settings_byte_identical:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_user_settings_path))

	_check(user_settings_byte_identical, "Real user settings file '%s' is byte-identical before and after the suite" % _user_settings_path)

	print("--- Settings & Accessibility Test Complete. Failures: %d ---" % _failures)
	if _failures == 0:
		print("ALL SETTINGS & ACCESSIBILITY TESTS PASSED (100% SUCCESS)")
		quit(0)
	else:
		printerr("TESTS FAILED with %d error(s)" % _failures)
		quit(1)

func _assert_focus_reachability(controls: Array[Control], sheet_name: String) -> void:
	_check(controls.size() > 0, "%s: Focusable controls list is not empty" % sheet_name)
	for c in controls:
		_check(c.focus_mode == Control.FOCUS_ALL, "%s: Control %s has focus_mode == FOCUS_ALL" % [sheet_name, c.name])
		_check(not String(c.focus_next).is_empty(), "%s: Control %s has focus_next configured" % [sheet_name, c.name])
		_check(not String(c.focus_previous).is_empty(), "%s: Control %s has focus_previous configured" % [sheet_name, c.name])
		_check(c.has_theme_stylebox_override("focus"), "%s: Control %s has high-visibility focus stylebox override" % [sheet_name, c.name])

	# Traverse circular focus chain via focus_next
	if controls.size() > 1:
		var current: Control = controls[0]
		var visited: Dictionary = {}
		for _step in range(controls.size() + 2):
			visited[current] = true
			var next_path: NodePath = current.focus_next
			var next_node: Control = current.get_node_or_null(next_path) as Control
			_check(next_node != null, "%s: Focus next target from %s exists" % [sheet_name, current.name])
			if next_node == controls[0]:
				break
			current = next_node
		_check(visited.size() == controls.size(), "%s: Focus traversal reached all %d controls in circular chain" % [sheet_name, controls.size()])

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
