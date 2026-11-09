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
var _pending_baselines: Dictionary = {} # String (question_id) -> Dictionary

func submit_answer(question_id: String, selected_index: int) -> Dictionary:
	var q: Dictionary = QuestionBank.get_question(question_id)
	if q.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}

	var options: Array = q.get("options", [])
	if selected_index < 0 or selected_index >= options.size():
		return {"error": ERR_INVALID_PARAMETER}

	if not _pending_baselines.has(question_id):
		if records.has(question_id):
			_pending_baselines[question_id] = (records[question_id] as Dictionary).duplicate(true)
		else:
			_pending_baselines[question_id] = {}

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
	}).duplicate(true)

	var is_first: bool = not rec.get("first_attempt_recorded", false) and int(rec.get("total_attempts", 0)) == 0
	rec["total_attempts"] = int(rec.get("total_attempts", 0)) + 1
	rec["timestamp"] = Time.get_unix_time_from_system()

	if is_first:
		rec["first_attempt_correct"] = is_correct
		rec["first_attempt_recorded"] = true
		rec["first_response"] = {
			"selected_index": selected_index,
			"index": selected_index,
			"is_correct": is_correct,
			"correct": is_correct
		}

	# Every valid option completes (completion-gated, not pass-score-gated)
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

func is_chapter_activity_completed(chapter_num: int) -> bool:
	var req_id: String = QuestionBank.get_required_question_id_for_chapter(chapter_num)
	return is_question_completed(req_id)

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
	if not data.has("records"):
		records = {}
		_pending_baselines.clear()
		return OK

	if typeof(data["records"]) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA

	var raw_records: Dictionary = data["records"] as Dictionary
	var validated_records: Dictionary = {}

	for q_id_var: Variant in raw_records.keys():
		if typeof(q_id_var) != TYPE_STRING:
			return ERR_INVALID_DATA
		var q_id: String = String(q_id_var)

		# Validate known question ID
		if not QuestionBank.QUESTIONS.has(q_id):
			return ERR_INVALID_DATA

		var rec_val: Variant = raw_records[q_id_var]
		if typeof(rec_val) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var rec: Dictionary = (rec_val as Dictionary).duplicate(true)

		var q_def: Dictionary = QuestionBank.get_question(q_id)

		# Validate matching question metadata when provided
		if rec.has("question_id"):
			if typeof(rec["question_id"]) != TYPE_STRING or rec["question_id"] != q_id:
				return ERR_INVALID_DATA
		else:
			rec["question_id"] = q_id

		if rec.has("competency"):
			if typeof(rec["competency"]) != TYPE_STRING or rec["competency"] != String(q_def.get("competency", "")):
				return ERR_INVALID_DATA

		if rec.has("difficulty"):
			if typeof(rec["difficulty"]) != TYPE_STRING or rec["difficulty"] != String(q_def.get("difficulty", "")):
				return ERR_INVALID_DATA

		# Validate bool fields
		if not rec.has("completed") or typeof(rec["completed"]) != TYPE_BOOL:
			return ERR_INVALID_DATA

		if not rec.has("first_attempt_correct") or typeof(rec["first_attempt_correct"]) != TYPE_BOOL:
			return ERR_INVALID_DATA

		if rec.has("first_attempt_recorded") and typeof(rec["first_attempt_recorded"]) != TYPE_BOOL:
			return ERR_INVALID_DATA

		# Validate valid positive integral total_attempts
		if not rec.has("total_attempts"):
			return ERR_INVALID_DATA
		var attempts_val: Variant = rec["total_attempts"]
		if typeof(attempts_val) != TYPE_INT and typeof(attempts_val) != TYPE_FLOAT:
			return ERR_INVALID_DATA
		if typeof(attempts_val) == TYPE_FLOAT and (not is_finite(attempts_val) or attempts_val != floor(attempts_val)):
			return ERR_INVALID_DATA
		var attempts_int: int = int(attempts_val)
		if attempts_int <= 0 or attempts_int > 9007199254740991:
			return ERR_INVALID_DATA

		# Existing records can contain fractional Unix timestamps.
		if rec.has("timestamp"):
			var timestamp: Variant = rec["timestamp"]
			if not (timestamp is int or timestamp is float):
				return ERR_INVALID_DATA
			if not is_finite(float(timestamp)) or float(timestamp) < 0.0 or float(timestamp) > 9007199254740991.0:
				return ERR_INVALID_DATA

		# Validate optional first_response; legacy missing first_response accepted
		if rec.has("first_response"):
			var fr_val: Variant = rec["first_response"]
			if typeof(fr_val) != TYPE_DICTIONARY:
				return ERR_INVALID_DATA
			var fr: Dictionary = fr_val as Dictionary

			var has_idx: bool = fr.has("selected_index") or fr.has("index")
			if not has_idx:
				return ERR_INVALID_DATA
			var idx_val: Variant = fr.get("selected_index", fr.get("index"))
			if typeof(idx_val) != TYPE_INT and typeof(idx_val) != TYPE_FLOAT:
				return ERR_INVALID_DATA
			if typeof(idx_val) == TYPE_FLOAT and (not is_finite(idx_val) or idx_val != floor(idx_val)):
				return ERR_INVALID_DATA
			var idx_int: int = int(idx_val)
			var options: Array = q_def.get("options", [])
			if idx_int < 0 or idx_int >= options.size():
				return ERR_INVALID_DATA

			var has_corr: bool = fr.has("is_correct") or fr.has("correct")
			if not has_corr:
				return ERR_INVALID_DATA
			if fr.has("is_correct") and typeof(fr["is_correct"]) != TYPE_BOOL:
				return ERR_INVALID_DATA
			if fr.has("correct") and typeof(fr["correct"]) != TYPE_BOOL:
				return ERR_INVALID_DATA
			var corr_val: bool = bool(fr.get("is_correct", fr.get("correct")))
			if corr_val != rec["first_attempt_correct"]:
				return ERR_INVALID_DATA
			var expected_corr: bool = (idx_int == int(q_def.get("correct_index", -1)))
			if corr_val != expected_corr:
				return ERR_INVALID_DATA

		validated_records[q_id] = rec

	# Validate before replacing live records
	records = validated_records
	_pending_baselines.clear()
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

	var latest_edu: Dictionary = {}
	if prof.has("education"):
		if typeof(prof["education"]) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		latest_edu = (prof["education"] as Dictionary).duplicate(true)

	var validator := AssessmentController.new()
	var val_err: Error = validator.deserialize(latest_edu)
	if val_err != OK:
		return val_err
	var latest_records: Dictionary = validator.records

	for q_id: String in _pending_baselines.keys():
		var baseline: Dictionary = _pending_baselines[q_id]
		var b_present: bool = not baseline.is_empty()
		var l_present: bool = latest_records.has(q_id)

		if b_present != l_present:
			return ERR_BUSY

		if b_present and l_present:
			var latest_rec: Dictionary = latest_records[q_id]

			var b_has_att: bool = baseline.has("total_attempts")
			var l_has_att: bool = latest_rec.has("total_attempts")
			if b_has_att != l_has_att:
				return ERR_BUSY
			if b_has_att and _numeric_differ(baseline["total_attempts"], latest_rec["total_attempts"]):
				return ERR_BUSY

			var b_has_fac: bool = baseline.has("first_attempt_correct")
			var l_has_fac: bool = latest_rec.has("first_attempt_correct")
			if b_has_fac != l_has_fac:
				return ERR_BUSY
			if b_has_fac and bool(baseline["first_attempt_correct"]) != bool(latest_rec["first_attempt_correct"]):
				return ERR_BUSY

			var b_fr_info: Dictionary = _extract_first_response_selected_index(baseline)
			var l_fr_info: Dictionary = _extract_first_response_selected_index(latest_rec)
			if b_fr_info["present"] != l_fr_info["present"]:
				return ERR_BUSY
			if b_fr_info["present"] and _numeric_differ(b_fr_info["value"], l_fr_info["value"]):
				return ERR_BUSY

			var b_has_ts: bool = baseline.has("timestamp")
			var l_has_ts: bool = latest_rec.has("timestamp")
			if b_has_ts != l_has_ts:
				return ERR_BUSY
			if b_has_ts and _numeric_differ(baseline["timestamp"], latest_rec["timestamp"]):
				return ERR_BUSY

	var merged_records: Dictionary = latest_records.duplicate(true)

	for q_id: String in _pending_baselines.keys():
		if records.has(q_id):
			merged_records[q_id] = (records[q_id] as Dictionary).duplicate(true)

	latest_edu["records"] = merged_records
	prof["education"] = latest_edu

	var save_err: Error = store.save_profile(slot, prof)
	if save_err != OK:
		return save_err

	records = merged_records
	_pending_baselines.clear()

	return OK

static func _numeric_differ(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		var fa: float = float(a)
		var fb: float = float(b)
		return fa != fb
	return a != b

static func _extract_first_response_selected_index(rec: Dictionary) -> Dictionary:
	if rec.has("first_response") and typeof(rec["first_response"]) == TYPE_DICTIONARY:
		var fr: Dictionary = rec["first_response"]
		if fr.has("selected_index") or fr.has("index"):
			var val: Variant = fr.get("selected_index", fr.get("index"))
			if val is int or val is float:
				return {"present": true, "value": val}
	return {"present": false, "value": null}

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
