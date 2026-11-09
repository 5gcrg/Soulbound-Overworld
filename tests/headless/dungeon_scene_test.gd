extends SceneTree

## SBL-W8-003 / SBL-P1-B dungeon expedition scene test suite:
## Verifies DungeonExpedition scene generation, extraction portal, loot transfer,
## and SBL-P1-B atomic extraction with failure retry and ProfileStore durability.
## Requirements: GDD-037, FR-DNG-003, TC-DNG-004.

const DungeonExpeditionScene: PackedScene = preload("res://scenes/dungeon/dungeon_expedition.tscn")

var _failures: int = 0

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("DUNGEON SCENE TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running SBL-W8-003 Dungeon Scene Test Suite ---")
	var expedition: DungeonExpedition = DungeonExpeditionScene.instantiate() as DungeonExpedition
	root.add_child(expedition)

	var ok: bool = expedition.setup(1337, 6)
	_check(ok == true, "Expedition setup succeeded")
	_check(expedition.is_active == true, "Expedition is active")
	_check(expedition.rooms_container.get_child_count() == 6, "Rooms container holds 6 rooms")
	_check(expedition.extraction_portal != null, "Extraction portal spawned")

	# Check satchel gathered loot
	_check(expedition.inventory.satchel_items.has("ancient_relic_fragment"), "Satchel collected relic fragments from normal rooms")
	var fragment_count: int = expedition.inventory.satchel_items["ancient_relic_fragment"]
	_check(fragment_count > 0, "Satchel holds > 0 fragments")

	# Adapt standalone regression to go through supported advance path to extraction chamber
	while not expedition.is_at_extraction_chamber():
		expedition._on_advance_pressed()
	_check(expedition.is_at_extraction_chamber() == true, "Reached extraction chamber via advance path")
	fragment_count = expedition.inventory.satchel_items.get("ancient_relic_fragment", 0)

	# Test Extraction
	var extracted: Dictionary = expedition.extract_now()
	_check(extracted["ancient_relic_fragment"] == fragment_count, "All fragments extracted")
	_check(expedition.inventory.satchel_items.is_empty(), "Satchel empty after extraction")
	_check(expedition.inventory.banked_items["ancient_relic_fragment"] == fragment_count, "Fragments transferred to bank")
	_check(expedition.is_active == false, "Expedition deactivated after extraction")

	# Test Defeat on second run
	expedition.setup(42, 5)
	_check(expedition.inventory.satchel_items.has("ancient_relic_fragment"), "Second run gathered new satchel loot")
	var lost: Dictionary = expedition.fail_now()
	_check(lost.size() > 0, "Defeat returned lost satchel items")
	_check(expedition.inventory.satchel_items.is_empty(), "Satchel wiped on defeat")
	_check(expedition.inventory.banked_items["ancient_relic_fragment"] == fragment_count, "Banked items strictly preserved after defeat")

	expedition.queue_free()

	# Run SBL-P1-B Atomic Extraction Regression Test
	_test_atomic_extraction_commit_and_retry()

	# Run SBL-P1-C Expedition Suspend & Resume Test
	_test_expedition_suspend_and_resume()

	# Run SBL-FIX-006 persisted suspend snapshot test
	await _test_game_persisted_expedition_resume()

	if _failures > 0:
		printerr("DUNGEON SCENE TESTS FAILED: ", _failures)
		quit(1)
		return

	print("=== ALL DUNGEON SCENE TESTS PASSED SUCCESSFULLY ===")
	quit(0)

func _test_atomic_extraction_commit_and_retry() -> void:
	print("--- Running SBL-P1-B Atomic Extraction Regression Test ---")
	var test_root: String = "user://test_dungeon_atomic_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var test_store: ProfileStore = ProfileStore.new(test_root)

	var expedition: DungeonExpedition = DungeonExpeditionScene.instantiate() as DungeonExpedition
	root.add_child(expedition)

	var live_inventory: InventoryManager = expedition.inventory
	var ok: bool = expedition.setup(1337, 6)
	_check(ok == true, "Atomic setup succeeded")
	_check(expedition.is_active == true, "Atomic expedition is active")

	var initial_satchel_count: int = live_inventory.satchel_items.get("ancient_relic_fragment", 0)
	_check(initial_satchel_count > 0, "Initial satchel gathered fragments")

	# Save initial baseline into profile store
	var save_err: Error = live_inventory.save_to_store(test_store, "profile_01")
	_check(save_err == OK, "Initial baseline inventory saved to ProfileStore")

	# Wire commit_extraction (game-backed)
	var callback_state: Dictionary = {"calls": 0, "fail": true}

	expedition.commit_extraction = func(candidate: InventoryManager) -> Error:
		callback_state["calls"] += 1
		if callback_state["fail"]:
			return ERR_FILE_CANT_WRITE
		return candidate.save_to_store(test_store, "profile_01")

	# Test 1: Guard early extraction request before reaching actual extraction chamber on game-backed calls
	_check(expedition.is_at_extraction_chamber() == false, "Currently at spawn chamber (step 0)")
	var early_result: Dictionary = expedition.extract_now()
	_check(early_result.is_empty(), "Early extraction request rejected before reaching extraction chamber")
	_check(callback_state["calls"] == 0, "commit_extraction was NOT invoked on early attempt")
	_check(expedition.is_active == true, "Expedition remains active after early attempt")
	_check(live_inventory.satchel_items.get("ancient_relic_fragment", 0) == initial_satchel_count, "Live satchel untouched on early attempt")
	_check(live_inventory.banked_items.get("ancient_relic_fragment", 0) == 0, "Live bank untouched on early attempt")

	# Advance along supported path to extraction chamber
	while not expedition.is_at_extraction_chamber():
		expedition._on_advance_pressed()
	_check(expedition.is_at_extraction_chamber() == true, "Navigated to actual extraction chamber")

	var gathered_count: int = live_inventory.satchel_items.get("ancient_relic_fragment", 0)
	_check(gathered_count >= initial_satchel_count, "Satchel holds gathered fragments at extraction shrine")

	# Track signal emissions
	var completed_emissions: Array[Dictionary] = []
	var failure_errors: Array[Error] = []

	expedition.expedition_completed.connect(func(items: Dictionary):
		completed_emissions.append(items)
	)
	expedition.extraction_save_failed.connect(func(err: Error):
		failure_errors.append(err)
	)

	# Test 2: Injected first commit failure
	callback_state["fail"] = true
	var fail_result: Dictionary = expedition.extract_now()

	_check(fail_result.is_empty(), "extract_now returned empty Dictionary on commit failure")
	_check(callback_state["calls"] == 1, "commit_extraction callback was invoked exactly once")
	_check(failure_errors.size() == 1, "extraction_save_failed signal emitted exactly once")
	_check(failure_errors[0] == ERR_FILE_CANT_WRITE, "extraction_save_failed error matches injected error")
	_check(completed_emissions.is_empty(), "expedition_completed was NOT emitted on failure (no premature success)")
	_check(expedition.is_active == true, "Expedition remains active on commit failure (run not finished)")
	_check(live_inventory.satchel_items.get("ancient_relic_fragment", 0) == gathered_count, "Live satchel NOT mutated on failure")
	_check(live_inventory.banked_items.get("ancient_relic_fragment", 0) == 0, "Live bank NOT mutated on failure")

	# Verify modal UI state on failure: retry message shown without disabling retry
	_check(expedition.extract_btn.disabled == false, "Extract button is enabled for retry")
	_check(expedition.room_description_label.text.find("failed") != -1, "Retry error message shown in modal description label")

	# Verify no premature disk mutation on failure
	var check_disk_inv: InventoryManager = InventoryManager.new()
	var check_err: Error = check_disk_inv.load_from_store(test_store, "profile_01")
	_check(check_err == OK, "Loaded profile store for failure verification")
	_check(check_disk_inv.banked_items.get("ancient_relic_fragment", 0) == 0, "No premature items granted in ProfileStore on failure")

	# Test 3: Succeeding retry
	callback_state["fail"] = false
	var retry_result: Dictionary = expedition.extract_now()

	_check(retry_result.get("ancient_relic_fragment", 0) == gathered_count, "extract_now returned extracted items on retry")
	_check(callback_state["calls"] == 2, "commit_extraction invoked second time for retry")
	_check(failure_errors.size() == 1, "No further failure signal emitted on success")
	_check(completed_emissions.size() == 1, "expedition_completed emitted exactly once on success")
	_check(completed_emissions[0].get("ancient_relic_fragment", 0) == gathered_count, "Completed signal payload matches extracted items")
	_check(expedition.is_active == false, "Expedition deactivated on successful extraction")

	# Verify published candidate state to SAME live inventory instance
	_check(expedition.inventory == live_inventory, "INVARIANT: expedition.inventory is the same live inventory object instance")
	_check(live_inventory.satchel_items.is_empty(), "Live satchel cleared upon successful extraction")
	_check(live_inventory.banked_items.get("ancient_relic_fragment", 0) == gathered_count, "Live bank credited with extracted fragments")

	# Test 4: Durable state on disk in ProfileStore
	var durable_inv: InventoryManager = InventoryManager.new()
	var durable_err: Error = durable_inv.load_from_store(test_store, "profile_01")
	_check(durable_err == OK, "Durable state loaded from ProfileStore")
	_check(durable_inv.banked_items.get("ancient_relic_fragment", 0) == gathered_count, "Durable state on disk has secured banked items")
	_check(durable_inv.satchel_items.is_empty(), "Durable state on disk has cleared satchel")

	# Test 5: Guard against inactive / duplicate extraction calls (no double grant or callback)
	var dup_result: Dictionary = expedition.extract_now()
	_check(dup_result.is_empty(), "Duplicate extraction request on inactive expedition rejected")
	_check(callback_state["calls"] == 2, "commit_extraction callback was NOT called again (no double callback)")
	_check(completed_emissions.size() == 1, "expedition_completed was NOT emitted again (no double grant)")
	_check(live_inventory.banked_items.get("ancient_relic_fragment", 0) == gathered_count, "Bank item count unchanged after duplicate request")

	expedition.queue_free()
	_cleanup_dir(test_root)

func _test_expedition_suspend_and_resume() -> void:
	print("--- Running SBL-P1-C Expedition Suspend & Resume Test ---")
	var expedition: DungeonExpedition = DungeonExpeditionScene.instantiate() as DungeonExpedition
	root.add_child(expedition)

	var ok: bool = expedition.setup(2026, 6)
	_check(ok == true, "Suspend test setup succeeded")

	# Advance 2 steps into dungeon
	expedition._on_advance_pressed()
	expedition._on_advance_pressed()
	_check(expedition.current_step == 2, "Advanced to chamber 3 (step 2)")

	var mid_satchel: int = expedition.inventory.satchel_items.get("ancient_relic_fragment", 0)
	var mid_bank: int = expedition.inventory.banked_items.get("ancient_relic_fragment", 0)
	_check(mid_satchel > 0, "Satchel holds fragments mid-run")

	# Suspend expedition
	var suspended_state: Dictionary = expedition.suspend_expedition()
	_check(suspended_state.get("is_active", false) == true, "Suspended state marked active")
	_check(int(suspended_state.get("current_step", -1)) == 2, "Suspended step is 2")
	_check(expedition.is_active == false, "Expedition node marked inactive after suspend")

	# Suspend does NOT count as extraction: bank is unchanged
	_check(expedition.inventory.banked_items.get("ancient_relic_fragment", 0) == mid_bank, "Bank unchanged upon suspend (not an extraction)")

	expedition.queue_free()
	await process_frame

	# Resume in new expedition instance
	var resumed_expedition: DungeonExpedition = DungeonExpeditionScene.instantiate() as DungeonExpedition
	root.add_child(resumed_expedition)

	var resume_ok: bool = resumed_expedition.restore_expedition(suspended_state)
	_check(resume_ok == true, "Expedition successfully restored from suspended state")
	_check(resumed_expedition.is_active == true, "Resumed expedition is active")
	_check(resumed_expedition.current_step == 2, "Resumed step is 2")
	_check(resumed_expedition.inventory.satchel_items.get("ancient_relic_fragment", 0) == mid_satchel, "Resumed satchel holds exact preserved fragments")

	# Continue run to extraction chamber
	while not resumed_expedition.is_at_extraction_chamber():
		resumed_expedition._on_advance_pressed()
	_check(resumed_expedition.is_at_extraction_chamber() == true, "Reached extraction chamber after resume")

	var final_satchel: int = resumed_expedition.inventory.satchel_items.get("ancient_relic_fragment", 0)
	var extracted: Dictionary = resumed_expedition.extract_now()
	_check(extracted.get("ancient_relic_fragment", 0) == final_satchel, "Extracted all fragments upon reaching portal")
	_check(resumed_expedition.inventory.banked_items.get("ancient_relic_fragment", 0) == final_satchel, "Exact-once transfer to bank verified (no double reward)")
	_check(resumed_expedition.inventory.satchel_items.is_empty(), "Satchel empty after extraction")

	resumed_expedition.queue_free()

## SBL-FIX-006: a suspend snapshot must survive a new GameRoot session, and extraction
## must clear it in the same profile write so rewards cannot be banked twice.
func _test_game_persisted_expedition_resume() -> void:
	print("--- Running SBL-FIX-006 Persisted Expedition Resume Test ---")
	var test_root: String = "user://test_dungeon_persist_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store: ProfileStore = ProfileStore.new(test_root)
	var game = preload("res://scenes/main/game_root.tscn").instantiate()
	game.profile_store = store
	root.add_child(game)
	game._init_slice_progress(store, "profile_01")
	await process_frame

	# Build a real suspended snapshot, then persist it through the GameRoot path.
	var expedition: DungeonExpedition = DungeonExpeditionScene.instantiate() as DungeonExpedition
	root.add_child(expedition)
	_check(expedition.setup(777, 6), "Persist test expedition setup")
	expedition._on_advance_pressed()
	var suspended: Dictionary = expedition.suspend_expedition()
	var satchel_count: int = expedition.inventory.satchel_items.get("ancient_relic_fragment", 0)
	expedition.queue_free()
	_check(satchel_count > 0, "Persist test gathered satchel loot")

	game._on_expedition_suspended(suspended)
	await process_frame
	var persisted: Dictionary = store.load_profile("profile_01")
	_check(persisted.get("error", ERR_UNCONFIGURED) == OK, "Persisted profile loads")
	var persisted_profile: Dictionary = persisted.get("profile", {})
	_check((persisted_profile.get("world", {}) as Dictionary).has("active_expedition"), "Suspend snapshot written to profile world")

	# A fresh session must reload the snapshot for resume.
	var resumed = preload("res://scenes/main/game_root.tscn").instantiate()
	resumed.profile_store = store
	root.add_child(resumed)
	resumed._init_slice_progress(store, "profile_01")
	await process_frame
	_check(not resumed._suspended_expedition.is_empty(), "New session reloads suspended expedition")
	_check(int(resumed._suspended_expedition.get("current_step", -1)) == 1, "Reloaded suspend step preserved")

	# Malformed snapshots must be rejected by the backup preflight validator.
	var bad_profile: Dictionary = persisted_profile.duplicate(true)
	var bad_state: Dictionary = suspended.duplicate(true)
	bad_state["satchel_items"] = {"ancient_relic_fragment": 0}
	bad_profile["world"]["active_expedition"] = bad_state
	_check(GameplayProfileValidator.validate(bad_profile) != OK, "Invalid active_expedition rejected by validator")

	# Extraction clears the snapshot atomically with the bank transfer.
	var candidate: InventoryManager = InventoryManager.new()
	candidate.deserialize(resumed.inventory_manager.serialize())
	candidate.satchel_items = suspended.get("satchel_items", {}).duplicate()
	candidate.extract_satchel_to_bank()
	var err: Error = resumed._commit_extraction(candidate)
	_check(err == OK, "Atomic extraction commit succeeded")
	var after: Dictionary = store.load_profile("profile_01")
	var after_profile: Dictionary = after.get("profile", {})
	_check(not (after_profile.get("world", {}) as Dictionary).has("active_expedition"), "Extraction clears persisted suspend snapshot")
	_check(int(after_profile["inventory"]["banked"].get("ancient_relic_fragment", 0)) == satchel_count, "Extraction banks satchel exactly once")

	# A subsequent session must not find a resumable run (no duplicate reward path).
	var fresh = preload("res://scenes/main/game_root.tscn").instantiate()
	fresh.profile_store = store
	root.add_child(fresh)
	fresh._init_slice_progress(store, "profile_01")
	await process_frame
	_check(fresh._suspended_expedition.is_empty(), "Cleared snapshot is not resumable")

	game.queue_free()
	resumed.queue_free()
	fresh.queue_free()
	await process_frame
	_cleanup_dir(test_root)

func _cleanup_dir(path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(global_path):
		var dir := DirAccess.open(global_path)
		if dir != null:
			for sub in dir.get_directories():
				var sub_dir := DirAccess.open(global_path + "/" + sub)
				if sub_dir != null:
					for f in sub_dir.get_files():
						sub_dir.remove(f)
					dir.remove(sub)
			for f in dir.get_files():
				dir.remove(f)
		DirAccess.remove_absolute(global_path)
