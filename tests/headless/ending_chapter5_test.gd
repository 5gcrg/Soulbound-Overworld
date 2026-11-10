extends SceneTree

## SBL-W11-001 Void Citadel & Dual-Ending Headless Test Suite
## Requirements: GDD-041/116, FR-WLD-001, AGENTS.md Invariants.

const ProfileTestIsolationScript = preload("res://tests/support/profile_test_isolation.gd")

var _failures: int = 0
var _profile_isolation: ProfileTestIsolation = null

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("VOID CITADEL & ENDING TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W11-001 Void Citadel & Dual-Ending Test Suite ---")
	_profile_isolation = ProfileTestIsolationScript.new("ending_chapter5")

	var root_scene: PackedScene = load("res://scenes/main/game_root.tscn")
	_check(root_scene != null, "game_root.tscn loaded successfully")

	var game_root: Control = root_scene.instantiate() as Control
	game_root.profile_store = _profile_isolation.make_store()
	root.add_child(game_root)
	await process_frame
	await process_frame

	# 1. Warp to Ashen Peaks and verify Citadel portal
	game_root.world_router.debug_warp("ashen_peaks", "default")
	await process_frame
	await process_frame
	_check(game_root.world_router.active_region_id == "ashen_peaks", "Warped to ashen_peaks")
	var peaks_region = game_root.world_router.active_region
	var portal_to_citadel = peaks_region.get_node_or_null("Portals/PortalToCitadel")
	_check(portal_to_citadel != null, "PortalToCitadel exists in ashen_peaks")

	# 2. Warp to Void Citadel
	game_root.world_router.debug_warp("void_citadel", "default")
	await process_frame
	await process_frame
	_check(game_root.world_router.active_region_id == "void_citadel", "Warped to void_citadel")
	var citadel_region = game_root.world_router.active_region
	_check(citadel_region != null, "Void Citadel active region valid")

	# 3. Verify Altars exist
	var altar_transcendence = citadel_region.get_node_or_null("EndingAltarTranscendence")
	var altar_restoration = citadel_region.get_node_or_null("EndingAltarRestoration")
	var boss_trigger = citadel_region.get_node_or_null("CitadelBossTrigger")
	_check(altar_transcendence != null, "EndingAltarTranscendence exists in Void Citadel")
	_check(altar_restoration != null, "EndingAltarRestoration exists in Void Citadel")
	_check(boss_trigger != null, "CitadelBossTrigger exists in Void Citadel")

	# 4. Test Ending A: Spirit Transcendence
	game_root.open_ending_modal("transcendence")
	await process_frame
	await process_frame
	_check(game_root._ending_modal != null, "EndingModal opened for Transcendence")
	_check(game_root.ending_manager.chosen_ending == "transcendence", "EndingManager recorded transcendence")
	_check(game_root.ending_manager.is_ending_achieved == true, "EndingManager marked ending achieved")
	_check(game_root.player.input_frozen == true, "Player frozen while ending modal is open")
	_check(game_root._ending_modal.ending_title.text.contains("Ending A"), "Modal shows Ending A title")
	_check(game_root._ending_modal.badge_label.text.contains("Transcendence Luminary"), "Modal displays correct Luminary badge")

	# Close modal
	game_root._close_ending_modal()
	await process_frame
	_check(game_root._ending_modal == null, "Ending modal closed")
	_check(game_root.player.input_frozen == false, "Player unfrozen after modal closed")

	# Verify persistence
	var loaded = game_root.profile_store.load_profile(game_root._profile_slot)
	_check(loaded.get("error") == OK, "Profile loaded successfully")
	var prof = loaded.get("profile", {})
	_check(prof.get("world", {}).get("ending", {}).get("chosen_ending") == "transcendence", "Profile persisted chosen ending transcendence")

	# 5. Test Ending B: World Restoration
	game_root.open_ending_modal("restoration")
	await process_frame
	await process_frame
	_check(game_root._ending_modal != null, "EndingModal opened for Restoration")
	_check(game_root.ending_manager.chosen_ending == "restoration", "EndingManager recorded restoration")
	_check(game_root._ending_modal.ending_title.text.contains("Ending B"), "Modal shows Ending B title")
	_check(game_root._ending_modal.badge_label.text.contains("Restoration Sovereign"), "Modal displays correct Sovereign badge")

	game_root._close_ending_modal()
	await process_frame
	_check(game_root._ending_modal == null, "Ending modal closed after Ending B")

	# 6. Verify Capstone Question in QuestionBank
	var q_meta = QuestionBank.get_question("q_meta_01")
	_check(not q_meta.is_empty(), "Question q_meta_01 exists in QuestionBank")
	_check(q_meta.get("chapter") == 5, "q_meta_01 belongs to Chapter 5")
	_check(q_meta.get("options", []).size() == 4, "q_meta_01 has 4 options")

	# 7. Evaluator Debug Bar Ending buttons
	game_root._debug_bar.ending_requested.emit("transcendence")
	await process_frame
	_check(game_root._ending_modal != null, "Debug bar ending cheat opens ending modal")
	game_root._close_ending_modal()

	game_root.queue_free()
	await process_frame
	_check(_profile_isolation.real_profile_is_unchanged(), "Real user://profiles/profile_01 is byte-identical before and after the suite")
	_profile_isolation.cleanup()

	if _failures == 0:
		print("--- SBL-W11-001 Void Citadel & Dual-Ending Test Suite PASSED ---")
		quit(0)
	else:
		printerr("--- SBL-W11-001 Void Citadel & Dual-Ending Test Suite FAILED with %d errors ---" % _failures)
		quit(1)
