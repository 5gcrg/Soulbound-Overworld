extends SceneTree

## SBL-M3-001 Milestone M3 systems test:
## Verifies CharacterStats, InventoryManager, KureiSystem, and DungeonGenerator.

const StoreScript = preload("res://scripts/persistence/profile_store.gd")
const StatsScript = preload("res://scripts/progression/character_stats.gd")
const InvScript = preload("res://scripts/inventory/inventory_manager.gd")
const KureiScript = preload("res://scripts/magic/kurei_system.gd")
const DungeonScript = preload("res://scripts/dungeon/dungeon_generator.gd")

const ROOT_PREFIX: String = "user://sbl_m3_test_"

var _failures: int = 0
var _test_root: String = ""

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("M3 SYSTEMS TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	_test_root = ROOT_PREFIX + "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store: ProfileStore = StoreScript.new(_test_root)

	_test_character_stats(store)
	_test_inventory_manager(store)
	_test_kurei_system()
	_test_dungeon_generator()

	_cleanup()

	if _failures > 0:
		printerr("M3 SYSTEMS TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL M3 SYSTEMS TESTS PASSED SUCCESSFULLY ===")
	quit(0)

# --- Test 1: CharacterStats ---------------------------------------------------

func _test_character_stats(store: ProfileStore) -> void:
	print("--- Testing CharacterStats ---")
	var stats: CharacterStats = StatsScript.new()

	_check(stats.level == 1, "Initial level is 1")
	_check(stats.xp == 0, "Initial XP is 0")
	_check(stats.get_max_hp() == 100, "Initial HP is 100 (10 vitality * 10)")
	_check(stats.get_spirit_power() == 50, "Initial Spirit Power is 50 (10 resonance * 5)")

	# Add XP below threshold
	var gained: int = stats.add_xp(50)
	_check(gained == 0, "No level gain at 50 XP")
	_check(stats.xp == 50, "XP is 50")

	# Add XP crossing threshold (Level 1 requires 100 XP)
	gained = stats.add_xp(60) # Total 110 XP -> Level 2 with 10 leftover
	_check(gained == 1, "Gained 1 level")
	_check(stats.level == 2, "Level is now 2")
	_check(stats.xp == 10, "Leftover XP is 10")
	_check(stats.unspent_points == 2, "Awarded 2 stat points on level up")

	# Allocate point to Vitality
	var allocated: bool = stats.allocate_point(CharacterStats.ATTR_VITALITY)
	_check(allocated, "Successfully allocated point to Vitality")
	_check(stats.vitality == 11, "Vitality increased to 11")
	_check(stats.get_max_hp() == 110, "Max HP increased to 110")
	_check(stats.unspent_points == 1, "Unspent points reduced to 1")

	# Persistence into ProfileStore
	var err: Error = stats.save_to_store(store, "profile_01")
	_check(err == OK, "CharacterStats saved to ProfileStore")

	var reloaded: CharacterStats = StatsScript.new()
	err = reloaded.load_from_store(store, "profile_01")
	_check(err == OK, "CharacterStats loaded from ProfileStore")
	_check(reloaded.level == 2, "Reloaded level is 2")
	_check(reloaded.vitality == 11, "Reloaded vitality is 11")
	_check(reloaded.get_max_hp() == 110, "Reloaded max HP is 110")
	print("PASS: CharacterStats verified")

# --- Test 2: InventoryManager -------------------------------------------------

func _test_inventory_manager(store: ProfileStore) -> void:
	print("--- Testing InventoryManager ---")
	var inv: InventoryManager = InvScript.new()

	# Add secured town items
	inv.add_banked_item("spirit_blade", 1)
	inv.add_banked_item("health_elixir", 3)
	_check(inv.banked_items["spirit_blade"] == 1, "Banked spirit blade count is 1")
	_check(inv.banked_items["health_elixir"] == 3, "Banked health elixir count is 3")

	# Equip weapon from bank
	var equipped: bool = inv.equip_item(InventoryManager.SLOT_WEAPON, "spirit_blade")
	_check(equipped, "Equipped spirit blade from bank")
	_check(inv.equipment["weapon"] == "spirit_blade", "Weapon slot holds spirit blade")
	_check(not inv.banked_items.has("spirit_blade"), "Spirit blade removed from bank while equipped")

	# Add at-risk satchel items in expedition
	inv.add_satchel_item("corruption_shard", 5)
	inv.add_satchel_item("ancient_relic", 1)
	_check(inv.satchel_items["corruption_shard"] == 5, "Satchel holds 5 shards")

	# Test Expedition Defeat Invariant: Lose satchel, keep bank & equipment
	var lost: Dictionary = inv.handle_expedition_defeat()
	_check(lost["corruption_shard"] == 5, "Defeat returns lost satchel items")
	_check(inv.satchel_items.is_empty(), "Satchel is cleared after defeat")
	_check(inv.equipment["weapon"] == "spirit_blade", "Equipped weapon strictly preserved after defeat")
	_check(inv.banked_items["health_elixir"] == 3, "Banked items strictly preserved after defeat")

	# Test Successful Extraction: Move satchel to bank exactly once
	inv.add_satchel_item("rare_kurei_crystal", 2)
	var extracted: Dictionary = inv.extract_satchel_to_bank()
	_check(extracted["rare_kurei_crystal"] == 2, "Extracted 2 crystals")
	_check(inv.satchel_items.is_empty(), "Satchel empty after extraction")
	_check(inv.banked_items["rare_kurei_crystal"] == 2, "Crystals transferred to bank")

	# Save/Load from ProfileStore
	var err: Error = inv.save_to_store(store, "profile_01")
	_check(err == OK, "Inventory saved to ProfileStore")

	var reloaded_inv: InventoryManager = InvScript.new()
	err = reloaded_inv.load_from_store(store, "profile_01")
	_check(err == OK, "Inventory loaded from ProfileStore")
	_check(reloaded_inv.equipment["weapon"] == "spirit_blade", "Reloaded equipment preserved")
	_check(reloaded_inv.banked_items["rare_kurei_crystal"] == 2, "Reloaded banked crystal preserved")
	print("PASS: InventoryManager verified")

# --- Test 3: KureiSystem ------------------------------------------------------

func _test_kurei_system() -> void:
	print("--- Testing KureiSystem ---")
	var kurei: KureiSystem = KureiScript.new()

	_check(KureiSystem.ALL_CATEGORIES.size() == 6, "All 6 Kurei categories defined")

	var skill: Dictionary = kurei.get_skill(&"flame_burst")
	_check(skill["category"] == KureiSystem.CAT_FLAME, "Flame burst belongs to Flame category")
	_check(skill["pip_cost"] == 2, "Flame burst costs 2 pips")

	# Pip checks
	_check(not kurei.can_cast(&"flame_burst", 1), "Cannot cast flame burst with only 1 pip")
	_check(kurei.can_cast(&"flame_burst", 2), "Can cast flame burst with 2 pips")

	# Cast and verify cooldown
	var res: Dictionary = kurei.cast_skill(&"flame_burst", 2)
	_check(res["error"] == OK, "Cast succeeded")
	_check(res["base_power"] == 18, "Base power is 18")
	_check(not kurei.can_cast(&"flame_burst", 3), "Cannot cast while on cooldown")

	# Tick cooldown
	kurei.tick_cooldowns()
	_check(not kurei.can_cast(&"flame_burst", 3), "Still on cooldown after 1 tick (cd is 2)")
	kurei.tick_cooldowns()
	_check(kurei.can_cast(&"flame_burst", 2), "Available again after cooldown expired")
	print("PASS: KureiSystem verified")

# --- Test 4: DungeonGenerator -------------------------------------------------

func _test_dungeon_generator() -> void:
	print("--- Testing DungeonGenerator ---")
	var gen1: DungeonGenerator = DungeonScript.new()
	var ok1: bool = gen1.generate(1337, 7)

	_check(ok1, "Dungeon generation succeeded")
	_check(gen1.is_valid, "Dungeon marked valid with reachable extraction")
	_check(gen1.rooms.size() == 7, "Generated exactly 7 rooms")

	# Test Determinism Invariant: Same seed produces identical rooms
	var gen2: DungeonGenerator = DungeonScript.new()
	var ok2: bool = gen2.generate(1337, 7)
	_check(ok2, "Second generation succeeded")
	_check(gen1.extraction_id == gen2.extraction_id, "Identical extraction room ID on same seed")
	_check(gen1.rooms == gen2.rooms, "Identical room graph on same seed (Determinism invariant)")

	# Test Suspend/Resume Invariant: Serialized active run
	var suspended: Dictionary = gen1.serialize_expedition_state()
	var resumed_gen: DungeonGenerator = DungeonScript.new()
	var err: Error = resumed_gen.deserialize_expedition_state(suspended)
	_check(err == OK, "Expedition state deserialized cleanly")
	_check(resumed_gen.current_seed == 1337, "Resumed seed matches")
	_check(resumed_gen.rooms.size() == 7, "Resumed rooms size matches")
	_check(resumed_gen.extraction_id == gen1.extraction_id, "Resumed extraction ID matches")
	print("PASS: DungeonGenerator verified")

func _cleanup() -> void:
	if not _test_root.begins_with(ROOT_PREFIX):
		return
	var gpath: String = ProjectSettings.globalize_path(_test_root)
	if not DirAccess.dir_exists_absolute(gpath):
		return
	for slot in ["profile_01", "profile_02", "profile_03"]:
		var d: String = _test_root.path_join(slot)
		var gd: String = ProjectSettings.globalize_path(d)
		if DirAccess.dir_exists_absolute(gd):
			for f in DirAccess.get_files_at(gd):
				DirAccess.remove_absolute(gd.path_join(f))
			DirAccess.remove_absolute(gd)
	DirAccess.remove_absolute(gpath)
