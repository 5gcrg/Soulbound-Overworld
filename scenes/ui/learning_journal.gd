class_name LearningJournal
extends Control

## LearningJournal — SBL-EDU-005 Learning Journal UI Screen
## Requirements: GDD-071, GDD-072, GDD-091, GDD-112, FR-EDU-002/004, TC-EDU-002/004, NFR-SEC-001, NFR-ACC-001.
##
## Rules:
## 1. Button-only access from exploration HUD; no new keyboard action.
## 2. One journal instance on SheetLayer; freezes movement, consumes menu hotkeys/Escape, prevents stacking.
## 3. Restores prior focus and movement lock on close.
## 4. Refreshes on every open, profile switch, and backup import; never retains a stale controller reference.
## 5. Exports allowlisted CSV and standalone HTML reports on desktop and injectable web download buffers.
## 6. Strictly displays OD-012 notice and labels timestamp as "Last recorded activity".

signal closed

var assessment_controller: AssessmentController = null
var profile_slot: String = "profile_01"
var injectable_download_bridge: Callable = Callable()

@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var notice_label: Label = $Panel/Margin/VBox/NoticeLabel
@onready var summary_label: Label = $Panel/Margin/VBox/SummaryLabel
@onready var scroll: ScrollContainer = $Panel/Margin/VBox/Scroll
@onready var empty_state_label: Label = $Panel/Margin/VBox/Scroll/ContentBox/EmptyStateLabel
@onready var table_container: VBoxContainer = $Panel/Margin/VBox/Scroll/ContentBox/TableContainer
@onready var rows_box: VBoxContainer = $Panel/Margin/VBox/Scroll/ContentBox/TableContainer/RowsBox
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel

@onready var export_csv_btn: Button = $Panel/Margin/VBox/Buttons/ExportCsvBtn
@onready var export_html_btn: Button = $Panel/Margin/VBox/Buttons/ExportHtmlBtn
@onready var close_btn: Button = $Panel/Margin/VBox/Buttons/CloseBtn

func _ready() -> void:
	if export_csv_btn != null:
		export_csv_btn.pressed.connect(_on_export_csv_pressed)
	if export_html_btn != null:
		export_html_btn.pressed.connect(_on_export_html_pressed)
	if close_btn != null:
		close_btn.pressed.connect(_on_close_pressed)

	_setup_focus()
	refresh()

	if close_btn != null:
		close_btn.grab_focus()

func configure(controller: AssessmentController, slot: String = "profile_01") -> void:
	assessment_controller = controller
	profile_slot = slot
	if is_inside_tree():
		refresh()

func _setup_focus() -> void:
	if export_csv_btn == null or export_html_btn == null or close_btn == null:
		return
	export_csv_btn.focus_neighbor_left = close_btn.get_path()
	export_csv_btn.focus_neighbor_right = export_html_btn.get_path()
	export_html_btn.focus_neighbor_left = export_csv_btn.get_path()
	export_html_btn.focus_neighbor_right = close_btn.get_path()
	close_btn.focus_neighbor_left = export_html_btn.get_path()
	close_btn.focus_neighbor_right = export_csv_btn.get_path()

func refresh() -> void:
	if notice_label != null:
		notice_label.text = LearningReport.OD012_NOTICE

	var records: Dictionary = {}
	if assessment_controller != null:
		records = assessment_controller.records

	var rows: Array[Dictionary] = LearningReport.get_rows(records)
	var row_count: int = rows.size()
	var completed_count: int = 0
	var first_correct_count: int = 0

	for r: Dictionary in rows:
		if r["completed"]:
			completed_count += 1
		if r["has_first_response"] and r["first_attempt_correct"]:
			first_correct_count += 1

	if summary_label != null:
		summary_label.text = "Active Profile: %s   |   Activities: %d   |   Completed: %d   |   First-Attempt Correct: %d" % [
			profile_slot,
			row_count,
			completed_count,
			first_correct_count
		]

	if rows_box == null or empty_state_label == null or table_container == null:
		return

	if row_count == 0:
		empty_state_label.visible = true
		table_container.visible = false
		for child: Node in rows_box.get_children():
			child.queue_free()
	else:
		empty_state_label.visible = false
		table_container.visible = true

		for child: Node in rows_box.get_children():
			child.queue_free()

		for r: Dictionary in rows:
			var row_box := HBoxContainer.new()
			row_box.add_theme_constant_override("separation", 8)

			var q_label := Label.new()
			q_label.text = String(r["question_id"])
			q_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			q_label.add_theme_font_size_override("font_size", 10)
			row_box.add_child(q_label)

			var c_label := Label.new()
			c_label.text = String(r["competency"])
			c_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c_label.add_theme_font_size_override("font_size", 10)
			row_box.add_child(c_label)

			var d_label := Label.new()
			d_label.text = String(r["difficulty"])
			d_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			d_label.add_theme_font_size_override("font_size", 10)
			row_box.add_child(d_label)

			var fa_label := Label.new()
			fa_label.text = String(r["first_attempt_display"])
			fa_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fa_label.add_theme_font_size_override("font_size", 10)
			row_box.add_child(fa_label)

			var att_label := Label.new()
			att_label.text = str(r["total_attempts"])
			att_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			att_label.add_theme_font_size_override("font_size", 10)
			row_box.add_child(att_label)

			var comp_label := Label.new()
			comp_label.text = "Yes" if r["completed"] else "No"
			comp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			comp_label.add_theme_font_size_override("font_size", 10)
			row_box.add_child(comp_label)

			var ts_label := Label.new()
			ts_label.text = LearningReport.format_timestamp(r["timestamp"])
			ts_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ts_label.add_theme_font_size_override("font_size", 10)
			row_box.add_child(ts_label)

			rows_box.add_child(row_box)

func _on_export_csv_pressed() -> void:
	if assessment_controller == null:
		if status_label != null:
			status_label.text = "Export failed: No assessment data available"
		return

	var export_path: String = "user://reports/learning_report.csv"
	if OS.has_feature("web") or injectable_download_bridge.is_valid():
		var csv_text: String = LearningReport.generate_csv(assessment_controller.records)
		var res: Dictionary = LearningReport.prepare_web_download(csv_text, "learning_report.csv", "text/csv", injectable_download_bridge)
		if res["error"] == OK:
			if status_label != null:
				status_label.text = "Prepared web download buffer: learning_report.csv"
		else:
			if status_label != null:
				status_label.text = "Web export failed: Error %d" % res["error"]
		return

	var err: Error = LearningReport.export_csv_file(assessment_controller.records, export_path)
	if err == OK:
		if status_label != null:
			status_label.text = "Report exported to: %s" % export_path
	else:
		if status_label != null:
			status_label.text = "Export failed: Error %d" % err

func _on_export_html_pressed() -> void:
	if assessment_controller == null:
		if status_label != null:
			status_label.text = "Export failed: No assessment data available"
		return

	var export_path: String = "user://reports/learning_report.html"
	if OS.has_feature("web") or injectable_download_bridge.is_valid():
		var html_text: String = LearningReport.generate_html(assessment_controller.records, profile_slot)
		var res: Dictionary = LearningReport.prepare_web_download(html_text, "learning_report.html", "text/html", injectable_download_bridge)
		if res["error"] == OK:
			if status_label != null:
				status_label.text = "Prepared web download buffer: learning_report.html"
		else:
			if status_label != null:
				status_label.text = "Web export failed: Error %d" % res["error"]
		return

	var err: Error = LearningReport.export_html_file(assessment_controller.records, profile_slot, export_path)
	if err == OK:
		if status_label != null:
			status_label.text = "Report exported to: %s" % export_path
	else:
		if status_label != null:
			status_label.text = "Export failed: Error %d" % err

func _on_close_pressed() -> void:
	closed.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("toggle_character") or event.is_action_pressed("toggle_inventory") \
			or event.is_action_pressed("toggle_settings"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
