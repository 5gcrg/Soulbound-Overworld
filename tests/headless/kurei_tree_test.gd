extends SceneTree

## SBL-W11-003 Kurei Art Skill Tree & Talent Allocation Headless Test Suite
## Requirements: GDD-009..015, FR-MAG-001/002, AGENTS.md Invariants.

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("KUREI TREE TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W11-003 Kurei Art Skill Tree Test Suite ---")

	var tree := KureiTree.new()

	# 1. Initial Starter Skills
	_check(tree.is_skill_unlocked(&"flame_burst"), "Flame Burst is unlocked by default")
	_check(tree.is_skill_unlocked(&"lumina_lance"), "Lumina Lance is unlocked by default")
	_check(tree.is_skill_unlocked(&"torrent_surge"), "Torrent Surge is unlocked by default")
	_check(not tree.is_skill_unlocked(&"solar_flare"), "Solar Flare is locked initially")
	_check(not tree.is_skill_unlocked(&"void_shift"), "Void Shift is locked initially")
	_check(not tree.is_skill_unlocked(&"phase_mastery"), "Phase Mastery is locked initially")
	_check(tree.has_phase_mastery() == false, "Tree reports has_phase_mastery false initially")
	_check(tree.get_max_sp_capacity(2) == 2, "Default normal SP capacity is 2 without mastery")
	_check(tree.get_max_sp_capacity(3) == 3, "Default boss SP capacity is 3 without mastery")
	_check(tree.is_skill_passive(&"phase_mastery") == true, "Phase Mastery classified as passive")
	_check(tree.is_skill_active(&"phase_mastery") == false, "Phase Mastery not classified as active")
	_check(tree.is_skill_active(&"solar_flare") == true, "Solar Flare classified as active")
	_check(tree.is_skill_passive(&"solar_flare") == false, "Solar Flare not classified as passive")

	# 2. Talent Points Scaling
	tree.sync_with_level(1)
	_check(tree.get_unspent_points() == 0, "Level 1 Ren has 0 talent points")

	tree.sync_with_level(5)
	_check(tree.get_unspent_points() == 4, "Level 5 Ren has 4 talent points")

	# 3. Prerequisites and Point Costs
	_check(not tree.can_unlock_skill(&"phase_mastery"), "Phase Mastery cannot be unlocked without Void Shift prerequisite")

	# Unlock Solar Flare (Cost: 2)
	_check(tree.can_unlock_skill(&"solar_flare"), "Solar Flare can be unlocked (Flame Burst mastered + 4 pts available)")
	var unlock_err: Error = tree.unlock_skill(&"solar_flare")
	_check(unlock_err == OK, "Solar Flare unlocked successfully")
	_check(tree.is_skill_unlocked(&"solar_flare"), "Solar Flare is now unlocked")
	_check(tree.get_unspent_points() == 2, "2 talent points remaining after unlocking Solar Flare")

	# Unlock Void Shift (Cost: 1)
	_check(tree.can_unlock_skill(&"void_shift"), "Void Shift can be unlocked")
	unlock_err = tree.unlock_skill(&"void_shift")
	_check(unlock_err == OK, "Void Shift unlocked successfully")
	_check(tree.is_skill_unlocked(&"void_shift"), "Void Shift is now unlocked")
	_check(tree.get_unspent_points() == 1, "1 talent point remaining after unlocking Void Shift")

	# Phase Mastery requires 2 points, but only 1 remains
	_check(not tree.can_unlock_skill(&"phase_mastery"), "Phase Mastery cannot be unlocked with only 1 point left")

	# Grant more points by raising level to 6 (5 unspent - 2 spent = 3 unspent)
	tree.sync_with_level(6)
	_check(tree.get_unspent_points() == 2, "Level 6 with 3 points spent has 2 unspent points")
	_check(tree.can_unlock_skill(&"phase_mastery"), "Phase Mastery can now be unlocked")
	unlock_err = tree.unlock_skill(&"phase_mastery")
	_check(unlock_err == OK, "Phase Mastery unlocked successfully")
	_check(tree.has_phase_mastery(), "Tree reports has_phase_mastery == true")
	_check(tree.get_max_sp_capacity(2) == 4, "Authored Phase Mastery expands normal max SP to 4")
	_check(tree.get_max_sp_capacity(3) == 4, "Authored Phase Mastery expands boss max SP to 4")

	# 4. Respec Talents
	tree.respec_talents()
	_check(tree.get_unspent_points() == 5, "Respec returned all 5 talent points")
	_check(not tree.is_skill_unlocked(&"solar_flare"), "Solar Flare relocked after respec")
	_check(not tree.is_skill_unlocked(&"void_shift"), "Void Shift relocked after respec")
	_check(not tree.is_skill_unlocked(&"phase_mastery"), "Phase Mastery relocked after respec")
	_check(tree.has_phase_mastery() == false, "Respec restored has_phase_mastery to false")
	_check(tree.get_max_sp_capacity(2) == 2, "Respec restored normal SP capacity to 2")
	_check(tree.get_max_sp_capacity(3) == 3, "Respec restored boss SP capacity to 3")
	_check(tree.is_skill_unlocked(&"flame_burst"), "Starters remain unlocked after respec")

	# 5. Serialization and ProfileStore with Phase Mastery
	tree.unlock_skill(&"void_shift")
	tree.unlock_skill(&"phase_mastery")
	tree.unlock_skill(&"solar_flare")
	var serialized: Dictionary = tree.serialize()
	_check(serialized.has("unlocked_skills"), "Serialized dictionary has unlocked_skills")
	_check(serialized["unlocked_skills"].has("solar_flare"), "Serialized includes solar_flare")
	_check(serialized["unlocked_skills"].has("phase_mastery"), "Serialized includes phase_mastery")

	var tree2 := KureiTree.new()
	tree2.deserialize(serialized)
	_check(tree2.is_skill_unlocked(&"solar_flare"), "Deserialized tree restored solar_flare")
	_check(tree2.has_phase_mastery(), "Deserialized tree restored phase_mastery")
	_check(tree2.get_max_sp_capacity(2) == 4, "Deserialized tree restored 4 max SP capacity")

	var temp_dir: String = "user://test_kurei_profiles_%d" % Time.get_ticks_msec()
	var store := ProfileStore.new(temp_dir)
	var save_err: Error = tree.save_to_store(store, "profile_01")
	_check(save_err == OK, "Saved KureiTree with Phase Mastery to ProfileStore")

	var tree_loaded := KureiTree.new()
	var load_err: Error = tree_loaded.load_from_store(store, "profile_01")
	_check(load_err == OK, "Loaded KureiTree from ProfileStore")
	_check(tree_loaded.is_skill_unlocked(&"solar_flare"), "Loaded tree has solar_flare")
	_check(tree_loaded.has_phase_mastery(), "Loaded tree has phase_mastery")
	_check(tree_loaded.get_max_sp_capacity(2) == 4, "Saved mastery survives reload and reports authored capacity 4")
	_check(tree_loaded.get_max_sp_capacity(3) == 4, "Saved mastery survives reload and reports authored boss capacity 4")

	# Restore tree to baseline state for UI testing
	tree.respec_talents()
	tree.unlock_skill(&"solar_flare")

	# 6. CharacterSheet UI Integration
	var sheet_scene: PackedScene = load("res://scenes/ui/character_sheet.tscn")
	_check(sheet_scene != null, "character_sheet.tscn loaded successfully")
	var sheet: CharacterSheet = sheet_scene.instantiate() as CharacterSheet
	root.add_child(sheet)
	await process_frame

	var stats := CharacterStats.new()
	stats.level = 5
	sheet.set_stats(stats)
	sheet.set_kurei_tree(tree)
	sheet.refresh()

	_check(sheet.kurei_header != null, "CharacterSheet has kurei_header")
	_check(sheet.btn_solar != null, "CharacterSheet has btn_solar")
	_check(sheet.btn_solar.disabled == true, "Mastered solar_flare button is disabled/checked")
	_check(sheet.btn_prism.disabled == false, "Can-unlock celestial_prism button is enabled")

	# Click reset button in UI
	sheet._on_respec()
	_check(tree.is_skill_unlocked(&"solar_flare") == false, "UI respec reset solar_flare")
	_check(sheet.btn_solar.disabled == false, "Solar Flare button enabled for purchase after respec")

	# 7. Combat Integration with BattleFixture
	var battle_scene: PackedScene = load("res://scenes/combat/battle_fixture.tscn")
	var battle: BattleFixture = battle_scene.instantiate() as BattleFixture
	root.add_child(battle)
	await process_frame

	battle.kurei_tree = tree
	_check(battle.max_sp == 2, "BattleFixture max_sp is 2 without phase mastery")
	_check(battle.ren_sp == 2, "BattleFixture starting ren_sp preserved at 2")

	# Passive cannot be cast
	var passive_blocked: bool = battle.request_action(&"kurei_phase_mastery")
	_check(passive_blocked == false, "Direct attempt to cast passive Phase Mastery is rejected")
	_check(battle.ren_sp == 2, "Rejected passive action does not mutate ren_sp")
	_check(battle.phase == BattleFixture.Phase.PLAYER, "Rejected passive action does not advance phase")

	battle.ren_sp = 3

	# Locked skill should be rejected
	var cast_blocked: bool = battle.request_action(&"kurei_celestial_prism")
	_check(cast_blocked == false, "Locked Celestial Prism rejected in BattleFixture")

	# Unlock celestial prism
	tree.unlock_skill(&"celestial_prism")
	var cast_ok: bool = battle.request_action(&"kurei_celestial_prism")
	_check(cast_ok == true, "Unlocked Celestial Prism accepted in BattleFixture")
	_check(battle.enemy_statuses.has_status(StatusEngine.EFFECT_STUN), "Celestial Prism inflicted Stun on enemy")

	# Unlock Void Shift & Phase Mastery -> verify capacity changes to 4
	tree.sync_with_level(10)
	var unlock_void_err: Error = tree.unlock_skill(&"void_shift")
	_check(unlock_void_err == OK, "Unlocked void_shift")
	var unlock_pm_err: Error = tree.unlock_skill(&"phase_mastery")
	_check(unlock_pm_err == OK, "Unlocked phase_mastery")
	_check(battle.max_sp == 4, "BattleFixture max_sp expanded to 4 upon unlocking Phase Mastery")

	sheet.queue_free()
	battle.queue_free()

	if _failures == 0:
		print("--- SBL-W11-003 Kurei Art Skill Tree Test Suite PASSED ---")
		quit(0)
	else:
		printerr("--- SBL-W11-003 Kurei Art Skill Tree Test Suite FAILED with %d errors ---" % _failures)
		quit(1)
