extends SceneTree

## SBL-W6-005 UI Sheets (Character & Inventory) Test Suite
## Requirements: GDD-005/006/007/025/026/027, FR-PRO-001, FR-INV-001.

const GameRootScene: PackedScene = preload("res://scenes/main/game_root.tscn")

var _failures: int = 0
var _test_root: String = ""

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("UI SHEETS TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W6-005 UI Sheets Test Suite ---")

	_test_root = "user://test_ui_profiles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var test_store: ProfileStore = ProfileStore.new(_test_root)

	var game_root: Control = GameRootScene.instantiate() as Control
	game_root.profile_store = test_store
	root.add_child(game_root)
	game_root._init_slice_progress(test_store, "profile_01")

	await process_frame
	await process_frame

	var player: PlayerCharacter = game_root.player
	_check(player != null, "Player instantiated")
	_check(player.input_frozen == false, "Player initially unfrozen")

	# ==========================================================================
	# Part 1: Character Sheet Flow
	# ==========================================================================
	var stats: CharacterStats = game_root.character_stats
	stats.unspent_points = 2
	var init_vit: int = stats.vitality
	var init_res: int = stats.resonance

	# Toggle Character Sheet ON
	game_root._toggle_character_sheet()
	await process_frame

	_check(game_root._character_sheet != null, "Character sheet instantiated")
	_check(player.input_frozen == true, "Player frozen while sheet open")

	var char_sheet: CharacterSheet = game_root._character_sheet
	_check(char_sheet.vit_btn.disabled == false, "Vit add button active when points available")

	# Allocate Vitality
	char_sheet._on_allocate(CharacterStats.ATTR_VITALITY)
	_check(stats.vitality == init_vit + 1, "Vitality increased by 1")
	_check(stats.unspent_points == 1, "Unspent points reduced to 1")
	_check(stats.get_max_hp() == (init_vit + 1) * 10, "Max HP recalculated correctly")

	# Allocate Resonance
	char_sheet._on_allocate(CharacterStats.ATTR_RESONANCE)
	_check(stats.resonance == init_res + 1, "Resonance increased by 1")
	_check(stats.unspent_points == 0, "Unspent points reduced to 0")
	_check(char_sheet.vit_btn.disabled == true, "Vit add button disabled when points reach 0")
	_check(char_sheet.res_btn.disabled == true, "Res add button disabled when points reach 0")

	# Close Character Sheet
	char_sheet.closed.emit()
	await process_frame

	_check(game_root._character_sheet == null, "Character sheet closed")
	_check(player.input_frozen == false, "Player unfrozen after sheet closed")

	# ==========================================================================
	# Part 2: Inventory Sheet Flow
	# ==========================================================================
	var inv: InventoryManager = game_root.inventory_manager
	inv.add_banked_item("iron_blade", 1)
	inv.add_banked_item("spirit_amulet", 1)

	# Toggle Inventory Sheet ON
	game_root._toggle_inventory_sheet()
	await process_frame

	_check(game_root._inventory_sheet != null, "Inventory sheet instantiated")
	_check(player.input_frozen == true, "Player frozen while inventory open")

	var inv_sheet: InventorySheet = game_root._inventory_sheet
	_check(inv.banked_items.has("iron_blade"), "Iron blade present in bank")
	_check(inv_sheet.weapon_equip_btn.disabled == false, "Weapon equip button enabled with banked blade")

	# 1. Equip weapon via UI Button
	var equipment_changed_received: Array[Dictionary] = []
	inv_sheet.equipment_changed.connect(func(slot: StringName, item_id: String) -> void:
		equipment_changed_received.append({"slot": slot, "item_id": item_id})
	)

	inv_sheet.weapon_equip_btn.pressed.emit()
	_check(inv.equipment["weapon"] == "iron_blade", "Weapon slot holds iron blade via UI button")
	_check(not inv.banked_items.has("iron_blade"), "Iron blade moved out of bank")
	_check(inv_sheet.weapon_unequip_btn.disabled == false, "Unequip button enabled after equip")
	_check(inv_sheet.weapon_equip_btn.disabled == true, "Weapon equip button disabled when no more banked weapons")
	_check(equipment_changed_received.size() == 1, "equipment_changed signal emitted on UI equip")

	# 2. Unequip weapon via UI Button
	inv_sheet.weapon_unequip_btn.pressed.emit()
	_check(inv.equipment["weapon"] == "", "Weapon slot unequipped via UI button")
	_check(inv.banked_items.has("iron_blade"), "Iron blade returned to bank")
	_check(inv_sheet.weapon_unequip_btn.disabled == true, "Unequip button disabled after unequip")
	_check(inv_sheet.weapon_equip_btn.disabled == false, "Weapon equip button re-enabled")
	_check(equipment_changed_received.size() == 2, "equipment_changed signal emitted on UI unequip")

	# 3. Equip relic via UI Button
	_check(inv_sheet.relic1_equip_btn.disabled == false, "Relic 1 equip button enabled with banked amulet")
	inv_sheet.relic1_equip_btn.pressed.emit()
	_check(inv.equipment["relic_1"] == "spirit_amulet", "Relic 1 slot holds spirit amulet via UI button")
	_check(inv_sheet.relic1_unequip_btn.disabled == false, "Relic 1 unequip button enabled")

	# Close Inventory Sheet
	inv_sheet.closed.emit()
	await process_frame

	_check(game_root._inventory_sheet == null, "Inventory sheet closed")
	_check(player.input_frozen == false, "Player unfrozen after inventory closed")

	# ==========================================================================
	# Part 3: Mutual Exclusivity
	# ==========================================================================
	game_root._toggle_character_sheet()
	await process_frame
	_check(game_root._character_sheet != null, "Character sheet open")

	game_root._toggle_inventory_sheet()
	await process_frame
	_check(game_root._character_sheet == null, "Character sheet automatically closed")
	_check(game_root._inventory_sheet != null, "Inventory sheet opened in its place")

	game_root._toggle_inventory_sheet()
	await process_frame
	_check(game_root._inventory_sheet == null, "Inventory sheet closed")
	_check(player.input_frozen == false, "Player restored to unfrozen state")

	game_root.queue_free()

	# Cleanup temporary profile dir
	if DirAccess.dir_exists_absolute(_test_root):
		var d := DirAccess.open(_test_root)
		if d != null:
			for sub in d.get_directories():
				var sub_d := DirAccess.open(_test_root + "/" + sub)
				if sub_d != null:
					for f in sub_d.get_files():
						sub_d.remove(f)
					d.remove(sub)
			d.remove("")

	if _failures > 0:
		printerr("UI SHEETS TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL UI SHEETS TESTS PASSED SUCCESSFULLY ===")
	quit(0)
