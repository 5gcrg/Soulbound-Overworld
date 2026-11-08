class_name KureiSystem
extends RefCounted

## KureiSystem — SBL-W7-001 M3 six Kurei magic categories and action pip mechanics.
## Requirements: GDD-009/010/011/012/013/014/015, FR-MAG-001.
##
## Categories:
##   - Flame: High burst damage, ignite status
##   - Torrent: Health restoration, purification, fluid defense
##   - Gale: Action acceleration, evasion, multi-hit
##   - Earth: Unyielding barrier, stagger, physical mitigation
##   - Lumina: True spirit sight, radiant pierce, focus amplification
##   - Umbra: Life drain, corruption curse, debuff amplification

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
	}
}

var cooldowns: Dictionary = {} # StringName -> int (turns remaining)

func get_skill(skill_id: StringName) -> Dictionary:
	return SKILL_CATALOG.get(skill_id, {})

func can_cast(skill_id: StringName, available_pips: int) -> bool:
	if not SKILL_CATALOG.has(skill_id):
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
