class_name CharacterStats
extends RefCounted

## CharacterStats — SBL-W6-001 M3 character progression and attributes system.
## Requirements: GDD-005/006/007, GDD-026/027/028/029/030, GDD-098/099, FR-PRO-001,
## FR-PRG-001/002, TC-PRG-001.
##
## Manages Ren's attributes, experience points, level scaling, and persistent profile storage.
## Attributes:
##   - Vitality: Governs max HP and physical defense
##   - Resonance: Governs Kurei spirit power and spell potency
##   - Agility: Governs action frequency and evasion
##   - Focus: Governs precision, critical chance, and pip recovery
##
## OD-005 owner-approved progression (10 Nov 2026):
##   - Permanent level cap of 30 (GDD-029); XP to next level = 100 x current level.
##   - Every level-up awards exactly 2 attribute points (GDD-028); each allocation
##     adds +1 to Vitality, Resonance, Agility, or Focus and never anything else.
##   - Kurei talent points keep the approved max(0, level - 1) rule
##     (KureiTree.sync_with_level); this class grants no skill points of its own.
##   - XP is never negative and levels are never lost; at the cap no further XP or
##     level is awarded, so progression cannot inflate past the approved budget.
##   - Capability/access rewards are preferred over raw stat inflation: leveling
##     hands out only the approved attribute points, never automatic stat growth.

signal leveled_up(new_level: int, points_awarded: int)

const BASE_XP_PER_LEVEL: int = 100
const POINTS_PER_LEVEL: int = 2
const LEVEL_CAP: int = 30

const ATTR_VITALITY: StringName = &"vitality"
const ATTR_RESONANCE: StringName = &"resonance"
const ATTR_AGILITY: StringName = &"agility"
const ATTR_FOCUS: StringName = &"focus"

var level: int = 1
var xp: int = 0
var vitality: int = 10
var resonance: int = 10
var agility: int = 10
var focus: int = 10
var unspent_points: int = 0

func get_xp_for_next_level() -> int:
	return level * BASE_XP_PER_LEVEL

func is_at_level_cap() -> bool:
	return level >= LEVEL_CAP

## OD-005: awards XP toward the next level using the approved 100 x current level
## threshold. XP never goes negative, levels are never lost, and once the approved
## cap of 30 is reached no further XP or level is awarded (no raw inflation past
## the cap; leveling only ever grants the approved attribute points).
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	if level >= LEVEL_CAP:
		return 0
	xp += amount
	var levels_gained: int = 0
	while level < LEVEL_CAP and xp >= get_xp_for_next_level():
		xp -= get_xp_for_next_level()
		level += 1
		unspent_points += POINTS_PER_LEVEL
		levels_gained += 1
		leveled_up.emit(level, POINTS_PER_LEVEL)
	return levels_gained

func allocate_point(attribute: StringName) -> bool:
	if unspent_points <= 0:
		return false
	match attribute:
		ATTR_VITALITY:
			vitality += 1
		ATTR_RESONANCE:
			resonance += 1
		ATTR_AGILITY:
			agility += 1
		ATTR_FOCUS:
			focus += 1
		_:
			return false
	unspent_points -= 1
	return true

func get_max_hp() -> int:
	return vitality * 10

func get_spirit_power() -> int:
	return resonance * 5

func serialize() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"vitality": vitality,
		"resonance": resonance,
		"agility": agility,
		"focus": focus,
		"unspent_points": unspent_points,
		"max_hp": get_max_hp(),
		"spirit_power": get_spirit_power()
	}

func deserialize(data: Dictionary) -> Error:
	if not data.has("level") or not data.has("xp"):
		return ERR_INVALID_DATA
	if typeof(data["level"]) != TYPE_INT and typeof(data["level"]) != TYPE_FLOAT:
		return ERR_INVALID_DATA
	# OD-005: level is clamped into the approved [1, 30] range on load (never a
	# level loss below 1, never past the cap), and XP is clamped to >= 0.
	level = clampi(int(data["level"]), 1, LEVEL_CAP)
	xp = maxi(0, int(data.get("xp", 0)))
	vitality = maxi(1, int(data.get("vitality", 10)))
	resonance = maxi(1, int(data.get("resonance", 10)))
	agility = maxi(1, int(data.get("agility", 10)))
	focus = maxi(1, int(data.get("focus", 10)))
	unspent_points = maxi(0, int(data.get("unspent_points", 0)))
	return OK

func load_from_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	if res["error"] != OK:
		return res["error"]
	var prof: Dictionary = res["profile"]
	if not prof.has("character") or typeof(prof["character"]) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	return deserialize(prof["character"])

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
	prof["character"] = serialize()
	return store.save_profile(slot, prof)
