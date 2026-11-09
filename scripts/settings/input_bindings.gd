class_name InputBindings
extends RefCounted

## InputBindings — SBL-UX-001 Persistent Keyboard/Mouse Rebinding
## Requirements: GDD-092, FR-SET-001, TC-ACC-001, NFR-ACC-001, AGENTS.md Invariants.

const CONFIGURABLE_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"shift_dimension",
	&"toggle_character",
	&"toggle_inventory",
	&"toggle_settings",
]

const ACTION_LABELS: Dictionary = {
	&"move_left": "Move Left",
	&"move_right": "Move Right",
	&"move_up": "Move Up",
	&"move_down": "Move Down",
	&"shift_dimension": "Shift Dimension",
	&"toggle_character": "Character Sheet",
	&"toggle_inventory": "Inventory Sheet",
	&"toggle_settings": "Settings Menu",
}

const REJECTED_KEYCODES: Array[int] = [
	KEY_ESCAPE,     # 4194305 — Reserved for cancel capture / dismiss modal
	KEY_ENTER,      # 4194309 — Reserved for UI activation
	KEY_KP_ENTER,   # 4194310 — Reserved for keypad activation
	KEY_TAB,        # 4194306 — Reserved for UI focus traversal
	KEY_F1,         # 4194332 — Reserved for Evaluator Debug Bar
	KEY_QUOTELEFT,  # 96 (backtick / grave) — Reserved for Evaluator Debug Bar
	KEY_SHIFT,      # 4194325 — Modifier-only key
	KEY_CTRL,       # 4194326 — Modifier-only key
	KEY_ALT,        # 4194328 — Modifier-only key
	KEY_META,       # 4194327 — Modifier-only key
	KEY_CAPSLOCK,   # 4194329 — Modifier-only key
	KEY_NUMLOCK,    # 4194330 — Modifier-only key
	KEY_SCROLLLOCK, # 4194331 — Modifier-only key
]

const ALLOWED_MOUSE_BUTTONS: Array[int] = [
	MOUSE_BUTTON_LEFT,   # 1
	MOUSE_BUTTON_RIGHT,  # 2
	MOUSE_BUTTON_MIDDLE, # 3
]

static var _authored_defaults_snapshotted: bool = false
static var _authored_primitives: Dictionary = {} # StringName -> Array[Dictionary]
static var _authored_events: Dictionary = {}     # StringName -> Array[InputEvent]
static var _authored_deadzones: Dictionary = {}  # StringName -> float

static var _capture_active: bool = false
static var _capture_action: StringName = &""

## Ensures authored defaults are snapshotted from pristine ProjectSettings (not runtime InputMap).
static func ensure_defaults_snapshotted() -> void:
	if _authored_defaults_snapshotted:
		return
	_authored_primitives.clear()
	_authored_events.clear()
	_authored_deadzones.clear()

	for action in CONFIGURABLE_ACTIONS:
		var setting_key: String = "input/" + String(action)
		var setting_val: Variant = ProjectSettings.get_setting(setting_key)
		var prim_list: Array[Dictionary] = []
		var ev_list: Array[InputEvent] = []
		var deadzone: float = 0.5

		if setting_val is Dictionary:
			deadzone = float(setting_val.get("deadzone", 0.5))
			var events_val: Variant = setting_val.get("events", [])
			if events_val is Array:
				for ev_variant in events_val:
					if ev_variant is InputEvent:
						var ev: InputEvent = ev_variant as InputEvent
						ev_list.append(ev.duplicate())
						var prim: Dictionary = event_to_primitive(ev)
						if not prim.is_empty():
							prim_list.append(prim)

		_authored_primitives[action] = prim_list
		_authored_events[action] = ev_list
		_authored_deadzones[action] = deadzone

	_authored_defaults_snapshotted = true

static func is_configurable_action(action: StringName) -> bool:
	return action in CONFIGURABLE_ACTIONS

static func get_action_label(action: StringName) -> String:
	return String(ACTION_LABELS.get(action, String(action)))

static func get_authored_primitives(action: StringName) -> Array[Dictionary]:
	ensure_defaults_snapshotted()
	var res: Array[Dictionary] = []
	var list: Array = _authored_primitives.get(action, [])
	for item in list:
		if item is Dictionary:
			res.append((item as Dictionary).duplicate(true))
	return res

static func get_authored_events(action: StringName) -> Array[InputEvent]:
	ensure_defaults_snapshotted()
	var res: Array[InputEvent] = []
	var list: Array = _authored_events.get(action, [])
	for ev in list:
		if ev is InputEvent:
			res.append((ev as InputEvent).duplicate())
	return res

static func get_authored_deadzone(action: StringName) -> float:
	ensure_defaults_snapshotted()
	return float(_authored_deadzones.get(action, 0.5))

## Capture active state tracking (public API per Rule 2)
static func is_capture_active() -> bool:
	return _capture_active

static func get_capture_action() -> StringName:
	return _capture_action

static func set_capture_active(active: bool, action: StringName = &"") -> void:
	_capture_active = active
	_capture_action = action if active else &""
	if not active:
		clear_all_pressed_actions()

## Converts an InputEvent to a primitive JSON-safe dictionary. Returns {} if unsupported.
static func event_to_primitive(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var k_ev := event as InputEventKey
		var pk: int = int(k_ev.physical_keycode if k_ev.physical_keycode != 0 else k_ev.keycode)
		if pk > 0:
			return {
				"kind": "key",
				"physical_keycode": pk
			}
	elif event is InputEventMouseButton:
		var m_ev := event as InputEventMouseButton
		if m_ev.button_index in ALLOWED_MOUSE_BUTTONS:
			return {
				"kind": "mouse_button",
				"button_index": int(m_ev.button_index)
			}
	return {}

## Converts a primitive dictionary to an InputEvent. Returns null if invalid.
static func primitive_to_event(data: Dictionary) -> InputEvent:
	var kind: String = String(data.get("kind", ""))
	if kind == "key":
		var pk: int = int(data.get("physical_keycode", 0))
		if pk > 0:
			var k_ev := InputEventKey.new()
			k_ev.physical_keycode = pk as Key
			k_ev.keycode = KEY_NONE
			return k_ev
	elif kind == "mouse_button" or kind == "mouse":
		var btn: int = int(data.get("button_index", 0))
		if btn in ALLOWED_MOUSE_BUTTONS:
			var m_ev := InputEventMouseButton.new()
			m_ev.button_index = btn as MouseButton
			return m_ev
	return null

static func primitives_are_equal(a: Dictionary, b: Dictionary) -> bool:
	var kind_a: String = String(a.get("kind", ""))
	var kind_b: String = String(b.get("kind", ""))
	if kind_a == "mouse":
		kind_a = "mouse_button"
	if kind_b == "mouse":
		kind_b = "mouse_button"
	if kind_a != kind_b:
		return false
	if kind_a == "key":
		return int(a.get("physical_keycode", 0)) == int(b.get("physical_keycode", 0))
	elif kind_a == "mouse_button":
		return int(a.get("button_index", 0)) == int(b.get("button_index", 0))
	return false

## Validates a single primitive dictionary from JSON.
static func validate_primitive(data: Dictionary) -> Error:
	var kind_val: Variant = data.get("kind")
	if typeof(kind_val) != TYPE_STRING:
		return ERR_INVALID_DATA
	var kind: String = String(kind_val)

	if kind == "key":
		if not data.has("physical_keycode"):
			return ERR_INVALID_DATA
		var pk_val: Variant = data.get("physical_keycode")
		if typeof(pk_val) != TYPE_INT and typeof(pk_val) != TYPE_FLOAT:
			return ERR_INVALID_DATA
		var pk: int = int(pk_val)
		if pk <= 0:
			return ERR_INVALID_DATA
		if pk in REJECTED_KEYCODES:
			return ERR_INVALID_DATA
		return OK
	elif kind == "mouse_button" or kind == "mouse":
		if not data.has("button_index"):
			return ERR_INVALID_DATA
		var btn_val: Variant = data.get("button_index")
		if typeof(btn_val) != TYPE_INT and typeof(btn_val) != TYPE_FLOAT:
			return ERR_INVALID_DATA
		var btn: int = int(btn_val)
		if btn not in ALLOWED_MOUSE_BUTTONS:
			return ERR_INVALID_DATA
		return OK

	return ERR_INVALID_DATA

## Validates a candidate live InputEvent for rebinding.
static func validate_candidate_event(event: InputEvent) -> Error:
	if event == null:
		return ERR_INVALID_PARAMETER
	if event is InputEventMouseMotion:
		return ERR_INVALID_DATA
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return ERR_INVALID_DATA
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return ERR_INVALID_DATA

	if event is InputEventMouseButton:
		var m_ev := event as InputEventMouseButton
		if m_ev.double_click:
			return ERR_INVALID_DATA
		if m_ev.shift_pressed or m_ev.ctrl_pressed or m_ev.alt_pressed or m_ev.meta_pressed:
			return ERR_INVALID_DATA
		if m_ev.button_index not in ALLOWED_MOUSE_BUTTONS:
			return ERR_INVALID_DATA
		return OK

	if event is InputEventKey:
		var k_ev := event as InputEventKey
		if k_ev.shift_pressed or k_ev.ctrl_pressed or k_ev.alt_pressed or k_ev.meta_pressed:
			return ERR_INVALID_DATA
		var pk: int = int(k_ev.physical_keycode if k_ev.physical_keycode != 0 else k_ev.keycode)
		if pk <= 0:
			return ERR_INVALID_DATA
		if pk in REJECTED_KEYCODES:
			return ERR_INVALID_DATA
		return OK

	return ERR_INVALID_DATA

static func get_candidate_rejection_reason(event: InputEvent) -> String:
	if event == null:
		return "Null event"
	if event is InputEventMouseMotion:
		return "Mouse motion cannot be bound"
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "Controllers are out of scope (keyboard and mouse only)"
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "Touch events are out of scope"
	if event is InputEventMouseButton:
		var m_ev := event as InputEventMouseButton
		if m_ev.double_click:
			return "Double-click cannot be bound"
		if m_ev.shift_pressed or m_ev.ctrl_pressed or m_ev.alt_pressed or m_ev.meta_pressed:
			return "Modifier chords are not supported"
		if m_ev.button_index == MOUSE_BUTTON_WHEEL_UP or m_ev.button_index == MOUSE_BUTTON_WHEEL_DOWN \
				or m_ev.button_index == MOUSE_BUTTON_WHEEL_LEFT or m_ev.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			return "Mouse wheel cannot be bound"
		if m_ev.button_index not in ALLOWED_MOUSE_BUTTONS:
			return "Only Left, Right, and Middle mouse buttons are supported"
	if event is InputEventKey:
		var k_ev := event as InputEventKey
		if k_ev.shift_pressed or k_ev.ctrl_pressed or k_ev.alt_pressed or k_ev.meta_pressed:
			return "Modifier chords are not supported"
		var pk: int = int(k_ev.physical_keycode if k_ev.physical_keycode != 0 else k_ev.keycode)
		if pk == KEY_ESCAPE:
			return "Escape is reserved for cancellation"
		if pk == KEY_ENTER or pk == KEY_KP_ENTER:
			return "Enter is reserved for UI navigation"
		if pk == KEY_TAB:
			return "Tab is reserved for UI focus navigation"
		if pk == KEY_F1 or pk == KEY_QUOTELEFT:
			return "F1 and ` are reserved for Evaluator Tools"
		if pk in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK]:
			return "Modifier keys cannot be bound alone"
	return "Unsupported input"

## Returns the effective primitive bindings for an action given an override dictionary.
static func get_effective_primitives(action: StringName, overrides: Dictionary) -> Array[Dictionary]:
	ensure_defaults_snapshotted()
	var raw_arr: Variant = null
	if overrides.has(action):
		raw_arr = overrides[action]
	elif overrides.has(String(action)):
		raw_arr = overrides[String(action)]
	if raw_arr is Array:
		var res: Array[Dictionary] = []
		for item in (raw_arr as Array):
			if item is Dictionary:
				res.append((item as Dictionary).duplicate(true))
		return res
	return get_authored_primitives(action)

## Returns the effective InputEvent objects for an action given an override dictionary.
static func get_effective_events(action: StringName, overrides: Dictionary) -> Array[InputEvent]:
	ensure_defaults_snapshotted()
	var raw_arr: Variant = null
	if overrides.has(action):
		raw_arr = overrides[action]
	elif overrides.has(String(action)):
		raw_arr = overrides[String(action)]
	if raw_arr is Array:
		var res: Array[InputEvent] = []
		for item in (raw_arr as Array):
			if item is Dictionary:
				var ev: InputEvent = primitive_to_event(item as Dictionary)
				if ev != null:
					res.append(ev)
		return res
	return get_authored_events(action)

## Finds if a candidate primitive conflicts with another configurable action.
## Returns the name of the conflicting action, or &"" if no conflict.
static func find_conflict(target_action: StringName, candidate: Dictionary, current_overrides: Dictionary) -> StringName:
	ensure_defaults_snapshotted()
	for action in CONFIGURABLE_ACTIONS:
		if action == target_action:
			continue
		var eff_prims := get_effective_primitives(action, current_overrides)
		for existing in eff_prims:
			if primitives_are_equal(existing, candidate):
				return action
	return &""

static func find_conflict_for_event(target_action: StringName, event: InputEvent, current_overrides: Dictionary) -> StringName:
	var prim: Dictionary = event_to_primitive(event)
	if prim.is_empty():
		return &""
	return find_conflict(target_action, prim, current_overrides)

## Finds if resetting an action to its authored defaults causes a conflict with other active overrides.
## Returns Dictionary with {"conflict_action": StringName, "conflicting_primitive": Dictionary} or {} if no conflict.
static func find_reset_conflict(action: StringName, current_overrides: Dictionary) -> Dictionary:
	ensure_defaults_snapshotted()
	var candidate: Dictionary = current_overrides.duplicate(true)
	var act_str: String = String(action)
	if candidate.has(act_str):
		candidate.erase(act_str)
	elif candidate.has(action):
		candidate.erase(action)

	var authored_prims: Array[Dictionary] = get_authored_primitives(action)
	for prim in authored_prims:
		var conf_act: StringName = find_conflict(action, prim, candidate)
		if conf_act != &"":
			return {
				"conflict_action": conf_act,
				"conflicting_primitive": prim
			}
	return {}

## Validates the entire override dictionary atomically.
## Rejects unknown actions, empty arrays, invalid primitives, duplicates within an action, and cross-action conflicts.
static func validate_overrides(overrides: Dictionary) -> Error:
	ensure_defaults_snapshotted()

	for k in overrides.keys():
		var action_name := StringName(k)
		if action_name not in CONFIGURABLE_ACTIONS:
			return ERR_INVALID_DATA
		var val: Variant = overrides[k]
		if typeof(val) != TYPE_ARRAY:
			return ERR_INVALID_DATA
		var arr: Array = val as Array
		if arr.is_empty():
			return ERR_INVALID_DATA

		# Pass 1: Validate every entry is a Dictionary and has a valid primitive shape before pairwise checks
		for idx in range(arr.size()):
			var item: Variant = arr[idx]
			if typeof(item) != TYPE_DICTIONARY:
				return ERR_INVALID_DATA
			var prim_err: Error = validate_primitive(item as Dictionary)
			if prim_err != OK:
				return prim_err

		# Pass 2: Check for duplicates within action (all entries are guaranteed to be Dictionaries)
		for i in range(arr.size()):
			var item_a: Dictionary = arr[i] as Dictionary
			for j in range(i + 1, arr.size()):
				var item_b: Dictionary = arr[j] as Dictionary
				if primitives_are_equal(item_a, item_b):
					return ERR_INVALID_DATA # Duplicate within same action

	# Cross-action conflict check across all effective bindings
	var seen_primitives: Array[Dictionary] = []
	var seen_actions: Array[StringName] = []

	for action in CONFIGURABLE_ACTIONS:
		var eff_prims: Array[Dictionary] = get_effective_primitives(action, overrides)
		for prim in eff_prims:
			for idx in range(seen_primitives.size()):
				if primitives_are_equal(seen_primitives[idx], prim):
					return ERR_INVALID_DATA # Conflict between action and seen_actions[idx]
			seen_primitives.append(prim)
			seen_actions.append(action)

	return OK

## Formats display text for an InputEvent.
static func get_event_display_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var k_ev := event as InputEventKey
		var pk: int = int(k_ev.physical_keycode if k_ev.physical_keycode != 0 else k_ev.keycode)
		if pk > 0:
			var s: String = OS.get_keycode_string(pk as Key)
			return s if not s.is_empty() else "Key %d" % pk
	elif event is InputEventMouseButton:
		var m_ev := event as InputEventMouseButton
		match m_ev.button_index:
			MOUSE_BUTTON_LEFT:
				return "Mouse Left"
			MOUSE_BUTTON_RIGHT:
				return "Mouse Right"
			MOUSE_BUTTON_MIDDLE:
				return "Mouse Middle"
			_:
				return "Mouse %d" % m_ev.button_index
	return "(None)"

static func get_primitive_display_text(primitive: Dictionary) -> String:
	var ev := primitive_to_event(primitive)
	if ev != null:
		return get_event_display_text(ev)
	return "(None)"

## Returns comma-separated text representation of effective bindings for an action.
static func get_action_binding_text(action: StringName, current_overrides: Dictionary = {}) -> String:
	var events: Array[InputEvent] = get_effective_events(action, current_overrides)
	if events.is_empty():
		return "(Unbound)"
	var parts: PackedStringArray = []
	for ev in events:
		parts.append(get_event_display_text(ev))
	return ", ".join(parts)

## Applies the given override dictionary to Godot's InputMap singleton.
## Preserves deadzones, unrelated actions, ui_* actions, and non-key/mouse events.
static func apply_overrides(overrides: Dictionary) -> Error:
	ensure_defaults_snapshotted()
	var val_err: Error = validate_overrides(overrides)
	if val_err != OK:
		return val_err

	for action in CONFIGURABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var deadzone: float = InputMap.action_get_deadzone(action)
		var preserved_events: Array[InputEvent] = []
		for ev in InputMap.action_get_events(action):
			if not (ev is InputEventKey or ev is InputEventMouseButton):
				preserved_events.append(ev)

		InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action, deadzone)

		for ev in preserved_events:
			InputMap.action_add_event(action, ev)

		var target_events: Array[InputEvent] = get_effective_events(action, overrides)
		for ev in target_events:
			InputMap.action_add_event(action, ev)

	return OK

## Restores all authored defaults from ProjectSettings to Godot's InputMap singleton.
static func restore_defaults_to_input_map() -> void:
	ensure_defaults_snapshotted()
	for action in CONFIGURABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var deadzone: float = get_authored_deadzone(action)
		var preserved_events: Array[InputEvent] = []
		for ev in InputMap.action_get_events(action):
			if not (ev is InputEventKey or ev is InputEventMouseButton):
				preserved_events.append(ev)

		InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action, deadzone)

		for ev in preserved_events:
			InputMap.action_add_event(action, ev)

		for ev in get_authored_events(action):
			InputMap.action_add_event(action, ev)

## Clears all pressed states across all actions in InputMap to prevent key-stuck leakage.
static func clear_all_pressed_actions() -> void:
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)
