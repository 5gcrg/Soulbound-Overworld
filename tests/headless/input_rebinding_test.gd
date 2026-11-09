extends SceneTree

## SBL-UX-001 Persistent Keyboard/Mouse Rebinding Headless Test Suite
## Requirements: GDD-092, FR-SET-001, TC-ACC-001, NFR-ACC-001, AGENTS.md Invariants.

const GameRootScene: PackedScene = preload("res://scenes/main/game_root.tscn")
const SettingsSheetScene: PackedScene = preload("res://scenes/ui/settings_sheet.tscn")

var _failures: int = 0
var _test_root: String = ""

func _check(condition: bool, message: String) -> bool:
	if condition:
		print("  PASS: %s" % message)
	else:
		printerr("  FAIL: %s" % message)
		_failures += 1
	return condition

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=================================================================")
	print("--- Running SBL-UX-001 Persistent Input Rebinding Test Suite ---")
	print("=================================================================")

	_test_root = "user://test_rebinding_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_test_root))

	await _test_authored_defaults_and_idempotence()
	await _test_physical_movement_rebind_and_reset()
	await _test_mouse_menu_binding()
	await _test_save_reload_persistence_and_profile_isolation()
	await _test_atomic_validation_and_disk_preservation()
	await _test_legacy_and_future_version_handling()
	await _test_capture_event_consumption_and_leakage()

	# Restore pristine InputMap state per Acceptance Criteria
	InputBindings.restore_defaults_to_input_map()
	_cleanup_dir(_test_root)

	print("=================================================================")
	print("--- SBL-UX-001 Input Rebinding Test Finished. Failures: %d ---" % _failures)
	print("=================================================================")
	if _failures == 0:
		print("ALL SBL-UX-001 REBINDING TESTS PASSED (100% SUCCESS)")
		quit(0)
	else:
		printerr("TESTS FAILED with %d error(s)" % _failures)
		quit(1)

# ==============================================================================
# 1. Authored Defaults & Idempotence
# ==============================================================================
func _test_authored_defaults_and_idempotence() -> void:
	print("\n[Part 1] Testing Authored Defaults & Idempotence...")
	InputBindings.ensure_defaults_snapshotted()

	for action in InputBindings.CONFIGURABLE_ACTIONS:
		var authored: Array[Dictionary] = InputBindings.get_authored_primitives(action)
		_check(authored.size() > 0, "Action '%s' has authored default bindings (%d item(s))" % [action, authored.size()])
		var deadzone: float = InputBindings.get_authored_deadzone(action)
		_check(is_equal_approx(deadzone, 0.5), "Action '%s' authored deadzone is 0.5" % action)

	# Verify move_left has two alternatives (KEY_LEFT and KEY_A)
	var ml_prims: Array[Dictionary] = InputBindings.get_authored_primitives(&"move_left")
	_check(ml_prims.size() == 2, "move_left has 2 authored alternatives")
	var has_left_arrow: bool = false
	var has_a_key: bool = false
	for p in ml_prims:
		if p.get("physical_keycode") == KEY_LEFT:
			has_left_arrow = true
		if p.get("physical_keycode") == KEY_A:
			has_a_key = true
	_check(has_left_arrow and has_a_key, "move_left authored defaults include Left Arrow and A")

	# Deadzones and unrelated UI actions unchanged
	var ui_accept_events_before: Array[InputEvent] = InputMap.action_get_events(&"ui_accept")
	var ui_cancel_events_before: Array[InputEvent] = InputMap.action_get_events(&"ui_cancel")

	# Apply overrides idempotence
	_check(InputBindings.apply_overrides({}) == OK, "apply_overrides({}) returns OK")
	_check(InputBindings.apply_overrides({}) == OK, "apply_overrides({}) called second time returns OK (idempotent)")

	# Restore defaults idempotence
	InputBindings.restore_defaults_to_input_map()
	InputBindings.restore_defaults_to_input_map()

	var ui_accept_events_after: Array[InputEvent] = InputMap.action_get_events(&"ui_accept")
	var ui_cancel_events_after: Array[InputEvent] = InputMap.action_get_events(&"ui_cancel")
	_check(ui_accept_events_before.size() == ui_accept_events_after.size(), "Unrelated action 'ui_accept' events count unchanged")
	_check(ui_cancel_events_before.size() == ui_cancel_events_after.size(), "Unrelated action 'ui_cancel' events count unchanged")
	_check(is_equal_approx(InputMap.action_get_deadzone(&"move_left"), 0.5), "move_left deadzone preserved at 0.5")

# ==============================================================================
# 2. Physical Movement Rebind, Replaced Key Invalidation & Reset
# ==============================================================================
func _test_physical_movement_rebind_and_reset() -> void:
	print("\n[Part 2] Testing Movement Rebind, Replaced Key Disabling & Reset...")

	# Rebind move_left to physical key J (KEY_J = 74)
	var override_j: Dictionary = {
		&"move_left": [{"kind": "key", "physical_keycode": KEY_J}]
	}
	var err: Error = InputBindings.apply_overrides(override_j)
	_check(err == OK, "Applied rebind of move_left to Key J")

	# Parse physical key J press
	var ev_j_press := InputEventKey.new()
	ev_j_press.physical_keycode = KEY_J
	ev_j_press.pressed = true
	Input.parse_input_event(ev_j_press)
	Input.flush_buffered_events()
	_check(Input.is_action_pressed(&"move_left") == true, "Key J press triggers move_left")

	# Release key J
	var ev_j_rel := InputEventKey.new()
	ev_j_rel.physical_keycode = KEY_J
	ev_j_rel.pressed = false
	Input.parse_input_event(ev_j_rel)
	Input.flush_buffered_events()
	_check(Input.is_action_pressed(&"move_left") == false, "Key J release untriggers move_left")

	# Replaced key (A and Left) must stop working
	var ev_a_press := InputEventKey.new()
	ev_a_press.physical_keycode = KEY_A
	ev_a_press.pressed = true
	Input.parse_input_event(ev_a_press)
	Input.flush_buffered_events()
	_check(Input.is_action_pressed(&"move_left") == false, "Replaced key A no longer triggers move_left")

	var ev_left_press := InputEventKey.new()
	ev_left_press.physical_keycode = KEY_LEFT
	ev_left_press.pressed = true
	Input.parse_input_event(ev_left_press)
	Input.flush_buffered_events()
	_check(Input.is_action_pressed(&"move_left") == false, "Replaced key Left Arrow no longer triggers move_left")

	# Clean release states
	InputBindings.clear_all_pressed_actions()

	# Reset restores all alternatives (both Key A and Left Arrow work again)
	InputBindings.restore_defaults_to_input_map()

	Input.parse_input_event(ev_a_press)
	Input.flush_buffered_events()
	_check(Input.is_action_pressed(&"move_left") == true, "Reset restores alternative Key A for move_left")
	ev_a_press.pressed = false
	Input.parse_input_event(ev_a_press)
	Input.flush_buffered_events()

	Input.parse_input_event(ev_left_press)
	Input.flush_buffered_events()
	_check(Input.is_action_pressed(&"move_left") == true, "Reset restores alternative Left Arrow for move_left")
	ev_left_press.pressed = false
	Input.parse_input_event(ev_left_press)
	Input.flush_buffered_events()

	InputBindings.clear_all_pressed_actions()

# ==============================================================================
# 3. Mouse Menu Binding Outside Capture
# ==============================================================================
func _test_mouse_menu_binding() -> void:
	print("\n[Part 3] Testing Mouse Menu Binding Outside Capture...")

	var mouse_override: Dictionary = {
		&"toggle_settings": [{"kind": "mouse_button", "button_index": MOUSE_BUTTON_MIDDLE}]
	}
	var err: Error = InputBindings.apply_overrides(mouse_override)
	_check(err == OK, "Applied mouse override for toggle_settings to Mouse Middle")

	var m_ev := InputEventMouseButton.new()
	m_ev.button_index = MOUSE_BUTTON_MIDDLE
	m_ev.pressed = true
	Input.parse_input_event(m_ev)
	Input.flush_buffered_events()
	_check(Input.is_action_pressed(&"toggle_settings") == true, "Mouse Middle press triggers toggle_settings outside capture")

	m_ev.pressed = false
	Input.parse_input_event(m_ev)
	Input.flush_buffered_events()
	_check(Input.is_action_pressed(&"toggle_settings") == false, "Mouse Middle release untriggers toggle_settings")

	InputBindings.clear_all_pressed_actions()
	InputBindings.restore_defaults_to_input_map()

# ==============================================================================
# 4. Save/Reload Persistence & Profile Switch Isolation
# ==============================================================================
func _test_save_reload_persistence_and_profile_isolation() -> void:
	print("\n[Part 4] Testing Persistence and Profile Switch Isolation...")
	var test_path: String = _test_root + "/settings_persist.json"

	var sm_save := SettingsManager.new()
	sm_save.set_master_volume(0.65)
	var err_override: Error = sm_save.set_input_override(&"move_down", [{"kind": "key", "physical_keycode": KEY_K}])
	_check(err_override == OK, "Set move_down override to Key K in manager")
	var err_save: Error = sm_save.save_settings(test_path)
	_check(err_save == OK, "Saved settings with overrides to disk")

	# Load in fresh instance
	var sm_load := SettingsManager.new()
	var err_load: Error = sm_load.load_settings(test_path)
	_check(err_load == OK, "Loaded settings from disk")
	_check(is_equal_approx(sm_load.master_volume, 0.65), "Loaded master volume matches 0.65")
	_check(sm_load.input_overrides.has("move_down"), "Loaded input_overrides contains 'move_down'")

	var eff_events: Array[InputEvent] = InputBindings.get_effective_events(&"move_down", sm_load.input_overrides)
	_check(eff_events.size() == 1, "Effective events size is 1")
	if eff_events.size() == 1 and eff_events[0] is InputEventKey:
		_check((eff_events[0] as InputEventKey).physical_keycode == KEY_K, "Effective event is physical key K")

	# Profile switch verification in GameRoot: global settings survive unchanged
	var store := ProfileStore.new(_test_root + "/profiles")
	var game_root: Control = GameRootScene.instantiate() as Control
	game_root.profile_store = store
	root.add_child(game_root)
	game_root._init_slice_progress(store, "profile_01")
	await process_frame
	await process_frame

	_check(game_root.settings_manager != null, "GameRoot settings_manager present")
	game_root.settings_manager.load_settings(test_path)
	_check(game_root.settings_manager.input_overrides.has("move_down"), "GameRoot has move_down override")

	# Switch profile to profile_02
	game_root._init_slice_progress(store, "profile_02")
	await process_frame
	_check(game_root.settings_manager.input_overrides.has("move_down"), "Settings override preserved after profile switch to profile_02")

	game_root.queue_free()
	await process_frame
	InputBindings.clear_all_pressed_actions()
	InputBindings.restore_defaults_to_input_map()

# ==============================================================================
# 5. Atomic Validation & Disk Preservation
# ==============================================================================
func _test_atomic_validation_and_disk_preservation() -> void:
	print("\n[Part 5] Testing Atomic Validation & Disk Byte Preservation...")
	var test_path: String = _test_root + "/settings_atomic.json"

	var sm := SettingsManager.new()
	sm.set_master_volume(0.77)
	sm.save_settings(test_path)

	var orig_bytes: PackedByteArray = FileAccess.get_file_as_bytes(test_path)
	_check(orig_bytes.size() > 0, "Authored valid initial settings file on disk")

	# 1. Conflict rejection (binding move_left to D which conflicts with move_right)
	var conflict_overrides := {
		"move_left": [{"kind": "key", "physical_keycode": KEY_D}]
	}
	_check(InputBindings.validate_overrides(conflict_overrides) == ERR_INVALID_DATA, "Conflict with move_right rejected by validator")
	sm.input_overrides = conflict_overrides
	_check(sm.save_settings(test_path) == ERR_INVALID_DATA, "Save rejected on conflict")
	_check(FileAccess.get_file_as_bytes(test_path) == orig_bytes, "Disk bytes unchanged after conflict rejection")

	# 2. Invalid action name rejection
	var invalid_act_overrides := {
		"jump_action": [{"kind": "key", "physical_keycode": KEY_SPACE}]
	}
	_check(InputBindings.validate_overrides(invalid_act_overrides) == ERR_INVALID_DATA, "Unknown action name rejected")
	sm.input_overrides = invalid_act_overrides
	_check(sm.save_settings(test_path) == ERR_INVALID_DATA, "Save rejected on invalid action")
	_check(FileAccess.get_file_as_bytes(test_path) == orig_bytes, "Disk bytes unchanged after invalid action rejection")

	# 3. Empty array rejection
	var empty_arr_overrides := {
		"move_left": []
	}
	_check(InputBindings.validate_overrides(empty_arr_overrides) == ERR_INVALID_DATA, "Empty array rejected")
	sm.input_overrides = empty_arr_overrides
	_check(sm.save_settings(test_path) == ERR_INVALID_DATA, "Save rejected on empty array")
	_check(FileAccess.get_file_as_bytes(test_path) == orig_bytes, "Disk bytes unchanged after empty array rejection")

	# 4. Bad kind and bad value rejection
	var bad_kind_overrides := {
		"move_left": [{"kind": "gamepad", "button": 1}]
	}
	_check(InputBindings.validate_overrides(bad_kind_overrides) == ERR_INVALID_DATA, "Bad kind 'gamepad' rejected")

	var bad_escape_key := {
		"move_left": [{"kind": "key", "physical_keycode": KEY_ESCAPE}]
	}
	_check(InputBindings.validate_overrides(bad_escape_key) == ERR_INVALID_DATA, "Reserved key Escape rejected")

	var bad_f1_key := {
		"move_left": [{"kind": "key", "physical_keycode": KEY_F1}]
	}
	_check(InputBindings.validate_overrides(bad_f1_key) == ERR_INVALID_DATA, "Reserved key F1 rejected")

	var bad_backtick_key := {
		"move_left": [{"kind": "key", "physical_keycode": KEY_QUOTELEFT}]
	}
	_check(InputBindings.validate_overrides(bad_backtick_key) == ERR_INVALID_DATA, "Reserved key ` (backtick) rejected")

	var bad_shift_key := {
		"move_left": [{"kind": "key", "physical_keycode": KEY_SHIFT}]
	}
	_check(InputBindings.validate_overrides(bad_shift_key) == ERR_INVALID_DATA, "Modifier-only key Shift rejected")

	var bad_wheel_mouse := {
		"move_left": [{"kind": "mouse_button", "button_index": MOUSE_BUTTON_WHEEL_DOWN}]
	}
	_check(InputBindings.validate_overrides(bad_wheel_mouse) == ERR_INVALID_DATA, "Mouse wheel rejected")

	# 5. Duplicate binding within action rejection
	var duplicate_overrides := {
		"move_left": [
			{"kind": "key", "physical_keycode": KEY_J},
			{"kind": "key", "physical_keycode": KEY_J}
		]
	}
	_check(InputBindings.validate_overrides(duplicate_overrides) == ERR_INVALID_DATA, "Duplicate key within action rejected")
	sm.input_overrides = duplicate_overrides
	_check(sm.save_settings(test_path) == ERR_INVALID_DATA, "Save rejected on duplicate key")
	_check(FileAccess.get_file_as_bytes(test_path) == orig_bytes, "Disk bytes unchanged after duplicate rejection")

	# 6. Promotion failure injection: disk bytes remain unchanged
	sm.input_overrides = {"move_left": [{"kind": "key", "physical_keycode": KEY_J}]}
	sm.test_inject_promotion_failure = true
	var prom_err: Error = sm.save_settings(test_path)
	_check(prom_err != OK, "Save failed when promotion failure injected")
	_check(FileAccess.get_file_as_bytes(test_path) == orig_bytes, "Disk bytes unchanged after promotion failure")
	sm.test_inject_promotion_failure = false

	InputBindings.restore_defaults_to_input_map()

# ==============================================================================
# 6. Legacy & Future Version Handling
# ==============================================================================
func _test_legacy_and_future_version_handling() -> void:
	print("\n[Part 6] Testing Legacy & Future Version Settings Handling...")

	# 1. Legacy unversioned settings: loads defaults without rewriting disk
	var legacy_path: String = _test_root + "/settings_legacy.json"
	var legacy_dict := {
		"master_volume": 0.42,
		"music_volume": 0.55,
		"sfx_volume": 0.66,
		"reduced_motion": true,
		"high_contrast": true,
		"text_scale": 1.2
	}
	var f := FileAccess.open(legacy_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy_dict, "  "))
	f.close()

	var legacy_orig_bytes: PackedByteArray = FileAccess.get_file_as_bytes(legacy_path)
	var sm_legacy := SettingsManager.new()
	var err_leg_load: Error = sm_legacy.load_settings(legacy_path)
	_check(err_leg_load == OK, "Legacy settings loaded successfully")
	_check(is_equal_approx(sm_legacy.master_volume, 0.42), "Legacy master volume loaded")
	_check(sm_legacy.input_overrides.is_empty(), "Legacy settings defaulted input_overrides to empty")
	_check(FileAccess.get_file_as_bytes(legacy_path) == legacy_orig_bytes, "Legacy file was NOT rewritten on load (bytes identical)")

	# 2. Future-version settings: load fails, disk untouched, ordinary save fails
	var future_path: String = _test_root + "/settings_future.json"
	var future_dict := {
		"settings_schema_version": 99,
		"master_volume": 0.12,
		"input_overrides": {
			"move_left": [{"kind": "key", "physical_keycode": 9999}]
		}
	}
	var f_fut := FileAccess.open(future_path, FileAccess.WRITE)
	f_fut.store_string(JSON.stringify(future_dict, "  "))
	f_fut.close()

	var future_orig_bytes: PackedByteArray = FileAccess.get_file_as_bytes(future_path)
	var sm_future := SettingsManager.new()
	var err_fut_load: Error = sm_future.load_settings(future_path)
	_check(err_fut_load == ERR_INVALID_DATA, "Future-version load returned ERR_INVALID_DATA")
	_check(sm_future.is_save_blocked() == true, "Save is blocked on future-version manager")
	_check(is_equal_approx(sm_future.master_volume, 1.0), "In-memory values reset to session defaults")
	_check(sm_future.input_overrides.is_empty(), "In-memory input_overrides reset to session defaults")
	_check(FileAccess.get_file_as_bytes(future_path) == future_orig_bytes, "Future file was NOT rewritten on load (bytes identical)")

	var err_fut_save: Error = sm_future.save_settings(future_path)
	_check(err_fut_save == ERR_UNAVAILABLE, "Ordinary save on future-version manager fails with ERR_UNAVAILABLE")
	_check(FileAccess.get_file_as_bytes(future_path) == future_orig_bytes, "Future file remains untouched after blocked save attempt")

# ==============================================================================
# 7. Event Consumption & Leakage Prevention During Capture
# ==============================================================================
func _test_capture_event_consumption_and_leakage() -> void:
	print("\n[Part 7] Testing Event Consumption & Leakage Prevention During Capture...")

	var sheet: SettingsSheet = SettingsSheetScene.instantiate() as SettingsSheet
	var sm := SettingsManager.new()
	sheet.settings = sm
	root.add_child(sheet)
	await process_frame
	await process_frame

	var move_left_row: Dictionary = sheet._action_rows.get(&"move_left", {})
	var rebind_btn: Button = move_left_row.get("rebind_btn") as Button
	_check(rebind_btn != null, "Found Rebind button for move_left")

	# Activate capture
	rebind_btn.pressed.emit()
	_check(InputBindings.is_capture_active() == true, "Capture is active after rebind pressed")
	_check(InputBindings.get_capture_action() == &"move_left", "Capture action is move_left")

	# 1. Send candidate F1 (reserved evaluator key): should be rejected and consumed
	var ev_f1 := InputEventKey.new()
	ev_f1.physical_keycode = KEY_F1
	ev_f1.pressed = true
	sheet._input(ev_f1)
	await process_frame
	_check(InputBindings.is_capture_active() == true, "Capture remains active after rejected F1 key")
	_check(sheet.capture_status_label.text.find("F1") != -1, "Status label reports F1 rejection")

	# 2. Send echo event: ignored
	var ev_echo := InputEventKey.new()
	ev_echo.physical_keycode = KEY_J
	ev_echo.pressed = true
	ev_echo.echo = true
	sheet._input(ev_echo)
	_check(InputBindings.is_capture_active() == true, "Capture remains active after echo event")

	# 3. Send candidate Escape: cancels capture, consumes event, leaves SettingsSheet open
	var ev_esc := InputEventKey.new()
	ev_esc.physical_keycode = KEY_ESCAPE
	ev_esc.pressed = true
	sheet._input(ev_esc)
	await process_frame
	_check(InputBindings.is_capture_active() == false, "Escape canceled capture")
	_check(sheet.capture_status_label.text.find("canceled") != -1, "Status label reports capture canceled")
	_check(is_instance_valid(sheet) and sheet.is_inside_tree(), "SettingsSheet remains open after Escape cancel")
	_check(rebind_btn.has_focus() == true, "Initiating rebind button regained focus")

	# Verify pressed states cleared (no leakage)
	for action in InputBindings.CONFIGURABLE_ACTIONS:
		_check(Input.is_action_pressed(action) == false, "Action '%s' is not stuck pressed after cancel" % action)

	# 4. Activate capture again and cancel via CancelCaptureBtn
	rebind_btn.pressed.emit()
	_check(InputBindings.is_capture_active() == true, "Capture reactivated")
	sheet.cancel_capture_btn.pressed.emit()
	await process_frame
	_check(InputBindings.is_capture_active() == false, "CancelCaptureBtn canceled capture")
	_check(rebind_btn.has_focus() == true, "Initiating rebind button regained focus after Cancel button")

	# 5. Activate capture and successfully rebind to Key J
	rebind_btn.pressed.emit()
	var ev_valid_j := InputEventKey.new()
	ev_valid_j.physical_keycode = KEY_J
	ev_valid_j.pressed = true
	sheet._input(ev_valid_j)
	await process_frame
	_check(InputBindings.is_capture_active() == false, "Capture ended after valid rebind")
	_check(sheet.capture_status_label.text.find("Rebound") != -1, "Status label reports Rebound")
	_check(sm.input_overrides.has("move_left"), "Manager recorded move_left override")

	sheet.queue_free()
	await process_frame
	InputBindings.clear_all_pressed_actions()
	InputBindings.restore_defaults_to_input_map()

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
				else:
					_cleanup_dir(path.path_join(file_name))
				file_name = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(global_path)
