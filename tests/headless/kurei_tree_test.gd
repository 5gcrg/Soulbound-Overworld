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

	# 8. SBL-REV-006: Six-Slot Equip Lifecycle & Loadout Invariants
	var eq_tree := KureiTree.new()
	_check(eq_tree.equipped_skills.size() == 3, "New tree defaults to 3 equipped skills")
	_check(eq_tree.is_skill_equipped(&"flame_burst"), "Starter flame_burst is equipped")
	_check(eq_tree.is_skill_equipped(&"lumina_lance"), "Starter lumina_lance is equipped")
	_check(eq_tree.is_skill_equipped(&"torrent_surge"), "Starter torrent_surge is equipped")

	# Validation: cannot unequip down to 0
	_check(eq_tree.can_unequip_skill(&"flame_burst") == true, "Can unequip when 3 skills equipped")
	_check(eq_tree.unequip_skill(&"flame_burst") == OK, "Unequipped flame_burst")
	_check(eq_tree.equipped_skills.size() == 2, "2 skills equipped after unequip")
	_check(eq_tree.unequip_skill(&"lumina_lance") == OK, "Unequipped lumina_lance")
	_check(eq_tree.equipped_skills.size() == 1, "1 skill equipped after unequip")
	_check(eq_tree.can_unequip_skill(&"torrent_surge") == false, "Cannot unequip last remaining active skill")
	_check(eq_tree.unequip_skill(&"torrent_surge") == FAILED, "unequip_skill rejected on last active skill")
	_check(eq_tree.equipped_skills.size() == 1, "Equipped count remains 1 (minimum invariant)")

	# Cannot equip locked skill
	_check(eq_tree.can_equip_skill(&"solar_flare") == false, "Cannot equip locked skill solar_flare")
	_check(eq_tree.equip_skill(&"solar_flare") == FAILED, "equip_skill rejected locked skill")

	# Re-equip flame_burst
	_check(eq_tree.can_equip_skill(&"flame_burst") == true, "Can re-equip unlocked flame_burst")
	_check(eq_tree.equip_skill(&"flame_burst") == OK, "Re-equipped flame_burst")
	# Cannot equip duplicate
	_check(eq_tree.can_equip_skill(&"flame_burst") == false, "Cannot equip already equipped skill")
	_check(eq_tree.equip_skill(&"flame_burst") == FAILED, "equip_skill rejected duplicate")

	# Re-equip lumina_lance
	eq_tree.equip_skill(&"lumina_lance")
	_check(eq_tree.equipped_skills.size() == 3, "Equipped count back to 3")

	# Unlock active skills: auto-equip up to 6
	eq_tree.sync_with_level(15)
	eq_tree.unlock_skill(&"solar_flare")
	_check(eq_tree.equipped_skills.size() == 4, "solar_flare auto-equipped (slot 4)")
	_check(eq_tree.is_skill_equipped(&"solar_flare"), "solar_flare is equipped")

	eq_tree.unlock_skill(&"celestial_prism")
	_check(eq_tree.equipped_skills.size() == 5, "celestial_prism auto-equipped (slot 5)")

	eq_tree.unlock_skill(&"glacial_aegis")
	_check(eq_tree.equipped_skills.size() == 6, "glacial_aegis auto-equipped (slot 6)")

	# Unlock 7th active skill (void_shift) when 6 slots are already filled
	eq_tree.unlock_skill(&"void_shift")
	_check(eq_tree.is_skill_unlocked(&"void_shift"), "void_shift unlocked")
	_check(eq_tree.equipped_skills.size() == 6, "Equipped count remains exactly 6 at maximum capacity")
	_check(eq_tree.is_skill_equipped(&"void_shift") == false, "7th active skill void_shift left unequipped")
	_check(eq_tree.can_equip_skill(&"void_shift") == false, "can_equip_skill returns false when slots full (6/6)")
	_check(eq_tree.equip_skill(&"void_shift") == FAILED, "equip_skill rejects when slots full")

	# Unlock passive phase_mastery (requires void_shift): must NOT be equipped
	eq_tree.unlock_skill(&"phase_mastery")
	_check(eq_tree.has_phase_mastery(), "phase_mastery unlocked")
	_check(eq_tree.is_skill_equipped(&"phase_mastery") == false, "Passive phase_mastery is NOT equipped")
	_check(eq_tree.can_equip_skill(&"phase_mastery") == false, "can_equip_skill rejects passive phase_mastery")
	_check(eq_tree.equip_skill(&"phase_mastery") == FAILED, "equip_skill rejects passive phase_mastery")

	# Swap skills: unequip glacial_aegis, equip void_shift
	_check(eq_tree.unequip_skill(&"glacial_aegis") == OK, "Unequipped glacial_aegis")
	_check(eq_tree.equipped_skills.size() == 5, "Equipped count is now 5")
	_check(eq_tree.can_equip_skill(&"void_shift") == true, "can_equip_skill now true for void_shift")
	_check(eq_tree.equip_skill(&"void_shift") == OK, "Equipped void_shift")
	_check(eq_tree.is_skill_equipped(&"void_shift") == true, "void_shift is now equipped")
	_check(eq_tree.equipped_skills.size() == 6, "Equipped count back to 6")

	# Respec resets equipped skills to the 3 starters
	eq_tree.respec_talents()
	_check(eq_tree.equipped_skills.size() == 3, "Respec reset equipped skills to 3 starters")
	_check(eq_tree.is_skill_equipped(&"flame_burst"), "flame_burst equipped after respec")
	_check(eq_tree.is_skill_equipped(&"lumina_lance"), "lumina_lance equipped after respec")
	_check(eq_tree.is_skill_equipped(&"torrent_surge"), "torrent_surge equipped after respec")

	# Serialization & Deserialization of equipped loadout
	eq_tree.sync_with_level(15)
	eq_tree.unlock_skill(&"solar_flare")
	eq_tree.unlock_skill(&"void_shift")
	var serialized_loadout := eq_tree.serialize()
	_check(serialized_loadout.has("equipped_skills"), "Serialized dictionary includes equipped_skills")
	var loaded_tree := KureiTree.new()
	var deser_err := loaded_tree.deserialize(serialized_loadout)
	_check(deser_err == OK, "Deserialized tree successfully")
	_check(loaded_tree.equipped_skills.size() == eq_tree.equipped_skills.size(), "Deserialized loadout size matches")
	for sid in eq_tree.equipped_skills:
		_check(loaded_tree.is_skill_equipped(sid), "Deserialized loadout contains %s" % sid)

	# GameplayProfileValidator preflight checks
	var base_profile: Dictionary = {
		"character": {
			"level": 1,
			"xp": 0,
			"vitality": 10,
			"resonance": 10,
			"agility": 10,
			"focus": 10,
			"unspent_points": 0,
			"max_hp": 100,
			"spirit_power": 50,
			"kurei_tree": {
				"unlocked_skills": ["flame_burst", "lumina_lance", "torrent_surge", "solar_flare"],
				"equipped_skills": ["flame_burst", "lumina_lance", "torrent_surge", "solar_flare"]
			}
		},
		"inventory": {},
		"world": {},
		"education": {}
	}
	_check(GameplayProfileValidator.validate(base_profile) == OK, "Valid profile with equipped_skills accepted by validator")

	# Validator rejects duplicate equipped skills
	var dup_profile: Dictionary = base_profile.duplicate(true)
	dup_profile["character"]["kurei_tree"]["equipped_skills"] = ["flame_burst", "flame_burst"]
	_check(GameplayProfileValidator.validate(dup_profile) == ERR_INVALID_DATA, "Validator rejected duplicate equipped skill")

	# Validator rejects unknown equipped skill
	var unk_profile: Dictionary = base_profile.duplicate(true)
	unk_profile["character"]["kurei_tree"]["equipped_skills"] = ["flame_burst", "mega_blast"]
	_check(GameplayProfileValidator.validate(unk_profile) == ERR_INVALID_DATA, "Validator rejected unknown equipped skill")

	# Validator rejects locked equipped skill
	var lck_profile: Dictionary = base_profile.duplicate(true)
	lck_profile["character"]["kurei_tree"]["equipped_skills"] = ["flame_burst", "void_shift"]
	_check(GameplayProfileValidator.validate(lck_profile) == ERR_INVALID_DATA, "Validator rejected locked equipped skill")

	# Validator rejects passive equipped skill
	var pas_profile: Dictionary = base_profile.duplicate(true)
	pas_profile["character"]["kurei_tree"]["unlocked_skills"].append("phase_mastery")
	pas_profile["character"]["kurei_tree"]["equipped_skills"] = ["flame_burst", "phase_mastery"]
	_check(GameplayProfileValidator.validate(pas_profile) == ERR_INVALID_DATA, "Validator rejected passive equipped skill")

	# Validator rejects >6 equipped skills
	var big_profile: Dictionary = base_profile.duplicate(true)
	big_profile["character"]["kurei_tree"]["equipped_skills"] = [
		"flame_burst", "lumina_lance", "torrent_surge", "solar_flare", "celestial_prism", "glacial_aegis", "void_shift"
	]
	_check(GameplayProfileValidator.validate(big_profile) == ERR_INVALID_DATA, "Validator rejected >6 equipped skills")

	# Validator rejects explicit empty equipped skills array
	var empty_eq_profile: Dictionary = base_profile.duplicate(true)
	empty_eq_profile["character"]["kurei_tree"]["equipped_skills"] = []
	_check(GameplayProfileValidator.validate(empty_eq_profile) == ERR_INVALID_DATA, "Validator rejected explicit empty equipped skills array")

	# Deserialization rejects explicit empty equipped skills array and preserves existing state atomically
	var atom_tree := KureiTree.new()
	atom_tree.sync_with_level(5)
	atom_tree.unlock_skill(&"solar_flare")
	var prev_unlocked := atom_tree.unlocked_skills.duplicate()
	var prev_equipped := atom_tree.equipped_skills.duplicate()
	var prev_spent := atom_tree.spent_talent_points
	var des_err: Error = atom_tree.deserialize({
		"unlocked_skills": ["flame_burst", "lumina_lance", "torrent_surge", "solar_flare"],
		"equipped_skills": [],
		"spent_talent_points": 1
	})
	_check(des_err == ERR_INVALID_DATA, "KureiTree.deserialize rejects explicit empty equipped array with ERR_INVALID_DATA")
	_check(atom_tree.unlocked_skills == prev_unlocked, "Atomic deserialize failure preserved unlocked_skills")
	_check(atom_tree.equipped_skills == prev_equipped, "Atomic deserialize failure preserved equipped_skills")
	_check(atom_tree.spent_talent_points == prev_spent, "Atomic deserialize failure preserved spent_talent_points")

	# Legacy profile lacking equipped_skills key passes validation and defaults to starter loadout in memory
	var legacy_kurei_prof: Dictionary = base_profile.duplicate(true)
	legacy_kurei_prof["character"]["kurei_tree"].erase("equipped_skills")
	_check(GameplayProfileValidator.validate(legacy_kurei_prof) == OK, "Legacy profile lacking equipped_skills passes validation")
	var leg_tree := KureiTree.new()
	var leg_des_err: Error = leg_tree.deserialize(legacy_kurei_prof["character"]["kurei_tree"])
	_check(leg_des_err == OK, "Legacy data deserialization returns OK")
	_check(leg_tree.equipped_skills == KureiTree.STARTER_SKILLS, "Legacy data defaults equipped_skills in memory to STARTER_SKILLS")

	# Normalization prevents visible-but-unusable loadout
	var empty_tree := KureiTree.new()
	empty_tree.equipped_skills.clear()
	_check(empty_tree.get_equipped_active_skills() == KureiTree.STARTER_SKILLS, "get_equipped_active_skills normalizes empty equipped_skills to starters")
	_check(empty_tree.is_skill_equipped(&"flame_burst") == true, "is_skill_equipped normalizes empty equipped_skills and returns true for starter")

	# UI Equip/Unequip interaction in CharacterSheet
	var ui_sheet: CharacterSheet = sheet_scene.instantiate() as CharacterSheet
	root.add_child(ui_sheet)
	await process_frame
	stats.level = 20
	ui_sheet.set_stats(stats)
	var ui_tree := KureiTree.new()
	ui_sheet.set_kurei_tree(ui_tree)
	ui_sheet.refresh()

	_check(ui_sheet.equipped_header.text.contains("3/6"), "EquippedHeader displays 3/6 initial slots")
	_check(ui_sheet._dynamic_equip_buttons.size() == 3, "3 unequip buttons in CharacterSheet for starters")

	# Unlock 7th active skill via UI to test feedback label
	ui_tree.sync_with_level(20)
	ui_tree.unlock_skill(&"solar_flare")
	ui_tree.unlock_skill(&"celestial_prism")
	ui_tree.unlock_skill(&"glacial_aegis")
	ui_sheet.refresh()
	_check(ui_sheet.equipped_header.text.contains("6/6"), "EquippedHeader displays 6/6 slots full")

	# Unlock 7th active skill
	ui_sheet._on_unlock_skill(&"void_shift")
	_check(ui_sheet.feedback_label.visible == true, "Feedback label visible when 7th skill unlocked with full slots")
	_check(ui_sheet.feedback_label.text == "Unlocked — equip in Character", "Feedback label displays 'Unlocked — equip in Character'")

	# Click unequip button on one skill
	var unequip_clicked := false
	for btn in ui_sheet._dynamic_equip_buttons:
		if btn.name.begins_with("UnequipBtn_"):
			btn.pressed.emit()
			unequip_clicked = true
			break
	_check(unequip_clicked, "Unequip button clicked in CharacterSheet")
	_check(ui_tree.equipped_skills.size() == 5, "Equipped skills reduced to 5 after UI unequip click")

	# Now equip the unequipped void_shift via UI Equip button
	var equip_clicked := false
	for btn in ui_sheet._dynamic_equip_buttons:
		if btn.name == "EquipBtn_void_shift":
			btn.pressed.emit()
			equip_clicked = true
			break
	_check(equip_clicked, "EquipBtn_void_shift clicked in CharacterSheet")
	_check(ui_tree.is_skill_equipped(&"void_shift"), "void_shift is now equipped after UI equip click")
	_check(ui_tree.equipped_skills.size() == 6, "Equipped skills count restored to 6")

	ui_sheet.queue_free()

	if _failures == 0:
		print("--- SBL-W11-003 Kurei Art Skill Tree Test Suite PASSED ---")
		quit(0)
	else:
		printerr("--- SBL-W11-003 Kurei Art Skill Tree Test Suite FAILED with %d errors ---" % _failures)
		quit(1)
