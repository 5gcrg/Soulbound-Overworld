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

	if _failures > 0:
		printerr("KUREI COMBAT TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL KUREI COMBAT TESTS PASSED SUCCESSFULLY ===")
	quit(0)
