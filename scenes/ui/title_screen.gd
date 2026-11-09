class_name TitleScreen
extends Control

signal game_started(slot_id: String)
signal settings_requested()
signal backup_requested()
signal defense_demo_requested()

@onready var main_menu: VBoxContainer = $CenterContainer/MainVBox/MenuButtons
@onready var profile_menu: VBoxContainer = $CenterContainer/MainVBox/ProfileSelector
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
	if recovery_export_btn != null:
		buttons.append(recovery_export_btn)
	for b in buttons:
		if b != null and is_instance_valid(b):
			b.disabled = blocked
			b.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL

func refresh_slot_summary(_slot_id: String = "") -> void:
	_refresh_profile_labels()

func _gui_input(_event: InputEvent) -> void:
	if _is_modal_blocked:
		accept_event()

func _ready() -> void:
	profile_menu.visible = false
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
		defense_demo_requested.emit()
	)
	if recovery_export_btn != null:
		recovery_export_btn.pressed.connect(_on_recovery_export_pressed)

	slot1_btn.pressed.connect(func(): _select_slot("profile_01"))
	slot2_btn.pressed.connect(func(): _select_slot("profile_02"))
	slot3_btn.pressed.connect(func(): _select_slot("profile_03"))
	back_from_profiles_btn.pressed.connect(_on_back_from_profiles)

	_refresh_profile_labels()

func setup_profiles(store: ProfileStore, default_slot: String = "profile_01") -> void:
	profile_store = store
	current_slot = default_slot
	_refresh_profile_labels()

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
		return "[Empty Slot]"
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
	game_started.emit(current_slot)

func _on_new_game_pressed() -> void:
	if _is_modal_blocked:
		return
	game_started.emit(current_slot)

func _on_recovery_export_pressed() -> void:
	if _is_modal_blocked:
		return
	_last_action_origin = recovery_export_btn
	backup_requested.emit()

func _on_select_profile_pressed() -> void:
	if _is_modal_blocked:
		return
	_refresh_profile_labels()
	main_menu.visible = false
	profile_menu.visible = true

func _on_back_from_profiles() -> void:
	if _is_modal_blocked:
		return
	profile_menu.visible = false
	main_menu.visible = true

func _select_slot(slot_id: String) -> void:
	if _is_modal_blocked:
		return
	current_slot = slot_id
	profile_menu.visible = false
	main_menu.visible = true
	_refresh_profile_labels()
	game_started.emit(slot_id)
