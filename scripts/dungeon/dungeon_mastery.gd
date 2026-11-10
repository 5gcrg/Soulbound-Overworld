class_name DungeonMastery
extends RefCounted

## DungeonMastery — SBL-OD-011 owner-approved dungeon mastery record.
## Requirements: GDD-046..048, FR-DNG-001, AGENTS.md Invariants.
##
## Owner-approved OD-011 rule: dungeon mastery grants knowledge/access MARKERS only, never
## uncapped combat power. This record therefore stores nothing but an ordered list of opaque
## marker identifiers:
##   - world["dungeon_mastery"] = {"schema": String, "markers": Array[String]}
##   - the strict schema rejects any additional key (a "power", "damage", "level" or other
##     stat field is never valid here), any non-string marker, duplicates and out-of-range
##     marker counts,
##   - this class has no API that touches CharacterStats, KureiTree, InventoryManager or any
##     combat value: granting a marker cannot change combat power.
##
## Marker identifiers are structural placeholders; the actual knowledge/access content that
## a marker unlocks stays TBD pending approved dungeon content (OD-011 content review).

const WORLD_KEY: String = "dungeon_mastery"
const SCHEMA_ID: String = "sbl-dungeon-mastery/1"
const ROOT_KEYS: Array[String] = ["schema", "markers"]

## Validation bounds (data-validation limits, not gameplay values).
const MAX_MARKERS: int = 1024
const MAX_MARKER_ID_LENGTH: int = 256

var markers: Array[String] = []

# ==============================================================================
# Public API
# ==============================================================================

## Records a knowledge/access marker. Idempotent: granting an existing marker is OK and
## never duplicates it. Error contract: ERR_INVALID_PARAMETER (empty or oversized id),
## ERR_PARAMETER_RANGE_ERROR (record capacity reached), otherwise OK.
func grant_marker(marker_id: String) -> Error:
	if marker_id.is_empty() or marker_id.length() > MAX_MARKER_ID_LENGTH:
		return ERR_INVALID_PARAMETER
	if markers.size() >= MAX_MARKERS:
		return ERR_PARAMETER_RANGE_ERROR
	if markers.has(marker_id):
		return OK
	markers.append(marker_id)
	return OK

func has_marker(marker_id: String) -> bool:
	return markers.has(marker_id)

func marker_count() -> int:
	return markers.size()

# ==============================================================================
# Serialization
# ==============================================================================

func serialize() -> Dictionary:
	return {"schema": SCHEMA_ID, "markers": markers.duplicate()}

## Strict structural parse: exact keys, schema id, unique non-empty bounded string markers.
## State is applied only on OK.
func deserialize(value: Variant) -> Error:
	var parsed: Dictionary = _parse(value)
	if parsed["error"] != OK:
		return parsed["error"]
	var raw: Array = parsed["markers"]
	var next_markers: Array[String] = []
	for marker_variant: Variant in raw:
		next_markers.append(String(marker_variant))
	markers = next_markers
	return OK

## Validates the dungeon-mastery record in isolation (backup/import boundary).
static func validate_record(value: Variant) -> Error:
	return _parse(value)["error"]

## Validates the optional world[WORLD_KEY] record inside a profile. An absent record is
## valid (profiles that never cleared a dungeon simply carry no mastery record).
static func validate_profile(profile: Dictionary) -> Error:
	if typeof(profile) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var world_value: Variant = profile.get("world", {})
	if typeof(world_value) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var world: Dictionary = world_value as Dictionary
	if not world.has(WORLD_KEY):
		return OK
	return validate_record(world[WORLD_KEY])

func load_from_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	if res["error"] != OK:
		return res["error"]
	var profile: Dictionary = res["profile"] as Dictionary
	var world_value: Variant = profile.get("world", {})
	if typeof(world_value) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var world: Dictionary = world_value as Dictionary
	if not world.has(WORLD_KEY):
		markers = []
		return OK
	return deserialize(world[WORLD_KEY])

func save_to_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	var profile: Dictionary = {}
	if res["error"] == ERR_FILE_NOT_FOUND:
		profile = store.new_profile(slot)
		if profile.is_empty():
			return ERR_INVALID_PARAMETER
	elif res["error"] == OK:
		profile = (res["profile"] as Dictionary).duplicate(true)
	else:
		return res["error"]
	var world: Dictionary = profile.get("world", {})
	if typeof(world) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	world[WORLD_KEY] = serialize()
	profile["world"] = world
	return store.save_profile(slot, profile)

# ==============================================================================
# Strict structural parsing
# ==============================================================================

static func _parse(value: Variant) -> Dictionary:
	var bad: Dictionary = {"error": ERR_INVALID_DATA, "markers": []}
	if typeof(value) != TYPE_DICTIONARY:
		return bad
	var data: Dictionary = value as Dictionary
	if not _exact_keys(data, ROOT_KEYS):
		return bad
	if typeof(data["schema"]) != TYPE_STRING or String(data["schema"]) != SCHEMA_ID:
		return bad
	if typeof(data["markers"]) != TYPE_ARRAY:
		return bad
	var raw: Array = data["markers"] as Array
	if raw.size() > MAX_MARKERS:
		return bad
	var seen: Dictionary = {}
	var parsed: Array = []
	for marker_variant: Variant in raw:
		if typeof(marker_variant) != TYPE_STRING:
			return bad
		var marker_id: String = String(marker_variant)
		if marker_id.is_empty() or marker_id.length() > MAX_MARKER_ID_LENGTH:
			return bad
		if seen.has(marker_id):
			return bad
		seen[marker_id] = true
		parsed.append(marker_id)
	return {"error": OK, "markers": parsed}

static func _exact_keys(d: Dictionary, keys: Array[String]) -> bool:
	if d.size() != keys.size():
		return false
	for key: String in keys:
		if not d.has(key):
			return false
	return true
