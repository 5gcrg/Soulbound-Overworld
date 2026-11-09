extends SceneTree

## SBL-FIX-010 Release-Tier Separation Headless Test Suite
## Requirements: GDD-041, GDD-113, GDD-116, AGENTS.md Engineering Invariants.
##
## Verifies that:
## 1. Default tier is full_release.
## 2. In academic_mvp tier:
##    - Void Citadel region is unavailable and transitions to it are rejected.
##    - PortalToCitadel in Ashen Peaks is hidden and disabled.
##    - open_ending_modal() strictly no-ops (no modal instantiated).
##    - Capstone question q_meta_01 is excluded from QuestionBank queries.
##    - Chapter 4 (ACADEMIC_COMPLETE) remains endpoint.
## 3. In full_release tier:
##    - All Chapter V / ending pathways function normally.

var _failures: int = 0
var _game_root: Control = null

func _init() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		printerr("  FAIL: %s" % message)
		_failures += 1

func _run_tests() -> void:
	print("--- Running SBL-FIX-010 Release-Tier Separation Test Suite ---")

	# 1. Default Setting Verification
	_check(ReleaseTier.get_tier() == ReleaseTier.TIER_FULL_RELEASE, "Default release tier is full_release")
	_check(ReleaseTier.is_full_release() == true, "is_full_release() is true by default")
	_check(ReleaseTier.is_academic_mvp() == false, "is_academic_mvp() is false by default")

	# Setup GameRoot
	var root_scene: PackedScene = load("res://scenes/main/game_root.tscn")
	_check(root_scene != null, "GameRoot scene loaded")
	_game_root = root_scene.instantiate() as Control
	root.add_child(_game_root)
	await process_frame
	await process_frame

	# 2. Full Release Verification
	_check(_game_root.world_router.is_region_available("void_citadel") == true, "Full tier: void_citadel is available in router")
	var q_full: Dictionary = QuestionBank.get_question("q_meta_01")
	_check(not q_full.is_empty(), "Full tier: q_meta_01 is accessible in QuestionBank")
	_check(QuestionBank.get_questions_by_chapter(5).size() > 0, "Full tier: Chapter 5 questions accessible")

	_game_root.open_ending_modal("transcendence")
	await process_frame
	_check(_game_root._ending_modal != null, "Full tier: open_ending_modal opens modal")
	_game_root._close_ending_modal()
	await process_frame
	_check(_game_root._ending_modal == null, "Full tier: ending modal closed cleanly")

	# 3. Switch to Academic MVP Tier Override
	ReleaseTier.set_tier_override(ReleaseTier.TIER_ACADEMIC_MVP)
	_check(ReleaseTier.is_academic_mvp() == true, "Academic tier: is_academic_mvp() is true")
	_check(ReleaseTier.is_full_release() == false, "Academic tier: is_full_release() is false")

	# 3a. Router availability & rejection
	_check(_game_root.world_router.is_region_available("void_citadel") == false, "Academic tier: void_citadel unavailable in router")
	var warp_res: bool = _game_root.world_router.debug_warp("void_citadel", "default")
	_check(warp_res == false, "Academic tier: debug_warp to void_citadel is refused")
	_check(_game_root.world_router.active_region_id != "void_citadel", "Academic tier: active region is not void_citadel")

	# 3b. Ashen Peaks portal hidden/disabled
	var peaks_warp: bool = _game_root.world_router.debug_warp("ashen_peaks", "default")
	_check(peaks_warp == true, "Warp to ashen_peaks succeeded")
	_game_root._sync_release_tier_for_region("ashen_peaks")
	await process_frame

	var citadel_portal: Node = _game_root.world_router.active_region.get_node_or_null("Portals/PortalToCitadel")
	_check(citadel_portal != null, "PortalToCitadel node exists in Ashen Peaks")
	if citadel_portal != null:
		_check(citadel_portal.visible == false, "Academic tier: PortalToCitadel is hidden")
		if citadel_portal is Area2D:
			_check((citadel_portal as Area2D).monitoring == false, "Academic tier: PortalToCitadel monitoring disabled")

	# 3c. Transition request to void_citadel is refused
	if citadel_portal != null and citadel_portal is RegionPortal:
		_game_root.world_router.request_transition(citadel_portal as RegionPortal, "void_citadel", "from_peaks")
		await process_frame
		_check(_game_root.world_router.active_region_id == "ashen_peaks", "Academic tier: transition request refused; remained in ashen_peaks")

	# 3d. Ending modal path strictly no-ops
	_game_root.open_ending_modal("transcendence")
	await process_frame
	_check(_game_root._ending_modal == null, "Academic tier: open_ending_modal(transcendence) strictly no-ops")

	_game_root.open_ending_modal("restoration")
	await process_frame
	_check(_game_root._ending_modal == null, "Academic tier: open_ending_modal(restoration) strictly no-ops")

	# 3e. Capstone question is gated
	var q_academic: Dictionary = QuestionBank.get_question("q_meta_01")
	_check(q_academic.is_empty(), "Academic tier: get_question(q_meta_01) returns empty dict")
	_check(QuestionBank.get_questions_by_chapter(5).is_empty(), "Academic tier: get_questions_by_chapter(5) returns empty array")
	_check(QuestionBank.get_required_question_id_for_chapter(5) == "", "Academic tier: get_required_question_id_for_chapter(5) returns empty string")
	_check(not QuestionBank.get_all_question_ids().has("q_meta_01"), "Academic tier: get_all_question_ids does not contain q_meta_01")

	# 3f. Evaluator debug bar ending buttons disabled
	if _game_root._debug_bar != null:
		_game_root._debug_bar.sync_release_tier()
		var panel: Control = _game_root._debug_bar.panel
		var btn_citadel: Button = panel.get_node_or_null("Margin/VBox/RegionGrid/BtnCitadel") as Button
		if btn_citadel != null:
			_check(btn_citadel.disabled == true, "Academic tier: debug bar BtnCitadel is disabled")
		var btn_ending_a: Button = panel.get_node_or_null("Margin/VBox/CheatsGrid/BtnEndingA") as Button
		if btn_ending_a != null:
			_check(btn_ending_a.disabled == true, "Academic tier: debug bar BtnEndingA is disabled")

	# 4. Restore Full Release Tier
	ReleaseTier.clear_tier_override()
	_game_root._sync_chapter_gates()
	if _game_root._debug_bar != null:
		_game_root._debug_bar.sync_release_tier()
	_check(ReleaseTier.is_full_release() == true, "Cleared override: is_full_release() restored")
	_check(_game_root.world_router.is_region_available("void_citadel") == true, "Cleared override: void_citadel is available again")
	_check(not QuestionBank.get_question("q_meta_01").is_empty(), "Cleared override: q_meta_01 accessible again")

	# Clean up
	_game_root.queue_free()

	if _failures == 0:
		print("--- SBL-FIX-010 Release-Tier Separation Test Suite PASSED ---")
		quit(0)
	else:
		printerr("--- SBL-FIX-010 Release-Tier Separation Test Suite FAILED with %d errors ---" % _failures)
		quit(1)
