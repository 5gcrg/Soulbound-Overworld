extends SceneTree

## SBL-TITLE-001 Title Screen & Procedural Audio Feedback Test Suite
## Requirements: GDD-098/103, TC-ACC-001, AGENTS.md Invariants.

const ProfileTestIsolationScript = preload("res://tests/support/profile_test_isolation.gd")

var _failures: int = 0
var _profile_isolation: ProfileTestIsolation = null

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("TITLE AUDIO TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-TITLE-001 Title Screen & Procedural Audio Test Suite ---")
	_profile_isolation = ProfileTestIsolationScript.new("title_screen_audio")

	# ==========================================================================
	# Part 1: AudioManager & SBL-REV-004 Bus Routing Verification
	# ==========================================================================
	# 1. Clean removal test: remove any pre-existing test Music/SFX buses
	var sfx_initial: int = AudioServer.get_bus_index("SFX")
	if sfx_initial >= 0:
		AudioServer.remove_bus(sfx_initial)
	var music_initial: int = AudioServer.get_bus_index("Music")
	if music_initial >= 0:
		AudioServer.remove_bus(music_initial)

	_check(AudioServer.get_bus_index("SFX") < 0, "SFX bus removed for isolated initialization test")
	_check(AudioServer.get_bus_index("Music") < 0, "Music bus removed for isolated initialization test")

	# 2. Initialize buses and assert existence, single instances, and routing to Master
	AudioManager.ensure_audio_buses()

	var mus_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	_check(mus_idx >= 0, "Music bus created by AudioManager.ensure_audio_buses()")
	_check(sfx_idx >= 0, "SFX bus created by AudioManager.ensure_audio_buses()")

	var music_count: int = 0
	var sfx_count: int = 0
	for b in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(b) == "Music":
			music_count += 1
		elif AudioServer.get_bus_name(b) == "SFX":
			sfx_count += 1

	_check(music_count == 1, "Exactly one Music bus exists")
	_check(sfx_count == 1, "Exactly one SFX bus exists")
	_check(AudioServer.get_bus_send(mus_idx) == &"Master", "Music bus routes to Master")
	_check(AudioServer.get_bus_send(sfx_idx) == &"Master", "SFX bus routes to Master")

	# 3. Reinitialize and assert no duplicate buses
	var bus_count_before: int = AudioServer.bus_count
	AudioManager.ensure_audio_buses()
	_check(AudioServer.bus_count == bus_count_before, "Re-initialization creates no duplicate buses")

	# 4. Instantiate AudioManager and assert all cue players route to SFX (never Master)
	var audio := AudioManager.new()
	root.add_child(audio)
	await process_frame

	_check(audio._players.size() == 8, "AudioManager initialized with 8 audio players")
	_check(audio.get_players().size() == 8, "get_players() returns 8 players")
	for i in range(audio._players.size()):
		var p: AudioStreamPlayer = audio._players[i]
		_check(p.bus == AudioManager.BUS_SFX, "Player %d assigned to SFX bus (got: %s)" % [i, p.bus])
		_check(p.bus != AudioManager.BUS_MASTER, "Player %d did not silently fall back to Master" % i)

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
	game_root.profile_store = _profile_isolation.make_store()
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

	# ==========================================================================
	# Part 3: SBL-REV-002 Title-Aware Settings & Backup Overlay Verification
	# ==========================================================================
	title = game_root._title_screen

	# 1. Click Title Settings
	title.settings_btn.pressed.emit()
	await process_frame

	_check(game_root._title_settings_sheet != null, "Title Settings opened SettingsSheet on overlay layer")
	var overlay_layer: CanvasLayer = game_root._get_title_overlay_layer()
	_check(overlay_layer != null, "TitleOverlayLayer exists")
	_check(game_root._title_settings_sheet.get_parent() == overlay_layer, "SettingsSheet attached to TitleOverlayLayer")
	_check(overlay_layer.layer == game_root._title_layer.layer + 1, "TitleOverlayLayer is exactly TitleLayer.layer + 1 (layer %d)" % overlay_layer.layer)
	_check(title._is_modal_blocked == true, "TitleScreen marked modal blocked while settings overlay open")
	_check(title.continue_btn.disabled == true, "Underlying title Continue button disabled")
	_check(title.continue_btn.focus_mode == Control.FOCUS_NONE, "Underlying title Continue button focus_mode is FOCUS_NONE")

	# 2. Duplicate entry guard: attempting to open again is rejected
	var sheet_before: SettingsSheet = game_root._title_settings_sheet
	game_root.open_title_settings("profile_01", title.settings_btn, "general")
	_check(game_root._title_settings_sheet == sheet_before, "Repeated title settings request creates no duplicate sheet")

	# 3. Underlying title clicks are ignored while modal blocked
	title._on_continue_pressed()
	_check(game_root._title_screen != null, "TitleScreen not dismissed by blocked Continue click")

	# 4. Close Title Settings
	game_root._title_settings_sheet.closed.emit()
	await process_frame

	_check(game_root._title_settings_sheet == null, "Title SettingsSheet freed on close")
	_check(game_root._title_screen != null, "TitleScreen remains open after settings sheet closed")
	_check(game_root.player.input_frozen == true, "Player Ren remains frozen while TitleScreen remains open")
	_check(title._is_modal_blocked == false, "TitleScreen modal block cleared")
	_check(title.continue_btn.disabled == false, "Underlying title Continue button re-enabled")
	_check(title.settings_btn.has_focus() == true, "Focus restored to originating SettingsBtn")

	# 5. Click Title Backup: reveals backup section immediately
	title.backup_btn.pressed.emit()
	await process_frame

	_check(game_root._title_settings_sheet != null, "Title Backup opened SettingsSheet")
	_check(game_root._title_settings_sheet.export_backup_btn.has_focus() == true, "Backup section controls focused immediately")

	# Close Title Backup
	game_root._title_settings_sheet.closed.emit()
	await process_frame

	_check(game_root._title_settings_sheet == null, "Title Backup sheet freed on close")
	_check(title.backup_btn.has_focus() == true, "Focus restored to originating BackupBtn")

	# 6. Recovery Export button routing
	title.recovery_box.visible = true
	title.recovery_export_btn.grab_focus()
	title.recovery_export_btn.pressed.emit()
	await process_frame

	_check(game_root._title_settings_sheet != null, "Recovery export button opened SettingsSheet")
	_check(game_root._title_settings_sheet.export_backup_btn.has_focus() == true, "Recovery export focuses backup controls immediately")

	game_root._title_settings_sheet.closed.emit()
	await process_frame

	_check(game_root._title_settings_sheet == null, "Recovery export sheet freed on close")
	_check(title.recovery_export_btn.has_focus() == true, "Focus restored to originating RecoveryExportBtn")

	game_root._close_title_screen()
	_check(game_root._title_screen == null, "Title screen closed cleanly")

	game_root.queue_free()
	await process_frame
	_check(_profile_isolation.real_profile_is_unchanged(), "Real user://profiles/profile_01 is byte-identical before and after the suite")
	_profile_isolation.cleanup()

	if _failures > 0:
		printerr("TITLE SCREEN & AUDIO TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL TITLE SCREEN & AUDIO TESTS PASSED SUCCESSFULLY ===")
	quit(0)
