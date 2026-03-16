extends RefCounted

const REGISTRY_SCHEMA_VERSION := "v21-scene-landmark-registry-1"

var _primary_registry_path := ""
var _load_registry_paths: Array[String] = []
var _entries: Dictionary = {}

func configure(primary_registry_path: String, load_registry_paths: Array = []) -> void:
	_primary_registry_path = _normalize_resource_path(primary_registry_path)
	_load_registry_paths.clear()
	if load_registry_paths.is_empty():
		if _primary_registry_path != "":
			_load_registry_paths.append(_primary_registry_path)
		return
	for path_variant in load_registry_paths:
		var path := _normalize_resource_path(str(path_variant))
		if path == "" or _load_registry_paths.has(path):
			continue
		_load_registry_paths.append(path)

func set_primary_registry_path(path: String) -> void:
	_primary_registry_path = _normalize_resource_path(path)
	if _primary_registry_path != "" and not _load_registry_paths.has(_primary_registry_path):
		_load_registry_paths.append(_primary_registry_path)

func load_registry() -> Dictionary:
	_entries.clear()
	for path in _load_registry_paths:
		_merge_registry_path(path)
	return get_entries_snapshot()

func get_entry(landmark_id: String) -> Dictionary:
	if landmark_id == "":
		return {}
	return (_entries.get(landmark_id, {}) as Dictionary).duplicate(true)

func get_entries_snapshot() -> Dictionary:
	return _entries.duplicate(true)

func get_primary_registry_path() -> String:
	return _primary_registry_path

func save_entry(entry: Dictionary) -> Dictionary:
	var landmark_id := str(entry.get("landmark_id", ""))
	if landmark_id == "":
		return {
			"success": false,
			"error": "missing_landmark_id",
		}
	_entries[landmark_id] = entry.duplicate(true)
	return save_registry()

func save_registry() -> Dictionary:
	if _primary_registry_path == "":
		return {
			"success": false,
			"error": "missing_primary_registry_path",
		}
	var global_path := _globalize_path(_primary_registry_path)
	var parent_dir := global_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return {
			"success": false,
			"error": "dir_create_failed:%s" % _primary_registry_path,
		}
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"error": "file_open_failed:%s" % _primary_registry_path,
		}
	file.store_string(JSON.stringify({
		"schema_version": REGISTRY_SCHEMA_VERSION,
		"entries": _entries.duplicate(true),
	}, "\t"))
	file.close()
	return {
		"success": true,
		"registry_path": _primary_registry_path,
	}

func _merge_registry_path(resource_path: String) -> void:
	if resource_path == "":
		return
	var global_path := _globalize_path(resource_path)
	if not FileAccess.file_exists(global_path):
		return
	var registry_text := FileAccess.get_file_as_string(global_path)
	if registry_text == "":
		return
	var registry_variant = JSON.parse_string(registry_text)
	if not (registry_variant is Dictionary):
		return
	var payload: Dictionary = registry_variant
	var entries_variant = payload.get("entries", {})
	if not (entries_variant is Dictionary):
		return
	var entries: Dictionary = entries_variant
	for key_variant in entries.keys():
		var key := str(key_variant)
		var entry: Dictionary = entries.get(key, {})
		if entry.is_empty():
			continue
		if _entries.has(key):
			continue
		_entries[key] = entry.duplicate(true)

static func _normalize_resource_path(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").strip_edges()

static func _globalize_path(path: String) -> String:
	var normalized := _normalize_resource_path(path)
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized)
	return normalized
