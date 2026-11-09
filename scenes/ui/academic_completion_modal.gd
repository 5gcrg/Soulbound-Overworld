class_name AcademicCompletionModal
extends Control

## AcademicCompletionModal — SBL-W9-002 Academic MVP Completion Celebration & Summary Modal
## Requirements: GDD-063/116, FR-EDU-004, TC-EDU-004, AGENTS.md Invariants.

signal closed

var chapter_manager: ChapterManager = null
var assessment_controller: AssessmentController = null
var character_stats: CharacterStats = null
var inventory_manager: InventoryManager = null

@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var stats_summary_label: Label = $Panel/Margin/VBox/StatsSummaryLabel
@onready var edu_summary_label: Label = $Panel/Margin/VBox/EduSummaryLabel
@onready var status_feedback_label: Label = $Panel/Margin/VBox/StatusFeedbackLabel

@onready var export_btn: Button = $Panel/Margin/VBox/Buttons/ExportBtn
@onready var close_btn: Button = $Panel/Margin/VBox/Buttons/CloseBtn

func _ready() -> void:
	export_btn.pressed.connect(_on_export_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	refresh()

func configure(ch_mgr: ChapterManager, assessment: AssessmentController, stats: CharacterStats, inv: InventoryManager) -> void:
	chapter_manager = ch_mgr
	assessment_controller = assessment
	character_stats = stats
	inventory_manager = inv
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
	if assessment_controller != null:
		var export_path: String = "user://reports/soulbound_academic_mvp_report.csv"
		var err: Error = assessment_controller.export_to_csv(export_path)
		if err == OK:
			status_feedback_label.text = "Report exported to: %s" % export_path
		else:
			status_feedback_label.text = "Export failed: Error %d" % err

func _on_close_pressed() -> void:
	closed.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("toggle_character") or event.is_action_pressed("toggle_inventory") or event.is_action_pressed("toggle_settings"):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
