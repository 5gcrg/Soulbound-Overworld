extends SceneTree

## SBL-W11-002 Multi-Phase Apex Boss Encounter Headless Test Suite
## Requirements: GDD-041/116, FR-CMB-001/002/003, AGENTS.md Invariants.

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("BOSS COMBAT TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W11-002 Multi-Phase Boss Encounter Test Suite ---")

	var boss_scene: PackedScene = load("res://scenes/combat/boss_encounter.tscn")
	_check(boss_scene != null, "boss_encounter.tscn loaded successfully")

	var boss: BossEncounter = boss_scene.instantiate() as BossEncounter
	root.add_child(boss)
	await process_frame
	await process_frame

	# 1. Initial State
	var phase_tracker: Array = [false]
	boss.boss_phase_changed.connect(func(new_p: int) -> void:
		if new_p == 2:
			phase_tracker[0] = true
	)

	_check(boss.current_phase == BossEncounter.BossPhase.PHASE_1, "Starts in Phase 1")
	_check(boss.boss_hp == 10, "Initial Boss HP is 10")
	_check(boss.ren_hp == 4, "Initial Ren HP is 4")
	_check(boss.ren_sp == 3, "Initial Ren SP is 3")
	_check(boss.boss_barrier == 0, "Initial Void Shield is 0 (Inactive)")
	_check(boss.is_cataclysm_charging == false, "Cataclysm not charging initially")

	# 2. Combat Action - Strike
	var action_ok: bool = boss.request_action(&"attack")
	_check(action_ok, "Player strike accepted")
	_check(boss.boss_hp == 9, "Boss took 1 damage from strike (HP: 9)")

	# 3. Kurei Action - Flame Burst (2 dmg + Burn)
	action_ok = boss.request_action(&"kurei_flame_burst")
	_check(action_ok, "Flame Burst accepted")
	_check(boss.boss_hp == 6, "Boss took direct + burn damage (HP: 6)")
	_check(boss.boss_statuses.has_status(StatusEngine.EFFECT_BURN), "Boss afflicted with Burn status")

	# 4. Trigger Phase 2 Transition (Drop HP <= 5)
	boss.ren_hp = 4 # Keep Ren healthy for testing
	action_ok = boss.request_action(&"attack") # 6 HP - 1 = 5 HP -> triggers Phase 2!
	_check(action_ok, "Player strike accepted")
	_check(phase_tracker[0] == true, "boss_phase_changed signal emitted for Phase 2")
	_check(boss.current_phase == BossEncounter.BossPhase.PHASE_2, "Boss entered Phase 2 (Cosmic Overdrive)")
	_check(boss.boss_barrier > 0, "Void Shield activated with absorption points")
	_check(boss.is_cataclysm_charging == true, "Void Cataclysm telegraphed charge began")

	# 5. Shield Absorption Test
	var pre_barrier: int = boss.boss_barrier
	var pre_barrier_hp: int = boss.boss_hp
	boss.ren_hp = 4
	boss.request_action(&"attack") # Strikes shield
	_check(boss.boss_barrier < pre_barrier, "Void Shield absorbed damage")
	_check(boss.boss_hp == pre_barrier_hp, "Boss HP unaffected while barrier holds")

	# 6. Lumina Lance Piercing Test (bypasses barrier)
	pre_barrier_hp = boss.boss_hp
	boss.ren_sp = 2
	boss.ren_hp = 4
	boss.request_action(&"kurei_lumina_lance")
	_check(boss.boss_hp == pre_barrier_hp - 2, "Lumina Lance pierced barrier directly into Boss HP")

	# 7. Telegraphed Cataclysm Mitigation
	boss.cataclysm_timer = 1
	boss.ren_hp = 4
	var pre_ren_hp: int = boss.ren_hp
	boss.request_action(&"defend") # Player chooses Defend!
	_check(boss.ren_hp >= pre_ren_hp - 1, "Defend mitigated Cataclysm (damage taken <= 1)")
	_check(boss.is_cataclysm_charging == false, "Cataclysm charge concluded")

	# 8. Boss Defeat and Reward Granting
	var victory_reward_tracker: Array[Dictionary] = [{}]
	var inv: InventoryManager = InventoryManager.new()
	boss.inventory = inv
	boss.boss_defeated.connect(func(rewards: Dictionary) -> void:
		victory_reward_tracker[0] = rewards
	)

	# Finish off boss HP
	boss.boss_statuses.clear_all()
	boss.ren_hp = 4
	boss.boss_hp = 1
	boss.boss_barrier = 0
	boss.request_action(&"attack")
	_check(boss.current_phase == BossEncounter.BossPhase.VICTORY, "Boss defeated: VICTORY phase reached")
	_check(victory_reward_tracker[0].has("void_crown"), "Victory granted void_crown")
	_check(victory_reward_tracker[0].has("sovereign_core"), "Victory granted sovereign_core")
	_check(inv.banked_items.get("void_crown", 0) >= 1, "void_crown deposited in bank")
	_check(inv.banked_items.get("sovereign_core", 0) >= 1, "sovereign_core deposited in bank")
	_check(boss.continue_btn.visible == true, "Continue button displayed upon victory")

	# 9. GameRoot Integration Test
	var root_scene: PackedScene = load("res://scenes/main/game_root.tscn")
	var game_root: Control = root_scene.instantiate() as Control
	root.add_child(game_root)
	await process_frame
	await process_frame

	game_root._debug_bar.boss_combat_requested.emit()
	await process_frame
	_check(game_root._boss_encounter != null, "Evaluator debug bar launched Boss Encounter")
	_check(game_root.player.input_frozen == true, "Player movement frozen during Boss Encounter")

	game_root._close_boss_encounter()
	await process_frame
	_check(game_root._boss_encounter == null, "Boss encounter closed cleanly")
	_check(game_root.player.input_frozen == false, "Player unfrozen after boss encounter")

	# =========================================================================
	# SBL-REV-005 Phase Mastery in BossEncounter
	# =========================================================================
	print("--- Running SBL-REV-005 Phase Mastery in BossEncounter ---")
	var boss_mastery: BossEncounter = boss_scene.instantiate() as BossEncounter
	root.add_child(boss_mastery)
	await process_frame

	_check(boss_mastery.max_ren_sp == 3, "Baseline BossEncounter max_ren_sp is 3 without mastery")
	_check(boss_mastery.ren_sp == 3, "Baseline BossEncounter starting ren_sp is 3")

	var boss_tree := KureiTree.new()
	boss_tree.sync_with_level(8)
	boss_tree.unlock_skill(&"void_shift")
	boss_tree.unlock_skill(&"phase_mastery")
	_check(boss_tree.has_phase_mastery(), "Boss tree has phase_mastery unlocked")

	boss_mastery.kurei_tree = boss_tree
	_check(boss_mastery.max_ren_sp == 4, "Phase Mastery gives authored capacity 4 in BossEncounter")
	_check(boss_mastery.ren_sp == 3, "Phase Mastery preserves baseline starting SP 3")

	# Reapplication does not stack or refill
	boss_mastery.apply_kurei_tree_capacity()
	_check(boss_mastery.max_ren_sp == 4, "Reapplying capacity does not stack above 4")
	_check(boss_mastery.ren_sp == 3, "Reapplying capacity does not refill SP")

	# Direct passive attempt rejects without mutation
	var boss_passive_ok: bool = boss_mastery.request_action(&"kurei_phase_mastery")
	_check(boss_passive_ok == false, "Direct passive phase_mastery request rejected in BossEncounter")
	_check(boss_mastery.ren_sp == 3, "Rejected passive request leaves ren_sp unchanged")
	_check(boss_mastery.turn_counter == 1, "Rejected passive request leaves turn_counter unchanged")
	_check(boss_mastery.last_player_action == &"", "Rejected passive request leaves last_player_action unchanged")
	_check(boss_mastery.kurei.cooldowns.is_empty(), "Rejected passive request does not start cooldown")

	# Unsupported advanced boss skill (OD-003/004 boundary) rejects without mutation
	var unsupp_ok: bool = boss_mastery.request_action(&"kurei_solar_flare")
	_check(unsupp_ok == false, "Unsupported advanced skill solar_flare rejected in BossEncounter without mutation")
	_check(boss_mastery.ren_sp == 3, "Rejected unsupported action leaves ren_sp at 3")
	_check(boss_mastery.turn_counter == 1, "Rejected unsupported action leaves turn_counter at 1")
	_check(boss_mastery.boss_hp == 10, "Rejected unsupported action leaves boss_hp at 10")

	# Turn 1: Defend against Void Strike -> end of turn regenerates SP to 4 (clamped to max_ren_sp 4)!
	boss_mastery.request_action(&"defend")
	_check(boss_mastery.ren_sp == 4, "SP regenerated to 4 (effective maximum with Phase Mastery)")

	# Respec restores baseline capacity 3 and clamps SP
	boss_tree.respec_talents()
	_check(boss_mastery.max_ren_sp == 3, "Respec restores BossEncounter max_ren_sp to baseline 3")
	_check(boss_mastery.ren_sp == 3, "Respec clamps ren_sp to restored baseline 3")

	# Cleanup
	boss.queue_free()
	game_root.queue_free()
	boss_mastery.queue_free()

	if _failures == 0:
		print("--- SBL-W11-002 Multi-Phase Boss Encounter Test Suite PASSED ---")
		quit(0)
	else:
		printerr("--- SBL-W11-002 Multi-Phase Boss Encounter Test Suite FAILED with %d errors ---" % _failures)
		quit(1)
