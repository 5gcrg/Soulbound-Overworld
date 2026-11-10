class_name QuestBranchModel
extends RefCounted

## QuestBranchModel — SBL-OD-010 owner-approved branch-and-reconverge quest structure.
## Requirements: GDD-036..041 (structure only), FR-QST-001, FR-WLD-001, AGENTS.md Invariants.
##
## Owner-approved OD-010 structure (docs/agy-next-queue.md; report/complete-od002-011-proposal.md
## Stage C; report/final-plan-specifications.md Stage 3):
##   - Academic MVP: Chapters I-III stay linear. No local choice cluster can be recorded and no
##     gate marker can be written while the model is in "academic_mvp" mode, so the 3-chapter
##     academic path cannot acquire branch state.
##   - Full release: at most ONE local choice cluster per chapter (MAX_CLUSTERS_PER_CHAPTER),
##     and every cluster reconverges at the next chapter gate. After the gate the chapter is
##     frozen: the recorded outcome is retained exactly, but no new local choice is accepted.
##   - Reputation/faction systems stay deferred from the academic MVP: the record carries no
##     reputation or faction field and the strict schema rejects any key outside the approved
##     structure (backup imports included).
##
## This class stores STRUCTURE ONLY. cluster_id / branch_id are opaque structural identifiers
## that future approved content must supply; no dialogue, lore, NPC roster, villain identity,
## ending trigger, faction roster or educational content lives here (OD-001/OD-010 content and
## GDD-061..066 question content remain blocked and unchanged). The academic chapter path in
## ChapterManager / GameRoot is untouched: nothing here is wired into the MVP play flow.

signal branch_recorded(chapter: int, cluster_id: String, branch_id: String)
signal chapter_reconverged(chapter: int)

const WORLD_KEY: String = "quest_branches"
const SCHEMA_ID: String = "sbl-quest-branches/1"

const MODE_ACADEMIC_MVP: String = ReleaseTier.TIER_ACADEMIC_MVP
const MODE_FULL_RELEASE: String = ReleaseTier.TIER_FULL_RELEASE

## Owner-approved: one local choice cluster per chapter (full release only).
const MAX_CLUSTERS_PER_CHAPTER: int = 1
## Structural bound from the AGENTS.md invariant: 5-chapter full release.
const FULL_RELEASE_CHAPTERS: int = 5
## Validation bounds (data-validation limits, not gameplay values).
const MAX_RECORDS: int = 64
const MAX_ID_LENGTH: int = 128

const ROOT_KEYS: Array[String] = ["schema", "mode", "clusters", "reconverged_chapters"]
const CLUSTER_KEYS: Array[String] = ["chapter", "cluster_id", "branch_id", "reconverged"]

var mode: String = MODE_ACADEMIC_MVP
var clusters: Array[Dictionary] = []
var reconverged_chapters: Array[int] = []

# ==============================================================================
# Public API
# ==============================================================================

## Selects the structural mode. Switching to the academic MVP is refused when any
## branch or gate state already exists (the linear MVP cannot carry branch data).
func configure(new_mode: String) -> Error:
	if new_mode != MODE_ACADEMIC_MVP and new_mode != MODE_FULL_RELEASE:
		return ERR_INVALID_PARAMETER
	if new_mode == MODE_ACADEMIC_MVP and (not clusters.is_empty() or not reconverged_chapters.is_empty()):
		return ERR_INVALID_DATA
	mode = new_mode
	return OK

## Records one local choice cluster outcome for a chapter (full release only).
## Error contract: ERR_UNAVAILABLE (academic MVP linear / chapter gate already reconverged),
## ERR_INVALID_PARAMETER (chapter out of range or empty identifier), ERR_PARAMETER_RANGE_ERROR
## (identifier too long or record capacity reached), ERR_ALREADY_EXISTS (a different cluster
## for the same chapter - the first local choice is retained), otherwise OK (idempotent
## re-record of the identical outcome).
func record_choice(chapter: int, cluster_id: String, branch_id: String) -> Error:
	if mode != MODE_FULL_RELEASE:
		return ERR_UNAVAILABLE
	if chapter < 1 or chapter > FULL_RELEASE_CHAPTERS:
		return ERR_INVALID_PARAMETER
	if cluster_id.is_empty() or branch_id.is_empty():
		return ERR_INVALID_PARAMETER
	if cluster_id.length() > MAX_ID_LENGTH or branch_id.length() > MAX_ID_LENGTH:
		return ERR_PARAMETER_RANGE_ERROR
	if reconverged_chapters.has(chapter):
		return ERR_UNAVAILABLE
	for rec: Dictionary in clusters:
		if int(rec["chapter"]) == chapter:
			if String(rec["cluster_id"]) == cluster_id and String(rec["branch_id"]) == branch_id:
				return OK
			return ERR_ALREADY_EXISTS
	if clusters.size() >= MAX_RECORDS:
		return ERR_PARAMETER_RANGE_ERROR
	clusters.append({
		"chapter": chapter,
		"cluster_id": cluster_id,
		"branch_id": branch_id,
		"reconverged": false,
	})
	branch_recorded.emit(chapter, cluster_id, branch_id)
	return OK

## Reconverges the chapter's local choice cluster at the chapter gate: the outcome stays
## persisted exactly, the cluster is marked reconverged and the chapter freezes.
## Error contract: ERR_UNAVAILABLE (academic MVP), ERR_INVALID_PARAMETER (chapter out of
## range), ERR_ALREADY_EXISTS (the gate already reconverged), otherwise OK.
func reconverge_at_gate(chapter: int) -> Error:
	if mode != MODE_FULL_RELEASE:
		return ERR_UNAVAILABLE
	if chapter < 1 or chapter > FULL_RELEASE_CHAPTERS:
		return ERR_INVALID_PARAMETER
	if reconverged_chapters.has(chapter):
		return ERR_ALREADY_EXISTS
	for rec: Dictionary in clusters:
		if int(rec["chapter"]) == chapter:
			rec["reconverged"] = true
	reconverged_chapters.append(chapter)
	chapter_reconverged.emit(chapter)
	return OK

## Returns the stored cluster record for a chapter, or {} when none exists.
func get_cluster(chapter: int) -> Dictionary:
	for rec: Dictionary in clusters:
		if int(rec["chapter"]) == chapter:
			return rec.duplicate(true)
	return {}

func is_reconverged(chapter: int) -> bool:
	return reconverged_chapters.has(chapter)

func cluster_count() -> int:
	return clusters.size()

# ==============================================================================
# Serialization
# ==============================================================================

func serialize() -> Dictionary:
	return {
		"schema": SCHEMA_ID,
		"mode": mode,
		"clusters": clusters.duplicate(true),
		"reconverged_chapters": reconverged_chapters.duplicate(),
	}

## Strict structural parse. Any key outside ROOT_KEYS / CLUSTER_KEYS (for example a
## deferred reputation or faction field), any malformed chapter or any cross-record
## inconsistency is rejected with ERR_INVALID_DATA. State is applied only on OK.
func deserialize(value: Variant) -> Error:
	var parsed: Dictionary = _parse(value)
	if parsed["error"] != OK:
		return parsed["error"]
	mode = String(parsed["mode"])
	var parsed_clusters: Array = parsed["clusters"]
	var next_clusters: Array[Dictionary] = []
	for rec_variant: Variant in parsed_clusters:
		next_clusters.append((rec_variant as Dictionary).duplicate(true))
	clusters = next_clusters
	var parsed_gates: Array = parsed["reconverged_chapters"]
	var next_gates: Array[int] = []
	for gate_variant: Variant in parsed_gates:
		next_gates.append(int(gate_variant))
	reconverged_chapters = next_gates
	return OK

## Validates a quest-branch record in isolation (backup/import boundary).
static func validate_record(value: Variant) -> Error:
	return _parse(value)["error"]

## Validates the optional world[WORLD_KEY] record inside a profile. An absent record is
## valid (fresh and academic-MVP profiles simply carry no branch state).
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
		# Absent record == no branch state (linear academic MVP profile).
		mode = MODE_ACADEMIC_MVP
		clusters = []
		reconverged_chapters = []
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
	var bad: Dictionary = {"error": ERR_INVALID_DATA, "mode": "", "clusters": [], "reconverged_chapters": []}
	if typeof(value) != TYPE_DICTIONARY:
		return bad
	var data: Dictionary = value as Dictionary
	if not _exact_keys(data, ROOT_KEYS):
		return bad
	if typeof(data["schema"]) != TYPE_STRING or String(data["schema"]) != SCHEMA_ID:
		return bad
	if typeof(data["mode"]) != TYPE_STRING:
		return bad
	var parsed_mode: String = String(data["mode"])
	if parsed_mode != MODE_ACADEMIC_MVP and parsed_mode != MODE_FULL_RELEASE:
		return bad
	if typeof(data["clusters"]) != TYPE_ARRAY or typeof(data["reconverged_chapters"]) != TYPE_ARRAY:
		return bad

	var raw_clusters: Array = data["clusters"] as Array
	if raw_clusters.size() > MAX_RECORDS:
		return bad
	var parsed_clusters: Array = []
	var seen_chapters: Dictionary = {}
	for rec_variant: Variant in raw_clusters:
		if typeof(rec_variant) != TYPE_DICTIONARY:
			return bad
		var rec: Dictionary = rec_variant as Dictionary
		if not _exact_keys(rec, CLUSTER_KEYS):
			return bad
		if not _is_int(rec["chapter"]):
			return bad
		var chapter: int = int(rec["chapter"])
		if chapter < 1 or chapter > FULL_RELEASE_CHAPTERS:
			return bad
		if seen_chapters.has(chapter):
			return bad
		seen_chapters[chapter] = true
		if typeof(rec["cluster_id"]) != TYPE_STRING or typeof(rec["branch_id"]) != TYPE_STRING:
			return bad
		var cluster_id: String = String(rec["cluster_id"])
		var branch_id: String = String(rec["branch_id"])
		if cluster_id.is_empty() or branch_id.is_empty():
			return bad
		if cluster_id.length() > MAX_ID_LENGTH or branch_id.length() > MAX_ID_LENGTH:
			return bad
		if typeof(rec["reconverged"]) != TYPE_BOOL:
			return bad
		parsed_clusters.append(rec)

	var parsed_gates: Array = []
	var seen_gates: Dictionary = {}
	var raw_gates: Array = data["reconverged_chapters"] as Array
	if raw_gates.size() > MAX_RECORDS:
		return bad
	for gate_variant: Variant in raw_gates:
		if not _is_int(gate_variant):
			return bad
		var gate: int = int(gate_variant)
		if gate < 1 or gate > FULL_RELEASE_CHAPTERS:
			return bad
		if seen_gates.has(gate):
			return bad
		seen_gates[gate] = true
		parsed_gates.append(gate)

	# Academic MVP must stay linear: no clusters, no gate markers.
	if parsed_mode == MODE_ACADEMIC_MVP and (not parsed_clusters.is_empty() or not parsed_gates.is_empty()):
		return bad
	# A cluster is reconverged exactly when its chapter gate has reconverged.
	for rec: Dictionary in parsed_clusters:
		if bool(rec["reconverged"]) != seen_gates.has(int(rec["chapter"])):
			return bad
	return {"error": OK, "mode": parsed_mode, "clusters": parsed_clusters, "reconverged_chapters": parsed_gates}

static func _exact_keys(d: Dictionary, keys: Array[String]) -> bool:
	if d.size() != keys.size():
		return false
	for key: String in keys:
		if not d.has(key):
			return false
	return true

static func _is_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var f: float = float(value)
		return is_finite(f) and not is_nan(f) and floor(f) == f
	return false
