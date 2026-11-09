class_name TitleScreen
extends Control

signal game_started(slot_id: String)
signal continue_requested(slot_id: String)
signal new_journey_requested(slot_id: String)
signal settings_requested()
signal backup_requested()
signal defense_demo_requested(slot_id: String)

@onready var main_menu: VBoxContainer = $CenterContainer/MainVBox/MenuButtons
@onready var profile_menu: VBoxContainer = $CenterContainer/MainVBox/ProfileSelector
@onready var new_game_menu: VBoxContainer = $CenterContainer/MainVBox/NewGameSelector
@onready var recovery_box: VBoxContainer = $CenterContainer/MainVBox/RecoveryBox
@onready var recovery_label: Label = $CenterContainer/MainVBox/RecoveryBox/RecoveryLabel
@onready var recovery_export_btn: Button = $CenterContainer/MainVBox/RecoveryBox/RecoveryExportBtn
@onready var continue_btn: Button = $CenterContainer/MainVBox/MenuButtons/ContinueBtn
@onready var new_game_btn: Button = $CenterContainer/MainVBox/MenuButtons/NewGameBtn
@onready var select_profile_btn: Button = $CenterContainer/MainVBox/MenuButtons/SelectProfileBtn
@onready var settings_btn: Button = $CenterContainer/MainVBox/MenuButtons/SettingsBtn
@onready var backup_btn: Button = $CenterContainer/MainVBox/MenuButtons/BackupBtn
@onready var defense_btn: Button = $CenterContainer/MainVBox/MenuButtons/DefenseBtn

@onready var slot1_btn: Button = $CenterContainer/MainVBox/ProfileSelector/Slot1Btn
@onready var slot2_btn: Button = $CenterContainer/MainVBox/ProfileSelector/Slot2Btn
@onready var slot3_btn: Button = $CenterContainer/MainVBox/ProfileSelector/Slot3Btn
@onready var back_from_profiles_btn: Button = $CenterContainer/MainVBox/ProfileSelector/BackBtn

@onready var new_slot1_btn: Button = $CenterContainer/MainVBox/NewGameSelector/NewSlot1Btn
@onready var new_slot2_btn: Button = $CenterContainer/MainVBox/NewGameSelector/NewSlot2Btn
@onready var new_slot3_btn: Button = $CenterContainer/MainVBox/NewGameSelector/NewSlot3Btn
@onready var no_empty_slots_label: Label = $CenterContainer/MainVBox/NewGameSelector/NoEmptySlotsLabel
@onready var back_from_new_game_btn: Button = $CenterContainer/MainVBox/NewGameSelector/BackBtn

@onready var error_box: VBoxContainer = $CenterContainer/MainVBox/ErrorBox
@onready var error_label: Label = $CenterContainer/MainVBox/ErrorBox/ErrorLabel

var profile_store: ProfileStore = null
var current_slot: String = "profile_01"
var _is_modal_blocked: bool = false
var _last_action_origin: Control = null

func get_last_action_origin() -> Control:
	return _last_action_origin

func set_modal_blocked(blocked: bool) -> void:
	_is_modal_blocked = blocked
	var buttons: Array[Button] = [
		continue_btn, new_game_btn, select_profile_btn,
		settings_btn, backup_btn, defense_btn,
		slot1_btn, slot2_btn, slot3_btn, back_from_profiles_btn
	]
	if new_slot1_btn != null:
		buttons.append(new_slot1_btn)
	if new_slot2_btn != null:
		buttons.append(new_slot2_btn)
	if new_slot3_btn != null:
		buttons.append(new_slot3_btn)
	if back_from_new_game_btn != null:
		buttons.append(back_from_new_game_btn)
	if recovery_export_btn != null:
		buttons.append(recovery_export_btn)
	for b in buttons:
		if b != null and is_instance_valid(b):
			b.disabled = blocked
			b.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL

func show_error(msg: String) -> void:
	if error_label != null:
		error_label.text = msg
	if error_box != null:
		error_box.visible = not msg.is_empty()

func refresh_slot_summary(_slot_id: String = "") -> void:
	_refresh_profile_labels()
	if new_game_menu != null and new_game_menu.visible:
		_refresh_new_game_labels()

func _gui_input(_event: InputEvent) -> void:
	if _is_modal_blocked:
		accept_event()

func _ready() -> void:
	profile_menu.visible = false
	if new_game_menu != null:
		new_game_menu.visible = false
	if error_box != null:
		error_box.visible = false
	main_menu.visible = true

	continue_btn.pressed.connect(_on_continue_pressed)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	select_profile_btn.pressed.connect(_on_select_profile_pressed)
	settings_btn.pressed.connect(func():
		if _is_modal_blocked: return
		_last_action_origin = settings_btn
		settings_requested.emit()
	)
	backup_btn.pressed.connect(func():
		if _is_modal_blocked: return
		_last_action_origin = backup_btn
		backup_requested.emit()
	)
	defense_btn.pressed.connect(func():
		if _is_modal_blocked: return
		show_error("")
		defense_demo_requested.emit(current_slot)
	)
	if recovery_export_btn != null:
		recovery_export_btn.pressed.connect(_on_recovery_export_pressed)

	slot1_btn.pressed.connect(func(): _select_slot("profile_01"))
	slot2_btn.pressed.connect(func(): _select_slot("profile_02"))
	slot3_btn.pressed.connect(func(): _select_slot("profile_03"))
	back_from_profiles_btn.pressed.connect(_on_back_from_profiles)

	if new_slot1_btn != null:
		new_slot1_btn.pressed.connect(func(): _on_new_slot_selected("profile_01"))
	if new_slot2_btn != null:
		new_slot2_btn.pressed.connect(func(): _on_new_slot_selected("profile_02"))
	if new_slot3_btn != null:
		new_slot3_btn.pressed.connect(func(): _on_new_slot_selected("profile_03"))
	if back_from_new_game_btn != null:
		back_from_new_game_btn.pressed.connect(_on_back_from_new_game)

	_refresh_profile_labels()

func setup_profiles(store: ProfileStore, default_slot: String = "profile_01") -> void:
	profile_store = store
	current_slot = default_slot
	_refresh_profile_labels()

func _is_slot_empty(slot: String) -> bool:
	if profile_store == null:
		return false
	var loaded: Dictionary = profile_store.load_profile(slot)
	return loaded.get("error", OK) == ERR_FILE_NOT_FOUND

func _refresh_new_game_labels() -> void:
	if profile_store == null or new_game_menu == null:
		return
	var slots: Array[String] = ["profile_01", "profile_02", "profile_03"]
	var btns: Array[Button] = [new_slot1_btn, new_slot2_btn, new_slot3_btn]
	var has_any_empty: bool = false
	var first_empty_btn: Button = null

	for i in range(slots.size()):
		var s := slots[i]
		var btn := btns[i]
		if btn == null:
			continue
		var is_empty: bool = _is_slot_empty(s)
		if is_empty:
			has_any_empty = true
			btn.disabled = false
			btn.focus_mode = Control.FOCUS_ALL
			btn.text = "Profile %d: [Empty Slot — Click to Start]" % (i + 1)
			if first_empty_btn == null:
				first_empty_btn = btn
		else:
			btn.disabled = true
			btn.focus_mode = Control.FOCUS_NONE
			var sum := _get_profile_summary(s)
			btn.text = "Profile %d: %s [Occupied]" % [(i + 1), sum]

	if no_empty_slots_label != null:
		no_empty_slots_label.visible = not has_any_empty

	if first_empty_btn != null:
		first_empty_btn.grab_focus()
	elif back_from_new_game_btn != null:
		back_from_new_game_btn.grab_focus()

func _refresh_profile_labels() -> void:
	if profile_store == null:
		return

	var s1 := _get_profile_summary("profile_01")
	var s2 := _get_profile_summary("profile_02")
	var s3 := _get_profile_summary("profile_03")

	if slot1_btn != null:
		slot1_btn.text = "Profile 1: " + s1
	if slot2_btn != null:
		slot2_btn.text = "Profile 2: " + s2
	if slot3_btn != null:
		slot3_btn.text = "Profile 3: " + s3

	var is_current_recovered: bool = false
	var cur_loaded: Dictionary = profile_store.load_profile(current_slot)
	if cur_loaded.get("error") == OK:
		is_current_recovered = bool(cur_loaded.get("recovered", false))

	if recovery_box != null:
		recovery_box.visible = is_current_recovered
		if is_current_recovered and recovery_label != null:
			recovery_label.text = "⚠ Profile slot '%s' was recovered from an earlier revision after corruption in the latest file. Export a backup before overwrite." % current_slot

	if continue_btn != null:
		var has_save: bool = _has_profile(current_slot)
		continue_btn.text = "Continue Journey (" + current_slot + ")" if has_save else "Start Journey (" + current_slot + ")"

func _has_profile(slot: String) -> bool:
	if profile_store == null:
		return false
	var loaded: Dictionary = profile_store.load_profile(slot)
	return loaded.get("error", ERR_DOES_NOT_EXIST) == OK and not loaded.get("profile", {}).is_empty()

func _get_profile_summary(slot: String) -> String:
	if not _has_profile(slot):
		var check: Dictionary = profile_store.load_profile(slot) if profile_store != null else {}
		if check.get("error", OK) == ERR_FILE_NOT_FOUND:
			return "[Empty Slot]"
		return "[Unavailable]"
	var loaded: Dictionary = profile_store.load_profile(slot)
	if loaded.get("error", OK) != OK:
		return "[Corrupted]"
	var p: Dictionary = loaded.get("profile", {})
	var lvl: int = int(p.get("character", {}).get("level", 1))
	var ch: int = int(p.get("world", {}).get("chapter_progress", {}).get("current_chapter", 1))
	var comp: bool = bool(p.get("world", {}).get("chapter_progress", {}).get("is_academic_complete", false))
	var status: String = "Academic MVP Complete" if comp else "Chapter %d" % ch
	var summary: String = "Level %d — %s" % [lvl, status]
	if bool(loaded.get("recovered", false)):
		summary += " [RECOVERED]"
	return summary

func _on_continue_pressed() -> void:
	if _is_modal_blocked:
		return
	show_error("")
	if _has_profile(current_slot):
		continue_requested.emit(current_slot)
		game_started.emit(current_slot)
	else:
		_on_new_game_pressed()

func _on_new_game_pressed() -> void:
	if _is_modal_blocked:
		return
	show_error("")
	main_menu.visible = false
	if profile_menu != null:
		profile_menu.visible = false
	if new_game_menu != null:
		new_game_menu.visible = true
		_refresh_new_game_labels()

func _on_back_from_new_game() -> void:
	if _is_modal_blocked:
		return
	show_error("")
	if new_game_menu != null:
		new_game_menu.visible = false
	main_menu.visible = true
	if new_game_btn != null and is_instance_valid(new_game_btn):
		new_game_btn.grab_focus()

func _on_new_slot_selected(slot_id: String) -> void:
	if _is_modal_blocked:
		return
	show_error("")
	if not _is_slot_empty(slot_id):
		show_error("Slot '%s' is occupied or unavailable." % slot_id)
		_refresh_new_game_labels()
		return
	current_slot = slot_id
	new_journey_requested.emit(slot_id)
	game_started.emit(slot_id)

func _on_recovery_export_pressed() -> void:
	if _is_modal_blocked:
		return
	_last_action_origin = recovery_export_btn
	backup_requested.emit()

func _on_select_profile_pressed() -> void:
	if _is_modal_blocked:
		return
	show_error("")
	_refresh_profile_labels()
	main_menu.visible = false
	if new_game_menu != null:
		new_game_menu.visible = false
	profile_menu.visible = true
	if slot1_btn != null:
		slot1_btn.grab_focus()

func _on_back_from_profiles() -> void:
	if _is_modal_blocked:
		return
	show_error("")
	profile_menu.visible = false
	main_menu.visible = true
	if select_profile_btn != null and is_instance_valid(select_profile_btn):
		select_profile_btn.grab_focus()

func _select_slot(slot_id: String) -> void:
	if _is_modal_blocked:
		return
	show_error("")
	current_slot = slot_id
	profile_menu.visible = false
	main_menu.visible = true
	_refresh_profile_labels()
	if continue_btn != null and is_instance_valid(continue_btn):
		continue_btn.grab_focus()
