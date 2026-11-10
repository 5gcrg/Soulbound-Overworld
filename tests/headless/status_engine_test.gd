extends SceneTree

## SBL-STAT-001 Combat Status Effect Engine Headless Test Suite
## Requirements: GDD-018/022/025, FR-CBT-003, AGENTS.md Invariants.

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("STATUS ENGINE TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-STAT-001 Combat Status Engine Test Suite ---")
	var engine := StatusEngine.new()

	# Test 1: Initial empty state
	_check(engine.active_effects.is_empty(), "Initial engine has no active effects")
	_check(engine.can_act() == true, "Can act when uninhibited")
	_check(engine.can_use_skills() == true, "Can use skills when uninhibited")

	# Test 2: Apply DoT effects
	engine.apply_status(StatusEngine.EFFECT_POISON, 2, 5)
	engine.apply_status(StatusEngine.EFFECT_BURN, 1, 3)
	_check(engine.has_status(StatusEngine.EFFECT_POISON) == true, "Poison is active")
	_check(engine.has_status(StatusEngine.EFFECT_BURN) == true, "Burn is active")
	_check(engine.get_potency(StatusEngine.EFFECT_POISON) == 5, "Poison potency is 5")

	# Test 3: Tick turn start DoT events
	var events: Array[Dictionary] = engine.tick_turn_start()
	_check(events.size() == 2, "Turn start returned 2 DoT events")
	var total_dmg: int = 0
	for ev in events:
		total_dmg += int(ev.get("damage", 0))
	_check(total_dmg == 8, "Turn start DoT total damage equals 8 (5 poison + 3 burn)")

	# Test 4: Shield absorption and damage mitigation
	engine.apply_status(StatusEngine.EFFECT_SHIELD, 3, 20)
	engine.apply_status(StatusEngine.EFFECT_DEFENSE_UP, 2, 1)

	var hit1: Dictionary = engine.process_incoming_damage(20)
	# 20 raw damage * 0.65 = 13 incoming; Shield has 20 so absorbs all 13; HP damage = 0
	_check(hit1["hp_damage"] == 0, "Shield fully absorbed mitigated attack")
	_check(hit1["shield_absorbed"] == 13, "Shield absorbed 13 damage")
	_check(engine.get_potency(StatusEngine.EFFECT_SHIELD) == 7, "Shield potency reduced from 20 to 7")

	var hit2: Dictionary = engine.process_incoming_damage(20)
	# 13 incoming; Shield has 7, absorbs 7, leaves 6 HP damage
	_check(hit2["hp_damage"] == 6, "Shield broke; remaining 6 damage broke through to HP")
	_check(hit2["shield_absorbed"] == 7, "Shield absorbed remaining 7 points")
	_check(engine.has_status(StatusEngine.EFFECT_SHIELD) == false, "Depleted shield expired")

	# Test 5: Crowd Control (Stun & Silence)
	engine.apply_status(StatusEngine.EFFECT_STUN, 1, 1)
	# OD-004: Silence is approved for 1 turn, so the engine caps the requested 2.
	engine.apply_status(StatusEngine.EFFECT_SILENCE, 2, 1)
	_check(engine.can_act() == false, "Stun correctly blocks actions")
	_check(engine.can_use_skills() == false, "Silence correctly blocks skills")
	_check(engine.get_duration(StatusEngine.EFFECT_SILENCE) == 1,
		"OD-004 caps Silence at the approved 1 turn")

	# Test 6: Tick turn end duration decrement
	var expired: Array[String] = engine.tick_turn_end()
	_check(expired.has(StatusEngine.EFFECT_BURN), "1-turn Burn expired on end turn")
	_check(expired.has(StatusEngine.EFFECT_STUN), "1-turn Stun expired on end turn")
	_check(expired.has(StatusEngine.EFFECT_SILENCE), "OD-004 1-turn Silence expired on end turn")
	_check(engine.can_act() == true, "Player can act again after Stun expiration")
	_check(engine.has_status(StatusEngine.EFFECT_POISON) == true, "2-turn Poison still has 1 turn remaining")

	# Test 7: Serialization round-trip
	var serialized: Dictionary = engine.serialize()
	var restored := StatusEngine.new()
	restored.deserialize(serialized)
	_check(restored.has_status(StatusEngine.EFFECT_POISON) == true, "Deserialized engine has poison")
	_check(restored.has_status(StatusEngine.EFFECT_SILENCE) == false,
		"Deserialized engine has no Silence (OD-004 1-turn duration already elapsed)")

	# =========================================================================
	# OD-004 owner-approved status policy
	# =========================================================================

	# Test 8: Approved default durations (single policy for Ren, enemies and bosses)
	var policy := StatusEngine.new()
	_check(policy.get_default_duration(StatusEngine.EFFECT_BURN) == 3, "OD-004 Burn defaults to 3 turns")
	_check(policy.get_default_duration(StatusEngine.EFFECT_POISON) == 3, "OD-004 Poison defaults to 3 turns")
	_check(policy.get_default_duration(StatusEngine.EFFECT_BLEED) == 3, "OD-004 Bleed defaults to 3 turns")
	_check(policy.get_default_duration(StatusEngine.EFFECT_REGENERATION) == 3, "OD-004 Regeneration defaults to 3 turns")
	_check(policy.get_default_duration(StatusEngine.EFFECT_DEFENSE_UP) == 2, "OD-004 Defense Up defaults to 2 turns")
	_check(policy.get_default_duration(StatusEngine.EFFECT_DEFENSE_DOWN) == 2, "OD-004 Defense Down defaults to 2 turns")
	_check(policy.get_default_duration(StatusEngine.EFFECT_SILENCE) == 1, "OD-004 Silence defaults to 1 turn")
	_check(policy.get_default_duration(StatusEngine.EFFECT_STUN) == 1, "OD-004 Stun defaults to 1 skipped action")
	_check(policy.get_default_duration(StatusEngine.EFFECT_SHIELD) == 3, "OD-004 Shield expires after 3 turns")

	# Applying without an explicit duration uses the approved default; over-long
	# requests are capped at the approved duration.
	policy.apply_status(StatusEngine.EFFECT_BURN)
	policy.apply_status(StatusEngine.EFFECT_DEFENSE_UP)
	policy.apply_status(StatusEngine.EFFECT_SHIELD)
	_check(policy.get_duration(StatusEngine.EFFECT_BURN) == 3, "Default Burn application lasts 3 turns")
	_check(policy.get_duration(StatusEngine.EFFECT_DEFENSE_UP) == 2, "Default Defense Up application lasts 2 turns")
	_check(policy.get_duration(StatusEngine.EFFECT_SHIELD) == 3, "Default Shield application lasts 3 turns")
	policy.apply_status(StatusEngine.EFFECT_BURN, 99, 1)
	_check(policy.get_duration(StatusEngine.EFFECT_BURN) == 3, "Burn is capped at the approved 3 turns")

	# Test 9: Same-name refresh takes the larger duration and larger potency, with
	# no intensity stacking.
	var refresh := StatusEngine.new()
	refresh.apply_status(StatusEngine.EFFECT_BURN, 1, 1)
	_check(refresh.get_duration(StatusEngine.EFFECT_BURN) == 1, "Short Burn applied first")
	refresh.apply_status(StatusEngine.EFFECT_BURN, 3, 2)
	_check(refresh.get_duration(StatusEngine.EFFECT_BURN) == 3, "Refresh takes the larger duration")
	_check(refresh.get_potency(StatusEngine.EFFECT_BURN) == 2, "Refresh takes the larger potency")
	_check(int(refresh.active_effects[StatusEngine.EFFECT_BURN].get("stacks", 0)) == 1,
		"Same-name refresh never stacks intensity (OD-004)")
	refresh.apply_status(StatusEngine.EFFECT_BURN, 1, 1)
	_check(refresh.get_duration(StatusEngine.EFFECT_BURN) == 3,
		"Weaker reapplication does not shorten the remaining duration")
	_check(refresh.get_potency(StatusEngine.EFFECT_BURN) == 2,
		"Weaker reapplication does not lower potency")
	_check(int(refresh.active_effects[StatusEngine.EFFECT_BURN].get("stacks", 0)) == 1,
		"Repeated applications keep a single intensity")

	# Approved durations expire exactly on schedule.
	var durations := StatusEngine.new()
	durations.apply_status(StatusEngine.EFFECT_REGENERATION)
	durations.apply_status(StatusEngine.EFFECT_DEFENSE_DOWN)
	durations.apply_status(StatusEngine.EFFECT_SHIELD)
	var tick_one: Array[String] = durations.tick_turn_end()
	_check(tick_one.is_empty(), "No status expires after one turn")
	var tick_two: Array[String] = durations.tick_turn_end()
	_check(tick_two.has(StatusEngine.EFFECT_DEFENSE_DOWN), "Defense Down expires after 2 turns")
	_check(not tick_two.has(StatusEngine.EFFECT_REGENERATION) and not tick_two.has(StatusEngine.EFFECT_SHIELD),
		"Regeneration and Shield outlive Defense Down")
	var tick_three: Array[String] = durations.tick_turn_end()
	_check(tick_three.has(StatusEngine.EFFECT_REGENERATION), "Regeneration expires after 3 turns")
	_check(tick_three.has(StatusEngine.EFFECT_SHIELD), "Shield expires after 3 turns when not depleted")

	# Test 10: Shield also expires when depleted (authored potency consumed).
	var shield := StatusEngine.new()
	shield.apply_status(StatusEngine.EFFECT_SHIELD, -1, 4)
	var break_hit: Dictionary = shield.process_incoming_damage(4)
	_check(int(break_hit["shield_absorbed"]) == 4, "Shield absorbed its full potency")
	_check(shield.has_status(StatusEngine.EFFECT_SHIELD) == false,
		"Shield expires immediately when depleted")

	# Test 11: Cleanse removes negative statuses only.
	var cleanse := StatusEngine.new()
	cleanse.apply_status(StatusEngine.EFFECT_BURN, -1, 2)
	cleanse.apply_status(StatusEngine.EFFECT_POISON, -1, 1)
	cleanse.apply_status(StatusEngine.EFFECT_DEFENSE_DOWN, -1, 1)
	cleanse.apply_status(StatusEngine.EFFECT_DEFENSE_UP, -1, 1)
	cleanse.apply_status(StatusEngine.EFFECT_SHIELD, -1, 5)
	cleanse.apply_status(StatusEngine.EFFECT_REGENERATION, -1, 1)
	var removed: Array[String] = cleanse.cleanse_negative()
	_check(removed.has(StatusEngine.EFFECT_BURN) and removed.has(StatusEngine.EFFECT_POISON)
		and removed.has(StatusEngine.EFFECT_DEFENSE_DOWN),
		"Cleanse removed every negative status")
	_check(removed.size() == 3, "Cleanse removed exactly the negative statuses")
	_check(cleanse.has_status(StatusEngine.EFFECT_BURN) == false, "Burn is gone after cleanse")
	_check(cleanse.has_status(StatusEngine.EFFECT_DEFENSE_UP) == true, "Cleanse keeps positive Defense Up")
	_check(cleanse.has_status(StatusEngine.EFFECT_SHIELD) == true, "Cleanse keeps positive Shield")
	_check(cleanse.has_status(StatusEngine.EFFECT_REGENERATION) == true, "Cleanse keeps positive Regeneration")
	_check(cleanse.cleanse_negative().is_empty(), "Second cleanse on an all-positive engine removes nothing")

	# Test 12: Stun skips exactly one action.
	var stun := StatusEngine.new()
	stun.apply_status(StatusEngine.EFFECT_STUN)
	_check(stun.get_duration(StatusEngine.EFFECT_STUN) == 1, "OD-004 Stun lasts one skipped action")
	_check(stun.can_act() == false, "Stunned actor cannot act")
	_check(stun.consume_stun() == true, "The skipped action consumes the Stun")
	_check(stun.has_status(StatusEngine.EFFECT_STUN) == false, "Stun is cleared after the skip")
	_check(stun.can_act() == true, "Actor may act again after exactly one skipped action")
	_check(stun.consume_stun() == false, "A second skip is not granted without a new Stun")

	if _failures > 0:
		printerr("STATUS ENGINE TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL STATUS ENGINE TESTS PASSED SUCCESSFULLY ===")
	quit(0)
