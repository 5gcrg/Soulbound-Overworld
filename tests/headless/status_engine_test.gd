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
	engine.apply_status(StatusEngine.EFFECT_SILENCE, 2, 1)
	_check(engine.can_act() == false, "Stun correctly blocks actions")
	_check(engine.can_use_skills() == false, "Silence correctly blocks skills")

	# Test 6: Tick turn end duration decrement
	var expired: Array[String] = engine.tick_turn_end()
	_check(expired.has(StatusEngine.EFFECT_BURN), "1-turn Burn expired on end turn")
	_check(expired.has(StatusEngine.EFFECT_STUN), "1-turn Stun expired on end turn")
	_check(engine.can_act() == true, "Player can act again after Stun expiration")
	_check(engine.has_status(StatusEngine.EFFECT_POISON) == true, "2-turn Poison still has 1 turn remaining")

	# Test 7: Serialization round-trip
	var serialized: Dictionary = engine.serialize()
	var restored := StatusEngine.new()
	restored.deserialize(serialized)
	_check(restored.has_status(StatusEngine.EFFECT_POISON) == true, "Deserialized engine has poison")
	_check(restored.has_status(StatusEngine.EFFECT_SILENCE) == true, "Deserialized engine has silence")

	if _failures > 0:
		printerr("STATUS ENGINE TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL STATUS ENGINE TESTS PASSED SUCCESSFULLY ===")
	quit(0)
