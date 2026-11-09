class_name AcademicCompletionModal
extends Control

## AcademicCompletionModal — SBL-W9-002 Academic MVP Completion Celebration & Summary Modal
## Requirements: GDD-063/116, FR-EDU-004, TC-EDU-004, AGENTS.md Invariants.

signal closed

var chapter_manager: ChapterManager = null
var assessment_controller: AssessmentController = null
var character_stats: CharacterStats = null
var inventory_manager: InventoryManager = null

## Active profile slot supplied by GameRoot; used for HTML report attribution.
var profile_slot: String = "profile_01"
## Report output directory. Defaults to the production user://reports location;
## tests redirect it to a disposable path (same pattern as injectable_download_bridge).
var report_export_dir: String = "user://reports"

@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var stats_summary_label: Label = _find_node(["Panel/Margin/VBox/Scroll/SummaryBox/StatsSummaryLabel", "Panel/Margin/VBox/StatsSummaryLabel"]) as Label
@onready var edu_summary_label: Label = _find_node(["Panel/Margin/VBox/Scroll/SummaryBox/EduSummaryLabel", "Panel/Margin/VBox/EduSummaryLabel"]) as Label
@onready var status_feedback_label: Label = _find_node(["Panel/Margin/VBox/Scroll/SummaryBox/StatusFeedbackLabel", "Panel/Margin/VBox/StatusFeedbackLabel"]) as Label

@onready var export_btn: Button = $Panel/Margin/VBox/Buttons/ExportBtn
@onready var export_html_btn: Button = $Panel/Margin/VBox/Buttons/ExportHtmlBtn
@onready var close_btn: Button = $Panel/Margin/VBox/Buttons/CloseBtn

var injectable_download_bridge: Callable = Callable()

func _find_node(paths: Array) -> Node:
	for p in paths:
		if has_node(String(p)):
			return get_node(String(p))
	return null

func _ready() -> void:
	export_btn.pressed.connect(_on_export_pressed)
	if export_html_btn != null:
		export_html_btn.pressed.connect(_on_export_html_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	refresh()

func configure(ch_mgr: ChapterManager, assessment: AssessmentController, stats: CharacterStats, inv: InventoryManager, slot: String = "profile_01") -> void:
	chapter_manager = ch_mgr
	assessment_controller = assessment
	character_stats = stats
	inventory_manager = inv
	profile_slot = slot
	if is_inside_tree():
		refresh()

func refresh() -> void:
	if character_stats != null:
		stats_summary_label.text = "Ren: Level %d   |   Max HP: %d   |   Spirit Power: %d   |   Banked Items: %d" % [
			character_stats.level,
			character_stats.get_max_hp(),
			character_stats.get_spirit_power(),
			inventory_manager.banked_items.size() if inventory_manager != null else 0
		]

	if assessment_controller != null:
		var summary: Dictionary = assessment_controller.get_completion_summary()
		edu_summary_label.text = "Curriculum Competencies Completed: %d / %d Questions (First-Attempt Correct: %d)\nCompetencies: Critical Thinking • Decision-Making • Perseverance • Resource Mgmt" % [
			summary.get("completed_questions", 0),
			summary.get("total_questions", 0),
			summary.get("first_attempt_correct_count", 0)
		]

func _on_export_pressed() -> void:
	if assessment_controller == null:
		return
	var export_path: String = report_export_dir.path_join("soulbound_academic_mvp_report.csv")
	if OS.has_feature("web") or injectable_download_bridge.is_valid():
		var csv_text: String = LearningReport.generate_csv(assessment_controller.records)
		var res: Dictionary = LearningReport.prepare_web_download(csv_text, "soulbound_academic_mvp_report.csv", "text/csv", injectable_download_bridge)
		if res["error"] == OK:
			status_feedback_label.text = "Prepared web download buffer: soulbound_academic_mvp_report.csv"
		else:
			status_feedback_label.text = "Web export failed: Error %d" % res["error"]
		return
	var err: Error = LearningReport.export_csv_file(assessment_controller.records, export_path)
	if err == OK:
		status_feedback_label.text = "Report exported to: %s" % export_path
	else:
		status_feedback_label.text = "Export failed: Error %d" % err

func _on_export_html_pressed() -> void:
	if assessment_controller == null:
		return
	var export_path: String = report_export_dir.path_join("soulbound_academic_mvp_report.html")
	if OS.has_feature("web") or injectable_download_bridge.is_valid():
		var html_text: String = LearningReport.generate_html(assessment_controller.records, profile_slot)
		var res: Dictionary = LearningReport.prepare_web_download(html_text, "soulbound_academic_mvp_report.html", "text/html", injectable_download_bridge)
		if res["error"] == OK:
			status_feedback_label.text = "Prepared web download buffer: soulbound_academic_mvp_report.html"
		else:
			status_feedback_label.text = "Web export failed: Error %d" % res["error"]
		return
	var err: Error = LearningReport.export_html_file(assessment_controller.records, profile_slot, export_path)
	if err == OK:
		status_feedback_label.text = "Report exported to: %s" % export_path
	else:
		status_feedback_label.text = "Export failed: Error %d" % err

func _on_close_pressed() -> void:
	closed.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("toggle_character") or event.is_action_pressed("toggle_inventory") \
			or event.is_action_pressed("toggle_settings") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
