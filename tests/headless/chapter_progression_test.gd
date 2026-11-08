extends SceneTree

## SBL-W9-003 Three-Chapter Academic Progression & Completion Test Suite
## Requirements: GDD-041/063/070/116, FR-WLD-001, FR-EDU-003/004, AGENTS.md Invariants.

const GameRootScene: PackedScene = preload("res://scenes/main/game_root.tscn")

var _failures: int = 0
var _test_root: String = ""

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("CHAPTER PROGRESSION TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W9-003 Three-Chapter Academic Progression Test Suite ---")

	_test_root = "user://test_chapter_profiles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
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

	_check(player != null, "Player character instantiated")
	_check(router != null, "WorldRouter instantiated")
	_check(ch_mgr != null, "ChapterManager instantiated")

	# ==========================================================================
	# Part 1: Chapter Lifecycle & Educational Completion Gating (GDD-063 & FR-EDU-003)
	# ==========================================================================
	_check(ch_mgr.current_chapter == ChapterManager.CHAPTER_1, "Initial chapter is Chapter I: Dawnreach Village")
	_check(ch_mgr.can_advance_chapter(assessment) == false, "Chapter 1 advance blocked: required learning activity incomplete")

	# Attempt advance before completing activity -> must fail
	var advanced_early: bool = ch_mgr.try_advance_chapter(assessment)
	_check(advanced_early == false, "try_advance_chapter rejected when activity incomplete")

	# Complete Chapter 1 required activity with wrong first attempt (immutable record) then correct retry
	var q1: Dictionary = QuestionBank.get_question("q_dec_01")
	var wrong_idx: int = 0 if int(q1["correct_index"]) != 0 else 1
	assessment.submit_answer("q_dec_01", wrong_idx)
	_check(assessment.records["q_dec_01"]["first_attempt_correct"] == false, "Ch 1 first attempt recorded as false")

	# Complete upon retry (completion-gated, NOT score-gated!)
	assessment.submit_answer("q_dec_01", int(q1["correct_index"]))
	_check(assessment.is_chapter_activity_completed(1) == true, "Ch 1 activity completed upon retry")
	_check(ch_mgr.can_advance_chapter(assessment) == true, "Ch 1 advance unlocked by completion-gated rule!")

	# Advance to Chapter 2
	var adv1_ok: bool = ch_mgr.try_advance_chapter(assessment)
	_check(adv1_ok == true, "Successfully advanced to Chapter II: Whispering Grove")
	_check(ch_mgr.current_chapter == ChapterManager.CHAPTER_2, "Current chapter is Chapter 2")

	# Complete Chapter 2 required activity
	var q2: Dictionary = QuestionBank.get_question("q_res_01")
	assessment.submit_answer("q_res_01", int(q2["correct_index"]))
	_check(assessment.is_chapter_activity_completed(2) == true, "Ch 2 activity completed")

	# Advance to Chapter 3
	var adv2_ok: bool = ch_mgr.try_advance_chapter(assessment)
	_check(adv2_ok == true, "Successfully advanced to Chapter III: Forgotten Shrine")
	_check(ch_mgr.current_chapter == ChapterManager.CHAPTER_3, "Current chapter is Chapter 3")

	# Complete Chapter 3 required activity
	var q3: Dictionary = QuestionBank.get_question("q_crit_02")
	assessment.submit_answer("q_crit_02", int(q3["correct_index"]))
	_check(assessment.is_chapter_activity_completed(3) == true, "Ch 3 activity completed")

	# Advance to Academic MVP Completion (GDD-116: 3-chapter completion point)
	var adv3_ok: bool = ch_mgr.try_advance_chapter(assessment)
	_check(adv3_ok == true, "Successfully achieved Academic MVP Completion")
	_check(ch_mgr.is_academic_complete == true, "Academic MVP complete flag verified")

	# ==========================================================================
	# Part 2: Regional Transitions Across All 3 Story Chapters
	# ==========================================================================
	# Transition from Alpha to Dawnreach Village
	var portal_to_village: RegionPortal = router.active_region.portals_container.get_node_or_null("PortalToVillage") as RegionPortal
	_check(portal_to_village != null, "PortalToVillage found in Alpha")
	router.request_transition(portal_to_village, "dawnreach_village", "from_alpha")
	await process_frame
	await process_frame

	_check(router.active_region_id == "dawnreach_village", "Transitioned to Dawnreach Village")
	_check(router.active_region.get_node_or_null("ElderKael") != null, "Elder Kael present in Dawnreach Village")

	# Transition to Whispering Grove
	var portal_to_grove: RegionPortal = router.active_region.portals_container.get_node_or_null("PortalToGrove") as RegionPortal
	_check(portal_to_grove != null, "PortalToGrove found in Village")
	router.request_transition(portal_to_grove, "whispering_grove", "from_village")
	await process_frame
	await process_frame

	_check(router.active_region_id == "whispering_grove", "Transitioned to Whispering Grove")
	var phys_wall: Node2D = router.active_region.get_node_or_null("Obstacles/PhysicalBrambleWall") as Node2D
	_check(phys_wall != null, "Physical bramble wall obstacle present in grove")

	# Verify Dimension Shifting in Whispering Grove
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state if player.get_world_2d() != null else null
	var shift_err: Error = game_root.dimension_manager.request_shift(player, space)
	_check(shift_err == OK, "Shifted dimension in Whispering Grove")
	game_root.dimension_manager.apply_dimension_to_region(router.active_region)
	_check(phys_wall.visible == false, "Physical bramble wall hidden in Spirit Dimension")

	# Transition to Forgotten Shrine
	var portal_to_shrine: RegionPortal = router.active_region.portals_container.get_node_or_null("PortalToShrine") as RegionPortal
	_check(portal_to_shrine != null, "PortalToShrine found in Grove")
	router.request_transition(portal_to_shrine, "forgotten_shrine", "from_grove")
	await process_frame
	await process_frame

	_check(router.active_region_id == "forgotten_shrine", "Transitioned to Forgotten Shrine")
	var academic_portal: Area2D = router.active_region.get_node_or_null("AcademicPortal") as Area2D
	_check(academic_portal != null, "Academic Completion Portal present in Forgotten Shrine")

	# ==========================================================================
	# Part 3: Academic Completion Sanctum & Report Export
	# ==========================================================================
	academic_portal.body_entered.emit(player)
	await process_frame

	_check(game_root._academic_modal != null, "AcademicCompletionModal instantiated upon entering portal")
	_check(player.input_frozen == true, "Player frozen while viewing completion modal")

	var modal: AcademicCompletionModal = game_root._academic_modal
	var report_path: String = "user://reports/soulbound_academic_mvp_report.csv"

	# Click Export Report Button
	modal.export_btn.pressed.emit()
	await process_frame

	_check(FileAccess.file_exists(report_path), "Academic MVP RFC-4180 CSV report successfully exported to disk")

	# Verify exported report content
	var f := FileAccess.open(report_path, FileAccess.READ)
	_check(f != null, "Opened academic report for reading")
	if f != null:
		var header: String = f.get_line()
		_check(header.begins_with("question_id,competency"), "Header matches RFC-4180 format")
		var has_ch1: bool = false
		var has_ch2: bool = false
		var has_ch3: bool = false
		while not f.eof_reached():
			var line: String = f.get_line()
			if line.contains("q_dec_01"): has_ch1 = true
			if line.contains("q_res_01"): has_ch2 = true
			if line.contains("q_crit_02"): has_ch3 = true
		f.close()
		_check(has_ch1 and has_ch2 and has_ch3, "Exported CSV records activities from all 3 chapters!")

	# Clean up exported report file
	if FileAccess.file_exists(report_path):
		DirAccess.remove_absolute(report_path)

	# Click Continue Free Exploration
	modal.close_btn.pressed.emit()
	await process_frame

	_check(game_root._academic_modal == null, "Academic modal closed")
	_check(player.input_frozen == false, "Player unfrozen and free to explore!")

	# ==========================================================================
	# Part 4: ProfileStore Chapter State Persistence
	# ==========================================================================
	var save_err: Error = ch_mgr.save_to_store(test_store, "profile_01")
	_check(save_err == OK, "Saved chapter state to ProfileStore")

	var reloaded_mgr := ChapterManager.new()
	var load_err: Error = reloaded_mgr.load_from_store(test_store, "profile_01")
	_check(load_err == OK, "Loaded chapter state from ProfileStore")
	_check(reloaded_mgr.is_academic_complete == true, "Academic complete state persisted")
	_check(reloaded_mgr.unlocked_chapters.has(ChapterManager.CHAPTER_3), "Unlocked chapters persisted")

	game_root.queue_free()

	# Cleanup temporary profile dir
	if DirAccess.dir_exists_absolute(_test_root):
		var d := DirAccess.open(_test_root)
		if d != null:
			for sub in d.get_directories():
				var sub_d := DirAccess.open(_test_root + "/" + sub)
				if sub_d != null:
					for f_name in sub_d.get_files():
						sub_d.remove(f_name)
					d.remove(sub)
			d.remove("")

	if _failures > 0:
		printerr("CHAPTER PROGRESSION TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL THREE-CHAPTER PROGRESSION TESTS PASSED SUCCESSFULLY ===")
	quit(0)
