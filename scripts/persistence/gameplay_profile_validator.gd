class_name GameplayProfileValidator
extends RefCounted

## GameplayProfileValidator — SBL-P1-C Safe Backup Preflight Validator
##
## Validates consumed gameplay fields and cross-record invariants before commit
## without modifying candidate dictionary. Rejects malformed records that would
## crash or lock out consumers.
##
## Invariants:
## - Envelope sections: character, inventory, world, education. Genuinely empty
##   sections and unrelated extension keys are allowed.
## - Bounded integral values: accepts JSON floats representing exact integers.
## - Inventory: banked/satchel counts must be positive exact safe integers;
##   known equipment slots ("weapon", "armor", "relic_1", "relic_2") must have String values.
## - Character: runtime numeric fields (level, xp, vitality, resonance, agility,
##   focus, unspent_points, max_hp, spirit_power) must be bounded integers in safe range.
## - World & Education cross-record invariants:
##   * Chapter progression: current_chapter (1..4), unlocked_chapters (exact contiguous
##     format [1], [1,2], [1,2,3] with completion 4 keeping [1,2,3]), is_academic_complete
##     (true iff current == 4).
##   * Chapter progression requires completed prerequisite question records:
##     Chapter 2 requires q_dec_01; Chapter 3 requires q_res_01; Academic Complete
##     requires q_crit_02. Pre-P1 bypass saves lacking records are rejected.
##   * M2 Vertical Slice consistency: delegated to SliceProgress.validate_profile(profile).
##   * Assessment records: verified via AssessmentController.deserialize.

const KNOWN_EQUIP_SLOTS: Array[StringName] = [
	&"weapon",
	&"armor",
	&"relic_1",
	&"relic_2"
]

const MIN_SAFE_INT: int = -9007199254740991
const MAX_SAFE_INT: int = 9007199254740991

static func validate(profile: Dictionary) -> Error:
	if typeof(profile) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA

	# Envelope sections check
	for sec_name in ["character", "inventory", "world", "education"]:
		if not profile.has(sec_name) or typeof(profile[sec_name]) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA

	var character: Dictionary = profile["character"] as Dictionary
	var inventory: Dictionary = profile["inventory"] as Dictionary
	var world: Dictionary = profile["world"] as Dictionary
	var education: Dictionary = profile["education"] as Dictionary

	var err: Error = _validate_character(character)
	if err != OK:
		return err

	err = _validate_inventory(inventory)
	if err != OK:
		return err

	err = _validate_education(education)
	if err != OK:
		return err

	err = _validate_world(world, education)
	if err != OK:
		return err

	err = _validate_m2_slice(profile)
	if err != OK:
		return err

	return OK

# ==============================================================================
# Focused Helper Validation
# ==============================================================================

static func _is_int_value(val: Variant) -> bool:
	if typeof(val) == TYPE_INT:
		return true
	if typeof(val) == TYPE_FLOAT:
		var f: float = val as float
		return is_finite(f) and not is_nan(f) and floor(f) == f
	return false

static func _is_bounded_int(val: Variant, min_val: int, max_val: int) -> bool:
	if not _is_int_value(val):
		return false
	var f: float = float(val)
	return f >= float(min_val) and f <= float(max_val)

static func _validate_character(character: Dictionary) -> Error:
	# Genuinely empty character section is allowed
	if character.is_empty():
		return OK

	if not character.has("level") or not character.has("xp"):
		return ERR_INVALID_DATA

	# Runtime numeric fields within safe integer range (no arbitrary balancing caps)
	if character.has("level"):
		if not _is_bounded_int(character["level"], 1, MAX_SAFE_INT):
			return ERR_INVALID_DATA

	if character.has("xp"):
		if not _is_bounded_int(character["xp"], 0, MAX_SAFE_INT):
			return ERR_INVALID_DATA

	if character.has("vitality"):
		if not _is_bounded_int(character["vitality"], 1, MAX_SAFE_INT):
			return ERR_INVALID_DATA

	if character.has("resonance"):
		if not _is_bounded_int(character["resonance"], 1, MAX_SAFE_INT):
			return ERR_INVALID_DATA

	if character.has("agility"):
		if not _is_bounded_int(character["agility"], 1, MAX_SAFE_INT):
			return ERR_INVALID_DATA

	if character.has("focus"):
		if not _is_bounded_int(character["focus"], 1, MAX_SAFE_INT):
			return ERR_INVALID_DATA

	if character.has("unspent_points"):
		if not _is_bounded_int(character["unspent_points"], 0, MAX_SAFE_INT):
			return ERR_INVALID_DATA

	if character.has("max_hp"):
		if not _is_bounded_int(character["max_hp"], 1, MAX_SAFE_INT):
			return ERR_INVALID_DATA

	if character.has("spirit_power"):
		if not _is_bounded_int(character["spirit_power"], 0, MAX_SAFE_INT):
			return ERR_INVALID_DATA

	if character.has("kurei_tree"):
		if typeof(character["kurei_tree"]) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var kt: Dictionary = character["kurei_tree"] as Dictionary
		if kt.has("equipped_skills"):
			if typeof(kt["equipped_skills"]) != TYPE_ARRAY:
				return ERR_INVALID_DATA
			var eq: Array = kt["equipped_skills"] as Array
			if eq.size() > KureiTree.MAX_EQUIPPED_SKILLS:
				return ERR_INVALID_DATA
			var unlocked_set := {}
			if kt.has("unlocked_skills") and typeof(kt["unlocked_skills"]) == TYPE_ARRAY:
				for u in kt["unlocked_skills"]:
					if typeof(u) == TYPE_STRING or typeof(u) == TYPE_STRING_NAME:
						unlocked_set[String(u)] = true
			for st in KureiTree.STARTER_SKILLS:
				unlocked_set[String(st)] = true
			var seen := {}
			for item in eq:
				if typeof(item) != TYPE_STRING and typeof(item) != TYPE_STRING_NAME:
					return ERR_INVALID_DATA
				var sid_str: String = String(item)
				if seen.has(sid_str):
					return ERR_INVALID_DATA
				seen[sid_str] = true
				var sid := StringName(sid_str)
				if not KureiTree.SKILL_NODES.has(sid):
					return ERR_INVALID_DATA
				if sid == &"phase_mastery" or KureiTree.SKILL_NODES[sid].get("passive", false):
					return ERR_INVALID_DATA
				if not unlocked_set.has(sid_str):
					return ERR_INVALID_DATA

	return OK

static func _validate_inventory(inventory: Dictionary) -> Error:
	if inventory.is_empty():
		return OK

	# Deduplicated banked and satchel item map checks for consumed keys
	for key in ["banked", "satchel"]:
		if inventory.has(key):
			var items_val: Variant = inventory[key]
			if typeof(items_val) != TYPE_DICTIONARY:
				return ERR_INVALID_DATA
			var items: Dictionary = items_val as Dictionary
			for item_id in items.keys():
				if typeof(item_id) != TYPE_STRING or (item_id as String).is_empty():
					return ERR_INVALID_DATA
				if not _is_bounded_int(items[item_id], 1, MAX_SAFE_INT):
					return ERR_INVALID_DATA

	var banked: Dictionary = inventory.get("banked", {}) as Dictionary
	var satchel: Dictionary = inventory.get("satchel", {}) as Dictionary
	for id in banked.keys():
		if satchel.has(id):
			if int(banked[id]) > MAX_SAFE_INT - int(satchel[id]):
				return ERR_INVALID_DATA

	# Known equipment slots' value types must be String
	if inventory.has("equipment"):
		var eq_val: Variant = inventory["equipment"]
		if typeof(eq_val) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var eq: Dictionary = eq_val as Dictionary
		for slot in KNOWN_EQUIP_SLOTS:
			var slot_str: String = String(slot)
			if eq.has(slot_str):
				if typeof(eq[slot_str]) != TYPE_STRING:
					return ERR_INVALID_DATA

	return OK

static func _validate_education(education: Dictionary) -> Error:
	return AssessmentController.new().deserialize(education)

static func _validate_world(world: Dictionary, education: Dictionary) -> Error:
	if world.is_empty():
		return OK

	if world.has("chapter_progress"):
		var cp_val: Variant = world["chapter_progress"]
		if typeof(cp_val) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var cp: Dictionary = cp_val as Dictionary

		# Validate current_chapter
		if not cp.has("current_chapter") or not _is_int_value(cp["current_chapter"]):
			return ERR_INVALID_DATA
		var current_chapter: int = int(cp["current_chapter"])
		if current_chapter < ChapterManager.CHAPTER_1 or current_chapter > ChapterManager.ACADEMIC_COMPLETE:
			return ERR_INVALID_DATA

		# Validate is_academic_complete
		if not cp.has("is_academic_complete") or typeof(cp["is_academic_complete"]) != TYPE_BOOL:
			return ERR_INVALID_DATA
		var is_academic_complete: bool = bool(cp["is_academic_complete"])

		# Cross-field consistency: current_chapter == 4 <==> is_academic_complete == true
		if is_academic_complete != (current_chapter == ChapterManager.ACADEMIC_COMPLETE):
			return ERR_INVALID_DATA

		# Validate chapter_flags
		if not cp.has("chapter_flags") or typeof(cp["chapter_flags"]) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA

		# Require exact contiguous unlocked list: [1], [1,2], [1,2,3] with completion 4 keeping [1,2,3]
		var expected_unlocked: Array[int] = []
		match current_chapter:
			ChapterManager.CHAPTER_1:
				expected_unlocked = [1]
			ChapterManager.CHAPTER_2:
				expected_unlocked = [1, 2]
			ChapterManager.CHAPTER_3, ChapterManager.ACADEMIC_COMPLETE:
				expected_unlocked = [1, 2, 3]
			_:
				return ERR_INVALID_DATA

		if not cp.has("unlocked_chapters") or typeof(cp["unlocked_chapters"]) != TYPE_ARRAY:
			return ERR_INVALID_DATA
		var un_val: Array = cp["unlocked_chapters"] as Array
		if un_val.size() != expected_unlocked.size():
			return ERR_INVALID_DATA
		for i in range(expected_unlocked.size()):
			if not _is_int_value(un_val[i]) or int(un_val[i]) != expected_unlocked[i]:
				return ERR_INVALID_DATA

		# Consistency with completed prerequisite educational records
		var needs_ch1_req: bool = current_chapter >= ChapterManager.CHAPTER_2
		var needs_ch2_req: bool = current_chapter >= ChapterManager.CHAPTER_3
		var needs_ch3_req: bool = current_chapter >= ChapterManager.ACADEMIC_COMPLETE

		if needs_ch1_req:
			var req_id: String = QuestionBank.get_required_question_id_for_chapter(1)
			if not _is_question_completed(education, req_id):
				return ERR_INVALID_DATA

		if needs_ch2_req:
			var req_id: String = QuestionBank.get_required_question_id_for_chapter(2)
			if not _is_question_completed(education, req_id):
				return ERR_INVALID_DATA

		if needs_ch3_req:
			var req_id: String = QuestionBank.get_required_question_id_for_chapter(3)
			if not _is_question_completed(education, req_id):
				return ERR_INVALID_DATA

	if world.has("active_expedition"):
		var ae_err: Error = _validate_active_expedition(world["active_expedition"])
		if ae_err != OK:
			return ae_err

	return OK

## Validates a persisted suspend snapshot before it can reach DungeonExpedition.restore_expedition.
static func _validate_active_expedition(value: Variant) -> Error:
	if typeof(value) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var state: Dictionary = value as Dictionary
	if typeof(state.get("is_active")) != TYPE_BOOL or state["is_active"] != true:
		return ERR_INVALID_DATA
	if not _is_bounded_int(state.get("seed"), MIN_SAFE_INT, MAX_SAFE_INT):
		return ERR_INVALID_DATA
	if not _is_bounded_int(state.get("room_count"), 1, 1024):
		return ERR_INVALID_DATA
	if typeof(state.get("expedition_path")) != TYPE_ARRAY:
		return ERR_INVALID_DATA
	var path_arr: Array = state["expedition_path"] as Array
	if path_arr.is_empty():
		return ERR_INVALID_DATA
	for step: Variant in path_arr:
		if not _is_bounded_int(step, 0, MAX_SAFE_INT):
			return ERR_INVALID_DATA
	if not _is_bounded_int(state.get("current_step"), 0, path_arr.size() - 1):
		return ERR_INVALID_DATA
	if typeof(state.get("satchel_items")) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var satchel: Dictionary = state["satchel_items"] as Dictionary
	for item_id: Variant in satchel.keys():
		if typeof(item_id) != TYPE_STRING or String(item_id).is_empty():
			return ERR_INVALID_DATA
		if not _is_bounded_int(satchel[item_id], 1, MAX_SAFE_INT):
			return ERR_INVALID_DATA
	return OK

static func _is_question_completed(education: Dictionary, q_id: String) -> bool:
	if not education.has("records"):
		return false
	var recs_val: Variant = education["records"]
	if typeof(recs_val) != TYPE_DICTIONARY:
		return false
	var recs: Dictionary = recs_val as Dictionary
	if not recs.has(q_id):
		return false
	var q_rec: Variant = recs[q_id]
	if typeof(q_rec) != TYPE_DICTIONARY:
		return false
	return bool((q_rec as Dictionary).get("completed", false)) == true

static func _validate_m2_slice(profile: Dictionary) -> Error:
	return SliceProgress.validate_profile(profile)
