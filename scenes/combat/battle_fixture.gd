class_name BattleFixture
extends Control

signal continued
signal action_performed(action_type: StringName)

enum Phase {
	PLAYER,
	ENEMY,
	VICTORY,
	DEFEAT,
}

const HEALING_ITEMS: Array[String] = [
	"spirit_salve",
	"health_elixir",
	"potion",
	"potions",
	"healing_herb"
]

const BASELINE_MAX_SP: int = 2

var phase: Phase = Phase.PLAYER
var ren_pips: int = 1
var max_ren_pips: int = 3
var enemy_pips: int = 2
var ren_sp: int = 2
var max_sp: int = BASELINE_MAX_SP
var enemy_intent: StringName = &"Strike"
var last_player_action: StringName = &""
var _continued_emitted: bool = false

var inventory: InventoryManager = null
var kurei_tree: KureiTree = null:
	set(value):
		if kurei_tree == value:
			return
		if kurei_tree != null:
			if kurei_tree.skill_unlocked.is_connected(_on_kurei_tree_updated):
				kurei_tree.skill_unlocked.disconnect(_on_kurei_tree_updated)
			if kurei_tree.talents_reset.is_connected(_on_kurei_tree_updated):
				kurei_tree.talents_reset.disconnect(_on_kurei_tree_updated)
		kurei_tree = value
		if kurei_tree != null:
			if not kurei_tree.skill_unlocked.is_connected(_on_kurei_tree_updated):
				kurei_tree.skill_unlocked.connect(_on_kurei_tree_updated)
			if not kurei_tree.talents_reset.is_connected(_on_kurei_tree_updated):
				kurei_tree.talents_reset.connect(_on_kurei_tree_updated)
		apply_kurei_tree_capacity()
var standalone_consumables: int = 0
var kurei: KureiSystem = KureiSystem.new()
var ren_statuses: StatusEngine = StatusEngine.new()
var enemy_statuses: StatusEngine = StatusEngine.new()

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

@onready var kurei_menu: Container = $VBoxContainer/KureiMenu
@onready var flame_burst_btn: Button = _find_menu_button("FlameBurstButton")
@onready var lumina_lance_btn: Button = _find_menu_button("LuminaLanceButton")
@onready var torrent_surge_btn: Button = _find_menu_button("TorrentSurgeButton")
@onready var cancel_kurei_btn: Button = $VBoxContainer/KureiMenu/CancelKureiButton

var _active_skill_buttons: Dictionary = {} # StringName -> Button

func _find_menu_button(btn_name: String) -> Button:
	if has_node("VBoxContainer/KureiMenu/" + btn_name):
		return get_node("VBoxContainer/KureiMenu/" + btn_name) as Button
	return null

func _ready() -> void:
	attack_button.pressed.connect(func() -> void: request_action(&"attack"))
	defend_button.pressed.connect(func() -> void: request_action(&"defend"))
	kurei_button.pressed.connect(_on_kurei_button_pressed)
	if item_button != null:
		item_button.pressed.connect(func() -> void: request_action(&"item"))
	cancel_kurei_btn.pressed.connect(_on_cancel_kurei_pressed)

	continue_button.pressed.connect(_on_continue_pressed)
	apply_kurei_tree_capacity()
	_rebuild_kurei_menu()
	_update_ui()

func _on_cancel_kurei_pressed() -> void:
	if kurei_menu != null:
		kurei_menu.visible = false
	if kurei_button != null and not kurei_button.disabled:
		kurei_button.grab_focus()

func _on_kurei_tree_updated(_arg = null) -> void:
	apply_kurei_tree_capacity()
	_rebuild_kurei_menu()

func apply_kurei_tree_capacity() -> void:
	if kurei_tree != null and kurei_tree.has_phase_mastery():
		max_sp = KureiTree.AUTHORED_PHASE_MASTERY_MAX_SP
	else:
		max_sp = BASELINE_MAX_SP
	ren_sp = mini(ren_sp, max_sp)
	_update_ui()

func get_equipped_active_skills() -> Array[StringName]:
	if kurei_tree != null:
		return kurei_tree.get_equipped_active_skills()
	var defaults: Array[StringName] = []
	for sid in KureiTree.STARTER_SKILLS:
		defaults.append(sid)
	return defaults

func _rebuild_kurei_menu() -> void:
	if kurei_menu == null:
		return

	for sid in _active_skill_buttons.keys():
		var b: Button = _active_skill_buttons[sid]
		if b != null and is_instance_valid(b):
			if b.get_parent() != null:
				b.get_parent().remove_child(b)
			b.queue_free()
	_active_skill_buttons.clear()

	# Remove initial static placeholder buttons if present
	for child in kurei_menu.get_children():
		if child != cancel_kurei_btn and child is Button and not child.name.begins_with("SkillBtn_"):
			kurei_menu.remove_child(child)
			child.queue_free()

	var skills := get_equipped_active_skills()
	for sid in skills:
		var btn := Button.new()
		btn.name = "SkillBtn_" + String(sid)
		btn.custom_minimum_size = Vector2(120, 36)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func() -> void: request_action("kurei_" + String(sid)))
		kurei_menu.add_child(btn)
		if cancel_kurei_btn != null:
			kurei_menu.move_child(btn, cancel_kurei_btn.get_index())
		_active_skill_buttons[sid] = btn

	if _active_skill_buttons.has(&"flame_burst"):
		flame_burst_btn = _active_skill_buttons[&"flame_burst"]
	if _active_skill_buttons.has(&"lumina_lance"):
		lumina_lance_btn = _active_skill_buttons[&"lumina_lance"]
	if _active_skill_buttons.has(&"torrent_surge"):
		torrent_surge_btn = _active_skill_buttons[&"torrent_surge"]

	_update_kurei_buttons()

func _on_kurei_button_pressed() -> void:
	if phase != Phase.PLAYER:
		return
	kurei_menu.visible = not kurei_menu.visible
	if kurei_menu.visible:
		_rebuild_kurei_menu()
		_focus_first_kurei_button()
	_update_kurei_buttons()

func _focus_first_kurei_button() -> void:
	for sid in _active_skill_buttons.keys():
		var btn: Button = _active_skill_buttons[sid]
		if btn != null and not btn.disabled:
			btn.grab_focus()
			return
	if cancel_kurei_btn != null and not cancel_kurei_btn.disabled:
		cancel_kurei_btn.grab_focus()

func _update_kurei_buttons() -> void:
	if not is_inside_tree() or kurei_menu == null or not kurei_menu.visible:
		return
	for sid in _active_skill_buttons.keys():
		var btn: Button = _active_skill_buttons[sid]
		if btn == null or not is_instance_valid(btn):
			continue
		var sname: String = String(KureiTree.SKILL_NODES.get(sid, {}).get("name", String(sid)))
		var cost: int = int(kurei.get_skill(sid).get("pip_cost", 1))
		var cd: int = int(kurei.cooldowns.get(sid, 0))

		if cd > 0:
			btn.text = "%s (CD: %d)" % [sname, cd]
			btn.disabled = true
		elif ren_sp < cost:
			btn.text = "%s (%d SP)" % [sname, cost]
			btn.disabled = true
		elif phase != Phase.PLAYER:
			btn.text = "%s (%d SP)" % [sname, cost]
			btn.disabled = true
		else:
			btn.text = "%s (%d SP)" % [sname, cost]
			btn.disabled = false

func get_available_item_count() -> int:
	if inventory == null:
		return standalone_consumables
	var total: int = 0
	for item_id: String in HEALING_ITEMS:
		total += int(inventory.satchel_items.get(item_id, 0))
		total += int(inventory.banked_items.get(item_id, 0))
	return total

func consume_healing_item() -> bool:
	if inventory == null:
		if standalone_consumables > 0:
			standalone_consumables -= 1
			return true
		return false

	for item_id: String in HEALING_ITEMS:
		if inventory.satchel_items.get(item_id, 0) > 0:
			var cnt: int = int(inventory.satchel_items[item_id]) - 1
			if cnt <= 0:
				inventory.satchel_items.erase(item_id)
			else:
				inventory.satchel_items[item_id] = cnt
			return true
		if inventory.banked_items.get(item_id, 0) > 0:
			return inventory.remove_banked_item(item_id, 1)
	return false

func request_action(action: StringName) -> bool:
	if phase != Phase.PLAYER:
		return false

	var is_kurei: bool = action.begins_with("kurei_")
	if action != &"attack" and action != &"defend" and action != &"item" and not is_kurei:
		return false

	if is_kurei:
		var skill_id: StringName = StringName(String(action).trim_prefix("kurei_"))
		if kurei_tree != null and not kurei_tree.is_skill_unlocked(skill_id):
			return false
		if kurei_tree != null and kurei_tree.is_skill_passive(skill_id):
			return false
		if skill_id == &"phase_mastery":
			return false
		if kurei_tree != null and not kurei_tree.is_skill_equipped(skill_id):
			return false
		if not kurei.can_cast(skill_id, ren_sp):
			return false
		var cast_res: Dictionary = kurei.cast_skill(skill_id, ren_sp)
		if cast_res.get("error", OK) != OK:
			return false
		ren_sp -= int(cast_res["pip_cost"])

		if skill_id == &"flame_burst":
			enemy_pips -= 2
			enemy_statuses.apply_status(StatusEngine.EFFECT_BURN, 2, 1)
		elif skill_id == &"solar_flare":
			enemy_pips -= 3
			enemy_statuses.apply_status(StatusEngine.EFFECT_BURN, 3, 2)
		elif skill_id == &"lumina_lance":
			enemy_pips -= 1
		elif skill_id == &"celestial_prism":
			enemy_pips -= 2
			enemy_statuses.apply_status(StatusEngine.EFFECT_STUN, 1, 1)
		elif skill_id == &"torrent_surge":
			ren_pips = mini(max_ren_pips, ren_pips + 1)
		elif skill_id == &"glacial_aegis":
			ren_pips = mini(max_ren_pips, ren_pips + 2)
			ren_statuses.apply_status(StatusEngine.EFFECT_SHIELD, 2, 2)
		elif skill_id == &"void_shift":
			ren_statuses.apply_status(StatusEngine.EFFECT_DEFENSE_UP, 1, 2)

		action_performed.emit(&"spell")
		last_player_action = action

		if enemy_pips <= 0:
			enemy_pips = 0
			phase = Phase.VICTORY
			_update_ui()
			return true

	if action == &"item":
		if get_available_item_count() <= 0:
			return false
		if ren_pips >= max_ren_pips:
			return false
		if not consume_healing_item():
			return false
		ren_pips = mini(max_ren_pips, ren_pips + 1)
		action_performed.emit(&"item")

	if action == &"defend":
		action_performed.emit(&"defend")

	last_player_action = action
	phase = Phase.ENEMY
	kurei_menu.visible = false

	if action == &"attack":
		action_performed.emit(&"attack")
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

	# Start of enemy turn: tick status effects
	var enemy_events: Array[Dictionary] = enemy_statuses.tick_turn_start()
	for ev: Dictionary in enemy_events:
		if int(ev.get("damage", 0)) > 0:
			enemy_pips = maxi(0, enemy_pips - int(ev["damage"]))
			if enemy_pips <= 0:
				phase = Phase.VICTORY
				_update_ui()
				return

	if enemy_intent == &"Strike":
		if last_player_action != &"defend":
			var dmg_info: Dictionary = ren_statuses.process_incoming_damage(1)
			ren_pips -= int(dmg_info.get("hp_damage", 0))
			if ren_pips <= 0:
				ren_pips = 0
				phase = Phase.DEFEAT
				_update_ui()
				return
	# Recover is harmless to the player

	enemy_intent = &"Recover" if enemy_intent == &"Strike" else &"Strike"
	ren_statuses.tick_turn_end()
	enemy_statuses.tick_turn_end()

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

	ren_pips_label.text = "Ren HP: %d/%d | SP: %d" % [ren_pips, max_ren_pips, ren_sp]
	enemy_pips_label.text = "Enemy HP: %d" % enemy_pips
	enemy_intent_label.text = "Intent: %s" % enemy_intent
	status_label.text = "Phase: %s" % Phase.keys()[phase]

	var is_player: bool = (phase == Phase.PLAYER)
	var is_terminal: bool = (phase == Phase.VICTORY or phase == Phase.DEFEAT)

	attack_button.disabled = not is_player
	defend_button.disabled = not is_player
	kurei_button.disabled = not is_player
	if item_button != null:
		var items_available: int = get_available_item_count()
		var can_use_item: bool = is_player and (items_available > 0) and (ren_pips < max_ren_pips)
		item_button.disabled = not can_use_item
		item_button.text = "Item (%d)" % items_available
	continue_button.visible = is_terminal
	continue_button.disabled = not is_terminal or _continued_emitted

	_update_kurei_buttons()

	if phase == Phase.VICTORY:
		outcome_label.text = "Outcome: VICTORY"
	elif phase == Phase.DEFEAT:
		outcome_label.text = "Outcome: DEFEAT"
	else:
		outcome_label.text = "Outcome: In Progress"

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if kurei_menu != null and kurei_menu.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_kurei_pressed()
		return
	if event.is_action_pressed("toggle_character") or event.is_action_pressed("toggle_inventory") \
			or event.is_action_pressed("toggle_settings") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
