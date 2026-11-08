extends SceneTree

## SBL-W7-003 Educational Assessment & CSV Export Test Suite
## Requirements: GDD-067/068/069/070, FR-EDU-001/002/003/004, AGENTS.md Invariants.

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("EDUCATION REPORT TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W7-003 Education & CSV Report Test Suite ---")

	# Test 1: Question Bank Catalog
	var all_ids: Array[String] = QuestionBank.get_all_question_ids()
	_check(all_ids.size() >= 4, "Question bank has at least 4 questions")
	var q_crit: Dictionary = QuestionBank.get_question("q_crit_01")
	_check(not q_crit.is_empty(), "Question q_crit_01 found")
	_check(q_crit["competency"] == QuestionBank.COMP_CRITICAL_THINKING, "Competency matches")

	# Test 2: Assessment Controller First-Attempt Success
	var controller := AssessmentController.new()
	var res1: Dictionary = controller.submit_answer("q_crit_01", q_crit["correct_index"])
	_check(res1["correct"] == true, "Answer was correct")
	_check(res1["first_attempt_correct"] == true, "First attempt recorded as correct")
	_check(res1["completed"] == true, "Question is marked completed")
	_check(res1["total_attempts"] == 1, "Total attempts is 1")
	_check(controller.is_question_completed("q_crit_01") == true, "Question state verified completed")

	# Test 3: Immutable First Attempt (Wrong then Right)
	var q_dec: Dictionary = QuestionBank.get_question("q_dec_01")
	var wrong_idx: int = 0 if int(q_dec["correct_index"]) != 0 else 1
	var res_wrong: Dictionary = controller.submit_answer("q_dec_01", wrong_idx)
	_check(res_wrong["correct"] == false, "Wrong answer detected")
	_check(res_wrong["first_attempt_correct"] == false, "First attempt recorded as false")
	_check(res_wrong["completed"] == false, "Question not yet completed")
	_check(res_wrong["total_attempts"] == 1, "Attempt count is 1")

	# Retry with correct answer
	var res_retry: Dictionary = controller.submit_answer("q_dec_01", int(q_dec["correct_index"]))
	_check(res_retry["correct"] == true, "Retry answer is correct")
	_check(res_retry["first_attempt_correct"] == false, "INVARIANT: first_attempt_correct remains strictly false!")
	_check(res_retry["completed"] == true, "INVARIANT: completed is now true (completion-gated)")
	_check(res_retry["total_attempts"] == 2, "Total attempts incremented to 2")

	# Test 4: ProfileStore Integration
	var temp_dir: String = "user://test_edu_profiles_%d" % Time.get_ticks_msec()
	var store := ProfileStore.new(temp_dir)
	var save_err: Error = controller.save_to_store(store, "profile_01")
	_check(save_err == OK, "Saved assessment records to ProfileStore")

	var reloaded := AssessmentController.new()
	var load_err: Error = reloaded.load_from_store(store, "profile_01")
	_check(load_err == OK, "Loaded assessment records from ProfileStore")
	_check(reloaded.is_question_completed("q_crit_01") == true, "q_crit_01 still completed in reloaded store")
	_check(reloaded.records["q_dec_01"]["first_attempt_correct"] == false, "q_dec_01 immutable first attempt preserved")
	_check(reloaded.records["q_dec_01"]["total_attempts"] == 2, "q_dec_01 attempts count preserved")

	# Test 5: RFC-4180 CSV Export
	var export_path: String = "user://test_reports/competency_record_test.csv"
	var csv_err: Error = controller.export_to_csv(export_path)
	_check(csv_err == OK, "CSV exported successfully")
	_check(FileAccess.file_exists(export_path), "Exported CSV file exists on disk")

	var file := FileAccess.open(export_path, FileAccess.READ)
	_check(file != null, "Opened exported CSV file for reading")
	if file != null:
		var header: String = file.get_line()
		_check(header == "question_id,competency,difficulty,first_attempt_correct,total_attempts,completed,timestamp", "CSV header matches RFC-4180 specification")
		var line1: String = file.get_line()
		_check(line1.begins_with("q_crit_01"), "First data row contains q_crit_01")
		_check(line1.contains("true,1,true"), "q_crit_01 data fields match expected values")
		var line2: String = file.get_line()
		_check(line2.begins_with("q_dec_01"), "Second data row contains q_dec_01")
		_check(line2.contains("false,2,true"), "q_dec_01 data fields match expected values (false, 2 attempts, completed)")
		file.close()

	# Cleanup test files
	if FileAccess.file_exists(export_path):
		DirAccess.remove_absolute(export_path)

	if _failures > 0:
		printerr("EDUCATION REPORT TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL EDUCATION & CSV REPORT TESTS PASSED SUCCESSFULLY ===")
	quit(0)
