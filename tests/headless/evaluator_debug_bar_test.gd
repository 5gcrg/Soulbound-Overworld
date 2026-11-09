extends SceneTree

## SBL-EVAL-001 Evaluator Debug Bar Headless Test Suite
## Requirements: GDD-116, Defense Presentation Tools, AGENTS.md Invariants.

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("EVALUATOR DEBUG BAR TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-EVAL-001 Evaluator Debug Bar Test Suite ---")

	var root_scene: PackedScene = load("res://scenes/main/game_root.tscn")
	_check(root_scene != null, "game_root.tscn loaded successfully")

	var game_root: Control = root_scene.instantiate() as Control
	root.add_child(game_root)
	await process_frame
	await process_frame

	var debug_layer: CanvasLayer = game_root.get_node_or_null("DebugLayer") as CanvasLayer
	_check(debug_layer != null, "DebugLayer exists on GameRoot")
	_check(debug_layer.layer == 10, "DebugLayer is configured at high priority layer 10")

	var debug_bar: EvaluatorDebugBar = game_root._debug_bar
	_check(debug_bar != null, "EvaluatorDebugBar instanced on GameRoot")
	_check(debug_bar.panel.visible == false, "Debug panel starts hidden for unobtrusive presentation")

	# Test 1: Panel toggle
	debug_bar.toggle_panel()
	_check(debug_bar.panel.visible == true, "Panel becomes visible after toggle")
	debug_bar.toggle_panel()
	_check(debug_bar.panel.visible == false, "Panel hides after second toggle")

	# Test 2: Grant items cheat
	debug_bar.grant_items_requested.emit()
	await process_frame
	var bank: Dictionary = game_root.inventory_manager.banked_items
	_check(bank.get("iron_sword", 0) >= 1, "Granted iron_sword in bank")
	_check(bank.get("iron_armor", 0) >= 1, "Granted iron_armor in bank")
	_check(bank.get("spirit_salve", 0) >= 5, "Granted 5 spirit salves in bank")

	# Test 3: Max stats cheat
	debug_bar.max_stats_requested.emit()
	await process_frame
	_check(game_root.character_stats.level == 10, "Ren level set to 10")
	_check(game_root.character_stats.vitality == 25, "Ren vitality set to 25")
	_check(game_root.character_stats.get_max_hp() == 250, "Ren max HP scaled to 250")

	# Test 4: Complete activities cheat
	debug_bar.complete_activities_requested.emit()
	await process_frame
	_check(game_root.assessment_controller.is_chapter_activity_completed(1) == true, "Ch 1 activity completed")
	_check(game_root.assessment_controller.is_chapter_activity_completed(2) == true, "Ch 2 activity completed")
	_check(game_root.assessment_controller.is_chapter_activity_completed(3) == true, "Ch 3 activity completed")
	_check(game_root.chapter_manager.current_chapter == ChapterManager.CHAPTER_3, "Current chapter is Chapter 3")
	_check(game_root._can_complete_academic() == true, "Sanctum completion unlocked")

	# Test 5: Region warp to Dawnreach Village
	debug_bar.region_warp_requested.emit("dawnreach_village")
	await process_frame
	await process_frame
	_check(game_root.world_router.active_region_id == "dawnreach_village", "Warped directly to Dawnreach Village")

	# Test 6: Region warp to Chapter IV Ashen Peaks
	debug_bar.region_warp_requested.emit("ashen_peaks")
	await process_frame
	await process_frame
	_check(game_root.world_router.active_region_id == "ashen_peaks", "Warped directly to Chapter IV Ashen Peaks")

	# Test 7: Open Academic Completion Modal directly
	debug_bar.academic_modal_requested.emit()
	await process_frame
	_check(game_root._academic_modal != null, "Academic Completion Modal opened directly for evaluator review")

	if _failures > 0:
		printerr("EVALUATOR DEBUG BAR TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL EVALUATOR DEBUG BAR TESTS PASSED SUCCESSFULLY ===")
	quit(0)
