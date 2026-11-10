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
##   OD-007 currency ("banked_coins", "satchel_coins") and OD-006 tiers ("tiers")
##   are optional; when present they must be non-negative bounded integers and a
##   String -> tier-index map inside the approved five-tier range.
## - Character: runtime numeric fields (level, xp, vitality, resonance, agility,
##   focus, unspent_points, max_hp, spirit_power) must be bounded integers in safe range;
##   level is additionally bounded by the OD-005 cap of 30 (CharacterStats.LEVEL_CAP).
## - World & Education cross-record invariants:
##   * Chapter progression: current_chapter (1..4), unlocked_chapters (exact contiguous
##     format [1], [1,2], [1,2,3] with completion 4 keeping [1,2,3]), is_academic_complete
##     (true iff current == 4).
##   * Chapter progression requires completed prerequisite question records:
##     Chapter 2 requires q_dec_01; Chapter 3 requires q_res_01; Academic Complete
##     requires q_crit_02. Pre-P1 bypass saves lacking records are rejected.
##   * M2 Vertical Slice consistency: delegated to SliceProgress.validate_profile(profile).
##   * Assessment records: verified via AssessmentController.deserialize.
##   * Active expedition snapshots: OD-007 satchel stack/slot boundaries and
##     non-negative at-risk currency are enforced on top of the OD-009 shape checks.
##   * OD-010 quest branch records (optional world["quest_branches"]): strict
##     branch-and-reconverge structure only - one local choice cluster per chapter,
##     gate reconvergence consistency, academic-MVP profiles must stay linear, and
##     any key outside the approved schema (for example a deferred reputation or
##     faction field) is rejected.
##   * OD-011 dungeon mastery records (optional world["dungeon_mastery"]): knowledge/
##     access markers only - unique bounded string markers under an exact two-key
##     schema, so a stat/power field can never ride along into a profile or backup.

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

	# Runtime numeric fields within safe integer range. Level is additionally
	# bounded by the OD-005 owner-approved cap of 30 (GDD-029 / TC-PRG-001).
	if character.has("level"):
		if not _is_bounded_int(character["level"], 1, CharacterStats.LEVEL_CAP):
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
			if eq.is_empty() or eq.size() > KureiTree.MAX_EQUIPPED_SKILLS:
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

	# OD-007 Spirit Coins: optional non-negative bounded integers (secured bank /
	# at-risk satchel). Absent keys mean 0 for legacy profiles.
	for coin_key in ["banked_coins", "satchel_coins"]:
		if inventory.has(coin_key):
			if not _is_bounded_int(inventory[coin_key], 0, MAX_SAFE_INT):
				return ERR_INVALID_DATA

	# OD-006 item tiers: optional String -> tier-index map inside the approved
	# Common..Legendary range; absent keys mean every item defaults to Common.
	if inventory.has("tiers"):
		var tiers_val: Variant = inventory["tiers"]
		if typeof(tiers_val) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var tiers: Dictionary = tiers_val as Dictionary
		for item_id: Variant in tiers.keys():
			if typeof(item_id) != TYPE_STRING or (item_id as String).is_empty():
				return ERR_INVALID_DATA
			if not _is_int_value(tiers[item_id]):
				return ERR_INVALID_DATA
			var tier_i: int = int(tiers[item_id])
			if tier_i < InventoryManager.TIER_COMMON or tier_i > InventoryManager.TIER_LEGENDARY:
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

	# OD-010: optional branch-and-reconverge quest structure (strict schema; the
	# academic MVP profile simply carries no record and stays linear).
	if world.has(QuestBranchModel.WORLD_KEY):
		var qb_err: Error = QuestBranchModel.validate_record(world[QuestBranchModel.WORLD_KEY])
		if qb_err != OK:
			return qb_err

	# OD-011: optional dungeon mastery record (knowledge/access markers only; a
	# stat or power field in the record is rejected here).
	if world.has(DungeonMastery.WORLD_KEY):
		var dm_err: Error = DungeonMastery.validate_record(world[DungeonMastery.WORLD_KEY])
		if dm_err != OK:
			return dm_err

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
	var satchel_types: int = 0
	for item_id: Variant in satchel.keys():
		if typeof(item_id) != TYPE_STRING or String(item_id).is_empty():
			return ERR_INVALID_DATA
		# OD-007: at-risk stacks respect the approved 99-unit ceiling and the
		# snapshot holds at most the approved 20 distinct item stacks.
		if not _is_bounded_int(satchel[item_id], 1, InventoryManager.MAX_STACK_SIZE):
			return ERR_INVALID_DATA
		satchel_types += 1
	if satchel_types > InventoryManager.MAX_INVENTORY_SLOTS:
		return ERR_INVALID_DATA
	# OD-007: optional at-risk currency (legacy snapshots carry none => 0).
	if state.has("satchel_coins"):
		if not _is_bounded_int(state["satchel_coins"], 0, MAX_SAFE_INT):
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
