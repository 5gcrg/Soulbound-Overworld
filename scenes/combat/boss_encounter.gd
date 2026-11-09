class_name BossEncounter
extends Control

## BossEncounter — SBL-W11-002 Multi-Phase Apex Boss Encounter Engine
## Requirements: GDD-041/116, FR-CMB-001/002/003, AGENTS.md Invariants.
##
## Features:
## - Phase 1: High defense, rotating physical and shadow strikes.
## - Phase 2 Transition (triggers at <= 50% Boss HP):
##     * Cosmic Overdrive mode with visual aura & warning.
##     * Void Shield / Phase Barrier absorption.
##     * Telegraphed 2-turn ultimate attack ("Void Cataclysm") requiring Defend/mitigation.
## - Integrated Kurei Magic system and Status Engine (Burn, Stun, Shield).
## - Scaled victory rewards deposited directly into persistent bank/inventory.

signal continued()
signal action_performed(action_type: StringName)
signal boss_phase_changed(new_phase: int)
signal boss_defeated(rewards: Dictionary)

enum BossPhase {
	PHASE_1,
	PHASE_2,
	VICTORY,
	DEFEAT
}

const BASELINE_MAX_SP: int = 3

const SUPPORTED_BOSS_SKILLS: Array[StringName] = [
	&"flame_burst",
	&"lumina_lance",
	&"torrent_surge"
]

const HEALING_ITEMS: Array[String] = [
	"spirit_salve",
	"health_elixir",
	"potion",
	"potions",
	"healing_herb"
]

const VICTORY_REWARDS: Dictionary = {
	"void_crown": 1,
	"sovereign_core": 1,
	"spirit_salve": 3
}

var current_phase: BossPhase = BossPhase.PHASE_1
var ren_hp: int = 4
var max_ren_hp: int = 4
var ren_sp: int = 3
var max_ren_sp: int = BASELINE_MAX_SP

var boss_hp: int = 10
var max_boss_hp: int = 10
var boss_barrier: int = 0
var max_boss_barrier: int = 4

var boss_intent: StringName = &"Void Strike"
var is_cataclysm_charging: bool = false
var cataclysm_timer: int = 0
var last_player_action: StringName = &""
var _continued_emitted: bool = false
var turn_counter: int = 1

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
var standalone_consumables: int = 2
var kurei: KureiSystem = KureiSystem.new()
var ren_statuses: StatusEngine = StatusEngine.new()
var boss_statuses: StatusEngine = StatusEngine.new()

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var phase_indicator: Label = $VBoxContainer/PhaseIndicator
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var telegraph_label: Label = $VBoxContainer/TelegraphBanner/TelegraphLabel
@onready var telegraph_banner: PanelContainer = $VBoxContainer/TelegraphBanner
@onready var outcome_label: Label = $VBoxContainer/OutcomeLabel

@onready var ren_panel: PanelContainer = $VBoxContainer/HBoxContainer/RenPanel
@onready var ren_hp_label: Label = $VBoxContainer/HBoxContainer/RenPanel/Margin/VBox/RenHP
@onready var ren_sp_label: Label = $VBoxContainer/HBoxContainer/RenPanel/Margin/VBox/RenSP
@onready var ren_status_label: Label = $VBoxContainer/HBoxContainer/RenPanel/Margin/VBox/RenStatuses

@onready var boss_panel: PanelContainer = $VBoxContainer/HBoxContainer/BossPanel
@onready var boss_hp_label: Label = $VBoxContainer/HBoxContainer/BossPanel/Margin/VBox/BossHP
@onready var boss_barrier_label: Label = $VBoxContainer/HBoxContainer/BossPanel/Margin/VBox/BossBarrier
@onready var boss_intent_label: Label = $VBoxContainer/HBoxContainer/BossPanel/Margin/VBox/BossIntent
@onready var boss_status_label: Label = $VBoxContainer/HBoxContainer/BossPanel/Margin/VBox/BossStatuses

@onready var attack_btn: Button = $VBoxContainer/Actions/AttackButton
@onready var defend_btn: Button = $VBoxContainer/Actions/DefendButton
@onready var kurei_btn: Button = $VBoxContainer/Actions/KureiButton
@onready var item_btn: Button = $VBoxContainer/Actions/ItemButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton

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
	if attack_btn != null:
		attack_btn.pressed.connect(func() -> void: request_action(&"attack"))
	if defend_btn != null:
		defend_btn.pressed.connect(func() -> void: request_action(&"defend"))
	if kurei_btn != null:
		kurei_btn.pressed.connect(_on_kurei_toggle)
	if item_btn != null:
		item_btn.pressed.connect(func() -> void: request_action(&"item"))
	if continue_btn != null:
		continue_btn.pressed.connect(_on_continue_pressed)

	if cancel_kurei_btn != null:
		cancel_kurei_btn.pressed.connect(_on_cancel_kurei_pressed)

	apply_kurei_tree_capacity()
	_rebuild_kurei_menu()
	_update_ui()

func _on_cancel_kurei_pressed() -> void:
	if kurei_menu != null:
		kurei_menu.visible = false
	if kurei_btn != null and not kurei_btn.disabled:
		kurei_btn.grab_focus()

func _on_kurei_tree_updated(_arg = null) -> void:
	apply_kurei_tree_capacity()
	_rebuild_kurei_menu()

func apply_kurei_tree_capacity() -> void:
	if kurei_tree != null and kurei_tree.has_phase_mastery():
		max_ren_sp = KureiTree.AUTHORED_PHASE_MASTERY_MAX_SP
	else:
		max_ren_sp = BASELINE_MAX_SP
	ren_sp = mini(ren_sp, max_ren_sp)
	_update_ui()

func is_boss_skill_supported(skill_id: StringName) -> bool:
	return SUPPORTED_BOSS_SKILLS.has(skill_id)

func get_equipped_active_skills() -> Array[StringName]:
	if kurei_tree != null and not kurei_tree.equipped_skills.is_empty():
		var list: Array[StringName] = []
		for sid in kurei_tree.equipped_skills:
			if kurei_tree.is_skill_active(sid):
				list.append(sid)
		return list
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

	for child in kurei_menu.get_children():
		if child != cancel_kurei_btn and child is Button and not child.name.begins_with("SkillBtn_"):
			kurei_menu.remove_child(child)
			child.queue_free()

	var skills := get_equipped_active_skills()
	for sid in skills:
		var btn := Button.new()
		btn.name = "SkillBtn_" + String(sid)
		btn.custom_minimum_size = Vector2(120, 36)
		btn.add_theme_font_size_override("font_size", 10)
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

func _on_kurei_toggle() -> void:
	if is_terminal():
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

		# Explicit OD-003/004 boundary:
		if not is_boss_skill_supported(sid):
			btn.text = "%s (Boss effect pending design approval)" % sname
			btn.disabled = true
		elif cd > 0:
			btn.text = "%s (CD: %d)" % [sname, cd]
			btn.disabled = true
		elif ren_sp < cost:
			btn.text = "%s (%d SP)" % [sname, cost]
			btn.disabled = true
		elif is_terminal():
			btn.text = "%s (%d SP)" % [sname, cost]
			btn.disabled = true
		else:
			btn.text = "%s (%d SP)" % [sname, cost]
			btn.disabled = false

func is_terminal() -> bool:
	return current_phase == BossPhase.VICTORY or current_phase == BossPhase.DEFEAT

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
	if is_terminal():
		return false

	var is_kurei: bool = action.begins_with("kurei_")
	if action != &"attack" and action != &"defend" and action != &"item" and not is_kurei:
		return false

	var skill_id: StringName = &""
	if is_kurei:
		skill_id = StringName(String(action).trim_prefix("kurei_"))
		if kurei_tree != null and not kurei_tree.is_skill_unlocked(skill_id):
			return false
		if kurei_tree != null and kurei_tree.is_skill_passive(skill_id):
			return false
		if skill_id == &"phase_mastery":
			return false
		if kurei_tree != null and not kurei_tree.is_skill_equipped(skill_id):
			return false
		if not is_boss_skill_supported(skill_id):
			return false
		if not kurei.can_cast(skill_id, ren_sp):
			return false

	if action == &"item":
		if get_available_item_count() <= 0 or ren_hp >= max_ren_hp:
			return false
		if not consume_healing_item():
			return false
		ren_hp = mini(max_ren_hp, ren_hp + 2)
		action_performed.emit(&"item")
	elif is_kurei:
		var cast_res: Dictionary = kurei.cast_skill(skill_id, ren_sp)
		if cast_res.get("error", OK) != OK:
			return false
		ren_sp -= int(cast_res["pip_cost"])
		action_performed.emit(&"spell")

		if skill_id == &"flame_burst":
			_deal_damage_to_boss(2)
			boss_statuses.apply_status(StatusEngine.EFFECT_BURN, 2, 1)
		elif skill_id == &"lumina_lance":
			# Radiant Piercing: ignores barrier directly to HP!
			boss_hp = maxi(0, boss_hp - 2)
			_check_phase_transition()
		elif skill_id == &"torrent_surge":
			ren_hp = mini(max_ren_hp, ren_hp + 1)
			ren_statuses.apply_status(StatusEngine.EFFECT_REGENERATION, 2, 1)

	last_player_action = action
	if kurei_menu != null:
		kurei_menu.visible = false

	# 1. Process player action (attack, defend)
	if action == &"attack":
		action_performed.emit(&"attack")
		_deal_damage_to_boss(1)
	elif action == &"defend":
		action_performed.emit(&"defend")
		ren_statuses.apply_status(StatusEngine.EFFECT_DEFENSE_UP, 1, 1)

	# Check boss defeat
	if boss_hp <= 0:
		_trigger_victory()
		return true

	# Check Phase 2 transition
	_check_phase_transition()

	# 2. Boss turn resolution
	_resolve_boss_turn()
	return true

func _deal_damage_to_boss(dmg: int) -> void:
	if boss_barrier > 0:
		if dmg <= boss_barrier:
			boss_barrier -= dmg
			dmg = 0
		else:
			dmg -= boss_barrier
			boss_barrier = 0
	if dmg > 0:
		boss_hp = maxi(0, boss_hp - dmg)

func _check_phase_transition() -> void:
	if current_phase == BossPhase.PHASE_1 and boss_hp <= (max_boss_hp / 2):
		current_phase = BossPhase.PHASE_2
		boss_barrier = max_boss_barrier
		is_cataclysm_charging = true
		cataclysm_timer = 2
		boss_intent = &"Cataclysm Charging"
		boss_phase_changed.emit(2)

func _resolve_boss_turn() -> void:
	turn_counter += 1

	# Tick statuses on boss
	var boss_events: Array[Dictionary] = boss_statuses.tick_turn_start()
	for ev: Dictionary in boss_events:
		if int(ev.get("damage", 0)) > 0:
			_deal_damage_to_boss(int(ev["damage"]))
			if boss_hp <= 0:
				_trigger_victory()
				return

	# Tick statuses on Ren
	var ren_events: Array[Dictionary] = ren_statuses.tick_turn_start()
	for ev: Dictionary in ren_events:
		if int(ev.get("heal", 0)) > 0:
			ren_hp = mini(max_ren_hp, ren_hp + int(ev["heal"]))

	# Resolve Boss Action
	if current_phase == BossPhase.PHASE_1:
		_resolve_phase_1_action()
	elif current_phase == BossPhase.PHASE_2:
		_resolve_phase_2_action()

	# End of turn cleanup
	ren_statuses.tick_turn_end()
	boss_statuses.tick_turn_end()
	kurei.tick_cooldowns()
	ren_sp = mini(max_ren_sp, ren_sp + 1)

	if ren_hp <= 0:
		ren_hp = 0
		current_phase = BossPhase.DEFEAT
	_update_ui()

func _resolve_phase_1_action() -> void:
	if boss_intent == &"Void Strike":
		var dmg: int = 1
		if last_player_action == &"defend":
			dmg = 0
		ren_hp = maxi(0, ren_hp - dmg)
		boss_intent = &"Shadow Siphon"
	elif boss_intent == &"Shadow Siphon":
		ren_sp = maxi(0, ren_sp - 1)
		boss_intent = &"Void Strike"
	else:
		boss_intent = &"Void Strike"

func _resolve_phase_2_action() -> void:
	if is_cataclysm_charging:
		cataclysm_timer -= 1
		if cataclysm_timer <= 0:
			# Cataclysm Unleashed!
			var cataclysm_dmg: int = 3
			if last_player_action == &"defend":
				cataclysm_dmg = 1 # Heavily mitigated by defending!
			ren_hp = maxi(0, ren_hp - cataclysm_dmg)
			is_cataclysm_charging = false
			boss_intent = &"Cosmic Slash"
		else:
			boss_intent = &"Cataclysm Imminent!"
	else:
		if boss_intent == &"Cosmic Slash":
			var slash_dmg: int = 1
			if last_player_action != &"defend":
				slash_dmg = 2
			ren_hp = maxi(0, ren_hp - slash_dmg)
			# Every 3 turns, boss begins charging Cataclysm again
			if turn_counter % 3 == 0:
				is_cataclysm_charging = true
				cataclysm_timer = 2
				boss_intent = &"Cataclysm Charging"
			else:
				boss_intent = &"Astral Pulse"
		elif boss_intent == &"Astral Pulse":
			ren_hp = maxi(0, ren_hp - 1)
			boss_intent = &"Cosmic Slash"
		else:
			boss_intent = &"Cosmic Slash"

func _trigger_victory() -> void:
	boss_hp = 0
	current_phase = BossPhase.VICTORY
	if inventory != null:
		for item: String in VICTORY_REWARDS.keys():
			inventory.add_banked_item(item, int(VICTORY_REWARDS[item]))
	boss_defeated.emit(VICTORY_REWARDS.duplicate(true))
	_update_ui()

func _on_continue_pressed() -> void:
	if _continued_emitted or not is_terminal():
		return
	_continued_emitted = true
	continued.emit()

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

func _update_ui() -> void:
	if not is_node_ready():
		return

	# Labels
	if ren_hp_label != null:
		ren_hp_label.text = "Ren HP: %d/%d" % [ren_hp, max_ren_hp]
	if ren_sp_label != null:
		ren_sp_label.text = "Ren SP: %d/%d" % [ren_sp, max_ren_sp]
	if ren_status_label != null:
		var st_list: Array = ren_statuses.active_effects.keys()
		ren_status_label.text = "Statuses: %s" % (", ".join(st_list) if not st_list.is_empty() else "None")

	if boss_hp_label != null:
		boss_hp_label.text = "Void Sovereign HP: %d/%d" % [boss_hp, max_boss_hp]
	if boss_barrier_label != null:
		boss_barrier_label.text = "Void Shield: %d/%d" % [boss_barrier, max_boss_barrier] if boss_barrier > 0 else "Void Shield: INACTIVE"
	if boss_intent_label != null:
		boss_intent_label.text = "Intent: %s" % boss_intent
	if boss_status_label != null:
		var b_st: Array = boss_statuses.active_effects.keys()
		boss_status_label.text = "Statuses: %s" % (", ".join(b_st) if not b_st.is_empty() else "None")

	# Phase indicator
	if phase_indicator != null:
		match current_phase:
			BossPhase.PHASE_1:
				phase_indicator.text = "[PHASE I: PRIMORDIAL RESONATOR]"
				phase_indicator.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4, 1))
			BossPhase.PHASE_2:
				phase_indicator.text = "[PHASE II: COSMIC OVERDRIVE (ASTRAL SHIELD ACTIVE)]"
				phase_indicator.add_theme_color_override("font_color", Color(1.0, 0.2, 0.3, 1))
			BossPhase.VICTORY:
				phase_indicator.text = "[VOID SOVEREIGN VAPORIZED — VICTORY]"
				phase_indicator.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1))
			BossPhase.DEFEAT:
				phase_indicator.text = "[REN FALLEN — EXPEDITION RECOVERY REQUIRED]"
				phase_indicator.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))

	# Telegraph banner
	if telegraph_banner != null and telegraph_label != null:
		if is_cataclysm_charging:
			telegraph_banner.visible = true
			telegraph_label.text = "CRITICAL ALERT: Void Cataclysm Charging (%d turn remaining)! DEFEND to survive!" % cataclysm_timer
		else:
			telegraph_banner.visible = false

	# Action buttons
	var is_player_active: bool = not is_terminal()
	if attack_btn != null:
		attack_btn.disabled = not is_player_active
	if defend_btn != null:
		defend_btn.disabled = not is_player_active
	if kurei_btn != null:
		kurei_btn.disabled = not is_player_active
	if item_btn != null:
		var items_available: int = get_available_item_count()
		var can_use: bool = is_player_active and (items_available > 0) and (ren_hp < max_ren_hp)
		item_btn.disabled = not can_use
		item_btn.text = "Item (%d)" % items_available

	if continue_btn != null:
		continue_btn.visible = is_terminal()
		continue_btn.disabled = not is_terminal or _continued_emitted

	if outcome_label != null:
		if current_phase == BossPhase.VICTORY:
			outcome_label.text = "OUTCOME: VICTORY! Dropped Sovereign Core, Void Crown, and Spirit Salves!"
			outcome_label.visible = true
		elif current_phase == BossPhase.DEFEAT:
			outcome_label.text = "OUTCOME: DEFEAT. Ren's essence reconstituted at Dawnreach Shrine."
			outcome_label.visible = true
		else:
			outcome_label.visible = false

	_update_kurei_buttons()
