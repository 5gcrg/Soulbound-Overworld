class_name ProfileTestIsolation
extends RefCounted

## Disposable ProfileStore fixture with byte-identity proof for the real profile_01.
const REAL_PROFILE_DIR: String = "user://profiles/profile_01"
const TEST_ROOT_PREFIX: String = "user://test_profile_isolation_"

var test_root: String = ""
var store_root: String = ""
var _before: Dictionary = {}

func _init(suite_name: String) -> void:
	test_root = "%s%s_%d_%d" % [TEST_ROOT_PREFIX, suite_name, OS.get_process_id(), Time.get_ticks_usec()]
	store_root = test_root.path_join("profiles")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_root))
	_before = _snapshot_dir_bytes(REAL_PROFILE_DIR)
	print("Profile isolation: %d real profile_01 file(s) snapshotted; disposable store: %s" % [_before.size(), store_root])

func make_store() -> ProfileStore:
	var store := ProfileStore.new(store_root)
	# GameRoot save boundaries require a valid baseline profile, just as the
	# historical real-profile fixture supplied before this isolation helper.
	var seed_error: Error = store.save_profile("profile_01", store.new_profile("profile_01"))
	if seed_error != OK:
		push_error("Failed to seed disposable profile_01: %s" % error_string(seed_error))
	return store

func real_profile_is_unchanged() -> bool:
	var current: Dictionary = _snapshot_dir_bytes(REAL_PROFILE_DIR)
	var identical: bool = current.size() == _before.size()
	if identical:
		for file_name: Variant in _before.keys():
			if not current.has(file_name) or current[file_name] != _before[file_name]:
				identical = false
				break
	if not identical:
		for file_name: Variant in current.keys():
			if not _before.has(file_name):
				printerr("PROFILE ISOLATION ADDED: %s/%s" % [REAL_PROFILE_DIR, file_name])
			elif current[file_name] != _before[file_name]:
				printerr("PROFILE ISOLATION MODIFIED: %s/%s" % [REAL_PROFILE_DIR, file_name])
		for file_name: Variant in _before.keys():
			if not current.has(file_name):
				printerr("PROFILE ISOLATION REMOVED: %s/%s" % [REAL_PROFILE_DIR, file_name])
	return identical

func cleanup() -> void:
	if not test_root.begins_with(TEST_ROOT_PREFIX):
		push_error("Refusing to clean an unexpected test root: %s" % test_root)
		return
	var global_path: String = ProjectSettings.globalize_path(test_root)
	if DirAccess.dir_exists_absolute(global_path):
		_remove_dir_recursive(global_path)

func _snapshot_dir_bytes(dir_path: String) -> Dictionary:
	var snapshot: Dictionary = {}
	_collect_dir_bytes(dir_path, "", snapshot)
	return snapshot

func _collect_dir_bytes(dir_path: String, prefix: String, out: Dictionary) -> void:
	var dir := DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			if dir.current_is_dir():
				_collect_dir_bytes(dir_path.path_join(entry), prefix + entry + "/", out)
			else:
				out[prefix + entry] = FileAccess.get_file_as_bytes(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()

func _remove_dir_recursive(global_path: String) -> void:
	var dir := DirAccess.open(global_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child: String = global_path.rstrip("/") + "/" + entry
			if dir.current_is_dir():
				_remove_dir_recursive(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(global_path)
