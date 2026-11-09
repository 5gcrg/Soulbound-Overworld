extends SceneTree

## SBL-FIX-012 Save Compatibility and Recovery UX Headless Test Suite
## Requirements: GDD-098..102, FR-SAV-001/002, AGENTS.md Invariants.
##
## Verifies that:
## 1. Profiles authored before active_expedition existed load cleanly without validation error.
## 2. Unknown top-level and section-level extension keys survive a full save/load cycle.
## 3. A corrupt newest revision recovers to the previous valid revision without losing prior files.
## 4. TitleScreen surfaces recovery state when recovered == true and provides backup export.
## 5. Strict schema version rules remain exact without accepting rounding approximations.

var _failures: int = 0
var _test_dir: String = "user://test_compat_recovery_%d" % Time.get_ticks_msec()

func _init() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		printerr("  FAIL: %s" % message)
		_failures += 1

func _cleanup_dir(path: String) -> void:
	var da := DirAccess.open(path)
	if da != null:
		da.list_dir_begin()
		var item: String = da.get_next()
		while not item.is_empty():
			if item != "." and item != "..":
				var full: String = path.path_join(item)
				if da.current_is_dir():
					_cleanup_dir(full)
				else:
					da.remove(item)
			item = da.get_next()
		da.list_dir_end()
		DirAccess.remove_absolute(path)

func _run_tests() -> void:
	print("--- Running SBL-FIX-012 Save Compatibility & Recovery UX Test Suite ---")

	var store := ProfileStore.new(_test_dir)

	# --------------------------------------------------------------------------
	# 1. Pre-active_expedition legacy profile loads cleanly
	# --------------------------------------------------------------------------
	print("\n[Test 1] Pre-active_expedition legacy profile compatibility...")
	var legacy_profile: Dictionary = {
		"schema_version": 1,
		"profile_id": "profile_01",
		"character": {
			"level": 3,
			"xp": 150,
			"vitality": 12,
			"resonance": 11,
			"agility": 10,
			"focus": 10,
			"unspent_points": 0,
			"max_hp": 120,
			"spirit_power": 55
		},
		"inventory": {
			"banked": {"iron_sword": 1, "health_potion": 3},
			"satchel": {},
			"equipment": {"weapon": "iron_sword", "armor": "", "relic_1": "", "relic_2": ""}
		},
		"world": {
			"chapter_progress": {
				"current_chapter": 2,
				"unlocked_chapters": [1, 2],
				"is_academic_complete": false,
				"chapter_flags": {}
			}
			# Note: NO active_expedition key
		},
		"education": {
			"records": {
				"q_dec_01": {
					"id": "q_dec_01",
					"completed": true,
					"first_attempt_correct": true,
					"total_attempts": 1,
					"selected_index": 1
				}
			}
		}
	}

	var val_err: Error = GameplayProfileValidator.validate(legacy_profile)
	_check(val_err == OK, "Legacy profile without active_expedition passes GameplayProfileValidator")

	var save_err: Error = store.save_profile("profile_01", legacy_profile)
	_check(save_err == OK, "Saved legacy profile to store")

	var loaded_res: Dictionary = store.load_profile("profile_01")
	_check(loaded_res.get("error") == OK, "Loaded legacy profile successfully")
	var loaded_p: Dictionary = loaded_res.get("profile", {})
	_check(not loaded_p.get("world", {}).has("active_expedition"), "Loaded profile preserves absent active_expedition")

	# --------------------------------------------------------------------------
	# 2. Unknown extension keys survive save/load cycles
	# --------------------------------------------------------------------------
	print("\n[Test 2] Unknown extension keys persistence across save cycles...")
	var ext_profile: Dictionary = store.new_profile("profile_02")
	ext_profile["character"] = {
		"level": 1,
		"xp": 0,
		"custom_mod_cosmetic": "astral_shroud"
	}
	ext_profile["custom_envelope_extension"] = {
		"mod_version": "2.4.0",
		"enabled_features": ["extra_stats", "custom_log"]
	}
	ext_profile["world"]["custom_world_tag"] = "void_touched"

	var ext_save_err: Error = store.save_profile("profile_02", ext_profile)
	_check(ext_save_err == OK, "Profile with top-level and section extension keys saved successfully")

	var ext_load_res: Dictionary = store.load_profile("profile_02")
	_check(ext_load_res.get("error") == OK, "Loaded profile with extensions")
	var ext_loaded_p: Dictionary = ext_load_res.get("profile", {})

	_check(ext_loaded_p.has("custom_envelope_extension"), "Top-level extension key preserved on load")
	_check(ext_loaded_p.get("custom_envelope_extension", {}).get("mod_version") == "2.4.0", "Top-level nested extension data preserved")
	_check(ext_loaded_p.get("character", {}).get("custom_mod_cosmetic") == "astral_shroud", "Section-level extension key preserved")
	_check(ext_loaded_p.get("world", {}).get("custom_world_tag") == "void_touched", "World section extension preserved")

	# Re-save with modifications to test round-trip cycle 2
	ext_loaded_p["character"]["level"] = 2
	var cycle2_err: Error = store.save_profile("profile_02", ext_loaded_p)
	_check(cycle2_err == OK, "Saved modified profile for cycle 2")

	var cycle2_res: Dictionary = store.load_profile("profile_02")
	var cycle2_p: Dictionary = cycle2_res.get("profile", {})
	_check(cycle2_p.get("character", {}).get("level") == 2, "Level updated to 2")
	_check(cycle2_p.get("custom_envelope_extension", {}).get("mod_version") == "2.4.0", "Top-level extension survived 2nd save cycle")
	_check(cycle2_p.get("character", {}).get("custom_mod_cosmetic") == "astral_shroud", "Section extension survived 2nd save cycle")

	# --------------------------------------------------------------------------
	# 3. Corrupt slot recovered without losing previous revision
	# --------------------------------------------------------------------------
	print("\n[Test 3] Corrupt slot recovery and revision preservation...")
	var rec_slot := "profile_03"
	var p3_base: Dictionary = store.new_profile(rec_slot)
	p3_base["character"]["level"] = 5
	p3_base["character"]["xp"] = 500
	var p3_save1: Error = store.save_profile(rec_slot, p3_base)
	_check(p3_save1 == OK, "Saved initial valid revision for profile_03")

	# List files to confirm revision 1
	var list1: Dictionary = store._list_profile_files(rec_slot)
	var files1: Array[String] = list1.get("files", [])
	_check(files1.size() == 1, "profile_03 has exactly 1 revision file on disk")
	var rev1_filename: String = files1[0]

	# Stage a corrupt newest revision directly in the profile slot directory
	var slot_dir: String = store._get_slot_dir(rec_slot)
	var corrupt_rev_filename: String = "profile.0000000000000002.9999999999.000000.json"
	var corrupt_file_path: String = slot_dir.path_join(corrupt_rev_filename)
	var fa: FileAccess = FileAccess.open(corrupt_file_path, FileAccess.WRITE)
	_check(fa != null, "Created corrupt revision file")
	fa.store_string("{corrupted_json_payload_syntax_error: true,")
	fa.close()

	# Re-list files to confirm both files exist
	var list2: Dictionary = store._list_profile_files(rec_slot)
	var files2: Array[String] = list2.get("files", [])
	_check(files2.size() == 2, "profile_03 slot directory contains 2 revisions (1 corrupt, 1 valid)")

	# Load profile: should recover from revision 1 and set recovered == true
	var rec_load_res: Dictionary = store.load_profile(rec_slot)
	_check(rec_load_res.get("error") == OK, "Load succeeded via recovery")
	_check(rec_load_res.get("recovered") == true, "ProfileStore load_profile reports recovered == true")
	_check(rec_load_res.get("profile", {}).get("character", {}).get("level") == 5, "Recovered data matches revision 1 level 5")

	# Confirm prior revision file was NOT lost
	_check(FileAccess.file_exists(slot_dir.path_join(rev1_filename)), "Previous valid revision file was preserved on disk")

	# --------------------------------------------------------------------------
	# 4. Surface recovery state on TitleScreen
	# --------------------------------------------------------------------------
	print("\n[Test 4] TitleScreen recovery surfacing and export offer...")
	var title_scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_check(title_scene != null, "title_screen.tscn loaded")
	var title_screen: TitleScreen = title_scene.instantiate() as TitleScreen
	root.add_child(title_screen)
	await process_frame
	await process_frame

	title_screen.setup_profiles(store, rec_slot)
	await process_frame

	_check(title_screen.recovery_box != null, "TitleScreen recovery_box exists")
	_check(title_screen.recovery_box.visible == true, "TitleScreen surfaces recovery_box for recovered profile_03")
	_check(title_screen.recovery_label.text.contains("recovered"), "Recovery label describes recovered revision state")
	_check(title_screen.slot3_btn.text.contains("[RECOVERED]"), "Slot 3 selector button displays [RECOVERED] badge")

	var backup_triggered: Array[bool] = [false]
	title_screen.backup_requested.connect(func(): backup_triggered[0] = true)
	title_screen.recovery_export_btn.pressed.emit()
	_check(backup_triggered[0] == true, "Recovery export button triggers backup_requested signal before overwrite")

	title_screen.queue_free()
	await process_frame

	# --------------------------------------------------------------------------
	# 5. Strict schema version rules remain exact
	# --------------------------------------------------------------------------
	print("\n[Test 5] Strict schema version exactness verification...")
	# Verify that values which only round to 1 are rejected
	var rounding_impostor: String = '{"schema_version": 1.00000000000000001, "profile_id": "profile_01", "character": {}, "inventory": {}, "world": {}, "education": {}}'
	var dec_impostor: Dictionary = store._decode(rounding_impostor, "profile_01")
	_check(dec_impostor["error"] == ERR_FILE_UNRECOGNIZED, "1.00000000000000001 rejected as ERR_FILE_UNRECOGNIZED")

	var dec_valid_exact: Dictionary = store._decode('{"schema_version": 1.0, "profile_id": "profile_01", "character": {}, "inventory": {}, "world": {}, "education": {}}', "profile_01")
	_check(dec_valid_exact["error"] == OK, "Exact mathematical 1.0 accepted as OK")

	# Clean up test directory
	_cleanup_dir(_test_dir)

	if _failures == 0:
		print("\n--- SBL-FIX-012 Save Compatibility & Recovery UX Test Suite PASSED ---")
		quit(0)
	else:
		printerr("\n--- SBL-FIX-012 Save Compatibility & Recovery UX Test Suite FAILED with %d errors ---" % _failures)
		quit(1)
