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

	# Test 3: Immutable First Attempt (Wrong then Right) & First Response Tracking
	var q_dec: Dictionary = QuestionBank.get_question("q_dec_01")
	var wrong_idx: int = 0 if int(q_dec["correct_index"]) != 0 else 1
	var res_wrong: Dictionary = controller.submit_answer("q_dec_01", wrong_idx)
	_check(res_wrong["correct"] == false, "Wrong answer detected")
	_check(res_wrong["first_attempt_correct"] == false, "First attempt recorded as false")
	_check(res_wrong["completed"] == true, "Wrong answer completes (completion-gated invariant)")
	_check(controller.is_question_completed("q_dec_01") == true, "Question verified completed after wrong answer")
	_check(res_wrong["total_attempts"] == 1, "Attempt count is 1")

	# Retry with correct answer
	var res_retry: Dictionary = controller.submit_answer("q_dec_01", int(q_dec["correct_index"]))
	_check(res_retry["correct"] == true, "Retry answer is correct")
	_check(res_retry["first_attempt_correct"] == false, "INVARIANT: first_attempt_correct remains strictly false!")
	_check(res_retry["completed"] == true, "INVARIANT: completed is now true (completion-gated)")
	_check(res_retry["total_attempts"] == 2, "Total attempts incremented to 2")

	# Assert immutable first response after retry
	_check(controller.records["q_dec_01"].has("first_response"), "Record contains first_response")
	var fr_dec: Dictionary = controller.records["q_dec_01"].get("first_response", {})
	_check(fr_dec.get("selected_index", -1) == wrong_idx, "first_response selected_index preserved as wrong_idx after retry")
	_check(fr_dec.get("is_correct", true) == false, "first_response is_correct preserved as false after retry")

	# Test 4: ProfileStore Integration & education.vertical_slice preservation
	var temp_dir: String = "user://test_edu_profiles_%d" % Time.get_ticks_msec()
	var store := ProfileStore.new(temp_dir)

	# Seed profile with existing education.vertical_slice
	var initial_prof: Dictionary = store.new_profile("profile_01")
	var sample_vs: Dictionary = {
		"fixture_id": "sbl_w4_001_one_region_slice",
		"first_choice": "match",
		"first_attempt_correct": true,
		"assessed": false
	}
	initial_prof["education"]["vertical_slice"] = sample_vs
	var seed_err: Error = store.save_profile("profile_01", initial_prof)
	_check(seed_err == OK, "Seeded profile with education.vertical_slice")

	var save_err: Error = controller.save_to_store(store, "profile_01")
	_check(save_err == OK, "Saved assessment records to ProfileStore")

	# Verify stored profile directly preserves education.vertical_slice
	var direct_load: Dictionary = store.load_profile("profile_01")
	_check(direct_load["error"] == OK, "Loaded profile directly from ProfileStore")
	var loaded_edu: Dictionary = direct_load["profile"].get("education", {})
	_check(loaded_edu.has("vertical_slice"), "education.vertical_slice preserved after save_to_store")
	_check(loaded_edu.get("vertical_slice") == sample_vs, "education.vertical_slice content exactly preserved")
	_check(loaded_edu.has("records"), "education.records merged into profile")

	var reloaded := AssessmentController.new()
	var load_err: Error = reloaded.load_from_store(store, "profile_01")
	_check(load_err == OK, "Loaded assessment records from ProfileStore")
	_check(reloaded.is_question_completed("q_crit_01") == true, "q_crit_01 still completed in reloaded store")
	_check(reloaded.records["q_dec_01"]["first_attempt_correct"] == false, "q_dec_01 immutable first attempt preserved")
	_check(reloaded.records["q_dec_01"]["total_attempts"] == 2, "q_dec_01 attempts count preserved")
	_check(reloaded.records["q_dec_01"].has("first_response"), "reloaded q_dec_01 has first_response")
	_check(reloaded.records["q_dec_01"]["first_response"].get("selected_index", -1) == wrong_idx, "first_response index preserved after store reload")

	# Test 5: Invalid Option Rejection (reject out of range before mutation)
	var invalid_controller := AssessmentController.new()
	var pre_records_count: int = invalid_controller.records.size()

	var res_neg: Dictionary = invalid_controller.submit_answer("q_crit_01", -1)
	_check(res_neg.get("error") == ERR_INVALID_PARAMETER, "Negative option index rejected with ERR_INVALID_PARAMETER")
	_check(invalid_controller.records.size() == pre_records_count, "No mutation occurred on negative option index")

	var res_overflow: Dictionary = invalid_controller.submit_answer("q_crit_01", 999)
	_check(res_overflow.get("error") == ERR_INVALID_PARAMETER, "Out of bounds option index rejected with ERR_INVALID_PARAMETER")
	_check(invalid_controller.records.size() == pre_records_count, "No mutation occurred on out of bounds option index")
	_check(invalid_controller.is_question_completed("q_crit_01") == false, "Question remains incomplete after rejected option")

	# Test 6: Deserialization Validation, Missing Records & Legacy Compatibility
	var val_ctrl := AssessmentController.new()

	# Missing records key is empty
	_check(val_ctrl.deserialize({}) == OK, "deserialize with missing records key returns OK")
	_check(val_ctrl.records.is_empty(), "records dictionary is empty when missing from input")

	# Legacy missing first_response accepted
	var legacy_data: Dictionary = {
		"records": {
			"q_crit_01": {
				"question_id": "q_crit_01",
				"competency": QuestionBank.COMP_CRITICAL_THINKING,
				"difficulty": "Foundational",
				"first_attempt_correct": true,
				"first_attempt_recorded": true,
				"total_attempts": 1,
				"completed": true,
				"timestamp": 1234567890
			}
		}
	}
	_check(val_ctrl.deserialize(legacy_data) == OK, "deserialize accepts legacy record with missing first_response")
	_check(val_ctrl.records.has("q_crit_01"), "legacy record loaded into records")
	_check(not val_ctrl.records["q_crit_01"].has("first_response"), "legacy record retains missing first_response")

	# Validation before replacing live records (reject unknown question ID without replacing live records)
	var live_snapshot: Dictionary = val_ctrl.records.duplicate(true)
	var invalid_id_data: Dictionary = {
		"records": {
			"unknown_question_id_xyz": {
				"question_id": "unknown_question_id_xyz",
				"first_attempt_correct": true,
				"total_attempts": 1,
				"completed": true,
				"timestamp": 1234567890
			}
		}
	}
	_check(val_ctrl.deserialize(invalid_id_data) == ERR_INVALID_DATA, "deserialize rejects unknown question ID")
	_check(val_ctrl.records == live_snapshot, "Live records remain untouched after rejected deserialize")

	# Test 7: RFC-4180 CSV Export
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

	_test_stale_first_answer(store)
	# Cleanup test files
	if FileAccess.file_exists(export_path):
		DirAccess.remove_absolute(export_path)

	if _failures > 0:
		printerr("EDUCATION REPORT TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL EDUCATION & CSV REPORT TESTS PASSED SUCCESSFULLY ===")
	quit(0)

func _test_stale_first_answer(store: ProfileStore) -> void:
	var slot := "profile_02"
	var question := QuestionBank.get_question("q_dec_01")
	var correct: int = question["correct_index"]
	var wrong: int = (correct + 1) % (question["options"] as Array).size()
	var first := AssessmentController.new()
	var stale := AssessmentController.new()
	first.submit_answer("q_dec_01", wrong)
	stale.submit_answer("q_dec_01", correct)
	_check(first.save_to_store(store, slot) == OK, "first instance saves original answer")
	_check(stale.save_to_store(store, slot) == ERR_BUSY, "stale first answer cannot overwrite persisted result")
	var reloaded := AssessmentController.new()
	if not _check(reloaded.load_from_store(store, slot) == OK, "reload first answer"):
		return
	var answer: Dictionary = reloaded.records.get("q_dec_01", {})
	_check(answer.get("first_attempt_correct", true) == false and answer.get("total_attempts", 0) == 1, "first wrong answer and attempt count preserved")
	_check(answer.get("first_response", {}).get("selected_index", -1) == wrong, "original option retained")
	reloaded.submit_answer("q_dec_01", correct)
	_check(reloaded.save_to_store(store, slot) == OK, "fresh retry saves")
	var final := AssessmentController.new()
	_check(final.load_from_store(store, slot) == OK, "reload retry")
	answer = final.records.get("q_dec_01", {})
	_check(answer.get("first_attempt_correct", true) == false and answer.get("total_attempts", 0) == 2, "retry preserves first answer and increases attempts")
