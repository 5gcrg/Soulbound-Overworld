class_name InventoryManager
extends RefCounted

## InventoryManager — SBL-W6-002 M3 secured town gear and at-risk expedition satchel system.
## Requirements: GDD-025/026/027/028/029/030, FR-INV-001, AGENTS.md Invariants.
##
## Core Invariants:
##   - Banked items are secured in town and NEVER lost upon expedition defeat.
##   - Satchel items are gathered during expeditions and are at-risk until extraction.
##   - Defeat in an expedition wipes the satchel but leaves banked items and equipped gear intact.
##   - Successful extraction transfers satchel contents into the bank exactly once.

const SLOT_WEAPON: StringName = &"weapon"
const SLOT_ARMOR: StringName = &"armor"
const SLOT_RELIC_1: StringName = &"relic_1"
const SLOT_RELIC_2: StringName = &"relic_2"

const VALID_EQUIP_SLOTS: Array[StringName] = [
	SLOT_WEAPON,
	SLOT_ARMOR,
	SLOT_RELIC_1,
	SLOT_RELIC_2
]

var banked_items: Dictionary = {} # String (item_id) -> int (count)
var satchel_items: Dictionary = {} # String (item_id) -> int (count)
var equipment: Dictionary = {
	"weapon": "",
	"armor": "",
	"relic_1": "",
	"relic_2": ""
}

func add_banked_item(item_id: String, count: int = 1) -> void:
	if item_id.is_empty() or count <= 0:
		return
	banked_items[item_id] = banked_items.get(item_id, 0) + count

func remove_banked_item(item_id: String, count: int = 1) -> bool:
	if item_id.is_empty() or count <= 0:
		return false
	var current: int = banked_items.get(item_id, 0)
	if current < count:
		return false
	current -= count
	if current <= 0:
		banked_items.erase(item_id)
	else:
		banked_items[item_id] = current
	return true

func add_satchel_item(item_id: String, count: int = 1) -> void:
	if item_id.is_empty() or count <= 0:
		return
	satchel_items[item_id] = satchel_items.get(item_id, 0) + count

func extract_satchel_to_bank() -> Dictionary:
	var extracted: Dictionary = satchel_items.duplicate()
	for item_id: String in extracted.keys():
		var count: int = int(extracted[item_id])
		add_banked_item(item_id, count)
	satchel_items.clear()
	return extracted

func handle_expedition_defeat() -> Dictionary:
	var lost: Dictionary = satchel_items.duplicate()
	satchel_items.clear()
	# Banked gear and equipment remain 100% secured
	return lost

func equip_item(slot: StringName, item_id: String) -> bool:
	if not VALID_EQUIP_SLOTS.has(slot):
		return false
	if not item_id.is_empty() and not banked_items.has(item_id):
		return false
	# Unequip previous
	var prev_item: String = equipment.get(String(slot), "")
	if not prev_item.is_empty():
		add_banked_item(prev_item, 1)

	if not item_id.is_empty():
		remove_banked_item(item_id, 1)
		equipment[String(slot)] = item_id
	else:
		equipment[String(slot)] = ""
	return true

func unequip_item(slot: StringName) -> bool:
	return equip_item(slot, "")

func serialize() -> Dictionary:
	return {
		"banked": banked_items.duplicate(),
		"satchel": satchel_items.duplicate(),
		"equipment": equipment.duplicate()
	}

func deserialize(data: Dictionary) -> Error:
	if typeof(data.get("banked", {})) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	banked_items = (data.get("banked", {}) as Dictionary).duplicate()
	satchel_items = (data.get("satchel", {}) as Dictionary).duplicate()
	var eq: Dictionary = data.get("equipment", {}) as Dictionary
	for slot: StringName in VALID_EQUIP_SLOTS:
		equipment[String(slot)] = String(eq.get(String(slot), ""))
	return OK

func load_from_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	if res["error"] != OK:
		return res["error"]
	var prof: Dictionary = res["profile"]
	if not prof.has("inventory") or typeof(prof["inventory"]) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	return deserialize(prof["inventory"])

func save_to_store(store: ProfileStore, slot: String = "profile_01") -> Error:
	if store == null:
		return ERR_INVALID_PARAMETER
	var res: Dictionary = store.load_profile(slot)
	var prof: Dictionary = {}
	if res["error"] == ERR_FILE_NOT_FOUND:
		prof = store.new_profile(slot)
	elif res["error"] == OK:
		prof = (res["profile"] as Dictionary).duplicate(true)
	else:
		return res["error"]
	prof["inventory"] = serialize()
	return store.save_profile(slot, prof)
