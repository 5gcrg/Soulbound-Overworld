extends SceneTree

## SBL-BLD-002: End-to-End Headless Gate Verification for Exported Artifacts
## Requirements: GDD-041, GDD-113, GDD-116, AGENTS.md Engineering Invariants.
##
## Verifies that an exported .pck has the correct release tier baked in
## and enforces the architectural invariants without manual runtime overrides.

var _failures: int = 0

func _init() -> void:
	call_deferred("_run_verification")

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: %s" % msg)
	else:
		printerr("  FAIL: %s" % msg)
		_failures += 1

func _run_verification() -> void:
	print("--- Running End-to-End Exported Artifact Tier Verification ---")

	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var expected_tier: String = ""
	if user_args.size() > 0:
		expected_tier = user_args[0].strip_edges().to_lower()

	var active_tier: String = ReleaseTier.get_tier()
	print("Detected Active Release Tier in mounted .pck: '%s'" % active_tier)

	if not expected_tier.is_empty():
		_check(active_tier == expected_tier, "Active tier '%s' matches expected '%s'" % [active_tier, expected_tier])
		if ProjectSettings.has_setting("soulbound/release_tier"):
			var setting_tier: String = String(ProjectSettings.get_setting("soulbound/release_tier")).strip_edges().to_lower()
			_check(setting_tier == expected_tier, "Pack project setting 'soulbound/release_tier' ('%s') matches expected '%s'" % [setting_tier, expected_tier])

	var root_scene: PackedScene = load("res://scenes/main/game_root.tscn")
	_check(root_scene != null, "GameRoot scene loaded from pack")
	var game_root: Control = root_scene.instantiate() as Control
	root.add_child(game_root)
	await process_frame
	await process_frame

	if active_tier == ReleaseTier.TIER_ACADEMIC_MVP:
		_check(ReleaseTier.is_academic_mvp() == true, "Academic MVP: is_academic_mvp() is true")
		_check(ReleaseTier.is_full_release() == false, "Academic MVP: is_full_release() is false")
		_check(game_root.world_router.is_region_available("void_citadel") == false, "Academic MVP: void_citadel is unavailable in router")

		# Ashen Peaks portal to citadel must be hidden / disabled
		var peaks_warp: bool = game_root.world_router.debug_warp("ashen_peaks", "default")
		_check(peaks_warp == true, "Academic MVP: Warp to ashen_peaks succeeded")
		game_root._sync_release_tier_for_region("ashen_peaks")
		await process_frame

		var citadel_portal: Node = game_root.world_router.active_region.get_node_or_null("Portals/PortalToCitadel")
		_check(citadel_portal != null, "Academic MVP: PortalToCitadel node exists")
		if citadel_portal != null:
			_check(citadel_portal.visible == false, "Academic MVP: PortalToCitadel is hidden")
			if citadel_portal is Area2D:
				_check((citadel_portal as Area2D).monitoring == false, "Academic MVP: PortalToCitadel monitoring disabled")

		# Transition to void_citadel rejected
		if citadel_portal != null and citadel_portal is RegionPortal:
			game_root.world_router.request_transition(citadel_portal as RegionPortal, "void_citadel", "from_peaks")
			await process_frame
			_check(game_root.world_router.active_region_id == "ashen_peaks", "Academic MVP: transition request refused; remained in ashen_peaks")

		# Ending modal must no-op (no modal instantiated)
		game_root.open_ending_modal("transcendence")
		await process_frame
		_check(game_root._ending_modal == null, "Academic MVP: open_ending_modal(transcendence) strictly no-ops")
		game_root.open_ending_modal("restoration")
		await process_frame
		_check(game_root._ending_modal == null, "Academic MVP: open_ending_modal(restoration) strictly no-ops")

		# Capstone question excluded
		var q_meta: Dictionary = QuestionBank.get_question("q_meta_01")
		_check(q_meta.is_empty(), "Academic MVP: capstone question q_meta_01 is gated")
		_check(QuestionBank.get_questions_by_chapter(5).is_empty(), "Academic MVP: Chapter 5 questions gated")

	elif active_tier == ReleaseTier.TIER_FULL_RELEASE:
		_check(ReleaseTier.is_full_release() == true, "Full Release: is_full_release() is true")
		_check(ReleaseTier.is_academic_mvp() == false, "Full Release: is_academic_mvp() is false")
		_check(game_root.world_router.is_region_available("void_citadel") == true, "Full Release: void_citadel is available in router")

		# Ending modal must open
		game_root.open_ending_modal("transcendence")
		await process_frame
		_check(game_root._ending_modal != null, "Full Release: open_ending_modal instantiates modal")
		game_root._close_ending_modal()
		await process_frame
		_check(game_root._ending_modal == null, "Full Release: ending modal closed cleanly")

		# Capstone question accessible
		var q_meta: Dictionary = QuestionBank.get_question("q_meta_01")
		_check(not q_meta.is_empty(), "Full Release: capstone question q_meta_01 is accessible")
		_check(QuestionBank.get_questions_by_chapter(5).size() > 0, "Full Release: Chapter 5 questions accessible")
	else:
		_check(false, "Unrecognized active tier: '%s'" % active_tier)

	game_root.queue_free()

	if _failures == 0:
		print("--- Exported Artifact Tier Verification PASSED for tier '%s' ---" % active_tier)
		quit(0)
	else:
		printerr("--- Exported Artifact Tier Verification FAILED with %d error(s) ---" % _failures)
		quit(1)
