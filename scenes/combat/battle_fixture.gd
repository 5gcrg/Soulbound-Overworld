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
var ren_sp: int = 2
var max_sp: int = 2
var enemy_intent: StringName = &"Strike"
var last_player_action: StringName = &""
var _continued_emitted: bool = false

var kurei: KureiSystem = KureiSystem.new()

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var outcome_label: Label = $VBoxContainer/OutcomeLabel
@onready var ren_pips_label: Label = $VBoxContainer/HBoxContainer/RenPanel/RenPips
@onready var enemy_pips_label: Label = $VBoxContainer/HBoxContainer/EnemyPanel/EnemyPips
@onready var enemy_intent_label: Label = $VBoxContainer/HBoxContainer/EnemyPanel/EnemyIntent
@onready var attack_button: Button = $VBoxContainer/Actions/AttackButton
@onready var defend_button: Button = $VBoxContainer/Actions/DefendButton
@onready var kurei_button: Button = $VBoxContainer/Actions/KureiButton
@onready var item_button: Button = $VBoxContainer/Actions/ItemButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton

@onready var kurei_menu: HBoxContainer = $VBoxContainer/KureiMenu
@onready var flame_burst_btn: Button = $VBoxContainer/KureiMenu/FlameBurstButton
@onready var lumina_lance_btn: Button = $VBoxContainer/KureiMenu/LuminaLanceButton
@onready var torrent_surge_btn: Button = $VBoxContainer/KureiMenu/TorrentSurgeButton
@onready var cancel_kurei_btn: Button = $VBoxContainer/KureiMenu/CancelKureiButton

func _ready() -> void:
	attack_button.pressed.connect(func() -> void: request_action(&"attack"))
	defend_button.pressed.connect(func() -> void: request_action(&"defend"))
	kurei_button.pressed.connect(_on_kurei_button_pressed)
	if item_button != null:
		item_button.pressed.connect(func() -> void: request_action(&"item"))
	cancel_kurei_btn.pressed.connect(func() -> void: kurei_menu.visible = false)

	flame_burst_btn.pressed.connect(func() -> void: request_action(&"kurei_flame_burst"))
	lumina_lance_btn.pressed.connect(func() -> void: request_action(&"kurei_lumina_lance"))
	torrent_surge_btn.pressed.connect(func() -> void: request_action(&"kurei_torrent_surge"))

	continue_button.pressed.connect(_on_continue_pressed)
	_update_ui()

func _on_kurei_button_pressed() -> void:
	if phase != Phase.PLAYER:
		return
	kurei_menu.visible = not kurei_menu.visible
	_update_kurei_buttons()

func _update_kurei_buttons() -> void:
	if not kurei_menu.visible:
		return
	flame_burst_btn.disabled = not kurei.can_cast(&"flame_burst", ren_sp)
	lumina_lance_btn.disabled = not kurei.can_cast(&"lumina_lance", ren_sp)
	torrent_surge_btn.disabled = not kurei.can_cast(&"torrent_surge", ren_sp)

func request_action(action: StringName) -> bool:
	if phase != Phase.PLAYER:
		return false

	var is_kurei: bool = action.begins_with("kurei_")
	if action != &"attack" and action != &"defend" and action != &"item" and not is_kurei:
		return false

	if is_kurei:
		var skill_id: StringName = StringName(String(action).trim_prefix("kurei_"))
		if not kurei.can_cast(skill_id, ren_sp):
			return false
		var cast_res: Dictionary = kurei.cast_skill(skill_id, ren_sp)
		if cast_res.get("error", OK) != OK:
			return false
		ren_sp -= int(cast_res["pip_cost"])

		if skill_id == &"flame_burst":
			enemy_pips -= 2
		elif skill_id == &"lumina_lance":
			enemy_pips -= 1
		elif skill_id == &"torrent_surge":
			ren_pips += 1

		if enemy_pips <= 0:
			enemy_pips = 0
			phase = Phase.VICTORY
			_update_ui()
			return true

	last_player_action = action
	phase = Phase.ENEMY
	kurei_menu.visible = false

	if action == &"attack":
		enemy_pips -= 1
		if enemy_pips <= 0:
			enemy_pips = 0
			phase = Phase.VICTORY
			_update_ui()
			return true
	elif action == &"item":
		ren_pips += 1

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
	kurei.tick_cooldowns()
	ren_sp = mini(max_sp, ren_sp + 1)
	_update_ui()

func _on_continue_pressed() -> void:
	if _continued_emitted or (phase != Phase.VICTORY and phase != Phase.DEFEAT):
		return
	_continued_emitted = true
	continued.emit()

func _update_ui() -> void:
	if not is_node_ready():
		return

	ren_pips_label.text = "Ren HP: %d | SP: %d" % [ren_pips, ren_sp]
	enemy_pips_label.text = "Enemy HP: %d" % enemy_pips
	enemy_intent_label.text = "Intent: %s" % enemy_intent
	status_label.text = "Phase: %s" % Phase.keys()[phase]

	var is_player: bool = (phase == Phase.PLAYER)
	var is_terminal: bool = (phase == Phase.VICTORY or phase == Phase.DEFEAT)

	attack_button.disabled = not is_player
	defend_button.disabled = not is_player
	kurei_button.disabled = not is_player
	if item_button != null:
		item_button.disabled = not is_player
	continue_button.visible = is_terminal
	continue_button.disabled = not is_terminal or _continued_emitted

	_update_kurei_buttons()

	if phase == Phase.VICTORY:
		outcome_label.text = "Outcome: VICTORY"
	elif phase == Phase.DEFEAT:
		outcome_label.text = "Outcome: DEFEAT"
	else:
		outcome_label.text = "Outcome: In Progress"
