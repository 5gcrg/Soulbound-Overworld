extends SceneTree

## SBL-OD-010/011 owner-approved narrative & dungeon structure test suite.
## Requirements: GDD-036..048 (structure scope), GDD-061..066 (unchanged), FR-WLD-001,
## FR-QST-001, FR-DNG-001/003, TC-WLD-001, TC-DNG-001/004, TC-SAV-001.
##
## Covers:
##   OD-010 - academic MVP linearity (no branch state on the Ch I-III path), full-release
##            one-local-choice-cluster-per-chapter with gate reconvergence, branch
##            persistence, quest/profile/backup isolation, deferred reputation/faction
##            rejection at the gameplay validator and backup boundary (FR-QST-001,
##            TC-SAV-001). No narrative, dialogue, lore or educational content is asserted
##            because none was added.
##   OD-011 - academic MVP seeded DAG unchanged (guaranteed extraction), full-release
##            3-floor / 6-slot seeded connected graph with exactly one entry, exactly one
##            extraction endpoint and at least one valid route, disconnected and
##            unreachable-extraction rejection, no invented reward probabilities, and
##            dungeon mastery markers that persist as knowledge/access only
##            (FR-DNG-001/003, TC-DNG-001/004, TC-SAV-001).

const ROOT_PREFIX: String = "user://sbl_od010_011_"

var _failures: int = 0
var _checks: int = 0
var _test_root: String = ""

func _check(ok: bool, msg: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("OD-010/011 TEST FAILED: ", msg)
	return ok

func _init() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	print("--- Running SBL-OD-010/011 Narrative & Dungeon Structure Test Suite ---")
	_test_root = ROOT_PREFIX + "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store: ProfileStore = ProfileStore.new(_test_root.path_join("store"))

	_test_od010_academic_linearity(store)
	_test_od010_branch_reconverge(store)
	_test_od010_isolation_backup(store)
	_test_od011_mvp_dungeon_unchanged()
	_test_od011_multifloor_valid()
	_test_od011_reject_invalid()
	_test_od011_mastery(store)

	_cleanup_dir(_test_root)

	if _failures > 0:
		printerr("OD-010/011 TESTS FAILED: ", _failures, " / ", _checks, " checks")
		quit(1)
		return

	print("=== ALL OD-010/011 NARRATIVE & DUNGEON STRUCTURE TESTS PASSED SUCCESSFULLY (%d checks) ===" % _checks)
	quit(0)

# ==============================================================================
# OD-010 - academic MVP stays linear (FR-WLD-001, FR-QST-001)
# ==============================================================================

func _test_od010_academic_linearity(store: ProfileStore) -> void:
	print("--- OD-010 academic MVP linearity ---")
	var model: QuestBranchModel = QuestBranchModel.new()
	_check(model.mode == QuestBranchModel.MODE_ACADEMIC_MVP, "Fresh quest model starts in academic MVP mode")
	for chapter: int in range(1, QuestBranchModel.FULL_RELEASE_CHAPTERS + 1):
		_check(model.record_choice(chapter, "fixture_cluster", "fixture_branch") == ERR_UNAVAILABLE,
			"Academic MVP refuses a local choice cluster at chapter %d" % chapter)
	_check(model.reconverge_at_gate(1) == ERR_UNAVAILABLE,
		"Academic MVP refuses gate markers (no branch state on the linear path)")
	_check(model.cluster_count() == 0, "No branch state was created in academic MVP mode")
	_check(model.configure(QuestBranchModel.MODE_ACADEMIC_MVP) == OK,
		"Academic mode is accepted on an empty model")

	var serialized: Dictionary = model.serialize()
	_check(_exact_keys(serialized, QuestBranchModel.ROOT_KEYS),
		"Serialized record exposes only the approved structural keys")
	_check(not serialized.has("reputation") and not serialized.has("faction"),
		"Serialized record carries no reputation or faction field")

	# The academic chapter path itself stays linear and completion-gated (unchanged).
	var chapter_manager: ChapterManager = ChapterManager.new()
	var assessment: AssessmentController = AssessmentController.new()
	_check(chapter_manager.current_chapter == ChapterManager.CHAPTER_1, "Academic path starts at Chapter I")
	_check(not chapter_manager.can_advance_chapter(assessment),
		"Chapter advance stays completion-gated with no activity records")
	_check(chapter_manager.try_advance_chapter(assessment) == false,
		"Chapter advance is refused before the required activity completes")

	var q1: Dictionary = QuestionBank.get_question("q_dec_01")
	assessment.submit_answer("q_dec_01", int(q1["correct_index"]))
	_check(chapter_manager.try_advance_chapter(assessment) == true, "Linear advance Chapter I -> II")
	var q2: Dictionary = QuestionBank.get_question("q_res_01")
	assessment.submit_answer("q_res_01", int(q2["correct_index"]))
	_check(chapter_manager.try_advance_chapter(assessment) == true, "Linear advance Chapter II -> III")
	var q3: Dictionary = QuestionBank.get_question("q_crit_02")
	assessment.submit_answer("q_crit_02", int(q3["correct_index"]))
	_check(chapter_manager.try_advance_chapter(assessment) == true,
		"Linear advance Chapter III -> Academic MVP Complete")
	_check(chapter_manager.is_academic_complete, "Academic MVP completion unchanged")
	_check(chapter_manager.unlocked_chapters.size() == 3, "Unlocked chapters remain the linear [1, 2, 3] set")

	_check(chapter_manager.save_to_store(store, "profile_01") == OK, "Academic chapter state saved")
	var saved: Dictionary = store.load_profile("profile_01")["profile"]
	# Persist the assessment evidence so the chapter profile is validator-complete.
	saved["education"] = assessment.serialize()
	_check(store.save_profile("profile_01", saved) == OK, "Assessment records persisted with the chapter profile")
	saved = store.load_profile("profile_01")["profile"]

	_check(not (saved["world"] as Dictionary).has(QuestBranchModel.WORLD_KEY),
		"The academic chapter flow writes no quest branch record")
	_check(GameplayProfileValidator.validate(saved) == OK, "Academic profile validates with no branch record")
	_check(QuestBranchModel.validate_profile(saved) == OK, "Branch validator accepts an absent record (linear MVP)")
	_check(DungeonMastery.validate_profile(saved) == OK, "Mastery validator accepts an absent record")

	print("PASS: OD-010 academic MVP linearity verified")

# ==============================================================================
# OD-010 - full-release branch / reconverge structure and persistence
# ==============================================================================

func _test_od010_branch_reconverge(store: ProfileStore) -> void:
	print("--- OD-010 branch / reconverge structure ---")
	var model: QuestBranchModel = QuestBranchModel.new()
	_check(model.configure(QuestBranchModel.MODE_FULL_RELEASE) == OK, "Full-release mode configured")
	_check(model.configure("unknown_tier") == ERR_INVALID_PARAMETER, "Unknown mode rejected")

	_check(model.record_choice(1, "fixture_cluster_ch1", "fixture_branch_a") == OK,
		"Local choice cluster recorded for Chapter I")
	_check(model.record_choice(1, "fixture_cluster_ch1", "fixture_branch_a") == OK,
		"Identical outcome re-record is idempotent")
	_check(model.record_choice(1, "fixture_cluster_ch1_alt", "fixture_branch_b") == ERR_ALREADY_EXISTS,
		"Exactly one local choice cluster per chapter")
	_check(model.cluster_count() == 1, "No duplicate cluster record was appended")
	_check(model.record_choice(9, "fixture_cluster", "fixture_branch") == ERR_INVALID_PARAMETER,
		"Out-of-range chapter rejected")
	_check(model.record_choice(0, "fixture_cluster", "fixture_branch") == ERR_INVALID_PARAMETER,
		"Chapter zero rejected")
	_check(model.record_choice(2, "", "fixture_branch") == ERR_INVALID_PARAMETER,
		"Empty cluster identifier rejected")
	_check(model.record_choice(2, "fixture_cluster", "") == ERR_INVALID_PARAMETER,
		"Empty branch identifier rejected")

	# Reconverge at the approved chapter gate.
	_check(model.reconverge_at_gate(1) == OK, "Chapter I gate reconverges the local cluster")
	_check(model.is_reconverged(1), "Chapter I gate recorded")
	_check(bool(model.get_cluster(1)["reconverged"]) == true, "Cluster flagged reconverged at the gate")
	_check(model.record_choice(1, "fixture_cluster_ch1", "fixture_branch_c") == ERR_UNAVAILABLE,
		"Gate freezes Chapter I: no new local choice after reconvergence")
	_check(model.reconverge_at_gate(1) == ERR_ALREADY_EXISTS, "Gate reconvergence happens exactly once")
	_check(model.reconverge_at_gate(99) == ERR_INVALID_PARAMETER, "Out-of-range gate rejected")

	# Local branch state stays local to its own chapter.
	_check(model.record_choice(2, "fixture_cluster_ch2", "fixture_branch_x") == OK,
		"Chapter II opens its own local cluster after the Chapter I gate")
	_check(String(model.get_cluster(1)["branch_id"]) == "fixture_branch_a",
		"Chapter I outcome unchanged by later local choices")
	_check(model.reconverge_at_gate(2) == OK, "Chapter II gate reconverges its own cluster")
	_check(model.cluster_count() == 2, "One local cluster per chapter, stored separately")
	_check(String(model.get_cluster(3)["branch_id"]) == "", "Chapter III carries no cluster yet")

	# Persistence: save/reload retains the exact selected quest outcomes (FR-QST-001).
	_check(model.save_to_store(store, "profile_02") == OK, "Branch state saved to profile_02")
	var reloaded: QuestBranchModel = QuestBranchModel.new()
	_check(reloaded.load_from_store(store, "profile_02") == OK, "Branch state reloaded")
	_check(reloaded.mode == QuestBranchModel.MODE_FULL_RELEASE, "Mode persisted")
	_check(reloaded.cluster_count() == 2, "Both cluster records persisted")
	_check(String(reloaded.get_cluster(1)["branch_id"]) == "fixture_branch_a"
		and String(reloaded.get_cluster(2)["branch_id"]) == "fixture_branch_x",
		"Save/reload retains the exact selected quest outcomes (FR-QST-001)")
	_check(reloaded.is_reconverged(1) and reloaded.is_reconverged(2), "Gate reconvergence persisted")
	_check(JSON.stringify(reloaded.serialize()) == JSON.stringify(model.serialize()),
		"Serialize -> store -> load -> serialize round trip is byte-identical")

	# The academic MVP mode can never hold branch state.
	_check(model.configure(QuestBranchModel.MODE_ACADEMIC_MVP) == ERR_INVALID_DATA,
		"Academic MVP refuses a model that already carries branch state")
	_check(model.mode == QuestBranchModel.MODE_FULL_RELEASE, "Failed mode switch changes nothing")

	# Strict structural rejections (deferred systems and malformed records).
	var bad: Dictionary = model.serialize()
	bad["reputation"] = 25
	_check(QuestBranchModel.validate_record(bad) != OK, "Unknown top-level key rejected")

	bad = model.serialize()
	var bad_clusters: Array = [{
		"chapter": 1, "cluster_id": "fixture", "branch_id": "fixture",
		"reconverged": true, "reputation": 50,
	}]
	bad["clusters"] = bad_clusters
	_check(QuestBranchModel.validate_record(bad) != OK, "Deferred reputation field rejected")

	bad = model.serialize()
	bad_clusters = [{
		"chapter": 1, "cluster_id": "fixture", "branch_id": "fixture",
		"reconverged": true, "faction": "unused",
	}]
	bad["clusters"] = bad_clusters
	_check(QuestBranchModel.validate_record(bad) != OK, "Deferred faction field rejected")

	# reconverged flag must match the recorded gate list in both directions.
	bad = model.serialize()
	var cluster_list: Array = bad["clusters"]
	var first_cluster: Dictionary = cluster_list[0]
	first_cluster["reconverged"] = false
	_check(QuestBranchModel.validate_record(bad) != OK,
		"Cluster not marked reconverged while its gate is recorded -> invalid")

	bad = model.serialize()
	bad["reconverged_chapters"] = [3]
	_check(QuestBranchModel.validate_record(bad) != OK,
		"Gate list inconsistent with cluster reconverged flags -> invalid")

	bad = model.serialize()
	bad_clusters = [
		{"chapter": 1, "cluster_id": "a", "branch_id": "x", "reconverged": true},
		{"chapter": 1, "cluster_id": "b", "branch_id": "y", "reconverged": true},
	]
	bad["clusters"] = bad_clusters
	bad["reconverged_chapters"] = [1, 2]
	_check(QuestBranchModel.validate_record(bad) != OK, "Two clusters for one chapter rejected")

	bad = model.serialize()
	bad["mode"] = QuestBranchModel.MODE_ACADEMIC_MVP
	bad["clusters"] = []
	bad["reconverged_chapters"] = []
	_check(QuestBranchModel.validate_record(bad) == OK, "Empty academic record accepted")
	bad["reconverged_chapters"] = [1]
	_check(QuestBranchModel.validate_record(bad) != OK,
		"Academic record with gate markers rejected (MVP stays linear)")
	_check(QuestBranchModel.validate_record("not a dictionary") != OK, "Non-dictionary record rejected")

	print("PASS: OD-010 branch/reconverge structure and persistence verified")

# ==============================================================================
# OD-010 - quest / profile / backup isolation (TC-SAV-001)
# ==============================================================================

func _test_od010_isolation_backup(store: ProfileStore) -> void:
	print("--- OD-010 quest / profile / backup isolation ---")
	var profile_01: Dictionary = store.load_profile("profile_01")["profile"]
	var profile_02: Dictionary = store.load_profile("profile_02")["profile"]
	_check(not (profile_01["world"] as Dictionary).has(QuestBranchModel.WORLD_KEY),
		"Academic slot carries no branch record")
	_check((profile_02["world"] as Dictionary).has(QuestBranchModel.WORLD_KEY),
		"Branch slot carries its branch record")
	_check(GameplayProfileValidator.validate(profile_01) == OK, "Academic slot validates")
	_check(GameplayProfileValidator.validate(profile_02) == OK, "Branch slot validates")

	# Independent slot with no branch state.
	var empty_slot: Dictionary = store.new_profile("profile_03")
	_check(store.save_profile("profile_03", empty_slot) == OK, "Independent empty slot saved")
	var fresh: QuestBranchModel = QuestBranchModel.new()
	_check(fresh.load_from_store(store, "profile_03") == OK, "Empty slot loads as an empty branch model")
	_check(fresh.cluster_count() == 0, "No branch state leaks into the independent slot (TC-SAV-001)")

	# Backup round trip retains the exact quest outcome.
	var exported: Dictionary = store.export_backup("profile_02")
	_check(exported["error"] == OK, "Branch profile exported")
	_check(store.import_backup("profile_03", String(exported["text"]), GameplayProfileValidator.validate) == OK,
		"Validated backup import accepts the branch record")
	var imported: QuestBranchModel = QuestBranchModel.new()
	_check(imported.load_from_store(store, "profile_03") == OK, "Imported branch record loads")
	_check(String(imported.get_cluster(1)["branch_id"]) == "fixture_branch_a"
		and String(imported.get_cluster(2)["branch_id"]) == "fixture_branch_x",
		"Backup round trip retains the exact selected quest outcomes")
	_check(imported.is_reconverged(1) and imported.is_reconverged(2),
		"Backup round trip retains gate reconvergence")

	# Deferred reputation/faction data is rejected at the backup boundary (zero mutation).
	var before: String = String(store.export_backup("profile_03")["text"])

	var tampered: Dictionary = JSON.parse_string(String(exported["text"])) as Dictionary
	var tampered_world: Dictionary = tampered["world"] as Dictionary
	var tampered_record: Dictionary = tampered_world[QuestBranchModel.WORLD_KEY]
	tampered_record["reputation"] = 50
	tampered_world[QuestBranchModel.WORLD_KEY] = tampered_record
	_check(store.import_backup("profile_03", JSON.stringify(tampered), GameplayProfileValidator.validate) != OK,
		"Backup carrying a deferred reputation field is rejected")
	_check(String(store.export_backup("profile_03")["text"]) == before,
		"Rejected backup leaves the target slot byte-identical")
	_check(GameplayProfileValidator.validate(tampered) != OK,
		"Gameplay validator rejects the reputation-tampered profile")

	tampered = JSON.parse_string(String(exported["text"])) as Dictionary
	tampered_world = tampered["world"] as Dictionary
	tampered_record = tampered_world[QuestBranchModel.WORLD_KEY]
	tampered_record["faction"] = "unused_faction"
	tampered_world[QuestBranchModel.WORLD_KEY] = tampered_record
	_check(store.import_backup("profile_03", JSON.stringify(tampered), GameplayProfileValidator.validate) != OK,
		"Backup carrying a deferred faction field is rejected")
	_check(String(store.export_backup("profile_03")["text"]) == before,
		"Second rejected backup also leaves the target slot byte-identical")

	# Slot isolation after every rejection.
	var after_profile_01: Dictionary = store.load_profile("profile_01")["profile"]
	var after_profile_02: Dictionary = store.load_profile("profile_02")["profile"]
	_check(not (after_profile_01["world"] as Dictionary).has(QuestBranchModel.WORLD_KEY)
		and (after_profile_02["world"] as Dictionary).has(QuestBranchModel.WORLD_KEY),
		"Profile slots stay isolated through import rejections (TC-SAV-001)")

	print("PASS: OD-010 quest/profile/backup isolation verified")

# ==============================================================================
# OD-011 - academic MVP dungeon generator unchanged (TC-DNG-001)
# ==============================================================================

func _test_od011_mvp_dungeon_unchanged() -> void:
	print("--- OD-011 academic MVP dungeon unchanged ---")
	var first: DungeonGenerator = DungeonGenerator.new()
	_check(first.generate(1337, 6) == true, "Academic MVP seeded DAG generation still succeeds")
	_check(first.is_valid, "Academic MVP generator still marks the layout valid (guaranteed extraction)")
	_check(first.rooms.size() == 6, "Academic MVP room count behavior unchanged")

	var second: DungeonGenerator = DungeonGenerator.new()
	_check(second.generate(1337, 6) == true, "Same seed reproduces the MVP layout")
	_check(JSON.stringify(first.serialize_expedition_state()) == JSON.stringify(second.serialize_expedition_state()),
		"MVP generator determinism unchanged (TC-DNG-001)")

	_check(_count_type(first.rooms, DungeonGenerator.TYPE_SPAWN) == 1, "MVP layout keeps exactly one entry")
	_check(_count_type(first.rooms, DungeonGenerator.TYPE_EXTRACTION) == 1,
		"MVP layout keeps exactly one extraction endpoint")
	_check(_count_type(first.rooms, DungeonGenerator.TYPE_COMBAT) > 0, "MVP encounter rooms retained")
	_check(_count_type(first.rooms, DungeonGenerator.TYPE_NORMAL) > 0, "MVP treasure rooms retained")
	_check(_mvp_reachable(first), "MVP extraction remains reachable from spawn (TC-DNG-001)")

	var default_gen: DungeonGenerator = DungeonGenerator.new()
	_check(default_gen.generate(20261111) == true and default_gen.rooms.size() == 6,
		"MVP default room count (6) unchanged")
	_check(not first.serialize_expedition_state().has("floors"),
		"MVP expedition state carries no multi-floor structure")

	print("PASS: OD-011 academic MVP dungeon generation unchanged")

# ==============================================================================
# OD-011 - full-release 3-floor / 6-slot seeded connected layouts
# ==============================================================================

func _test_od011_multifloor_valid() -> void:
	print("--- OD-011 full-release 3-floor / 6-slot structure ---")
	_check(MultiFloorLayout.FLOOR_COUNT == 3, "Owner-approved floor count is 3")
	_check(MultiFloorLayout.ROOMS_PER_FLOOR == 6, "Owner-approved room slots per floor is 6")
	_check(MultiFloorLayout.ROOM_TOTAL == 18, "18 generated room slots in total")

	var probe: MultiFloorLayout = MultiFloorLayout.new()
	_check(probe.generate(1337) == true, "Seed 1337 produces a valid layout")
	var layout: Dictionary = probe.layout
	_check(MultiFloorLayout.validate_layout(layout) == OK, "Generated layout validates (FR-DNG-001)")
	_check((layout["floors"] as Array).size() == MultiFloorLayout.FLOOR_COUNT, "Exactly 3 floors")

	var total_rooms: int = 0
	for floor_value: Variant in (layout["floors"] as Array):
		var floor_data: Dictionary = floor_value as Dictionary
		var rooms: Array = floor_data["rooms"] as Array
		_check(rooms.size() == MultiFloorLayout.ROOMS_PER_FLOOR,
			"Floor %d holds exactly 6 room slots" % int(floor_data["floor"]))
		total_rooms += rooms.size()
	_check(total_rooms == MultiFloorLayout.ROOM_TOTAL, "18 generated room slots in total")

	var entry_id: int = int(layout["entry_id"])
	var extraction_id: int = int(layout["extraction_id"])
	_check(_layout_type_count(layout, DungeonGenerator.TYPE_SPAWN) == 1, "Exactly one entry room")
	_check(_layout_type_count(layout, DungeonGenerator.TYPE_EXTRACTION) == 1, "Exactly one extraction endpoint")
	_check(entry_id != extraction_id, "Entry and extraction are distinct")
	var route: Array[int] = MultiFloorLayout.find_route(layout, entry_id, extraction_id)
	_check(route.size() >= 2 and route[0] == entry_id and route[route.size() - 1] == extraction_id,
		"At least one valid route runs from the entry to the extraction endpoint")
	_check(_layout_reachable(layout), "Every room is reachable from the entry (connected graph)")
	_check(_layout_types_approved(layout), "Only existing approved room types are used")
	_check(_layout_no_risk_flags(layout), "Generated layouts flag no risk rooms (no invented reward probability)")

	# Seeded sweep: every seed must yield a connected, extraction-reachable layout.
	var seeds: Array[int] = [0, 1, -1, 42, 1337, 999983, 20261111, 123456789]
	for seed_value: int in seeds:
		var gen: MultiFloorLayout = MultiFloorLayout.new()
		_check(gen.generate(seed_value) == true and MultiFloorLayout.validate_layout(gen.layout) == OK,
			"Seed %d yields a valid connected layout" % seed_value)
	for offset: int in range(64):
		var sweep_seed: int = 1000 + offset
		var sweep_gen: MultiFloorLayout = MultiFloorLayout.new()
		_check(sweep_gen.generate(sweep_seed) == true and MultiFloorLayout.validate_layout(sweep_gen.layout) == OK,
			"Seeded sweep seed %d is connected with a reachable extraction" % sweep_seed)

	# Determinism and persistence shape.
	var a: MultiFloorLayout = MultiFloorLayout.new()
	var b: MultiFloorLayout = MultiFloorLayout.new()
	_check(a.generate(1337) and b.generate(1337), "Both determinism probes generated")
	_check(JSON.stringify(a.layout) == JSON.stringify(b.layout),
		"Same seed reproduces the identical layout (FR-DNG-001)")
	var c: MultiFloorLayout = MultiFloorLayout.new()
	c.generate(4242)
	_check(JSON.stringify(a.layout) != JSON.stringify(c.layout), "Different seeds diverge")
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(a.layout))
	_check(typeof(roundtrip) == TYPE_DICTIONARY and MultiFloorLayout.validate_layout(roundtrip) == OK,
		"Layout survives a JSON round trip (persistence shape)")

	print("PASS: OD-011 multi-floor seeded connected layouts verified")

# ==============================================================================
# OD-011 - invalid graph rejection (disconnected / unreachable extraction)
# ==============================================================================

func _test_od011_reject_invalid() -> void:
	print("--- OD-011 invalid graph rejection ---")
	var baseline: MultiFloorLayout = MultiFloorLayout.new()
	_check(baseline.generate(1337) == true, "Baseline valid layout generated")
	var baseline_text: String = JSON.stringify(baseline.layout)
	var entry_id: int = int(baseline.layout["entry_id"])
	var extraction_id: int = int(baseline.layout["extraction_id"])

	# 1. Disconnected graph: cut the inter-floor link so a floor falls off the route.
	var broken: Dictionary = _deep(baseline.layout)
	var link: Array = _find_cross_floor_edge(broken)
	_check(link.size() == 2, "Found an inter-floor link to cut")
	if link.size() == 2:
		_remove_edge(broken, int(link[0]), int(link[1]))
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Disconnected graph rejected")
	_check(MultiFloorLayout.find_route(broken, entry_id, extraction_id).is_empty(),
		"Disconnected layout reports no valid route (unreachable extraction)")

	# 2. Isolate the extraction room entirely.
	broken = _deep(baseline.layout)
	_isolate_room(broken, extraction_id)
	_check(MultiFloorLayout.validate_layout(broken) != OK,
		"Unreachable extraction endpoint rejected (TC-DNG-001)")

	# 3. Wrong floor count.
	broken = _deep(baseline.layout)
	var floors_arr: Array = broken["floors"]
	floors_arr.pop_back()
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Wrong floor count rejected")

	# 4. Wrong room-slot count on one floor.
	broken = _deep(baseline.layout)
	floors_arr = broken["floors"]
	var first_floor: Dictionary = floors_arr[0]
	var rooms_arr: Array = first_floor["rooms"]
	rooms_arr.pop_back()
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Wrong room-slot count rejected")

	# 5. Duplicate room id.
	broken = _deep(baseline.layout)
	floors_arr = broken["floors"]
	var second_floor: Dictionary = floors_arr[1]
	rooms_arr = second_floor["rooms"]
	var room_copy: Dictionary = rooms_arr[0]
	room_copy["id"] = 0
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Duplicate room id rejected")

	# 6. Unknown room type (no new room type may be invented).
	broken = _deep(baseline.layout)
	var target: Dictionary = _room_by_id(broken, _first_room_of_type(broken, DungeonGenerator.TYPE_NORMAL))
	target["type"] = "treasure"
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Unknown room type rejected")

	# 7. Two extraction endpoints.
	broken = _deep(baseline.layout)
	target = _room_by_id(broken, _first_room_of_type(broken, DungeonGenerator.TYPE_NORMAL))
	target["type"] = DungeonGenerator.TYPE_EXTRACTION
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Two extraction endpoints rejected")

	# 8. No extraction endpoint.
	broken = _deep(baseline.layout)
	target = _room_by_id(broken, extraction_id)
	target["type"] = DungeonGenerator.TYPE_NORMAL
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Missing extraction endpoint rejected")

	# 9. Entry pointing at a non-spawn room.
	broken = _deep(baseline.layout)
	broken["entry_id"] = 5
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Entry id not matching the spawn room rejected")

	# 10. Risk flag on a terminal room (risk only fits existing reward-path rooms).
	broken = _deep(baseline.layout)
	target = _room_by_id(broken, _first_room_of_type(broken, DungeonGenerator.TYPE_SPAWN))
	target["risk"] = true
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Risk flag on the entry room rejected")
	broken = _deep(baseline.layout)
	target = _room_by_id(broken, extraction_id)
	target["risk"] = true
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Risk flag on the extraction room rejected")

	# 11. Invented probability / reward fields are structurally invalid.
	broken = _deep(baseline.layout)
	broken["drop_rate"] = 0.25
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Invented root drop probability rejected")
	broken = _deep(baseline.layout)
	floors_arr = broken["floors"]
	first_floor = floors_arr[0]
	rooms_arr = first_floor["rooms"]
	room_copy = rooms_arr[0]
	room_copy["loot_chance"] = 0.5
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Invented room loot probability rejected")

	# 12. Malformed edges: self loop, missing id, asymmetric link.
	broken = _deep(baseline.layout)
	target = _room_by_id(broken, entry_id)
	(target["neighbors"] as Array).append(entry_id)
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Self loop rejected")
	broken = _deep(baseline.layout)
	target = _room_by_id(broken, entry_id)
	(target["neighbors"] as Array).append(999)
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Neighbor id without a room rejected")
	broken = _deep(baseline.layout)
	_check(_add_asymmetric_link(broken) == true, "Asymmetric link fixture created")
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Asymmetric neighbor link rejected")

	# 13. Schema and payload shape.
	broken = _deep(baseline.layout)
	broken["schema"] = "sbl-multi-floor-layout/9"
	_check(MultiFloorLayout.validate_layout(broken) != OK, "Unknown schema id rejected")
	_check(MultiFloorLayout.validate_layout([]) != OK, "Non-dictionary payload rejected")
	_check(MultiFloorLayout.validate_layout(null) != OK, "Null payload rejected")

	# Zero mutation: every rejection above must leave the source layout untouched.
	_check(JSON.stringify(baseline.layout) == baseline_text,
		"Rejected validations never mutate the source layout")

	print("PASS: OD-011 disconnected / unreachable graph rejection verified")

# ==============================================================================
# OD-011 - dungeon mastery as knowledge/access markers only
# ==============================================================================

func _test_od011_mastery(store: ProfileStore) -> void:
	print("--- OD-011 dungeon mastery markers ---")
	var mastery: DungeonMastery = DungeonMastery.new()
	_check(mastery.marker_count() == 0, "Fresh mastery record is empty")
	_check(mastery.grant_marker("") == ERR_INVALID_PARAMETER, "Empty marker id rejected")
	_check(mastery.grant_marker("x".repeat(DungeonMastery.MAX_MARKER_ID_LENGTH + 1)) == ERR_INVALID_PARAMETER,
		"Oversized marker id rejected")
	_check(mastery.grant_marker("fixture_access_marker") == OK, "Knowledge/access marker granted")
	_check(mastery.has_marker("fixture_access_marker"), "Marker query works")
	_check(mastery.grant_marker("fixture_access_marker") == OK and mastery.marker_count() == 1,
		"Granting is idempotent - no duplicate marker")

	var serialized: Dictionary = mastery.serialize()
	_check(_exact_keys(serialized, ["schema", "markers"]),
		"Mastery record exposes only schema + markers (knowledge/access only)")
	_check(not serialized.has("power") and not serialized.has("attack") and not serialized.has("level"),
		"Mastery record carries no combat-power field")

	# Marker grants never touch combat power.
	var stats: CharacterStats = CharacterStats.new()
	var stats_before: String = JSON.stringify(stats.serialize())
	_check(mastery.grant_marker("fixture_knowledge_marker") == OK, "Second marker granted")
	_check(JSON.stringify(stats.serialize()) == stats_before,
		"Marker grants leave CharacterStats byte-identical (no uncapped combat power)")

	# Persistence alongside permanent character state.
	var current: Dictionary = store.load_profile("profile_01")["profile"]
	current["character"]["level"] = 7
	current["character"]["xp"] = 350
	current["character"]["vitality"] = 14
	_check(store.save_profile("profile_01", current) == OK, "Permanent character state seeded (test fixture)")
	var character_before: String = JSON.stringify((store.load_profile("profile_01")["profile"])["character"])

	_check(mastery.save_to_store(store, "profile_01") == OK, "Mastery record saved alongside permanent state")
	var reloaded: DungeonMastery = DungeonMastery.new()
	_check(reloaded.load_from_store(store, "profile_01") == OK, "Mastery record reloaded")
	_check(reloaded.has_marker("fixture_access_marker") and reloaded.has_marker("fixture_knowledge_marker"),
		"Knowledge/access markers persist across save/load")

	var after_profile: Dictionary = store.load_profile("profile_01")["profile"]
	_check(JSON.stringify(after_profile["character"]) == character_before,
		"Mastery grants never change combat power / character stats")
	_check(GameplayProfileValidator.validate(after_profile) == OK, "Profile with mastery record validates")
	_check(QuestBranchModel.validate_profile(after_profile) == OK,
		"Chapter/branch validation unaffected by the mastery write")

	# Validator boundary: only knowledge/access markers are accepted.
	var template: Dictionary = store.new_profile("profile_03")
	var template_world: Dictionary = template["world"] as Dictionary
	template_world[DungeonMastery.WORLD_KEY] = mastery.serialize()
	template["world"] = template_world
	_check(GameplayProfileValidator.validate(template) == OK, "Valid mastery record accepted")

	var power_payload: Dictionary = mastery.serialize()
	power_payload["power"] = 999
	template_world = template["world"] as Dictionary
	template_world[DungeonMastery.WORLD_KEY] = power_payload
	_check(GameplayProfileValidator.validate(template) != OK,
		"Combat-power field inside the mastery record rejected")

	var non_string_payload: Dictionary = mastery.serialize()
	non_string_payload["markers"] = [123]
	template_world = template["world"] as Dictionary
	template_world[DungeonMastery.WORLD_KEY] = non_string_payload
	_check(GameplayProfileValidator.validate(template) != OK, "Non-string marker rejected")

	var duplicate_payload: Dictionary = {
		"schema": DungeonMastery.SCHEMA_ID,
		"markers": ["fixture_access_marker", "fixture_access_marker"],
	}
	template_world = template["world"] as Dictionary
	template_world[DungeonMastery.WORLD_KEY] = duplicate_payload
	_check(GameplayProfileValidator.validate(template) != OK, "Duplicate marker rejected")

	# Slot isolation: mastery lives only in the slot that earned it.
	var other_slot: Dictionary = store.load_profile("profile_03")["profile"]
	_check(not (other_slot["world"] as Dictionary).has(DungeonMastery.WORLD_KEY),
		"Mastery record stays inside its own profile slot (TC-SAV-001)")
	_check(GameplayProfileValidator.validate(other_slot) == OK, "Slot without mastery record validates")

	print("PASS: OD-011 dungeon mastery knowledge/access markers verified")

# ==============================================================================
# Helpers
# ==============================================================================

func _exact_keys(d: Dictionary, keys: Array) -> bool:
	if d.size() != keys.size():
		return false
	for key: Variant in keys:
		if not d.has(key):
			return false
	return true

func _count_type(rooms: Array, room_type: String) -> int:
	var count: int = 0
	for room: Dictionary in rooms:
		if String(room.get("type", "")) == room_type:
			count += 1
	return count

func _mvp_reachable(gen: DungeonGenerator) -> bool:
	var adjacency: Dictionary = {}
	for room: Dictionary in gen.rooms:
		adjacency[int(room["id"])] = room.get("neighbors", [])
	var visited: Dictionary = {gen.spawn_id: true}
	var queue: Array[int] = [gen.spawn_id]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == gen.extraction_id:
			return true
		for neighbor: Variant in adjacency.get(current, []):
			var neighbor_id: int = int(neighbor)
			if adjacency.has(neighbor_id) and not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)
	return false

func _all_rooms(layout: Dictionary) -> Array:
	var rooms: Array = []
	var floors_value: Variant = layout.get("floors", [])
	if typeof(floors_value) != TYPE_ARRAY:
		return rooms
	for floor_value: Variant in (floors_value as Array):
		if typeof(floor_value) != TYPE_DICTIONARY:
			continue
		var rooms_value: Variant = (floor_value as Dictionary).get("rooms", [])
		if typeof(rooms_value) != TYPE_ARRAY:
			continue
		for room_value: Variant in (rooms_value as Array):
			if typeof(room_value) == TYPE_DICTIONARY:
				rooms.append(room_value)
	return rooms

func _room_by_id(layout: Dictionary, room_id: int) -> Dictionary:
	for room_value: Variant in _all_rooms(layout):
		var room: Dictionary = room_value
		if int(room.get("id", -1)) == room_id:
			return room
	return {}

func _layout_type_count(layout: Dictionary, room_type: String) -> int:
	var count: int = 0
	for room_value: Variant in _all_rooms(layout):
		if String((room_value as Dictionary).get("type", "")) == room_type:
			count += 1
	return count

func _layout_reachable(layout: Dictionary) -> bool:
	var adjacency: Dictionary = {}
	for room_value: Variant in _all_rooms(layout):
		var room: Dictionary = room_value
		adjacency[int(room["id"])] = room.get("neighbors", [])
	var start: int = int(layout.get("entry_id", -1))
	if not adjacency.has(start):
		return false
	var visited: Dictionary = {start: true}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor: Variant in adjacency.get(current, []):
			var neighbor_id: int = int(neighbor)
			if adjacency.has(neighbor_id) and not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)
	return visited.size() == adjacency.size()

func _layout_types_approved(layout: Dictionary) -> bool:
	var approved: Dictionary = {
		DungeonGenerator.TYPE_SPAWN: true,
		DungeonGenerator.TYPE_NORMAL: true,
		DungeonGenerator.TYPE_COMBAT: true,
		DungeonGenerator.TYPE_EXTRACTION: true,
	}
	for room_value: Variant in _all_rooms(layout):
		if not approved.has(String((room_value as Dictionary).get("type", ""))):
			return false
	return true

func _layout_no_risk_flags(layout: Dictionary) -> bool:
	for room_value: Variant in _all_rooms(layout):
		if bool((room_value as Dictionary).get("risk", false)):
			return false
	return true

func _first_room_of_type(layout: Dictionary, room_type: String) -> int:
	for room_value: Variant in _all_rooms(layout):
		var room: Dictionary = room_value
		if String(room.get("type", "")) == room_type:
			return int(room["id"])
	return -1

func _find_cross_floor_edge(layout: Dictionary) -> Array:
	var rooms: Array = _all_rooms(layout)
	for a_value: Variant in rooms:
		var a: Dictionary = a_value
		var neighbors: Array = a["neighbors"] as Array
		for neighbor_value: Variant in neighbors:
			var b: Dictionary = _room_by_id(layout, int(neighbor_value))
			if not b.is_empty() and int(b["floor"]) != int(a["floor"]):
				return [int(a["id"]), int(neighbor_value)]
	return []

func _remove_edge(layout: Dictionary, a: int, b: int) -> void:
	var room_a: Dictionary = _room_by_id(layout, a)
	var room_b: Dictionary = _room_by_id(layout, b)
	if room_a.is_empty() or room_b.is_empty():
		return
	(room_a["neighbors"] as Array).erase(b)
	(room_b["neighbors"] as Array).erase(a)

func _isolate_room(layout: Dictionary, room_id: int) -> void:
	var room: Dictionary = _room_by_id(layout, room_id)
	if room.is_empty():
		return
	var snapshot: Array = (room["neighbors"] as Array).duplicate()
	for neighbor_value: Variant in snapshot:
		_remove_edge(layout, room_id, int(neighbor_value))

func _add_asymmetric_link(layout: Dictionary) -> bool:
	var rooms: Array = _all_rooms(layout)
	for a_value: Variant in rooms:
		var a: Dictionary = a_value
		var a_neighbors: Array = a["neighbors"] as Array
		for b_value: Variant in rooms:
			var b: Dictionary = b_value
			var a_id: int = int(a["id"])
			var b_id: int = int(b["id"])
			if a_id == b_id:
				continue
			if a_neighbors.has(b_id):
				continue
			if (b["neighbors"] as Array).has(a_id):
				continue
			a_neighbors.append(b_id)
			return true
	return false

func _deep(value: Dictionary) -> Dictionary:
	return value.duplicate(true)

func _remove_recursive(global_path: String) -> void:
	var dir: DirAccess = DirAccess.open(global_path)
	if dir == null:
		return
	var subs: PackedStringArray = dir.get_directories()
	var files: PackedStringArray = dir.get_files()
	dir = null # release the handle before deleting on Windows
	for sub: String in subs:
		_remove_recursive(global_path.path_join(sub))
	for fname: String in files:
		DirAccess.remove_absolute(global_path.path_join(fname))
	DirAccess.remove_absolute(global_path)

func _cleanup_dir(path: String) -> void:
	if not path.begins_with(ROOT_PREFIX):
		return
	_remove_recursive(ProjectSettings.globalize_path(path))
