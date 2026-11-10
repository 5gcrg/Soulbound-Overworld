extends SceneTree

## SBL-OD-002/003/004 initiative test suite (owner-approved combat batch).
## Requirements: GDD-016/017/018/023, GDD-030, GDD-089, FR-CMB-001/002/003,
## TC-CMB-001, OD-002 (initiative), OD-004 (Stun/action budget interplay).
##
## Covers: initiative = effective Agility, higher acts first, stable actor ID
## ascending ties, one main action per actor per round (no extra turns), no ATB /
## no initiative rolls / determinism, haste-slow applied only at the round boundary,
## and the battle HUD preview of the next three actors in both combat scenes.

const BattleFixtureScene: PackedScene = preload("res://scenes/combat/battle_fixture.tscn")
const BossEncounterScene: PackedScene = preload("res://scenes/combat/boss_encounter.tscn")

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("INITIATIVE TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _order_is(order: Array, expected: Array) -> bool:
	if order.size() != expected.size():
		return false
	for i in order.size():
		if order[i] != expected[i]:
			return false
	return true

func _run_test() -> void:
	print("--- Running SBL-OD-002 Initiative Test Suite ---")

	# =========================================================================
	# 1. Initiative equals effective Agility; higher acts first (OD-002)
	# =========================================================================
	var order := InitiativeOrder.new()
	order.register_actor(&"slow", 5, "Slow")
	order.register_actor(&"fast", 50, "Fast")
	order.register_actor(&"mid", 20, "Mid")
	order.begin_round()

	_check(order.round_index == 1, "begin_round opens round 1")
	_check(_order_is(order.get_round_order(), [&"fast", &"mid", &"slow"]),
		"Higher effective Agility acts first (50 > 20 > 5)")
	_check(order.current_actor() == &"fast", "Current actor is the highest effective Agility")
	_check(order.get_effective_agility(&"fast") == 50, "Effective Agility is snapshotted for the round")

	# =========================================================================
	# 2. Ties resolve by stable actor ID ascending (OD-002)
	# =========================================================================
	var ties := InitiativeOrder.new()
	ties.register_actor(&"zeta", 10, "Zeta") # stable actor ID 0 (registered first)
	ties.register_actor(&"alpha", 10, "Alpha") # stable actor ID 1
	ties.begin_round()

	_check(ties.get_stable_id(&"zeta") < ties.get_stable_id(&"alpha"),
		"Stable actor IDs are ascending in registration order")
	_check(_order_is(ties.get_round_order(), [&"zeta", &"alpha"]),
		"Equal effective Agility resolves by stable actor ID ascending, not by display name")
	_check(ties.current_actor() == &"zeta", "Tied round opens with the lower stable actor ID")

	# =========================================================================
	# 3. One main action per actor per round; no extra turns (OD-002)
	# =========================================================================
	_check(order.can_act(&"fast"), "Actor may act at the start of its round")
	_check(order.record_action(&"fast"), "First main action is accepted")
	_check(order.record_action(&"fast") == false,
		"Second main action in the same round is rejected (no extra turns)")
	_check(order.can_act(&"fast") == false, "Actor has no action budget left this round")
	_check(order.has_acted(&"fast"), "Spent action is recorded for the round")
	_check(order.is_round_complete() == false, "Round is incomplete while actors remain")

	_check(order.record_action(&"mid"), "Second actor action accepted")
	_check(order.record_action(&"slow"), "Third actor action accepted")
	_check(order.is_round_complete(), "Round completes once every actor acted exactly once")
	_check(order.current_actor() == &"", "No actor is due after the round completes")

	order.begin_round()
	_check(order.round_index == 2, "Round index advances at the boundary")
	_check(order.can_act(&"fast"), "Action budget resets exactly once per round")
	_check(order.has_acted(&"fast") == false, "Recorded actions do not leak across rounds")
	_check(order.record_action(&"fast"), "Actor can act again in the new round")

	# =========================================================================
	# 4. No ATB / no initiative rolls: fully deterministic recompute (OD-002)
	# =========================================================================
	var deterministic := InitiativeOrder.new()
	deterministic.register_actor(&"a", 12, "A")
	deterministic.register_actor(&"b", 31, "B")
	deterministic.register_actor(&"c", 12, "C")
	deterministic.register_actor(&"d", 31, "D")
	var reference: Array[StringName] = []
	for iteration in 5:
		deterministic.begin_round()
		var pass_order: Array[StringName] = deterministic.get_round_order()
		if reference.is_empty():
			reference = pass_order.duplicate()
		_check(_order_is(pass_order, reference),
			"Recomputing round order is identical across repeats (no initiative rolls, no ATB ticks)")
	_check(reference[0] == &"b" or reference[0] == &"d",
		"Highest effective Agility actors open the round")
	_check(_order_is(reference, [&"b", &"d", &"a", &"c"]),
		"Order is effective Agility desc, then stable actor ID ascending (b=1 < d=3, a=0 < c=2)")

	# =========================================================================
	# 5. Haste/slow changes apply at the next round boundary only (OD-002)
	# =========================================================================
	order.set_modifier(&"slow", 100)
	_check(order.get_modifier(&"slow") == 100, "Modifier is stored")
	_check(order.get_effective_agility(&"slow") == 5,
		"Mid-round haste/slow change does not affect the current round's effective Agility")
	_check(_order_is(order.get_round_order(), [&"fast", &"mid", &"slow"]),
		"Mid-round haste/slow change does not reorder the current round")
	_check(order.current_actor() == &"mid",
		"Mid-round modifier does not move the action cursor (the acting actor spent its action already)")

	order.begin_round()
	_check(order.get_effective_agility(&"slow") == 105,
		"Haste/slow change applies at the round boundary (5 + 100)")
	_check(_order_is(order.get_round_order(), [&"slow", &"fast", &"mid"]),
		"Round re-sorts by the new effective Agility at the boundary")

	# Changing base Agility behaves identically: boundary-only reordering.
	order.set_actor_agility(&"mid", 500)
	_check(order.get_effective_agility(&"mid") == 20,
		"Base Agility change is not applied to the round already in progress")
	order.begin_round()
	_check(_order_is(order.get_round_order(), [&"mid", &"slow", &"fast"]),
		"Base Agility change is applied at the next round boundary")

	# =========================================================================
	# 6. Battle HUD preview: the next three actors (OD-002)
	# =========================================================================
	_check(InitiativeOrder.HUD_PREVIEW_COUNT == 3, "HUD preview constant is three actors")
	var preview: Array[StringName] = order.get_next_actors(InitiativeOrder.HUD_PREVIEW_COUNT)
	_check(preview.size() == 3, "Preview returns exactly three actors")
	_check(_order_is(preview, [&"mid", &"slow", &"fast"]),
		"Preview follows the round order from the actor due next")
	_check(order.record_action(&"mid"), "Acting advances the preview window")
	var preview_after: Array[StringName] = order.get_next_actors(InitiativeOrder.HUD_PREVIEW_COUNT)
	_check(_order_is(preview_after, [&"slow", &"fast", &"mid"]),
		"Preview advances with the action cursor and wraps into the next round")
	_check(order.get_next_actor_names(3) == "Slow > Fast > Mid",
		"Preview renders display names in order")

	# =========================================================================
	# 7. BattleFixture: authored defaults, round flow and next-three HUD
	# =========================================================================
	var fixture: BattleFixture = BattleFixtureScene.instantiate() as BattleFixture
	root.add_child(fixture)
	await process_frame
	await process_frame

	_check(fixture.initiative.round_index == 1, "Fixture opens round 1")
	_check(fixture.initiative.current_actor() == BattleFixture.ACTOR_REN,
		"Ren opens round 1 (authored Ren Agility 10 vs unauthored opponent 0)")
	_check(fixture.phase == BattleFixture.Phase.PLAYER, "Fixture waits for Ren's action")
	_check(fixture.turn_order_label != null, "Battle HUD exposes the turn order label")
	_check(fixture.get_next_three_actors_text() == "Next: Ren > Adversary > Ren",
		"Battle HUD shows the next three actors: %s" % fixture.get_next_three_actors_text())
	var fixture_preview: Array[StringName] = fixture.initiative.get_next_actors(3)
	_check(fixture_preview.size() == 3, "Fixture preview lists three actors")
	_check(fixture_preview[0] == BattleFixture.ACTOR_REN and fixture_preview[1] == BattleFixture.ACTOR_ENEMY
		and fixture_preview[2] == BattleFixture.ACTOR_REN,
		"Fixture preview wraps into the next round (Ren > Adversary > Ren)")

	# Round boundary: both actors act, then a new round opens for Ren.
	_check(fixture.request_action(&"defend"), "Ren's defend action accepted")
	_check(fixture.initiative.has_acted(BattleFixture.ACTOR_REN), "Ren's action recorded for round 1")
	_check(fixture.initiative.can_act(BattleFixture.ACTOR_REN) == false,
		"Ren cannot take a second main action in the same round")
	_check(fixture.phase == BattleFixture.Phase.ENEMY, "Opponent resolves after Ren's action")
	await process_frame
	await process_frame

	_check(fixture.initiative.round_index == 2,
		"Round advances after both actors spent their single main action")
	_check(fixture.phase == BattleFixture.Phase.PLAYER, "Control returns to Ren in round 2")
	_check(fixture.initiative.can_act(BattleFixture.ACTOR_REN),
		"Ren's action budget resets at the round boundary")
	_check(fixture.turn_order_label.text == "Next: Ren > Adversary > Ren",
		"Battle HUD refreshes after the round boundary: %s" % fixture.turn_order_label.text)

	# =========================================================================
	# 8. No-extra-turn negative control in BattleFixture (OD-002 / TC-CMB-001)
	# =========================================================================
	var guarded: BattleFixture = BattleFixtureScene.instantiate() as BattleFixture
	root.add_child(guarded)
	await process_frame
	_check(guarded.request_action(&"defend"), "Guarded fixture defend accepted")
	# Force player control to isolate the OD-002 round guard from the phase gate.
	guarded.phase = BattleFixture.Phase.PLAYER
	var snapshot: Dictionary = {
		"round": guarded.initiative.round_index,
		"ren_acted": guarded.initiative.has_acted(BattleFixture.ACTOR_REN),
		"enemy_pips": guarded.enemy_pips,
		"ren_pips": guarded.ren_pips,
		"ren_sp": guarded.ren_sp,
		"intent": guarded.enemy_intent,
		"last_action": guarded.last_player_action,
	}
	_check(guarded.request_action(&"attack") == false,
		"Second main action in the same round is rejected by the initiative guard")
	_check(guarded.initiative.round_index == snapshot["round"], "Rejected action leaves the round unchanged")
	_check(guarded.initiative.has_acted(BattleFixture.ACTOR_REN) == snapshot["ren_acted"],
		"Rejected action leaves the action record unchanged")
	_check(guarded.enemy_pips == snapshot["enemy_pips"], "Rejected action deals no damage")
	_check(guarded.ren_pips == snapshot["ren_pips"], "Rejected action changes no Ren HP")
	_check(guarded.ren_sp == snapshot["ren_sp"], "Rejected action spends no SP")
	_check(guarded.enemy_intent == snapshot["intent"], "Rejected action does not advance the telegraph")
	_check(guarded.last_player_action == snapshot["last_action"], "Rejected action leaves history unchanged")
	guarded.queue_free()
	await process_frame

	# =========================================================================
	# 9. BattleFixture: higher opponent initiative acts first, HUD leads with it
	# =========================================================================
	var opponent_first: BattleFixture = BattleFixtureScene.instantiate() as BattleFixture
	opponent_first.enemy_agility = 30 # test-authored effective Agility for the opponent
	opponent_first.ren_pips = 3 # Ren survives the opening strike in this fixture
	root.add_child(opponent_first) # _ready runs synchronously

	_check(opponent_first.phase == BattleFixture.Phase.ENEMY,
		"Opponent opens the round when its effective Agility is higher")
	_check(opponent_first.turn_order_label.text == "Next: Adversary > Ren > Adversary",
		"Battle HUD leads with the higher-Initiative actor: %s" % opponent_first.turn_order_label.text)
	_check(opponent_first.initiative.current_actor() == BattleFixture.ACTOR_ENEMY,
		"Initiative cursor points at the opponent")

	await process_frame
	await process_frame
	_check(opponent_first.initiative.has_acted(BattleFixture.ACTOR_ENEMY),
		"Opponent acted before Ren when its effective Agility is higher")
	_check(opponent_first.phase == BattleFixture.Phase.PLAYER, "Ren's turn follows the opponent's")
	_check(opponent_first.ren_pips == 2, "Opening opponent strike resolved before Ren's first action")
	_check(opponent_first.enemy_intent == &"Recover", "Telegraph advanced after the opponent acted")
	_check(opponent_first.turn_order_label.text == "Next: Ren > Adversary > Ren",
		"Battle HUD preview advances with the cursor: %s" % opponent_first.turn_order_label.text)

	# Round 2 keeps the same effective Agility ordering (opponent first).
	_check(opponent_first.request_action(&"attack"), "Ren's first main action accepted")
	await process_frame
	await process_frame
	_check(opponent_first.initiative.round_index == 2, "Round 2 opened after both actors acted")
	_check(opponent_first.initiative.has_acted(BattleFixture.ACTOR_ENEMY),
		"Round 2 opens with the higher-Initiative opponent again")
	_check(opponent_first.phase == BattleFixture.Phase.PLAYER, "Ren acts after the opponent in round 2")
	_check(opponent_first.ren_pips == 2, "Opponent Recover round dealt no damage")
	opponent_first.queue_free()
	await process_frame

	# =========================================================================
	# 10. BattleFixture: haste/slow modifier applies only at the round boundary
	# =========================================================================
	var haste_fixture: BattleFixture = BattleFixtureScene.instantiate() as BattleFixture
	haste_fixture.ren_pips = 3
	root.add_child(haste_fixture)
	await process_frame

	haste_fixture.initiative.set_modifier(BattleFixture.ACTOR_ENEMY, 50)
	_check(haste_fixture.initiative.get_effective_agility(BattleFixture.ACTOR_ENEMY) == 0,
		"Haste modifier does not apply to the round already in progress")
	_check(haste_fixture.initiative.get_round_order()[0] == BattleFixture.ACTOR_REN,
		"Current round order is unchanged by the mid-round modifier")

	_check(haste_fixture.request_action(&"defend"), "Ren's defend accepted in the haste fixture")
	await process_frame
	await process_frame

	_check(haste_fixture.initiative.round_index == 2, "Haste fixture advanced to round 2")
	_check(haste_fixture.initiative.get_effective_agility(BattleFixture.ACTOR_ENEMY) == 50,
		"Haste modifier applies at the round boundary")
	_check(haste_fixture.initiative.get_round_order()[0] == BattleFixture.ACTOR_ENEMY,
		"Hasted opponent overtakes Ren in the new round")
	_check(haste_fixture.phase == BattleFixture.Phase.PLAYER,
		"Play resumes with Ren after the hasted opponent acted")
	_check(haste_fixture.initiative.can_act(BattleFixture.ACTOR_ENEMY) == false,
		"Haste changed ordering only - the opponent still spends exactly one action per round")
	_check(haste_fixture.ren_pips == 3, "Defend mitigated the hasted opponent's strike")
	haste_fixture.queue_free()
	await process_frame

	fixture.queue_free()
	await process_frame

	# =========================================================================
	# 11. BossEncounter: initiative defaults, HUD and one-action-per-round
	# =========================================================================
	var boss: BossEncounter = BossEncounterScene.instantiate() as BossEncounter
	root.add_child(boss) # _ready runs synchronously

	_check(boss.initiative.round_index == 1, "Boss encounter opens round 1")
	_check(boss.initiative.current_actor() == BossEncounter.ACTOR_REN,
		"Ren opens the boss round (authored Ren Agility 10 vs unauthored boss 0)")
	_check(boss.turn_order_label != null, "Boss HUD exposes the turn order label")
	_check(boss.get_next_three_actors_text() == "Next: Ren > Void Sovereign > Ren",
		"Boss HUD shows the next three actors: %s" % boss.get_next_three_actors_text())
	await process_frame
	await process_frame
	_check(boss.turn_counter == 1, "Boss does not act before Ren with authored initiative")

	_check(boss.request_action(&"attack"), "Ren's boss-round action accepted")
	_check(boss.boss_hp == 9, "Ren's round-1 action executed (boss HP 10 -> 9)")
	_check(boss.initiative.round_index == 2,
		"Boss round advances after both actors spent their single main action")
	_check(boss.turn_counter == 2, "Boss acted exactly once in round 1")
	_check(boss.initiative.can_act(BossEncounter.ACTOR_REN), "Ren's action budget resets in round 2")
	_check(boss.turn_order_label.text == "Next: Ren > Void Sovereign > Ren",
		"Boss HUD refreshes after the round boundary: %s" % boss.turn_order_label.text)

	# No-extra-turn negative control (OD-002 / TC-CMB-001).
	_check(boss.initiative.record_action(BossEncounter.ACTOR_REN),
		"Ren's round-2 action budget can be spent")
	var boss_snapshot: Dictionary = {
		"round": boss.initiative.round_index,
		"ren_hp": boss.ren_hp,
		"ren_sp": boss.ren_sp,
		"boss_hp": boss.boss_hp,
		"barrier": boss.boss_barrier,
		"turn_counter": boss.turn_counter,
		"intent": boss.boss_intent,
		"last_action": boss.last_player_action,
		"cooldowns": boss.kurei.cooldowns.duplicate(true),
	}
	_check(boss.request_action(&"attack") == false,
		"Second main action in the same boss round is rejected")
	_check(boss.initiative.round_index == boss_snapshot["round"], "Rejected boss action leaves the round unchanged")
	_check(boss.ren_hp == boss_snapshot["ren_hp"], "Rejected boss action changes no Ren HP")
	_check(boss.ren_sp == boss_snapshot["ren_sp"], "Rejected boss action spends no SP")
	_check(boss.boss_hp == boss_snapshot["boss_hp"], "Rejected boss action deals no damage")
	_check(boss.boss_barrier == boss_snapshot["barrier"], "Rejected boss action leaves the barrier unchanged")
	_check(boss.turn_counter == boss_snapshot["turn_counter"], "Rejected boss action does not advance the boss turn")
	_check(boss.boss_intent == boss_snapshot["intent"], "Rejected boss action leaves the telegraph unchanged")
	_check(boss.last_player_action == boss_snapshot["last_action"], "Rejected boss action leaves history unchanged")
	_check(boss.kurei.cooldowns == boss_snapshot["cooldowns"], "Rejected boss action starts no cooldown")
	boss.queue_free()
	await process_frame

	# =========================================================================
	# 12. BossEncounter: higher boss initiative acts first
	# =========================================================================
	var boss_first: BossEncounter = BossEncounterScene.instantiate() as BossEncounter
	boss_first.boss_agility = 30 # test-authored effective Agility for the boss
	root.add_child(boss_first) # _ready runs synchronously

	_check(boss_first.turn_order_label.text == "Next: Void Sovereign > Ren > Void Sovereign",
		"Boss HUD leads with the higher-Initiative actor: %s" % boss_first.turn_order_label.text)
	_check(boss_first.initiative.current_actor() == BossEncounter.ACTOR_BOSS,
		"Initiative cursor points at the boss")

	await process_frame
	await process_frame
	_check(boss_first.initiative.has_acted(BossEncounter.ACTOR_BOSS),
		"Boss acted before Ren when its effective Agility is higher")
	_check(boss_first.turn_counter == 2, "Boss spent exactly one action opening the round")
	_check(boss_first.ren_hp == 3, "Opening boss strike resolved before Ren's first action")

	_check(boss_first.request_action(&"attack"), "Ren's action accepted against the boss-first order")
	await process_frame
	await process_frame
	_check(boss_first.initiative.round_index == 2, "Boss-first round advanced after both actors acted")
	_check(boss_first.turn_counter == 3, "Boss acted exactly once per round (two rounds, two boss actions)")
	_check(boss_first.initiative.can_act(BossEncounter.ACTOR_REN),
		"Ren's action budget resets for the new round")
	boss_first.queue_free()
	await process_frame

	if _failures > 0:
		printerr("INITIATIVE TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL OD-002 INITIATIVE TESTS PASSED SUCCESSFULLY ===")
	quit(0)
