class_name DungeonExpedition
extends Control

## DungeonExpedition — SBL-W8-002 M3 procedural dungeon expedition scene & interactive modal.
## Requirements: GDD-031/032/033/034/035, FR-DNG-001/002, AGENTS.md Invariants.
##
## Spawns modular dungeon rooms from DungeonGenerator, manages at-risk satchel loot,
## and provides an extraction portal at the verified endpoint.

signal expedition_completed(extracted_items: Dictionary)
signal expedition_failed(lost_items: Dictionary)
signal expedition_cancelled

const ROOM_SIZE: Vector2 = Vector2(180, 120)
const ROOM_SPACING: Vector2 = Vector2(240, 180)

var generator: DungeonGenerator = DungeonGenerator.new()
var inventory: InventoryManager = InventoryManager.new()

var is_active: bool = false
var extraction_portal: Area2D = null
var expedition_path: Array[int] = []
var current_step: int = 0

@onready var rooms_container: Node2D = $RoomsContainer
@onready var corridors_container: Node2D = $CorridorsContainer
@onready var entities_container: Node2D = $EntitiesContainer

# UI references
@onready var title_label: Label = $UI/Panel/Margin/VBox/Header/TitleLabel
@onready var location_label: Label = $UI/Panel/Margin/VBox/StatusBox/LocationLabel
@onready var satchel_label: Label = $UI/Panel/Margin/VBox/StatusBox/SatchelLabel
@onready var bank_label: Label = $UI/Panel/Margin/VBox/StatusBox/BankLabel
@onready var room_description_label: Label = $UI/Panel/Margin/VBox/DescriptionBox/RoomDescriptionLabel
@onready var room_path_label: Label = $UI/Panel/Margin/VBox/PathBox/RoomPathLabel

@onready var advance_btn: Button = $UI/Panel/Margin/VBox/ActionBox/AdvanceBtn
@onready var extract_btn: Button = $UI/Panel/Margin/VBox/ActionBox/ExtractBtn
@onready var retreat_btn: Button = $UI/Panel/Margin/VBox/ActionBox/RetreatBtn
@onready var step_back_btn: Button = $UI/Panel/Margin/VBox/ActionBox/StepBackBtn

func _ready() -> void:
	if advance_btn != null:
		advance_btn.pressed.connect(_on_advance_pressed)
	if extract_btn != null:
		extract_btn.pressed.connect(_on_extract_pressed)
	if retreat_btn != null:
		retreat_btn.pressed.connect(_on_retreat_pressed)
	if step_back_btn != null:
		step_back_btn.pressed.connect(_on_step_back_pressed)

	if is_active:
		refresh_ui()

func setup(seed_val: int = 1337, room_count: int = 6) -> bool:
	var success: bool = generator.generate(seed_val, room_count)
	if not success or not generator.is_valid:
		return false

	_build_scene()
	expedition_path = _calculate_path()
	current_step = 0
	is_active = true

	if is_inside_tree():
		refresh_ui()
	return true

func _build_scene() -> void:
	# Clear existing children
	if rooms_container != null:
		for c in rooms_container.get_children():
			c.queue_free()
	if corridors_container != null:
		for c in corridors_container.get_children():
			c.queue_free()
	if entities_container != null:
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
				# Place initial loot in normal rooms for satchel
				if inventory.satchel_items.get("ancient_relic_fragment", 0) == 0:
					inventory.add_satchel_item("ancient_relic_fragment", 1)

		if rooms_container != null:
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
	if entities_container != null:
		entities_container.add_child(portal)
	extraction_portal = portal

func _on_portal_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body is PlayerCharacter or body.name == "Player":
		extract_now()

func _calculate_path() -> Array[int]:
	# BFS shortest path from spawn_id to extraction_id
	var queue: Array[Array] = [[generator.spawn_id]]
	var visited: Dictionary = {generator.spawn_id: true}

	while not queue.is_empty():
		var path: Array = queue.pop_front()
		var curr: int = int(path[-1])
		if curr == generator.extraction_id:
			var res: Array[int] = []
			for x in path:
				res.append(int(x))
			return res

		# Search neighbors
		for r: Dictionary in generator.rooms:
			if int(r["id"]) == curr:
				for n: int in r.get("neighbors", []):
					if not visited.has(n):
						visited[n] = true
						var new_path: Array = path.duplicate()
						new_path.append(n)
						queue.append(new_path)
				break

	return [generator.spawn_id, generator.extraction_id]

func refresh_ui() -> void:
	if title_label == null:
		return

	title_label.text = "✦ Abyssal Expedition (Seed %d) ✦" % generator.current_seed

	var curr_room_id: int = expedition_path[current_step] if current_step < expedition_path.size() else generator.spawn_id
	var room_type: String = "Normal"
	for r: Dictionary in generator.rooms:
		if int(r["id"]) == curr_room_id:
			room_type = String(r.get("type", "normal"))
			break

	location_label.text = "Chamber %d / %d [%s]" % [current_step + 1, expedition_path.size(), room_type.capitalize()]

	var satchel_count: int = inventory.satchel_items.get("ancient_relic_fragment", 0)
	satchel_label.text = "Satchel: %d Fragments (At-Risk!)" % satchel_count

	var bank_count: int = inventory.banked_items.get("ancient_relic_fragment", 0)
	bank_label.text = "Town Bank: %d Fragments (Secured)" % bank_count

	# Breadcrumb trail
	var trail: Array[String] = []
	for i in range(expedition_path.size()):
		var rid: int = expedition_path[i]
		var tag: String = "Chamber %d" % (i + 1)
		if i == 0:
			tag = "Spawn"
		elif i == expedition_path.size() - 1:
			tag = "Extraction Shrine"
		if i == current_step:
			trail.append("★ [%s]" % tag)
		elif i < current_step:
			trail.append("✓ %s" % tag)
		else:
			trail.append("%s" % tag)
	room_path_label.text = "  ➔  ".join(trail)

	# Descriptions
	var is_at_extraction: bool = (current_step >= expedition_path.size() - 1 or curr_room_id == generator.extraction_id)
	if current_step == 0:
		room_description_label.text = "You stand at the threshold of the Abyssal depths. Proceed deeper to find ancient relic fragments, or step back to the overworld."
	elif is_at_extraction:
		room_description_label.text = "You have discovered the Abyssal Extraction Shrine! Step through the portal now to transfer and secure all gathered satchel loot in your Town Bank."
	else:
		match room_type:
			DungeonGenerator.TYPE_COMBAT:
				room_description_label.text = "A lingering spirit warden challenges your advance. You focus your resonant energy and push deeper into the chambers."
			_:
				room_description_label.text = "You uncover an ancient relic stash! 1x Ancient Relic Fragment added to your at-risk satchel."

	# Action buttons
	if is_at_extraction:
		advance_btn.disabled = true
		advance_btn.text = "Destination Reached"
		extract_btn.disabled = false
		extract_btn.grab_focus()
	else:
		advance_btn.disabled = false
		advance_btn.text = "Advance to Chamber %d" % (current_step + 2)
		extract_btn.disabled = true
		advance_btn.grab_focus()

	step_back_btn.visible = (current_step == 0)
	retreat_btn.visible = (current_step > 0)

func _on_advance_pressed() -> void:
	if current_step < expedition_path.size() - 1:
		current_step += 1
		var curr_room_id: int = expedition_path[current_step]
		for r: Dictionary in generator.rooms:
			if int(r["id"]) == curr_room_id:
				if String(r.get("type", "")) == DungeonGenerator.TYPE_NORMAL:
					inventory.add_satchel_item("ancient_relic_fragment", 1)
				break
		refresh_ui()

func _on_extract_pressed() -> void:
	extract_now()

func _on_retreat_pressed() -> void:
	fail_now()

func _on_step_back_pressed() -> void:
	cancel_expedition()

func cancel_expedition() -> void:
	is_active = false
	expedition_cancelled.emit()

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if current_step == 0:
			cancel_expedition()
		else:
			fail_now()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if advance_btn != null and advance_btn.visible and not advance_btn.disabled:
			_on_advance_pressed()
		elif extract_btn != null and extract_btn.visible and not extract_btn.disabled:
			_on_extract_pressed()
