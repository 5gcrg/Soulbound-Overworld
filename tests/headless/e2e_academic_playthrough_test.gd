extends SceneTree

## SBL-M5-001 End-to-End Full Academic Playthrough QA Test Suite
## Requirements: GDD-001 through GDD-132, M1-M4 Integration, AGENTS.md Invariants.

const GameRootScene: PackedScene = preload("res://scenes/main/game_root.tscn")

var _failures: int = 0
var _test_root: String = ""

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("E2E PLAYTHROUGH TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-M5-001 End-to-End Academic Playthrough QA Test ---")

	_test_root = "user://test_e2e_profiles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var test_store: ProfileStore = ProfileStore.new(_test_root)

	var game_root: Control = GameRootScene.instantiate() as Control
	game_root.profile_store = test_store
	root.add_child(game_root)
	game_root._init_slice_progress(test_store, "profile_01")

	await process_frame
	await process_frame

	var player: PlayerCharacter = game_root.player
	var router: WorldRouter = game_root.world_router
	var ch_mgr: ChapterManager = game_root.chapter_manager
	var assessment: AssessmentController = game_root.assessment_controller
	var inv: InventoryManager = game_root.inventory_manager
	var stats: CharacterStats = game_root.character_stats

	_check(player != null, "Player instantiated")
	_check(router != null, "WorldRouter initialized")
	_check(router.active_region_id == "test_region_alpha", "Initial region is Alpha")

	# ==========================================================================
	# Step 1: Transition to Chapter I: Dawnreach Village
	# ==========================================================================
	var portal_to_village: RegionPortal = router.active_region.portals_container.get_node_or_null("PortalToVillage") as RegionPortal
	_check(portal_to_village != null, "PortalToVillage found in Alpha")
	router.request_transition(portal_to_village, "dawnreach_village", "from_alpha")
	await process_frame
	await process_frame

	_check(router.active_region_id == "dawnreach_village", "Arrived at Chapter I: Dawnreach Village")
	_check(ch_mgr.current_chapter == ChapterManager.CHAPTER_1, "Chapter I active")

	# Complete Chapter I learning activity: wrong first attempt, then correct retry
	var q1: Dictionary = QuestionBank.get_question("q_dec_01")
	var wrong_ans: int = (int(q1["correct_index"]) + 1) % 4
	assessment.submit_answer("q_dec_01", wrong_ans)
	_check(assessment.records["q_dec_01"]["first_attempt_correct"] == false, "Ch 1 first attempt recorded as false")

	# Retry with correct answer -> completion-gated progression
	assessment.submit_answer("q_dec_01", int(q1["correct_index"]))
	_check(assessment.is_chapter_activity_completed(1), "Ch 1 activity completed upon retry")
	var ch1_advance: bool = ch_mgr.try_advance_chapter(assessment)
	_check(ch1_advance, "Advanced from Chapter I to Chapter II")

	# ==========================================================================
	# Step 2: Transition to Chapter II: Whispering Grove & Dimension Puzzle
	# ==========================================================================
	var portal_to_grove: RegionPortal = router.active_region.portals_container.get_node_or_null("PortalToGrove") as RegionPortal
	_check(portal_to_grove != null, "PortalToGrove found in Village")
	router.request_transition(portal_to_grove, "whispering_grove", "from_village")
	await process_frame
	await process_frame

	_check(router.active_region_id == "whispering_grove", "Arrived at Chapter II: Whispering Grove")
	var bramble: Node2D = router.active_region.get_node_or_null("Obstacles/PhysicalBrambleWall") as Node2D
	_check(bramble != null, "Physical bramble obstacle present")
	_check(bramble.visible == true, "Bramble visible in physical plane")

	# Shift to Spirit Dimension (Q) to dissolve physical brambles
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state if player.get_world_2d() != null else null
	var shift_err: Error = game_root.dimension_manager.request_shift(player, space)
	_check(shift_err == OK, "Dimension shifted successfully")
	game_root.dimension_manager.apply_dimension_to_region(router.active_region)
	_check(bramble.visible == false, "Physical brambles dissolved in Spirit Dimension")

	# Complete Chapter II learning activity
	var q2: Dictionary = QuestionBank.get_question("q_res_01")
	assessment.submit_answer("q_res_01", int(q2["correct_index"]))
	_check(assessment.is_chapter_activity_completed(2), "Ch 2 activity completed")
	var ch2_advance: bool = ch_mgr.try_advance_chapter(assessment)
	_check(ch2_advance, "Advanced from Chapter II to Chapter III")

	# ==========================================================================
	# Step 3: Transition to Chapter III: Forgotten Shrine & Academic Completion
	# ==========================================================================
	var portal_to_shrine: RegionPortal = router.active_region.portals_container.get_node_or_null("PortalToShrine") as RegionPortal
	_check(portal_to_shrine != null, "PortalToShrine found in Grove")
	router.request_transition(portal_to_shrine, "forgotten_shrine", "from_grove")
	await process_frame
	await process_frame

	_check(router.active_region_id == "forgotten_shrine", "Arrived at Chapter III: Forgotten Shrine")

	# Complete Chapter III learning activity
	var q3: Dictionary = QuestionBank.get_question("q_crit_02")
	assessment.submit_answer("q_crit_02", int(q3["correct_index"]))
	_check(assessment.is_chapter_activity_completed(3), "Ch 3 activity completed")
	var ch3_advance: bool = ch_mgr.try_advance_chapter(assessment)
	_check(ch3_advance, "Achieved Academic MVP Completion")
	_check(ch_mgr.is_academic_complete, "ChapterManager marked academic complete")

	# Step onto Academic Portal
	var acad_portal: Area2D = router.active_region.get_node_or_null("AcademicPortal") as Area2D
	_check(acad_portal != null, "Academic Portal present in Shrine")
	acad_portal.body_entered.emit(player)
	await process_frame

	_check(game_root._academic_modal != null, "Academic Completion Modal displayed")
	_check(player.input_frozen, "Player frozen while reading completion modal")

	# Export report and continue free exploration
	var modal: AcademicCompletionModal = game_root._academic_modal
	modal.export_btn.pressed.emit()
	await process_frame
	_check(FileAccess.file_exists("user://reports/soulbound_academic_mvp_report.csv"), "RFC-4180 CSV report generated")

	modal.close_btn.pressed.emit()
	await process_frame
	_check(game_root._academic_modal == null, "Academic modal closed")
	_check(player.input_frozen == false, "Player restored to free exploration")

	# ==========================================================================
	# Step 4: Return to Alpha via Story Portals & Enter Dungeon Gateway
	# ==========================================================================
	# Forgotten Shrine -> Whispering Grove
	var p_shrine_to_grove: RegionPortal = router.active_region.portals_container.get_node_or_null("PortalToGrove") as RegionPortal
	_check(p_shrine_to_grove != null, "PortalToGrove found in Shrine")
	router.request_transition(p_shrine_to_grove, "whispering_grove", "from_shrine")
	await process_frame
	await process_frame
	_check(router.active_region_id == "whispering_grove", "Returned to Whispering Grove")

	# Whispering Grove -> Dawnreach Village
	var p_grove_to_village: RegionPortal = router.active_region.portals_container.get_node_or_null("PortalToVillage") as RegionPortal
	_check(p_grove_to_village != null, "PortalToVillage found in Grove")
	router.request_transition(p_grove_to_village, "dawnreach_village", "from_grove")
	await process_frame
	await process_frame
	_check(router.active_region_id == "dawnreach_village", "Returned to Dawnreach Village")

	# Dawnreach Village -> Test Region Alpha
	var p_village_to_alpha: RegionPortal = router.active_region.portals_container.get_node_or_null("PortalToAlpha") as RegionPortal
	_check(p_village_to_alpha != null, "PortalToAlpha found in Village")
	router.request_transition(p_village_to_alpha, "test_region_alpha", "default")
	await process_frame
	await process_frame
	_check(router.active_region_id == "test_region_alpha", "Returned to Alpha")

	var gateway: Area2D = router.active_region.get_node_or_null("ExpeditionGateway") as Area2D
	_check(gateway != null, "ExpeditionGateway present in Alpha")
	gateway.body_entered.emit(player)
	await process_frame

	_check(game_root._expedition != null, "DungeonExpedition modal opened")
	_check(player.input_frozen, "Player frozen while in dungeon modal")

	var expedition: DungeonExpedition = game_root._expedition
	_check(expedition.current_step == 0, "Dungeon starts at chamber step 0")

	# Advance 2 chambers, gathering loot into satchel automatically
	expedition._on_advance_pressed()
	await process_frame
	expedition._on_advance_pressed()
	await process_frame
	_check(expedition.current_step == 2, "Navigated to chamber step 2")
	_check(inv.satchel_items.get("ancient_relic_fragment", 0) >= 1, "Ancient relic fragment gathered in expedition satchel")

	# Extract at portal
	expedition._on_extract_pressed()
	await process_frame

	_check(game_root._expedition == null, "Dungeon expedition modal closed upon extraction")
	_check(player.input_frozen == false, "Player unfrozen after extraction")
	_check(player.position == Vector2(600, 220), "Player positioned safely outside gateway")
	_check(inv.satchel_items.is_empty(), "Satchel cleared after successful extraction")
	_check(inv.banked_items.get("ancient_relic_fragment", 0) >= 1, "Satchel loot safely secured into town bank")

	# ==========================================================================
	# Step 5: Character & Settings Modifications
	# ==========================================================================
	var init_vit: int = stats.vitality
	stats.unspent_points += 1
	var allocated: bool = stats.allocate_point(CharacterStats.ATTR_VITALITY)
	_check(allocated, "Point allocated to Vitality")
	_check(stats.vitality == init_vit + 1, "Vitality incremented by 1")

	game_root.settings_manager.set_master_volume(0.75)
	game_root.settings_manager.set_reduced_motion(true)
	game_root.settings_manager.save_settings()

	# Save full profile
	ch_mgr.save_to_store(test_store, "profile_01")
	inv.save_to_store(test_store, "profile_01")
	stats.save_to_store(test_store, "profile_01")
	assessment.save_to_store(test_store, "profile_01")

	# ==========================================================================
	# Step 6: Full Reload & Persistence Verification
	# ==========================================================================
	var verify_store := ProfileStore.new(_test_root)
	var reloaded_ch := ChapterManager.new()
	var reloaded_inv := InventoryManager.new()
	var reloaded_stats := CharacterStats.new()
	var reloaded_assess := AssessmentController.new()

	_check(reloaded_ch.load_from_store(verify_store, "profile_01") == OK, "Loaded ChapterManager")
	_check(reloaded_inv.load_from_store(verify_store, "profile_01") == OK, "Loaded InventoryManager")
	_check(reloaded_stats.load_from_store(verify_store, "profile_01") == OK, "Loaded CharacterStats")
	_check(reloaded_assess.load_from_store(verify_store, "profile_01") == OK, "Loaded AssessmentController")

	_check(reloaded_ch.is_academic_complete, "Reloaded: Academic MVP Complete verified")
	_check(reloaded_inv.banked_items.get("ancient_relic_fragment", 0) >= 1, "Reloaded: Secured bank items verified")
	_check(reloaded_stats.vitality == init_vit + 1, "Reloaded: Allocated Vitality attribute verified")
	_check(reloaded_assess.records["q_dec_01"]["first_attempt_correct"] == false, "Reloaded: Immutable first attempt preserved")
	_check(reloaded_assess.is_chapter_activity_completed(1), "Reloaded: Ch 1 completed")
	_check(reloaded_assess.is_chapter_activity_completed(2), "Reloaded: Ch 2 completed")
	_check(reloaded_assess.is_chapter_activity_completed(3), "Reloaded: Ch 3 completed")

	game_root.queue_free()

	# Clean up temporary test files
	_cleanup_dir(_test_root)

	print("--- End-to-End Academic Playthrough QA Test Complete. Failures: %d ---" % _failures)
	if _failures == 0:
		print("ALL END-TO-END PLAYTHROUGH CHECKS PASSED (100% SUCCESS)")
		quit(0)
	else:
		printerr("E2E TEST FAILED with %d error(s)" % _failures)
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
