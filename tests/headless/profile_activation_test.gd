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
