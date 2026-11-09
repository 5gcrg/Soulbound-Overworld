class_name ChapterActivityDialog
extends Control
## SBL-P1-D: Native chapter practice-activity dialog (interface only).
##
## Instantiated with .new() by GameRoot, configured BEFORE entering the tree,
## then added to DialogLayer. It never commits or mutates save state itself:
## it only emits intent signals and displays whatever GameRoot reports back.
##
## Flow:
##   configure(question, existing_record)
##   option pressed  -> answer_selected(index)          (once per attempt)
##   GameRoot commit -> set_feedback(result) | show_save_error(err)
##   Continue        -> feedback_acknowledged            (once per attempt)
##   GameRoot commit -> closes the dialog itself, or show_save_error(err) to retry
##   Close / Escape  -> closed                           (once)
##
## The dialog never frees itself or emits `closed` automatically.
## Content shown is limited to the supplied question data (practice only).

signal answer_selected(index: int)
signal feedback_acknowledged
signal closed

enum Phase {
	ANSWERING,          ## Options enabled, waiting for the player.
	AWAITING_ANSWER,    ## answer_selected emitted, waiting on GameRoot.
	ANSWER_RETRY,       ## Answer write failed; Retry re-sends the same index.
	FEEDBACK,           ## Feedback shown, Continue enabled.
	AWAITING_ACK,       ## feedback_acknowledged emitted, waiting on GameRoot.
	RESTORED,           ## Completed record restored; explanation + Continue.
}

const PANEL_MIN_SIZE := Vector2(640, 420)
const OPTION_LABELS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const COLOR_CORRECT := Color(0.55, 0.9, 0.55)
const COLOR_INCORRECT := Color(1.0, 0.6, 0.5)
const COLOR_ERROR := Color(1.0, 0.45, 0.4)

## Answer buttons, in question option order. Public for live tests.
var option_buttons: Array[Button] = []
## Continue button (hidden until feedback or restored record). Public for live tests.
var continue_button: Button

var _question: Dictionary = {}
var _existing_record: Dictionary = {}
var _phase: int = Phase.ANSWERING
var _pending_index: int = -1
var _selected_index: int = -1
var _correct_index: int = -1
var _feedback_correct: bool = false
var _feedback_text: String = ""
var _has_feedback_result: bool = false
var _error_text: String = ""
var _closed_emitted: bool = false

var _practice_label: Label
var _question_label: Label
var _options_box: VBoxContainer
var _status_label: Label
var _explanation_label: Label
var _error_label: Label
var _retry_button: Button
var _close_button: Button


func _init() -> void:
	_build_ui()


func _ready() -> void:
	_refresh()
	_grab_initial_focus()


## Supply the question (QuestionBank dictionary) and an optional restored record.
## Call before adding to the tree; calling later simply rebuilds the view.
func configure(question: Dictionary, existing_record: Dictionary = {}) -> void:
	_question = question.duplicate(true)
	_existing_record = existing_record.duplicate(true)
	_pending_index = -1
	_selected_index = -1
	_correct_index = -1
	_feedback_correct = false
	_feedback_text = ""
	_has_feedback_result = false
	_error_text = ""
	_closed_emitted = false
	_phase = Phase.ANSWERING

	if _record_is_completed(_existing_record):
		_phase = Phase.RESTORED
		_selected_index = _record_first_attempt_index(_existing_record)
		_correct_index = _record_correct_index(_existing_record)
		if _existing_record.has("correct") or _existing_record.has("is_correct") \
				or _existing_record.has("first_attempt_correct"):
			_feedback_correct = bool(_existing_record.get("first_attempt_correct",
					_existing_record.get("correct", _existing_record.get("is_correct", false))))
			_has_feedback_result = true

	_rebuild_options()
	_refresh()
	if is_inside_tree():
		_grab_initial_focus()


## Display GameRoot's committed result for the selected answer.
## Expected keys (all optional/defensive): correct|is_correct, explanation,
## selected_index, correct_index.
func set_feedback(result: Dictionary) -> void:
	if _phase == Phase.RESTORED:
		return  # A restored completed record is never altered.
	_feedback_correct = bool(result.get("correct", result.get("is_correct", false)))
	_feedback_text = str(result.get("explanation", ""))
	_has_feedback_result = true
	var selected: int = int(result.get("selected_index", _pending_index))
	if selected >= 0:
		_selected_index = selected
	elif _pending_index >= 0:
		_selected_index = _pending_index
	if result.has("correct_index"):
		_correct_index = int(result["correct_index"])
	_error_text = ""
	_phase = Phase.FEEDBACK
	_refresh()
	if is_inside_tree():
		continue_button.grab_focus()


## Show a save failure and make the failed step retryable.
func show_save_error(error: Error) -> void:
	_error_text = "Could not save your progress (%s). Please try again." % error_string(error)
	match _phase:
		Phase.AWAITING_ANSWER:
			_phase = Phase.ANSWER_RETRY
		Phase.AWAITING_ACK:
			_phase = Phase.FEEDBACK
		_:
			pass
	_refresh()
	if not is_inside_tree():
		return
	match _phase:
		Phase.ANSWER_RETRY:
			_retry_button.grab_focus()
		Phase.FEEDBACK, Phase.RESTORED:
			continue_button.grab_focus()
		_:
			_close_button.grab_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _closed_emitted:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()


# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_MIN_SIZE
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = PANEL_MIN_SIZE - Vector2(40, 40)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)

	_practice_label = Label.new()
	_practice_label.text = "Practice activity"
	_practice_label.add_theme_font_size_override("font_size", 14)
	column.add_child(_practice_label)

	_question_label = _make_wrapping_label()
	_question_label.add_theme_font_size_override("font_size", 20)
	column.add_child(_question_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	column.add_child(_options_box)

	_status_label = _make_wrapping_label()
	_status_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_status_label)

	_explanation_label = _make_wrapping_label()
	column.add_child(_explanation_label)

	_error_label = _make_wrapping_label()
	_error_label.add_theme_color_override("font_color", COLOR_ERROR)
	column.add_child(_error_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)

	_retry_button = Button.new()
	_retry_button.text = "Retry"
	_retry_button.focus_mode = Control.FOCUS_ALL
	_retry_button.pressed.connect(_on_retry_pressed)
	buttons.add_child(_retry_button)

	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.pressed.connect(_on_continue_pressed)
	buttons.add_child(continue_button)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.pressed.connect(_on_close_pressed)
	buttons.add_child(_close_button)


func _make_wrapping_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_MIN_SIZE.x - 80, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _rebuild_options() -> void:
	for button in option_buttons:
		if is_instance_valid(button):
			_options_box.remove_child(button)
			button.queue_free()
	option_buttons.clear()

	var options := _question_options(_question)
	for i in options.size():
		var button := Button.new()
		button.text = "%s. %s" % [_option_prefix(i), options[i]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(PANEL_MIN_SIZE.x - 80, 40)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_option_pressed.bind(i))
		_options_box.add_child(button)
		option_buttons.append(button)


# --- State -> view ---------------------------------------------------------

func _refresh() -> void:
	_question_label.text = _question_text(_question)

	var options_enabled := _phase == Phase.ANSWERING
	for i in option_buttons.size():
		var button := option_buttons[i]
		button.disabled = not options_enabled
		button.modulate = Color.WHITE
		if i == _selected_index and _phase != Phase.ANSWERING:
			button.modulate = Color(1.0, 1.0, 0.7)
		if _phase in [Phase.FEEDBACK, Phase.AWAITING_ACK, Phase.RESTORED] and i == _correct_index:
			button.modulate = COLOR_CORRECT

	var show_feedback := _phase in [Phase.FEEDBACK, Phase.AWAITING_ACK, Phase.RESTORED]
	_status_label.visible = show_feedback
	_explanation_label.visible = show_feedback
	if show_feedback:
		if _phase == Phase.RESTORED:
			_status_label.text = "Already completed."
			if _has_feedback_result:
				_status_label.text += " Your first attempt was %s." % \
						("correct" if _feedback_correct else "incorrect")
		else:
			_status_label.text = "Correct!" if _feedback_correct else "Not quite."
		_status_label.add_theme_color_override("font_color",
				COLOR_CORRECT if _feedback_correct or _phase != Phase.FEEDBACK and not _has_feedback_result
				else COLOR_INCORRECT)
		var explanation := _feedback_text
		if explanation.is_empty():
			explanation = _question_explanation(_question)
		if explanation.is_empty() and _phase == Phase.RESTORED:
			explanation = str(_existing_record.get("explanation", ""))
		_explanation_label.text = explanation
		_explanation_label.visible = not explanation.is_empty()

	_error_label.visible = not _error_text.is_empty()
	_error_label.text = _error_text

	_retry_button.visible = _phase in [Phase.ANSWER_RETRY, Phase.AWAITING_ANSWER]
	_retry_button.disabled = _phase != Phase.ANSWER_RETRY
	continue_button.visible = show_feedback
	continue_button.disabled = _phase == Phase.AWAITING_ACK
	_close_button.disabled = _closed_emitted


func _grab_initial_focus() -> void:
	if not is_inside_tree():
		return
	match _phase:
		Phase.RESTORED, Phase.FEEDBACK:
			continue_button.grab_focus()
		Phase.ANSWER_RETRY:
			_retry_button.grab_focus()
		_:
			for button in option_buttons:
				if not button.disabled:
					button.grab_focus()
					return
			_close_button.grab_focus()


# --- Handlers --------------------------------------------------------------

func _on_option_pressed(index: int) -> void:
	if _phase != Phase.ANSWERING or _closed_emitted:
		return
	_pending_index = index
	_selected_index = index
	_error_text = ""
	_phase = Phase.AWAITING_ANSWER
	_refresh()
	answer_selected.emit(index)


func _on_retry_pressed() -> void:
	if _phase != Phase.ANSWER_RETRY or _closed_emitted or _pending_index < 0:
		return
	_error_text = ""
	_phase = Phase.AWAITING_ANSWER
	_refresh()
	answer_selected.emit(_pending_index)


func _on_continue_pressed() -> void:
	if _closed_emitted:
		return
	if _phase != Phase.FEEDBACK and _phase != Phase.RESTORED:
		return
	var was_restored := _phase == Phase.RESTORED
	_error_text = ""
	if not was_restored:
		_phase = Phase.AWAITING_ACK
	else:
		# Restored dialogs have no further state to lock; guard re-entry via disabled.
		continue_button.disabled = true
	_refresh()
	if was_restored:
		continue_button.disabled = true
	feedback_acknowledged.emit()


func _on_close_pressed() -> void:
	if _closed_emitted:
		return
	_closed_emitted = true
	_refresh()
	closed.emit()


# --- Question / record parsing (defensive about key names) -----------------

func _question_text(question: Dictionary) -> String:
	for key in ["prompt", "question", "text", "stem", "content"]:
		if question.has(key) and not str(question[key]).is_empty():
			return str(question[key])
	return ""


func _question_explanation(question: Dictionary) -> String:
	return str(question.get("explanation", question.get("rationale", "")))


func _question_options(question: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = null
	for key in ["options", "choices", "answers"]:
		if question.has(key):
			raw = question[key]
			break
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				result.append(str(entry.get("text", entry.get("label", entry.get("name", "")))))
			else:
				result.append(str(entry))
	return result


func _option_prefix(index: int) -> String:
	if index >= 0 and index < OPTION_LABELS.length():
		return OPTION_LABELS[index]
	return str(index + 1)


func _record_is_completed(record: Dictionary) -> bool:
	if record.is_empty():
		return false
	if record.has("completed"):
		return bool(record["completed"])
	return record.has("first_attempt_index") or record.has("selected_index") \
			or record.has("first_attempt")


func _record_first_attempt_index(record: Dictionary) -> int:
	var response: Variant = record.get("first_response")
	if response is Dictionary:
		return int(response.get("selected_index", response.get("index", -1)))
	return -1


func _record_correct_index(_record: Dictionary) -> int:
	return int(_question.get("correct_index", -1))
