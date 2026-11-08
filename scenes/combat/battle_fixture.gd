class_name BattleFixture
extends Control

signal continued

enum Phase {
	PLAYER,
	ENEMY,
	VICTORY,
	DEFEAT,
}

var phase: Phase = Phase.PLAYER
var ren_pips: int = 1
var enemy_pips: int = 2
var enemy_intent: StringName = &"Strike"
var last_player_action: StringName = &""
var _continued_emitted: bool = false

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var outcome_label: Label = $VBoxContainer/OutcomeLabel
@onready var ren_pips_label: Label = $VBoxContainer/HBoxContainer/RenPanel/RenPips
@onready var enemy_pips_label: Label = $VBoxContainer/HBoxContainer/EnemyPanel/EnemyPips
@onready var enemy_intent_label: Label = $VBoxContainer/HBoxContainer/EnemyPanel/EnemyIntent
@onready var attack_button: Button = $VBoxContainer/Actions/AttackButton
@onready var defend_button: Button = $VBoxContainer/Actions/DefendButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton

func _ready() -> void:
	attack_button.pressed.connect(func() -> void: request_action(&"attack"))
	defend_button.pressed.connect(func() -> void: request_action(&"defend"))
	continue_button.pressed.connect(_on_continue_pressed)
	_update_ui()

func request_action(action: StringName) -> bool:
	if phase != Phase.PLAYER:
		return false
	if action != &"attack" and action != &"defend":
		return false

	last_player_action = action
	phase = Phase.ENEMY

	if action == &"attack":
		enemy_pips -= 1
		if enemy_pips <= 0:
			enemy_pips = 0
			phase = Phase.VICTORY
			_update_ui()
			return true

	_update_ui()
	_resolve_enemy_turn.call_deferred()
	return true

func _resolve_enemy_turn() -> void:
	if phase != Phase.ENEMY:
		return

	if enemy_intent == &"Strike":
		if last_player_action != &"defend":
			ren_pips -= 1
			if ren_pips <= 0:
				ren_pips = 0
				phase = Phase.DEFEAT
				_update_ui()
				return
	# Recover is harmless to the player

	enemy_intent = &"Recover" if enemy_intent == &"Strike" else &"Strike"
	phase = Phase.PLAYER
	_update_ui()

func _on_continue_pressed() -> void:
	if _continued_emitted or (phase != Phase.VICTORY and phase != Phase.DEFEAT):
		return
	_continued_emitted = true
	continued.emit()

func _update_ui() -> void:
	if not is_node_ready():
		return

	ren_pips_label.text = "Ren HP: %d" % ren_pips
	enemy_pips_label.text = "Enemy HP: %d" % enemy_pips
	enemy_intent_label.text = "Intent: %s" % enemy_intent
	status_label.text = "Phase: %s" % Phase.keys()[phase]

	var is_player: bool = (phase == Phase.PLAYER)
	var is_terminal: bool = (phase == Phase.VICTORY or phase == Phase.DEFEAT)

	attack_button.disabled = not is_player
	defend_button.disabled = not is_player
	continue_button.visible = is_terminal
	continue_button.disabled = not is_terminal or _continued_emitted

	if phase == Phase.VICTORY:
		outcome_label.text = "Outcome: VICTORY"
	elif phase == Phase.DEFEAT:
		outcome_label.text = "Outcome: DEFEAT"
	else:
		outcome_label.text = "Outcome: In Progress"
