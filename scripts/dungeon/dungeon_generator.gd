class_name DungeonGenerator
extends RefCounted

## DungeonGenerator — SBL-W8-001 M3 seeded modular dungeon generator and layout validator.
## Requirements: GDD-031/032/033/034/035, FR-DNG-001/002, AGENTS.md Invariants.
##
## Core Invariants:
##   - Determinism: Identical seed + room_count produces identical graph layout.
##   - Reachability: Extraction room is guaranteed reachable from spawn (verified via BFS).
##   - Suspend/Resume: Suspended expedition state can serialize/deserialize without counting as extraction.

const TYPE_SPAWN: String = "spawn"
const TYPE_NORMAL: String = "normal"
const TYPE_COMBAT: String = "combat"
const TYPE_EXTRACTION: String = "extraction"

const CARDINAL_DIRS: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(-1, 0)
]

var current_seed: int = 0
var rooms: Array[Dictionary] = []
var spawn_id: int = 0
var extraction_id: int = 0
var is_valid: bool = false

func generate(seed_val: int, room_count: int = 6) -> bool:
	current_seed = seed_val
	rooms.clear()
	is_valid = false

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val

	var target_count: int = maxi(3, room_count)
	var coords_to_id: Dictionary = {} # Vector2i -> int
	var id_to_coord: Dictionary = {} # int -> Vector2i
	var adjacency: Dictionary = {} # int -> Array[int]

	# Room 0 is spawn at (0, 0)
	var current_pos: Vector2i = Vector2i(0, 0)
	coords_to_id[current_pos] = 0
	id_to_coord[0] = current_pos
	adjacency[0] = []

	var available_heads: Array[Vector2i] = [current_pos]

	while coords_to_id.size() < target_count:
		var parent_pos: Vector2i = available_heads[rng.randi_range(0, available_heads.size() - 1)]
		var parent_id: int = coords_to_id[parent_pos]

		var candidate_dirs: Array[Vector2i] = []
		for dir: Vector2i in CARDINAL_DIRS:
			var candidate_pos: Vector2i = parent_pos + dir
			if not coords_to_id.has(candidate_pos):
				candidate_dirs.append(dir)

		if candidate_dirs.is_empty():
			available_heads.erase(parent_pos)
			if available_heads.is_empty():
				break
			continue

		var chosen_dir: Vector2i = candidate_dirs[rng.randi_range(0, candidate_dirs.size() - 1)]
		var new_pos: Vector2i = parent_pos + chosen_dir
		var new_id: int = coords_to_id.size()

		coords_to_id[new_pos] = new_id
		id_to_coord[new_id] = new_pos
		adjacency[new_id] = [parent_id]
		adjacency[parent_id].append(new_id)
		available_heads.append(new_pos)

	spawn_id = 0
	# Extraction room is placed at the furthest room from spawn
	extraction_id = _find_furthest_room(0, adjacency)

	# Build room objects
	for rid: int in adjacency.keys():
		var rtype: String = TYPE_NORMAL
		if rid == spawn_id:
			rtype = TYPE_SPAWN
		elif rid == extraction_id:
			rtype = TYPE_EXTRACTION
		elif rid % 2 == 1:
			rtype = TYPE_COMBAT

		rooms.append({
			"id": rid,
			"type": rtype,
			"coord_x": id_to_coord[rid].x,
			"coord_y": id_to_coord[rid].y,
			"neighbors": adjacency[rid]
		})

	is_valid = _verify_reachability(spawn_id, extraction_id, adjacency)
	return is_valid

func _find_furthest_room(start: int, adj: Dictionary) -> int:
	var queue: Array[int] = [start]
	var visited: Dictionary = {start: true}
	var last_node: int = start

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		last_node = curr
		for neighbor: int in adj.get(curr, []):
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return last_node

func _verify_reachability(start: int, target: int, adj: Dictionary) -> bool:
	var queue: Array[int] = [start]
	var visited: Dictionary = {start: true}

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		if curr == target:
			return true
		for neighbor: int in adj.get(curr, []):
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return false

func serialize_expedition_state() -> Dictionary:
	return {
		"seed": current_seed,
		"spawn_id": spawn_id,
		"extraction_id": extraction_id,
		"rooms": rooms.duplicate(true),
		"is_valid": is_valid
	}

func deserialize_expedition_state(data: Dictionary) -> Error:
	if not data.has("seed") or not data.has("rooms") or not data.has("extraction_id"):
		return ERR_INVALID_DATA
	current_seed = int(data["seed"])
	spawn_id = int(data.get("spawn_id", 0))
	extraction_id = int(data["extraction_id"])
	rooms = (data["rooms"] as Array).duplicate(true)
	is_valid = bool(data.get("is_valid", false))
	return OK
