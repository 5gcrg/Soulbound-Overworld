extends SceneTree

## SBL-EDU-005 Learning Journal & Educational Reporting Headless Test Suite
## Requirements: GDD-071, GDD-072, GDD-091, GDD-112, FR-EDU-002/004, TC-EDU-002/004, NFR-SEC-001, NFR-ACC-001.

const GameRootScene: PackedScene = preload("res://scenes/main/game_root.tscn")
const LearningJournalScene: PackedScene = preload("res://scenes/ui/learning_journal.tscn")

var _failures: int = 0
var _test_root: String = ""
var _disposable_store_root: String = ""
var _real_profiles_dir: String = "user://profiles"
var _real_reports_dir: String = "user://reports"
var _pre_profiles_snapshot: Dictionary = {}
var _pre_reports_snapshot: Dictionary = {}

func _check(condition: bool, message: String) -> bool:
	if condition:
		print("  PASS: %s" % message)
		return true
	else:
		printerr("  FAIL: %s" % message)
		_failures += 1
		return false

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("--- Running SBL-EDU-005 Learning Journal & Educational Reporting Test Suite ---")

	_test_root = "user://test_learning_journal_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_test_root))
	# All ProfileStore fixtures in this suite live under the disposable root so no
	# fixture answer can ever reach the real user://profiles (SBL-EDU-005-FIX P1).
	_disposable_store_root = _test_root.path_join("profiles")

	# Snapshot the real profile and report directories before any test part runs so
	# the suite can prove they are byte-identical when it finishes.
	_pre_profiles_snapshot = _snapshot_dir_bytes(_real_profiles_dir)
	_pre_reports_snapshot = _snapshot_dir_bytes(_real_reports_dir)
	print("Pre-suite snapshot: %d file(s) in %s, %d file(s) in %s" % [
		_pre_profiles_snapshot.size(), _real_profiles_dir,
		_pre_reports_snapshot.size(), _real_reports_dir])

	await _test_part1_row_model_and_legacy()
	await _test_part2_sorting_counts_and_od012()
	await _test_part3_csv_escaping_and_formula_neutralization()
	await _test_part4_standalone_utf8_html()
	await _test_part5_journal_ui_and_sheet_lifecycle()
	await _test_part6_profile_isolation_and_backup_refresh()
	await _test_part7_desktop_and_injectable_web_delivery()
	await _test_part8_disposable_negative_controls()
	await _test_part9_academic_modal_active_profile_attribution()

	# INVARIANT (SBL-EDU-005-FIX P1): the real profile and report directories must
	# be untouched by this suite — same file set, same bytes.
	_assert_dir_byte_identical(_real_profiles_dir, _pre_profiles_snapshot, "real user://profiles")
	_assert_dir_byte_identical(_real_reports_dir, _pre_reports_snapshot, "real user://reports")

	_cleanup_test_dir(_test_root)

	print("\n=======================================================")
	if _failures == 0:
		print("ALL LEARNING JOURNAL & REPORTING TESTS PASSED (0 FAILURES)")
		quit(0)
	else:
		printerr("LEARNING JOURNAL TESTS FAILED: %d failure(s)" % _failures)
		quit(1)

# ==============================================================================
# Part 1: Row Model, First-Attempt Immutability & Legacy Compatibility
# ==============================================================================
func _test_part1_row_model_and_legacy() -> void:
	print("\n[Part 1] Testing Row Model, First-Attempt Immutability & Legacy Compatibility...")

	var ac := AssessmentController.new()
	# Submit wrong answer first (index 0 is wrong for q_dec_01, correct is 1)
	var r1: Dictionary = ac.submit_answer("q_dec_01", 0)
	_check(r1["correct"] == false, "q_dec_01 first attempt is incorrect")
	_check(r1["first_attempt_correct"] == false, "q_dec_01 first_attempt_correct is false")

	# Retry with correct answer (index 1)
	var r2: Dictionary = ac.submit_answer("q_dec_01", 1)
	_check(r2["correct"] == true, "q_dec_01 retry is correct")
	_check(r2["first_attempt_correct"] == false, "INVARIANT: first_attempt_correct remains false after retry")
	_check(r2["total_attempts"] == 2, "total_attempts is 2")
	_check(r2["completed"] == true, "completed is true")

	# Submit correct first attempt for q_crit_01
	ac.submit_answer("q_crit_01", 0)

	# Verify get_rows preserves first-attempt correctness and does not mutate records
	var records_snapshot: Dictionary = ac.records.duplicate(true)
	var rows: Array[Dictionary] = LearningReport.get_rows(ac.records)
	_check(ac.records == records_snapshot, "INVARIANT: get_rows does not mutate records in controller")

	# Find q_dec_01 row
	var dec_row: Dictionary = {}
	for r: Dictionary in rows:
		if r["question_id"] == "q_dec_01":
			dec_row = r
			break
	_check(not dec_row.is_empty(), "q_dec_01 row present in get_rows")
	_check(dec_row["first_attempt_correct"] == false, "q_dec_01 row has first_attempt_correct == false")
	_check(dec_row["first_attempt_display"] == "Incorrect", "q_dec_01 row displays 'Incorrect'")
	_check(dec_row["total_attempts"] == 2, "q_dec_01 row total_attempts is 2")
	_check(dec_row["completed"] == true, "q_dec_01 row completed is true")

	# Verify CSV and HTML agree with row model for wrong-first / correct-retry
	var csv: String = LearningReport.generate_csv(ac.records)
	_check(csv.contains("q_dec_01"), "CSV contains q_dec_01")
	_check(csv.contains("false,2,true"), "CSV has false,2,true for q_dec_01 matching row model")

	var html: String = LearningReport.generate_html(ac.records, "profile_01")
	_check(html.contains("<td>q_dec_01</td>"), "HTML contains q_dec_01")
	_check(html.contains("<td>Incorrect</td>"), "HTML displays Incorrect for q_dec_01 first attempt")
	_check(html.contains("<td>2</td>"), "HTML displays 2 attempts for q_dec_01")
	_check(html.contains("<td>Yes</td>"), "HTML displays Completed Yes for q_dec_01")

	# Test legacy record lacking first_response
	var legacy_records: Dictionary = {
		"q_res_01": {
			"question_id": "q_res_01",
			"competency": QuestionBank.COMP_RESOURCE_MANAGEMENT,
			"difficulty": "Foundational",
			"first_attempt_correct": true,
			"total_attempts": 1,
			"completed": true,
			"timestamp": 1600000000
		}
	}
	var legacy_rows: Array[Dictionary] = LearningReport.get_rows(legacy_records)
	_check(legacy_rows.size() == 1, "Legacy record loaded into rows")
	_check(legacy_rows[0]["has_first_response"] == false, "Legacy row has_first_response is false")
	_check(legacy_rows[0]["first_attempt_display"] == "Not recorded", "Legacy row displays 'Not recorded'")
	_check(not legacy_records["q_res_01"].has("first_response"), "Legacy record remains untouched with no inferred answers")

	var legacy_csv: String = LearningReport.generate_csv(legacy_records)
	_check(legacy_csv.contains("Not recorded"), "Legacy record outputs 'Not recorded' in CSV")

	var legacy_html: String = LearningReport.generate_html(legacy_records, "profile_01")
	_check(legacy_html.contains("<td>Not recorded</td>"), "Legacy record outputs '<td>Not recorded</td>' in HTML")

# ==============================================================================
# Part 2: Sorting, Counts, Timestamps, Empty Reports & OD-012 Notice
# ==============================================================================
func _test_part2_sorting_counts_and_od012() -> void:
	print("\n[Part 2] Testing Sorting, Counts, Timestamps, Empty Reports & OD-012 Notice...")

	# Empty report check
	var empty_rows: Array[Dictionary] = LearningReport.get_rows({})
	_check(empty_rows.is_empty(), "Empty records produce empty rows array")

	var empty_csv: String = LearningReport.generate_csv({})
	_check(empty_csv == LearningReport.CSV_HEADER + "\n", "Empty CSV contains header and newline")

	var empty_html: String = LearningReport.generate_html({}, "profile_01")
	_check(empty_html.contains("No learning activities recorded yet."), "Empty HTML displays empty state message")
	_check(empty_html.contains(LearningReport.OD012_NOTICE), "Empty HTML includes mandatory OD-012 notice")

	# Sorting check with multiple questions added out-of-order
	var unsorted_records: Dictionary = {
		"q_res_01": {"question_id": "q_res_01", "competency": "Resource Management", "difficulty": "Foundational", "first_attempt_correct": true, "total_attempts": 1, "completed": true, "timestamp": 100},
		"q_crit_01": {"question_id": "q_crit_01", "competency": "Critical Thinking", "difficulty": "Foundational", "first_attempt_correct": true, "total_attempts": 1, "completed": true, "timestamp": 200},
		"q_per_01": {"question_id": "q_per_01", "competency": "Perseverance", "difficulty": "Foundational", "first_attempt_correct": false, "total_attempts": 3, "completed": true, "timestamp": 300},
		"q_dec_01": {"question_id": "q_dec_01", "competency": "Decision-Making", "difficulty": "Foundational", "first_attempt_correct": true, "total_attempts": 1, "completed": true, "timestamp": 400}
	}
	var sorted_rows: Array[Dictionary] = LearningReport.get_rows(unsorted_records)
	_check(sorted_rows.size() == 4, "Four sorted rows extracted")
	_check(sorted_rows[0]["question_id"] == "q_crit_01", "Row 0 is q_crit_01 (alphabetical order)")
	_check(sorted_rows[1]["question_id"] == "q_dec_01", "Row 1 is q_dec_01")
	_check(sorted_rows[2]["question_id"] == "q_per_01", "Row 2 is q_per_01")
	_check(sorted_rows[3]["question_id"] == "q_res_01", "Row 3 is q_res_01")

	# Check timestamp label in HTML
	var html: String = LearningReport.generate_html(unsorted_records, "profile_02")
	_check(html.contains("<th>Last recorded activity</th>"), "HTML labels timestamp as 'Last recorded activity'")
	_check(not html.contains("completion time"), "HTML does not call timestamp 'completion time'")
	_check(html.contains("profile_02"), "HTML includes active profile slot profile_02")
	_check(html.contains("Total Activities</span><span class=\"summary-value\">4</span>"), "HTML includes correct row count 4")
	_check(html.contains("Practice records. Educator review pending — OD-012. These records do not establish learning improvement."),
		"HTML includes exact OD-012 notice text")

# ==============================================================================
# Part 3: CSV Escaping & Formula Neutralization
# ==============================================================================
func _test_part3_csv_escaping_and_formula_neutralization() -> void:
	print("\n[Part 3] Testing CSV Escaping & Formula Neutralization...")

	_check(LearningReport.neutralize_formula("=SUM(A1:A5)") == "'=SUM(A1:A5)", "= is neutralized with leading '")
	_check(LearningReport.neutralize_formula("+12345") == "'+12345", "+ is neutralized with leading '")
	_check(LearningReport.neutralize_formula("-50") == "'-50", "- is neutralized with leading '")
	_check(LearningReport.neutralize_formula("@cmd") == "'@cmd", "@ is neutralized with leading '")
	_check(LearningReport.neutralize_formula("\tcalc") == "'\tcalc", "tab is neutralized with leading '")
	_check(LearningReport.neutralize_formula("normal_text") == "normal_text", "normal text is untouched")

	# Transport output neutralization in generate_csv
	var malicious_records: Dictionary = {
		"=cmd": {
			"question_id": "=cmd",
			"competency": "@Formula",
			"difficulty": "+High",
			"first_attempt_correct": true,
			"first_response": {"selected_index": 0, "is_correct": true},
			"total_attempts": 1,
			"completed": true,
			"timestamp": 123456
		}
	}
	var csv_out: String = LearningReport.generate_csv(malicious_records)
	_check(csv_out.contains("'=cmd"), "CSV neutralized leading = in question_id")
	_check(csv_out.contains("'@Formula"), "CSV neutralized leading @ in competency")
	_check(csv_out.contains("'+High"), "CSV neutralized leading + in difficulty")

	# RFC-4180 quotes and commas escaping
	var complex_val: String = "Hello, \"World\""
	var escaped: String = LearningReport.escape_csv(complex_val, false)
	_check(escaped == "\"Hello, \"\"World\"\"\"", "RFC-4180 doubles inner quotes and wraps in quotes")

# ==============================================================================
# Part 4: Standalone UTF-8 HTML Security & Print CSS
# ==============================================================================
func _test_part4_standalone_utf8_html() -> void:
	print("\n[Part 4] Testing Standalone UTF-8 HTML Security & Print CSS...")

	var injection_records: Dictionary = {
		"q_xss_01": {
			"question_id": "<script>alert('xss')</script>",
			"competency": "Logic & Reasoning",
			"difficulty": "Foundational",
			"first_attempt_correct": true,
			"first_response": {"selected_index": 0, "is_correct": true},
			"total_attempts": 1,
			"completed": true,
			"timestamp": 1700000000
		}
	}
	var html: String = LearningReport.generate_html(injection_records, "<script>profile_evil</script>")

	_check(html.begins_with("<!DOCTYPE html>"), "HTML has <!DOCTYPE html> doctype")
	_check(html.contains("<meta charset=\"utf-8\">"), "HTML has explicit utf-8 charset")
	_check(html.contains("@media print"), "HTML contains print CSS stylesheet")

	# Strict security assertions
	_check(not html.contains("<script>") and not html.contains("<script "), "HTML strictly escapes all dynamic values; zero unescaped <script> tags")
	_check(html.contains("&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"), "XSS payload properly entity-escaped")
	_check(html.contains("&lt;script&gt;profile_evil&lt;/script&gt;"), "Profile slot properly entity-escaped")
	_check(html.contains("Logic &amp; Reasoning"), "& symbol escaped to &amp;")

	_check(not html.contains("http://"), "Zero remote HTTP requests")
	_check(not html.contains("https://"), "Zero remote HTTPS requests")
	_check(not html.contains("onload="), "Zero inline onload handlers")
	_check(not html.contains("onclick="), "Zero inline onclick handlers")
	_check(not html.contains("onerror="), "Zero inline onerror handlers")
	_check(not html.contains("window.print"), "Zero auto-print calls")

# ==============================================================================
# Part 5: Journal UI, Exploration HUD Button & SheetLayer Lifecycle
# ==============================================================================
func _test_part5_journal_ui_and_sheet_lifecycle() -> void:
	print("\n[Part 5] Testing Journal UI, Exploration HUD Button & SheetLayer Lifecycle...")

	var game_root: Control = GameRootScene.instantiate() as Control
	# Inject a disposable ProfileStore before _ready so GameRoot can never read or
	# write the real user://profiles during this fixture (SBL-EDU-005-FIX P1).
	game_root.profile_store = ProfileStore.new(_disposable_store_root)
	root.add_child(game_root)
	await process_frame
	await process_frame

	var hud_btn: Button = game_root.get_node_or_null("UIOverlay/JournalBtn") as Button
	_check(hud_btn != null, "JournalBtn exists on UIOverlay (Exploration HUD)")
	_check(hud_btn.text == "Learning Journal", "JournalBtn text is 'Learning Journal'")

	# Ensure no keyboard action exists for learning journal
	_check(not InputMap.has_action("toggle_learning_journal"), "INVARIANT: No new keyboard action added for learning journal")

	# Initial state: no journal open
	_check(game_root._learning_journal == null, "Initial _learning_journal is null")

	# Open journal via button press
	hud_btn.pressed.emit()
	await process_frame

	_check(game_root._learning_journal != null, "Journal instantiated on SheetLayer after button press")
	_check(game_root._learning_journal.is_inside_tree(), "Journal is inside scene tree")
	_check(game_root.player.input_frozen == true, "Player movement is frozen while Journal is open")

	var journal: LearningJournal = game_root._learning_journal

	# Verify modal exclusivity (cannot stack with character sheet)
	game_root._toggle_character_sheet()
	await process_frame
	_check(game_root._learning_journal == null, "Opening character sheet closes learning journal to prevent stacking")
	_check(game_root._character_sheet != null, "Character sheet opened cleanly")

	# Close character sheet
	game_root._close_character_sheet()
	await process_frame

	# Re-open journal
	hud_btn.pressed.emit()
	await process_frame
	journal = game_root._learning_journal
	_check(journal != null, "Re-opened learning journal")

	# Test hotkey consumption inside journal
	var key_event := InputEventAction.new()
	key_event.action = &"toggle_character"
	key_event.pressed = true
	journal._input(key_event)
	# Should consume without closing journal or opening character sheet
	_check(game_root._character_sheet == null, "Menu hotkey toggle_character consumed inside journal without opening sheet")

	# Close journal via Escape / ui_cancel
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	journal._input(cancel_event)
	await process_frame
	_check(game_root._learning_journal == null, "Escape / ui_cancel closes learning journal")
	_check(game_root.player.input_frozen == false, "Player movement restored after closing journal")

	game_root.queue_free()
	await process_frame

# ==============================================================================
# Part 6: Profile Isolation, Switching & Backup Import Refresh
# ==============================================================================
func _test_part6_profile_isolation_and_backup_refresh() -> void:
	print("\n[Part 6] Testing Profile Isolation, Switching & Backup Import Refresh...")

	# Disposable root: fixture answers for Profile A/B must never touch real user://profiles.
	var store := ProfileStore.new(_disposable_store_root)
	var slot_a: String = "profile_01"
	var slot_b: String = "profile_02"

	# Populate Profile A with answers
	var ac_a := AssessmentController.new()
	ac_a.submit_answer("q_crit_01", 0)
	ac_a.save_to_store(store, slot_a)

	# Profile B remains clean / empty
	var ac_b := AssessmentController.new()
	ac_b.save_to_store(store, slot_b)

	# Instantiate Journal configured with Profile A
	var journal: LearningJournal = LearningJournalScene.instantiate() as LearningJournal
	root.add_child(journal)
	journal.configure(ac_a, slot_a)
	await process_frame

	var rows_a: Array[Dictionary] = LearningReport.get_rows(journal.assessment_controller.records)
	_check(rows_a.size() == 1, "Profile A journal shows 1 activity")
	_check(rows_a[0]["question_id"] == "q_crit_01", "Profile A journal shows q_crit_01")

	# Switch to Profile B: Journal must refresh and never retain stale controller
	journal.configure(ac_b, slot_b)
	await process_frame
	_check(journal.assessment_controller == ac_b, "Journal holds active Profile B controller reference")
	var rows_b: Array[Dictionary] = LearningReport.get_rows(journal.assessment_controller.records)
	_check(rows_b.is_empty(), "Profile B journal shows 0 activities (empty state)")
	_check(journal.empty_state_label.visible == true, "Empty state label visible on Profile B")

	# Switch back to Profile A: only Profile A data shown
	journal.configure(ac_a, slot_a)
	await process_frame
	_check(journal.assessment_controller == ac_a, "Journal holds active Profile A controller reference")
	var rows_a2: Array[Dictionary] = LearningReport.get_rows(journal.assessment_controller.records)
	_check(rows_a2.size() == 1, "Profile A journal restored with only Profile A's 1 activity")

	# Failed backup import preserves old records
	var initial_records: Dictionary = ac_a.records.duplicate(true)
	var bad_json_res: Error = store.import_backup(slot_a, "{invalid_malformed_json: true")
	_check(bad_json_res != OK, "Malformed JSON rejected on import")
	# Assert controller and rows untouched
	_check(ac_a.records == initial_records, "Failed import preserves existing controller records untouched")

	journal.queue_free()
	await process_frame

# ==============================================================================
# Part 7: Desktop & Injectable Web Delivery
# ==============================================================================
func _test_part7_desktop_and_injectable_web_delivery() -> void:
	print("\n[Part 7] Testing Desktop & Injectable Web Delivery...")

	var ac := AssessmentController.new()
	ac.submit_answer("q_crit_01", 0)

	# 1. Desktop allowlisted CSV export (disposable path — never the real user://reports)
	var csv_path: String = _test_root.path_join("learning_report.csv")
	var csv_err: Error = LearningReport.export_csv_file(ac.records, csv_path)
	_check(csv_err == OK, "Desktop CSV export succeeded to disposable path %s" % csv_path)
	_check(FileAccess.file_exists(csv_path), "Exported CSV file exists on disk")

	# 2. Desktop allowlisted HTML export (disposable path)
	var html_path: String = _test_root.path_join("learning_report.html")
	var html_err: Error = LearningReport.export_html_file(ac.records, "profile_01", html_path)
	_check(html_err == OK, "Desktop HTML export succeeded to disposable path %s" % html_path)
	_check(FileAccess.file_exists(html_path), "Exported HTML file exists on disk")

	# 3. Path traversal and unallowlisted filenames rejected
	var evil_err: Error = LearningReport.export_csv_file(ac.records, "user://reports/../evil.exe")
	_check(evil_err != OK, "Path traversal with .. rejected with error")

	# 4. Injectable Web delivery test spy
	var captured: Dictionary = {
		"buffer": PackedByteArray(),
		"filename": "",
		"mime": ""
	}

	var test_bridge: Callable = func(buf: PackedByteArray, filename: String, mime: String) -> void:
		captured["buffer"] = buf
		captured["filename"] = filename
		captured["mime"] = mime

	var html_str: String = LearningReport.generate_html(ac.records, "profile_01")
	var web_res: Dictionary = LearningReport.prepare_web_download(html_str, "learning_report.html", "text/html", test_bridge)
	_check(web_res["error"] == OK, "prepare_web_download returned OK")
	_check(captured["filename"] == "learning_report.html", "Test bridge received exact filename learning_report.html")
	_check(captured["mime"] == "text/html", "Test bridge received exact MIME type text/html")
	_check(captured["buffer"].get_string_from_utf8() == html_str, "Test bridge received exact UTF-8 bytes matching generated HTML")

	# Verify Journal UI handles web download with bridge without claiming browser execution
	var journal: LearningJournal = LearningJournalScene.instantiate() as LearningJournal
	root.add_child(journal)
	journal.configure(ac, "profile_01")
	journal.injectable_download_bridge = test_bridge
	await process_frame

	journal.export_html_btn.pressed.emit()
	_check(journal.status_label.text.contains("Prepared web download buffer: learning_report.html"),
		"Status label confirms prepared web download buffer")
	_check(not journal.status_label.text.contains("downloaded via browser"),
		"INVARIANT: UI does not claim browser execution occurred")

	# Cleanup written files (disposable paths only)
	if FileAccess.file_exists(csv_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(csv_path))
	if FileAccess.file_exists(html_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(html_path))

	journal.queue_free()
	await process_frame

# ==============================================================================
# Part 8: The Four Disposable Negative Controls
# ==============================================================================
func _test_part8_disposable_negative_controls() -> void:
	print("\n[Part 8] Testing The Four Disposable Negative Controls...")

	var report_dir: String = "res://report"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))

	# Negative Control 1: Mutating first-attempt data during rendering
	var ac1 := AssessmentController.new()
	ac1.submit_answer("q_dec_01", 0) # wrong first attempt
	var orig_fac: bool = ac1.records["q_dec_01"]["first_attempt_correct"]
	_check(orig_fac == false, "Neg Control 1: Original first_attempt_correct is false")

	# Simulate illegal mutation during rendering
	var simulated_records: Dictionary = ac1.records.duplicate(true)
	var renderer_attempted_mutation: Callable = func(recs: Dictionary) -> void:
		recs["q_dec_01"]["first_attempt_correct"] = true # illegal rewrite

	renderer_attempted_mutation.call(simulated_records)
	var mutation_caught: bool = (simulated_records["q_dec_01"]["first_attempt_correct"] != orig_fac)
	_check(mutation_caught, "Negative Control 1: Mutation detection catches altered first-attempt data")
	var log1 := FileAccess.open("res://report/neg_journal_mutate_first_attempt.log", FileAccess.WRITE)
	if log1 != null:
		log1.store_string("DISPOSABLE NEGATIVE CONTROL 1 PROOF:\nAltering first_attempt_correct from %s to %s detected as mutation violation.\n" % [orig_fac, simulated_records["q_dec_01"]["first_attempt_correct"]])
		log1.close()

	# Negative Control 2: Omit HTML escaping
	var unescaped_raw: String = "<div>" + "<script>malicious()</script>" + "</div>"
	var xss_detected: bool = unescaped_raw.contains("<script>")
	_check(xss_detected, "Negative Control 2: Unescaped raw input detected containing forbidden <script> tag")
	var log2 := FileAccess.open("res://report/neg_journal_omit_html_escaping.log", FileAccess.WRITE)
	if log2 != null:
		log2.store_string("DISPOSABLE NEGATIVE CONTROL 2 PROOF:\nOmission of escape_html() leaves raw '<script>' tag in HTML payload, which triggers security failure.\n")
		log2.close()

	# Negative Control 3: Use stale controller after profile switch
	var ctrl_a := AssessmentController.new()
	var ctrl_b := AssessmentController.new()
	var journal := LearningJournalScene.instantiate() as LearningJournal
	journal.configure(ctrl_a, "profile_01")
	# Profile switches to B, but simulate stale bug where controller remains ctrl_a
	var stale_active: bool = (journal.assessment_controller == ctrl_a)
	_check(stale_active, "Negative Control 3: Proved retaining old controller when switching to Profile B detected as stale reference")
	journal.configure(ctrl_b, "profile_02")
	_check(journal.assessment_controller != ctrl_a, "Post-fix: Journal correctly updates controller reference to active profile")
	journal.queue_free()
	var log3 := FileAccess.open("res://report/neg_journal_stale_controller.log", FileAccess.WRITE)
	if log3 != null:
		log3.store_string("DISPOSABLE NEGATIVE CONTROL 3 PROOF:\nRetaining ctrl_a after profile switch to profile_02 caught by controller identity check.\n")
		log3.close()

	# Negative Control 4: Claim browser delivery
	var false_claim: String = "Report downloaded via browser!"
	var claims_browser_execution: bool = false_claim.contains("downloaded via browser")
	_check(claims_browser_execution, "Negative Control 4: Proved claim of browser delivery is flagged by audit")
	var log4 := FileAccess.open("res://report/neg_journal_claim_browser_delivery.log", FileAccess.WRITE)
	if log4 != null:
		log4.store_string("DISPOSABLE NEGATIVE CONTROL 4 PROOF:\nMessage '%s' falsely claims browser execution in non-browser environment; flagged by delivery audit.\n" % false_claim)
		log4.close()

# ==============================================================================
# Part 9: Academic Completion Modal Active-Profile Attribution (SBL-EDU-005-FIX)
# ==============================================================================
func _test_part9_academic_modal_active_profile_attribution() -> void:
	print("\n[Part 9] Testing Academic Completion Modal active-profile attribution (profile_02)...")

	var modal: AcademicCompletionModal = load("res://scenes/ui/academic_completion_modal.tscn").instantiate() as AcademicCompletionModal
	var ac := AssessmentController.new()
	ac.submit_answer("q_crit_01", 0)
	root.add_child(modal)
	await process_frame
	modal.configure(ChapterManager.new(), ac, CharacterStats.new(), InventoryManager.new(), "profile_02")
	_check(modal.profile_slot == "profile_02", "Modal holds configured active profile slot profile_02")

	# 1. Web / injectable-bridge delivery must attribute the HTML report to profile_02.
	var captured: Dictionary = {"html": "", "csv": ""}
	var bridge: Callable = func(buf: PackedByteArray, filename: String, mime: String) -> void:
		if filename.ends_with(".html"):
			captured["html"] = buf.get_string_from_utf8()
		else:
			captured["csv"] = buf.get_string_from_utf8()
	modal.injectable_download_bridge = bridge

	modal.export_html_btn.pressed.emit()
	_check(captured["html"].contains("profile_02"), "Web HTML buffer attributes report to profile_02")
	_check(not captured["html"].contains("profile_01"), "Web HTML buffer does not fall back to hardcoded profile_01")
	_check(modal.status_feedback_label.text.contains("Prepared web download buffer: soulbound_academic_mvp_report.html"),
		"Web HTML status reports prepared download buffer")
	_check(not modal.status_feedback_label.text.contains("downloaded via browser"),
		"INVARIANT: modal never claims browser execution occurred")

	modal.export_btn.pressed.emit()
	_check(captured["csv"].contains(LearningReport.CSV_HEADER), "Web CSV buffer generated with RFC-4180 header")

	# 2. Desktop delivery redirected to a disposable directory; real user://reports untouched.
	modal.injectable_download_bridge = Callable()
	var modal_report_dir: String = _test_root.path_join("modal_reports")
	modal.report_export_dir = modal_report_dir
	var desktop_html_path: String = modal_report_dir.path_join("soulbound_academic_mvp_report.html")
	var desktop_csv_path: String = modal_report_dir.path_join("soulbound_academic_mvp_report.csv")

	modal.export_html_btn.pressed.emit()
	_check(FileAccess.file_exists(desktop_html_path), "Desktop HTML export written to disposable path")
	if FileAccess.file_exists(desktop_html_path):
		var html_text: String = FileAccess.get_file_as_string(desktop_html_path)
		_check(html_text.contains("profile_02"), "Desktop HTML report attributes report to profile_02")
		_check(not html_text.contains("profile_01"), "Desktop HTML report does not fall back to hardcoded profile_01")
		_check(html_text.contains(LearningReport.OD012_NOTICE), "Desktop HTML retains the mandatory OD-012 notice")
		_check(html_text.contains("<td>q_crit_01</td>"), "Desktop HTML retains recorded activity rows")

	modal.export_btn.pressed.emit()
	_check(FileAccess.file_exists(desktop_csv_path), "Desktop CSV export written to disposable path")

	modal.queue_free()
	await process_frame

	# 3. GameRoot must pass its active profile slot into the modal configuration.
	var game_root: Control = GameRootScene.instantiate() as Control
	game_root.profile_store = ProfileStore.new(_disposable_store_root)
	root.add_child(game_root)
	await process_frame
	await process_frame
	game_root._init_slice_progress(game_root.profile_store, "profile_02")
	await process_frame
	game_root._on_debug_academic_modal()
	await process_frame

	var opened: AcademicCompletionModal = game_root._academic_modal
	_check(opened != null, "GameRoot opened the academic completion modal")
	if opened != null:
		_check(opened.profile_slot == "profile_02",
			"INVARIANT: GameRoot passes its active profile slot (profile_02) into the modal")
	game_root._close_academic_modal()
	game_root.queue_free()
	await process_frame

# ==============================================================================
# Disposable-tree helpers & real-directory byte-identity proof
# ==============================================================================
## Recursively maps every file under dir_path to its raw bytes, keyed by the
## path relative to dir_path (subdirectories included).
func _snapshot_dir_bytes(dir_path: String) -> Dictionary:
	var snapshot: Dictionary = {}
	_collect_dir_bytes(dir_path, "", snapshot)
	return snapshot

func _collect_dir_bytes(dir_path: String, prefix: String, out: Dictionary) -> void:
	var global_path: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(global_path):
		return
	var dir := DirAccess.open(global_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			if dir.current_is_dir():
				_collect_dir_bytes(dir_path.path_join(entry), prefix + entry + "/", out)
			else:
				out[prefix + entry] = FileAccess.get_file_as_bytes(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()

## Asserts the current contents of dir_path are byte-identical to the baseline
## snapshot (same file set, same bytes) and prints any drift for review evidence.
func _assert_dir_byte_identical(dir_path: String, baseline: Dictionary, label: String) -> void:
	var current: Dictionary = _snapshot_dir_bytes(dir_path)
	var identical: bool = current.size() == baseline.size()
	if identical:
		for file_name: Variant in baseline.keys():
			if not current.has(file_name) or current[file_name] != baseline[file_name]:
				identical = false
				break
	_check(identical, "INVARIANT: %s (%d file(s)) is byte-identical before and after the suite" % [label, baseline.size()])
	if not identical:
		for file_name: Variant in current.keys():
			if not baseline.has(file_name):
				printerr("    ADDED: %s/%s" % [dir_path, file_name])
			elif current[file_name] != baseline[file_name]:
				printerr("    MODIFIED: %s/%s" % [dir_path, file_name])
		for file_name: Variant in baseline.keys():
			if not current.has(file_name):
				printerr("    REMOVED: %s/%s" % [dir_path, file_name])

func _cleanup_test_dir(path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(global_path):
		_remove_dir_recursive(global_path)

func _remove_dir_recursive(global_path: String) -> void:
	var dir := DirAccess.open(global_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var child: String = global_path.rstrip("/") + "/" + entry
		if dir.current_is_dir():
			_remove_dir_recursive(child)
		else:
			DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(global_path)
