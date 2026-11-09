extends SceneTree

const GAME := preload("res://scenes/main/game_root.tscn")

var _failures: int = 0
var _fixture: String

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures += 1
		printerr("ACADEMIC PLAYTHROUGH FAILED: ", message)
	return condition

func _run() -> void:
	_fixture = "user://test_p1_chapter_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store := ProfileStore.new(_fixture)
	var game = GAME.instantiate()
	game.profile_store = store
	root.add_child(game)
	await _play(game, store)
	game.queue_free()
	await process_frame
	_cleanup()
	if _failures > 0:
		quit(1)
	else:
		print("ACADEMIC PLAYTHROUGH TESTS PASSED")
		quit(0)

func _play(game, store: ProfileStore) -> void:
	var router: WorldRouter = game.world_router
	var player: PlayerCharacter = game.player
	await _enter(player, router.active_region.get_node("Portals/PortalToVillage"))
	if not _check(router.active_region_id == "dawnreach_village", "enter Dawnreach via portal"):
		return
	await _enter(player, router.active_region.get_node("Portals/PortalToGrove"))
	if not _check(router.active_region_id == "dawnreach_village", "Grove gated before first activity"):
		return
	if not await _finish_activity(game, "ElderKael", "q_dec_01", true):
		return
	if not _check(game.chapter_manager.current_chapter == ChapterManager.CHAPTER_2, "wrong answer plus feedback unlocks chapter II"):
		return
	await _enter(player, router.active_region.get_node("Portals/PortalToGrove"))
	if not _check(router.active_region_id == "whispering_grove", "enter Grove after activity"):
		return
	await _enter(player, router.active_region.get_node("Portals/PortalToShrine"))
	if not _check(router.active_region_id == "whispering_grove", "Shrine gated before second activity"):
		return
	if not await _finish_activity(game, "ScoutLyra", "q_res_01", false):
		return
	await _enter(player, router.active_region.get_node("Portals/PortalToShrine"))
	if not _check(router.active_region_id == "forgotten_shrine", "enter Shrine after second activity"):
		return
	var final_portal: Area2D = router.active_region.get_node("AcademicPortal")
	await _enter(player, final_portal)
	if not _check(game._academic_modal == null and not game.chapter_manager.is_academic_complete, "final portal rejects incomplete third activity"):
		return
	if not await _finish_activity(game, "AwakeningAltar", "q_crit_02", false):
		return
	_check(not game.chapter_manager.is_academic_complete, "third activity alone does not finalize the game")
	await _enter(player, final_portal)
	var modal: AcademicCompletionModal = game._academic_modal
	if not _check(modal != null and game.chapter_manager.is_academic_complete, "final portal opens completion after three activities"):
		return
	_check(player.input_frozen, "player frozen while results are displayed")
	modal.close_btn.pressed.emit()
	await process_frame
	_check(not player.input_frozen, "completion modal restores movement")

	var reloaded = GAME.instantiate()
	reloaded.profile_store = store
	root.add_child(reloaded)
	_check(reloaded.chapter_manager.is_academic_complete, "completion survives a new session without manual saves")
	for chapter in range(1, 4):
		_check(reloaded.assessment_controller.is_chapter_activity_completed(chapter), "chapter %d activity persisted" % chapter)
	var first: Dictionary = reloaded.assessment_controller.records.get("q_dec_01", {})
	_check(first.get("first_attempt_correct", true) == false and first.get("total_attempts", 0) == 1, "wrong first attempt remains immutable after reload")
	reloaded.queue_free()
	await process_frame

func _finish_activity(game, npc_name: String, question_id: String, wrong: bool) -> bool:
	var npc: Area2D = game.world_router.active_region.get_node(npc_name)
	await _enter(game.player, npc)
	var dialog: ChapterActivityDialog = game._chapter_dialog
	if not _check(dialog != null, "open chapter practice via " + npc_name):
		return false
	var question := QuestionBank.get_question(question_id)
	var index: int = int(question["correct_index"])
	if wrong:
		index = (index + 1) % (question["options"] as Array).size()
	if not _check(index < dialog.option_buttons.size(), "answer button available"):
		return false
	var answer: Button = dialog.option_buttons[index]
	if not _check(answer.is_visible_in_tree() and not answer.disabled, "answer button actionable"):
		return false
	answer.pressed.emit()
	await process_frame
	if not _check(dialog.continue_button.is_visible_in_tree() and not dialog.continue_button.disabled, "feedback can be acknowledged"):
		return false
	dialog.continue_button.pressed.emit()
	await process_frame
	return _check(game._chapter_dialog == null, "activity closes after durable acknowledgement")

func _enter(player: PlayerCharacter, area: Area2D) -> void:
	player.global_position = area.global_position
	for frame in range(8):
		await physics_frame

func _cleanup() -> void:
	var slot := _fixture.path_join("profile_01")
	var dir := DirAccess.open(slot)
	if dir == null:
		return
	for name in dir.get_files():
		if name.begins_with("profile.") and (name.ends_with(".json") or name.ends_with(".tmp")):
			dir.remove(name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_fixture))
