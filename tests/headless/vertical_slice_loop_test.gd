extends SceneTree

## SBL-W4-001 M2 full loop headless integration test:
## Drives PlayerCharacter through the complete one-region loop:
## Quest NPC (Offer) -> Practice Question (Completion-gated) -> Combat -> Victory -> Turn-in -> Save Profile.

const ROOT_PREFIX: String = "user://sbl_w4_loop_test_"
const StoreScript = preload("res://scripts/persistence/profile_store.gd")

var _failures: int = 0
var _test_root: String = ""

func _fail(message: String) -> void:
	printerr("VERTICAL SLICE LOOP TEST FAILED: ", message)
	quit(1)

func _check(ok: bool, message: String) -> bool:
	if not ok:
		_failures += 1
		printerr("VERTICAL SLICE LOOP TEST FAILED: ", message)
	return ok

func _init() -> void:
	call_deferred("_run_loop_test")

func _run_loop_test() -> void:
	var watchdog := create_timer(10.0)
	watchdog.timeout.connect(func() -> void: _fail("Watchdog 10.0s timeout reached"))

	_test_root = ROOT_PREFIX + "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var test_store: ProfileStore = StoreScript.new(_test_root)

	var root_scene: PackedScene = load("res://scenes/main/game_root.tscn")
	if root_scene == null:
		_fail("Missing game_root.tscn")
		return

	var game_root: Node = root_scene.instantiate()
	root.add_child(game_root)
	await process_frame
	await process_frame

	# Configure game_root to use our isolated test store
	game_root._init_slice_progress(test_store, "profile_01")
	var slice_prog: SliceProgress = game_root.get("slice_progress") as SliceProgress
	if slice_prog == null:
		_fail("game_root missing slice_progress")
		return

	var player: PlayerCharacter = game_root.get_node("Player") as PlayerCharacter
	var router: WorldRouter = game_root.get_node("WorldRouter") as WorldRouter
	var battle_layer: CanvasLayer = game_root.get_node("BattleLayer") as CanvasLayer
	var dialog_layer: CanvasLayer = game_root.get_node("DialogLayer") as CanvasLayer

	if player == null or router == null or battle_layer == null or dialog_layer == null:
		_fail("Missing required game_root nodes")
		return

	var active_region: Node2D = router.active_region
	if active_region == null:
		_fail("Missing router.active_region")
		return

	var npc: Area2D = active_region.get_node_or_null("QuestNpc") as Area2D
	var encounter: Area2D = active_region.get_node_or_null("CombatEncounter") as Area2D

	if npc == null or encounter == null:
		_fail("Missing QuestNpc or CombatEncounter in Region Alpha")
		return

	print("PASS: Scene graph initialized and components located")

	# --- Step 1: Walk to Quest Guide NPC ---
	player.global_position = npc.global_position
	for i in 5:
		await physics_frame
	await process_frame

	if dialog_layer.get_child_count() != 1:
		_fail("Expected 1 QuestDialog in DialogLayer on NPC contact")
		return

	var dialog: QuestDialog = dialog_layer.get_child(0) as QuestDialog
	if dialog == null or not player.input_frozen:
		_fail("Dialog instance invalid or player not frozen on NPC contact")
		return

	_check(slice_prog.stage == SliceProgress.Stage.OFFERED, "Stage is OFFERED upon initial contact")
	print("PASS: Quest NPC opened dialog in OFFERED stage, player frozen")

	# --- Step 2: Accept Quest -> Enters PRACTICE ---
	dialog.accept_button.pressed.emit()
	await process_frame
	_check(slice_prog.stage == SliceProgress.Stage.PRACTICE, "Stage advanced to PRACTICE after accepting")
	_check(dialog.option_a_button.visible and dialog.option_b_button.visible, "Practice options visible")
	print("PASS: Quest accepted, advanced to PRACTICE stage")

	# --- Step 3: Choose Option B (Mismatch / Incorrect) to test GDD-069 Completion Gating ---
	dialog.option_b_button.pressed.emit()
	await process_frame

	_check(slice_prog.stage == SliceProgress.Stage.BATTLE, "Stage unlocked to BATTLE despite incorrect answer (GDD-069)")
	_check(slice_prog.first_choice == SliceProgress.CHOICE_MISMATCH, "first_choice is mismatch")
	_check(slice_prog.attempt_correct == false, "attempt_correct is false")
	_check(dialog.proceed_button.visible, "Proceed button visible after response")
	print("PASS: Educational practice answered, completion gating unblocked BATTLE stage")

	# Close dialog
	dialog.proceed_button.pressed.emit()
	await process_frame
	_check(dialog_layer.get_child_count() == 0, "Dialog closed after proceed pressed")
	_check(not player.input_frozen, "Player movement resumed after dialog closed")

	# --- SBL-VER-001 Probe 1: Newer banked gear disappears on a quest checkpoint ---
	# Grant banked gear after practice step, advance the quest, reload the profile, assert gear is still banked.
	game_root.inventory_manager.banked_items["probe_banked_gear"] = 2
	var inv_save_err: Error = game_root.inventory_manager.save_to_store(test_store, "profile_01")
	_check(inv_save_err == OK, "Saved banked gear to store after practice step")

	# --- Step 4: Walk to Combat Encounter ---
	player.global_position = encounter.global_position
	for i in 5:
		await physics_frame
	await process_frame

	if battle_layer.get_child_count() != 1:
		_fail("Expected 1 BattleFixture in BattleLayer on encounter contact")
		return

	var battle: BattleFixture = battle_layer.get_child(0) as BattleFixture
	if battle == null or not player.input_frozen:
		_fail("BattleFixture invalid or player not frozen on encounter contact")
		return
	print("PASS: Combat fixture opened, player frozen")

	# Fight through battle fixture to victory
	battle.defend_button.pressed.emit() # Ren defends Strike
	await process_frame
	battle.attack_button.pressed.emit() # Ren attacks Recover -> enemy HP 1
	await process_frame
	battle.defend_button.pressed.emit() # Ren defends Strike
	await process_frame
	battle.attack_button.pressed.emit() # Ren attacks Recover -> enemy HP 0 (VICTORY)
	await process_frame

	_check(battle.phase == BattleFixture.Phase.VICTORY, "Battle ended in VICTORY")
	battle.continue_button.pressed.emit()
	await process_frame
	await process_frame

	_check(battle_layer.get_child_count() == 0, "BattleFixture cleaned up after continue")
	_check(not player.input_frozen, "Player movement restored after battle")
	_check(slice_prog.stage == SliceProgress.Stage.TURN_IN, "Slice stage advanced to TURN_IN upon victory")
	print("PASS: Battle won and victory checkpoint recorded in TURN_IN stage")

	# Probe 1 assertion: Reload profile from store and verify newer banked gear survived the quest victory checkpoint
	var p_after_victory: Dictionary = test_store.load_profile("profile_01")["profile"]
	_check(p_after_victory["inventory"]["banked"].get("probe_banked_gear", 0) == 2,
		"PROBE 1 PASSED: Newer banked gear survived quest checkpoint into TURN_IN")

	# --- SBL-VER-001 Probe 2: Imported inventory disappears on the next checkpoint ---
	# Import a backup profile mid-run, advance a stage, assert imported banked/satchel counts survive the merge.
	var backup_res: Dictionary = test_store.export_backup("profile_01")
	_check(backup_res["error"] == OK, "Exported backup for mid-run mutation")
	var backup_dict: Dictionary = JSON.parse_string(backup_res["text"])
	backup_dict["inventory"]["banked"]["imported_gem"] = 7
	backup_dict["inventory"]["satchel"]["imported_herb"] = 3
	var backup_text: String = JSON.stringify(backup_dict)
	var import_err: Error = test_store.import_backup("profile_01", backup_text, GameplayProfileValidator.validate)
	_check(import_err == OK, "Imported backup mid-run into profile_01")
	game_root._reload_imported_profile()
	_check(game_root.inventory_manager.banked_items.get("imported_gem", 0) == 7, "Live banked items updated from import")
	_check(game_root.inventory_manager.satchel_items.get("imported_herb", 0) == 3, "Live satchel items updated from import")

	# --- Step 5: Return to Quest NPC for Turn In ---
	player.global_position = npc.global_position
	for i in 5:
		await physics_frame
	await process_frame

	if dialog_layer.get_child_count() != 1:
		_fail("Expected QuestDialog to reopen on return to NPC")
		return

	dialog = dialog_layer.get_child(0) as QuestDialog
	_check(dialog.turn_in_button.visible, "TurnIn button visible in TURN_IN stage")

	dialog.turn_in_button.pressed.emit()
	await process_frame
	_check(slice_prog.stage == SliceProgress.Stage.COMPLETE, "Slice stage is now COMPLETE")
	print("PASS: Quest turned in, stage is COMPLETE")

	# Probe 2 assertion: Verify imported banked & satchel counts survived the quest turn-in checkpoint
	var p_post_turnin: Dictionary = test_store.load_profile("profile_01")["profile"]
	_check(p_post_turnin["inventory"]["banked"].get("imported_gem", 0) == 7,
		"PROBE 2 PASSED: Imported banked inventory survived quest turn-in checkpoint")
	_check(p_post_turnin["inventory"]["satchel"].get("imported_herb", 0) == 3,
		"PROBE 2 PASSED: Imported satchel inventory survived quest turn-in checkpoint")
	_check(p_post_turnin["inventory"]["banked"].get("probe_banked_gear", 0) == 2,
		"PROBE 1 & 2 PASSED: Prior banked gear also survived across all checkpoints")

	dialog.close_button.pressed.emit()
	await process_frame

	# --- Step 6: Verify Persistence in ProfileStore ---
	var verify_store: ProfileStore = StoreScript.new(_test_root)
	var loaded: Dictionary = verify_store.load_profile("profile_01")
	_check(loaded["error"] == OK, "Profile loaded ok from store")
	var p: Dictionary = loaded["profile"]
	_check(p["world"]["vertical_slice"]["stage"] == "complete", "Stored world stage is complete")
	_check(p["education"]["vertical_slice"]["first_choice"] == "mismatch", "Stored education first_choice is mismatch")
	_check(p["education"]["vertical_slice"]["first_attempt_correct"] == false, "Stored education attempt_correct is false")
	_check(p["education"]["vertical_slice"]["assessed"] == false, "Stored education assessed is false")
	print("PASS: ProfileStore verified: immutable education record and complete stage persisted")

	_cleanup()

	if _failures > 0:
		_fail("Encountered %d failure(s)" % _failures)
		return

	print("=== VERTICAL SLICE FULL LOOP INTEGRATION TEST PASSED ===")
	quit(0)

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
