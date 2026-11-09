class_name CharacterSheet
extends Control

## CharacterSheet — SBL-W6-003 Character Progression UI Sheet
## Requirements: GDD-005/006/007/098/099, FR-PRO-001.

signal closed

var stats: CharacterStats = null
var kurei_tree: KureiTree = null

@onready var level_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/HeaderBox/LevelLabel", "Panel/Margin/VBox/HeaderBox/LevelLabel"]) as Label
@onready var xp_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/HeaderBox/XpLabel", "Panel/Margin/VBox/HeaderBox/XpLabel"]) as Label
@onready var unspent_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/HeaderBox/UnspentLabel", "Panel/Margin/VBox/HeaderBox/UnspentLabel"]) as Label

@onready var vit_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/Grid/VitRow/ValueLabel", "Panel/Margin/VBox/Grid/VitRow/ValueLabel"]) as Label
@onready var res_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/Grid/ResRow/ValueLabel", "Panel/Margin/VBox/Grid/ResRow/ValueLabel"]) as Label
@onready var agi_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/Grid/AgiRow/ValueLabel", "Panel/Margin/VBox/Grid/AgiRow/ValueLabel"]) as Label
@onready var foc_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/Grid/FocRow/ValueLabel", "Panel/Margin/VBox/Grid/FocRow/ValueLabel"]) as Label

@onready var vit_btn: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/Grid/VitRow/AddButton", "Panel/Margin/VBox/Grid/VitRow/AddButton"]) as Button
@onready var res_btn: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/Grid/ResRow/AddButton", "Panel/Margin/VBox/Grid/ResRow/AddButton"]) as Button
@onready var agi_btn: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/Grid/AgiRow/AddButton", "Panel/Margin/VBox/Grid/AgiRow/AddButton"]) as Button
@onready var foc_btn: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/Grid/FocRow/AddButton", "Panel/Margin/VBox/Grid/FocRow/AddButton"]) as Button

@onready var combat_stats_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/CombatStatsLabel", "Panel/Margin/VBox/CombatStatsLabel"]) as Label
@onready var close_btn: Button = $Panel/Margin/VBox/CloseButton

@onready var kurei_header: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/KureiHeader", "Panel/Margin/VBox/KureiSection/KureiHeader"]) as Label
@onready var equipped_header: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/EquippedHeader"]) as Label
@onready var feedback_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/FeedbackLabel"]) as Label
@onready var equipped_container: GridContainer = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/EquippedContainer"]) as GridContainer
@onready var available_box: VBoxContainer = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/AvailableBox"]) as VBoxContainer
@onready var available_container: GridContainer = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/AvailableBox/AvailableContainer"]) as GridContainer

@onready var btn_solar: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/SkillGrid/BtnSolarFlare", "Panel/Margin/VBox/KureiSection/SkillGrid/BtnSolarFlare"]) as Button
@onready var btn_prism: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/SkillGrid/BtnCelestialPrism", "Panel/Margin/VBox/KureiSection/SkillGrid/BtnCelestialPrism"]) as Button
@onready var btn_aegis: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/SkillGrid/BtnGlacialAegis", "Panel/Margin/VBox/KureiSection/SkillGrid/BtnGlacialAegis"]) as Button
@onready var btn_void_shift: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/SkillGrid/BtnVoidShift", "Panel/Margin/VBox/KureiSection/SkillGrid/BtnVoidShift"]) as Button
@onready var btn_mastery: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/SkillGrid/BtnPhaseMastery", "Panel/Margin/VBox/KureiSection/SkillGrid/BtnPhaseMastery"]) as Button
@onready var btn_respec: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/KureiSection/RespecButton", "Panel/Margin/VBox/KureiSection/RespecButton"]) as Button

var _dynamic_equip_buttons: Array[Button] = []

func _find_node(paths: Array) -> Node:
	for p in paths:
		if has_node(String(p)):
			return get_node(String(p))
	for p in paths:
		var node_name: String = String(p).get_file()
		var found := find_child(node_name, true, false)
		if found != null:
			return found
	return null

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

	setup_focus()

	if stats != null:
		refresh()

func get_focusable_controls() -> Array[Control]:
	var list: Array[Control] = [
		vit_btn,
		res_btn,
		agi_btn,
		foc_btn
	]
	for btn in _dynamic_equip_buttons:
		if btn != null and is_instance_valid(btn):
			list.append(btn)
	list.append_array([
		btn_solar,
		btn_prism,
		btn_aegis,
		btn_void_shift,
		btn_mastery,
		btn_respec,
		close_btn
	])
	var res: Array[Control] = []
	for c in list:
		if c != null and is_instance_valid(c):
			res.append(c)
	return res

func setup_focus() -> void:
	var controls := get_focusable_controls()
	if controls.is_empty():
		return
	for i in range(controls.size()):
		var c := controls[i]
		c.focus_mode = Control.FOCUS_ALL
		var next_ctrl := controls[(i + 1) % controls.size()]
		var prev_ctrl := controls[(i - 1 + controls.size()) % controls.size()]
		c.focus_next = next_ctrl.get_path()
		c.focus_previous = prev_ctrl.get_path()
		_apply_visible_focus(c)

	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focused == null or not is_ancestor_of(focused):
		for c in controls:
			if not c.disabled:
				c.grab_focus()
				break

static func _apply_visible_focus(control: Control) -> void:
	var focus_box := StyleBoxFlat.new()
	focus_box.draw_center = false
	focus_box.border_width_left = 2
	focus_box.border_width_top = 2
	focus_box.border_width_right = 2
	focus_box.border_width_bottom = 2
	focus_box.border_color = Color(1.0, 0.85, 0.1, 1.0)
	focus_box.corner_radius_top_left = 4
	focus_box.corner_radius_top_right = 4
	focus_box.corner_radius_bottom_left = 4
	focus_box.corner_radius_bottom_right = 4
	control.add_theme_stylebox_override("focus", focus_box)

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
		_refresh_equipped_section()

func _refresh_equipped_section() -> void:
	if kurei_tree == null:
		return
	if equipped_header != null:
		equipped_header.text = "Equipped Spells (%d/%d Slots Used)" % [kurei_tree.equipped_skills.size(), KureiTree.MAX_EQUIPPED_SKILLS]

	if feedback_label != null:
		feedback_label.visible = not feedback_label.text.is_empty()

	_dynamic_equip_buttons.clear()
	if equipped_container != null:
		for child in equipped_container.get_children():
			equipped_container.remove_child(child)
			child.queue_free()
		for sid: StringName in kurei_tree.equipped_skills:
			var sname: String = String(KureiTree.SKILL_NODES.get(sid, {}).get("name", String(sid)))
			var unequip_btn := Button.new()
			unequip_btn.name = "UnequipBtn_" + String(sid)
			unequip_btn.text = "Unequip: %s" % sname
			unequip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			unequip_btn.add_theme_font_size_override("font_size", 10)
			unequip_btn.custom_minimum_size = Vector2(100, 22)
			unequip_btn.disabled = not kurei_tree.can_unequip_skill(sid)
			unequip_btn.pressed.connect(_on_unequip_skill.bind(sid))
			equipped_container.add_child(unequip_btn)
			_dynamic_equip_buttons.append(unequip_btn)

	var unequipped_active: Array[StringName] = []
	for sid: StringName in kurei_tree.unlocked_skills:
		if kurei_tree.is_skill_active(sid) and not kurei_tree.is_skill_equipped(sid):
			unequipped_active.append(sid)

	if available_box != null:
		available_box.visible = not unequipped_active.is_empty()

	if available_container != null:
		for child in available_container.get_children():
			available_container.remove_child(child)
			child.queue_free()
		var slots_full: bool = (kurei_tree.equipped_skills.size() >= KureiTree.MAX_EQUIPPED_SKILLS)
		for sid: StringName in unequipped_active:
			var sname: String = String(KureiTree.SKILL_NODES.get(sid, {}).get("name", String(sid)))
			var equip_btn := Button.new()
			equip_btn.name = "EquipBtn_" + String(sid)
			equip_btn.text = "Equip: %s" % sname
			equip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			equip_btn.add_theme_font_size_override("font_size", 10)
			equip_btn.custom_minimum_size = Vector2(100, 22)
			equip_btn.disabled = slots_full
			equip_btn.pressed.connect(_on_equip_skill.bind(sid))
			available_container.add_child(equip_btn)
			_dynamic_equip_buttons.append(equip_btn)

	setup_focus()

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
	if kurei_tree != null:
		var err: Error = kurei_tree.unlock_skill(skill_id)
		if err == OK:
			if kurei_tree.is_skill_active(skill_id):
				if kurei_tree.is_skill_equipped(skill_id):
					if feedback_label != null:
						feedback_label.text = ""
				else:
					if feedback_label != null:
						feedback_label.text = "Unlocked — equip in Character"
			else:
				if feedback_label != null:
					feedback_label.text = ""
			refresh()

func _on_equip_skill(skill_id: StringName) -> void:
	if kurei_tree != null and kurei_tree.can_equip_skill(skill_id):
		kurei_tree.equip_skill(skill_id)
		if feedback_label != null:
			feedback_label.text = ""
		refresh()

func _on_unequip_skill(skill_id: StringName) -> void:
	if kurei_tree != null and kurei_tree.can_unequip_skill(skill_id):
		kurei_tree.unequip_skill(skill_id)
		refresh()

func _on_respec() -> void:
	if kurei_tree != null:
		kurei_tree.respec_talents()
		if feedback_label != null:
			feedback_label.text = ""
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
