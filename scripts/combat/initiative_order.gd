class_name InitiativeOrder
extends RefCounted

## InitiativeOrder — OD-002 speed initiative engine (owner-approved combat batch).
## Requirements: GDD-016/017/018/023, GDD-030, FR-CMB-001/002/003, TC-CMB-001.
##
## Approved rules (docs/agy-next-queue.md, report/complete-od002-011-proposal.md):
## - Initiative equals effective Agility (authored base Agility + haste/slow modifier).
## - The actor with the higher effective Agility acts first.
## - Ties resolve by stable actor ID ascending (the ID assigned when the actor is
##   registered into the encounter, i.e. stable spawn order).
## - Every actor receives exactly one main action per round.
## - No ATB, extra turns, reaction attacks, or initiative rolls exist: ordering is a
##   pure, fully deterministic sort with no random input and no time input.
## - Haste/slow modifier changes apply at the next round boundary only; a round's
##   effective Agility is snapshotted in begin_round() and never mutated mid-round.
## - The battle HUD previews the next three actors (HUD_PREVIEW_COUNT).
##
## The engine holds no damage, cost, cooldown, or status formulas (OD-003/OD-004);
## it only orders actors and budgets one action per actor per round.

## OD-002: the battle HUD shows the next three actors.
const HUD_PREVIEW_COUNT: int = 3

## One-based index of the current round. Incremented by begin_round().
var round_index: int = 0

var _actors: Dictionary = {} # StringName -> { stable_id, registration, agility, modifier, display_name }
var _stable_id_counter: int = 0
var _registration_counter: int = 0
var _round_order: Array[StringName] = []
var _round_effective: Dictionary = {} # StringName -> effective Agility snapshotted for this round
var _acted_this_round: Dictionary = {} # StringName -> true once the actor spent its main action
var _cursor: int = 0

## Registers a combatant. The stable actor ID is assigned in registration (spawn)
## order, so equal effective Agility resolves deterministically by ascending ID.
func register_actor(actor_id: StringName, agility: int, display_name: String = "") -> void:
	if _actors.has(actor_id):
		var existing: Dictionary = _actors[actor_id]
		existing["agility"] = agility
		if display_name != "":
			existing["display_name"] = display_name
		return
	_actors[actor_id] = {
		"stable_id": _stable_id_counter,
		"registration": _registration_counter,
		"agility": agility,
		"modifier": 0,
		"display_name": display_name if display_name != "" else String(actor_id),
	}
	_stable_id_counter += 1
	_registration_counter += 1

func has_actor(actor_id: StringName) -> bool:
	return _actors.has(actor_id)

## Stable actor ID used for OD-002 tie resolution (ascending).
func get_stable_id(actor_id: StringName) -> int:
	if not _actors.has(actor_id):
		return -1
	return int((_actors[actor_id] as Dictionary).get("stable_id", -1))

## Authored base Agility. Like every other authored value it only affects ordering
## at the next round boundary (OD-002 haste/slow rule).
func set_actor_agility(actor_id: StringName, agility: int) -> void:
	if not _actors.has(actor_id):
		return
	(_actors[actor_id] as Dictionary)["agility"] = agility

func get_actor_agility(actor_id: StringName) -> int:
	if not _actors.has(actor_id):
		return 0
	return int((_actors[actor_id] as Dictionary).get("agility", 0))

## Haste/slow modifier applied to effective Agility. OD-002: a change made during a
## round is picked up at the next begin_round() only.
func set_modifier(actor_id: StringName, value: int) -> void:
	if not _actors.has(actor_id):
		return
	(_actors[actor_id] as Dictionary)["modifier"] = value

func get_modifier(actor_id: StringName) -> int:
	if not _actors.has(actor_id):
		return 0
	return int((_actors[actor_id] as Dictionary).get("modifier", 0))

## Effective Agility for the current round (snapshot taken by begin_round()).
func get_effective_agility(actor_id: StringName) -> int:
	if not _round_effective.has(actor_id):
		return 0
	return int(_round_effective[actor_id])

func set_display_name(actor_id: StringName, display_name: String) -> void:
	if not _actors.has(actor_id):
		return
	(_actors[actor_id] as Dictionary)["display_name"] = display_name

func get_display_name(actor_id: StringName) -> String:
	if not _actors.has(actor_id):
		return String(actor_id)
	return String((_actors[actor_id] as Dictionary).get("display_name", String(actor_id)))

## Opens the next round: snapshots effective Agility (base + haste/slow modifier),
## re-sorts by effective Agility desc / stable actor ID asc, and resets the per-round
## action budget. No rolls, no time input.
func begin_round() -> void:
	_round_effective.clear()
	for actor_id: StringName in _actors.keys():
		var record: Dictionary = _actors[actor_id]
		_round_effective[actor_id] = int(record.get("agility", 0)) + int(record.get("modifier", 0))

	_round_order.clear()
	for actor_id: StringName in _actors.keys():
		_round_order.append(actor_id)
	_round_order.sort_custom(_sort_by_initiative)

	_acting_round_reset()
	_cursor = 0
	round_index += 1

func _acting_round_reset() -> void:
	_acted_this_round.clear()

## Deterministic comparator: higher effective Agility first, then stable actor ID
## ascending, then registration order as a final total-order tiebreak.
func _sort_by_initiative(a: StringName, b: StringName) -> bool:
	var effective_a: int = int(_round_effective.get(a, 0))
	var effective_b: int = int(_round_effective.get(b, 0))
	if effective_a != effective_b:
		return effective_a > effective_b
	var stable_a: int = get_stable_id(a)
	var stable_b: int = get_stable_id(b)
	if stable_a != stable_b:
		return stable_a < stable_b
	return int((_actors[a] as Dictionary).get("registration", 0)) < int((_actors[b] as Dictionary).get("registration", 0))

func get_round_order() -> Array[StringName]:
	return _round_order.duplicate()

## The actor whose main action is due next, or &"" when the round is complete.
func current_actor() -> StringName:
	if _cursor < _round_order.size():
		return _round_order[_cursor]
	return &""

func has_acted(actor_id: StringName) -> bool:
	return _acted_this_round.has(actor_id)

## OD-002 one-main-action budget: an actor may act only while it has not spent its
## action in the current round.
func can_act(actor_id: StringName) -> bool:
	return _actors.has(actor_id) and not _acted_this_round.has(actor_id)

func is_round_complete() -> bool:
	return _cursor >= _round_order.size()

## Spends the actor's single main action for this round and advances the cursor.
## Returns false for unknown actors and for any second action in the same round
## (OD-002: no extra turns).
func record_action(actor_id: StringName) -> bool:
	if not can_act(actor_id):
		return false
	_acted_this_round[actor_id] = true
	while _cursor < _round_order.size() and _acted_this_round.has(_round_order[_cursor]):
		_cursor += 1
	return true

## OD-002 battle HUD preview: the next `count` actors to act, wrapping into the next
## round(s). The wrapped portion assumes the current effective Agility ordering and is
## recomputed by begin_round() at every round boundary.
func get_next_actors(count: int) -> Array[StringName]:
	var preview: Array[StringName] = []
	if _round_order.is_empty() or count <= 0:
		return preview
	var index: int = _cursor
	for i in count:
		preview.append(_round_order[index % _round_order.size()])
		index += 1
	return preview

## OD-002 battle HUD preview rendered as display names ("A > B > C").
func get_next_actor_names(count: int, separator: String = " > ") -> String:
	var names: Array[String] = []
	for actor_id: StringName in get_next_actors(count):
		names.append(get_display_name(actor_id))
	return separator.join(names)
