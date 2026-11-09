class_name InventorySheet
extends Control

## InventorySheet — SBL-W6-004 Town Bank & Expedition Satchel UI Sheet
## Requirements: GDD-025/026/027/028/029/030, FR-INV-001, AGENTS.md Invariants.

signal closed
signal equipment_changed(slot: StringName, item_id: String)

var inventory: InventoryManager = null

@onready var bank_list_label: Label = $Panel/Margin/VBox/Columns/BankCol/Scroll/BankListLabel
@onready var satchel_list_label: Label = $Panel/Margin/VBox/Columns/SatchelCol/Scroll/SatchelListLabel

@onready var weapon_label: Label = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/WeaponRow/Value", "Panel/Margin/VBox/Columns/EquipCol/WeaponRow/Value"]) as Label
@onready var weapon_equip_btn: Button = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/WeaponRow/EquipBtn", "Panel/Margin/VBox/Columns/EquipCol/WeaponRow/EquipBtn"]) as Button
@onready var weapon_unequip_btn: Button = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/WeaponRow/UnequipBtn", "Panel/Margin/VBox/Columns/EquipCol/WeaponRow/UnequipBtn"]) as Button

@onready var armor_label: Label = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/ArmorRow/Value", "Panel/Margin/VBox/Columns/EquipCol/ArmorRow/Value"]) as Label
@onready var armor_equip_btn: Button = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/ArmorRow/EquipBtn", "Panel/Margin/VBox/Columns/EquipCol/ArmorRow/EquipBtn"]) as Button
@onready var armor_unequip_btn: Button = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/ArmorRow/UnequipBtn", "Panel/Margin/VBox/Columns/EquipCol/ArmorRow/UnequipBtn"]) as Button

@onready var relic1_label: Label = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/Relic1Row/Value", "Panel/Margin/VBox/Columns/EquipCol/Relic1Row/Value"]) as Label
@onready var relic1_equip_btn: Button = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/Relic1Row/EquipBtn", "Panel/Margin/VBox/Columns/EquipCol/Relic1Row/EquipBtn"]) as Button
@onready var relic1_unequip_btn: Button = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/Relic1Row/UnequipBtn", "Panel/Margin/VBox/Columns/EquipCol/Relic1Row/UnequipBtn"]) as Button

@onready var relic2_label: Label = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/Relic2Row/Value", "Panel/Margin/VBox/Columns/EquipCol/Relic2Row/Value"]) as Label
@onready var relic2_equip_btn: Button = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/Relic2Row/EquipBtn", "Panel/Margin/VBox/Columns/EquipCol/Relic2Row/EquipBtn"]) as Button
@onready var relic2_unequip_btn: Button = _find_node(["Panel/Margin/VBox/Columns/EquipCol/Scroll/Rows/Relic2Row/UnequipBtn", "Panel/Margin/VBox/Columns/EquipCol/Relic2Row/UnequipBtn"]) as Button

@onready var close_btn: Button = $Panel/Margin/VBox/CloseButton

func _find_node(paths: Array) -> Node:
	for p in paths:
		if has_node(String(p)):
			return get_node(String(p))
	return null

func _ready() -> void:
	weapon_equip_btn.pressed.connect(_on_equip_slot.bind(InventoryManager.SLOT_WEAPON))
	armor_equip_btn.pressed.connect(_on_equip_slot.bind(InventoryManager.SLOT_ARMOR))
	relic1_equip_btn.pressed.connect(_on_equip_slot.bind(InventoryManager.SLOT_RELIC_1))
	relic2_equip_btn.pressed.connect(_on_equip_slot.bind(InventoryManager.SLOT_RELIC_2))

	weapon_unequip_btn.pressed.connect(_on_unequip.bind(InventoryManager.SLOT_WEAPON))
	armor_unequip_btn.pressed.connect(_on_unequip.bind(InventoryManager.SLOT_ARMOR))
	relic1_unequip_btn.pressed.connect(_on_unequip.bind(InventoryManager.SLOT_RELIC_1))
	relic2_unequip_btn.pressed.connect(_on_unequip.bind(InventoryManager.SLOT_RELIC_2))
	close_btn.pressed.connect(_on_close_pressed)

	setup_focus()

	if inventory != null:
		refresh()

func get_focusable_controls() -> Array[Control]:
	var list: Array[Control] = [
		weapon_equip_btn,
		weapon_unequip_btn,
		armor_equip_btn,
		armor_unequip_btn,
		relic1_equip_btn,
		relic1_unequip_btn,
		relic2_equip_btn,
		relic2_unequip_btn,
		close_btn
	]
	var res: Array[Control] = []
	for c in list:
		if c != null and is_instance_valid(c):
			res.append(c)
	return res

func setup_focus() -> void:
	var controls := get_focusable_controls()
	for i in range(controls.size()):
		var c := controls[i]
		c.focus_mode = Control.FOCUS_ALL
		var next_ctrl := controls[(i + 1) % controls.size()]
		var prev_ctrl := controls[(i - 1 + controls.size()) % controls.size()]
		c.focus_next = next_ctrl.get_path()
		c.focus_previous = prev_ctrl.get_path()
		_apply_visible_focus(c)
	# Grab focus on first enabled button or close button
	for c in controls:
		if not c.disabled:
			c.grab_focus()
			break

static func _apply_visible_focus(control: Control) -> void:
	var focus_box := StyleBoxFlat.new()
	focus_box.draw_center = false
	focus_box.border_width_left = 2
	focus_box.border_width_top = 2
	focus_box.border_width_right = 2
	focus_box.border_width_bottom = 2
	focus_box.border_color = Color(1.0, 0.85, 0.1, 1.0)
	focus_box.corner_radius_top_left = 4
	focus_box.corner_radius_top_right = 4
	focus_box.corner_radius_bottom_left = 4
	focus_box.corner_radius_bottom_right = 4
	control.add_theme_stylebox_override("focus", focus_box)

func set_inventory(new_inventory: InventoryManager) -> void:
	inventory = new_inventory
	if is_inside_tree():
		refresh()

func refresh() -> void:
	if inventory == null:
		return

	# Banked Items
	if inventory.banked_items.is_empty():
		bank_list_label.text = "(No secured items)"
	else:
		var lines: Array[String] = []
		for item_id: String in inventory.banked_items.keys():
			lines.append("• %s (x%d)" % [item_id, inventory.banked_items[item_id]])
		bank_list_label.text = "\n".join(lines)

	# Satchel Items
	if inventory.satchel_items.is_empty():
		satchel_list_label.text = "(Satchel empty)"
	else:
		var lines: Array[String] = []
		for item_id: String in inventory.satchel_items.keys():
			lines.append("• %s (x%d)" % [item_id, inventory.satchel_items[item_id]])
		satchel_list_label.text = "\n".join(lines)

	# Equipment
	var w: String = inventory.equipment.get("weapon", "")
	weapon_label.text = w if not w.is_empty() else "(Empty)"
	weapon_unequip_btn.disabled = w.is_empty()
	weapon_equip_btn.disabled = get_equippable_banked_items(InventoryManager.SLOT_WEAPON).is_empty()

	var a: String = inventory.equipment.get("armor", "")
	armor_label.text = a if not a.is_empty() else "(Empty)"
	armor_unequip_btn.disabled = a.is_empty()
	armor_equip_btn.disabled = get_equippable_banked_items(InventoryManager.SLOT_ARMOR).is_empty()

	var r1: String = inventory.equipment.get("relic_1", "")
	relic1_label.text = r1 if not r1.is_empty() else "(Empty)"
	relic1_unequip_btn.disabled = r1.is_empty()
	relic1_equip_btn.disabled = get_equippable_banked_items(InventoryManager.SLOT_RELIC_1).is_empty()

	var r2: String = inventory.equipment.get("relic_2", "")
	relic2_label.text = r2 if not r2.is_empty() else "(Empty)"
	relic2_unequip_btn.disabled = r2.is_empty()
	relic2_equip_btn.disabled = get_equippable_banked_items(InventoryManager.SLOT_RELIC_2).is_empty()

func get_equippable_banked_items(slot: StringName) -> Array[String]:
	var result: Array[String] = []
	if inventory == null:
		return result

	for item_id: String in inventory.banked_items.keys():
		var id_str: String = item_id.to_lower()
		var count: int = int(inventory.banked_items[item_id])
		if count <= 0:
			continue

		# Skip consumable items
		if id_str.contains("potion") or id_str.contains("salve") or id_str.contains("elixir") or id_str.contains("herb"):
			continue

		match slot:
			InventoryManager.SLOT_WEAPON:
				if id_str.contains("blade") or id_str.contains("sword") or id_str.contains("weapon") or id_str.contains("staff") or id_str.contains("dagger") or id_str.contains("bow") or (not id_str.contains("armor") and not id_str.contains("robe") and not id_str.contains("amulet") and not id_str.contains("relic") and not id_str.contains("ring")):
					result.append(item_id)
			InventoryManager.SLOT_ARMOR:
				if id_str.contains("armor") or id_str.contains("robe") or id_str.contains("mail") or id_str.contains("tunic") or id_str.contains("plate") or id_str.contains("vest"):
					result.append(item_id)
			InventoryManager.SLOT_RELIC_1, InventoryManager.SLOT_RELIC_2:
				if id_str.contains("relic") or id_str.contains("amulet") or id_str.contains("ring") or id_str.contains("charm") or id_str.contains("crystal") or id_str.contains("shard"):
					result.append(item_id)
	return result

func _on_equip_slot(slot: StringName) -> void:
	if inventory == null:
		return
	var candidates: Array[String] = get_equippable_banked_items(slot)
	if candidates.is_empty():
		return
	equip_from_bank(slot, candidates[0])

func _on_unequip(slot: StringName) -> void:
	if inventory != null and inventory.unequip_item(slot):
		refresh()
		equipment_changed.emit(slot, "")

func equip_from_bank(slot: StringName, item_id: String) -> bool:
	if inventory != null and inventory.equip_item(slot, item_id):
		refresh()
		equipment_changed.emit(slot, item_id)
		return true
	return false

func _on_close_pressed() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
