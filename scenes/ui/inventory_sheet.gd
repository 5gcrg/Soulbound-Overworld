class_name InventorySheet
extends Control

## InventorySheet — SBL-W6-004 Town Bank & Expedition Satchel UI Sheet
## Requirements: GDD-025/026/027/028/029/030, FR-INV-001, AGENTS.md Invariants.

signal closed

var inventory: InventoryManager = null

@onready var bank_list_label: Label = $Panel/Margin/VBox/Columns/BankCol/Scroll/BankListLabel
@onready var satchel_list_label: Label = $Panel/Margin/VBox/Columns/SatchelCol/Scroll/SatchelListLabel

@onready var weapon_label: Label = $Panel/Margin/VBox/Columns/EquipCol/WeaponRow/Value
@onready var weapon_unequip_btn: Button = $Panel/Margin/VBox/Columns/EquipCol/WeaponRow/UnequipBtn

@onready var armor_label: Label = $Panel/Margin/VBox/Columns/EquipCol/ArmorRow/Value
@onready var armor_unequip_btn: Button = $Panel/Margin/VBox/Columns/EquipCol/ArmorRow/UnequipBtn

@onready var relic1_label: Label = $Panel/Margin/VBox/Columns/EquipCol/Relic1Row/Value
@onready var relic1_unequip_btn: Button = $Panel/Margin/VBox/Columns/EquipCol/Relic1Row/UnequipBtn

@onready var relic2_label: Label = $Panel/Margin/VBox/Columns/EquipCol/Relic2Row/Value
@onready var relic2_unequip_btn: Button = $Panel/Margin/VBox/Columns/EquipCol/Relic2Row/UnequipBtn

@onready var close_btn: Button = $Panel/Margin/VBox/CloseButton

func _ready() -> void:
	weapon_unequip_btn.pressed.connect(_on_unequip.bind(InventoryManager.SLOT_WEAPON))
	armor_unequip_btn.pressed.connect(_on_unequip.bind(InventoryManager.SLOT_ARMOR))
	relic1_unequip_btn.pressed.connect(_on_unequip.bind(InventoryManager.SLOT_RELIC_1))
	relic2_unequip_btn.pressed.connect(_on_unequip.bind(InventoryManager.SLOT_RELIC_2))
	close_btn.pressed.connect(_on_close_pressed)

	if inventory != null:
		refresh()

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

	var a: String = inventory.equipment.get("armor", "")
	armor_label.text = a if not a.is_empty() else "(Empty)"
	armor_unequip_btn.disabled = a.is_empty()

	var r1: String = inventory.equipment.get("relic_1", "")
	relic1_label.text = r1 if not r1.is_empty() else "(Empty)"
	relic1_unequip_btn.disabled = r1.is_empty()

	var r2: String = inventory.equipment.get("relic_2", "")
	relic2_label.text = r2 if not r2.is_empty() else "(Empty)"
	relic2_unequip_btn.disabled = r2.is_empty()

func _on_unequip(slot: StringName) -> void:
	if inventory != null and inventory.unequip_item(slot):
		refresh()

func equip_from_bank(slot: StringName, item_id: String) -> bool:
	if inventory != null and inventory.equip_item(slot, item_id):
		refresh()
		return true
	return false

func _on_close_pressed() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
