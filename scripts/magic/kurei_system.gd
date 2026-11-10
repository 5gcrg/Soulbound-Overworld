class_name KureiSystem
extends RefCounted

## KureiSystem — SBL-W7-001 M3 six Kurei magic categories and action pip mechanics.
## Requirements: GDD-009/010/011/012/013/014/015, GDD-019/021/030, FR-MAG-001,
## OD-003 (owner-approved combat batch).
##
## Categories and OD-003 roles (identity only; no rock-paper-scissors multiplier
## chart exists in the academic MVP and no hidden elemental multiplier is applied):
##   - Flame: damage/Burn
##   - Torrent: heal/cleanse
##   - Gale: haste/evasion
##   - Earth: shield/mitigation
##   - Lumina: pierce/focus
##   - Umbra: drain/debuff
##
## Skill magnitude uses the authored base_power below; pip costs, cooldowns and
## base_power values are authored content and are not rescaled by this slice.
## SP baselines (BattleFixture 2 / BossEncounter 3, Phase Mastery 4) live with their
## scenes and KureiTree; no regeneration, critical, resistance or boss-effect
## formula is defined here (unsupported advanced boss effects stay disabled).

const CAT_FLAME: StringName = &"flame"
const CAT_TORRENT: StringName = &"torrent"
const CAT_GALE: StringName = &"gale"
const CAT_EARTH: StringName = &"earth"
const CAT_LUMINA: StringName = &"lumina"
const CAT_UMBRA: StringName = &"umbra"

const ALL_CATEGORIES: Array[StringName] = [
	CAT_FLAME,
	CAT_TORRENT,
	CAT_GALE,
	CAT_EARTH,
	CAT_LUMINA,
	CAT_UMBRA
]

## OD-003 approved role per category (identity strings, no numeric effect):
## no counter-chart, weakness multiplier, resistance matrix or affinity multiplier
## exists anywhere in the academic MVP.
const CATEGORY_ROLES: Dictionary = {
	CAT_FLAME: "damage/Burn",
	CAT_TORRENT: "heal/cleanse",
	CAT_GALE: "haste/evasion",
	CAT_EARTH: "shield/mitigation",
	CAT_LUMINA: "pierce/focus",
	CAT_UMBRA: "drain/debuff"
}

## Baseline catalog of approved skills (1 starter skill per category)
const SKILL_CATALOG: Dictionary = {
	&"flame_burst": {
		"id": &"flame_burst",
		"name": "Flame Burst",
		"category": CAT_FLAME,
		"pip_cost": 2,
		"cooldown_turns": 2,
		"base_power": 18,
		"effect": "burn"
	},
	&"torrent_surge": {
		"id": &"torrent_surge",
		"name": "Torrent Surge",
		"category": CAT_TORRENT,
		"pip_cost": 2,
		"cooldown_turns": 3,
		"base_power": 12,
		"effect": "heal"
	},
	&"gale_flurry": {
		"id": &"gale_flurry",
		"name": "Gale Flurry",
		"category": CAT_GALE,
		"pip_cost": 1,
		"cooldown_turns": 1,
		"base_power": 10,
		"effect": "haste"
	},
	&"earth_bastion": {
		"id": &"earth_bastion",
		"name": "Earth Bastion",
		"category": CAT_EARTH,
		"pip_cost": 2,
		"cooldown_turns": 3,
		"base_power": 0,
		"effect": "shield"
	},
	&"lumina_lance": {
		"id": &"lumina_lance",
		"name": "Lumina Lance",
		"category": CAT_LUMINA,
		"pip_cost": 1,
		"cooldown_turns": 2,
		"base_power": 14,
		"effect": "pierce"
	},
	&"umbra_drain": {
		"id": &"umbra_drain",
		"name": "Umbra Drain",
		"category": CAT_UMBRA,
		"pip_cost": 2,
		"cooldown_turns": 3,
		"base_power": 12,
		"effect": "drain"
	},
	&"solar_flare": {
		"id": &"solar_flare",
		"name": "Solar Flare",
		"category": CAT_FLAME,
		"pip_cost": 3,
		"cooldown_turns": 3,
		"base_power": 28,
		"effect": "burn"
	},
	&"celestial_prism": {
		"id": &"celestial_prism",
		"name": "Celestial Prism",
		"category": CAT_LUMINA,
		"pip_cost": 2,
		"cooldown_turns": 3,
		"base_power": 20,
		"effect": "stun"
	},
	&"glacial_aegis": {
		"id": &"glacial_aegis",
		"name": "Glacial Aegis",
		"category": CAT_TORRENT,
		"pip_cost": 2,
		"cooldown_turns": 3,
		"base_power": 16,
		"effect": "shield"
	},
	&"void_shift": {
		"id": &"void_shift",
		"name": "Void Shift",
		"category": CAT_UMBRA,
		"pip_cost": 1,
		"cooldown_turns": 2,
		"base_power": 10,
		"effect": "evade"
	},
	&"phase_mastery": {
		"id": &"phase_mastery",
		"name": "Phase Mastery",
		"category": CAT_UMBRA,
		"pip_cost": 0,
		"cooldown_turns": 0,
		"base_power": 0,
		"effect": "mastery",
		"passive": true
	}
}

## OD-003 role of a category ("damage/Burn", ... ). Unknown categories return "".
func get_category_role(category: StringName) -> String:
	return String(CATEGORY_ROLES.get(category, ""))

## OD-003 role of a skill, derived from its authored category.
func get_skill_role(skill_id: StringName) -> String:
	if not SKILL_CATALOG.has(skill_id):
		return ""
	return get_category_role(StringName((SKILL_CATALOG[skill_id] as Dictionary).get("category", &"")))

var cooldowns: Dictionary = {} # StringName -> int (turns remaining)

func is_skill_passive(skill_id: StringName) -> bool:
	if skill_id == &"phase_mastery":
		return true
	if SKILL_CATALOG.has(skill_id):
		var node: Dictionary = SKILL_CATALOG[skill_id]
		return bool(node.get("passive", false)) or String(node.get("effect", "")) == "mastery"
	return false

func get_skill(skill_id: StringName) -> Dictionary:
	return SKILL_CATALOG.get(skill_id, {})

func can_cast(skill_id: StringName, available_pips: int) -> bool:
	if not SKILL_CATALOG.has(skill_id):
		return false
	if is_skill_passive(skill_id):
		return false
	if cooldowns.get(skill_id, 0) > 0:
		return false
	var skill: Dictionary = SKILL_CATALOG[skill_id]
	return available_pips >= int(skill.get("pip_cost", 1))

func cast_skill(skill_id: StringName, available_pips: int) -> Dictionary:
	if not can_cast(skill_id, available_pips):
		return {"error": ERR_UNAVAILABLE}
	var skill: Dictionary = SKILL_CATALOG[skill_id]
	var cost: int = int(skill.get("pip_cost", 1))
	var cd: int = int(skill.get("cooldown_turns", 0))
	cooldowns[skill_id] = cd
	return {
		"error": OK,
		"skill_id": skill_id,
		"pip_cost": cost,
		"base_power": int(skill.get("base_power", 0)),
		"effect": String(skill.get("effect", "")),
		"cooldown": cd
	}

func tick_cooldowns() -> void:
	var expired: Array[StringName] = []
	for sid: StringName in cooldowns.keys():
		var remaining: int = cooldowns[sid] - 1
		if remaining <= 0:
			expired.append(sid)
		else:
			cooldowns[sid] = remaining
	for sid: StringName in expired:
		cooldowns.erase(sid)

func reset_cooldowns() -> void:
	cooldowns.clear()
