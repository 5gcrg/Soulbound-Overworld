extends SceneTree

## SBL-REV-003 Profile Activation & Distinct New Journey Test Suite
## Requirements: GDD-015, GDD-098, FR-SAV-001, FR-WLD-001/002, TC-SAV-001/002, TC-WLD-001, TC-DIM-001.
## AGENTS.md Persistence Invariants.

const GameRootScene: PackedScene = preload("res://scenes/main/game_root.tscn")
const TitleScreenScene: PackedScene = preload("res://scenes/ui/title_screen.tscn")

var _failures: int = 0
var _test_root: String = ""

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("ACTIVATION TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-REV-003 Profile Activation & Distinct New Journey Test Suite ---")

	_test_root = "user://test_activation_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store := ProfileStore.new(_test_root)

	# ==========================================================================
	# Part 1: Distinct New Journey Empty-Slot Picker (Empty vs Occupied vs Corrupt)
	# ==========================================================================
	# Seed Profile 1: Valid existing save (Level 3, Chapter 2)
	var p1 := store.new_profile("profile_01")
	var cs := CharacterStats.new()
	cs.level = 3
	cs.xp = 100
	cs.vitality = 12
	cs.resonance = 12
	cs.agility = 10
	cs.focus = 10
	p1["character"] = cs.serialize()

	var inv := InventoryManager.new()
	inv.add_banked_item("iron_sword", 1)
	p1["inventory"] = inv.serialize()

	var cm := ChapterManager.new()
	cm.current_chapter = 2
	cm.unlocked_chapters = [1, 2]
	p1["world"]["chapter_progress"] = cm.serialize()

	var ac := AssessmentController.new()
	var q_def := QuestionBank.get_question("q_dec_01")
	ac.submit_answer("q_dec_01", int(q_def.get("correct_index", 0)))
	p1["education"] = ac.serialize()
	_check(store.save_profile("profile_01", p1) == OK, "Saved valid profile_01 to test store")

	# Seed Profile 2: Intentionally corrupted JSON file on disk
	var p2_dir: String = ProjectSettings.globalize_path("%s/profile_02" % _test_root)
	DirAccess.make_dir_recursive_absolute(p2_dir)
	var corrupt_file := FileAccess.open("%s/profile.0000000000000001.00001.000001.json" % p2_dir, FileAccess.WRITE)
	corrupt_file.store_string("{corrupted_json_syntax: true")
	corrupt_file.close()

	# Profile 3: Genuinely empty (no files)

	var title: TitleScreen = TitleScreenScene.instantiate() as TitleScreen
	root.add_child(title)
	await process_frame

	title.setup_profiles(store, "profile_01")
	await process_frame

	_check(title.main_menu.visible == true, "Title main menu visible initially")
	_check(title.new_game_menu.visible == false, "New game menu hidden initially")

	# Click Start New Journey
	title.new_game_btn.pressed.emit()
	await process_frame

	_check(title.main_menu.visible == false, "Main menu hidden when new-game picker opens")
	_check(title.new_game_menu.visible == true, "New game empty-slot picker visible")

	# Check slot states in New Game Picker
	_check(title.new_slot1_btn.disabled == true, "Slot 1 (occupied) is disabled in new-game picker")
	_check(title.new_slot1_btn.text.contains("Occupied"), "Slot 1 labeled as Occupied")
	_check(title.new_slot1_btn.focus_mode == Control.FOCUS_NONE, "Slot 1 has FOCUS_NONE")

	_check(title.new_slot2_btn.disabled == true, "Slot 2 (corrupt file on disk) is disabled in new-game picker")
	_check(title.new_slot2_btn.text.contains("Occupied") or title.new_slot2_btn.text.contains("Corrupted"), "Slot 2 not presented as empty")

	_check(title.new_slot3_btn.disabled == false, "Slot 3 (genuinely empty) is enabled in new-game picker")
	_check(title.new_slot3_btn.text.contains("Empty Slot"), "Slot 3 labeled as Empty Slot")
	_check(title.new_slot3_btn.has_focus() == true, "First empty slot button (Slot 3) has focus")

	# Test Back button from New Game Picker
	title.back_from_new_game_btn.pressed.emit()
	await process_frame

	_check(title.new_game_menu.visible == false, "New game menu hidden after Back")
	_check(title.main_menu.visible == true, "Main menu restored after Back")
	_check(title.new_game_btn.has_focus() == true, "Focus returned to initiating NewGameBtn")

	# ==========================================================================
	# Part 2: All Slots Occupied/Unavailable Scenario
	# ==========================================================================
	# Seed Profile 3 so no empty slots remain
	var p3 := store.new_profile("profile_03")
	_check(store.save_profile("profile_03", p3) == OK, "Saved profile_03 to test store")

	title.new_game_btn.pressed.emit()
	await process_frame

	_check(title.no_empty_slots_label.visible == true, "No empty slots label visible when all slots occupied")
	_check(title.new_slot1_btn.disabled == true, "Slot 1 disabled")
	_check(title.new_slot2_btn.disabled == true, "Slot 2 disabled")
	_check(title.new_slot3_btn.disabled == true, "Slot 3 disabled")
	_check(title.back_from_new_game_btn.has_focus() == true, "Back button focused when no slots available")

	title.back_from_new_game_btn.pressed.emit()
	await process_frame
	_check(title.main_menu.visible == true, "Main menu restored safely")

	# ==========================================================================
	# Part 3: Profile Selection does NOT automatically start gameplay (Finding 3/4)
	# ==========================================================================
	var started_slots: Array[String] = []
	title.continue_requested.connect(func(s: String): started_slots.append("continue:" + s))
	title.new_journey_requested.connect(func(s: String): started_slots.append("new:" + s))

	title.select_profile_btn.pressed.emit()
	await process_frame
	_check(title.profile_menu.visible == true, "Profile selector opened")

	# Click Slot 1
	title.slot1_btn.pressed.emit()
	await process_frame

	_check(title.profile_menu.visible == false, "Profile menu closed after slot selection")
	_check(title.main_menu.visible == true, "Main menu visible after slot selection")
	_check(title.current_slot == "profile_01", "Selected slot updated to profile_01")
	_check(started_slots.is_empty(), "Selecting profile did NOT emit start/continue signal")
	_check(title.continue_btn.has_focus() == true, "Continue button focused after slot selection")

	# ==========================================================================
	# Part 4: Continue on Empty Slot Redirects to New Game Picker
	# ==========================================================================
	# Delete profile_03 from store
	_cleanup_dir("%s/profile_03" % _test_root)
	title._refresh_profile_labels()
	title.current_slot = "profile_03"

	title.continue_btn.pressed.emit()
	await process_frame

	_check(started_slots.is_empty(), "Continue on empty slot did NOT emit continue signal")
	_check(title.new_game_menu.visible == true, "Continue on empty slot directed player to new-game picker")

	title.queue_free()
	await process_frame

	# ==========================================================================
	# Part 5: Full GameRoot Profile Activation & State Isolation (Finding 4)
	# ==========================================================================
	var game_root: Control = GameRootScene.instantiate() as Control
	game_root.profile_store = store
	root.add_child(game_root)
	await process_frame
	await process_frame

	# Activate Profile 1 (late game state)
	var act1_err: Error = game_root.activate_profile("profile_01", false)
	_check(act1_err == OK, "Activated profile_01 on GameRoot")
	_check(game_root._profile_slot == "profile_01", "Active slot is profile_01")
	_check(game_root.chapter_manager.current_chapter == 2, "Profile 1 has Chapter 2")
	_check(game_root.world_router.is_region_available("whispering_grove") == true, "Chapter 2 region whispering_grove unlocked for profile_01")

	# Transition profile_01 to Spirit dimension and non-zero position & velocity
	game_root.dimension_manager.current_dimension = DimensionManager.Dimension.SPIRIT
	game_root._sync_dimension_state()
	game_root.player.global_position = Vector2(400, 300)
	game_root.player.velocity = Vector2(80, -40)

	# Store a suspended expedition snapshot in profile_01
	var snap := {
		"is_active": true,
		"seed": 9876,
		"room_count": 6,
		"current_step": 3,
		"expedition_path": [0, 1, 2, 3, 4, 5],
		"satchel_items": {"ancient_relic_fragment": 3}
	}
	p1["world"]["active_expedition"] = snap
	_check(store.save_profile("profile_01", p1) == OK, "Saved profile_01 with active_expedition snapshot")
	game_root._suspended_expedition = snap.duplicate(true)

	_check(game_root.dimension_manager.current_dimension == DimensionManager.Dimension.SPIRIT, "Player currently in Spirit dimension")
	_check(game_root.player.velocity != Vector2.ZERO, "Player has non-zero velocity")
	_check(not game_root._suspended_expedition.is_empty(), "GameRoot holds active snapshot for profile_01")

	# Open Title Screen on GameRoot
	game_root.open_title_screen()
	await process_frame
	_check(game_root._title_screen != null, "TitleScreen opened on GameRoot")

	# Start New Journey into empty Slot 3 via Title Screen UI
	var gr_title: TitleScreen = game_root._title_screen
	gr_title.new_game_btn.pressed.emit()
	await process_frame
	_check(gr_title.new_game_menu.visible == true, "New game menu opened on TitleScreen")

	gr_title.new_slot3_btn.pressed.emit()
	await process_frame
	await process_frame

	# Verify Title Screen dismissed after successful new journey creation
	_check(game_root._title_screen == null, "TitleScreen dismissed after new journey activated")

	# Verify active profile is profile_03
	_check(game_root._profile_slot == "profile_03", "Active profile slot is now profile_03")

	# Verify reset to DEFAULT_START_REGION (test_region_alpha) and physical dimension
	_check(game_root._current_region_id == game_root.DEFAULT_START_REGION, "World reset to DEFAULT_START_REGION (test_region_alpha)")
	_check(game_root.world_router.active_region_id == game_root.DEFAULT_START_REGION, "WorldRouter active region is test_region_alpha")
	_check(game_root.dimension_manager.current_dimension == DimensionManager.Dimension.PHYSICAL, "Dimension cleanly reset to PHYSICAL")
	_check(game_root.player.velocity == Vector2.ZERO, "Player velocity zeroed after profile activation")

	# Verify Chapter 1 progression and locked gates for profile_03
	_check(game_root.chapter_manager.current_chapter == 1, "New profile has Chapter 1")
	_check(game_root.world_router.is_region_available("whispering_grove") == false, "Chapter 2 region whispering_grove locked for new profile")

	# Verify profile_01's suspended expedition was NOT leaked into profile_03
	_check(game_root._suspended_expedition.is_empty() == true, "Profile 1's suspended expedition snapshot cleared in Profile 3")
	var p3_disk: Dictionary = store.load_profile("profile_03").get("profile", {})
	_check(p3_disk.get("world", {}).has("active_expedition") == false, "Profile 3 on disk has no active_expedition snapshot")

	# ==========================================================================
	# Part 6: Activation Failure Safety & Invariant Preservation
	# ==========================================================================
	# 1. Attempt to activate profile during combat encounter
	game_root._battle = Control.new()
	var busy_err: Error = game_root.activate_profile("profile_01", false)
	_check(busy_err == ERR_BUSY, "activate_profile rejected with ERR_BUSY during active combat")
	game_root._battle.queue_free()
	game_root._battle = null

	# 2. Corrupt slot activation from Title Screen: TitleScreen remains open, error shown
	game_root.open_title_screen()
	await process_frame

	game_root._on_title_continue_requested("profile_02") # profile_02 has corrupt JSON on disk
	await process_frame

	_check(game_root._title_screen != null, "TitleScreen remains open after corrupt profile activation rejected")
	_check(game_root._title_screen.error_box.visible == true, "Error message shown on TitleScreen")
	_check(game_root._title_screen.error_label.text.contains("Cannot load profile"), "Error label explains load failure")
	_check(game_root._profile_slot == "profile_03", "Active profile slot remained profile_03 (prior profile untouched)")

	# Close title screen before Part 7
	game_root._close_title_screen()
	await process_frame

	# ==========================================================================
	# Part 7: SBL-REV-003-FIX Defense Demo Activates Title-Selected Profile (Finding 1)
	# ==========================================================================
	# 1. Activate profile_01 as current active gameplay profile
	var act_p1_err: Error = game_root.activate_profile("profile_01", false)
	_check(act_p1_err == OK, "Activated profile_01 as baseline gameplay profile")
	_check(game_root._profile_slot == "profile_01", "Active profile slot is profile_01")
	var p1_pre_text: String = store.export_backup("profile_01").get("text", "")
	_check(not p1_pre_text.is_empty(), "Exported baseline profile_01 text")

	# 2. Seed profile_02 with a valid, clean profile (replaces corrupted test revision)
	var p2_clean := store.new_profile("profile_02")
	var cs2 := CharacterStats.new()
	cs2.level = 1
	cs2.vitality = 10
	cs2.resonance = 10
	cs2.agility = 10
	cs2.focus = 10
	p2_clean["character"] = cs2.serialize()
	var inv2 := InventoryManager.new()
	inv2.add_banked_item("wooden_staff", 1)
	p2_clean["inventory"] = inv2.serialize()
	var cm2 := ChapterManager.new()
	cm2.current_chapter = 1
	cm2.unlocked_chapters = [1]
	p2_clean["world"]["chapter_progress"] = cm2.serialize()
	p2_clean["education"] = {"records": {}}
	_check(store.save_profile("profile_02", p2_clean) == OK, "Saved clean profile_02 into store")
	var p2_pre_text: String = store.export_backup("profile_02").get("text", "")
	_check(not p2_pre_text.is_empty(), "Exported baseline profile_02 text")

	# 3. Open Title Screen on GameRoot while gameplay profile_01 is loaded
	game_root.open_title_screen()
	await process_frame
	var gr_title2: TitleScreen = game_root._title_screen
	_check(gr_title2 != null, "TitleScreen opened while profile_01 active")
	_check(gr_title2.current_slot == "profile_01", "TitleScreen initialized with active slot profile_01")

	# 4. Select profile_02 on Title Screen (non-launching selection)
	gr_title2._select_slot("profile_02")
	await process_frame
	_check(gr_title2.current_slot == "profile_02", "TitleScreen selected slot updated to profile_02")
	_check(game_root._profile_slot == "profile_01", "GameRoot active profile slot remains profile_01 before demo launch")

	# 5. Activate Defense Demo from Title Screen
	gr_title2.defense_btn.pressed.emit()
	await process_frame
	await process_frame

	# 6. Assert TitleScreen dismissed and profile_02 is the active/modified profile
	_check(game_root._title_screen == null, "TitleScreen dismissed after defense demo activated")
	_check(game_root._profile_slot == "profile_02", "Defense demo activated selected slot profile_02 (not stale profile_01)")
	_check(game_root.character_stats.level == 10, "In-memory Ren level updated to 10 for profile_02")
	_check(game_root.chapter_manager.current_chapter == ChapterManager.CHAPTER_3, "In-memory chapter updated to Chapter 3")
	_check(game_root.inventory_manager.banked_items.get("spirit_salve", 0) >= 5, "In-memory inventory received spirit salves")

	# 7. Assert profile_02 on disk received the defense demo mutations
	var p2_post_data: Dictionary = store.load_profile("profile_02").get("profile", {})
	_check(int(p2_post_data.get("character", {}).get("level", 0)) == 10, "Disk profile_02 level updated to 10")
	_check(int(p2_post_data.get("world", {}).get("chapter_progress", {}).get("current_chapter", 0)) == 3, "Disk profile_02 chapter updated to 3")
	_check(int(p2_post_data.get("inventory", {}).get("banked", {}).get("spirit_salve", 0)) >= 5, "Disk profile_02 received spirit salves")
	_check(p2_post_data.get("education", {}).get("records", {}).is_empty() == false, "Disk profile_02 education records populated")

	# 8. Assert profile_01 on disk is completely unchanged (byte-identical)
	var p1_post_text: String = store.export_backup("profile_01").get("text", "")
	_check(p1_post_text == p1_pre_text, "Profile 1 on disk is byte-identical to pre-demo state (no mutation)")
	var p1_post_data: Dictionary = store.load_profile("profile_01").get("profile", {})
	_check(int(p1_post_data.get("character", {}).get("level", 0)) == 3, "Profile 1 character level unchanged (3)")
	_check(int(p1_post_data.get("world", {}).get("chapter_progress", {}).get("current_chapter", 0)) == 2, "Profile 1 chapter progress unchanged (2)")
	_check(p1_post_data.get("inventory", {}).get("banked", {}).has("spirit_salve") == false, "Profile 1 did NOT receive demo items")
	_check(p1_post_data.get("education", {}).get("records", {}).has("q_dec_01") == true, "Profile 1 educational records intact")

	# ==========================================================================
	# Part 8: Failure-Path Test: Corrupt Profile Activation Leaves Title Visible & Files Untouched
	# ==========================================================================
	# Clean any existing files in profile_03 directory first, then seed corrupted JSON
	_cleanup_dir("%s/profile_03" % _test_root)
	var p3_dir: String = ProjectSettings.globalize_path("%s/profile_03" % _test_root)
	DirAccess.make_dir_recursive_absolute(p3_dir)
	var corrupt_p3 := FileAccess.open("%s/profile.0000000000000001.00003.000001.json" % p3_dir, FileAccess.WRITE)
	var corrupt_payload: String = "{broken_json_syntax: true"
	corrupt_p3.store_string(corrupt_payload)
	corrupt_p3.close()

	var p2_pre_fail_text: String = store.export_backup("profile_02").get("text", "")

	# Open Title Screen while profile_02 is active
	game_root.open_title_screen()
	await process_frame
	var gr_title3: TitleScreen = game_root._title_screen
	_check(gr_title3 != null, "TitleScreen opened for failure-path test")

	# Select corrupt profile_03
	gr_title3._select_slot("profile_03")
	await process_frame
	_check(gr_title3.current_slot == "profile_03", "TitleScreen selected slot updated to corrupt profile_03")

	# Click Defense Demo on corrupt slot
	gr_title3.defense_btn.pressed.emit()
	await process_frame
	await process_frame

	# Assertions for failure path: TitleScreen remains open, error shown, files untouched
	_check(game_root._title_screen != null, "TitleScreen remains open after corrupt profile defense demo rejected")
	if game_root._title_screen != null:
		_check(game_root._title_screen.error_box.visible == true, "TitleScreen error box visible on defense demo failure")
		_check(game_root._title_screen.error_label.text.contains("Cannot load profile"), "TitleScreen error label explains load failure")
	_check(game_root._profile_slot == "profile_02", "Active profile slot remained profile_02 (prior profile untouched)")

	# Profile 2 bytes unchanged
	var p2_post_fail_text: String = store.export_backup("profile_02").get("text", "")
	_check(p2_post_fail_text == p2_pre_fail_text, "Active profile_02 bytes unchanged after failed defense demo")

	# Profile 3 file still has raw corrupt payload
	var p3_check_file := FileAccess.open("%s/profile.0000000000000001.00003.000001.json" % p3_dir, FileAccess.READ)
	_check(p3_check_file != null, "Profile 3 file still exists")
	var p3_actual_payload: String = p3_check_file.get_as_text()
	p3_check_file.close()
	_check(p3_actual_payload == corrupt_payload, "Corrupted profile_03 file untouched on disk")

	# Clean up
	game_root._close_title_screen()
	game_root.queue_free()
	await process_frame
	_cleanup_dir(_test_root)

	print("--- SBL-REV-003 Profile Activation Test Complete. Failures: %d ---" % _failures)
	if _failures == 0:
		print("ALL SBL-REV-003 ACTIVATION CHECKS PASSED (100% SUCCESS)")
		quit(0)
	else:
		printerr("ACTIVATION TESTS FAILED with %d error(s)" % _failures)
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
