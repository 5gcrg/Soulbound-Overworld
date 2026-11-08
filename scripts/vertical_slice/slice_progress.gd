class_name SliceProgress
extends RefCounted

## SliceProgress — SBL-W4-001 M2 one-region vertical slice progress (fixture state machine).
##
## Requirements: GDD-067/068/069/071/098/099/100, FR-QST-001, FR-EDU-002/003, FR-SAV-001 (partial),
## TC-EDU-002/003, TC-SAV-001.
##
## Persists through a caller-supplied, versioned ProfileStore. Owned data lives ONLY in two
## fixture-keyed records; no other section or key is ever created, modified or removed:
##   world["vertical_slice"]     = {"fixture_id": String, "stage": "practice"|"battle"|"turn_in"|"complete"}
##   education["vertical_slice"] = {"fixture_id": String, "first_choice": "match"|"mismatch",
##                                  "first_attempt_correct": bool, "assessed": false}
## Absent world record == Stage.OFFERED (never written until accept_quest()).
## Absent education record == no practice response yet (written atomically with the BATTLE advance).
## The practice step is a non-assessed UI demo: zero rewards, no stats/quests/lore, no combat or
## expedition state. Stage TURN_IN is the sole persisted victory checkpoint.

enum Stage { OFFERED, PRACTICE, BATTLE, TURN_IN, COMPLETE }

const SLICE_KEY: String = "vertical_slice"
const FIXTURE_ID: String = "sbl_w4_001_one_region_slice"
const CHOICE_MATCH: String = "match"
const CHOICE_MISMATCH: String = "mismatch"

const _WORLD_KEYS: Array[String] = ["fixture_id", "stage"]
const _EDU_KEYS: Array[String] = ["fixture_id", "first_choice", "first_attempt_correct", "assessed"]
const _STAGE_NAMES: Dictionary = {
	Stage.PRACTICE: "practice",
	Stage.BATTLE: "battle",
	Stage.TURN_IN: "turn_in",
	Stage.COMPLETE: "complete",
}

var _store: ProfileStore = null
var _slot: String = "profile_01"
var _profile: Dictionary = {}
var _ready: bool = false
var _recovered: bool = false
var _stage: Stage = Stage.OFFERED
var _first_choice: String = ""
var _attempt_correct: bool = false

## True only after configure() fully succeeded. Transitions fail closed while false.
var ready: bool:
	get:
		return _ready
	set(_value):
		pass

## Current slice stage (read-only).
var stage: Stage:
	get:
		return _stage
	set(_value):
		pass

## First practice response ("match"/"mismatch"); "" until finish_practice() succeeds (read-only).
var first_choice: String:
	get:
		return _first_choice
	set(_value):
		pass

## Immutable first-attempt correctness; false until recorded (read-only).
var attempt_correct: bool:
	get:
		return _attempt_correct
	set(_value):
		pass

## True when the loaded profile came from a ProfileStore backup revision (read-only).
var recovered_from_backup: bool:
	get:
		return _recovered
	set(_value):
		pass

# ==============================================================================
# Public API
# ==============================================================================

## Loads the slot profile. Only ERR_FILE_NOT_FOUND creates an in-memory (unwritten) new profile.
## Any other store error, or an invalid owned record, leaves ready == false and writes nothing.
func configure(store: ProfileStore, slot: String = "profile_01") -> Error:
	_reset_state()
	if store == null:
		return ERR_INVALID_PARAMETER
	var loaded: Dictionary = store.load_profile(slot)
	var load_err: Error = loaded["error"]
	var profile: Dictionary = {}
	var recovered: bool = false
	if load_err == ERR_FILE_NOT_FOUND:
		profile = store.new_profile(slot)
		if profile.is_empty():
			return ERR_INVALID_PARAMETER
	elif load_err != OK:
		return load_err
	else:
		if typeof(loaded["profile"]) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		profile = (loaded["profile"] as Dictionary).duplicate(true)
		recovered = bool(loaded["recovered"])
	var parsed: Dictionary = _parse_owned(profile)
	if parsed["error"] != OK:
		return parsed["error"]
	_store = store
	_slot = slot
	_profile = profile
	_recovered = recovered
	_apply_state(parsed)
	_ready = true
	return OK

## OFFERED -> PRACTICE.
func accept_quest() -> Error:
	return _transition(Stage.OFFERED, Stage.PRACTICE)

## PRACTICE -> BATTLE. Accepts exactly "match" (correct) or "mismatch" (incorrect). The first response
## and its correctness persist together with the stage advance, even when incorrect (completion-gated,
## not score-gated). The record is never rewritten.
func finish_practice(choice: String) -> Error:
	if choice != CHOICE_MATCH and choice != CHOICE_MISMATCH:
		return ERR_INVALID_PARAMETER
	return _transition(Stage.PRACTICE, Stage.BATTLE, choice)

## BATTLE -> TURN_IN. Persists only the victory checkpoint; no combat/expedition state.
func record_victory() -> Error:
	return _transition(Stage.BATTLE, Stage.TURN_IN)

## TURN_IN -> COMPLETE. Grants nothing (zero rewards).
func turn_in() -> Error:
	return _transition(Stage.TURN_IN, Stage.COMPLETE)

# ==============================================================================
# Transition pipeline
# ==============================================================================

## Error contract: ERR_UNCONFIGURED (not ready), ERR_INVALID_PARAMETER (bad choice),
## ERR_UNAVAILABLE (stage not reached yet), ERR_ALREADY_EXISTS (duplicate / stage already passed),
## otherwise the ProfileStore save error. No state changes and no save unless the save returns OK.
func _transition(expected: Stage, next: Stage, choice: String = "") -> Error:
	if not _ready or _store == null:
		return ERR_UNCONFIGURED
	if _stage < expected:
		return ERR_UNAVAILABLE
	if _stage > expected:
		return ERR_ALREADY_EXISTS

	var candidate: Dictionary = _profile.duplicate(true)
	var world: Dictionary = candidate["world"] as Dictionary
	world[SLICE_KEY] = {"fixture_id": FIXTURE_ID, "stage": _STAGE_NAMES[next]}
	var correct: bool = false
	if expected == Stage.PRACTICE:
		correct = (choice == CHOICE_MATCH)
		var education: Dictionary = candidate["education"] as Dictionary
		education[SLICE_KEY] = {
			"fixture_id": FIXTURE_ID,
			"first_choice": choice,
			"first_attempt_correct": correct,
			"assessed": false,
		}

	# Never persist anything this class would itself refuse to load.
	var check: Dictionary = _parse_owned(candidate)
	if check["error"] != OK or check["stage"] != next:
		return ERR_INVALID_DATA
	var save_err: Error = _store.save_profile(_slot, candidate)
	if save_err != OK:
		return save_err
	_profile = candidate
	_apply_state(check)
	return OK

# ==============================================================================
# Owned-record validation
# ==============================================================================

## Validates only the two owned records and their cross-record consistency. Unrelated keys and
## sections are ignored. Returns {"error", "stage", "choice", "correct"}; ERR_INVALID_DATA on any defect.
func _parse_owned(profile: Dictionary) -> Dictionary:
	var bad: Dictionary = {"error": ERR_INVALID_DATA, "stage": Stage.OFFERED, "choice": "", "correct": false}
	if typeof(profile.get("world")) != TYPE_DICTIONARY or typeof(profile.get("education")) != TYPE_DICTIONARY:
		return bad
	var world: Dictionary = profile["world"] as Dictionary
	var education: Dictionary = profile["education"] as Dictionary

	var stage_value: Stage = Stage.OFFERED
	if world.has(SLICE_KEY):
		var parsed_stage: int = _parse_world_record(world[SLICE_KEY])
		if parsed_stage < 0:
			return bad
		stage_value = parsed_stage as Stage

	var has_response: bool = education.has(SLICE_KEY)
	var needs_response: bool = stage_value >= Stage.BATTLE
	if has_response != needs_response:
		return bad
	var choice: String = ""
	var correct: bool = false
	if has_response:
		var rec: Variant = education[SLICE_KEY]
		if typeof(rec) != TYPE_DICTIONARY or not _has_exact_keys(rec as Dictionary, _EDU_KEYS):
			return bad
		var d: Dictionary = rec as Dictionary
		if typeof(d["fixture_id"]) != TYPE_STRING or d["fixture_id"] != FIXTURE_ID:
			return bad
		if typeof(d["first_choice"]) != TYPE_STRING:
			return bad
		choice = d["first_choice"]
		if choice != CHOICE_MATCH and choice != CHOICE_MISMATCH:
			return bad
		if typeof(d["first_attempt_correct"]) != TYPE_BOOL:
			return bad
		correct = d["first_attempt_correct"]
		if correct != (choice == CHOICE_MATCH):
			return bad
		if typeof(d["assessed"]) != TYPE_BOOL or d["assessed"] != false:
			return bad
	return {"error": OK, "stage": stage_value, "choice": choice, "correct": correct}

## Returns the Stage int for a valid stored world record, or -1. Stage values are exact strings only.
func _parse_world_record(rec: Variant) -> int:
	if typeof(rec) != TYPE_DICTIONARY or not _has_exact_keys(rec as Dictionary, _WORLD_KEYS):
		return -1
	var d: Dictionary = rec as Dictionary
	if typeof(d["fixture_id"]) != TYPE_STRING or d["fixture_id"] != FIXTURE_ID:
		return -1
	if typeof(d["stage"]) != TYPE_STRING:
		return -1
	for key in _STAGE_NAMES.keys():
		if _STAGE_NAMES[key] == d["stage"]:
			return int(key)
	return -1

func _has_exact_keys(d: Dictionary, keys: Array[String]) -> bool:
	if d.size() != keys.size():
		return false
	for k in keys:
		if not d.has(k):
			return false
	return true

func _apply_state(parsed: Dictionary) -> void:
	_stage = parsed["stage"]
	_first_choice = parsed["choice"]
	_attempt_correct = parsed["correct"]

func _reset_state() -> void:
	_store = null
	_slot = "profile_01"
	_profile = {}
	_ready = false
	_recovered = false
	_stage = Stage.OFFERED
	_first_choice = ""
	_attempt_correct = false
