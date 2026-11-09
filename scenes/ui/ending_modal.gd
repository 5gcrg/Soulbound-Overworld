class_name EndingModal
extends Control

signal closed()
signal title_menu_requested()

@onready var ending_title: Label = $PanelContainer/Margin/VBox/EndingTitle
@onready var summary_label: Label = _find_node(["PanelContainer/Margin/VBox/Scroll/ContentBox/SummaryLabel", "PanelContainer/Margin/VBox/SummaryLabel"]) as Label
@onready var epilogue_label: Label = _find_node(["PanelContainer/Margin/VBox/Scroll/ContentBox/EpilogueLabel", "PanelContainer/Margin/VBox/EpilogueLabel"]) as Label
@onready var stats_label: Label = _find_node(["PanelContainer/Margin/VBox/Scroll/ContentBox/StatsPanel/Margin/StatsLabel", "PanelContainer/Margin/VBox/StatsPanel/Margin/StatsLabel"]) as Label
@onready var badge_label: Label = _find_node(["PanelContainer/Margin/VBox/Scroll/ContentBox/BadgeLabel", "PanelContainer/Margin/VBox/BadgeLabel"]) as Label
@onready var roam_btn: Button = $PanelContainer/Margin/VBox/ButtonRow/RoamBtn
@onready var title_btn: Button = $PanelContainer/Margin/VBox/ButtonRow/TitleBtn

func _find_node(paths: Array) -> Node:
	for p in paths:
		if has_node(String(p)):
			return get_node(String(p))
	return null

var _cached_details: Dictionary = {}
var _cached_stats_text: String = ""

func _ready() -> void:
	if roam_btn != null:
		roam_btn.pressed.connect(_on_roam_pressed)
	if title_btn != null:
		title_btn.pressed.connect(_on_title_pressed)
	_apply_ui()

func configure(ending_type: String, ending_mgr: EndingManager, stats: CharacterStats, assessment: AssessmentController) -> void:
	_cached_details = ending_mgr.get_ending_details(ending_type)

	var summary := assessment.get_completion_summary() if assessment != null else {}
	var total_q: int = int(summary.get("total_questions", 0))
	var first_try: int = int(summary.get("first_attempt_correct_count", 0))
	var acc: float = (float(first_try) / float(total_q) * 100.0) if total_q > 0 else 100.0

	_cached_stats_text = "Ren Level: %d | Max HP: %d | Educational Questions Completed: %d/%d (First-Try Accuracy: %.1f%%)" % [
		stats.level if stats != null else 1,
		stats.get_max_hp() if stats != null else 100,
		int(summary.get("completed_questions", 0)),
		total_q,
		acc
	]

	_apply_ui()

func _apply_ui() -> void:
	if ending_title != null and not _cached_details.is_empty():
		ending_title.text = String(_cached_details.get("title", "Campaign Conclusion"))

	if summary_label != null and not _cached_details.is_empty():
		summary_label.text = String(_cached_details.get("summary", ""))

	if epilogue_label != null and not _cached_details.is_empty():
		epilogue_label.text = String(_cached_details.get("epilogue", ""))

	if badge_label != null and not _cached_details.is_empty():
		badge_label.text = "HONORARY TITULAR BADGE: [%s]" % String(_cached_details.get("badge", "Cosmic Voyager"))

	if stats_label != null and not _cached_stats_text.is_empty():
		stats_label.text = _cached_stats_text

## Results are terminal until the player explicitly chooses Roam or Title. Consume sheet
## hotkeys so no character/inventory/settings panel can stack over the epilogue.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("toggle_character") or event.is_action_pressed("toggle_inventory") \
			or event.is_action_pressed("toggle_settings") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func _on_roam_pressed() -> void:
	closed.emit()

func _on_title_pressed() -> void:
	title_menu_requested.emit()
