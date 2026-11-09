class_name CharacterSheet
extends Control

## CharacterSheet — SBL-W6-003 Character Progression UI Sheet
## Requirements: GDD-005/006/007/098/099, FR-PRO-001.

signal closed

var stats: CharacterStats = null
var kurei_tree: KureiTree = null

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

@onready var kurei_header: Label = $Panel/Margin/VBox/KureiSection/KureiHeader
@onready var btn_solar: Button = $Panel/Margin/VBox/KureiSection/SkillGrid/BtnSolarFlare
@onready var btn_prism: Button = $Panel/Margin/VBox/KureiSection/SkillGrid/BtnCelestialPrism
@onready var btn_aegis: Button = $Panel/Margin/VBox/KureiSection/SkillGrid/BtnGlacialAegis
@onready var btn_void_shift: Button = $Panel/Margin/VBox/KureiSection/SkillGrid/BtnVoidShift
@onready var btn_mastery: Button = $Panel/Margin/VBox/KureiSection/SkillGrid/BtnPhaseMastery
@onready var btn_respec: Button = $Panel/Margin/VBox/KureiSection/RespecButton

func _ready() -> void:
	vit_btn.pressed.connect(_on_allocate.bind(CharacterStats.ATTR_VITALITY))
	res_btn.pressed.connect(_on_allocate.bind(CharacterStats.ATTR_RESONANCE))
	agi_btn.pressed.connect(_on_allocate.bind(CharacterStats.ATTR_AGILITY))
	foc_btn.pressed.connect(_on_allocate.bind(CharacterStats.ATTR_FOCUS))
	close_btn.pressed.connect(_on_close_pressed)

	if btn_solar != null:
		btn_solar.pressed.connect(func(): _on_unlock_skill(&"solar_flare"))
	if btn_prism != null:
		btn_prism.pressed.connect(func(): _on_unlock_skill(&"celestial_prism"))
	if btn_aegis != null:
		btn_aegis.pressed.connect(func(): _on_unlock_skill(&"glacial_aegis"))
	if btn_void_shift != null:
		btn_void_shift.pressed.connect(func(): _on_unlock_skill(&"void_shift"))
	if btn_mastery != null:
		btn_mastery.pressed.connect(func(): _on_unlock_skill(&"phase_mastery"))
	if btn_respec != null:
		btn_respec.pressed.connect(_on_respec)

	if stats != null:
		refresh()

func set_stats(new_stats: CharacterStats) -> void:
	stats = new_stats
	if is_inside_tree():
		refresh()

func set_kurei_tree(new_tree: KureiTree) -> void:
	kurei_tree = new_tree
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

	if kurei_tree != null:
		kurei_tree.sync_with_level(stats.level)
		if kurei_header != null:
			kurei_header.text = "Kurei Art Skill Tree (Talent Points: %d Available)" % kurei_tree.get_unspent_points()
		_update_skill_button(btn_solar, &"solar_flare")
		_update_skill_button(btn_prism, &"celestial_prism")
		_update_skill_button(btn_aegis, &"glacial_aegis")
		_update_skill_button(btn_void_shift, &"void_shift")
		_update_skill_button(btn_mastery, &"phase_mastery")

func _update_skill_button(btn: Button, skill_id: StringName) -> void:
	if btn == null or kurei_tree == null:
		return
	var node: Dictionary = KureiTree.SKILL_NODES.get(skill_id, {})
	var sname: String = String(node.get("name", String(skill_id)))
	var cost: int = int(node.get("cost", 0))

	if kurei_tree.is_skill_unlocked(skill_id):
		btn.text = "✓ %s (Mastered)" % sname
		btn.disabled = true
	elif kurei_tree.can_unlock_skill(skill_id):
		btn.text = "+ %s (%d Pts)" % [sname, cost]
		btn.disabled = false
	else:
		btn.text = "🔒 %s (%d Pts)" % [sname, cost]
		btn.disabled = true

func _on_unlock_skill(skill_id: StringName) -> void:
	if kurei_tree != null and kurei_tree.unlock_skill(skill_id) == OK:
		refresh()

func _on_respec() -> void:
	if kurei_tree != null:
		kurei_tree.respec_talents()
		refresh()

func _on_allocate(attr: StringName) -> void:
	if stats != null and stats.allocate_point(attr):
		refresh()

func _on_close_pressed() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_character") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
