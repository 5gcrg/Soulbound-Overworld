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

	# ==========================================================================
	# SBL-FIX-008: Terminal-State Input Exclusivity & Modal Blocking
	# ==========================================================================
	print("--- Running SBL-FIX-008 Input Exclusivity & Modal Blocking Tests ---")

	# Case 1: Academic Completion Modal input exclusivity
	_check(game_root.has_blocking_modal() == true, "has_blocking_modal() is true with academic modal visible")
	var initial_sheet_children: int = game_root._sheet_layer.get_child_count()

	for action in ["toggle_character", "toggle_inventory", "toggle_settings", "ui_cancel"]:
		_send_action(action)
		await process_frame

	_check(game_root._sheet_layer.get_child_count() == initial_sheet_children, "Zero extra children on sheet layer after input events")
	_check(game_root._character_sheet == null, "Character sheet not opened over academic modal")
	_check(game_root._inventory_sheet == null, "Inventory sheet not opened over academic modal")
	_check(game_root._settings_sheet == null, "Settings sheet not opened over academic modal")

	# Attempt to open second modal via debug bar while academic modal is open
	debug_bar.combat_requested.emit()
	debug_bar.dungeon_requested.emit()
	debug_bar.chapter_dialog_requested.emit()
	debug_bar.ending_requested.emit("transcendence")
	debug_bar.boss_combat_requested.emit()
	await process_frame

	_check(game_root._sheet_layer.get_child_count() == initial_sheet_children, "Zero extra children on sheet layer after debug bar triggers")
	_check(game_root._battle == null, "Combat fixture not opened over academic modal")
	_check(game_root._expedition == null, "Dungeon expedition not opened over academic modal")
	_check(game_root._boss_encounter == null, "Boss encounter not opened over academic modal")
	_check(game_root._ending_modal == null, "Ending modal not opened over academic modal")

	game_root._close_academic_modal()
	await process_frame
	_check(game_root._academic_modal == null, "Academic modal closed")
	_check(game_root.has_blocking_modal() == false, "has_blocking_modal() is false after closing")

	# Case 2: Boss Encounter Results State input exclusivity
	game_root.open_boss_encounter()
	await process_frame
	_check(game_root._boss_encounter != null, "Boss encounter opened")
	_check(game_root.has_blocking_modal() == true, "has_blocking_modal() is true during boss encounter")

	# Set boss encounter to results state (terminal victory)
	game_root._boss_encounter.current_phase = BossEncounter.BossPhase.VICTORY
	game_root._boss_encounter._update_ui()
	_check(game_root._boss_encounter.is_terminal() == true, "Boss encounter is in terminal results state")

	var boss_sheet_children: int = game_root._sheet_layer.get_child_count()
	for action in ["toggle_character", "toggle_inventory", "toggle_settings", "ui_cancel"]:
		_send_action(action)
		await process_frame

	_check(game_root._sheet_layer.get_child_count() == boss_sheet_children, "Zero extra children on sheet layer during boss results state")
	_check(game_root._character_sheet == null, "Character sheet blocked during boss results")
	_check(game_root._inventory_sheet == null, "Inventory sheet blocked during boss results")
	_check(game_root._settings_sheet == null, "Settings sheet blocked during boss results")

	# Debug bar attempts during boss results state
	debug_bar.academic_modal_requested.emit()
	debug_bar.ending_requested.emit("transcendence")
	await process_frame
	_check(game_root._sheet_layer.get_child_count() == boss_sheet_children, "Zero extra children on sheet layer after debug bar requests during boss results")
	_check(game_root._academic_modal == null, "Academic modal blocked during boss results")
	_check(game_root._ending_modal == null, "Ending modal blocked during boss results")

	game_root._close_boss_encounter()
	await process_frame
	_check(game_root._boss_encounter == null, "Boss encounter closed")
	_check(game_root.has_blocking_modal() == false, "has_blocking_modal() is false after closing boss encounter")

	# Case 3: Ending Modal Epilogue input exclusivity
	game_root.open_ending_modal("transcendence")
	await process_frame
	_check(game_root._ending_modal != null, "Ending modal opened")
	_check(game_root.has_blocking_modal() == true, "has_blocking_modal() is true during ending modal")

	var ending_sheet_children: int = game_root._sheet_layer.get_child_count()
	for action in ["toggle_character", "toggle_inventory", "toggle_settings", "ui_cancel"]:
		_send_action(action)
		await process_frame

	_check(game_root._sheet_layer.get_child_count() == ending_sheet_children, "Zero extra children on sheet layer during ending modal")
	_check(game_root._character_sheet == null, "Character sheet blocked during ending modal")
	_check(game_root._inventory_sheet == null, "Inventory sheet blocked during ending modal")
	_check(game_root._settings_sheet == null, "Settings sheet blocked during ending modal")

	debug_bar.academic_modal_requested.emit()
	debug_bar.boss_combat_requested.emit()
	await process_frame
	_check(game_root._sheet_layer.get_child_count() == ending_sheet_children, "Zero extra children after debug bar requests during ending modal")
	_check(game_root._academic_modal == null, "Academic modal blocked during ending modal")
	_check(game_root._boss_encounter == null, "Boss encounter blocked during ending modal")

	game_root._close_ending_modal()
	await process_frame
	_check(game_root._ending_modal == null, "Ending modal closed")
	_check(game_root.has_blocking_modal() == false, "has_blocking_modal() is false after closing ending modal")

	# Case 4: Chapter Activity Dialog input exclusivity
	game_root._on_debug_chapter_dialog()
	await process_frame
	_check(game_root._chapter_dialog != null, "Chapter activity dialog opened")
	_check(game_root.has_blocking_modal() == true, "has_blocking_modal() is true during chapter dialog")

	var ch_sheet_children: int = game_root._sheet_layer.get_child_count()
	for action in ["toggle_character", "toggle_inventory", "toggle_settings", "ui_cancel"]:
		_send_action(action)
		await process_frame

	_check(game_root._sheet_layer.get_child_count() == ch_sheet_children, "Zero extra children on sheet layer during chapter dialog")
	_check(game_root._character_sheet == null, "Character sheet blocked during chapter dialog")
	_check(game_root._inventory_sheet == null, "Inventory sheet blocked during chapter dialog")
	_check(game_root._settings_sheet == null, "Settings sheet blocked during chapter dialog")

	debug_bar.academic_modal_requested.emit()
	debug_bar.ending_requested.emit("restoration")
	await process_frame
	_check(game_root._sheet_layer.get_child_count() == ch_sheet_children, "Zero extra children after debug bar requests during chapter dialog")

	game_root._close_chapter_dialog()
	await process_frame
	_check(game_root._chapter_dialog == null, "Chapter dialog closed")
	_check(game_root.has_blocking_modal() == false, "has_blocking_modal() is false after closing chapter dialog")

	if _failures > 0:
		printerr("EVALUATOR DEBUG BAR TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL EVALUATOR DEBUG BAR TESTS PASSED SUCCESSFULLY ===")
	quit(0)

func _send_action(action_name: String) -> void:
	var ev_press := InputEventAction.new()
	ev_press.action = action_name
	ev_press.pressed = true
	Input.parse_input_event(ev_press)

	var ev_release := InputEventAction.new()
	ev_release.action = action_name
	ev_release.pressed = false
	Input.parse_input_event(ev_release)
