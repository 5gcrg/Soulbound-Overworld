extends SceneTree

## OD-005/006/007/008 owner-approved progression & economy batch test suite.
## Requirements: GDD-024..030, GDD-034/035, FR-PRG-001/002, FR-INV-001/002,
## FR-DNG-002, FR-SAV-001, TC-PRG-001, TC-INV-001/002, TC-DNG-003/004, TC-SAV-001.
##
## Covers:
##   OD-005 - XP formula, level cap 30, 2 points/level, +1 allocations,
##            max(0, level - 1) Kurei talent points, no negative XP / level loss,
##            cap load-save roundtrip (TC-PRG-001).
##   OD-006 - five approved tiers, deterministic refinement cost
##            (base_item_cost x next_tier_index), no random affix rolls,
##            refinement can never destroy an item (TC-INV-002).
##   OD-007 - 20-slot shared inventory budget, 99-unit stacks, bank/satchel
##            security, banked vs. satchel Spirit Coins (TC-INV-001).
##   OD-008 - defeat loses all unbanked satchel and preserves permanent data
##            with no consolation EXP/currency, extraction transfers exactly once
##            and clears the snapshot, failed persistence leaves the run open
##            (TC-DNG-003/004, TC-SAV-001).

const GameRootScene: PackedScene = preload("res://scenes/main/game_root.tscn")

const ROOT_PREFIX: String = "user://sbl_od005_008_"

var _failures: int = 0
var _checks: int = 0
var _test_root: String = ""

func _check(ok: bool, msg: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("PROGRESSION ECONOMY TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	_test_root = ROOT_PREFIX + "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_od005_progression()
	_test_od006_refinement()
	_test_od007_inventory_capacity()
	await _test_od008_defeat_extraction()
	_cleanup_dir(_test_root)

	if _failures > 0:
		printerr("PROGRESSION ECONOMY TESTS FAILED: ", _failures, " / ", _checks, " checks")
		quit(1)
		return

	print("=== ALL OD-005..008 PROGRESSION ECONOMY TESTS PASSED SUCCESSFULLY (%d checks) ===" % _checks)
	quit(0)

# ==============================================================================
# OD-005 - progression formulas, level cap, allocation (TC-PRG-001)
# ==============================================================================

func _test_od005_progression() -> void:
	print("--- OD-005 progression ---")

	# XP threshold formula: 100 x current level at every sampled level.
	var probe: CharacterStats = CharacterStats.new()
	for lvl: int in [1, 2, 15, 29, 30]:
		probe.level = lvl
		probe.xp = 0
		_check(probe.get_xp_for_next_level() == 100 * lvl,
			"XP to next level is 100 x current level at level %d" % lvl)

	# Level-up grants exactly 2 attribute points; each allocation is +1 to one of
	# the four approved attributes and never anything else.
	var stats: CharacterStats = CharacterStats.new()
	_check(CharacterStats.LEVEL_CAP == 30, "Approved level cap is 30 (GDD-029)")
	_check(CharacterStats.POINTS_PER_LEVEL == 2, "Level-up reward is 2 attribute points")
	var gained: int = stats.add_xp(99)
	_check(gained == 0 and stats.level == 1 and stats.xp == 99,
		"99 XP stays below the level-1 threshold (100 x 1)")
	gained = stats.add_xp(1)
	_check(gained == 1 and stats.level == 2 and stats.xp == 0,
		"Crossing 100 XP levels to 2 with 0 leftover")
	_check(stats.unspent_points == 2, "Level-up awarded exactly 2 attribute points")

	var base_vit: int = stats.vitality
	var base_res: int = stats.resonance
	var base_agi: int = stats.agility
	var base_foc: int = stats.focus
	_check(stats.allocate_point(CharacterStats.ATTR_VITALITY) and stats.vitality == base_vit + 1,
		"Allocation adds +1 Vitality")
	_check(stats.allocate_point(CharacterStats.ATTR_RESONANCE) and stats.resonance == base_res + 1,
		"Allocation adds +1 Resonance")
	_check(stats.unspent_points == 0, "Both points consumed")
	_check(not stats.allocate_point(CharacterStats.ATTR_AGILITY), "Allocation rejected with no points left")
	_check(not stats.allocate_point(&"luck"), "Unknown attribute rejected")
	_check(stats.agility == base_agi and stats.focus == base_foc,
		"Rejected allocations change nothing")

	# No negative XP and no level loss (OD-005 / OD-008 defeat policy).
	var xp_before: int = stats.xp
	var level_before: int = stats.level
	_check(stats.add_xp(-500) == 0 and stats.xp == xp_before and stats.level == level_before,
		"Negative XP is refused - XP never goes down")
	_check(stats.add_xp(0) == 0, "Zero XP awards nothing")

	# Level cap: the exact approved XP total lands on level 30 and stops there.
	var cap_stats: CharacterStats = CharacterStats.new()
	var total_to_cap: int = 0
	for lvl: int in range(1, CharacterStats.LEVEL_CAP):
		total_to_cap += 100 * lvl # sum(100 x level) for level 1..29 = 43500
	gained = cap_stats.add_xp(total_to_cap)
	_check(cap_stats.level == CharacterStats.LEVEL_CAP,
		"Exact approved XP total reaches level 30")
	_check(cap_stats.xp == 0, "Exact cap XP leaves 0 leftover")
	_check(gained == 29, "29 level-ups from level 1 to 30")
	_check(cap_stats.unspent_points == 29 * CharacterStats.POINTS_PER_LEVEL,
		"2 attribute points per level across all 29 level-ups (58 total)")
	_check(cap_stats.is_at_level_cap(), "is_at_level_cap() true at level 30")

	var xp_at_cap: int = cap_stats.xp
	var points_at_cap: int = cap_stats.unspent_points
	_check(cap_stats.add_xp(100000) == 0, "No level gained once at the cap")
	_check(cap_stats.level == CharacterStats.LEVEL_CAP and cap_stats.xp == xp_at_cap
		and cap_stats.unspent_points == points_at_cap,
		"Cap absorbs further XP with zero extra levels or points (no raw inflation)")
	_check(cap_stats.add_xp(-1000) == 0 and cap_stats.level == CharacterStats.LEVEL_CAP,
		"Negative XP at the cap never lowers the level")

	# Load clamps: level stays within [1, 30], XP stays >= 0 (no level loss, no
	# past-cap levels from tampered or legacy data).
	var tampered: CharacterStats = CharacterStats.new()
	_check(tampered.deserialize({"level": 999, "xp": 0}) == OK
		and tampered.level == CharacterStats.LEVEL_CAP,
		"Load clamps level 999 down to the cap of 30")
	_check(tampered.deserialize({"level": 0, "xp": -50}) == OK
		and tampered.level == 1 and tampered.xp == 0,
		"Load clamps level 0 to 1 and negative XP to 0")

	# TC-PRG-001: cap state survives a ProfileStore save/load roundtrip.
	var store: ProfileStore = ProfileStore.new(_test_root.path_join("prg"))
	_check(cap_stats.save_to_store(store, "profile_01") == OK, "Capped character saved")
	var loaded: CharacterStats = CharacterStats.new()
	_check(loaded.load_from_store(store, "profile_01") == OK, "Capped character loads")
	_check(loaded.level == CharacterStats.LEVEL_CAP and loaded.xp == xp_at_cap
		and loaded.unspent_points == points_at_cap,
		"TC-PRG-001 roundtrip preserves level 30, XP and attribute points")
	_check(loaded.vitality == cap_stats.vitality and loaded.agility == cap_stats.agility,
		"Roundtrip preserves allocated attributes")

	# The backup validator enforces the same cap at the data boundary.
	var over_cap: Dictionary = store.new_profile("profile_02")
	over_cap["character"] = {"level": CharacterStats.LEVEL_CAP + 1, "xp": 0}
	_check(GameplayProfileValidator.validate(over_cap) != OK,
		"Validator rejects a level above the cap (TC-PRG-001)")
	over_cap["character"] = {"level": CharacterStats.LEVEL_CAP, "xp": 0}
	_check(GameplayProfileValidator.validate(over_cap) == OK,
		"Validator accepts a level at the cap")

	# Kurei talent points keep the approved max(0, level - 1) rule (OD-005).
	var tree: KureiTree = KureiTree.new()
	tree.sync_with_level(1)
	_check(tree.total_talent_points == 0, "Level 1 grants 0 Kurei talent points")
	tree.sync_with_level(0)
	_check(tree.total_talent_points == 0, "Level 0 grants 0 points (never negative)")
	tree.sync_with_level(CharacterStats.LEVEL_CAP)
	_check(tree.total_talent_points == 29,
		"Level 30 grants 29 Kurei talent points (max(0, level - 1))")
	var capped_sync: CharacterStats = CharacterStats.new()
	capped_sync.deserialize({"level": CharacterStats.LEVEL_CAP, "xp": 0})
	var capped_tree: KureiTree = KureiTree.new()
	capped_tree.sync_with_level(capped_sync.level)
	_check(capped_tree.get_unspent_points() == 29,
		"Capped character holds exactly 29 unspent Kurei talent points")

	print("PASS: OD-005 progression verified")

# ==============================================================================
# OD-006 - deterministic tiers and refinement (TC-INV-002)
# ==============================================================================

func _test_od006_refinement() -> void:
	print("--- OD-006 deterministic tiers & refinement ---")

	# The five approved tiers, in order (GDD-032).
	var expected_tiers: Array = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
	var names_ok: bool = InventoryManager.TIER_NAMES.size() == expected_tiers.size()
	for i: int in range(expected_tiers.size()):
		if InventoryManager.TIER_NAMES[i] != expected_tiers[i]:
			names_ok = false
	_check(names_ok, "Five approved tiers in order: Common/Uncommon/Rare/Epic/Legendary")
	_check(InventoryManager.TIER_COMMON == 0 and InventoryManager.TIER_LEGENDARY == 4,
		"Tier indices span 0..4")
	var fresh: InventoryManager = InventoryManager.new()
	_check(fresh.get_item_tier("unknown_item") == InventoryManager.TIER_COMMON,
		"Unlisted items default to Common")
	_check(fresh.get_item_tier_name("unknown_item") == "Common",
		"Default tier name is Common")

	# Approved cost formula: base_item_cost x next_tier_index.
	_check(InventoryManager.refinement_cost(100, 0) == 100, "Common -> Uncommon costs base x 1")
	_check(InventoryManager.refinement_cost(100, 1) == 200, "Uncommon -> Rare costs base x 2")
	_check(InventoryManager.refinement_cost(100, 2) == 300, "Rare -> Epic costs base x 3")
	_check(InventoryManager.refinement_cost(100, 3) == 400, "Epic -> Legendary costs base x 4")
	_check(InventoryManager.refinement_cost(100, 4) == -1,
		"Legendary has no next tier - refinement refused")
	_check(InventoryManager.refinement_cost(0, 0) == -1
		and InventoryManager.refinement_cost(-5, 0) == -1,
		"Non-positive base cost refused (no invented value)")
	_check(InventoryManager.refinement_cost(100, -1) == -1, "Negative tier index refused")

	# Successful deterministic refinement: cost debited, tier advanced, item kept.
	var inv: InventoryManager = InventoryManager.new()
	_check(inv.add_banked_item("iron_sword", 1), "Banked iron sword")
	inv.banked_coins = 1000 # test fixture value, not a game economy value
	inv.base_item_cost_table["iron_sword"] = 100 # test stand-in for the authored table

	var first: Dictionary = inv.refine_item("iron_sword")
	_check(int(first["error"]) == OK, "Refinement succeeds once a cost is authored")
	_check(int(first["cost"]) == 100, "First refinement costs base x 1 = 100")
	_check(inv.banked_coins == 900, "Cost debited exactly once from banked Spirit Coins")
	_check(inv.get_item_tier("iron_sword") == InventoryManager.TIER_UNCOMMON,
		"Tier advanced Common -> Uncommon")
	_check(int(inv.banked_items.get("iron_sword", 0)) == 1,
		"Item preserved after refinement (never destroyed)")

	var second: Dictionary = inv.refine_item("iron_sword")
	_check(int(second["error"]) == OK and int(second["cost"]) == 200 and inv.banked_coins == 700,
		"Second refinement costs base x 2 = 200 and debits exactly 200")
	_check(inv.get_item_tier("iron_sword") == InventoryManager.TIER_RARE,
		"Tier advanced Uncommon -> Rare")

	# Determinism: identical inputs on separate instances yield identical results.
	var det_a: InventoryManager = InventoryManager.new()
	var det_b: InventoryManager = InventoryManager.new()
	for d: InventoryManager in [det_a, det_b]:
		d.add_banked_item("iron_sword", 1)
		d.banked_coins = 1000
		d.base_item_cost_table["iron_sword"] = 100
	var res_a: Dictionary = det_a.refine_item("iron_sword")
	var res_b: Dictionary = det_b.refine_item("iron_sword")
	_check(JSON.stringify(res_a) == JSON.stringify(res_b)
		and det_a.serialize().hash() == det_b.serialize().hash(),
		"Refinement is deterministic: same inputs, same result, same state")

	# FR-ITM-002: every failed refinement mutates nothing and destroys nothing.
	var fail_inv: InventoryManager = InventoryManager.new()
	fail_inv.add_banked_item("iron_sword", 1)
	fail_inv.add_banked_item("mystery_relic", 1)
	fail_inv.banked_coins = 1000
	fail_inv.base_item_cost_table["iron_sword"] = 100

	var snap: String = JSON.stringify(fail_inv.serialize())
	_check(int(fail_inv.refine_item("ghost_blade")["error"]) == ERR_INVALID_PARAMETER,
		"Unbanked item refused")
	_check(JSON.stringify(fail_inv.serialize()) == snap,
		"Failed refine (unbanked) leaves state byte-identical")

	snap = JSON.stringify(fail_inv.serialize())
	var no_cost: Dictionary = fail_inv.refine_item("mystery_relic")
	_check(int(no_cost["error"]) == ERR_DOES_NOT_EXIST
		and String(no_cost["reason"]) == "cost_not_authored",
		"Item without an authored cost refused - no value invented")
	_check(JSON.stringify(fail_inv.serialize()) == snap,
		"Failed refine (cost not authored) leaves state byte-identical")

	fail_inv.banked_coins = 0
	snap = JSON.stringify(fail_inv.serialize())
	_check(int(fail_inv.refine_item("iron_sword")["error"]) == ERR_UNAVAILABLE
		and String(fail_inv.refine_item("iron_sword")["reason"]) == "insufficient_coins",
		"Insufficient banked Spirit Coins refused")
	_check(JSON.stringify(fail_inv.serialize()) == snap,
		"Failed refine (insufficient coins) leaves state byte-identical")

	fail_inv.banked_coins = 1000
	fail_inv.item_tiers["iron_sword"] = InventoryManager.TIER_LEGENDARY
	snap = JSON.stringify(fail_inv.serialize())
	_check(int(fail_inv.refine_item("iron_sword")["error"]) == ERR_PARAMETER_RANGE_ERROR
		and String(fail_inv.refine_item("iron_sword")["reason"]) == "tier_cap",
		"Legendary refinement refused at the approved tier cap")
	_check(JSON.stringify(fail_inv.serialize()) == snap,
		"Failed refine (tier cap) leaves state byte-identical")
	_check(int(fail_inv.banked_items.get("iron_sword", 0)) == 1
		and int(fail_inv.banked_items.get("mystery_relic", 0)) == 1,
		"No failed refinement ever destroyed an item")

	# No random affix rolls in the academic MVP: the inventory code contains no
	# RNG entry points at all (OD-006 negative control).
	var rng_hits: Array[String] = []
	for script_path: String in [
		"res://scripts/inventory/inventory_manager.gd",
		"res://scenes/ui/inventory_sheet.gd"
	]:
		var f: FileAccess = FileAccess.open(script_path, FileAccess.READ)
		_check(f != null, "Readable script for RNG scan: %s" % script_path)
		if f == null:
			continue
		var src: String = f.get_as_text()
		f.close()
		for token: String in ["randi", "randf", "randfn", "randomize", "RandomNumberGenerator",
				"pick_random", "rand_weighted"]:
			if src.findn(token) != -1:
				rng_hits.append("%s:%s" % [script_path, token])
	_check(rng_hits.is_empty(),
		"No RNG / random-affix entry points in inventory code: %s" % str(rng_hits))

	# Persistence: tiers and currency roundtrip exactly; legacy saves keep defaults.
	var persist: InventoryManager = InventoryManager.new()
	persist.add_banked_item("iron_sword", 1)
	persist.add_banked_item("healing_herb", 40)
	persist.item_tiers["iron_sword"] = InventoryManager.TIER_EPIC
	persist.banked_coins = 777
	persist.satchel_coins = 33
	var roundtrip: InventoryManager = InventoryManager.new()
	_check(roundtrip.deserialize(persist.serialize()) == OK,
		"Inventory with tiers and coins deserializes")
	_check(JSON.stringify(roundtrip.serialize()) == JSON.stringify(persist.serialize()),
		"Tiers and coins roundtrip exactly (TC-SAV-001)")
	_check(roundtrip.get_item_tier("iron_sword") == InventoryManager.TIER_EPIC,
		"Epic tier preserved through the roundtrip")
	_check(roundtrip.banked_coins == 777 and roundtrip.satchel_coins == 33,
		"Banked and satchel coins preserved through the roundtrip")

	var legacy: InventoryManager = InventoryManager.new()
	_check(legacy.deserialize({"banked": {"iron_sword": 1}, "satchel": {},
			"equipment": {}}) == OK,
		"Legacy inventory without tiers/coins loads (backward compatible)")
	_check(legacy.get_item_tier("iron_sword") == InventoryManager.TIER_COMMON
		and legacy.banked_coins == 0 and legacy.satchel_coins == 0,
		"Legacy defaults: Common tier and 0 coins")

	# Malformed tier/coin data is rejected atomically (no partial commit).
	var atomic: InventoryManager = InventoryManager.new()
	atomic.add_banked_item("keep_me", 3)
	_check(atomic.deserialize({"banked": {}, "satchel": {}, "equipment": {},
			"tiers": {"iron_sword": 9}}) != OK,
		"Out-of-range tier index rejected")
	_check(int(atomic.banked_items.get("keep_me", 0)) == 3,
		"Failed deserialize leaves prior state untouched")
	_check(atomic.deserialize({"banked": {}, "satchel": {}, "equipment": {},
			"banked_coins": -5}) != OK,
		"Negative banked coins rejected")
	_check(atomic.deserialize({"banked": {}, "satchel": {}, "equipment": {},
			"satchel_coins": "ten"}) != OK,
		"Non-numeric satchel coins rejected")
	_check(int(atomic.banked_items.get("keep_me", 0)) == 3,
		"State still untouched after every malformed load")

	print("PASS: OD-006 deterministic tiers and refinement verified")

# ==============================================================================
# OD-007 - inventory capacity, stacks, bank/satchel security (TC-INV-001)
# ==============================================================================

func _test_od007_inventory_capacity() -> void:
	print("--- OD-007 inventory capacity, stacks, bank/satchel ---")

	_check(InventoryManager.MAX_INVENTORY_SLOTS == 20,
		"Approved MVP inventory capacity is exactly 20 slots (no expansion)")
	_check(InventoryManager.MAX_STACK_SIZE == 99,
		"Approved maximum stack size is exactly 99")

	# 20-slot boundary: 20 distinct stacks fit, the 21st is refused with zero mutation.
	var inv: InventoryManager = InventoryManager.new()
	for i: int in range(InventoryManager.MAX_INVENTORY_SLOTS):
		_check(inv.add_banked_item("slot_item_%d" % i, 1),
			"Slot %d accepted within capacity" % (i + 1))
	_check(inv.inventory_slot_count() == 20, "Bank holds exactly 20 slots")
	_check(not inv.add_banked_item("slot_item_20", 1), "21st distinct bank stack refused")
	_check(not inv.add_satchel_item("fresh_loot", 1),
		"21st distinct stack refused in the satchel as well")
	_check(inv.inventory_slot_count() == 20 and not inv.banked_items.has("slot_item_20")
		and not inv.satchel_items.has("fresh_loot"),
		"Refused adds mutate nothing (all-or-nothing)")

	# One shared budget: bank + satchel together never exceed 20 slots.
	var shared: InventoryManager = InventoryManager.new()
	for i: int in range(10):
		_check(shared.add_banked_item("bank_item_%d" % i, 1), "Shared bank slot %d" % (i + 1))
	for i: int in range(10):
		_check(shared.add_satchel_item("loot_item_%d" % i, 1), "Shared satchel slot %d" % (i + 1))
	_check(shared.inventory_slot_count() == 20, "Bank 10 + satchel 10 = 20 shared slots")
	_check(not shared.add_banked_item("extra", 1) and not shared.add_satchel_item("extra", 1),
		"Shared budget blocks both containers once 20 slots are occupied")

	# 99-unit stack ceiling, counted across bank + satchel for one item type.
	var stack: InventoryManager = InventoryManager.new()
	_check(stack.add_satchel_item("healing_herb", 99), "99-unit stack accepted")
	_check(not stack.add_satchel_item("healing_herb", 1), "100th unit refused (stack ceiling)")
	_check(int(stack.satchel_items["healing_herb"]) == 99, "Stack stays at exactly 99")
	var split: InventoryManager = InventoryManager.new()
	_check(split.add_banked_item("spirit_salve", 60), "60 units banked")
	_check(not split.add_satchel_item("spirit_salve", 40),
		"Combined bank + satchel may not exceed 99 for one item type")
	_check(split.add_satchel_item("spirit_salve", 39), "Combined total of exactly 99 accepted")
	_check(split.item_total_count("spirit_salve") == 99, "Combined total is 99")
	_check(not split.can_add_item("spirit_salve", 1),
		"can_add_item reflects the approved stack ceiling")
	_check(split.add_satchel_item("fresh_herb", 1),
		"A new item type still fits while slots remain")

	# Bank/satchel security: defeat wipes only unbanked satchel state (items +
	# currency) and preserves banked items, equipped gear and banked coins.
	var sec: InventoryManager = InventoryManager.new()
	sec.add_banked_item("iron_sword", 1)
	sec.add_banked_item("healing_herb", 10)
	_check(sec.equip_item(InventoryManager.SLOT_WEAPON, "iron_sword"), "Equipped weapon from bank")
	_check(sec.add_banked_coins(500), "Banked 500 Spirit Coins (secured)")
	_check(sec.add_satchel_item("ancient_relic_fragment", 6), "Gathered 6 satchel fragments")
	_check(sec.add_satchel_coins(120), "Found 120 satchel coins (at risk)")

	var lost: Dictionary = sec.handle_expedition_defeat()
	_check(int(lost.get("ancient_relic_fragment", 0)) == 6,
		"Defeat reports the lost satchel stacks (TC-DNG-003)")
	_check(sec.satchel_items.is_empty() and sec.satchel_coins == 0,
		"Defeat loses ALL unbanked satchel items and currency")
	_check(int(sec.banked_items.get("healing_herb", 0)) == 10,
		"Banked items survive defeat (secured)")
	_check(sec.equipment["weapon"] == "iron_sword",
		"Equipped gear survives defeat (secured)")
	_check(sec.banked_coins == 500,
		"Banked Spirit Coins survive defeat and defeat grants no consolation currency")

	# Extraction moves items + currency exactly once (TC-DNG-004 with OD-007 currency).
	var ext: InventoryManager = InventoryManager.new()
	ext.add_banked_item("healing_herb", 10)
	ext.add_banked_coins(500)
	ext.add_satchel_item("ancient_relic_fragment", 6)
	ext.add_satchel_coins(70)
	var first_extract: Dictionary = ext.extract_satchel_to_bank()
	_check(int(first_extract.get("ancient_relic_fragment", 0)) == 6,
		"Extraction returns the moved stacks")
	_check(int(ext.banked_items.get("ancient_relic_fragment", 0)) == 6,
		"Satchel items banked on extraction")
	_check(ext.banked_coins == 570 and ext.satchel_coins == 0,
		"Satchel currency moved into the secured bank")
	var second_extract: Dictionary = ext.extract_satchel_to_bank()
	_check(second_extract.is_empty() and ext.banked_coins == 570
		and int(ext.banked_items.get("ancient_relic_fragment", 0)) == 6,
		"Second extraction transfers nothing (exactly once)")

	# OD-008 defeat never grants anything: defeat on a full state only removes.
	var no_gain: Dictionary = ext.handle_expedition_defeat()
	_check(no_gain.is_empty() and ext.banked_coins == 570
		and int(ext.banked_items.get("ancient_relic_fragment", 0)) == 6,
		"Defeat of an empty satchel grants no items or currency (no consolation)")

	# Untrusted suspend snapshots must respect the OD-007 boundaries.
	var over_stack: Dictionary = {"is_active": true, "seed": 1, "room_count": 4,
		"expedition_path": [1, 2], "current_step": 0, "satchel_items": {"a": 100}}
	_check(GameplayProfileValidator._validate_active_expedition(over_stack) != OK,
		"Snapshot stack above 99 rejected")
	var many_stacks: Dictionary = {}
	for i: int in range(InventoryManager.MAX_INVENTORY_SLOTS + 1):
		many_stacks["stack_item_%d" % i] = 1
	over_stack["satchel_items"] = many_stacks
	_check(GameplayProfileValidator._validate_active_expedition(over_stack) != OK,
		"Snapshot with 21 distinct stacks rejected")
	over_stack["satchel_items"] = {"a": 1}
	over_stack["satchel_coins"] = -3
	_check(GameplayProfileValidator._validate_active_expedition(over_stack) != OK,
		"Negative snapshot currency rejected")
	over_stack["satchel_coins"] = 5
	_check(GameplayProfileValidator._validate_active_expedition(over_stack) == OK,
		"Valid snapshot with at-risk currency accepted")

	print("PASS: OD-007 inventory capacity, stacks and currency verified")

# ==============================================================================
# OD-008 - defeat preservation/loss, extraction exactly-once, retry (GameRoot)
# ==============================================================================

func _open_game_expedition(game_inst: Node) -> bool:
	var gw: Area2D = game_inst.world_router.active_region.get_node("ExpeditionGateway") as Area2D
	return game_inst._try_open_expedition(gw.get_instance_id())

func _test_od008_defeat_extraction() -> void:
	print("--- OD-008 defeat preservation / extraction exactly-once ---")
	var store: ProfileStore = ProfileStore.new(_test_root.path_join("od008"))

	# Seed permanent state: level/XP/attributes, Kurei skills/talents, story,
	# education, secured bank + equipment + banked Spirit Coins.
	var seeded: Dictionary = store.new_profile("profile_01")
	seeded["character"]["level"] = 7
	seeded["character"]["xp"] = 350
	seeded["character"]["vitality"] = 14
	seeded["character"]["resonance"] = 12
	seeded["character"]["agility"] = 11
	seeded["character"]["focus"] = 10
	seeded["character"]["unspent_points"] = 3
	seeded["character"]["kurei_tree"] = {
		"unlocked_skills": ["flame_burst", "lumina_lance", "torrent_surge", "solar_flare"],
		"equipped_skills": ["flame_burst", "lumina_lance", "torrent_surge"],
		"spent_talent_points": 2,
		"total_talent_points": 6
	}
	seeded["inventory"]["banked"] = {"iron_sword": 1, "healing_herb": 4}
	seeded["inventory"]["satchel"] = {}
	seeded["inventory"]["equipment"] = {"weapon": "", "armor": "", "relic_1": "", "relic_2": ""}
	seeded["inventory"]["banked_coins"] = 250
	seeded["inventory"]["satchel_coins"] = 0
	seeded["world"]["chapter_progress"] = {
		"current_chapter": 1,
		"unlocked_chapters": [1],
		"is_academic_complete": false,
		"chapter_flags": {}
	}
	seeded["education"]["records"] = {
		"q_dec_01": {
			"id": "q_dec_01",
			"competency": "Decision-Making",
			"completed": true,
			"first_attempt_correct": true,
			"total_attempts": 1,
			"selected_index": 0
		}
	}
	_check(store.save_profile("profile_01", seeded) == OK, "OD-008 baseline profile saved")
	_check(GameplayProfileValidator.validate(seeded) == OK, "Baseline profile validates")
	var baseline_text: String = JSON.stringify(store.load_profile("profile_01")["profile"])

	var game = GameRootScene.instantiate()
	game.profile_store = store
	root.add_child(game)
	game._init_slice_progress(store, "profile_01")
	await process_frame
	_check(JSON.stringify(store.load_profile("profile_01")["profile"]) == baseline_text,
		"Session boot leaves the profile byte-identical (OD-009 boundary preserved)")

	# ---- Defeat: lose every unbanked satchel unit, preserve permanent data ----
	_check(_open_game_expedition(game), "Expedition opened for the defeat probe")
	game._expedition._on_advance_pressed()
	_check(game.inventory_manager.add_satchel_coins(75),
		"Run found at-risk satchel currency (test fixture amount)")
	var d_satchel: int = game.inventory_manager.satchel_items.get("ancient_relic_fragment", 0)
	_check(d_satchel > 0, "Run gathered at-risk satchel loot")
	var pre_profile: Dictionary = store.load_profile("profile_01")["profile"]

	game._expedition.retreat_btn.pressed.emit()
	await process_frame
	_check(game._expedition == null, "Expedition closed after defeat")

	var post: Dictionary = store.load_profile("profile_01")["profile"]
	var post_inv: Dictionary = post["inventory"]
	_check(JSON.stringify(post["character"]) == JSON.stringify(pre_profile["character"]),
		"Defeat leaves character (level/XP/attributes/talents/skills) byte-identical - no consolation EXP, no level loss")
	_check(JSON.stringify(post["world"]) == JSON.stringify(pre_profile["world"]),
		"Defeat leaves story progress byte-identical")
	_check(JSON.stringify(post["education"]) == JSON.stringify(pre_profile["education"]),
		"Defeat leaves education records byte-identical")
	_check(int(post["character"]["level"]) == 7 and int(post["character"]["xp"]) == 350,
		"Level 7 and 350 XP preserved exactly (TC-DNG-003)")
	_check(int(post_inv["banked"].get("iron_sword", 0)) == 1
		and int(post_inv["banked"].get("healing_herb", 0)) == 4,
		"Secured bank items preserved (TC-DNG-003)")
	_check(int(post_inv["banked_coins"]) == 250,
		"Banked Spirit Coins preserved; defeat grants no consolation currency")
	_check((post_inv["satchel"] as Dictionary).is_empty() and int(post_inv["satchel_coins"]) == 0,
		"All unbanked satchel items and currency lost on defeat (OD-008)")
	_check(not (post.get("world", {}) as Dictionary).has("active_expedition"),
		"Defeat clears the persisted run snapshot")

	# ---- Extraction: failed persistence retries, then exact-once transfer ----
	_check(_open_game_expedition(game), "Second expedition opened for the extraction probe")
	game._expedition._on_advance_pressed()
	_check(game.inventory_manager.add_satchel_coins(40),
		"Second run found at-risk currency")
	while not game._expedition.is_at_extraction_chamber():
		game._expedition._on_advance_pressed()
	_check(game._expedition.is_at_extraction_chamber(), "Reached the extraction chamber")
	# Measured at the portal: advancing through rooms keeps adding loot.
	var e_satchel: int = game.inventory_manager.satchel_items.get("ancient_relic_fragment", 0)
	_check(e_satchel > 0, "Second run gathered loot")

	var orig_commit: Callable = game._expedition.commit_extraction
	var fail_once: Dictionary = {"fail": true}
	game._expedition.commit_extraction = func(candidate: InventoryManager) -> Error:
		if bool(fail_once["fail"]):
			fail_once["fail"] = false
			return ERR_FILE_CANT_WRITE
		return orig_commit.call(candidate)

	var fail_res: Dictionary = game._expedition.extract_now()
	_check(fail_res.is_empty(), "Failed persistence reports no transfer")
	_check(game._expedition != null and game._expedition.is_active,
		"Failed persistence leaves the run open for retry (OD-008)")
	_check(game.inventory_manager.satchel_items.get("ancient_relic_fragment", 0) == e_satchel,
		"Satchel items preserved after the failed commit")
	_check(game.inventory_manager.satchel_coins == 40,
		"Satchel currency preserved after the failed commit")
	var disk_after_fail: Dictionary = store.load_profile("profile_01")["profile"]
	_check(int(disk_after_fail["inventory"]["banked"].get("ancient_relic_fragment", 0)) == 0
		and int(disk_after_fail["inventory"]["banked_coins"]) == 250,
		"Failed persistence committed nothing to disk")

	var stale_extract: Callable = game._expedition.commit_extraction
	var retry_res: Dictionary = game._expedition.extract_now()
	_check(retry_res.get("ancient_relic_fragment", 0) == e_satchel,
		"Retry transfers the satchel")
	await process_frame
	_check(game._expedition == null, "Expedition closed after successful extraction")

	var after: Dictionary = store.load_profile("profile_01")["profile"]
	var after_inv: Dictionary = after["inventory"]
	_check(int(after_inv["banked"].get("ancient_relic_fragment", 0)) == e_satchel,
		"Loot banked exactly once (TC-DNG-004)")
	_check(int(after_inv["banked_coins"]) == 250 + 40,
		"Satchel currency banked exactly once")
	_check((after_inv["satchel"] as Dictionary).is_empty()
		and int(after_inv["satchel_coins"]) == 0,
		"Persisted satchel snapshot cleared on extraction")
	_check(not (after.get("world", {}) as Dictionary).has("active_expedition"),
		"Persisted run record cleared on extraction")

	# A repeat attempt through the old callback is rejected and changes nothing.
	var after_text: String = JSON.stringify(after)
	_check(stale_extract.call(game.inventory_manager) == ERR_UNAUTHORIZED,
		"Stale extraction callback rejected (exact-once guard)")
	_check(JSON.stringify(store.load_profile("profile_01")["profile"]) == after_text,
		"Repeat extraction attempt leaves the profile byte-identical")

	# ---- Suspend keeps currency at risk; resume restores it; defeat loses it ----
	_check(_open_game_expedition(game), "Third expedition opened for the suspend probe")
	game._expedition._on_advance_pressed()
	_check(game.inventory_manager.add_satchel_coins(15), "Third run found at-risk currency")
	game._expedition.suspend_btn.pressed.emit()
	await process_frame
	_check(game._expedition == null, "Expedition suspended")
	_check(int(game._suspended_expedition.get("satchel_coins", -1)) == 15,
		"Suspend snapshot carries the at-risk currency (FR-DNG-002)")
	var suspended_profile: Dictionary = store.load_profile("profile_01")["profile"]
	_check(int(suspended_profile["inventory"]["banked_coins"]) == 290,
		"Suspension does not secure currency - suspend is not an extraction")
	_check((suspended_profile["world"] as Dictionary).has("active_expedition"),
		"Suspend persists the run snapshot")

	_check(_open_game_expedition(game), "Suspended run resumed")
	_check(game.inventory_manager.satchel_coins == 15,
		"Resume restores the at-risk currency")
	game._expedition.retreat_btn.pressed.emit()
	await process_frame
	_check(game._expedition == null, "Resumed run defeated")

	var final: Dictionary = store.load_profile("profile_01")["profile"]
	var final_inv: Dictionary = final["inventory"]
	_check(int(final_inv["satchel_coins"]) == 0
		and int(final_inv["banked_coins"]) == 290,
		"Resumed defeat loses only the at-risk currency")
	_check(int(final_inv["banked"].get("healing_herb", 0)) == 4
		and int(final_inv["banked"].get("iron_sword", 0)) == 1,
		"Secured bank intact after the final defeat")
	var final_kurei: Dictionary = final["character"]["kurei_tree"] as Dictionary
	_check((final_kurei.get("unlocked_skills", []) as Array).has("solar_flare"),
		"Kurei skills preserved across every terminal commit")
	_check(int(final["character"]["level"]) == 7 and int(final["character"]["xp"]) == 350,
		"Level and XP still intact after every terminal commit")

	game.queue_free()
	await process_frame
	print("PASS: OD-008 defeat, extraction and retry verified")

# ==============================================================================

func _remove_recursive(global_path: String) -> void:
	var dir: DirAccess = DirAccess.open(global_path)
	if dir == null:
		return
	var subs: PackedStringArray = dir.get_directories()
	var files: PackedStringArray = dir.get_files()
	dir = null # release the handle before deleting on Windows
	for sub: String in subs:
		_remove_recursive(global_path.path_join(sub))
	for fname: String in files:
		DirAccess.remove_absolute(global_path.path_join(fname))
	DirAccess.remove_absolute(global_path)

func _cleanup_dir(path: String) -> void:
	if not path.begins_with(ROOT_PREFIX):
		return
	_remove_recursive(ProjectSettings.globalize_path(path))
