class_name EvaluatorDebugBar
extends Control

signal region_warp_requested(region_id: String)
signal combat_requested()
signal boss_combat_requested()
signal dungeon_requested()
signal chapter_dialog_requested()
signal academic_modal_requested()
signal dimension_shift_requested()
signal grant_items_requested()
signal complete_activities_requested()
signal max_stats_requested()
signal title_screen_requested()
signal ending_requested(ending_type: String)

@onready var panel: PanelContainer = $DebugPanel
@onready var toggle_btn: Button = $ToggleBtn
@onready var status_summary: Label = $DebugPanel/Margin/VBox/StatusSummary

var _is_open: bool = false

func _ready() -> void:
	panel.visible = false
	toggle_btn.pressed.connect(_on_toggle_pressed)
	_connect_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if InputBindings.is_capture_active():
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if k == KEY_F1 or k == KEY_QUOTELEFT:
			toggle_panel()
			get_viewport().set_input_as_handled()

func toggle_panel() -> void:
	_is_open = not _is_open
	panel.visible = _is_open
	toggle_btn.text = "[- Evaluator Tools]" if _is_open else "[⚙ Evaluator Tools (F1)]"
	if _is_open:
		sync_release_tier()

func sync_release_tier() -> void:
	if panel == null:
		return
	var is_full := ReleaseTier.is_full_release()
	var btn_citadel: Button = panel.get_node_or_null("Margin/VBox/RegionGrid/BtnCitadel") as Button
	if btn_citadel != null:
		btn_citadel.disabled = not is_full
		btn_citadel.tooltip_text = "" if is_full else "Locked in Academic MVP tier"
	var btn_boss: Button = panel.get_node_or_null("Margin/VBox/ActionsGrid/BtnBoss") as Button
	if btn_boss != null:
		btn_boss.disabled = not is_full
		btn_boss.tooltip_text = "" if is_full else "Locked in Academic MVP tier"
	var btn_ending_a: Button = panel.get_node_or_null("Margin/VBox/CheatsGrid/BtnEndingA") as Button
	if btn_ending_a != null:
		btn_ending_a.disabled = not is_full
		btn_ending_a.tooltip_text = "" if is_full else "Locked in Academic MVP tier"
	var btn_ending_b: Button = panel.get_node_or_null("Margin/VBox/CheatsGrid/BtnEndingB") as Button
	if btn_ending_b != null:
		btn_ending_b.disabled = not is_full
		btn_ending_b.tooltip_text = "" if is_full else "Locked in Academic MVP tier"

func update_status(info: Dictionary) -> void:
	if status_summary == null:
		return
	var text := "Region: %s | Dim: %s | Ch: %d | Level: %d (HP %d/%d, Ren %d/%d)" % [
		info.get("region", "n/a"),
		info.get("dimension", "n/a"),
		info.get("chapter", 1),
		info.get("level", 1),
		info.get("hp", 100),
		info.get("max_hp", 100),
		info.get("pips", 3),
		info.get("max_pips", 3)
	]
	status_summary.text = text

func _on_toggle_pressed() -> void:
	toggle_panel()

func _connect_buttons() -> void:
	var btn_dawnreach: Button = panel.get_node_or_null("Margin/VBox/RegionGrid/BtnDawnreach") as Button
	if btn_dawnreach != null:
		btn_dawnreach.pressed.connect(func(): region_warp_requested.emit("dawnreach_village"))

	var btn_grove: Button = panel.get_node_or_null("Margin/VBox/RegionGrid/BtnGrove") as Button
	if btn_grove != null:
		btn_grove.pressed.connect(func(): region_warp_requested.emit("whispering_grove"))

	var btn_shrine: Button = panel.get_node_or_null("Margin/VBox/RegionGrid/BtnShrine") as Button
	if btn_shrine != null:
		btn_shrine.pressed.connect(func(): region_warp_requested.emit("forgotten_shrine"))

	var btn_alpha: Button = panel.get_node_or_null("Margin/VBox/RegionGrid/BtnAlpha") as Button
	if btn_alpha != null:
		btn_alpha.pressed.connect(func(): region_warp_requested.emit("test_region_alpha"))

	var btn_beta: Button = panel.get_node_or_null("Margin/VBox/RegionGrid/BtnBeta") as Button
	if btn_beta != null:
		btn_beta.pressed.connect(func(): region_warp_requested.emit("test_region_beta"))

	var btn_peaks: Button = panel.get_node_or_null("Margin/VBox/RegionGrid/BtnPeaks") as Button
	if btn_peaks != null:
		btn_peaks.pressed.connect(func(): region_warp_requested.emit("ashen_peaks"))

	var btn_citadel: Button = panel.get_node_or_null("Margin/VBox/RegionGrid/BtnCitadel") as Button
	if btn_citadel != null:
		if not ReleaseTier.is_full_release():
			btn_citadel.disabled = true
			btn_citadel.tooltip_text = "Locked in Academic MVP tier"
		btn_citadel.pressed.connect(func():
			if ReleaseTier.is_full_release():
				region_warp_requested.emit("void_citadel")
		)

	var btn_combat: Button = panel.get_node_or_null("Margin/VBox/ActionsGrid/BtnCombat") as Button
	if btn_combat != null:
		btn_combat.pressed.connect(func(): combat_requested.emit())

	var btn_boss: Button = panel.get_node_or_null("Margin/VBox/ActionsGrid/BtnBoss") as Button
	if btn_boss != null:
		if not ReleaseTier.is_full_release():
			btn_boss.disabled = true
			btn_boss.tooltip_text = "Locked in Academic MVP tier"
		btn_boss.pressed.connect(func():
			if ReleaseTier.is_full_release():
				toggle_panel()
				boss_combat_requested.emit()
		)

	var btn_dungeon: Button = panel.get_node_or_null("Margin/VBox/ActionsGrid/BtnDungeon") as Button
	if btn_dungeon != null:
		btn_dungeon.pressed.connect(func(): dungeon_requested.emit())

	var btn_dialog: Button = panel.get_node_or_null("Margin/VBox/ActionsGrid/BtnDialog") as Button
	if btn_dialog != null:
		btn_dialog.pressed.connect(func(): chapter_dialog_requested.emit())

	var btn_academic: Button = panel.get_node_or_null("Margin/VBox/ActionsGrid/BtnAcademic") as Button
	if btn_academic != null:
		btn_academic.pressed.connect(func(): academic_modal_requested.emit())

	var btn_shift: Button = panel.get_node_or_null("Margin/VBox/ActionsGrid/BtnShift") as Button
	if btn_shift != null:
		btn_shift.pressed.connect(func(): dimension_shift_requested.emit())

	var btn_items: Button = panel.get_node_or_null("Margin/VBox/CheatsGrid/BtnItems") as Button
	if btn_items != null:
		btn_items.pressed.connect(func(): grant_items_requested.emit())

	var btn_activities: Button = panel.get_node_or_null("Margin/VBox/CheatsGrid/BtnActivities") as Button
	if btn_activities != null:
		btn_activities.pressed.connect(func(): complete_activities_requested.emit())

	var btn_stats: Button = panel.get_node_or_null("Margin/VBox/CheatsGrid/BtnStats") as Button
	if btn_stats != null:
		btn_stats.pressed.connect(func(): max_stats_requested.emit())

	var btn_ending_a: Button = panel.get_node_or_null("Margin/VBox/CheatsGrid/BtnEndingA") as Button
	if btn_ending_a != null:
		if not ReleaseTier.is_full_release():
			btn_ending_a.disabled = true
			btn_ending_a.tooltip_text = "Locked in Academic MVP tier"
		btn_ending_a.pressed.connect(func():
			if ReleaseTier.is_full_release():
				toggle_panel()
				ending_requested.emit("transcendence")
		)

	var btn_ending_b: Button = panel.get_node_or_null("Margin/VBox/CheatsGrid/BtnEndingB") as Button
	if btn_ending_b != null:
		if not ReleaseTier.is_full_release():
			btn_ending_b.disabled = true
			btn_ending_b.tooltip_text = "Locked in Academic MVP tier"
		btn_ending_b.pressed.connect(func():
			if ReleaseTier.is_full_release():
				toggle_panel()
				ending_requested.emit("restoration")
		)

	var btn_title: Button = panel.get_node_or_null("Margin/VBox/CheatsGrid/BtnTitle") as Button
	if btn_title != null:
		btn_title.pressed.connect(func():
			toggle_panel()
			title_screen_requested.emit()
		)

	var btn_close: Button = panel.get_node_or_null("Margin/VBox/BtnClose") as Button
	if btn_close != null:
		btn_close.pressed.connect(toggle_panel)
