class_name DungeonExpedition
extends Node2D

## DungeonExpedition — SBL-W8-002 M3 procedural dungeon expedition scene.
## Requirements: GDD-031/032/033/034/035, FR-DNG-001/002, AGENTS.md Invariants.
##
## Spawns modular dungeon rooms from DungeonGenerator, manages at-risk satchel loot,
## and provides an extraction portal at the verified endpoint.

signal expedition_completed(extracted_items: Dictionary)
signal expedition_failed(lost_items: Dictionary)

const ROOM_SIZE: Vector2 = Vector2(180, 120)
const ROOM_SPACING: Vector2 = Vector2(240, 180)

var generator: DungeonGenerator = DungeonGenerator.new()
var inventory: InventoryManager = InventoryManager.new()

var is_active: bool = false
var extraction_portal: Area2D = null

@onready var rooms_container: Node2D = $RoomsContainer
@onready var corridors_container: Node2D = $CorridorsContainer
@onready var entities_container: Node2D = $EntitiesContainer

func setup(seed_val: int = 1337, room_count: int = 6) -> bool:
	var success: bool = generator.generate(seed_val, room_count)
	if not success or not generator.is_valid:
		return false

	_build_scene()
	is_active = true
	return true

func _build_scene() -> void:
	# Clear existing children
	for c in rooms_container.get_children():
		c.queue_free()
	for c in corridors_container.get_children():
		c.queue_free()
	for c in entities_container.get_children():
		c.queue_free()

	for room: Dictionary in generator.rooms:
		var rid: int = int(room["id"])
		var grid_pos: Vector2i = Vector2i(int(room["coord_x"]), int(room["coord_y"]))
		var world_pos: Vector2 = Vector2(grid_pos.x * ROOM_SPACING.x, grid_pos.y * ROOM_SPACING.y)

		# Build Room Visual
		var room_rect := ColorRect.new()
		room_rect.name = "Room_%d" % rid
		room_rect.size = ROOM_SIZE
		room_rect.position = world_pos - (ROOM_SIZE / 2.0)

		match String(room["type"]):
			DungeonGenerator.TYPE_SPAWN:
				room_rect.color = Color(0.15, 0.25, 0.35, 1.0)
			DungeonGenerator.TYPE_EXTRACTION:
				room_rect.color = Color(0.20, 0.35, 0.25, 1.0)
				_spawn_extraction_portal(world_pos)
			DungeonGenerator.TYPE_COMBAT:
				room_rect.color = Color(0.35, 0.15, 0.15, 1.0)
			_:
				room_rect.color = Color(0.18, 0.20, 0.25, 1.0)
				# Place loot in normal rooms
				inventory.add_satchel_item("ancient_relic_fragment", 1)

		rooms_container.add_child(room_rect)

func _spawn_extraction_portal(pos: Vector2) -> void:
	var portal := Area2D.new()
	portal.name = "ExtractionPortal"
	portal.position = pos
	portal.collision_layer = 0
	portal.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 48)
	shape.shape = rect
	portal.add_child(shape)

	var visual := ColorRect.new()
	visual.size = Vector2(36, 36)
	visual.position = Vector2(-18, -18)
	visual.color = Color(0.3, 0.9, 0.5, 0.85)
	portal.add_child(visual)

	portal.body_entered.connect(_on_portal_entered)
	entities_container.add_child(portal)
	extraction_portal = portal

func _on_portal_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body is PlayerCharacter or body.name == "Player":
		extract_now()

func extract_now() -> Dictionary:
	is_active = false
	var extracted: Dictionary = inventory.extract_satchel_to_bank()
	expedition_completed.emit(extracted)
	return extracted

func fail_now() -> Dictionary:
	is_active = false
	var lost: Dictionary = inventory.handle_expedition_defeat()
	expedition_failed.emit(lost)
	return lost
