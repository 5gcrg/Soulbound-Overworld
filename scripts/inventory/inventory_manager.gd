class_name InventoryManager
extends RefCounted

## InventoryManager — SBL-W6-002 M3 secured town gear and at-risk expedition satchel system.
## Requirements: GDD-025/026/027/028/029/030, GDD-032/034/035/036/037, FR-INV-001/002,
## FR-ITM-001/002, FR-DNG-002/003, TC-INV-001/002, AGENTS.md Invariants.
##
## Core Invariants:
##   - Banked items are secured in town and NEVER lost upon expedition defeat.
##   - Satchel items are gathered during expeditions and are at-risk until extraction.
##   - Defeat in an expedition wipes the satchel but leaves banked items and equipped gear intact.
##   - Successful extraction transfers satchel contents into the bank exactly once.
##
## OD-007 owner-approved inventory/currency rules (10 Nov 2026):
##   - One 20-slot MVP inventory split into the secured bank and the at-risk satchel.
##     A slot is one distinct item stack; there is no inventory expansion in the
##     academic MVP (capacity is a fixed constant, never grown at runtime).
##   - A stack holds at most 99 units of one item type across bank + satchel, so an
##     extraction move can never overflow a stack or add a slot (exactly-once safe).
##   - Equipped gear and banked items are secured; satchel items stay at risk until
##     extraction. Banked Spirit Coins are secured; satchel currency follows the
##     same satchel-loss policy as satchel items.
##   - No tokens, PvP economy, monetization, or trading exists or is added here.
##
## OD-006 owner-approved gear/refinement rules (10 Nov 2026):
##   - Five tiers: Common, Uncommon, Rare, Epic, Legendary (GDD-032), held per item
##     type with Common as the default; no random affix rolls exist in the MVP.
##   - Refinement is deterministic (no RNG anywhere in this script), can never
##     destroy the item, and costs base_item_cost x next_tier_index read from the
##     authored item cost table (which ships empty: no item value is invented).
##   - Character progression owns new capabilities; gear owns specialization and
##     magnitude: refining changes only an item's tier, never a character attribute.

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

## OD-007: fixed MVP inventory capacity. One shared budget of distinct item stacks
## across bank + satchel; never expanded in the academic MVP.
const MAX_INVENTORY_SLOTS: int = 20
## OD-007: maximum units of one item type per stack (stackable consumables/materials),
## counted across bank + satchel.
const MAX_STACK_SIZE: int = 99

## OD-006: the five approved rarity tiers, ordered by index.
const TIER_COMMON: int = 0
const TIER_UNCOMMON: int = 1
const TIER_RARE: int = 2
const TIER_EPIC: int = 3
const TIER_LEGENDARY: int = 4
const TIER_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

var banked_items: Dictionary = {} # String (item_id) -> int (count) — secured
var satchel_items: Dictionary = {} # String (item_id) -> int (count) — at risk until extraction
var equipment: Dictionary = {
	"weapon": "",
	"armor": "",
	"relic_1": "",
	"relic_2": ""
}
## OD-007: banked Spirit Coins are secured; satchel currency is at risk until extraction.
var banked_coins: int = 0
var satchel_coins: int = 0
## OD-006: refinement tier per item type (default TIER_COMMON when absent).
var item_tiers: Dictionary = {} # String (item_id) -> int (tier index)
## OD-006: the authored base_item_cost table used by refine_item(). This is the
## designated content table and ships EMPTY: FR-ITM-002 allows refinement "once
## costs are authored", so no item cost value is invented in this slice.
var base_item_cost_table: Dictionary = {} # String (item_id) -> int (base cost)

# ==============================================================================
# OD-007 capacity, stack and currency boundaries
# ==============================================================================

## Distinct item stacks occupied across bank + satchel (the shared 20-slot budget).
func inventory_slot_count() -> int:
	var ids: Dictionary = {}
	for item_id: Variant in banked_items.keys():
		ids[item_id] = true
	for item_id: Variant in satchel_items.keys():
		ids[item_id] = true
	return ids.size()

## Total units of one item type owned across bank + satchel.
func item_total_count(item_id: String) -> int:
	if item_id.is_empty():
		return 0
	return int(banked_items.get(item_id, 0)) + int(satchel_items.get(item_id, 0))

## True when adding `count` units of `item_id` keeps both OD-007 boundaries:
## the stack stays <= MAX_STACK_SIZE and the inventory stays <= MAX_INVENTORY_SLOTS.
func can_add_item(item_id: String, count: int = 1) -> bool:
	if item_id.is_empty() or count <= 0:
		return false
	if item_total_count(item_id) + count > MAX_STACK_SIZE:
		return false
	if banked_items.has(item_id) or satchel_items.has(item_id):
		return true
	return inventory_slot_count() < MAX_INVENTORY_SLOTS

## Adds to the secured bank. All-or-nothing: returns false with zero mutation when
## the stack or slot boundary would be crossed.
func add_banked_item(item_id: String, count: int = 1) -> bool:
	return _add_item(banked_items, item_id, count)

## Adds to the at-risk satchel. Same all-or-nothing boundaries as the bank.
func add_satchel_item(item_id: String, count: int = 1) -> bool:
	return _add_item(satchel_items, item_id, count)

func _add_item(container: Dictionary, item_id: String, count: int) -> bool:
	if not can_add_item(item_id, count):
		return false
	container[item_id] = int(container.get(item_id, 0)) + count
	return true

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

## OD-007: secures Spirit Coins in the bank (counts must be positive integers).
func add_banked_coins(amount: int) -> bool:
	if amount <= 0:
		return false
	banked_coins += amount
	return true

## OD-007: records currency found during an expedition; at risk until extraction.
func add_satchel_coins(amount: int) -> bool:
	if amount <= 0:
		return false
	satchel_coins += amount
	return true

# ==============================================================================
# OD-008 terminal transfers (extraction exactly once, defeat loss policy)
# ==============================================================================

## Moves every satchel stack and all satchel currency into the secured bank.
## Move semantics (not acquisition): each stack is transferred as-is so loot can
## never be destroyed by the add-time capacity boundaries, and the satchel is
## cleared so a second call transfers nothing (exactly once).
func extract_satchel_to_bank() -> Dictionary:
	var extracted: Dictionary = satchel_items.duplicate()
	for item_id: String in extracted.keys():
		banked_items[item_id] = int(banked_items.get(item_id, 0)) + int(extracted[item_id])
	satchel_items.clear()
	# OD-007/008: satchel currency follows the same exactly-once move; banked
	# Spirit Coins were already secured and are never touched by this call.
	if satchel_coins > 0:
		banked_coins += satchel_coins
		satchel_coins = 0
	return extracted

## OD-008 defeat policy: loses ALL unbanked satchel contents (items and currency)
## and preserves banked items, equipped gear, and everything permanent. Defeat
## grants no consolation EXP or currency - this function only removes.
func handle_expedition_defeat() -> Dictionary:
	var lost: Dictionary = satchel_items.duplicate()
	satchel_items.clear()
	satchel_coins = 0
	# Banked gear, banked Spirit Coins and equipment remain 100% secured.
	return lost

# ==============================================================================
# Equipment (secured ownership; OD-007 transactional swap)
# ==============================================================================

func equip_item(slot: StringName, item_id: String) -> bool:
	if not VALID_EQUIP_SLOTS.has(slot):
		return false
	if not item_id.is_empty() and not banked_items.has(item_id):
		return false
	var prev_item: String = equipment.get(String(slot), "")

	# OD-006/007 transactional swap: free the new item's bank entry first, then
	# return the previously equipped item; if the return cannot fit the shared
	# boundaries, restore the exact prior bank state so no item is ever destroyed.
	if not item_id.is_empty():
		if not remove_banked_item(item_id, 1):
			return false
	if not prev_item.is_empty():
		if not add_banked_item(prev_item, 1):
			if not item_id.is_empty():
				# Direct restore of the entry we just removed: cannot fail, so the
				# pre-swap state (banked item + equipped gear) is always preserved.
				banked_items[item_id] = int(banked_items.get(item_id, 0)) + 1
			return false
	equipment[String(slot)] = item_id
	return true

func unequip_item(slot: StringName) -> bool:
	return equip_item(slot, "")

# ==============================================================================
# OD-006 deterministic tiers and refinement
# ==============================================================================

## Stored tier for an item type; unlisted items are Common (index 0).
func get_item_tier(item_id: String) -> int:
	var tier: Variant = item_tiers.get(item_id, TIER_COMMON)
	if typeof(tier) == TYPE_INT:
		return clampi(int(tier), TIER_COMMON, TIER_LEGENDARY)
	if typeof(tier) == TYPE_FLOAT:
		return clampi(int(tier), TIER_COMMON, TIER_LEGENDARY)
	return TIER_COMMON

func get_item_tier_name(item_id: String) -> String:
	return TIER_NAMES[get_item_tier(item_id)]

## OD-006 approved refinement cost: base_item_cost x next_tier_index.
## Returns -1 when the inputs are unusable or the item is already Legendary
## (there is no next tier), so callers can refuse without mutating anything.
static func refinement_cost(base_item_cost: int, current_tier_index: int) -> int:
	if base_item_cost <= 0:
		return -1
	if current_tier_index < TIER_COMMON or current_tier_index >= TIER_LEGENDARY:
		return -1
	return base_item_cost * (current_tier_index + 1)

## Deterministic one-tier refinement of banked gear (FR-ITM-002 / TC-INV-002).
## - Reads base_item_cost from the authored item cost table; an unauthored item
##   is refused (no value is invented, no resource is consumed).
## - On any failure the inventory is byte-identical: invalid upgrades never
##   consume resources and the item is never destroyed.
## - On success the item keeps its count, exactly `cost` banked Spirit Coins are
##   debited, and the tier advances by one. No RNG is involved: the same inputs
##   always yield the same result (no random affix rolls in the academic MVP).
## Returns {"error", "reason", "item_id", "cost", "tier", "new_tier"}.
func refine_item(item_id: String) -> Dictionary:
	var current_tier: int = get_item_tier(item_id)
	var result: Dictionary = {
		"error": OK,
		"reason": "",
		"item_id": item_id,
		"cost": 0,
		"tier": current_tier,
		"new_tier": current_tier
	}
	if item_id.is_empty() or int(banked_items.get(item_id, 0)) <= 0:
		result["error"] = ERR_INVALID_PARAMETER
		result["reason"] = "item_not_banked"
		return result
	if current_tier >= TIER_LEGENDARY:
		result["error"] = ERR_PARAMETER_RANGE_ERROR
		result["reason"] = "tier_cap"
		return result
	var base_cost: int = int(base_item_cost_table.get(item_id, -1))
	if base_cost <= 0:
		result["error"] = ERR_DOES_NOT_EXIST
		result["reason"] = "cost_not_authored"
		return result
	var cost: int = refinement_cost(base_cost, current_tier)
	if cost <= 0:
		result["error"] = ERR_PARAMETER_RANGE_ERROR
		result["reason"] = "invalid_cost"
		return result
	if banked_coins < cost:
		result["error"] = ERR_UNAVAILABLE
		result["reason"] = "insufficient_coins"
		return result
	# Deterministic commit: debit the cost, advance exactly one tier, keep the item.
	banked_coins -= cost
	item_tiers[item_id] = current_tier + 1
	result["cost"] = cost
	result["new_tier"] = current_tier + 1
	return result

# ==============================================================================
# Persistence
# ==============================================================================

func serialize() -> Dictionary:
	return {
		"banked": banked_items.duplicate(),
		"satchel": satchel_items.duplicate(),
		"equipment": equipment.duplicate(),
		"tiers": item_tiers.duplicate(),
		"banked_coins": banked_coins,
		"satchel_coins": satchel_coins
	}

func deserialize(data: Dictionary) -> Error:
	if typeof(data.get("banked", {})) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	if typeof(data.get("satchel", {})) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	if typeof(data.get("equipment", {})) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	var new_banked: Dictionary = (data.get("banked", {}) as Dictionary).duplicate()
	var new_satchel: Dictionary = (data.get("satchel", {}) as Dictionary).duplicate()

	var new_equipment: Dictionary = {}
	var eq: Dictionary = data.get("equipment", {}) as Dictionary
	for slot: StringName in VALID_EQUIP_SLOTS:
		new_equipment[String(slot)] = String(eq.get(String(slot), ""))

	# OD-006 tiers: optional so legacy saves load unchanged; malformed or
	# out-of-range entries are rejected before any state is committed.
	var new_tiers: Dictionary = {}
	var tiers_val: Variant = data.get("tiers", {})
	if typeof(tiers_val) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	for item_id: Variant in (tiers_val as Dictionary).keys():
		if typeof(item_id) != TYPE_STRING or String(item_id).is_empty():
			return ERR_INVALID_DATA
		var tier_val: Variant = (tiers_val as Dictionary)[item_id]
		if typeof(tier_val) != TYPE_INT and typeof(tier_val) != TYPE_FLOAT:
			return ERR_INVALID_DATA
		var tier_f: float = float(tier_val)
		if is_nan(tier_f) or is_inf(tier_f) or tier_f != floor(tier_f):
			return ERR_INVALID_DATA
		var tier_i: int = int(tier_f)
		if tier_i < TIER_COMMON or tier_i > TIER_LEGENDARY:
			return ERR_INVALID_DATA
		new_tiers[String(item_id)] = tier_i

	# OD-007 currency: optional, non-negative bounded integers (legacy = 0).
	var new_banked_coins: int = _read_nonneg_int(data, "banked_coins")
	var new_satchel_coins: int = _read_nonneg_int(data, "satchel_coins")
	if new_banked_coins < 0 or new_satchel_coins < 0:
		return ERR_INVALID_DATA

	# Atomic commit: mutate self only after every section validated.
	banked_items = new_banked
	satchel_items = new_satchel
	equipment = new_equipment
	item_tiers = new_tiers
	banked_coins = new_banked_coins
	satchel_coins = new_satchel_coins
	return OK

## Reads an optional non-negative integer from JSON-parsed data (Godot parses
## whole numbers as float). Returns -1 when present but invalid, 0 when absent.
static func _read_nonneg_int(data: Dictionary, key: String) -> int:
	if not data.has(key):
		return 0
	var v: Variant = data[key]
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return -1
	var f: float = float(v)
	if is_nan(f) or is_inf(f) or f != floor(f) or f < 0.0 or f > 9007199254740991.0:
		return -1
	return int(f)

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
