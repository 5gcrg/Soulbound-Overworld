extends SceneTree

## SBL-TITLE-001 Title Screen & Procedural Audio Feedback Test Suite
## Requirements: GDD-098/103, TC-ACC-001, AGENTS.md Invariants.

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("TITLE AUDIO TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-TITLE-001 Title Screen & Procedural Audio Test Suite ---")

	# ==========================================================================
	# Part 1: AudioManager Verification
	# ==========================================================================
	var audio := AudioManager.new()
	root.add_child(audio)
	await process_frame

	_check(audio._players.size() == 8, "AudioManager initialized with 8 audio players")
	_check(audio._cache.size() >= 9, "All 9 procedural sound cues pregenerated in memory")

	var cues_to_test: Array[String] = [
		"button",
		"strike",
		"defend",
		"heal",
		"spell_cast",
		"shift",
		"portal",
		"correct",
		"wrong"
	]

	var played_cues: Array[String] = []
	audio.cue_played.connect(func(cue: String): played_cues.append(cue))

	for cue in cues_to_test:
		audio.play_cue(cue)
		_check(audio._cache.has(cue), "Audio cache contains cue: %s" % cue)
		var stream: AudioStreamWAV = audio._cache[cue]
		_check(stream != null and stream.data.size() > 0, "Procedural WAV data generated for: %s" % cue)

	_check(played_cues.size() == cues_to_test.size(), "All 9 audio cues played through audio system")
	audio.queue_free()

	# ==========================================================================
	# Part 2: Title Screen Integration on GameRoot
	# ==========================================================================
	var root_scene: PackedScene = load("res://scenes/main/game_root.tscn")
	_check(root_scene != null, "game_root.tscn loaded")

	var game_root: Control = root_scene.instantiate() as Control
	root.add_child(game_root)
	await process_frame
	await process_frame

	_check(game_root.audio_manager != null, "GameRoot hosts active AudioManager")

	# Test opening title screen explicitly
	game_root.open_title_screen()
	await process_frame

	_check(game_root._title_screen != null, "TitleScreen instantiated on TitleLayer")
	_check(game_root.has_blocking_modal() == true, "TitleScreen blocks overworld input")
	_check(game_root.player.input_frozen == true, "Player movement frozen during TitleScreen")

	var title: TitleScreen = game_root._title_screen
	_check(title.main_menu.visible == true, "Main menu options visible on TitleScreen")

	# Switch to profile selector
	title._on_select_profile_pressed()
	_check(title.profile_menu.visible == true, "Profile selector opened")
	_check(title.main_menu.visible == false, "Main menu hidden during profile selection")

	title._on_back_from_profiles()
	_check(title.main_menu.visible == true, "Main menu restored after back")

	# Test Academic Defense Quick-Start button
	title.defense_btn.pressed.emit()
	await process_frame
	await process_frame

	_check(game_root._title_screen == null, "TitleScreen dismissed after defense quick-start")
	_check(game_root.chapter_manager.current_chapter == ChapterManager.CHAPTER_3, "Defense quick-start set Chapter 3")
	_check(game_root.character_stats.level == 10, "Defense quick-start set Ren level 10")
	_check(game_root.inventory_manager.banked_items.get("spirit_salve", 0) >= 5, "Defense quick-start granted salves")

	# Test reopening title screen via evaluator debug bar
	game_root._debug_bar.title_screen_requested.emit()
	await process_frame

	_check(game_root._title_screen != null, "Title screen reopened via Evaluator Tools")
	game_root._close_title_screen()
	_check(game_root._title_screen == null, "Title screen closed cleanly")

	if _failures > 0:
		printerr("TITLE SCREEN & AUDIO TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL TITLE SCREEN & AUDIO TESTS PASSED SUCCESSFULLY ===")
	quit(0)
