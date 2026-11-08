extends SceneTree

## SBL-W4-001 vertical slice headless test:
## Verifies SliceProgress state machine, completion gating, first-attempt immutability,
## persistence roundtrips through ProfileStore, slot isolation, and corrupt-state rejection.

const StoreScript = preload("res://scripts/persistence/profile_store.gd")
const SliceProgressScript = preload("res://scripts/vertical_slice/slice_progress.gd")
const SLOTS: Array[String] = ["profile_01", "profile_02", "profile_03"]
const ROOT_PREFIX: String = "user://sbl_w4_001_test_"

var _failures: int = 0
var _base: String = ""
var _roots: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_base = ROOT_PREFIX + "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_fresh_configuration()
	_test_progression_pipeline()
	_test_completion_gated_not_score_gated()
	_test_persistence_roundtrip_and_isolation()
	_test_corrupt_data_rejection()
	_test_out_of_order_guards()
	_cleanup()

	if _failures > 0:
		printerr("VERTICAL SLICE TESTS FAILED: ", _failures)
		quit(1)
		return
	print("VERTICAL SLICE TESTS PASSED")
	quit(0)

# --- Helpers ------------------------------------------------------------------

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("VERTICAL SLICE TEST FAILED: ", msg)
	return ok

func _root(tag: String) -> String:
	var r: String = _base + "_" + tag
	_roots.append(r)
	return r

func _store(root: String) -> StoreScript:
	return StoreScript.new(root)

func _global(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func _cleanup() -> void:
	for r in _roots:
		if not r.begins_with(ROOT_PREFIX):
			continue
		if not DirAccess.dir_exists_absolute(_global(r)):
			continue
		for slot in SLOTS:
			var d: String = r.path_join(slot)
			if not DirAccess.dir_exists_absolute(_global(d)):
				continue
			for f: String in DirAccess.get_files_at(d):
				if f.begins_with("profile.") and (f.ends_with(".json") or f.ends_with(".tmp")):
					DirAccess.remove_absolute(_global(d.path_join(f)))
			DirAccess.remove_absolute(_global(d))
		DirAccess.remove_absolute(_global(r))

# --- Tests --------------------------------------------------------------------

func _test_fresh_configuration() -> void:
	var root: String = _root("fresh")
	var store: StoreScript = _store(root)
	var sp: SliceProgress = SliceProgressScript.new()

	_check(not sp.ready, "sp starts unready")
	_check(sp.stage == SliceProgress.Stage.OFFERED, "default stage is OFFERED")
	_check(sp.first_choice == "", "default first_choice is empty")
	_check(not sp.attempt_correct, "default attempt_correct is false")

	# Unconfigured transition fails
	_check(sp.accept_quest() == ERR_UNCONFIGURED, "accept_quest before configure returns ERR_UNCONFIGURED")

	# Configure with null store fails
	_check(sp.configure(null, "profile_01") == ERR_INVALID_PARAMETER, "configure with null store returns ERR_INVALID_PARAMETER")

	# Configure with valid empty slot
	var err: Error = sp.configure(store, "profile_01")
	_check(err == OK, "configure on fresh slot returns OK")
	_check(sp.ready, "sp is ready after configure")
	_check(sp.stage == SliceProgress.Stage.OFFERED, "stage remains OFFERED")
	_check(sp.first_choice == "", "first_choice remains empty")
	_check(not sp.attempt_correct, "attempt_correct remains false")
	_check(not sp.recovered_from_backup, "recovered_from_backup is false")

func _test_progression_pipeline() -> void:
	var root: String = _root("pipeline")
	var store: StoreScript = _store(root)
	var sp: SliceProgress = SliceProgressScript.new()
	sp.configure(store, "profile_01")

	# OFFERED -> PRACTICE
	var err: Error = sp.accept_quest()
	_check(err == OK, "accept_quest succeeds")
	_check(sp.stage == SliceProgress.Stage.PRACTICE, "stage is now PRACTICE")
	_check(sp.first_choice == "", "first_choice still empty in PRACTICE")

	# Duplicate accept_quest fails
	_check(sp.accept_quest() == ERR_ALREADY_EXISTS, "duplicate accept_quest returns ERR_ALREADY_EXISTS")

	# Invalid choice in finish_practice
	_check(sp.finish_practice("unknown") == ERR_INVALID_PARAMETER, "unknown choice returns ERR_INVALID_PARAMETER")
	_check(sp.stage == SliceProgress.Stage.PRACTICE, "stage remains PRACTICE after invalid choice")

	# PRACTICE -> BATTLE with "match" (correct)
	err = sp.finish_practice(SliceProgress.CHOICE_MATCH)
	_check(err == OK, "finish_practice(match) succeeds")
	_check(sp.stage == SliceProgress.Stage.BATTLE, "stage is now BATTLE")
	_check(sp.first_choice == SliceProgress.CHOICE_MATCH, "first_choice is match")
	_check(sp.attempt_correct == true, "attempt_correct is true")

	# Duplicate finish_practice fails
	_check(sp.finish_practice(SliceProgress.CHOICE_MATCH) == ERR_ALREADY_EXISTS, "duplicate finish_practice returns ERR_ALREADY_EXISTS")

	# BATTLE -> TURN_IN
	err = sp.record_victory()
	_check(err == OK, "record_victory succeeds")
	_check(sp.stage == SliceProgress.Stage.TURN_IN, "stage is now TURN_IN")

	# TURN_IN -> COMPLETE
	err = sp.turn_in()
	_check(err == OK, "turn_in succeeds")
	_check(sp.stage == SliceProgress.Stage.COMPLETE, "stage is now COMPLETE")

	# Further transitions rejected
	_check(sp.turn_in() == ERR_ALREADY_EXISTS, "duplicate turn_in returns ERR_ALREADY_EXISTS")
	_check(sp.record_victory() == ERR_ALREADY_EXISTS, "record_victory after complete returns ERR_ALREADY_EXISTS")

func _test_completion_gated_not_score_gated() -> void:
	var root: String = _root("completion_gate")
	var store: StoreScript = _store(root)
	var sp: SliceProgress = SliceProgressScript.new()
	sp.configure(store, "profile_02")

	sp.accept_quest()
	# GDD-069 & FR-EDU-003: Incorrect choice ("mismatch") MUST unlock progression
	var err: Error = sp.finish_practice(SliceProgress.CHOICE_MISMATCH)
	_check(err == OK, "finish_practice with incorrect choice still succeeds (completion gated)")
	_check(sp.stage == SliceProgress.Stage.BATTLE, "advances to BATTLE despite incorrect answer")
	_check(sp.first_choice == SliceProgress.CHOICE_MISMATCH, "first_choice recorded as mismatch")
	_check(sp.attempt_correct == false, "attempt_correct recorded as false")

	# Full remaining loop still completes
	_check(sp.record_victory() == OK, "record_victory succeeds on incorrect branch")
	_check(sp.turn_in() == OK, "turn_in succeeds on incorrect branch")
	_check(sp.stage == SliceProgress.Stage.COMPLETE, "completed slice on incorrect branch")

func _test_persistence_roundtrip_and_isolation() -> void:
	var root: String = _root("persistence")
	var store: StoreScript = _store(root)

	# Pre-populate custom data in slot 1 and slot 2
	var p1: Dictionary = store.new_profile("profile_01")
	p1["character"]["level"] = 5
	p1["inventory"]["potions"] = 3
	store.save_profile("profile_01", p1)

	var p2: Dictionary = store.new_profile("profile_02")
	p2["character"]["level"] = 12
	store.save_profile("profile_02", p2)

	# Operate on slot 1 through SliceProgress
	var sp1: SliceProgress = SliceProgressScript.new()
	sp1.configure(store, "profile_01")
	sp1.accept_quest()
	sp1.finish_practice(SliceProgress.CHOICE_MATCH)

	# Check slot 1 in store preserves character and inventory
	var loaded1: Dictionary = store.load_profile("profile_01")
	_check(loaded1["error"] == OK, "slot 1 loaded ok")
	var prof1: Dictionary = loaded1["profile"]
	_check(prof1["character"]["level"] == 5, "character level preserved in slot 1")
	_check(prof1["inventory"]["potions"] == 3, "inventory preserved in slot 1")
	_check(prof1["world"]["vertical_slice"]["stage"] == "battle", "world stage is battle in store")
	_check(prof1["education"]["vertical_slice"]["first_choice"] == "match", "edu choice is match in store")

	# Check slot 2 is completely untouched (slot isolation)
	var loaded2: Dictionary = store.load_profile("profile_02")
	_check(loaded2["error"] == OK, "slot 2 loaded ok")
	var prof2: Dictionary = loaded2["profile"]
	_check(prof2["character"]["level"] == 12, "slot 2 character level preserved")
	_check(not prof2["world"].has("vertical_slice"), "slot 2 world has no vertical_slice")
	_check(not prof2["education"].has("vertical_slice"), "slot 2 education has no vertical_slice")

	# Re-create SliceProgress and configure from existing slot 1
	var sp1_reload: SliceProgress = SliceProgressScript.new()
	var err: Error = sp1_reload.configure(store, "profile_01")
	_check(err == OK, "reloading sp1 returns OK")
	_check(sp1_reload.ready, "reloaded sp1 is ready")
	_check(sp1_reload.stage == SliceProgress.Stage.BATTLE, "reloaded stage is BATTLE")
	_check(sp1_reload.first_choice == SliceProgress.CHOICE_MATCH, "reloaded choice is match")
	_check(sp1_reload.attempt_correct == true, "reloaded attempt_correct is true")

	# Advance reloaded instance to COMPLETE
	_check(sp1_reload.record_victory() == OK, "reloaded sp1 record_victory succeeds")
	_check(sp1_reload.turn_in() == OK, "reloaded sp1 turn_in succeeds")
	_check(sp1_reload.stage == SliceProgress.Stage.COMPLETE, "reloaded sp1 stage is COMPLETE")

func _test_corrupt_data_rejection() -> void:
	var root: String = _root("corrupt")
	var store: StoreScript = _store(root)

	# Corrupt 1: Bad fixture_id in world
	var p: Dictionary = store.new_profile("profile_01")
	p["world"]["vertical_slice"] = {"fixture_id": "wrong_id", "stage": "practice"}
	store.save_profile("profile_01", p)

	var sp: SliceProgress = SliceProgressScript.new()
	var err: Error = sp.configure(store, "profile_01")
	_check(err == ERR_INVALID_DATA, "bad fixture_id returns ERR_INVALID_DATA")
	_check(not sp.ready, "sp is not ready on bad fixture_id")

	# Corrupt 2: Unknown stage string
	p["world"]["vertical_slice"] = {"fixture_id": SliceProgress.FIXTURE_ID, "stage": "nonexistent_stage"}
	store.save_profile("profile_01", p)
	err = sp.configure(store, "profile_01")
	_check(err == ERR_INVALID_DATA, "unknown stage returns ERR_INVALID_DATA")

	# Corrupt 3: Stage BATTLE but education record is missing
	p["world"]["vertical_slice"] = {"fixture_id": SliceProgress.FIXTURE_ID, "stage": "battle"}
	p["education"].erase("vertical_slice")
	store.save_profile("profile_01", p)
	err = sp.configure(store, "profile_01")
	_check(err == ERR_INVALID_DATA, "missing education at battle stage returns ERR_INVALID_DATA")

	# Corrupt 4: Stage PRACTICE but education record is present prematurely
	p["world"]["vertical_slice"] = {"fixture_id": SliceProgress.FIXTURE_ID, "stage": "practice"}
	p["education"]["vertical_slice"] = {
		"fixture_id": SliceProgress.FIXTURE_ID,
		"first_choice": "match",
		"first_attempt_correct": true,
		"assessed": false,
	}
	store.save_profile("profile_01", p)
	err = sp.configure(store, "profile_01")
	_check(err == ERR_INVALID_DATA, "premature education at practice stage returns ERR_INVALID_DATA")

	# Corrupt 5: Inconsistent education choice vs correct flag
	p["world"]["vertical_slice"] = {"fixture_id": SliceProgress.FIXTURE_ID, "stage": "battle"}
	p["education"]["vertical_slice"] = {
		"fixture_id": SliceProgress.FIXTURE_ID,
		"first_choice": "match",
		"first_attempt_correct": false, # mismatch!
		"assessed": false,
	}
	store.save_profile("profile_01", p)
	err = sp.configure(store, "profile_01")
	_check(err == ERR_INVALID_DATA, "inconsistent choice/correct returns ERR_INVALID_DATA")

func _test_out_of_order_guards() -> void:
	var root: String = _root("guards")
	var store: StoreScript = _store(root)
	var sp: SliceProgress = SliceProgressScript.new()
	sp.configure(store, "profile_01")

	# While in OFFERED:
	_check(sp.finish_practice(SliceProgress.CHOICE_MATCH) == ERR_UNAVAILABLE, "finish_practice before accept returns ERR_UNAVAILABLE")
	_check(sp.record_victory() == ERR_UNAVAILABLE, "record_victory in OFFERED returns ERR_UNAVAILABLE")
	_check(sp.turn_in() == ERR_UNAVAILABLE, "turn_in in OFFERED returns ERR_UNAVAILABLE")

	# While in PRACTICE:
	sp.accept_quest()
	_check(sp.record_victory() == ERR_UNAVAILABLE, "record_victory in PRACTICE returns ERR_UNAVAILABLE")
	_check(sp.turn_in() == ERR_UNAVAILABLE, "turn_in in PRACTICE returns ERR_UNAVAILABLE")

	# While in BATTLE:
	sp.finish_practice(SliceProgress.CHOICE_MATCH)
	_check(sp.turn_in() == ERR_UNAVAILABLE, "turn_in in BATTLE returns ERR_UNAVAILABLE")
