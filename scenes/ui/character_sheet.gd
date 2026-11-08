class_name CharacterSheet
extends Control

## CharacterSheet — SBL-W6-003 Character Progression UI Sheet
## Requirements: GDD-005/006/007/098/099, FR-PRO-001.

signal closed

var stats: CharacterStats = null

@onready var level_label: Label = $Panel/Margin/VBox/HeaderBox/LevelLabel
@onready var xp_label: Label = $Panel/Margin/VBox/HeaderBox/XpLabel
@onready var unspent_label: Label = $Panel/Margin/VBox/HeaderBox/UnspentLabel

@onready var vit_label: Label = $Panel/Margin/VBox/Grid/VitRow/ValueLabel
@onready var res_label: Label = $Panel/Margin/VBox/Grid/ResRow/ValueLabel
@onready var agi_label: Label = $Panel/Margin/VBox/Grid/AgiRow/ValueLabel
@onready var foc_label: Label = $Panel/Margin/VBox/Grid/FocRow/ValueLabel

@onready var vit_btn: Button = $Panel/Margin/VBox/Grid/VitRow/AddButton
@onready var res_btn: Button = $Panel/Margin/VBox/Grid/ResRow/AddButton
@onready var agi_btn: Button = $Panel/Margin/VBox/Grid/AgiRow/AddButton
@onready var foc_btn: Button = $Panel/Margin/VBox/Grid/FocRow/AddButton

@onready var combat_stats_label: Label = $Panel/Margin/VBox/CombatStatsLabel
@onready var close_btn: Button = $Panel/Margin/VBox/CloseButton

func _ready() -> void:
	vit_btn.pressed.connect(_on_allocate.bind(CharacterStats.ATTR_VITALITY))
	res_btn.pressed.connect(_on_allocate.bind(CharacterStats.ATTR_RESONANCE))
	agi_btn.pressed.connect(_on_allocate.bind(CharacterStats.ATTR_AGILITY))
	foc_btn.pressed.connect(_on_allocate.bind(CharacterStats.ATTR_FOCUS))
	close_btn.pressed.connect(_on_close_pressed)

	if stats != null:
		refresh()

func set_stats(new_stats: CharacterStats) -> void:
	stats = new_stats
	if is_inside_tree():
		refresh()

func refresh() -> void:
	if stats == null:
		return
	level_label.text = "Level %d" % stats.level
	xp_label.text = "XP: %d / %d" % [stats.xp, stats.get_xp_for_next_level()]
	unspent_label.text = "Available Attribute Points: %d" % stats.unspent_points

	vit_label.text = "%d" % stats.vitality
	res_label.text = "%d" % stats.resonance
	agi_label.text = "%d" % stats.agility
	foc_label.text = "%d" % stats.focus

	var has_points: bool = stats.unspent_points > 0
	vit_btn.disabled = not has_points
	res_btn.disabled = not has_points
	agi_btn.disabled = not has_points
	foc_btn.disabled = not has_points

	combat_stats_label.text = "Max HP: %d   |   Spirit Power: %d" % [stats.get_max_hp(), stats.get_spirit_power()]

func _on_allocate(attr: StringName) -> void:
	if stats != null and stats.allocate_point(attr):
		refresh()

func _on_close_pressed() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_character") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
