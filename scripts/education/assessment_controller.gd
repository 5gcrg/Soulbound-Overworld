class_name AssessmentController
extends RefCounted

## AssessmentController — SBL-W7-002 Educational Assessment Engine
## Requirements: GDD-067/068/069/070/071/072, FR-EDU-001/002/003/004, AGENTS.md Invariants.
##
## Enforces:
## 1. Completion-gated progression (progression unlocks upon completion, not pass score).
## 2. Immutable first-attempt tracking (first_attempt_correct is never altered by subsequent attempts).
## 3. Persistent integration into ProfileStore "education" section.
## 4. RFC-4180 compliant CSV export for educator dashboard / LMS integration.

signal question_answered(question_id: String, is_correct: bool, is_first_attempt: bool)
signal competency_completed(competency: String)

var records: Dictionary = {} # String (question_id) -> Dictionary

func submit_answer(question_id: String, selected_index: int) -> Dictionary:
	var q: Dictionary = QuestionBank.get_question(question_id)
	if q.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}

	var correct_idx: int = int(q.get("correct_index", -1))
	var is_correct: bool = (selected_index == correct_idx)

	var rec: Dictionary = records.get(question_id, {
		"question_id": question_id,
		"competency": String(q.get("competency", "")),
		"difficulty": String(q.get("difficulty", "Foundational")),
		"first_attempt_correct": false,
		"first_attempt_recorded": false,
		"total_attempts": 0,
		"completed": false,
		"timestamp": Time.get_unix_time_from_system()
	})

	var is_first: bool = not rec.get("first_attempt_recorded", false)
	rec["total_attempts"] = int(rec.get("total_attempts", 0)) + 1
	rec["timestamp"] = Time.get_unix_time_from_system()

	if is_first:
		rec["first_attempt_correct"] = is_correct
		rec["first_attempt_recorded"] = true

	if is_correct:
		rec["completed"] = true

	records[question_id] = rec

	question_answered.emit(question_id, is_correct, is_first)

	var comp: String = String(q.get("competency", ""))
	if is_competency_completed(comp):
		competency_completed.emit(comp)

	return {
		"error": OK,
		"correct": is_correct,
		"first_attempt_correct": rec["first_attempt_correct"],
		"total_attempts": rec["total_attempts"],
		"completed": rec["completed"],
		"explanation": String(q.get("explanation", ""))
	}

func is_question_completed(question_id: String) -> bool:
	if records.has(question_id):
		return bool(records[question_id].get("completed", false))
	return false

func is_competency_completed(competency: String) -> bool:
	var questions: Array[Dictionary] = QuestionBank.get_questions_by_competency(competency)
	if questions.is_empty():
		return false
	for q: Dictionary in questions:
		var q_id: String = String(q.get("id", ""))
		if not is_question_completed(q_id):
			return false
	return true

func get_completion_summary() -> Dictionary:
	var total_questions: int = QuestionBank.get_all_question_ids().size()
	var completed_count: int = 0
	var first_try_correct_count: int = 0

	for q_id: String in records.keys():
		var rec: Dictionary = records[q_id]
		if rec.get("completed", false):
			completed_count += 1
		if rec.get("first_attempt_correct", false):
			first_try_correct_count += 1

	return {
		"total_questions": total_questions,
		"completed_questions": completed_count,
		"first_attempt_correct_count": first_try_correct_count,
		"is_fully_completed": (completed_count >= total_questions and total_questions > 0)
	}

# ==============================================================================
# Serialization & ProfileStore Integration
# ==============================================================================

func serialize() -> Dictionary:
	return {
		"records": records.duplicate(true)
	}

func deserialize(data: Dictionary) -> Error:
	if not data.has("records") or typeof(data["records"]) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	records = (data["records"] as Dictionary).duplicate(true)
	return OK

func load_from_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	if res["error"] != OK:
		return res["error"]
	var prof: Dictionary = res["profile"]
	if not prof.has("education") or typeof(prof["education"]) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	return deserialize(prof["education"])

func save_to_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	var prof: Dictionary = {}
	if res["error"] == ERR_FILE_NOT_FOUND:
		prof = store.new_profile(slot)
	elif res["error"] == OK:
		prof = (res["profile"] as Dictionary).duplicate(true)
	else:
		return res["error"]
	prof["education"] = serialize()
	return store.save_profile(slot, prof)

# ==============================================================================
# RFC-4180 CSV Report Export
# ==============================================================================

func export_to_csv(export_path: String = "user://reports/competency_record.csv") -> Error:
	var base_dir: String = export_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		var make_err: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if make_err != OK:
			return make_err

	var file := FileAccess.open(export_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	# RFC-4180 CSV Header
	file.store_line("question_id,competency,difficulty,first_attempt_correct,total_attempts,completed,timestamp")

	var keys: Array = records.keys()
	keys.sort()
	for q_id: String in keys:
		var rec: Dictionary = records[q_id]
		var line: String = "%s,%s,%s,%s,%d,%s,%d" % [
			_escape_csv(String(rec.get("question_id", ""))),
			_escape_csv(String(rec.get("competency", ""))),
			_escape_csv(String(rec.get("difficulty", ""))),
			"true" if rec.get("first_attempt_correct", false) else "false",
			int(rec.get("total_attempts", 0)),
			"true" if rec.get("completed", false) else "false",
			int(rec.get("timestamp", 0))
		]
		file.store_line(line)

	file.close()
	return OK

func _escape_csv(value: String) -> String:
	if value.contains(",") or value.contains("\"") or value.contains("\n") or value.contains("\r"):
		return "\"" + value.replace("\"", "\"\"") + "\""
	return value
