class_name SettingsManager
extends RefCounted

## SettingsManager — SBL-W10-001 Settings, Audio & Accessibility Options
## Requirements: GDD-103, TC-ACC-001, AGENTS.md Invariants.

signal settings_changed

const SETTINGS_FILE_PATH: String = "user://settings.json"

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var reduced_motion: bool = false
var high_contrast: bool = false
var text_scale: float = 1.0

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

func apply_audio_buses() -> void:
	var m_bus: int = AudioServer.get_bus_index("Master")
	if m_bus >= 0:
		AudioServer.set_bus_volume_db(m_bus, linear_to_db(master_volume) if master_volume > 0.001 else -80.0)
	var music_bus: int = AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume) if music_volume > 0.001 else -80.0)
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume) if sfx_volume > 0.001 else -80.0)

func apply_all_settings() -> void:
	apply_audio_buses()

func serialize() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"reduced_motion": reduced_motion,
		"high_contrast": high_contrast,
		"text_scale": text_scale
	}

func deserialize(data: Dictionary) -> Error:
	master_volume = clampf(float(data.get("master_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 0.9)), 0.0, 1.0)
	reduced_motion = bool(data.get("reduced_motion", false))
	high_contrast = bool(data.get("high_contrast", false))
	text_scale = clampf(float(data.get("text_scale", 1.0)), 0.8, 1.5)
	return OK

func save_settings(path: String = SETTINGS_FILE_PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(serialize(), "\t"))
	f.close()
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
		return ERR_INVALID_DATA
	var err: Error = deserialize(parsed as Dictionary)
	if err == OK:
		apply_audio_buses()
	return err
