extends SceneTree

## SBL-FIX-011 960x540 Layout & Overflow Audit Headless Test Suite
## Requirements: GDD-103, TC-ACC-001, AGENTS.md Engineering Invariants.
##
## Verifies that:
## 1. At 960x540 logical resolution, all 6 UI panels/modals:
##    - SettingsSheet
##    - InventorySheet
##    - CharacterSheet
##    - ChapterActivityDialog
##    - AcademicCompletionModal
##    - EndingModal
## 2. At text_scale 1.0:
##    - Each panel's rect stays fully inside Rect2(0, 0, 960, 540).
##    - No ScrollContainer reports clipped content (content fits without vertical overflow).
## 3. At text_scale 1.5:
##    - Each panel's rect stays fully inside Rect2(0, 0, 960, 540).
##    - ScrollContainers absorb content growth without panel boundary overflow.

var _failures: int = 0
const VIEWPORT_RECT := Rect2(0, 0, 960, 540)

func _init() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		printerr("  FAIL: %s" % message)
		_failures += 1

func _find_panel(node: Node) -> Control:
	for child in node.get_children():
		if child is PanelContainer:
			return child as Control
		if child is CenterContainer:
			for sub in child.get_children():
				if sub is PanelContainer:
					return sub as Control
	return null

func _get_scroll_containers(node: Node) -> Array[ScrollContainer]:
	var list: Array[ScrollContainer] = []
	_collect_scroll_containers(node, list)
	return list

func _collect_scroll_containers(node: Node, out_list: Array[ScrollContainer]) -> void:
	if node is ScrollContainer:
		out_list.append(node as ScrollContainer)
	for child in node.get_children():
		_collect_scroll_containers(child, out_list)

func _apply_text_scale(node: Node, scale: float) -> void:
	if node is Control:
		var ctrl: Control = node as Control
		if not ctrl.has_meta("_orig_font_size"):
			ctrl.set_meta("_orig_font_size", ctrl.get_theme_font_size("font_size"))
		var base: int = int(ctrl.get_meta("_orig_font_size"))
		if base > 0:
			var scaled: int = int(round(float(base) * scale))
			ctrl.add_theme_font_size_override("font_size", scaled)
	for child in node.get_children():
		_apply_text_scale(child, scale)

func _run_tests() -> void:
	print("--- Running SBL-FIX-011 960x540 Layout and Overflow Audit ---")

	var root_control := Control.new()
	root_control.custom_minimum_size = Vector2(960, 540)
	root_control.size = Vector2(960, 540)
	root.add_child(root_control)
	await process_frame
	await process_frame

	var modal_loaders: Dictionary = {
		"SettingsSheet": func() -> Control:
			var s: SettingsSheet = load("res://scenes/ui/settings_sheet.tscn").instantiate() as SettingsSheet
			var sm := SettingsManager.new()
			var ps := ProfileStore.new()
			s.settings = sm
			s.profile_store = ps
			return s,
		"InventorySheet": func() -> Control:
			var s: InventorySheet = load("res://scenes/ui/inventory_sheet.tscn").instantiate() as InventorySheet
			s.inventory = InventoryManager.new()
			return s,
		"CharacterSheet": func() -> Control:
			var s: CharacterSheet = load("res://scenes/ui/character_sheet.tscn").instantiate() as CharacterSheet
			s.stats = CharacterStats.new()
			s.kurei_tree = KureiTree.new()
			return s,
		"ChapterActivityDialog": func() -> Control:
			var dlg := ChapterActivityDialog.new()
			dlg.configure({
				"id": "q_audit_01",
				"chapter": 1,
				"prompt": "Evaluate whether the dimensional continuum can withstand planar convergence under strict resonance limits.",
				"options": ["Maintain stable equilibrium", "Induce catastrophic cascade", "Withdraw without choice", "Suppress resonance"],
				"correct_index": 0,
				"explanation": "Equilibrium preserves both physical and spirit plane stability."
			})
			return dlg,
		"AcademicCompletionModal": func() -> Control:
			var m: AcademicCompletionModal = load("res://scenes/ui/academic_completion_modal.tscn").instantiate() as AcademicCompletionModal
			m.configure(ChapterManager.new(), AssessmentController.new(), CharacterStats.new(), InventoryManager.new())
			return m,
		"EndingModal": func() -> Control:
			var m: EndingModal = load("res://scenes/ui/ending_modal.tscn").instantiate() as EndingModal
			var em := EndingManager.new()
			em.choose_ending("transcendence")
			m.configure("transcendence", em, CharacterStats.new(), AssessmentController.new())
			return m
	}

	# 1. Audit at text_scale 1.0
	print("\n[Phase 1] Auditing panels at text_scale 1.0 (Authored Base)...")
	for name: String in modal_loaders.keys():
		var factory: Callable = modal_loaders[name]
		var inst: Control = factory.call() as Control
		root_control.add_child(inst)
		inst.size = Vector2(960, 540)
		await process_frame
		await process_frame

		var panel: Control = _find_panel(inst)
		_check(panel != null, "%s: Found panel container" % name)
		if panel != null:
			var rect: Rect2 = panel.get_global_rect()
			var inside := (rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 960 and rect.end.y <= 540)
			_check(inside, "%s @ 1.0x: Panel rect %s stays inside 960x540 viewport" % [name, rect])

			# Assert no scroll container reports clipped content at 1.0x
			var scrolls := _get_scroll_containers(panel)
			for s in scrolls:
				var vbar := s.get_v_scroll_bar()
				# At 1.0x, content fits if max_value <= size.y or page >= max_value (no unreached scroll range)
				var fits := (vbar.page >= vbar.max_value) or (vbar.max_value <= s.size.y) or (not vbar.is_visible())
				_check(fits, "%s @ 1.0x: ScrollContainer '%s' reports no clipped content (size=%.1f, max=%.1f, page=%.1f)" % [
					name, s.name, s.size.y, vbar.max_value, vbar.page
				])

		inst.queue_free()
		await process_frame

	# 2. Audit at text_scale 1.5
	print("\n[Phase 2] Auditing panels at text_scale 1.5 (Maximum Accessibility Scale)...")
	for name: String in modal_loaders.keys():
		var factory: Callable = modal_loaders[name]
		var inst: Control = factory.call() as Control
		root_control.add_child(inst)
		inst.size = Vector2(960, 540)
		await process_frame

		# Scale fonts by 1.5x
		_apply_text_scale(inst, 1.5)
		await process_frame
		await process_frame

		var panel: Control = _find_panel(inst)
		_check(panel != null, "%s: Found panel container at 1.5x" % name)
		if panel != null:
			var rect: Rect2 = panel.get_global_rect()
			var inside := (rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 960 and rect.end.y <= 540)
			_check(inside, "%s @ 1.5x: Panel rect %s stays inside 960x540 viewport" % [name, rect])

		inst.queue_free()
		await process_frame

	root_control.queue_free()

	if _failures == 0:
		print("\n--- SBL-FIX-011 960x540 Layout & Overflow Audit PASSED ---")
		quit(0)
	else:
		printerr("\n--- SBL-FIX-011 960x540 Layout & Overflow Audit FAILED with %d errors ---" % _failures)
		quit(1)
