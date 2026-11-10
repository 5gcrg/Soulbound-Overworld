class_name MultiFloorLayout
extends RefCounted

## MultiFloorLayout — SBL-OD-011 owner-approved full-release dungeon structure validator
## and seeded structure generator.
## Requirements: GDD-042..048, FR-DNG-001/003, TC-DNG-001, AGENTS.md Invariants.
##
## Owner-approved OD-011 structure (docs/agy-next-queue.md; report/complete-od002-011-proposal.md
## Stage C; report/final-plan-specifications.md Stage 3):
##   - Academic MVP keeps the existing seeded exploration DAG in DungeonGenerator /
##     DungeonExpedition. Nothing in this class is wired into the MVP expedition flow.
##   - Full-release proposal: FLOOR_COUNT floors with ROOMS_PER_FLOOR generated room slots
##     per floor, exactly one entry (spawn), at least one valid route, and exactly one
##     extraction endpoint.
##   - A seed that produces a disconnected graph, or an extraction that is unreachable from
##     the entry, is INVALID (validate_layout returns ERR_INVALID_DATA).
##   - Room types reuse ONLY the existing DungeonGenerator types (spawn / normal / combat /
##     extraction); no new room type, reward path, drop table or probability exists here.
##     An optional risk room may only be flagged on an existing reward-path room (normal or
##     combat) and adds no reward value of its own - reward-value increases stay TBD pending
##     approved content.
##   - Generation is seeded and deterministic (same seed -> identical layout) and uses the
##     same head-growing connection grammar as the academic MVP generator.

const SCHEMA_ID: String = "sbl-multi-floor-layout/1"

## Owner-approved full-release proposal: 3 floors, 6 generated room slots per floor.
const FLOOR_COUNT: int = 3
const ROOMS_PER_FLOOR: int = 6
const ROOM_TOTAL: int = FLOOR_COUNT * ROOMS_PER_FLOOR

const TYPE_SPAWN: String = DungeonGenerator.TYPE_SPAWN
const TYPE_NORMAL: String = DungeonGenerator.TYPE_NORMAL
const TYPE_COMBAT: String = DungeonGenerator.TYPE_COMBAT
const TYPE_EXTRACTION: String = DungeonGenerator.TYPE_EXTRACTION

const LAYOUT_KEYS: Array[String] = ["schema", "seed", "floors", "entry_id", "extraction_id"]
const FLOOR_KEYS: Array[String] = ["floor", "rooms"]
const ROOM_KEYS: Array[String] = ["id", "floor", "slot", "type", "risk", "neighbors"]
const MIN_SAFE_INT: int = -9007199254740991
const MAX_SAFE_INT: int = 9007199254740991

var seed_val: int = 0
var layout: Dictionary = {}

# ==============================================================================
# Generation (seeded, deterministic, structure only)
# ==============================================================================

## Builds a 3-floor / 6-slot layout for the seed and returns true only when the
## generated layout passes validate_layout (connected graph + reachable extraction).
func generate(p_seed: int) -> bool:
	seed_val = p_seed
	layout = {}

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = p_seed

	var rooms_by_id: Dictionary = {}
	var floor_entry_ids: Array[int] = []
	var floor_exit_ids: Array[int] = []
	var next_id: int = 0

	for floor_num: int in range(1, FLOOR_COUNT + 1):
		# Grow a ROOMS_PER_FLOOR spanning DAG on this floor's own grid with the
		# same seeded head-growing grammar the academic MVP generator uses.
		var coords: Dictionary = {}
		var adjacency: Dictionary = {}
		coords[Vector2i(0, 0)] = 0
		adjacency[0] = []
		var heads: Array[Vector2i] = [Vector2i(0, 0)]
		while coords.size() < ROOMS_PER_FLOOR:
			var parent_pos: Vector2i = heads[rng.randi_range(0, heads.size() - 1)]
			var parent_local: int = int(coords[parent_pos])
			var candidate_dirs: Array[Vector2i] = []
			for dir: Vector2i in DungeonGenerator.CARDINAL_DIRS:
				var candidate_pos: Vector2i = parent_pos + dir
				if not coords.has(candidate_pos):
					candidate_dirs.append(dir)
			if candidate_dirs.is_empty():
				heads.erase(parent_pos)
				if heads.is_empty():
					break
				continue
			var chosen_dir: Vector2i = candidate_dirs[rng.randi_range(0, candidate_dirs.size() - 1)]
			var new_pos: Vector2i = parent_pos + chosen_dir
			var new_local: int = coords.size()
			coords[new_pos] = new_local
			adjacency[new_local] = [parent_local]
			adjacency[parent_local].append(new_local)
			heads.append(new_pos)

		if adjacency.size() != ROOMS_PER_FLOOR:
			return false

		for local_id: int in range(ROOMS_PER_FLOOR):
			if not adjacency.has(local_id):
				return false
			var gid: int = next_id + local_id
			var neighbors: Array = []
			for neighbor_local: Variant in adjacency[local_id]:
				neighbors.append(next_id + int(neighbor_local))
			rooms_by_id[gid] = {
				"id": gid,
				"floor": floor_num,
				"slot": local_id,
				"type": TYPE_NORMAL,
				"risk": false,
				"neighbors": neighbors,
			}
		floor_entry_ids.append(next_id)
		floor_exit_ids.append(next_id + ROOMS_PER_FLOOR - 1)
		next_id += ROOMS_PER_FLOOR

	# One route per floor boundary: deepest room of floor N -> first room of floor N+1.
	for f: int in range(FLOOR_COUNT - 1):
		_link(rooms_by_id, floor_exit_ids[f], floor_entry_ids[f + 1])

	# Extraction endpoint: furthest room from the last-floor route head, on the last floor.
	var extraction_id: int = _furthest_on_floor(rooms_by_id, floor_exit_ids[FLOOR_COUNT - 1], FLOOR_COUNT)

	# Room types reuse ONLY the existing approved DungeonGenerator types.
	for gid_variant: Variant in rooms_by_id.keys():
		var gid: int = int(gid_variant)
		var room: Dictionary = rooms_by_id[gid]
		var room_type: String = TYPE_NORMAL
		if gid == 0:
			room_type = TYPE_SPAWN
		elif gid == extraction_id:
			room_type = TYPE_EXTRACTION
		elif gid % 2 == 1:
			room_type = TYPE_COMBAT
		room["type"] = room_type

	var floors: Array = []
	for floor_num: int in range(1, FLOOR_COUNT + 1):
		var rooms: Array = []
		for local_id: int in range(ROOMS_PER_FLOOR):
			rooms.append(rooms_by_id[(floor_num - 1) * ROOMS_PER_FLOOR + local_id])
		floors.append({"floor": floor_num, "rooms": rooms})

	layout = {
		"schema": SCHEMA_ID,
		"seed": p_seed,
		"floors": floors,
		"entry_id": 0,
		"extraction_id": extraction_id,
	}
	return validate_layout(layout) == OK

func is_valid() -> bool:
	return validate_layout(layout) == OK

# ==============================================================================
# Validation (FR-DNG-001 / TC-DNG-001)
# ==============================================================================

## Validates the complete structure contract:
##   - exact schema keys (any extra key - e.g. an invented drop probability - is invalid),
##   - exactly FLOOR_COUNT floors, each with exactly ROOMS_PER_FLOOR unique slots,
##   - only approved room types, exactly one spawn (the entry) and one extraction,
##   - well-formed symmetric neighbor edges (existing ids, no self loops, no duplicates),
##   - a connected graph: every room reachable from the entry,
##   - the extraction endpoint reachable from the entry (>= 1 valid route),
##   - risk flags only on existing reward-path rooms (normal / combat).
static func validate_layout(value: Variant) -> Error:
	if typeof(value) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var data: Dictionary = value as Dictionary
	if not _exact_keys(data, LAYOUT_KEYS):
		return ERR_INVALID_DATA
	if typeof(data["schema"]) != TYPE_STRING or String(data["schema"]) != SCHEMA_ID:
		return ERR_INVALID_DATA
	if not _is_int(data["seed"]):
		return ERR_INVALID_DATA
	if not _is_int(data["entry_id"]) or not _is_int(data["extraction_id"]):
		return ERR_INVALID_DATA
	var entry_id: int = int(data["entry_id"])
	var extraction_id: int = int(data["extraction_id"])
	if typeof(data["floors"]) != TYPE_ARRAY:
		return ERR_INVALID_DATA
	var floors: Array = data["floors"] as Array
	if floors.size() != FLOOR_COUNT:
		return ERR_INVALID_DATA

	var rooms_by_id: Dictionary = {}
	var spawn_rooms: Array[int] = []
	var extraction_rooms: Array[int] = []
	var seen_slots: Dictionary = {}

	for index: int in range(FLOOR_COUNT):
		var floor_value: Variant = floors[index]
		if typeof(floor_value) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var floor_data: Dictionary = floor_value as Dictionary
		if not _exact_keys(floor_data, FLOOR_KEYS):
			return ERR_INVALID_DATA
		if not _is_int(floor_data["floor"]) or int(floor_data["floor"]) != index + 1:
			return ERR_INVALID_DATA
		if typeof(floor_data["rooms"]) != TYPE_ARRAY:
			return ERR_INVALID_DATA
		var rooms: Array = floor_data["rooms"] as Array
		if rooms.size() != ROOMS_PER_FLOOR:
			return ERR_INVALID_DATA
		for room_value: Variant in rooms:
			if typeof(room_value) != TYPE_DICTIONARY:
				return ERR_INVALID_DATA
			var room: Dictionary = room_value as Dictionary
			if not _exact_keys(room, ROOM_KEYS):
				return ERR_INVALID_DATA
			if not _is_int(room["id"]) or not _is_int(room["floor"]) or not _is_int(room["slot"]):
				return ERR_INVALID_DATA
			var room_id: int = int(room["id"])
			var room_floor: int = int(room["floor"])
			var room_slot: int = int(room["slot"])
			if room_id < 0 or room_id >= ROOM_TOTAL:
				return ERR_INVALID_DATA
			if room_floor != index + 1:
				return ERR_INVALID_DATA
			if room_slot < 0 or room_slot >= ROOMS_PER_FLOOR:
				return ERR_INVALID_DATA
			if rooms_by_id.has(room_id):
				return ERR_INVALID_DATA
			var slot_key: String = "%d:%d" % [room_floor, room_slot]
			if seen_slots.has(slot_key):
				return ERR_INVALID_DATA
			seen_slots[slot_key] = true
			if typeof(room["type"]) != TYPE_STRING:
				return ERR_INVALID_DATA
			var room_type: String = String(room["type"])
			if room_type != TYPE_SPAWN and room_type != TYPE_NORMAL \
					and room_type != TYPE_COMBAT and room_type != TYPE_EXTRACTION:
				return ERR_INVALID_DATA
			if room_type == TYPE_SPAWN:
				spawn_rooms.append(room_id)
			elif room_type == TYPE_EXTRACTION:
				extraction_rooms.append(room_id)
			if typeof(room["risk"]) != TYPE_BOOL:
				return ERR_INVALID_DATA
			if bool(room["risk"]) and room_type != TYPE_NORMAL and room_type != TYPE_COMBAT:
				# Optional risk rooms may only sit on an existing reward-path room.
				return ERR_INVALID_DATA
			if typeof(room["neighbors"]) != TYPE_ARRAY:
				return ERR_INVALID_DATA
			rooms_by_id[room_id] = room

	if rooms_by_id.size() != ROOM_TOTAL:
		return ERR_INVALID_DATA
	if spawn_rooms.size() != 1 or extraction_rooms.size() != 1:
		return ERR_INVALID_DATA
	if spawn_rooms[0] != entry_id or extraction_rooms[0] != extraction_id:
		return ERR_INVALID_DATA
	if entry_id == extraction_id:
		return ERR_INVALID_DATA

	# Edge integrity: existing ids only, no self loops, no duplicates, symmetric.
	for room_id_variant: Variant in rooms_by_id.keys():
		var room: Dictionary = rooms_by_id[room_id_variant]
		var neighbors: Array = room["neighbors"] as Array
		var seen_neighbors: Dictionary = {}
		for neighbor_value: Variant in neighbors:
			if not _is_int(neighbor_value):
				return ERR_INVALID_DATA
			var neighbor_id: int = int(neighbor_value)
			if neighbor_id == room_id_variant or not rooms_by_id.has(neighbor_id):
				return ERR_INVALID_DATA
			if seen_neighbors.has(neighbor_id):
				return ERR_INVALID_DATA
			seen_neighbors[neighbor_id] = true
			var back: Array = (rooms_by_id[neighbor_id] as Dictionary)["neighbors"] as Array
			var linked_back: bool = false
			for back_value: Variant in back:
				if _is_int(back_value) and int(back_value) == int(room_id_variant):
					linked_back = true
					break
			if not linked_back:
				return ERR_INVALID_DATA

	# Connectivity: every room must be reachable from the entry (no unreachable rooms).
	var reachable: Dictionary = _bfs(rooms_by_id, entry_id)
	if reachable.size() != rooms_by_id.size():
		return ERR_INVALID_DATA
	# Extraction reachability: >= 1 valid route from entry to extraction.
	if not reachable.has(extraction_id):
		return ERR_INVALID_DATA
	var route: Array[int] = _route(rooms_by_id, entry_id, extraction_id)
	if route.size() < 2:
		return ERR_INVALID_DATA
	return OK

## BFS route from -> to as an id array (empty when unreachable).
static func find_route(value: Variant, from_id: int, to_id: int) -> Array[int]:
	if typeof(value) != TYPE_DICTIONARY:
		return []
	var data: Dictionary = value as Dictionary
	if not data.has("floors") or typeof(data["floors"]) != TYPE_ARRAY:
		return []
	var rooms_by_id: Dictionary = {}
	for floor_value: Variant in (data["floors"] as Array):
		if typeof(floor_value) != TYPE_DICTIONARY:
			return []
		var floor_data: Dictionary = floor_value as Dictionary
		if not floor_data.has("rooms") or typeof(floor_data["rooms"]) != TYPE_ARRAY:
			return []
		for room_value: Variant in (floor_data["rooms"] as Array):
			if typeof(room_value) != TYPE_DICTIONARY:
				return []
			var room: Dictionary = room_value as Dictionary
			if not room.has("id") or not _is_int(room["id"]):
				return []
			rooms_by_id[int(room["id"])] = room
	return _route(rooms_by_id, from_id, to_id)

# ==============================================================================
# Internal helpers
# ==============================================================================

static func _link(rooms_by_id: Dictionary, a: int, b: int) -> void:
	if not rooms_by_id.has(a) or not rooms_by_id.has(b) or a == b:
		return
	var a_room: Dictionary = rooms_by_id[a]
	var b_room: Dictionary = rooms_by_id[b]
	(a_room["neighbors"] as Array).append(b)
	(b_room["neighbors"] as Array).append(a)

static func _bfs(rooms_by_id: Dictionary, start_id: int) -> Dictionary:
	var visited: Dictionary = {}
	if not rooms_by_id.has(start_id):
		return visited
	var queue: Array[int] = [start_id]
	visited[start_id] = true
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var room: Dictionary = rooms_by_id.get(current, {})
		for neighbor_value: Variant in room.get("neighbors", []):
			if not _is_int(neighbor_value):
				continue
			var neighbor_id: int = int(neighbor_value)
			if rooms_by_id.has(neighbor_id) and not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)
	return visited

static func _route(rooms_by_id: Dictionary, from_id: int, to_id: int) -> Array[int]:
	var empty: Array[int] = []
	if not rooms_by_id.has(from_id) or not rooms_by_id.has(to_id):
		return empty
	var parent: Dictionary = {from_id: -1}
	var queue: Array[int] = [from_id]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == to_id:
			break
		var room: Dictionary = rooms_by_id.get(current, {})
		for neighbor_value: Variant in room.get("neighbors", []):
			if not _is_int(neighbor_value):
				continue
			var neighbor_id: int = int(neighbor_value)
			if rooms_by_id.has(neighbor_id) and not parent.has(neighbor_id):
				parent[neighbor_id] = current
				queue.append(neighbor_id)
	if not parent.has(to_id):
		return empty
	var path: Array[int] = []
	var cursor: int = to_id
	while cursor != -1:
		path.push_front(cursor)
		cursor = int(parent[cursor])
	return path

## Deterministic BFS furthest room inside one floor (ties resolved by BFS order).
static func _furthest_on_floor(rooms_by_id: Dictionary, start_id: int, floor_num: int) -> int:
	var visited: Dictionary = {}
	var queue: Array[int] = [start_id]
	visited[start_id] = true
	var last_node: int = start_id
	while not queue.is_empty():
		var current: int = queue.pop_front()
		last_node = current
		var room: Dictionary = rooms_by_id.get(current, {})
		for neighbor_value: Variant in room.get("neighbors", []):
			if not _is_int(neighbor_value):
				continue
			var neighbor_id: int = int(neighbor_value)
			if not rooms_by_id.has(neighbor_id) or visited.has(neighbor_id):
				continue
			if int((rooms_by_id[neighbor_id] as Dictionary)["floor"]) != floor_num:
				continue
			visited[neighbor_id] = true
			queue.append(neighbor_id)
	return last_node

static func _exact_keys(d: Dictionary, keys: Array[String]) -> bool:
	if d.size() != keys.size():
		return false
	for key: String in keys:
		if not d.has(key):
			return false
	return true

static func _is_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= MIN_SAFE_INT and value <= MAX_SAFE_INT
	if typeof(value) == TYPE_FLOAT:
		var f: float = float(value)
		return is_finite(f) and not is_nan(f) and floor(f) == f \
			and f >= float(MIN_SAFE_INT) and f <= float(MAX_SAFE_INT)
	return false
