class_name ProfileStore
extends RefCounted

## ProfileStore — SBL-W3-002 Storage Foundation
##
## Manages atomic, versioned profile storage across three isolated slots:
## profile_01, profile_02, and profile_03.
## Conforms to GDD-098/099/100/102, FR-SAV-001/002 partial, and TC-SAV-001/002.
##
## Note on scope: Expedition state persistence is separate and future.
## Only schema_version 1 envelopes with keys: schema_version, profile_id,
## character, inventory, world, and education are accepted.
## Any extra/unknown keys (including "expedition") are strictly rejected.

const VALID_PROFILE_IDS: PackedStringArray = [
	"profile_01",
	"profile_02",
	"profile_03"
]

const REQUIRED_ENVELOPE_KEYS: Array[String] = [
	"schema_version",
	"profile_id",
	"character",
	"inventory",
	"world",
	"education"
]

const PRIMARY_FILENAME: String = "profile.json"
const BACKUP_FILENAME: String = "profile.backup.json"
const PRIMARY_TMP_FILENAME: String = "profile.json.tmp"
const BACKUP_TMP_FILENAME: String = "profile.backup.json.tmp"

const CURRENT_SCHEMA_VERSION: int = 1
const MAX_JSON_BYTES: int = 4 * 1024 * 1024 # 4 MiB max payload
const MAX_DEPTH: int = 64
const MIN_SAFE_INT: int = -9007199254740991
const MAX_SAFE_INT: int = 9007199254740991

var _root_path: String


func _init(root_path: String = "user://profiles") -> void:
	_root_path = root_path


# ==============================================================================
# Public API
# ==============================================================================

## Returns an empty, valid schema_version 1 envelope for the given slot.
## Sections are default empty dictionaries with no fabricated game data.
## Returns an empty Dictionary if profile_id is invalid.
func new_profile(profile_id: String) -> Dictionary:
	if not _is_valid_profile_id(profile_id):
		return {}

	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"profile_id": profile_id,
		"character": {},
		"inventory": {},
		"world": {},
		"education": {}
	}


## Atomically saves validated profile data to the specified slot.
## Staging, verification, prior primary backup promotion, and atomic rename
## ensure that at least one recoverable valid copy is preserved on disk.
func save_profile(profile_id: String, data: Dictionary) -> Error:
	if not _is_valid_profile_id(profile_id):
		return ERR_INVALID_PARAMETER

	# 1. Validate data in memory before touching any file on disk.
	var val_err: Error = _validate_envelope_and_sections(data, profile_id)
	if val_err != OK:
		return val_err

	# 2. Serialize using full precision and bound payload byte size before writing.
	var new_text: String = JSON.stringify(data, "\t", true, true)
	var new_bytes: PackedByteArray = new_text.to_utf8_buffer()
	if new_bytes.size() > MAX_JSON_BYTES:
		return ERR_INVALID_DATA

	# 3. Ensure destination slot directory exists.
	var slot_dir: String = _get_slot_dir(profile_id)
	var dir_err: Error = _ensure_dir_exists(slot_dir)
	if dir_err != OK:
		return dir_err

	var primary_path: String = _get_primary_path(profile_id)
	var backup_path: String = _get_backup_path(profile_id)
	var backup_tmp_path: String = _get_backup_tmp_path(profile_id)
	var primary_tmp_path: String = _get_primary_tmp_path(profile_id)

	# 4. Inspect existing primary if present.
	if FileAccess.file_exists(primary_path):
		var primary_file: FileAccess = FileAccess.open(primary_path, FileAccess.READ)
		if primary_file == null:
			var open_err: Error = FileAccess.get_open_error()
			return open_err if open_err != OK else ERR_FILE_CANT_OPEN

		var primary_len: int = primary_file.get_length()
		if primary_len > MAX_JSON_BYTES:
			primary_file.close()
			# Primary is oversized/corrupt. Do not stage as backup.
		else:
			var primary_text: String = primary_file.get_as_text()
			primary_file.close()

			var json: JSON = JSON.new()
			var parse_err: Error = json.parse(primary_text)
			if parse_err == OK and json.data is Dictionary:
				var parsed_primary: Dictionary = json.data as Dictionary
				# Check for unsupported version before overwriting.
				if parsed_primary.has("schema_version"):
					var ver: Variant = parsed_primary["schema_version"]
					if (ver is int or ver is float) and int(ver) != CURRENT_SCHEMA_VERSION:
						return ERR_FILE_UNRECOGNIZED

				# If prior primary is valid, stage and promote to backup.
				if _validate_envelope_and_sections(parsed_primary, profile_id) == OK:
					var backup_err: Error = _stage_and_promote_backup(
						backup_tmp_path,
						backup_path,
						primary_text,
						primary_len
					)
					if backup_err != OK:
						return backup_err
				else:
					# Corrupt primary: do not overwrite good backup with corrupt primary.
					pass
			else:
				# Malformed JSON in primary: do not overwrite good backup.
				pass

	# 5. Stage write new primary to temporary file, flush, close, and verify read-back.
	var write_err: Error = _stage_and_verify_file(primary_tmp_path, new_text, new_bytes.size())
	if write_err != OK:
		_remove_file_if_exists(primary_tmp_path)
		return write_err

	# 6. Atomically rename staged temporary file to final primary file.
	var rename_err: Error = _atomic_rename(primary_tmp_path, primary_path)
	if rename_err != OK:
		_remove_file_if_exists(primary_tmp_path)
		return rename_err

	return OK


## Loads the active profile for the given slot.
## Tries the primary file first; if missing or corrupt, falls back to the last-good backup.
## Returns a Dictionary with keys:
##   - "error": Error
##   - "profile": Dictionary
##   - "recovered": bool (true if loaded from backup fallback)
## Never reads from temp files and executes no implicit writes.
func load_profile(profile_id: String) -> Dictionary:
	var result: Dictionary = {
		"error": OK,
		"profile": {},
		"recovered": false
	}

	if not _is_valid_profile_id(profile_id):
		result["error"] = ERR_INVALID_PARAMETER
		return result

	var primary_path: String = _get_primary_path(profile_id)
	var backup_path: String = _get_backup_path(profile_id)

	# 1. Check primary file if it exists.
	if FileAccess.file_exists(primary_path):
		var primary_read: Dictionary = _read_and_validate_file(primary_path, profile_id)
		if primary_read["error"] == OK:
			result["error"] = OK
			result["profile"] = primary_read["data"]
			result["recovered"] = false
			return result

		# Refuse to silently downgrade or bypass unsupported versions / I/O errors.
		if primary_read["is_unsupported_version"]:
			result["error"] = ERR_FILE_UNRECOGNIZED
			return result
		if primary_read["is_io_error"]:
			result["error"] = primary_read["error"]
			return result

		# Primary exists but is corrupt on disk. Proceed to backup fallback.

	# 2. Fallback to backup if primary was missing or corrupt.
	if FileAccess.file_exists(backup_path):
		var backup_read: Dictionary = _read_and_validate_file(backup_path, profile_id)
		if backup_read["error"] == OK:
			result["error"] = OK
			result["profile"] = backup_read["data"]
			result["recovered"] = true
			return result

		result["error"] = backup_read["error"]
		return result

	# Neither primary nor backup exists.
	result["error"] = ERR_FILE_NOT_FOUND
	return result


## Imports and validates an external profile backup JSON string into the slot.
## Rejects malformed text, wrong slot, or invalid versions without touching disk.
func import_backup(profile_id: String, text: String) -> Error:
	if not _is_valid_profile_id(profile_id):
		return ERR_INVALID_PARAMETER

	var utf8_bytes: PackedByteArray = text.to_utf8_buffer()
	var byte_size: int = utf8_bytes.size()
	if byte_size == 0 or byte_size > MAX_JSON_BYTES:
		return ERR_INVALID_DATA

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(text)
	if parse_err != OK:
		return ERR_PARSE_ERROR

	if not (json.data is Dictionary):
		return ERR_INVALID_DATA

	var parsed_dict: Dictionary = json.data as Dictionary

	# Check schema version explicitly for distinct version error.
	if parsed_dict.has("schema_version"):
		var ver: Variant = parsed_dict["schema_version"]
		if (ver is int or ver is float) and int(ver) != CURRENT_SCHEMA_VERSION:
			return ERR_FILE_UNRECOGNIZED

	var val_err: Error = _validate_envelope_and_sections(parsed_dict, profile_id)
	if val_err != OK:
		return val_err

	# Validated successfully; commit to disk via safe save_profile.
	return save_profile(profile_id, parsed_dict)


## Exports the active profile from the slot as a JSON string.
## Returns a Dictionary with keys:
##   - "error": Error
##   - "text": String
func export_backup(profile_id: String) -> Dictionary:
	var result: Dictionary = {
		"error": OK,
		"text": ""
	}

	if not _is_valid_profile_id(profile_id):
		result["error"] = ERR_INVALID_PARAMETER
		return result

	var load_res: Dictionary = load_profile(profile_id)
	if load_res["error"] != OK:
		result["error"] = load_res["error"]
		return result

	var profile_dict: Dictionary = load_res["profile"]
	var text: String = JSON.stringify(profile_dict, "\t", true, true)
	if text.to_utf8_buffer().size() > MAX_JSON_BYTES:
		result["error"] = ERR_INVALID_DATA
		return result

	result["error"] = OK
	result["text"] = text
	return result


# ==============================================================================
# Validation Helpers
# ==============================================================================

func _is_valid_profile_id(profile_id: String) -> bool:
	return profile_id in VALID_PROFILE_IDS


func _validate_envelope_and_sections(data: Dictionary, expected_profile_id: String) -> Error:
	# Reject unknown or missing envelope keys.
	if data.size() != REQUIRED_ENVELOPE_KEYS.size():
		return ERR_INVALID_DATA

	for required_key in REQUIRED_ENVELOPE_KEYS:
		if not data.has(required_key):
			return ERR_INVALID_DATA

	for key in data.keys():
		if typeof(key) != TYPE_STRING or not REQUIRED_ENVELOPE_KEYS.has(key):
			return ERR_INVALID_DATA

	# Validate schema_version.
	var ver: Variant = data["schema_version"]
	if not (ver is int or ver is float):
		return ERR_INVALID_DATA
	if int(ver) != CURRENT_SCHEMA_VERSION:
		return ERR_FILE_UNRECOGNIZED

	# Validate profile_id.
	var pid: Variant = data["profile_id"]
	if typeof(pid) != TYPE_STRING:
		return ERR_INVALID_DATA
	if pid != expected_profile_id:
		return ERR_INVALID_DATA

	# Validate mandatory sections: character, inventory, world, education.
	var section_names: Array[String] = ["character", "inventory", "world", "education"]
	for section_name in section_names:
		var section: Variant = data[section_name]
		if typeof(section) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		if not _validate_json_native_value(section, 0):
			return ERR_INVALID_DATA

	return OK


func _validate_json_native_value(value: Variant, depth: int) -> bool:
	if depth > MAX_DEPTH:
		return false

	var v_type: int = typeof(value)
	match v_type:
		TYPE_NIL, TYPE_BOOL:
			return true
		TYPE_INT:
			var int_val: int = value as int
			return int_val >= MIN_SAFE_INT and int_val <= MAX_SAFE_INT
		TYPE_FLOAT:
			var float_val: float = value as float
			return not is_nan(float_val) and not is_inf(float_val) and is_finite(float_val)
		TYPE_STRING:
			return true
		TYPE_ARRAY:
			var arr: Array = value as Array
			for elem in arr:
				if not _validate_json_native_value(elem, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			var dict: Dictionary = value as Dictionary
			for k in dict.keys():
				if typeof(k) != TYPE_STRING:
					return false
				if not _validate_json_native_value(dict[k], depth + 1):
					return false
			return true
		_:
			return false


# ==============================================================================
# File and Path Helpers
# ==============================================================================

func _get_slot_dir(profile_id: String) -> String:
	return _root_path.path_join(profile_id)


func _get_primary_path(profile_id: String) -> String:
	return _get_slot_dir(profile_id).path_join(PRIMARY_FILENAME)


func _get_backup_path(profile_id: String) -> String:
	return _get_slot_dir(profile_id).path_join(BACKUP_FILENAME)


func _get_primary_tmp_path(profile_id: String) -> String:
	return _get_slot_dir(profile_id).path_join(PRIMARY_TMP_FILENAME)


func _get_backup_tmp_path(profile_id: String) -> String:
	return _get_slot_dir(profile_id).path_join(BACKUP_TMP_FILENAME)


func _global_path(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _ensure_dir_exists(dir_path: String) -> Error:
	var global_dir: String = _global_path(dir_path)
	if DirAccess.dir_exists_absolute(global_dir):
		return OK
	return DirAccess.make_dir_recursive_absolute(global_dir)


func _remove_file_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_global_path(path))


func _atomic_rename(from_path: String, to_path: String) -> Error:
	var global_from: String = _global_path(from_path)
	var global_to: String = _global_path(to_path)

	var err: Error = DirAccess.rename_absolute(global_from, global_to)
	if err != OK:
		# Fallback for platforms where rename_absolute fails if destination exists.
		if FileAccess.file_exists(to_path):
			DirAccess.remove_absolute(global_to)
			err = DirAccess.rename_absolute(global_from, global_to)
	return err


func _stage_and_verify_file(tmp_path: String, text: String, expected_byte_size: int) -> Error:
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		var open_err: Error = FileAccess.get_open_error()
		return open_err if open_err != OK else ERR_FILE_CANT_WRITE

	file.store_string(text)
	file.flush()
	file.close()

	var verify_file: FileAccess = FileAccess.open(tmp_path, FileAccess.READ)
	if verify_file == null:
		var read_open_err: Error = FileAccess.get_open_error()
		return read_open_err if read_open_err != OK else ERR_FILE_CANT_READ

	var read_len: int = verify_file.get_length()
	if read_len != expected_byte_size:
		verify_file.close()
		return ERR_FILE_CORRUPT

	var read_text: String = verify_file.get_as_text()
	verify_file.close()

	if read_text != text:
		return ERR_FILE_CORRUPT

	return OK


func _stage_and_promote_backup(
	backup_tmp_path: String,
	backup_path: String,
	text: String,
	expected_byte_size: int
) -> Error:
	var stage_err: Error = _stage_and_verify_file(backup_tmp_path, text, expected_byte_size)
	if stage_err != OK:
		_remove_file_if_exists(backup_tmp_path)
		return stage_err

	var rename_err: Error = _atomic_rename(backup_tmp_path, backup_path)
	if rename_err != OK:
		_remove_file_if_exists(backup_tmp_path)
		return rename_err

	return OK


func _read_and_validate_file(path: String, expected_profile_id: String) -> Dictionary:
	var result: Dictionary = {
		"error": OK,
		"data": {},
		"is_unsupported_version": false,
		"is_io_error": false
	}

	if not FileAccess.file_exists(path):
		result["error"] = ERR_FILE_NOT_FOUND
		return result

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_err: Error = FileAccess.get_open_error()
		result["error"] = open_err if open_err != OK else ERR_FILE_CANT_OPEN
		result["is_io_error"] = true
		return result

	var file_len: int = file.get_length()
	if file_len == 0 or file_len > MAX_JSON_BYTES:
		file.close()
		result["error"] = ERR_INVALID_DATA
		return result

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(text)
	if parse_err != OK:
		result["error"] = ERR_FILE_CORRUPT
		return result

	if not (json.data is Dictionary):
		result["error"] = ERR_INVALID_DATA
		return result

	var parsed: Dictionary = json.data as Dictionary

	if parsed.has("schema_version"):
		var ver: Variant = parsed["schema_version"]
		if (ver is int or ver is float) and int(ver) != CURRENT_SCHEMA_VERSION:
			result["error"] = ERR_FILE_UNRECOGNIZED
			result["is_unsupported_version"] = true
			return result

	var val_err: Error = _validate_envelope_and_sections(parsed, expected_profile_id)
	if val_err != OK:
		result["error"] = val_err
		return result

	result["error"] = OK
	result["data"] = parsed
	return result
