extends SceneTree

## SBL-W3-002 save model test: local profile model and JSON text only.
## Fixtures live under a unique user:// root per run and only known test paths are removed.

const StoreScript = preload("res://scripts/persistence/profile_store.gd")
const SLOTS: Array[String] = ["profile_01", "profile_02", "profile_03"]
const ROOT_PREFIX: String = "user://sbl_w3_002_test_"
const TEMPLATE: String = '{"schema_version":%s,"profile_id":"%s","character":{%s},"inventory":{},"world":{},"education":{}}'

## Injects a promotion failure after the staged file has been verified.
class FailingStore extends "res://scripts/persistence/profile_store.gd":
	func _promote_revision(_temp_path: String, _final_path: String) -> Error:
		return ERR_CANT_CREATE

## Counts engine/script errors (not warnings) raised while the suite runs, as smoke_test.gd does.
class SaveErrorCaptureLogger extends Logger:
	var _mutex: Mutex = Mutex.new()
	var error_count: int = 0

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		_code: String,
		_rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			_mutex.lock()
			error_count += 1
			_mutex.unlock()

	func get_error_count() -> int:
		_mutex.lock()
		var count: int = error_count
		_mutex.unlock()
		return count

var _failures: int = 0
var _base: String = ""
var _roots: Array[String] = []
## Regular files planted where a slot directory belongs; removed individually by _cleanup.
var _file_fixtures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_base = ROOT_PREFIX + "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var logger: SaveErrorCaptureLogger = SaveErrorCaptureLogger.new()
	OS.add_logger(logger)
	_test_roundtrip_slots_fallback()
	_test_export_import()
	_test_failed_promotion()
	_test_rejections()
	_test_future_revision()
	_test_schema_version_tokens()
	_test_legacy_schema_spellings()
	_test_size_limits()
	_test_unsafe_int_in_unsupported_schema()
	_test_slot_path_is_regular_file()
	OS.remove_logger(logger)
	_cleanup()
	# Engine/script errors fail the run even if one aborted a helper before any _check ran.
	var captured_errors: int = logger.get_error_count()
	if captured_errors > 0:
		_failures += 1
		printerr("SAVE MODEL TEST FAILED: scoped logger captured %d engine/script error(s)" % captured_errors)
	if _failures > 0:
		printerr("SAVE MODEL TESTS FAILED: ", _failures)
		quit(1)
		return
	print("SAVE MODEL TESTS PASSED")
	quit(0)

# --- Helpers ---------------------------------------------------------------

func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_failures += 1
		printerr("SAVE MODEL TEST FAILED: ", msg)
	return ok

func _root(tag: String) -> String:
	var r: String = _base + "_" + tag
	_roots.append(r)
	return r

func _store(root: String) -> StoreScript:
	return StoreScript.new(root)

func _profile(store: StoreScript, slot: String, level: int) -> Dictionary:
	var p: Dictionary = store.new_profile(slot)
	p["character"]["level"] = level
	p["character"]["stats"] = {"hp": 30, "mods": [0, -4, {"deep": 7}]}
	p["inventory"]["items"] = [{"id": "item_a", "count": 3}]
	p["world"]["flags"] = {"a": {"b": [0, 1, 2]}}
	p["education"]["done"] = [1, 2, 3]
	return p

func _global(path: String) -> String:
	return ProjectSettings.globalize_path(path)

## Committed revisions only (.json), sorted oldest first. .tmp files are ignored.
func _files(root: String, slot: String) -> Array[String]:
	var out: Array[String] = []
	var slot_dir: String = root.path_join(slot)
	if not DirAccess.dir_exists_absolute(_global(slot_dir)):
		return out
	for f: String in DirAccess.get_files_at(slot_dir):
		if f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out

func _file_bytes(root: String, slot: String, fname: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(root.path_join(slot).path_join(fname))

func _snapshot(root: String, slot: String) -> Dictionary:
	var snap: Dictionary = {}
	for f in _files(root, slot):
		snap[f] = _file_bytes(root, slot, f)
	return snap

func _same_snapshot(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k: String in a.keys():
		if not b.has(k) or a[k] != b[k]:
			return false
	return true

func _write_fixture(root: String, slot: String, fname: String, text: String) -> void:
	var dir_path: String = root.path_join(slot)
	DirAccess.make_dir_recursive_absolute(_global(dir_path))
	var f: FileAccess = FileAccess.open(dir_path.path_join(fname), FileAccess.WRITE)
	if _check(f != null, "cannot write fixture " + fname):
		f.store_buffer(text.to_utf8_buffer())
		f.close()

func _text(version: String, slot: String, body: String) -> String:
	return TEMPLATE % [version, slot, body]

## Numeric JSON equality: ordinary ints and decoded floats compare by value.
func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return float(a) == float(b)
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k: Variant in da.keys():
			if not db.has(k) or not _same(da[k], db[k]):
				return false
		return true
	if a is Array and b is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i in aa.size():
			if not _same(aa[i], ab[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b

func _cleanup() -> void:
	# Plain files planted at slot paths: remove only exact known fixtures under the test prefix.
	for fp in _file_fixtures:
		if fp.begins_with(ROOT_PREFIX) and FileAccess.file_exists(fp) and not DirAccess.dir_exists_absolute(_global(fp)):
			DirAccess.remove_absolute(_global(fp))
	for r in _roots:
		if not r.begins_with(ROOT_PREFIX):
			continue
		if not DirAccess.dir_exists_absolute(_global(r)):
			continue
		for slot in SLOTS:
			var d: String = r.path_join(slot)
			if not DirAccess.dir_exists_absolute(_global(d)):
				continue
			for f: String in DirAccess.get_files_at(d):
				if f.begins_with("profile.") and (f.ends_with(".json") or f.ends_with(".tmp")):
					DirAccess.remove_absolute(_global(d.path_join(f)))
			DirAccess.remove_absolute(_global(d))
		DirAccess.remove_absolute(_global(r))

# --- Tests -----------------------------------------------------------------

func _test_roundtrip_slots_fallback() -> void:
	var root: String = _root("a")
	var store: StoreScript = _store(root)
	var saved: Array[Dictionary] = []
	for i in SLOTS.size():
		var p: Dictionary = _profile(store, SLOTS[i], 10 * (i + 1))
		saved.append(p)
		_check(store.save_profile(SLOTS[i], p) == OK, "save " + SLOTS[i])
	for i in SLOTS.size():
		var res: Dictionary = store.load_profile(SLOTS[i])
		var prof: Dictionary = res["profile"]
		_check(res["error"] == OK and not res["recovered"], "load " + SLOTS[i])
		_check(_same(prof, saved[i]), "numeric round trip " + SLOTS[i])
		_check(prof["character"]["level"] == 10 * (i + 1) and int(prof["character"]["level"]) == 10 * (i + 1), "level persists " + SLOTS[i])
		_check(prof["character"]["stats"]["mods"][2]["deep"] == 7 and prof["character"]["stats"]["mods"][1] == -4, "nested ints persist " + SLOTS[i])
		_check(_files(root, SLOTS[i]).size() == 1, "one revision " + SLOTS[i])

	# Second revision in slot 2 leaves slots 1 and 3 untouched.
	var s1: Dictionary = _snapshot(root, SLOTS[0])
	var s3: Dictionary = _snapshot(root, SLOTS[2])
	var rev2: Dictionary = _profile(store, SLOTS[1], 21)
	_check(store.save_profile(SLOTS[1], rev2) == OK, "second revision")
	_check(_files(root, SLOTS[1]).size() == 2, "two committed revisions")
	_check(_same_snapshot(s1, _snapshot(root, SLOTS[0])) and _same_snapshot(s3, _snapshot(root, SLOTS[2])), "other slots unchanged")
	_check(_same(store.load_profile(SLOTS[1])["profile"], rev2), "slot 2 loads newest")
	_check(store.load_profile(SLOTS[0])["profile"]["character"]["level"] == 10 and store.load_profile(SLOTS[2])["profile"]["character"]["level"] == 30, "slots independent")

	# Corrupt newest revision: fall back to older, never rewrite the corrupt bytes.
	var names: Array[String] = _files(root, SLOTS[1])
	var corrupt: PackedByteArray = '{"schema_version":1,'.to_utf8_buffer()
	_write_fixture(root, SLOTS[1], names[1], '{"schema_version":1,')
	var before: Dictionary = _snapshot(root, SLOTS[1])
	_check(before[names[1]] == corrupt, "newest corrupted")
	var rec: Dictionary = store.load_profile(SLOTS[1])
	_check(rec["error"] == OK and rec["recovered"] and rec["profile"]["character"]["level"] == 20, "fallback to older revision")
	_check(store.export_backup(SLOTS[1])["text"].to_utf8_buffer() == before[names[0]], "export uses fallback revision")
	_check(_same_snapshot(before, _snapshot(root, SLOTS[1])), "corrupted bytes not rewritten on load")

	# Both revisions corrupt: error, empty profile, bytes untouched.
	_write_fixture(root, SLOTS[1], names[0], "{")
	before = _snapshot(root, SLOTS[1])
	rec = store.load_profile(SLOTS[1])
	_check(rec["error"] != OK and rec["profile"].is_empty(), "all corrupt revisions fail")
	_check(_same_snapshot(before, _snapshot(root, SLOTS[1])), "all-corrupt bytes not rewritten")

func _test_export_import() -> void:
	var root_a: String = _roots[0]
	var root_b: String = _root("b")
	var store_a: StoreScript = _store(root_a)
	var slot: String = SLOTS[0]
	var exported: Dictionary = store_a.export_backup(slot)
	var newest: PackedByteArray = _file_bytes(root_a, slot, _files(root_a, slot).back())
	_check(exported["error"] == OK and exported["text"].to_utf8_buffer() == newest, "export is raw committed text")
	var store_b: StoreScript = _store(root_b)
	_check(store_b.import_backup(slot, exported["text"]) == OK, "import at fresh root")
	_check(_same(store_b.load_profile(slot)["profile"], store_a.load_profile(slot)["profile"]), "import loads same profile")
	_check(store_b.export_backup(slot)["text"] == exported["text"], "re-export identical text")
	_check(_file_bytes(root_b, slot, _files(root_b, slot)[0]) == newest, "imported bytes identical")
	_check(store_b.import_backup(SLOTS[1], exported["text"]) != OK and _files(root_b, SLOTS[1]).is_empty(), "import into other slot rejected")

func _test_failed_promotion() -> void:
	var root: String = _root("c")
	var slot: String = SLOTS[2]
	var store: StoreScript = _store(root)
	for level in [1, 2, 3]:
		_check(store.save_profile(slot, _profile(store, slot, level)) == OK, "revision %d" % level)
	var names: Array[String] = _files(root, slot)
	_check(names.size() == 2 and names[0].begins_with("profile.0000000000000002.") and names[1].begins_with("profile.0000000000000003."), "two newest revisions kept")
	var before: Dictionary = _snapshot(root, slot)
	var failing: StoreScript = FailingStore.new(root)
	_check(failing.save_profile(slot, _profile(failing, slot, 99)) == ERR_CANT_CREATE, "promotion failure reported")
	_check(_same_snapshot(before, _snapshot(root, slot)), "committed revisions byte-for-byte after failed promotion")
	_check(DirAccess.get_files_at(root.path_join(slot)).size() == 2, "no staged file left behind")
	_check(store.load_profile(slot)["profile"]["character"]["level"] == 3, "newest committed profile still loads")

func _test_rejections() -> void:
	var root: String = _root("r")
	var store: StoreScript = _store(root)
	var slot: String = SLOTS[0]
	var limit: int = StoreScript.MAX_JSON_BYTES
	var bad: Array[Dictionary] = []
	for v: Variant in [9007199254740993, 1.0e20, NAN, Vector2(1, 2)]:
		var p: Dictionary = _profile(store, slot, 1)
		p["character"]["bad"] = [v]
		bad.append(p)
	var keyed: Dictionary = _profile(store, slot, 1)
	keyed["world"]["nested"] = {1: "non-string key"}
	bad.append(keyed)
	var big: Dictionary = _profile(store, slot, 1)
	big["education"]["blob"] = "x".repeat(limit + 1)
	bad.append(big)
	var fraction: Dictionary = _profile(store, slot, 1)
	fraction["schema_version"] = 1.5
	bad.append(fraction)
	var wrong_id: Dictionary = _profile(store, slot, 1)
	wrong_id["profile_id"] = SLOTS[1]
	bad.append(wrong_id)
	for i in bad.size():
		_check(store.save_profile(slot, bad[i]) != OK, "save rejects invalid record %d" % i)
	var good: Dictionary = _profile(store, slot, 1)
	for bad_slot in ["../profile_01", "profile_04", ""]:
		_check(store.save_profile(bad_slot, good) != OK, "save rejects slot '%s'" % bad_slot)
		_check(store.import_backup(bad_slot, _text("1", slot, '"level":1')) != OK, "import rejects slot '%s'" % bad_slot)

	var texts: Dictionary = {
		"leading zero": _text("1", slot, '"level":007'),
		"trailing comma": _text("1", slot, '"level":1,'),
		"duplicate decoded names": _text("1", slot, '"a":1,"\\u0061":2'),
		"fraction version": _text("1.5", slot, '"level":1'),
		"future version": _text("2", slot, '"level":1'),
		"wrong profile id": _text("1", SLOTS[1], '"level":1'),
		"unsafe number": _text("1", slot, '"level":9007199254740993'),
		"malformed": '{"schema_version":1,',
		"empty": "",
		"not an object": "[]",
		"oversized": "x".repeat(limit + 1),
	}
	for label: String in texts.keys():
		_check(store.import_backup(slot, texts[label]) != OK, "import rejects " + label)
	_check(not DirAccess.dir_exists_absolute(_global(root)) or DirAccess.get_directories_at(root).is_empty(), "rejected records create nothing")
	_check(store.import_backup(slot, _text("1", slot, '"level":7')) == OK and _files(root, slot).size() == 1, "valid template imports")

func _test_schema_version_tokens() -> void:
	var slot: String = SLOTS[0]
	var rounded: Array[String] = ["1.00000000000000001", "0.99999999999999999", "2"]
	var late_version: String = '{"character":{"schema_version":1},"inventory":{},"world":{},"education":{},"profile_id":"%s","schema_version":%s}'

	# Imports: native JSON rounds the first two tokens to 1, but only the exact token 1 is schema 1.
	var import_root: String = _root("v")
	var import_store: StoreScript = _store(import_root)
	for token: String in rounded:
		_check(import_store.import_backup(slot, _text(token, slot, '"level":1')) == ERR_FILE_UNRECOGNIZED, "import protects version token " + token)
		_check(import_store.import_backup(slot, late_version % [slot, token]) == ERR_FILE_UNRECOGNIZED, "import checks top-level version token " + token)
	_check(import_store.import_backup(slot, _text('"1"', slot, '"level":1')) == ERR_INVALID_DATA, "string version keeps invalid-data error")
	_check(not DirAccess.dir_exists_absolute(_global(import_root)) or DirAccess.get_directories_at(import_root).is_empty(), "rejected version tokens create nothing")
	# Nested fields named schema_version are ordinary data and never checked.
	var nested: String = _text("1", slot, '"schema_version":1.00000000000000001')
	_check(import_store.import_backup(slot, nested) == OK, "nested schema_version field is not inspected")

	# Committed files with a non-1 version token stay protected from load, save and import.
	for token: String in rounded:
		var root: String = _root("v_" + token.replace(".", "_"))
		var store: StoreScript = _store(root)
		_write_fixture(root, slot, "profile.0000000000000001.1.1.json", _text(token, slot, '"level":9'))
		var before: Dictionary = _snapshot(root, slot)
		var rec: Dictionary = store.load_profile(slot)
		_check(rec["error"] == ERR_FILE_UNRECOGNIZED and rec["profile"].is_empty(), "committed version token %s is unsupported, not corrupt" % token)
		_check(store.save_profile(slot, _profile(store, slot, 5)) == ERR_FILE_UNRECOGNIZED, "save refuses over version token " + token)
		_check(store.import_backup(slot, _text("1", slot, '"level":7')) == ERR_FILE_UNRECOGNIZED, "import refuses over version token " + token)
		_check(_same_snapshot(before, _snapshot(root, slot)), "version token %s files unchanged" % token)

	# Load -> save: Godot parses 1 as float, yet the resaved envelope must carry integer token 1.
	var resave_root: String = _root("w")
	var resave_store: StoreScript = _store(resave_root)
	_check(resave_store.save_profile(slot, _profile(resave_store, slot, 4)) == OK, "resave setup save")
	var loaded: Dictionary = resave_store.load_profile(slot)["profile"]
	var loaded_type: int = typeof(loaded["schema_version"])
	_check(resave_store.save_profile(slot, loaded) == OK, "loaded profile saves again")
	_check(typeof(loaded["schema_version"]) == loaded_type, "save leaves caller's schema_version untouched")
	var names: Array[String] = _files(resave_root, slot)
	_check(names.size() == 2, "resave commits a second revision")
	for fname in names:
		var info: Dictionary = StrictProfileJson.inspect(_file_bytes(resave_root, slot, fname).get_string_from_utf8())
		_check(info["accepted"] and info["schema_version_token"] == "1", "committed token is exactly 1 in " + fname)
	_check(_same(resave_store.load_profile(slot)["profile"], loaded), "resaved profile loads identically")

	var float_version: Dictionary = _profile(resave_store, slot, 6)
	float_version["schema_version"] = 1.0
	_check(resave_store.save_profile(slot, float_version) == OK and typeof(float_version["schema_version"]) == TYPE_FLOAT, "float 1.0 version saves, caller unchanged")
	var newest: String = _files(resave_root, slot).back()
	_check(StrictProfileJson.inspect(_file_bytes(resave_root, slot, newest).get_string_from_utf8())["schema_version_token"] == "1", "float 1.0 serialized as token 1")

## Prior builds stored mathematically exact spellings of 1 (1.0, 1e0, ...). They stay loadable,
## exportable and re-importable byte-for-byte, while near-1, negative and future tokens stay unsupported.
func _test_legacy_schema_spellings() -> void:
	var slot: String = SLOTS[0]
	var exact: Array[String] = ["1.0", "1e0", "1E0", "0.01e2", "100e-2", "10e-1", "1.0E+0", "1e-0", "1e+00", "0.1e1"]
	var inexact: Array[String] = ["1.1", "1.0000000000000000001", "0.9", "10", "1e1", "1e-1", "0.01e1", "100e-1", "1e00001", "11e-1", "-1", "-1.0", "0", "0.0", "2.0"]

	# Exact decimal equivalents import, load and export; everything else is unsupported.
	var import_store: StoreScript = _store(_root("lg_i"))
	for token: String in exact:
		var text: String = _text(token, slot, '"level":1')
		_check(import_store.import_backup(slot, text) == OK, "import accepts exact version spelling " + token)
		var rec: Dictionary = import_store.load_profile(slot)
		_check(rec["error"] == OK and rec["profile"]["character"]["level"] == 1, "load accepts exact version spelling " + token)
		_check(import_store.export_backup(slot)["text"] == text, "export preserves exact text for " + token)
	var reject_root: String = _root("lg_r")
	var reject_store: StoreScript = _store(reject_root)
	for token: String in inexact:
		_check(reject_store.import_backup(slot, _text(token, slot, '"level":1')) == ERR_FILE_UNRECOGNIZED, "import keeps version spelling unsupported " + token)
	_check(not DirAccess.dir_exists_absolute(_global(reject_root)) or DirAccess.get_directories_at(reject_root).is_empty(), "unsupported spellings create nothing")

	# Committed legacy fixture: exact text survives load, export and re-import; next save is canonical.
	var legacy_root: String = _root("lg_c")
	var legacy_store: StoreScript = _store(legacy_root)
	var legacy_name: String = "profile.0000000000000001.1.1.json"
	var legacy_text: String = _text("1.0", slot, '"level":9')
	_write_fixture(legacy_root, slot, legacy_name, legacy_text)
	var legacy_before: Dictionary = _snapshot(legacy_root, slot)
	var loaded: Dictionary = legacy_store.load_profile(slot)
	_check(loaded["error"] == OK and not loaded["recovered"] and loaded["profile"]["character"]["level"] == 9, "legacy 1.0 committed record loads")
	_check(_same_snapshot(legacy_before, _snapshot(legacy_root, slot)), "load leaves legacy file untouched")
	var exported: Dictionary = legacy_store.export_backup(slot)
	_check(exported["error"] == OK and exported["text"] == legacy_text, "legacy 1.0 export preserves exact text")
	var reimport_root: String = _root("lg_e")
	var reimport_store: StoreScript = _store(reimport_root)
	_check(reimport_store.import_backup(slot, exported["text"]) == OK, "legacy 1.0 export re-imports")
	_check(reimport_store.export_backup(slot)["text"] == legacy_text, "legacy 1.0 re-export identical text")
	_check(_file_bytes(reimport_root, slot, _files(reimport_root, slot)[0]) == legacy_text.to_utf8_buffer(), "re-imported legacy bytes identical")

	# Next save over the legacy record succeeds, commits canonical integer token 1, keeps legacy bytes.
	_check(legacy_store.save_profile(slot, loaded["profile"]) == OK, "save over legacy 1.0 record")
	var names: Array[String] = _files(legacy_root, slot)
	_check(names.size() == 2 and names[0] == legacy_name, "legacy revision kept beside new revision")
	_check(_file_bytes(legacy_root, slot, legacy_name) == legacy_text.to_utf8_buffer(), "legacy bytes unchanged after next save")
	var newest_text: String = _file_bytes(legacy_root, slot, names[1]).get_string_from_utf8()
	_check(StrictProfileJson.inspect(newest_text)["schema_version_token"] == "1", "next save after legacy record is canonical token 1")
	var latest: Dictionary = legacy_store.load_profile(slot)
	_check(latest["error"] == OK and not latest["recovered"] and latest["profile"]["character"]["level"] == 9, "canonical save loads after legacy record")
	_check(legacy_store.export_backup(slot)["text"] == newest_text, "export returns canonical newest text")

func _test_size_limits() -> void:
	var slot: String = SLOTS[0]
	var limit: int = StoreScript.MAX_JSON_BYTES

	# Existing oversized committed record: save refuses and preserves its bytes.
	var big_root: String = _root("o")
	var big_store: StoreScript = _store(big_root)
	_write_fixture(big_root, slot, "profile.0000000000000001.1.1.json", "x".repeat(limit + 1))
	var big_before: Dictionary = _snapshot(big_root, slot)
	_check(big_store.save_profile(slot, _profile(big_store, slot, 1)) != OK, "save refuses over oversized record")
	_check(_same_snapshot(big_before, _snapshot(big_root, slot)) and _files(big_root, slot).size() == 1, "oversized record bytes preserved on save")

	# Raw valid text padded to exactly MAX_JSON_BYTES imports and exports unchanged.
	var pad_root: String = _root("p")
	var pad_store: StoreScript = _store(pad_root)
	var pad_len: int = limit - _text("1", slot, '"pad":""').to_utf8_buffer().size()
	var padded: String = _text("1", slot, '"pad":"%s"' % "x".repeat(pad_len))
	_check(padded.to_utf8_buffer().size() == limit, "padded text is exactly MAX_JSON_BYTES")
	_check(pad_store.import_backup(slot, padded) == OK, "import accepts exactly MAX_JSON_BYTES")
	var padded_export: Dictionary = pad_store.export_backup(slot)
	_check(padded_export["error"] == OK and padded_export["text"] == padded, "export returns exact padded raw text")

func _test_future_revision() -> void:
	var root: String = _root("f")
	var slot: String = SLOTS[0]
	var store: StoreScript = _store(root)
	_check(store.save_profile(slot, _profile(store, slot, 1)) == OK, "future setup save")
	_write_fixture(root, slot, "profile.0000000000000002.1.1.json", _text("2", slot, '"level":9'))
	var before: Dictionary = _snapshot(root, slot)
	var rec: Dictionary = store.load_profile(slot)
	_check(rec["error"] == ERR_FILE_UNRECOGNIZED and rec["profile"].is_empty(), "future revision is not silently downgraded")
	_check(store.save_profile(slot, _profile(store, slot, 5)) == ERR_FILE_UNRECOGNIZED, "save refuses over future revision")
	_check(store.import_backup(slot, _text("1", slot, '"level":7')) != OK, "import refuses over future revision")
	_check(_same_snapshot(before, _snapshot(root, slot)), "future revision files unchanged")

	var limit_root: String = _root("g")
	var limit_store: StoreScript = _store(limit_root)
	_write_fixture(limit_root, slot, "profile.9999999999999999.1.1.json", _text("1", slot, '"level":9'))
	var limit_before: Dictionary = _snapshot(limit_root, slot)
	_check(limit_store.save_profile(slot, _profile(limit_store, slot, 1)) == ERR_PARAMETER_RANGE_ERROR, "revision counter overflow refused")
	_check(_same_snapshot(limit_before, _snapshot(limit_root, slot)), "overflow refusal leaves files unchanged")

## Codex finding 1: a committed schema 2 record is unsupported even when a nested section holds
## 9007199254740992 (2^53). It must not be treated as corrupt and fall back to the older valid revision.
func _test_unsafe_int_in_unsupported_schema() -> void:
	var root: String = _root("u")
	var slot: String = SLOTS[0]
	var store: StoreScript = _store(root)
	_check(store.save_profile(slot, _profile(store, slot, 1)) == OK, "unsupported-schema setup save (older valid revision)")
	_check(_files(root, slot).size() == 1, "older valid revision exists before fixture")
	_write_fixture(root, slot, "profile.0000000000000002.1.1.json", _text("2", slot, '"nested":{"deep":[0,{"big":9007199254740992}]}'))
	var before: Dictionary = _snapshot(root, slot)
	_check(before.size() == 2, "schema 2 fixture committed beside older revision")

	var rec: Dictionary = store.load_profile(slot)
	_check(rec["error"] == ERR_FILE_UNRECOGNIZED and rec["profile"].is_empty() and not rec["recovered"], "load blocks on schema 2 with nested 2^53, no fallback to older revision")
	var exported: Dictionary = store.export_backup(slot)
	_check(exported["error"] == ERR_FILE_UNRECOGNIZED and exported["text"] == "", "export blocks on schema 2 with nested 2^53")
	_check(store.save_profile(slot, _profile(store, slot, 5)) == ERR_FILE_UNRECOGNIZED, "save refuses over schema 2 with nested 2^53")
	_check(store.import_backup(slot, _text("1", slot, '"level":7')) == ERR_FILE_UNRECOGNIZED, "valid import refuses over schema 2 with nested 2^53")
	_check(_same_snapshot(before, _snapshot(root, slot)), "schema 2 nested 2^53 files byte-for-byte unchanged")

## Codex finding 2: a regular file occupying a fixed slot path is an I/O error, not an empty slot.
func _test_slot_path_is_regular_file() -> void:
	var root: String = _root("x")
	var slot: String = SLOTS[0]
	var slot_path: String = root.path_join(slot)
	var store: StoreScript = _store(root)
	DirAccess.make_dir_recursive_absolute(_global(root))
	_file_fixtures.append(slot_path)
	var planted: PackedByteArray = "not a directory".to_utf8_buffer()
	var f: FileAccess = FileAccess.open(slot_path, FileAccess.WRITE)
	if not _check(f != null, "cannot plant regular file at slot path"):
		return
	f.store_buffer(planted)
	f.close()
	_check(FileAccess.file_exists(slot_path) and not DirAccess.dir_exists_absolute(_global(slot_path)), "slot path is a regular file")

	var rec: Dictionary = store.load_profile(slot)
	_check(rec["error"] != OK and rec["error"] != ERR_FILE_NOT_FOUND and rec["profile"].is_empty(), "load errors other than not-found when slot path is a file")
	var exported: Dictionary = store.export_backup(slot)
	_check(exported["error"] != OK and exported["error"] != ERR_FILE_NOT_FOUND and exported["text"] == "", "export errors other than not-found when slot path is a file")
	_check(store.save_profile(slot, _profile(store, slot, 1)) != OK, "save cannot overwrite file at slot path")
	_check(store.import_backup(slot, _text("1", slot, '"level":7')) != OK, "import cannot overwrite file at slot path")
	_check(FileAccess.file_exists(slot_path) and not DirAccess.dir_exists_absolute(_global(slot_path)), "slot path still a regular file")
	_check(FileAccess.get_file_as_bytes(slot_path) == planted, "file at slot path bytes preserved")
	_check(DirAccess.get_files_at(root) == PackedStringArray([slot]) and DirAccess.get_directories_at(root).is_empty(), "nothing else created beside planted file")
