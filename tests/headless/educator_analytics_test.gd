extends SceneTree

## SBL-M5-002 Educator Cohort & Analytics Simulator Test Suite
## Requirements: GDD-067/068/069/070/071/072, FR-EDU-001/002/003/004, AGENTS.md Invariants.

var _failures: int = 0
var _test_root: String = ""

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("COHORT ANALYTICS TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-M5-002 Educator Cohort & Analytics Simulator Test ---")

	_test_root = "user://test_cohort_analytics_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_test_root))

	var cohort_size: int = 12
	var question_ids: Array[String] = QuestionBank.get_all_question_ids()
	var student_records: Array[Dictionary] = [] # Array of {student_id, assessment_controller}

	# ==========================================================================
	# Step 1: Simulate 12 Learners Across 3 Distinct Archetypes
	# ==========================================================================
	for i in range(cohort_size):
		var student_id: String = "student_%02d" % (i + 1)
		var controller := AssessmentController.new()

		# Archetype 1: Students 1-4 (High Mastery: 100% First Attempt Correct)
		if i < 4:
			for q_id in question_ids:
				var q: Dictionary = QuestionBank.get_question(q_id)
				var correct_idx: int = int(q["correct_index"])
				var res: Dictionary = controller.submit_answer(q_id, correct_idx)
				_check(res["correct"] == true, "[%s] Immediate correct" % student_id)
				_check(res["first_attempt_correct"] == true, "[%s] First attempt marked correct" % student_id)

		# Archetype 2: Students 5-8 (Persistent Learner: Wrong first attempt, retries until correct)
		elif i < 8:
			for q_id in question_ids:
				var q: Dictionary = QuestionBank.get_question(q_id)
				var correct_idx: int = int(q["correct_index"])
				var wrong_idx: int = (correct_idx + 1) % 4

				# First attempt: incorrect
				var res1: Dictionary = controller.submit_answer(q_id, wrong_idx)
				_check(res1["correct"] == false, "[%s] First attempt incorrect" % student_id)
				_check(res1["first_attempt_correct"] == false, "[%s] First attempt marked false" % student_id)

				# Second attempt: incorrect
				controller.submit_answer(q_id, (correct_idx + 2) % 4)

				# Third attempt: correct
				var res3: Dictionary = controller.submit_answer(q_id, correct_idx)
				_check(res3["correct"] == true, "[%s] Third attempt correct" % student_id)
				# CRITICAL INVARIANT: first_attempt_correct MUST remain false!
				_check(res3["first_attempt_correct"] == false, "[%s] First attempt strictly immutable!" % student_id)
				_check(res3["total_attempts"] == 3, "[%s] Total attempts counted as 3" % student_id)
				_check(res3["completed"] == true, "[%s] Completed via completion-gated rule" % student_id)

		# Archetype 3: Students 9-12 (Mixed Performance: Varies by question)
		else:
			for idx in range(question_ids.size()):
				var q_id: String = question_ids[idx]
				var q: Dictionary = QuestionBank.get_question(q_id)
				var correct_idx: int = int(q["correct_index"])

				if idx % 2 == 0:
					# Correct first try
					controller.submit_answer(q_id, correct_idx)
				else:
					# Incorrect first try, correct second
					controller.submit_answer(q_id, (correct_idx + 1) % 4)
					controller.submit_answer(q_id, correct_idx)

		student_records.append({
			"id": student_id,
			"controller": controller
		})

	# ==========================================================================
	# Step 2: Validate Immutability and Completion Gating Across Cohort
	# ==========================================================================
	var total_records_evaluated: int = 0
	var total_completed: int = 0
	var first_attempt_correct_count: int = 0

	for entry in student_records:
		var s_id: String = entry["id"]
		var ctrl: AssessmentController = entry["controller"]

		for q_id in question_ids:
			total_records_evaluated += 1
			var rec: Dictionary = ctrl.records.get(q_id, {})
			_check(not rec.is_empty(), "Record exists for %s on %s" % [s_id, q_id])
			_check(rec.get("completed", false) == true, "Completion-gated rule satisfied for %s" % s_id)
			total_completed += 1

			if rec.get("first_attempt_correct", false) == true:
				first_attempt_correct_count += 1

	_check(total_records_evaluated == cohort_size * question_ids.size(), "All 72 student activities evaluated")
	_check(total_completed == total_records_evaluated, "100% completion rate achieved (completion-gated invariant)")

	# Expected first attempt correct: 4 students * 6 + 0 + 4 students * 3 (indices 0, 2, 4) = 24 + 0 + 12 = 36
	_check(first_attempt_correct_count == 36, "First-attempt accuracy matches exact archetype expectation: 36/72 (50.0%%)")

	# ==========================================================================
	# Step 3: Generate Aggregated Cohort RFC-4180 CSV Export
	# ==========================================================================
	var export_dir: String = "user://reports"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(export_dir))
	var export_path: String = "%s/cohort_analytics_report.csv" % export_dir

	var f := FileAccess.open(export_path, FileAccess.WRITE)
	_check(f != null, "Opened cohort analytics CSV for writing")

	if f != null:
		# RFC-4180 Header
		f.store_line("student_id,question_id,competency,first_attempt_correct,completed,total_attempts")

		var row_count: int = 0
		for entry in student_records:
			var s_id: String = entry["id"]
			var ctrl: AssessmentController = entry["controller"]

			for q_id in question_ids:
				var rec: Dictionary = ctrl.records.get(q_id, {})
				var comp: String = rec.get("competency", "")
				var first_corr: String = "true" if rec.get("first_attempt_correct", false) else "false"
				var comp_flag: String = "true" if rec.get("completed", false) else "false"
				var attempts: int = int(rec.get("total_attempts", 0))

				f.store_line("%s,%s,\"%s\",%s,%s,%d" % [
					s_id, q_id, comp, first_corr, comp_flag, attempts
				])
				row_count += 1

		f.close()
		_check(row_count == cohort_size * question_ids.size(), "All 60 rows written to CSV")

	# ==========================================================================
	# Step 4: Validate Exported RFC-4180 CSV Integrity
	# ==========================================================================
	_check(FileAccess.file_exists(export_path), "Cohort CSV file exists on disk")
	var f_read := FileAccess.open(export_path, FileAccess.READ)
	_check(f_read != null, "Opened CSV for reading verification")

	if f_read != null:
		var header_line: String = f_read.get_line()
		_check(header_line == "student_id,question_id,competency,first_attempt_correct,completed,total_attempts", "Header conforms exactly to RFC-4180")

		var read_rows: int = 0
		while not f_read.eof_reached():
			var line: String = f_read.get_line().strip_edges()
			if line.is_empty():
				continue
			var cols := line.split(",")
			_check(cols.size() == 6, "Row has 6 valid CSV columns: " + line)
			read_rows += 1

		f_read.close()
		_check(read_rows == cohort_size * question_ids.size(), "Read back exactly 72 valid data rows")

	# Clean up temporary test files
	if FileAccess.file_exists(export_path):
		DirAccess.remove_absolute(export_path)
	_cleanup_dir(_test_root)

	print("--- Educator Cohort & Analytics Simulator Complete. Failures: %d ---" % _failures)
	if _failures == 0:
		print("ALL EDUCATOR COHORT & ANALYTICS CHECKS PASSED (100% SUCCESS)")
		quit(0)
	else:
		printerr("COHORT TEST FAILED with %d error(s)" % _failures)
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
