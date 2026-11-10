extends SceneTree

## SBL-W7-003 Kurei combat integration test suite:
## Verifies BattleFixture Kurei spell menu, pip consumption, damage effects, and cooldowns.

const BattleFixtureScene: PackedScene = preload("res://scenes/combat/battle_fixture.tscn")

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("KUREI COMBAT TEST FAILED: ", msg)
	return ok

## OD-003 exact authored value assertion for one catalog skill.
func _check_skill(skill_id: StringName, pip_cost: int, cooldown_turns: int, base_power: int) -> void:
	var skill: Dictionary = KureiSystem.SKILL_CATALOG.get(skill_id, {})
	if skill.is_empty():
		_check(false, "Authored skill %s exists in SKILL_CATALOG" % String(skill_id))
		return
	_check(int(skill.get("pip_cost", -1)) == pip_cost,
		"%s pip cost stays at the authored %d" % [String(skill_id), pip_cost])
	_check(int(skill.get("cooldown_turns", -1)) == cooldown_turns,
		"%s cooldown stays at the authored %d" % [String(skill_id), cooldown_turns])
	_check(int(skill.get("base_power", -1)) == base_power,
		"%s base_power stays at the authored %d" % [String(skill_id), base_power])

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W7-003 Kurei Combat Test Suite ---")
	var fixture: BattleFixture = BattleFixtureScene.instantiate() as BattleFixture
	root.add_child(fixture)
	await process_frame

	_check(fixture.ren_sp == 2, "Ren starts with 2 SP")
	_check(fixture.enemy_pips == 2, "Enemy starts with 2 HP")
	_check(fixture.enemy_intent == &"Strike", "Enemy opening intent is Strike")

	# Turn 1: Defend against Strike
	fixture.request_action(&"defend")
	await process_frame
	await process_frame
	_check(fixture.enemy_intent == &"Recover", "Enemy intent is now Recover")
	_check(fixture.ren_pips == 1, "Ren HP intact after defend")

	# Turn 2: Cast Lumina Lance (1 pip -> 1 damage during enemy Recover)
	var ok: bool = fixture.request_action(&"kurei_lumina_lance")
	_check(ok == true, "Lumina lance cast succeeds")
	_check(fixture.ren_sp == 1, "Ren SP reduced from 2 to 1")
	_check(fixture.enemy_pips == 1, "Enemy HP reduced from 2 to 1")

	# Enemy recovers harmlessly, pass back to Player
	await process_frame
	await process_frame
	_check(fixture.phase == BattleFixture.Phase.PLAYER, "Turn returned to PLAYER")
	_check(fixture.ren_sp == 2, "Ren regenerated 1 SP back to max (2)")
	_check(fixture.enemy_intent == &"Strike", "Enemy intent is Strike again")

	# Turn 3: Defend against Strike
	fixture.request_action(&"defend")
	await process_frame
	await process_frame
	_check(fixture.enemy_intent == &"Recover", "Enemy intent is Recover again")

	# Turn 4: Cast Flame Burst (2 pips -> 2 damage -> VICTORY)
	ok = fixture.request_action(&"kurei_flame_burst")
	_check(ok == true, "Flame burst cast succeeds")
	_check(fixture.enemy_pips == 0, "Enemy HP reached 0")
	_check(fixture.phase == BattleFixture.Phase.VICTORY, "Battle ended in VICTORY via Flame Burst")

	fixture.queue_free()

	# =========================================================================
	# SBL-REV-005 Phase Mastery & Capacity Verification in Normal Combat
	# =========================================================================
	print("--- Running SBL-REV-005 Phase Mastery in BattleFixture ---")
	var fixture_mastery: BattleFixture = BattleFixtureScene.instantiate() as BattleFixture
	root.add_child(fixture_mastery)
	await process_frame

	_check(fixture_mastery.max_sp == 2, "Unconfigured fixture has baseline max_sp 2")
	_check(fixture_mastery.ren_sp == 2, "Unconfigured fixture has baseline starting ren_sp 2")

	var mastery_tree := KureiTree.new()
	mastery_tree.sync_with_level(10)
	mastery_tree.unlock_skill(&"void_shift")
	mastery_tree.unlock_skill(&"phase_mastery")
	mastery_tree.unlock_skill(&"solar_flare")
	_check(mastery_tree.has_phase_mastery(), "Tree has phase_mastery unlocked")

	fixture_mastery.kurei_tree = mastery_tree
	_check(fixture_mastery.max_sp == 4, "Phase Mastery gives authored capacity 4 in BattleFixture")
	_check(fixture_mastery.ren_sp == 2, "Phase Mastery preserves baseline starting SP 2")

	# Re-application must not refill SP or stack capacity
	fixture_mastery.apply_kurei_tree_capacity()
	_check(fixture_mastery.max_sp == 4, "Reapplying capacity does not stack above 4")
	_check(fixture_mastery.ren_sp == 2, "Reapplying capacity does not refill SP")

	# Passive is not castable or equippable; direct attempts reject without mutation
	var passive_res: bool = fixture_mastery.request_action(&"kurei_phase_mastery")
	_check(passive_res == false, "Direct attempt to cast passive phase_mastery is rejected")
	_check(fixture_mastery.ren_sp == 2, "Passive request leaves ren_sp unchanged")
	_check(fixture_mastery.phase == BattleFixture.Phase.PLAYER, "Passive request leaves PLAYER phase unchanged")
	_check(fixture_mastery.last_player_action == &"", "Passive request leaves last_player_action unchanged")
	_check(fixture_mastery.kurei.cooldowns.is_empty(), "Passive request does not trigger any cooldown")

	# Locked skill request rejects without mutation
	var locked_res: bool = fixture_mastery.request_action(&"kurei_celestial_prism")
	_check(locked_res == false, "Locked skill celestial_prism is rejected")
	_check(fixture_mastery.ren_sp == 2, "Locked request leaves ren_sp unchanged")
	_check(fixture_mastery.phase == BattleFixture.Phase.PLAYER, "Locked request leaves PLAYER phase unchanged")

	# Turn 1: Defend against Strike -> enemy recovers -> Ren regenerates to 3 SP!
	fixture_mastery.request_action(&"defend")
	await process_frame
	await process_frame
	_check(fixture_mastery.phase == BattleFixture.Phase.PLAYER, "Turn returned to PLAYER after defend")
	_check(fixture_mastery.ren_sp == 3, "Ren regenerated to 3 SP (unlocked by max capacity 4)")

	# Turn 2: Cast Solar Flare (costs 3 SP) — previously unreachable without Phase Mastery!
	var solar_ok: bool = fixture_mastery.request_action(&"kurei_solar_flare")
	_check(solar_ok == true, "Solar Flare (3 SP cost) successfully cast thanks to Phase Mastery")
	_check(fixture_mastery.ren_sp == 0, "Ren SP correctly reduced from 3 to 0 after Solar Flare")
	_check(fixture_mastery.enemy_pips == 0, "Enemy defeated by Solar Flare 3 damage")
	_check(fixture_mastery.phase == BattleFixture.Phase.VICTORY, "Combat ended in VICTORY via Solar Flare")

	# Respec restores baseline capacity 2
	mastery_tree.respec_talents()
	_check(fixture_mastery.max_sp == 2, "Respec restores BattleFixture max_sp to baseline 2")
	_check(fixture_mastery.ren_sp <= 2, "Respec clamps ren_sp to restored max_sp")

	fixture_mastery.queue_free()

	# ==========================================================================
	# SBL-REV-006: Dynamic Kurei Menu & Six-Slot Combat Enforcement in BattleFixture
	# ==========================================================================
	print("--- Running SBL-REV-006 Dynamic Kurei Menu in BattleFixture ---")
	var fixture_loadout: BattleFixture = BattleFixtureScene.instantiate() as BattleFixture
	root.add_child(fixture_loadout)
	await process_frame

	var combat_tree := KureiTree.new()
	combat_tree.sync_with_level(20)
	combat_tree.unlock_skill(&"solar_flare")
	combat_tree.unlock_skill(&"celestial_prism")
	combat_tree.unlock_skill(&"glacial_aegis")
	combat_tree.unlock_skill(&"void_shift") # 7th active skill, unequipped
	combat_tree.unlock_skill(&"phase_mastery") # Expands capacity to 4
	_check(combat_tree.equipped_skills.size() == 6, "combat_tree has 6 equipped skills")
	_check(combat_tree.is_skill_equipped(&"void_shift") == false, "void_shift is unequipped in combat_tree")

	fixture_loadout.kurei_tree = combat_tree
	fixture_loadout._update_ui()
	_check(fixture_loadout.max_sp == 4, "BattleFixture max_sp is 4 with phase_mastery")

	# Open Kurei Menu
	fixture_loadout.kurei_button.pressed.emit()
	_check(fixture_loadout.kurei_menu.visible == true, "Kurei menu opened on button press")
	_check(fixture_loadout._active_skill_buttons.size() == 6, "Menu contains exactly 6 dynamic buttons for 6 equipped skills")
	_check(fixture_loadout._active_skill_buttons.has(&"solar_flare"), "Menu contains solar_flare button")
	_check(fixture_loadout._active_skill_buttons.has(&"celestial_prism"), "Menu contains celestial_prism button")
	_check(fixture_loadout._active_skill_buttons.has(&"glacial_aegis"), "Menu contains glacial_aegis button")
	_check(fixture_loadout._active_skill_buttons.has(&"void_shift") == false, "Unequipped void_shift has NO button in menu")

	# Cancel via CancelKureiButton
	fixture_loadout.cancel_kurei_btn.pressed.emit()
	_check(fixture_loadout.kurei_menu.visible == false, "Cancel button closed Kurei menu")

	# Reopen and cancel via Escape (ui_cancel)
	fixture_loadout.kurei_button.pressed.emit()
	_check(fixture_loadout.kurei_menu.visible == true, "Kurei menu reopened")
	var esc_event := InputEventAction.new()
	esc_event.action = "ui_cancel"
	esc_event.pressed = true
	fixture_loadout._input(esc_event)
	_check(fixture_loadout.kurei_menu.visible == false, "Escape (ui_cancel) dismissed Kurei menu")

	# Direct request for unequipped skill is rejected
	var unequipped_blocked: bool = fixture_loadout.request_action(&"kurei_void_shift")
	_check(unequipped_blocked == false, "Direct request_action for unequipped void_shift is rejected")
	_check(fixture_loadout.ren_sp == 2, "Rejected unequipped action does not consume ren_sp")
	_check(fixture_loadout.phase == BattleFixture.Phase.PLAYER, "Rejected unequipped action does not advance phase")

	# Direct request for equipped skill succeeds
	fixture_loadout.ren_sp = 3
	var equipped_ok: bool = fixture_loadout.request_action(&"kurei_solar_flare")
	_check(equipped_ok == true, "Direct request_action for equipped solar_flare succeeds")
	_check(fixture_loadout.enemy_statuses.has_status(StatusEngine.EFFECT_BURN), "Solar Flare inflicted burn on enemy")
	_check(fixture_loadout.last_player_action == &"kurei_solar_flare", "last_player_action set to kurei_solar_flare")

	fixture_loadout.queue_free()

	# Regression test: Empty equipped loadout normalization prevents visible-but-unusable menu
	var fixture_empty: BattleFixture = BattleFixtureScene.instantiate() as BattleFixture
	root.add_child(fixture_empty)
	await process_frame

	var empty_tree := KureiTree.new()
	empty_tree.equipped_skills.clear()
	fixture_empty.kurei_tree = empty_tree
	fixture_empty.kurei_button.pressed.emit()
	_check(fixture_empty.kurei_menu.visible == true, "Kurei menu visible with empty_tree")
	_check(fixture_empty._active_skill_buttons.size() == 3, "Menu displays 3 starter buttons via normalization")

	# Assert that visible button for Flame Burst is fully functional and request_action succeeds
	var empty_cast_ok: bool = fixture_empty.request_action(&"kurei_flame_burst")
	_check(empty_cast_ok == true, "request_action for visible flame_burst succeeds on normalized tree (no unusable menu defect)")
	_check(fixture_empty.enemy_pips == 0, "flame_burst dealt 2 damage to enemy (pips: 0)")
	fixture_empty.queue_free()

	# ==========================================================================
	# OD-003: six categories with approved roles and exact authored values
	# ==========================================================================
	print("--- Running OD-003 Kurei Role Metadata and Authored Value Controls ---")
	var kurei := KureiSystem.new()

	_check(KureiSystem.ALL_CATEGORIES.size() == 6, "Exactly six Kurei categories exist")
	_check(kurei.get_category_role(KureiSystem.CAT_FLAME) == "damage/Burn", "Flame role is damage/Burn")
	_check(kurei.get_category_role(KureiSystem.CAT_TORRENT) == "heal/cleanse", "Torrent role is heal/cleanse")
	_check(kurei.get_category_role(KureiSystem.CAT_GALE) == "haste/evasion", "Gale role is haste/evasion")
	_check(kurei.get_category_role(KureiSystem.CAT_EARTH) == "shield/mitigation", "Earth role is shield/mitigation")
	_check(kurei.get_category_role(KureiSystem.CAT_LUMINA) == "pierce/focus", "Lumina role is pierce/focus")
	_check(kurei.get_category_role(KureiSystem.CAT_UMBRA) == "drain/debuff", "Umbra role is drain/debuff")
	_check(kurei.get_skill_role(&"flame_burst") == "damage/Burn", "flame_burst inherits the Flame role")
	_check(kurei.get_skill_role(&"torrent_surge") == "heal/cleanse", "torrent_surge inherits the Torrent role")
	_check(kurei.get_skill_role(&"gale_flurry") == "haste/evasion", "gale_flurry inherits the Gale role")
	_check(kurei.get_skill_role(&"earth_bastion") == "shield/mitigation", "earth_bastion inherits the Earth role")
	_check(kurei.get_skill_role(&"lumina_lance") == "pierce/focus", "lumina_lance inherits the Lumina role")
	_check(kurei.get_skill_role(&"umbra_drain") == "drain/debuff", "umbra_drain inherits the Umbra role")
	_check(kurei.get_skill_role(&"unknown_skill") == "", "Unknown skills have no invented role")

	# Exact authored pip costs, cooldowns and base powers (OD-003: unchanged content).
	_check_skill(&"flame_burst", 2, 2, 18)
	_check_skill(&"torrent_surge", 2, 3, 12)
	_check_skill(&"gale_flurry", 1, 1, 10)
	_check_skill(&"earth_bastion", 2, 3, 0)
	_check_skill(&"lumina_lance", 1, 2, 14)
	_check_skill(&"umbra_drain", 2, 3, 12)
	_check_skill(&"solar_flare", 3, 3, 28)
	_check_skill(&"celestial_prism", 2, 3, 20)
	_check_skill(&"glacial_aegis", 2, 3, 16)
	_check_skill(&"void_shift", 1, 2, 10)
	_check_skill(&"phase_mastery", 0, 0, 0)
	_check(kurei.is_skill_passive(&"phase_mastery"), "phase_mastery stays a passive with no cost")

	# Exact SP baselines: normal 2, Phase Mastery 4, boss 3 / Phase Mastery 4.
	_check(BattleFixture.BASELINE_MAX_SP == 2, "Normal SP baseline stays 2")
	_check(BossEncounter.BASELINE_MAX_SP == 3, "Boss SP baseline stays 3")
	_check(KureiTree.AUTHORED_PHASE_MASTERY_MAX_SP == 4, "Phase Mastery raises SP capacity to 4 for both")

	# OD-003 negative controls: no rock-paper-scissors multiplier chart anywhere.
	var banned_fields: Array[String] = [
		"multiplier", "element_multiplier", "weakness_multiplier", "resistance_multiplier",
		"affinity_chart", "counter_chart", "element_chart", "affinity"
	]
	var chart_leaks: Array[String] = []
	for skill_id: StringName in KureiSystem.SKILL_CATALOG:
		var skill_record: Dictionary = KureiSystem.SKILL_CATALOG[skill_id]
		for banned: String in banned_fields:
			if skill_record.has(banned):
				chart_leaks.append("%s.%s" % [String(skill_id), banned])
	_check(chart_leaks.is_empty(),
		"No authored skill carries an elemental multiplier/counter field (OD-003): %s" % str(chart_leaks))
	var cast_probe: Dictionary = kurei.cast_skill(&"flame_burst", 2)
	_check(int(cast_probe.get("base_power", -1)) == 18,
		"cast_skill returns the authored base_power unchanged (no hidden elemental multiplier)")
	_check(cast_probe.get("error", ERR_UNAVAILABLE) == OK, "Authored flame_burst cast succeeds with 2 SP")

	# ==========================================================================
	# OD-004: status durations, refresh/no-stack, Stun skip and Torrent cleanse
	# ==========================================================================
	print("--- Running OD-004 Status Policy in BattleFixture ---")
	var od_fixture: BattleFixture = BattleFixtureScene.instantiate() as BattleFixture
	od_fixture.ren_pips = 3 # Ren survives the opponent strikes during these probes
	root.add_child(od_fixture)
	await process_frame

	od_fixture.enemy_pips = 20 # keep the opponent alive for the status probes
	var flame_ok: bool = od_fixture.request_action(&"kurei_flame_burst")
	_check(flame_ok, "Flame Burst accepted for the OD-004 probe")
	_check(od_fixture.enemy_statuses.get_duration(StatusEngine.EFFECT_BURN) == 3,
		"Flame applies the OD-004 3-turn Burn")
	_check(od_fixture.enemy_statuses.get_potency(StatusEngine.EFFECT_BURN) == 1,
		"Flame keeps its authored Burn potency")
	_check(int(od_fixture.enemy_statuses.active_effects[StatusEngine.EFFECT_BURN].get("stacks", 0)) == 1,
		"Applied Burn holds a single intensity")
	await process_frame
	await process_frame
	_check(od_fixture.phase == BattleFixture.Phase.PLAYER, "Control returned to Ren after the opponent acted")

	# Same-name refresh: larger duration and larger potency, never a stack.
	od_fixture.kurei.reset_cooldowns()
	od_fixture.ren_sp = 2
	od_fixture.enemy_statuses.apply_status(StatusEngine.EFFECT_BURN, 3, 2) # stronger authored Burn
	_check(od_fixture.enemy_statuses.get_duration(StatusEngine.EFFECT_BURN) == 3, "Stronger Burn refreshed to 3 turns")
	var weaker_cast_ok: bool = od_fixture.request_action(&"kurei_flame_burst")
	_check(weaker_cast_ok, "Weaker Flame reapplication accepted")
	_check(od_fixture.enemy_statuses.get_duration(StatusEngine.EFFECT_BURN) == 3,
		"Refresh keeps the larger duration")
	_check(od_fixture.enemy_statuses.get_potency(StatusEngine.EFFECT_BURN) == 2,
		"Refresh keeps the larger potency")
	_check(int(od_fixture.enemy_statuses.active_effects[StatusEngine.EFFECT_BURN].get("stacks", 0)) == 1,
		"Refresh never stacks intensity (OD-004)")
	await process_frame
	await process_frame

	# OD-004 Stun: the opponent skips exactly one action.
	od_fixture.enemy_statuses.clear_all()
	od_fixture.enemy_statuses.apply_status(StatusEngine.EFFECT_STUN)
	od_fixture.enemy_pips = 10
	var pre_skip_pips: int = od_fixture.ren_pips
	var pre_skip_intent: StringName = od_fixture.enemy_intent
	var attack_ok: bool = od_fixture.request_action(&"attack")
	_check(attack_ok, "Ren attack accepted before the stunned opponent acts")
	await process_frame
	await process_frame
	_check(od_fixture.ren_pips == pre_skip_pips,
		"Stunned opponent skipped its Strike (no damage to Ren)")
	_check(od_fixture.enemy_intent == pre_skip_intent,
		"Telegraphed intent did not advance for an action the opponent never took")
	_check(od_fixture.enemy_statuses.has_status(StatusEngine.EFFECT_STUN) == false,
		"Stun consumed by the single skipped action")
	_check(od_fixture.phase == BattleFixture.Phase.PLAYER, "Battle continues after the skipped action")

	# OD-003/OD-004 Torrent role: heal/cleanse - negatives removed, positives kept.
	od_fixture.ren_statuses.apply_status(StatusEngine.EFFECT_BURN, -1, 2)
	od_fixture.ren_statuses.apply_status(StatusEngine.EFFECT_DEFENSE_UP, -1, 1)
	od_fixture.ren_sp = 2
	var pre_heal_pips: int = od_fixture.ren_pips
	var torrent_ok: bool = od_fixture.request_action(&"kurei_torrent_surge")
	_check(torrent_ok, "Torrent Surge accepted for the cleanse probe")
	_check(od_fixture.ren_statuses.has_status(StatusEngine.EFFECT_BURN) == false,
		"Cleanse removed the negative Burn from Ren")
	_check(od_fixture.ren_statuses.has_status(StatusEngine.EFFECT_DEFENSE_UP) == true,
		"Cleanse kept the positive Defense Up")
	_check(od_fixture.ren_pips == mini(od_fixture.max_ren_pips, pre_heal_pips + 1),
		"Torrent Surge healed Ren by its authored amount")
	od_fixture.queue_free()
	await process_frame

	if _failures > 0:
		printerr("KUREI COMBAT TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL KUREI COMBAT TESTS PASSED SUCCESSFULLY ===")
	quit(0)
