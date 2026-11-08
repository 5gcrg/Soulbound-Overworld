class_name SettingsSheet
extends Control

## SettingsSheet — SBL-W10-002 Audio, Accessibility & Options UI Sheet
## Requirements: GDD-103, TC-ACC-001, AGENTS.md Invariants.

signal closed

var settings: SettingsManager = null

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

@onready var close_btn: Button = $Panel/Margin/VBox/CloseBtn

func _ready() -> void:
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	high_contrast_check.toggled.connect(_on_high_contrast_toggled)
	text_scale_slider.value_changed.connect(_on_text_scale_changed)
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
