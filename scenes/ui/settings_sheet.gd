class_name SettingsSheet
extends Control

## SettingsSheet — SBL-W10-002 Audio, Accessibility & Options UI Sheet
## Requirements: GDD-103, TC-ACC-001, AGENTS.md Invariants.

signal closed
signal backup_imported

var settings: SettingsManager = null
var profile_store: ProfileStore = null
var active_profile_id: String = "profile_01"
var last_exported_backup: String = ""

@onready var master_slider: HSlider = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/AudioBox/MasterRow/MasterSlider", "Panel/Margin/VBox/AudioBox/MasterRow/MasterSlider"]) as HSlider
@onready var master_val_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/AudioBox/MasterRow/ValLabel", "Panel/Margin/VBox/AudioBox/MasterRow/ValLabel"]) as Label

@onready var music_slider: HSlider = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/AudioBox/MusicRow/MusicSlider", "Panel/Margin/VBox/AudioBox/MusicRow/MusicSlider"]) as HSlider
@onready var music_val_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/AudioBox/MusicRow/ValLabel", "Panel/Margin/VBox/AudioBox/MusicRow/ValLabel"]) as Label

@onready var sfx_slider: HSlider = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/AudioBox/SfxRow/SfxSlider", "Panel/Margin/VBox/AudioBox/SfxRow/SfxSlider"]) as HSlider
@onready var sfx_val_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/AudioBox/SfxRow/ValLabel", "Panel/Margin/VBox/AudioBox/SfxRow/ValLabel"]) as Label

@onready var reduced_motion_check: CheckBox = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/AccessBox/ReducedMotionCheck", "Panel/Margin/VBox/AccessBox/ReducedMotionCheck"]) as CheckBox
@onready var high_contrast_check: CheckBox = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/AccessBox/HighContrastCheck", "Panel/Margin/VBox/AccessBox/HighContrastCheck"]) as CheckBox

@onready var text_scale_slider: HSlider = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/AccessBox/TextScaleRow/ScaleSlider", "Panel/Margin/VBox/AccessBox/TextScaleRow/ScaleSlider"]) as HSlider
@onready var text_scale_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/AccessBox/TextScaleRow/ValLabel", "Panel/Margin/VBox/AccessBox/TextScaleRow/ValLabel"]) as Label

@onready var export_backup_btn: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/BackupRow/ExportBackupBtn", "Panel/Margin/VBox/BackupRow/ExportBackupBtn"]) as Button
@onready var import_backup_btn: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/BackupRow/ImportBackupBtn", "Panel/Margin/VBox/BackupRow/ImportBackupBtn"]) as Button
@onready var import_text_btn: Button = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/BackupRow/ImportTextBtn", "Panel/Margin/VBox/BackupRow/ImportTextBtn"]) as Button
@onready var backup_text_field: TextEdit = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/BackupTextField", "Panel/Margin/VBox/BackupTextField"]) as TextEdit
@onready var backup_status_label: Label = _find_node(["Panel/Margin/VBox/Scroll/ContentBox/BackupStatusLabel", "Panel/Margin/VBox/BackupStatusLabel"]) as Label

@onready var close_btn: Button = $Panel/Margin/VBox/CloseBtn

func _find_node(paths: Array) -> Node:
	for p in paths:
		if has_node(String(p)):
			return get_node(String(p))
	return null

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
	if import_text_btn != null:
		import_text_btn.pressed.connect(_on_import_text_pressed)
	close_btn.pressed.connect(_on_close_pressed)

	setup_focus()

	if settings != null:
		refresh()

func get_focusable_controls() -> Array[Control]:
	var list: Array[Control] = [
		master_slider,
		music_slider,
		sfx_slider,
		reduced_motion_check,
		high_contrast_check,
		text_scale_slider,
		export_backup_btn,
		import_backup_btn,
		import_text_btn,
		backup_text_field,
		close_btn
	]
	var res: Array[Control] = []
	for c in list:
		if c != null and is_instance_valid(c):
			res.append(c)
	return res

func setup_focus() -> void:
	var controls := get_focusable_controls()
	for i in range(controls.size()):
		var c := controls[i]
		c.focus_mode = Control.FOCUS_ALL
		var next_ctrl := controls[(i + 1) % controls.size()]
		var prev_ctrl := controls[(i - 1 + controls.size()) % controls.size()]
		c.focus_next = next_ctrl.get_path()
		c.focus_previous = prev_ctrl.get_path()
		_apply_visible_focus(c)
	if controls.size() > 0:
		controls[0].grab_focus()

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
		settings.set_music_volume(val / 100.0)
		music_val_label.text = "%d%%" % int(val)

func _on_sfx_slider_changed(val: float) -> void:
	if settings != null:
		settings.set_sfx_volume(val / 100.0)
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
		if backup_text_field != null:
			backup_text_field.text = txt
		if OS.has_feature("web"):
			var buf: PackedByteArray = txt.to_utf8_buffer()
			JavaScriptBridge.download_buffer(buf, "soulbound_backup_%s.json" % active_profile_id, "application/json")
			if backup_status_label != null:
				backup_status_label.text = "Profile backup downloaded via browser! (%d chars)" % txt.length()
		else:
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
			backup_status_label.text = "Clipboard is empty. Use \"Import From Text\" after pasting a backup."
		return
	_import_backup_text(txt)

## Browser-safe import path: uses only the in-sheet text box, so it never depends on
## DisplayServer clipboard access (which browsers may deny).
func _on_import_text_pressed() -> void:
	if profile_store == null:
		if backup_status_label != null:
			backup_status_label.text = "ProfileStore unavailable for import."
		return
	var txt: String = backup_text_field.text.strip_edges() if backup_text_field != null else ""
	if txt.is_empty():
		if backup_status_label != null:
			backup_status_label.text = "Paste a backup JSON string into the text box first."
		return
	_import_backup_text(txt)

func _import_backup_text(txt: String) -> void:
	var err: Error = profile_store.import_backup(active_profile_id, txt, GameplayProfileValidator.validate)
	if err == OK:
		if backup_status_label != null:
			backup_status_label.text = "Profile imported successfully from backup text!"
		backup_imported.emit()
	else:
		if backup_status_label != null:
			backup_status_label.text = "Import failed: %s (Invalid data)" % error_string(err)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
