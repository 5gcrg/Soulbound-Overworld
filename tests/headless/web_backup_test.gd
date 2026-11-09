extends SceneTree

## SBL-M6-001 Web Save Backup & Export Verification Test Suite
## Requirements: GDD-098/099/100/101/102, FR-SAV-001, AGENTS.md Invariants ("provide local web backup export/import").

const SettingsSheetScene: PackedScene = preload("res://scenes/ui/settings_sheet.tscn")

var _failures: int = 0
var _test_root: String = ""

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("WEB BACKUP TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-M6-001 Web Save Backup & Export Test Suite ---")

	_test_root = "user://test_web_backup_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store := ProfileStore.new(_test_root)

	# ==========================================================================
	# Step 1: Create and Populate Source Profile (profile_01)
	# ==========================================================================
	var profile: Dictionary = store.new_profile("profile_01")
	profile["character"] = {
		"level": 3,
		"xp": 150,
		"vitality": 12,
		"resonance": 14,
		"agility": 10,
		"focus": 11,
		"unspent_points": 1
	}
	profile["inventory"] = {
		"banked_items": {"ancient_relic_fragment": 5, "iron_sword": 1},
		"satchel_items": {},
		"equipment": {"weapon": "iron_sword", "armor": "", "relic_1": "", "relic_2": ""}
	}
	profile["world"] = {
		"chapter_progress": {"current_chapter": 2, "is_academic_complete": false, "unlocked_chapters": [1, 2]}
	}
	profile["education"] = {
		"records": {
			"q_dec_01": {"competency": "Decision-Making", "completed": true, "first_attempt_correct": true, "total_attempts": 1}
		}
	}

	var save_err: Error = store.save_profile("profile_01", profile)
	_check(save_err == OK, "Saved initial source profile_01 to ProfileStore")

	# ==========================================================================
	# Step 2: Export Backup String (AGENTS.md Web Backup Invariant)
	# ==========================================================================
	var export_res: Dictionary = store.export_backup("profile_01")
	_check(export_res.get("error", ERR_UNCONFIGURED) == OK, "export_backup returned OK")
	var backup_str: String = export_res.get("text", "")
	_check(not backup_str.is_empty(), "Exported backup string is non-empty")
	_check(backup_str.contains("profile_01"), "Backup string contains profile identifier")
	_check(backup_str.contains("ancient_relic_fragment"), "Backup string contains inventory contents")
	_check(backup_str.contains("Decision-Making"), "Backup string contains educational records")

	# ==========================================================================
	# Step 3: Import Backup String into a Fresh Slot (profile_02)
	# ==========================================================================
	# Profile 02 must have profile_02 identifier in envelope
	var profile_02_backup: String = backup_str.replace('"profile_01"', '"profile_02"')
	var import_err: Error = store.import_backup("profile_02", profile_02_backup)
	_check(import_err == OK, "import_backup into profile_02 succeeded with exit OK")

	var loaded_p2: Dictionary = store.load_profile("profile_02")
	_check(loaded_p2.get("error", ERR_UNCONFIGURED) == OK, "Loaded imported profile_02 successfully")
	var p2_data: Dictionary = loaded_p2.get("profile", {})
	_check(p2_data.get("profile_id", "") == "profile_02", "Imported profile has correct profile_id")
	_check(int(p2_data["character"]["level"]) == 3, "Imported character level preserved (3)")
	_check(int(p2_data["inventory"]["banked_items"]["ancient_relic_fragment"]) == 5, "Imported inventory banked items preserved (5)")
	_check(p2_data["education"]["records"]["q_dec_01"]["completed"] == true, "Imported educational completion preserved")

	# ==========================================================================
	# Step 4: Robust Rejection of Malformed / Corrupted Backup Strings
	# ==========================================================================
	var err_corrupt_json: Error = store.import_backup("profile_03", "{malformed_not_json:")
	_check(err_corrupt_json != OK, "Malformed JSON string rejected")

	var err_empty: Error = store.import_backup("profile_03", "")
	_check(err_empty != OK, "Empty string rejected")

	var err_wrong_schema: String = profile_02_backup.replace('"schema_version": 1', '"schema_version": 999')
	var err_schema_res: Error = store.import_backup("profile_03", err_wrong_schema)
	_check(err_schema_res != OK, "Unsupported schema version rejected")

	# Verify profile_03 was never created/corrupted
	var p3_load: Dictionary = store.load_profile("profile_03")
	_check(p3_load.get("error", OK) == ERR_FILE_NOT_FOUND, "Slot profile_03 remains clean and uncorrupted")

	# ==========================================================================
	# Step 5: SettingsSheet UI Web Backup Interaction
	# ==========================================================================
	var sheet: SettingsSheet = SettingsSheetScene.instantiate() as SettingsSheet
	root.add_child(sheet)
	await process_frame

	sheet.set_profile_context(store, "profile_01")
	await process_frame

	_check(sheet.export_backup_btn != null, "Export Backup button found in SettingsSheet")
	_check(sheet.import_backup_btn != null, "Import Backup button found in SettingsSheet")

	# Simulate Export Button Click
	sheet._on_export_backup_pressed()
	await process_frame
	var export_text: String = sheet.last_exported_backup
	_check(not export_text.is_empty(), "Export button populated backup string")
	_check(sheet.backup_status_label.text.contains("Profile backup copied to clipboard"), "Status label shows copy confirmation")

	# Simulate Import Button Click
	sheet.active_profile_id = "profile_02"
	# sheet.last_exported_backup currently holds profile_01 data, so import to profile_02 should reject mismatched profile_id
	sheet._on_import_backup_pressed()
	await process_frame
	_check(sheet.backup_status_label.text.contains("Import failed"), "Mismatched profile ID import rejected with error feedback")

	sheet.queue_free()
	await process_frame

	# Clean up temporary test profiles
	_cleanup_dir(_test_root)

	# Web CSV buffer generation test
	var ac := AssessmentController.new()
	ac.submit_answer("q_dec_01", 0)
	var csv_text: String = ac.generate_csv_text()
	_check(csv_text.begins_with("question_id,competency,difficulty,first_attempt_correct,total_attempts,completed,timestamp"), "generate_csv_text has valid RFC-4180 header")
	_check(csv_text.contains("q_dec_01"), "generate_csv_text includes question record")
	var web_buffer: PackedByteArray = csv_text.to_utf8_buffer()
	_check(web_buffer.size() > 0, "Web CSV buffer successfully created for JavaScriptBridge.download_buffer")

	await _test_live_restore()

	print("--- Web Save Backup & Export Verification Complete. Failures: %d ---" % _failures)
	if _failures == 0:
		print("ALL WEB BACKUP & EXPORT CHECKS PASSED (100% SUCCESS)")
		quit(0)
	else:
		printerr("WEB BACKUP TESTS FAILED with %d error(s)" % _failures)
		quit(1)

func _cleanup_dir(path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(global_path):
		var dir := DirAccess.open(global_path)
		if dir != null:
			for sub in dir.get_directories():
				var sub_dir := DirAccess.open(global_path + "/" + sub)
				if sub_dir != null:
					for f in sub_dir.get_files():
						sub_dir.remove(f)
					dir.remove(sub)
			for f in dir.get_files():
				dir.remove(f)
		DirAccess.remove_absolute(global_path)

func _test_live_restore() -> void:
	var fixture_root := "user://test_gr_backup_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store := ProfileStore.new(fixture_root)
	_check(store.save_profile("profile_01", store.new_profile("profile_01")) == OK, "seed independent slot")
	var slot_one_text: String = store.export_backup("profile_01")["text"]
	var baseline := store.new_profile("profile_02")
	_check(store.save_profile("profile_02", baseline) == OK, "seed baseline")
	var original: String = store.export_backup("profile_02")["text"]
	var game = preload("res://scenes/main/game_root.tscn").instantiate()
	game.profile_store = store
	root.add_child(game)
	game._init_slice_progress(store, "profile_02")
	game._toggle_settings_sheet()
	var sheet: SettingsSheet = game._settings_sheet
	var malformed := baseline.duplicate(true)
	malformed["education"]["records"] = {"q_dec_01": null}
	sheet.last_exported_backup = JSON.stringify(malformed)
	sheet.import_backup_btn.pressed.emit()
	_check(sheet.backup_status_label.text.contains("Import failed"), "invalid nested record rejected")
	_check(store.export_backup("profile_02")["text"] == original, "rejected import preserves active revision")
	var good := baseline.duplicate(true)
	var inventory := InventoryManager.new()
	inventory.add_banked_item("iron_sword", 1)
	good["inventory"] = inventory.serialize()
	sheet.last_exported_backup = JSON.stringify(good)
	sheet.import_backup_btn.pressed.emit()
	_check(game.inventory_manager.banked_items.get("iron_sword", 0) == 1, "successful import activates restored inventory")
	game._close_settings_sheet()
	_check(game.slice_progress.accept_quest() == OK, "quest checkpoint after restore succeeds")
	_check(store.load_profile("profile_02")["profile"]["inventory"].get("banked", {}).get("iron_sword", 0) == 1, "quest save preserves restored gear")
	game._toggle_inventory_sheet()
	game._close_inventory_sheet()
	_check(store.export_backup("profile_01")["text"] == slot_one_text, "slot 2 gameplay writes leave slot 1 unchanged")
	game.queue_free()
	await process_frame
	_cleanup_dir(fixture_root)
