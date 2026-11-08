class_name SettingsSheet
extends Control

## SettingsSheet — SBL-W10-002 Audio, Accessibility & Options UI Sheet
## Requirements: GDD-103, TC-ACC-001, AGENTS.md Invariants.

signal closed

var settings: SettingsManager = null
var profile_store: ProfileStore = null
var active_profile_id: String = "profile_01"
var last_exported_backup: String = ""

@onready var master_slider: HSlider = $Panel/Margin/VBox/AudioBox/MasterRow/MasterSlider
@onready var master_val_label: Label = $Panel/Margin/VBox/AudioBox/MasterRow/ValLabel

@onready var music_slider: HSlider = $Panel/Margin/VBox/AudioBox/MusicRow/MusicSlider
@onready var music_val_label: Label = $Panel/Margin/VBox/AudioBox/MusicRow/ValLabel

@onready var sfx_slider: HSlider = $Panel/Margin/VBox/AudioBox/SfxRow/SfxSlider
@onready var sfx_val_label: Label = $Panel/Margin/VBox/AudioBox/SfxRow/ValLabel

@onready var reduced_motion_check: CheckBox = $Panel/Margin/VBox/AccessBox/ReducedMotionCheck
@onready var high_contrast_check: CheckBox = $Panel/Margin/VBox/AccessBox/HighContrastCheck

@onready var text_scale_slider: HSlider = $Panel/Margin/VBox/AccessBox/TextScaleRow/ScaleSlider
@onready var text_scale_label: Label = $Panel/Margin/VBox/AccessBox/TextScaleRow/ValLabel

@onready var export_backup_btn: Button = $Panel/Margin/VBox/BackupRow/ExportBackupBtn
@onready var import_backup_btn: Button = $Panel/Margin/VBox/BackupRow/ImportBackupBtn
@onready var backup_status_label: Label = $Panel/Margin/VBox/BackupStatusLabel

@onready var close_btn: Button = $Panel/Margin/VBox/CloseBtn

func _ready() -> void:
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	high_contrast_check.toggled.connect(_on_high_contrast_toggled)
	text_scale_slider.value_changed.connect(_on_text_scale_changed)
	if export_backup_btn != null:
		export_backup_btn.pressed.connect(_on_export_backup_pressed)
	if import_backup_btn != null:
		import_backup_btn.pressed.connect(_on_import_backup_pressed)
	close_btn.pressed.connect(_on_close_pressed)

	if settings != null:
		refresh()

func set_settings(new_settings: SettingsManager) -> void:
	settings = new_settings
	if is_inside_tree():
		refresh()

func refresh() -> void:
	if settings == null:
		return

	master_slider.value = settings.master_volume * 100.0
	master_val_label.text = "%d%%" % int(settings.master_volume * 100.0)

	music_slider.value = settings.music_volume * 100.0
	music_val_label.text = "%d%%" % int(settings.music_volume * 100.0)

	sfx_slider.value = settings.sfx_volume * 100.0
	sfx_val_label.text = "%d%%" % int(settings.sfx_volume * 100.0)

	reduced_motion_check.button_pressed = settings.reduced_motion
	high_contrast_check.button_pressed = settings.high_contrast

	text_scale_slider.value = settings.text_scale * 100.0
	text_scale_label.text = "%d%%" % int(settings.text_scale * 100.0)

func _on_master_slider_changed(val: float) -> void:
	if settings != null:
		settings.set_master_volume(val / 100.0)
		master_val_label.text = "%d%%" % int(val)

func _on_music_slider_changed(val: float) -> void:
	if settings != null:
		settings.music_volume = clampf(val / 100.0, 0.0, 1.0)
		music_val_label.text = "%d%%" % int(val)

func _on_sfx_slider_changed(val: float) -> void:
	if settings != null:
		settings.sfx_volume = clampf(val / 100.0, 0.0, 1.0)
		sfx_val_label.text = "%d%%" % int(val)

func _on_reduced_motion_toggled(enabled: bool) -> void:
	if settings != null:
		settings.set_reduced_motion(enabled)

func _on_high_contrast_toggled(enabled: bool) -> void:
	if settings != null:
		settings.set_high_contrast(enabled)

func _on_text_scale_changed(val: float) -> void:
	if settings != null:
		settings.set_text_scale(val / 100.0)
		text_scale_label.text = "%d%%" % int(val)

func _on_close_pressed() -> void:
	closed.emit()

func set_profile_context(store: ProfileStore, profile_id: String = "profile_01") -> void:
	profile_store = store
	active_profile_id = profile_id

func _on_export_backup_pressed() -> void:
	if profile_store == null:
		if backup_status_label != null:
			backup_status_label.text = "ProfileStore unavailable for export."
		return
	var res: Dictionary = profile_store.export_backup(active_profile_id)
	if res.get("error", ERR_UNCONFIGURED) == OK:
		var txt: String = res.get("text", "")
		last_exported_backup = txt
		if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			DisplayServer.clipboard_set(txt)
		if backup_status_label != null:
			backup_status_label.text = "Profile backup copied to clipboard! (%d chars)" % txt.length()
	else:
		if backup_status_label != null:
			backup_status_label.text = "Export failed with error: %s" % error_string(res.get("error", 0))

func _on_import_backup_pressed() -> void:
	if profile_store == null:
		if backup_status_label != null:
			backup_status_label.text = "ProfileStore unavailable for import."
		return
	var txt: String = last_exported_backup
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		var clip: String = DisplayServer.clipboard_get()
		if not clip.is_empty():
			txt = clip
	if txt.is_empty():
		if backup_status_label != null:
			backup_status_label.text = "Clipboard is empty. Copy backup string first."
		return
	var err: Error = profile_store.import_backup(active_profile_id, txt)
	if err == OK:
		if backup_status_label != null:
			backup_status_label.text = "Profile imported successfully from clipboard!"
	else:
		if backup_status_label != null:
			backup_status_label.text = "Import failed: %s (Invalid data)" % error_string(err)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
