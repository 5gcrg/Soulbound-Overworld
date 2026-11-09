class_name KureiTree
extends RefCounted

## KureiTree — SBL-W11-003 Kurei Art Skill Tree & Talent Allocation Engine
## Requirements: GDD-009..015, FR-MAG-001/002, AGENTS.md Invariants.
##
## Governs 4 elemental branches with 2 tiers each:
## - Flame Branch: Flame Burst (T1) -> Solar Flare (T2)
## - Lumina Branch: Lumina Lance (T1) -> Celestial Prism (T2)
## - Torrent Branch: Torrent Surge (T1) -> Glacial Aegis (T2)
## - Void Branch: Void Shift (T1) -> Phase Mastery (T2)

signal skill_unlocked(skill_id: StringName)
signal talents_reset()

const STARTER_SKILLS: Array[StringName] = [
	&"flame_burst",
	&"lumina_lance",
	&"torrent_surge"
]

const SKILL_NODES: Dictionary = {
	&"flame_burst": {
		"id": &"flame_burst",
		"name": "Flame Burst",
		"branch": "Flame",
		"tier": 1,
		"cost": 0,
		"prerequisite": &"",
		"description": "Unleashes concentrated fire dealing 2 damage and inflicting Burn."
	},
	&"solar_flare": {
		"id": &"solar_flare",
		"name": "Solar Flare",
		"branch": "Flame",
		"tier": 2,
		"cost": 2,
		"prerequisite": &"flame_burst",
		"description": "Unleashes solar conflagration dealing 3 damage and inflicting 3-turn Burn."
	},
	&"lumina_lance": {
		"id": &"lumina_lance",
		"name": "Lumina Lance",
		"branch": "Lumina",
		"tier": 1,
		"cost": 0,
		"prerequisite": &"",
		"description": "Radiant spear that pierces all defensive barriers directly into enemy HP."
	},
	&"celestial_prism": {
		"id": &"celestial_prism",
		"name": "Celestial Prism",
		"branch": "Lumina",
		"tier": 2,
		"cost": 2,
		"prerequisite": &"lumina_lance",
		"description": "Prismatic refraction dealing 2 piercing damage and inflicting Stun."
	},
	&"torrent_surge": {
		"id": &"torrent_surge",
		"name": "Torrent Surge",
		"branch": "Torrent",
		"tier": 1,
		"cost": 0,
		"prerequisite": &"",
		"description": "Cleansing tide restoring 1 HP and applying Regeneration."
	},
	&"glacial_aegis": {
		"id": &"glacial_aegis",
		"name": "Glacial Aegis",
		"branch": "Torrent",
		"tier": 2,
		"cost": 2,
		"prerequisite": &"torrent_surge",
		"description": "Restores 2 HP and encases Ren in a protective Cryo Barrier."
	},
	&"void_shift": {
		"id": &"void_shift",
		"name": "Void Shift",
		"branch": "Void",
		"tier": 1,
		"cost": 1,
		"prerequisite": &"",
		"description": "Phase-steps into the astral realm, evading incoming strikes."
	},
	&"phase_mastery": {
		"id": &"phase_mastery",
		"name": "Phase Mastery",
		"branch": "Void",
		"tier": 2,
		"cost": 2,
		"prerequisite": &"void_shift",
		"passive": true,
		"description": "Passive resonance expanding Ren's maximum SP capacity to 4."
	}
}

const AUTHORED_PHASE_MASTERY_MAX_SP: int = 4

var unlocked_skills: Array[StringName] = []
var total_talent_points: int = 0
var spent_talent_points: int = 0

func _init() -> void:
	_init_starters()

func _init_starters() -> void:
	unlocked_skills.clear()
	for s: StringName in STARTER_SKILLS:
		unlocked_skills.append(s)
	spent_talent_points = 0

func sync_with_level(ren_level: int) -> void:
	total_talent_points = maxi(0, ren_level - 1)

func get_unspent_points() -> int:
	return maxi(0, total_talent_points - spent_talent_points)

func is_skill_unlocked(skill_id: StringName) -> bool:
	return unlocked_skills.has(skill_id)

func has_phase_mastery() -> bool:
	return is_skill_unlocked(&"phase_mastery")

func get_max_sp_capacity(baseline_max_sp: int = 2) -> int:
	if has_phase_mastery():
		return AUTHORED_PHASE_MASTERY_MAX_SP
	return baseline_max_sp

func is_skill_passive(skill_id: StringName) -> bool:
	if skill_id == &"phase_mastery":
		return true
	if SKILL_NODES.has(skill_id):
		return bool(SKILL_NODES[skill_id].get("passive", false))
	return false

func is_skill_active(skill_id: StringName) -> bool:
	return SKILL_NODES.has(skill_id) and not is_skill_passive(skill_id)

func can_unlock_skill(skill_id: StringName) -> bool:
	if not SKILL_NODES.has(skill_id):
		return false
	if is_skill_unlocked(skill_id):
		return false
	var node: Dictionary = SKILL_NODES[skill_id]
	var prereq: StringName = StringName(node.get("prerequisite", &""))
	if not prereq.is_empty() and not is_skill_unlocked(prereq):
		return false
	var cost: int = int(node.get("cost", 0))
	return get_unspent_points() >= cost

func unlock_skill(skill_id: StringName) -> Error:
	if not can_unlock_skill(skill_id):
		return ERR_UNAVAILABLE
	var cost: int = int(SKILL_NODES[skill_id].get("cost", 0))
	unlocked_skills.append(skill_id)
	spent_talent_points += cost
	skill_unlocked.emit(skill_id)
	return OK

func respec_talents() -> void:
	_init_starters()
	talents_reset.emit()

func serialize() -> Dictionary:
	var string_skills: Array[String] = []
	for s: StringName in unlocked_skills:
		string_skills.append(String(s))
	return {
		"unlocked_skills": string_skills,
		"spent_talent_points": spent_talent_points,
		"total_talent_points": total_talent_points
	}

func deserialize(data: Dictionary) -> Error:
	if not data.has("unlocked_skills"):
		_init_starters()
		return OK
	var list: Array = data["unlocked_skills"] as Array
	unlocked_skills.clear()
	for item: Variant in list:
		var sid: StringName = StringName(String(item))
		if SKILL_NODES.has(sid) and not unlocked_skills.has(sid):
			unlocked_skills.append(sid)
	for s: StringName in STARTER_SKILLS:
		if not unlocked_skills.has(s):
			unlocked_skills.append(s)
	spent_talent_points = maxi(0, int(data.get("spent_talent_points", 0)))
	total_talent_points = maxi(0, int(data.get("total_talent_points", 0)))
	return OK

func load_from_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	if res.get("error") != OK:
		return res.get("error", ERR_FILE_NOT_FOUND)
	var prof: Dictionary = res.get("profile", {})
	var char_data: Dictionary = prof.get("character", {})
	if char_data.has("kurei_tree") and char_data["kurei_tree"] is Dictionary:
		return deserialize(char_data["kurei_tree"])
	return OK

func save_to_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	var prof: Dictionary = {}
	if res.get("error") == ERR_FILE_NOT_FOUND:
		prof = store.new_profile(slot)
	elif res.get("error") == OK:
		prof = (res.get("profile", {}) as Dictionary).duplicate(true)
	else:
		return res.get("error", ERR_FILE_NOT_FOUND)
	if not prof.has("character") or not (prof["character"] is Dictionary):
		prof["character"] = {}
	prof["character"]["kurei_tree"] = serialize()
	return store.save_profile(slot, prof)
