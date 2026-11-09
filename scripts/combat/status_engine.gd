class_name StatusEngine
extends RefCounted

## StatusEngine — Turn-Based Combat Status Effect Controller
## Requirements: GDD-018/022/025, FR-CBT-003, AGENTS.md Invariants.
##
## Manages buff and debuff status lifecycles during turn-based combat:
## - POISON, BURN, BLEED (Damage over Time)
## - REGENERATION (Healing over Time)
## - SHIELD (Damage Absorption)
## - STUN (Turn loss)
## - SILENCE (Kurei/magic lock)
## - DEFENSE_UP, DEFENSE_DOWN (Damage mitigation modifiers)

signal status_applied(effect_type: String, duration: int, potency: int)
signal status_expired(effect_type: String)
signal damage_taken_from_status(effect_type: String, amount: int)
signal healed_from_status(effect_type: String, amount: int)

const EFFECT_POISON: String = "poison"
const EFFECT_BURN: String = "burn"
const EFFECT_BLEED: String = "bleed"
const EFFECT_REGENERATION: String = "regeneration"
const EFFECT_SHIELD: String = "shield"
const EFFECT_STUN: String = "stun"
const EFFECT_SILENCE: String = "silence"
const EFFECT_DEFENSE_UP: String = "defense_up"
const EFFECT_DEFENSE_DOWN: String = "defense_down"

const ALL_EFFECTS: Array[String] = [
	EFFECT_POISON,
	EFFECT_BURN,
	EFFECT_BLEED,
	EFFECT_REGENERATION,
	EFFECT_SHIELD,
	EFFECT_STUN,
	EFFECT_SILENCE,
	EFFECT_DEFENSE_UP,
	EFFECT_DEFENSE_DOWN
]

# Dictionary of effect_type -> { "duration": int, "potency": int, "stacks": int }
var active_effects: Dictionary = {}

func apply_status(effect_type: String, duration: int, potency: int = 1) -> void:
	if not ALL_EFFECTS.has(effect_type):
		return
	if duration <= 0:
		return

	if active_effects.has(effect_type):
		var cur: Dictionary = active_effects[effect_type]
		cur["duration"] = maxi(int(cur["duration"]), duration)
		cur["potency"] = maxi(int(cur["potency"]), potency)
		cur["stacks"] = int(cur.get("stacks", 1)) + 1
	else:
		active_effects[effect_type] = {
			"duration": duration,
			"potency": potency,
			"stacks": 1
		}
	status_applied.emit(effect_type, duration, potency)

func has_status(effect_type: String) -> bool:
	return active_effects.has(effect_type) and int(active_effects[effect_type]["duration"]) > 0

func get_potency(effect_type: String) -> int:
	if has_status(effect_type):
		return int(active_effects[effect_type].get("potency", 0))
	return 0

func remove_status(effect_type: String) -> void:
	if active_effects.has(effect_type):
		active_effects.erase(effect_type)
		status_expired.emit(effect_type)

func clear_all() -> void:
	var keys: Array = active_effects.keys()
	active_effects.clear()
	for k: String in keys:
		status_expired.emit(k)

## Evaluates effects that trigger at start of turn (DoTs, HoTs)
## Returns array of event dictionaries: { "effect": String, "damage": int, "heal": int }
func tick_turn_start() -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	# Poison damage
	if has_status(EFFECT_POISON):
		var dmg: int = get_potency(EFFECT_POISON)
		damage_taken_from_status.emit(EFFECT_POISON, dmg)
		events.append({"effect": EFFECT_POISON, "damage": dmg, "heal": 0})

	# Burn damage
	if has_status(EFFECT_BURN):
		var dmg: int = get_potency(EFFECT_BURN)
		damage_taken_from_status.emit(EFFECT_BURN, dmg)
		events.append({"effect": EFFECT_BURN, "damage": dmg, "heal": 0})

	# Regeneration healing
	if has_status(EFFECT_REGENERATION):
		var heal_amt: int = get_potency(EFFECT_REGENERATION)
		healed_from_status.emit(EFFECT_REGENERATION, heal_amt)
		events.append({"effect": EFFECT_REGENERATION, "damage": 0, "heal": heal_amt})

	return events

## Evaluates damage mitigation, shield absorption, and defense buffs/debuffs
## Returns the actual HP damage taken after shield and defense modifiers.
func process_incoming_damage(raw_damage: int) -> Dictionary:
	var final_damage: float = float(raw_damage)

	if has_status(EFFECT_DEFENSE_UP):
		final_damage *= 0.65 # 35% damage reduction

	if has_status(EFFECT_DEFENSE_DOWN):
		final_damage *= 1.35 # 35% increased damage taken

	var int_damage: int = maxi(1, int(round(final_damage)))
	var absorbed: int = 0

	# Shield absorption
	if has_status(EFFECT_SHIELD):
		var shield_val: int = get_potency(EFFECT_SHIELD)
		if shield_val >= int_damage:
			absorbed = int_damage
			active_effects[EFFECT_SHIELD]["potency"] = shield_val - int_damage
			int_damage = 0
			if active_effects[EFFECT_SHIELD]["potency"] <= 0:
				remove_status(EFFECT_SHIELD)
		else:
			absorbed = shield_val
			int_damage -= shield_val
			remove_status(EFFECT_SHIELD)

	return {
		"hp_damage": int_damage,
		"shield_absorbed": absorbed,
		"raw_damage": raw_damage
	}

## Decrements durations at end of turn; expires completed statuses
func tick_turn_end() -> Array[String]:
	var expired: Array[String] = []
	for effect: String in active_effects.keys():
		var data: Dictionary = active_effects[effect]
		data["duration"] = int(data["duration"]) - 1
		if int(data["duration"]) <= 0:
			expired.append(effect)

	for exp_effect: String in expired:
		active_effects.erase(exp_effect)
		status_expired.emit(exp_effect)

	return expired

func can_act() -> bool:
	return not has_status(EFFECT_STUN)

func can_use_skills() -> bool:
	return not has_status(EFFECT_SILENCE)

func serialize() -> Dictionary:
	return active_effects.duplicate(true)

func deserialize(data: Dictionary) -> void:
	active_effects = data.duplicate(true)
