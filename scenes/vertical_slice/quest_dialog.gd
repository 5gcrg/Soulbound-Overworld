class_name QuestDialog
extends Control

## QuestDialog — SBL-W4-001 M2 interactive quest and educational practice dialog.
## Requirements: GDD-067/068/069/071/119, FR-QST-001, FR-EDU-001/002/003.
## Presents quest context, immediate instructional feedback, and completion-gated progression.

signal closed
signal quest_accepted
signal practice_completed(choice: String, correct: bool)
signal quest_turned_in

var _progress: SliceProgress = null

@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBox/TitleLabel
@onready var speaker_label: Label = $CenterContainer/Panel/MarginContainer/VBox/SpeakerLabel
@onready var dialogue_text: Label = $CenterContainer/Panel/MarginContainer/VBox/DialogueText
@onready var feedback_label: Label = $CenterContainer/Panel/MarginContainer/VBox/FeedbackLabel
@onready var button_container: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBox/Buttons
@onready var accept_button: Button = $CenterContainer/Panel/MarginContainer/VBox/Buttons/AcceptButton
@onready var option_a_button: Button = $CenterContainer/Panel/MarginContainer/VBox/Buttons/OptionAButton
@onready var option_b_button: Button = $CenterContainer/Panel/MarginContainer/VBox/Buttons/OptionBButton
@onready var proceed_button: Button = $CenterContainer/Panel/MarginContainer/VBox/Buttons/ProceedButton
@onready var turn_in_button: Button = $CenterContainer/Panel/MarginContainer/VBox/Buttons/TurnInButton
@onready var close_button: Button = $CenterContainer/Panel/MarginContainer/VBox/Buttons/CloseButton

func _ready() -> void:
	accept_button.pressed.connect(_on_accept_pressed)
	option_a_button.pressed.connect(func() -> void: _on_practice_choice(SliceProgress.CHOICE_MATCH))
	option_b_button.pressed.connect(func() -> void: _on_practice_choice(SliceProgress.CHOICE_MISMATCH))
	proceed_button.pressed.connect(_on_close_pressed)
	turn_in_button.pressed.connect(_on_turn_in_pressed)
	close_button.pressed.connect(_on_close_pressed)
	_refresh_view()

func set_progress(progress: SliceProgress) -> void:
	_progress = progress
	if is_node_ready():
		_refresh_view()

func _refresh_view() -> void:
	if _progress == null or not _progress.ready:
		title_label.text = "Spirit Elder"
		speaker_label.text = "Spirit Elder:"
		dialogue_text.text = "The spirit stream is quiet. Profile store not initialized."
		_hide_all_buttons()
		close_button.visible = true
		feedback_label.text = ""
		return

	_hide_all_buttons()
	feedback_label.text = ""

	match _progress.stage:
		SliceProgress.Stage.OFFERED:
			title_label.text = "Spirit Elder — Trial of Harmony"
			speaker_label.text = "Spirit Elder:"
			dialogue_text.text = "Greetings, Ren. An ancient disruption has manifested in the southern field. Before facing it, you must evaluate your approach to resonant stabilization. Will you undertake the practice challenge?"
			accept_button.visible = true
			close_button.visible = true

		SliceProgress.Stage.PRACTICE:
			title_label.text = "Educational Practice — Critical Thinking"
			speaker_label.text = "Competency Assessment Scenario:"
			dialogue_text.text = "An ancient archive barrier is destabilizing. The resonance frequency fluctuates inversely with the ambient spirit stream. How should you approach stabilization?"
			option_a_button.visible = true
			option_b_button.visible = true

		SliceProgress.Stage.BATTLE:
			title_label.text = "Spirit Elder — Active Mission"
			speaker_label.text = "Spirit Elder:"
			var attempt_str: String = "Correct" if _progress.attempt_correct else "Completed with Review"
			dialogue_text.text = "Your practice assessment has been archived (Outcome: %s). The corrupted sentinel awaits in the southern field (red zone). Confront and defeat it to secure the seal." % attempt_str
			close_button.visible = true

		SliceProgress.Stage.TURN_IN:
			title_label.text = "Spirit Elder — Mission Accomplished"
			speaker_label.text = "Spirit Elder:"
			dialogue_text.text = "Splendid work, Ren! The corrupted sentinel is pacified and balance is restored. Turn in your mission to finalize your educational and combat record."
			turn_in_button.visible = true

		SliceProgress.Stage.COMPLETE:
			title_label.text = "Spirit Elder — Chapter Milestone Complete"
			speaker_label.text = "Spirit Elder:"
			var outcome_text: String = "100% Correct" if _progress.attempt_correct else "Completed (Completion Gated)"
			dialogue_text.text = "The vertical slice trial is complete! Your record (%s, Choice: '%s') is permanently saved in profile storage." % [outcome_text, _progress.first_choice]
			close_button.visible = true

func _on_accept_pressed() -> void:
	if _progress == null:
		return
	var err: Error = _progress.accept_quest()
	if err == OK:
		quest_accepted.emit()
		_refresh_view()
	else:
		feedback_label.text = "Save error: Failed to record quest acceptance (Error %d). Press Escape or Close to exit." % err
		feedback_label.modulate = Color(1.0, 0.4, 0.4)
		close_button.visible = true
		close_button.grab_focus()

func _on_practice_choice(choice: String) -> void:
	if _progress == null or _progress.stage != SliceProgress.Stage.PRACTICE:
		return

	var err: Error = _progress.finish_practice(choice)
	if err != OK:
		feedback_label.text = "Save error: Failed to record practice completion (Error %d). Press Escape or Close to exit." % err
		feedback_label.modulate = Color(1.0, 0.4, 0.4)
		close_button.visible = true
		close_button.grab_focus()
		return

	var is_correct: bool = (choice == SliceProgress.CHOICE_MATCH)
	practice_completed.emit(choice, is_correct)

	option_a_button.visible = false
	option_b_button.visible = false
	proceed_button.visible = true

	if is_correct:
		feedback_label.text = "Feedback: Correct! Harmonizing aligns opposing flows without causing catastrophic resonance."
		feedback_label.modulate = Color(0.3, 0.95, 0.4)
	else:
		feedback_label.text = "Feedback: Incorrect: Forcing energy causes dangerous resonance overload. However, analyzing failure develops perseverance. Per curriculum rules, progression is completion-gated: combat is now unlocked."
		feedback_label.modulate = Color(1.0, 0.75, 0.3)

func _on_turn_in_pressed() -> void:
	if _progress == null:
		return
	var err: Error = _progress.turn_in()
	if err == OK:
		quest_turned_in.emit()
		_refresh_view()
	else:
		feedback_label.text = "Save error: Failed to record quest turn-in (Error %d). Press Escape or Close to exit." % err
		feedback_label.modulate = Color(1.0, 0.4, 0.4)
		close_button.visible = true
		close_button.grab_focus()

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("toggle_character") or event.is_action_pressed("toggle_inventory") or event.is_action_pressed("toggle_settings"):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()

func _hide_all_buttons() -> void:
	accept_button.visible = false
	option_a_button.visible = false
	option_b_button.visible = false
	proceed_button.visible = false
	turn_in_button.visible = false
	close_button.visible = false
