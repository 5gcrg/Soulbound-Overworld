extends SceneTree

## SBL-W9-003 Three-Chapter Academic Progression & Completion Test Suite
## Requirements: GDD-041/063/070/116, FR-WLD-001, FR-EDU-003/004, AGENTS.md Invariants.

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

	var ch_mgr := ChapterManager.new()
	var assessment := AssessmentController.new()

	_check(ch_mgr != null, "ChapterManager instantiated")
	_check(assessment != null, "AssessmentController instantiated")

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
	_check(assessment.is_chapter_activity_completed(1) == true, "Ch 1 activity completes immediately on wrong valid submission")
	_check(ch_mgr.can_advance_chapter(assessment) == true, "Ch 1 advance unlocked immediately by completion-gated rule")

	# Retry with correct answer; first_attempt_correct must remain false
	assessment.submit_answer("q_dec_01", int(q1["correct_index"]))
	_check(assessment.records["q_dec_01"]["first_attempt_correct"] == false, "Ch 1 retry leaves first_attempt_correct false")
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
	# Part 4: ProfileStore Chapter State Persistence
	# ==========================================================================
	var save_err: Error = ch_mgr.save_to_store(test_store, "profile_01")
	_check(save_err == OK, "Saved chapter state to ProfileStore")

	var reloaded_mgr := ChapterManager.new()
	var load_err: Error = reloaded_mgr.load_from_store(test_store, "profile_01")
	_check(load_err == OK, "Loaded chapter state from ProfileStore")
	_check(reloaded_mgr.is_academic_complete == true, "Academic complete state persisted")
	_check(reloaded_mgr.unlocked_chapters.has(ChapterManager.CHAPTER_3), "Unlocked chapters persisted")

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
