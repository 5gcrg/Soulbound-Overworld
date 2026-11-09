class_name ProfileStore
extends RefCounted

## ProfileStore — SBL-W3-002 Storage Foundation (Immutable Revisions)

const VALID_PROFILE_IDS: PackedStringArray = ["profile_01", "profile_02", "profile_03"]
const REQUIRED_ENVELOPE_KEYS: Array[String] = [
	"schema_version", "profile_id", "character", "inventory", "world", "education"
]
const CURRENT_SCHEMA_VERSION: int = 1
const MAX_JSON_BYTES: int = 4 * 1024 * 1024
const MAX_DEPTH: int = 64
const MIN_SAFE_INT: int = -9007199254740991
const MAX_SAFE_INT: int = 9007199254740991
const MAX_REVISION: int = 9999999999999999

var _root_path: String
var _file_regex: RegEx

func _init(root_path: String = "user://profiles") -> void:
	_root_path = root_path
	_file_regex = RegEx.new()
	_file_regex.compile(r"^profile\.(\d{16})\.(\d+)\.(\d+)\.json$")

# ==============================================================================
# Public API
# ==============================================================================

func new_profile(profile_id: String) -> Dictionary:
	if not _is_valid_profile_id(profile_id):
		return {}
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"profile_id": profile_id,
		"character": {}, "inventory": {}, "world": {}, "education": {}
	}

func save_profile(profile_id: String, data: Dictionary) -> Error:
	if not _is_valid_profile_id(profile_id):
		return ERR_INVALID_PARAMETER
	var val_err: Error = _validate_envelope(data, profile_id)
	if val_err != OK:
		return val_err
	# Godot parses 1 as float; serialize the envelope version as integer 1 without mutating the caller.
	var envelope: Dictionary = data.duplicate(false)
	envelope["schema_version"] = CURRENT_SCHEMA_VERSION
	var raw_text: String = JSON.stringify(envelope, "\t", true, true)
	var raw_bytes: PackedByteArray = raw_text.to_utf8_buffer()
	if raw_bytes.is_empty() or raw_bytes.size() > MAX_JSON_BYTES:
		return ERR_INVALID_DATA
	var dec: Dictionary = _decode(raw_text, profile_id)
	if dec["error"] != OK:
		return dec["error"]
	# JSON parses every number as float, so compare numerically rather than by Variant type.
	if not _same_json(envelope, dec["data"]):
		return ERR_INVALID_DATA
	return _commit_profile(profile_id, raw_text)

func load_profile(profile_id: String) -> Dictionary:
	var rec: Dictionary = _load_active_record(profile_id)
	return {"error": rec["error"], "profile": rec.get("data", {}), "recovered": rec.get("recovered", false)}

func import_backup(profile_id: String, text: String, validate: Callable = Callable()) -> Error:
	if not _is_valid_profile_id(profile_id):
		return ERR_INVALID_PARAMETER
	var raw_bytes: PackedByteArray = text.to_utf8_buffer()
	if raw_bytes.is_empty() or raw_bytes.size() > MAX_JSON_BYTES:
		return ERR_INVALID_DATA
	if raw_bytes.get_string_from_utf8() != text:
		return ERR_FILE_CORRUPT
	var dec: Dictionary = _decode(text, profile_id)
	if dec["error"] != OK:
		return dec["error"]
	if validate.is_valid():
		var val_res: Variant = validate.call(dec["data"])
		if val_res is int:
			if (val_res as int) != OK:
				return val_res as Error
		elif val_res is bool:
			if not (val_res as bool):
				return ERR_INVALID_DATA
	return _commit_profile(profile_id, text)

func export_backup(profile_id: String) -> Dictionary:
	var rec: Dictionary = _load_active_record(profile_id)
	return {"error": rec["error"], "text": "" if rec["error"] != OK else rec["text"]}

# ==============================================================================
# Commit & Storage Pipeline
# ==============================================================================

func _commit_profile(profile_id: String, raw_text: String) -> Error:
	var bytes: PackedByteArray = raw_text.to_utf8_buffer()
	if bytes.is_empty() or bytes.size() > MAX_JSON_BYTES:
		return ERR_INVALID_DATA
	var slot_dir: String = _get_slot_dir(profile_id)
	var dir_err: Error = _ensure_dir_exists(slot_dir)
	if dir_err != OK:
		return dir_err

	var listing: Dictionary = _list_profile_files(profile_id)
	if listing["error"] != OK:
		return listing["error"]
	var files: Array[String] = listing["files"]

	# Corrupt and unknown revisions are never pruned. Only valid v1 revisions older
	# than the newest prior valid one are pruned, and only after the commit succeeds.
	var prior_valid_found: bool = false
	var to_prune: Array[String] = []
	for fname in files:
		var rec: Dictionary = _read_record(slot_dir.path_join(fname), profile_id)
		if rec["is_unsupported"]:
			return ERR_FILE_UNRECOGNIZED
		if rec["is_oversized"]:
			return ERR_INVALID_DATA
		if rec["is_io_error"]:
			return rec["error"]
		if rec["error"] == OK:
			if prior_valid_found:
				to_prune.append(fname)
			else:
				prior_valid_found = true

	var next_rev: int = 1
	if not files.is_empty():
		var m: RegExMatch = _file_regex.search(files[0])
		if m == null:
			return ERR_FILE_CORRUPT
		var newest_rev: int = m.get_string(1).to_int()
		if newest_rev >= MAX_REVISION:
			return ERR_PARAMETER_RANGE_ERROR
		next_rev = newest_rev + 1

	var base_name: String = "profile.%016d.%d.%d" % [next_rev, OS.get_process_id(), Time.get_ticks_usec()]
	var tmp_path: String = slot_dir.path_join(base_name + ".tmp")
	var final_path: String = slot_dir.path_join(base_name + ".json")

	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		var open_err: Error = FileAccess.get_open_error()
		return open_err if open_err != OK else ERR_FILE_CANT_WRITE
	file.store_buffer(bytes)
	file.flush()
	file.close()

	var vfile: FileAccess = FileAccess.open(tmp_path, FileAccess.READ)
	if vfile == null:
		_remove_file_if_exists(tmp_path)
		var read_open_err: Error = FileAccess.get_open_error()
		return read_open_err if read_open_err != OK else ERR_FILE_CANT_READ
	var staged_len: int = vfile.get_length()
	if staged_len != bytes.size():
		vfile.close()
		_remove_file_if_exists(tmp_path)
		return ERR_FILE_CORRUPT
	var read_bytes: PackedByteArray = vfile.get_buffer(bytes.size())
	vfile.close()
	if read_bytes.size() != bytes.size() or read_bytes != bytes:
		_remove_file_if_exists(tmp_path)
		return ERR_FILE_CORRUPT

	var promote_err: Error = _promote_revision(tmp_path, final_path)
	if promote_err != OK:
		_remove_file_if_exists(tmp_path)
		return promote_err

	for fname in to_prune:
		DirAccess.remove_absolute(_global_path(slot_dir.path_join(fname)))
	return OK

## Moves a staged temp file onto an absent final revision path. Isolated so tests can inject failures.
func _promote_revision(temp_path: String, final_path: String) -> Error:
	if FileAccess.file_exists(final_path):
		return ERR_ALREADY_EXISTS
	return DirAccess.rename_absolute(_global_path(temp_path), _global_path(final_path))

func _load_active_record(profile_id: String) -> Dictionary:
	if not _is_valid_profile_id(profile_id):
		return {"error": ERR_INVALID_PARAMETER, "data": {}, "text": "", "recovered": false}
	var listing: Dictionary = _list_profile_files(profile_id)
	if listing["error"] != OK:
		return {"error": listing["error"], "data": {}, "text": "", "recovered": false}
	var files: Array[String] = listing["files"]
	if files.is_empty():
		return {"error": ERR_FILE_NOT_FOUND, "data": {}, "text": "", "recovered": false}
	var slot_dir: String = _get_slot_dir(profile_id)
	var last_corrupt_err: Error = ERR_FILE_CORRUPT
	for i in range(files.size()):
		var rec: Dictionary = _read_record(slot_dir.path_join(files[i]), profile_id)
		if rec["error"] == OK:
			rec["recovered"] = (i > 0)
			return rec
		# Stop at any unsupported/oversized/IO record, even if newer revisions were corrupt.
		if rec["is_unsupported"] or rec["is_oversized"] or rec["is_io_error"]:
			return {"error": rec["error"], "data": {}, "text": "", "recovered": false}
		last_corrupt_err = rec["error"]
	return {"error": last_corrupt_err, "data": {}, "text": "", "recovered": false}

func _read_record(path: String, profile_id: String) -> Dictionary:
	var res: Dictionary = {
		"error": OK, "data": {}, "text": "",
		"is_unsupported": false, "is_io_error": false, "is_oversized": false
	}
	if not FileAccess.file_exists(path):
		res["error"] = ERR_FILE_NOT_FOUND
		res["is_io_error"] = true
		return res
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var err: Error = FileAccess.get_open_error()
		res["error"] = err if err != OK else ERR_FILE_CANT_OPEN
		res["is_io_error"] = true
		return res
	var file_len: int = file.get_length()
	if file_len > MAX_JSON_BYTES or file_len == 0:
		file.close()
		res["error"] = ERR_INVALID_DATA if file_len > MAX_JSON_BYTES else ERR_FILE_CORRUPT
		res["is_oversized"] = file_len > MAX_JSON_BYTES
		return res
	var bytes: PackedByteArray = file.get_buffer(file_len)
	file.close()
	if bytes.size() != file_len:
		res["error"] = ERR_FILE_CANT_READ
		res["is_io_error"] = true
		return res
	var text: String = bytes.get_string_from_utf8()
	if text.is_empty() or text.to_utf8_buffer() != bytes:
		res["error"] = ERR_FILE_CORRUPT
		return res
	var dec: Dictionary = _decode(text, profile_id)
	var dec_err: Error = ERR_FILE_CORRUPT if dec["error"] == ERR_PARSE_ERROR else dec["error"]
	if dec_err != OK:
		res["error"] = dec_err
		res["is_unsupported"] = (dec_err == ERR_FILE_UNRECOGNIZED)
		return res
	res["data"] = dec["data"]
	res["text"] = text
	return res

# ==============================================================================
# Validation & Parsing Helpers
# ==============================================================================

## Shared decode for disk, import and save paths.
func _decode(text: String, expected_profile_id: String) -> Dictionary:
	var strict_json: GDScript = preload("res://scripts/persistence/strict_profile_json.gd")
	var info: Dictionary = strict_json.inspect(text, MAX_DEPTH)
	if not info["accepted"]:
		return {"error": ERR_PARSE_ERROR, "data": {}}
	# Native JSON rounds e.g. 1.00000000000000001 to 1, so judge the raw token text, never the parsed float.
	# Mathematically exact spellings of 1 (1.0, 1e0, 100e-2) are legacy schema 1; any other numeric
	# top-level version is a well-formed unsupported schema, not corruption.
	var token: String = info["schema_version_token"]
	var numeric_token: bool = _is_number_token(token)
	var exact_one: bool = numeric_token and _is_exact_schema_one(token)
	if numeric_token and not exact_one:
		return {"error": ERR_FILE_UNRECOGNIZED, "data": {}}
	# Exact version 1 (or a non-numeric token) must not carry numbers violating schema-1 rules.
	if not info["numbers_valid"]:
		return {"error": ERR_PARSE_ERROR, "data": {}}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"error": ERR_PARSE_ERROR, "data": {}}
	if not (json.data is Dictionary):
		return {"error": ERR_INVALID_DATA, "data": {}}
	var dict: Dictionary = json.data as Dictionary
	if exact_one and dict.has("schema_version"):
		# The token was proven exactly 1 by text; do not let float parsing of the spelling decide.
		dict["schema_version"] = 1.0
	var err: Error = _validate_envelope(dict, expected_profile_id)
	return {"error": err, "data": dict if err == OK else {}}

func _is_number_token(token: String) -> bool:
	if token.is_empty():
		return false
	var c: int = token.unicode_at(0)
	return c == 0x2D or (c >= 0x30 and c <= 0x39)

## Exact decimal check on the raw (already syntax-validated) number token: true only when its
## mathematical value is exactly 1. Pure text arithmetic, no float conversion, no overflow.
func _is_exact_schema_one(token: String) -> bool:
	if token == "1":
		return true
	if token.is_empty() or token.begins_with("-"):
		return false
	var e_pos: int = -1
	for i in range(token.length()):
		var ch: String = token[i]
		if ch == "e" or ch == "E":
			e_pos = i
			break
	var mantissa: String = token
	var exp_text: String = ""
	if e_pos >= 0:
		mantissa = token.substr(0, e_pos)
		exp_text = token.substr(e_pos + 1)
	var int_part: String = mantissa
	var frac_part: String = ""
	var dot_pos: int = mantissa.find(".")
	if dot_pos >= 0:
		int_part = mantissa.substr(0, dot_pos)
		frac_part = mantissa.substr(dot_pos + 1)
	# Value = digits * 10^(exponent - fractional digits); drop the dot and leading zeros.
	var digits: String = (int_part + frac_part).lstrip("0")
	var significant: String = digits.rstrip("0")
	if significant != "1":
		return false
	var trailing_zeros: int = digits.length() - significant.length()
	var required_exp: int = frac_part.length() - trailing_zeros
	# Normalize the actual exponent text (optional sign, leading zeros) and compare textually.
	var exp_negative: bool = false
	var exp_digits: String = exp_text
	if exp_digits.begins_with("-"):
		exp_negative = true
		exp_digits = exp_digits.substr(1)
	elif exp_digits.begins_with("+"):
		exp_digits = exp_digits.substr(1)
	exp_digits = exp_digits.lstrip("0")
	if exp_digits.is_empty():
		exp_negative = false
	var required_digits: String = "" if required_exp == 0 else str(absi(required_exp))
	return exp_negative == (required_exp < 0) and exp_digits == required_digits

func _validate_envelope(data: Dictionary, expected_profile_id: String) -> Error:
	for key in data.keys():
		if typeof(key) != TYPE_STRING:
			return ERR_INVALID_DATA
	if not data.has("schema_version"):
		return ERR_INVALID_DATA
	var ver: Variant = data["schema_version"]
	if not (ver is int or ver is float):
		return ERR_INVALID_DATA
	if (ver is int and ver != CURRENT_SCHEMA_VERSION) or (ver is float and ver != 1.0):
		return ERR_FILE_UNRECOGNIZED
	for k in REQUIRED_ENVELOPE_KEYS:
		if not data.has(k):
			return ERR_INVALID_DATA
	if typeof(data["profile_id"]) != TYPE_STRING or data["profile_id"] != expected_profile_id:
		return ERR_INVALID_DATA
	for sec_name in ["character", "inventory", "world", "education"]:
		var sec: Variant = data[sec_name]
		if typeof(sec) != TYPE_DICTIONARY or not _validate_json_native_value(sec, 0):
			return ERR_INVALID_DATA
	for key: String in data.keys():
		if not REQUIRED_ENVELOPE_KEYS.has(key):
			if not _validate_json_native_value(data[key], 0):
				return ERR_INVALID_DATA
	return OK

func _validate_json_native_value(value: Variant, depth: int) -> bool:
	if depth > MAX_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return value >= MIN_SAFE_INT and value <= MAX_SAFE_INT
		TYPE_FLOAT:
			var f: float = value as float
			return is_finite(f) and not is_nan(f) and (floor(f) != f or (f >= MIN_SAFE_INT and f <= MAX_SAFE_INT))
		TYPE_ARRAY:
			for elem in value as Array:
				if not _validate_json_native_value(elem, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for k in (value as Dictionary).keys():
				if typeof(k) != TYPE_STRING:
					return false
				if not _validate_json_native_value(value[k], depth + 1):
					return false
			return true
		_:
			return false

## Recursive JSON equality: numbers compare by value (JSON has no int/float distinction).
func _same_json(a: Variant, b: Variant) -> bool:
	if a is int or a is float:
		if not (b is int or b is float):
			return false
		return float(a) == float(b)
	if a is Dictionary:
		if not (b is Dictionary):
			return false
		var da: Dictionary = a as Dictionary
		var db: Dictionary = b as Dictionary
		if da.size() != db.size():
			return false
		for k in da.keys():
			if not db.has(k):
				return false
			if not _same_json(da[k], db[k]):
				return false
		return true
	if a is Array:
		if not (b is Array):
			return false
		var aa: Array = a as Array
		var ab: Array = b as Array
		if aa.size() != ab.size():
			return false
		for i in range(aa.size()):
			if not _same_json(aa[i], ab[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b

# ==============================================================================
# Filesystem Helpers
# ==============================================================================

## Returns {"error": Error, "files": Array[String]} sorted newest revision first.
## A missing slot directory is an empty listing; any other DirAccess failure is propagated.
func _list_profile_files(profile_id: String) -> Dictionary:
	var files: Array[String] = []
	var dir_path: String = _get_slot_dir(profile_id)
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		var open_err: Error = DirAccess.get_open_error()
		if open_err == OK:
			open_err = ERR_CANT_OPEN
		return {"error": _missing_slot_error(dir_path, open_err), "files": files}
	var list_err: Error = dir.list_dir_begin()
	if list_err != OK:
		return {"error": list_err, "files": files}
	var fname: String = dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and _file_regex.search(fname) != null:
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	files.reverse()
	return {"error": OK, "files": files}

## Classifies a failed slot open. Walks upward from the globalized slot path to the nearest
## accessible parent and lists it (hidden entries included) looking for the missing child.
## Returns OK when the child is absent from that parent (slot genuinely missing); returns
## open_err when the child is present or no parent can be inspected.
func _missing_slot_error(slot_path: String, open_err: Error) -> Error:
	var child: String = _global_path(slot_path).simplify_path()
	var case_insensitive: bool = OS.get_name() == "Windows"
	while true:
		if child.length() > 1 and not child.ends_with(":/"):
			child = child.rstrip("/")
		var child_name: String = child.get_file()
		var parent: String = child.get_base_dir()
		if child_name.is_empty() or parent.is_empty() or parent == child:
			return open_err
		var parent_dir: DirAccess = DirAccess.open(parent)
		if parent_dir != null:
			parent_dir.include_hidden = true
			if parent_dir.list_dir_begin() == OK:
				var found: bool = false
				var entry: String = parent_dir.get_next()
				while not entry.is_empty():
					if (entry.nocasecmp_to(child_name) == 0) if case_insensitive else (entry == child_name):
						found = true
						break
					entry = parent_dir.get_next()
				parent_dir.list_dir_end()
				return open_err if found else OK
		child = parent
	return open_err

func _is_valid_profile_id(pid: String) -> bool:
	return pid in VALID_PROFILE_IDS

func _get_slot_dir(pid: String) -> String:
	return _root_path.path_join(pid)

func _global_path(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func _ensure_dir_exists(p: String) -> Error:
	var gp: String = _global_path(p)
	if DirAccess.dir_exists_absolute(gp):
		return OK
	return DirAccess.make_dir_recursive_absolute(gp)

func _remove_file_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_global_path(path))
