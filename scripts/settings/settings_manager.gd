class_name SettingsManager
extends RefCounted

## SettingsManager — SBL-W10-001 Settings, Audio & Accessibility Options
## SBL-UX-001 Persistent Keyboard/Mouse Rebinding
## Requirements: GDD-092, GDD-103, FR-SET-001, TC-ACC-001, AGENTS.md Invariants.

signal settings_changed

const SETTINGS_FILE_PATH: String = "user://settings.json"
const CURRENT_SETTINGS_SCHEMA_VERSION: int = 1

var settings_schema_version: int = CURRENT_SETTINGS_SCHEMA_VERSION
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var reduced_motion: bool = false
var high_contrast: bool = false
var text_scale: float = 1.0
var input_overrides: Dictionary = {} # action_name (String) -> Array[Dictionary]

var _save_blocked: bool = false
var _is_legacy_source: bool = false
var test_inject_promotion_failure: bool = false

func reset_to_defaults() -> void:
	settings_schema_version = CURRENT_SETTINGS_SCHEMA_VERSION
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 0.9
	reduced_motion = false
	high_contrast = false
	text_scale = 1.0
	input_overrides.clear()
	apply_all_settings()

func is_save_blocked() -> bool:
	return _save_blocked

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	settings_changed.emit()

func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	settings_changed.emit()

func set_text_scale(scale: float) -> void:
	text_scale = clampf(scale, 0.8, 1.5)
	settings_changed.emit()

func set_master_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)
	apply_audio_buses()
	settings_changed.emit()

func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	apply_audio_buses()
	settings_changed.emit()

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
	apply_audio_buses()
	settings_changed.emit()

func set_input_override(action: StringName, primitives: Array) -> Error:
	if not InputBindings.is_configurable_action(action):
		return ERR_INVALID_DATA
	var candidate_overrides: Dictionary = input_overrides.duplicate(true)
	candidate_overrides[String(action)] = primitives.duplicate(true)
	var val_err: Error = InputBindings.validate_overrides(candidate_overrides)
	if val_err != OK:
		return val_err
	input_overrides = candidate_overrides
	InputBindings.apply_overrides(input_overrides)
	settings_changed.emit()
	return OK

func reset_input_override(action: StringName) -> void:
	if input_overrides.has(String(action)):
		input_overrides.erase(String(action))
	elif input_overrides.has(action):
		input_overrides.erase(action)
	InputBindings.apply_overrides(input_overrides)
	settings_changed.emit()

func reset_all_input_overrides() -> void:
	input_overrides.clear()
	InputBindings.restore_defaults_to_input_map()
	settings_changed.emit()

func apply_audio_buses() -> void:
	AudioManager.ensure_audio_buses()

	var m_bus: int = AudioServer.get_bus_index("Master")
	if m_bus >= 0:
		var is_master_zero: bool = master_volume <= 0.001
		AudioServer.set_bus_mute(m_bus, is_master_zero)
		AudioServer.set_bus_volume_db(m_bus, linear_to_db(master_volume) if not is_master_zero else -80.0)

	var music_bus: int = AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		var is_music_zero: bool = music_volume <= 0.001
		AudioServer.set_bus_mute(music_bus, is_music_zero)
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume) if not is_music_zero else -80.0)

	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		var is_sfx_zero: bool = sfx_volume <= 0.001
		AudioServer.set_bus_mute(sfx_bus, is_sfx_zero)
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume) if not is_sfx_zero else -80.0)

func apply_all_settings() -> void:
	apply_audio_buses()
	InputBindings.apply_overrides(input_overrides)

func serialize() -> Dictionary:
	return {
		"settings_schema_version": CURRENT_SETTINGS_SCHEMA_VERSION,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"reduced_motion": reduced_motion,
		"high_contrast": high_contrast,
		"text_scale": text_scale,
		"input_overrides": input_overrides.duplicate(true)
	}

func deserialize(data: Dictionary) -> Error:
	if data.has("settings_schema_version"):
		var ver_val: Variant = data.get("settings_schema_version")
		if typeof(ver_val) != TYPE_INT and typeof(ver_val) != TYPE_FLOAT:
			_save_blocked = true
			return ERR_INVALID_DATA
		var ver: int = int(ver_val)
		if ver > CURRENT_SETTINGS_SCHEMA_VERSION:
			_save_blocked = true
			return ERR_INVALID_DATA
		if ver < 1:
			_save_blocked = true
			return ERR_INVALID_DATA
		settings_schema_version = ver
	else:
		_is_legacy_source = true
		settings_schema_version = CURRENT_SETTINGS_SCHEMA_VERSION

	master_volume = clampf(float(data.get("master_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 0.9)), 0.0, 1.0)
	reduced_motion = bool(data.get("reduced_motion", false))
	high_contrast = bool(data.get("high_contrast", false))
	text_scale = clampf(float(data.get("text_scale", 1.0)), 0.8, 1.5)

	if data.has("input_overrides"):
		var raw_overrides: Variant = data.get("input_overrides")
		if typeof(raw_overrides) != TYPE_DICTIONARY:
			_save_blocked = true
			return ERR_INVALID_DATA
		var val_err: Error = InputBindings.validate_overrides(raw_overrides as Dictionary)
		if val_err != OK:
			_save_blocked = true
			return val_err
		input_overrides = (raw_overrides as Dictionary).duplicate(true)
	else:
		input_overrides = {}

	return OK

func load_settings(path: String = SETTINGS_FILE_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return FileAccess.get_open_error()
	var text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_save_blocked = true
		reset_to_defaults()
		push_error("Failed to parse settings JSON: malformed data at '%s'" % path)
		return ERR_INVALID_DATA

	var parsed_dict: Dictionary = parsed as Dictionary
	if parsed_dict.has("settings_schema_version"):
		var ver_val: Variant = parsed_dict.get("settings_schema_version")
		if typeof(ver_val) == TYPE_INT or typeof(ver_val) == TYPE_FLOAT:
			if int(ver_val) > CURRENT_SETTINGS_SCHEMA_VERSION:
				_save_blocked = true
				reset_to_defaults()
				push_error("Unsupported future settings schema version: %d at '%s'" % [int(ver_val), path])
				return ERR_INVALID_DATA

	var err: Error = deserialize(parsed_dict)
	if err != OK:
		_save_blocked = true
		reset_to_defaults()
		push_error("Failed to deserialize settings at '%s': %s" % [path, error_string(err)])
		return err

	_save_blocked = false
	apply_all_settings()
	return OK

func save_settings(path: String = SETTINGS_FILE_PATH) -> Error:
	if _save_blocked:
		push_error("Ordinary save blocked: current settings source is malformed or future version.")
		return ERR_UNAVAILABLE

	var val_err: Error = InputBindings.validate_overrides(input_overrides)
	if val_err != OK:
		return val_err

	# Do not overwrite a file that on disk has a future schema version
	if FileAccess.file_exists(path):
		var check_f := FileAccess.open(path, FileAccess.READ)
		if check_f != null:
			var existing_text: String = check_f.get_as_text()
			check_f.close()
			var parsed_ex: Variant = JSON.parse_string(existing_text)
			if parsed_ex is Dictionary and parsed_ex.has("settings_schema_version"):
				var ex_ver: Variant = parsed_ex.get("settings_schema_version")
				if (typeof(ex_ver) == TYPE_INT or typeof(ex_ver) == TYPE_FLOAT) and int(ex_ver) > CURRENT_SETTINGS_SCHEMA_VERSION:
					push_error("Refusing to overwrite future-version settings file at '%s'" % path)
					return ERR_UNAVAILABLE

	var json_str: String = JSON.stringify(serialize(), "\t")
	var bytes: PackedByteArray = json_str.to_utf8_buffer()

	var tmp_path: String = path + ".tmp_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var tmp_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		return FileAccess.get_open_error()
	tmp_file.store_buffer(bytes)
	tmp_file.flush()
	tmp_file.close()

	# Verify readability and byte content of temporary file
	var vfile := FileAccess.open(tmp_path, FileAccess.READ)
	if vfile == null:
		_remove_file_if_exists(tmp_path)
		return FileAccess.get_open_error()
	var vbytes: PackedByteArray = vfile.get_buffer(vfile.get_length())
	vfile.close()

	if vbytes != bytes:
		_remove_file_if_exists(tmp_path)
		return ERR_FILE_CORRUPT

	var promote_err: Error = _promote_file(tmp_path, path)
	if promote_err != OK:
		_remove_file_if_exists(tmp_path)
		return promote_err

	settings_changed.emit()
	return OK

func _promote_file(tmp_path: String, path: String) -> Error:
	if test_inject_promotion_failure:
		return ERR_CANT_CREATE

	var global_tmp: String = ProjectSettings.globalize_path(tmp_path)
	var global_target: String = ProjectSettings.globalize_path(path)

	if not FileAccess.file_exists(path):
		var ren_err: Error = DirAccess.rename_absolute(global_tmp, global_target)
		if ren_err != OK:
			_remove_file_if_exists(tmp_path)
		return ren_err

	var bak_path: String = path + ".bak_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var global_bak: String = ProjectSettings.globalize_path(bak_path)

	var bak_err: Error = DirAccess.rename_absolute(global_target, global_bak)
	if bak_err != OK:
		_remove_file_if_exists(tmp_path)
		return bak_err

	var prom_err: Error = DirAccess.rename_absolute(global_tmp, global_target)
	if prom_err != OK:
		# Rollback original from backup
		DirAccess.rename_absolute(global_bak, global_target)
		_remove_file_if_exists(tmp_path)
		return prom_err

	_remove_file_if_exists(bak_path)
	return OK

func _remove_file_if_exists(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
