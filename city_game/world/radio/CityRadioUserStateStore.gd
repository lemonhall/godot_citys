extends RefCounted
class_name CityRadioUserStateStore

const USER_SCHEMA_VERSION := 1
const USER_DIRECTORY := "user://radio"

func build_presets_path() -> String:
	return "%s/presets.json" % USER_DIRECTORY

func build_favorites_path() -> String:
	return "%s/favorites.json" % USER_DIRECTORY

func build_recents_path() -> String:
	return "%s/recents.json" % USER_DIRECTORY

func build_session_state_path() -> String:
	return "%s/session_state.json" % USER_DIRECTORY

func save_presets(slots: Array, saved_at_unix_sec: int = -1) -> Dictionary:
	return _write_json_file(build_presets_path(), {
		"schema_version": USER_SCHEMA_VERSION,
		"saved_at_unix_sec": _resolve_timestamp(saved_at_unix_sec),
		"slots": _duplicate_array(slots),
	})

func load_presets() -> Dictionary:
	var read_result := _read_json_file(build_presets_path())
	if not bool(read_result.get("success", false)):
		return {
			"slots": [],
			"error": str(read_result.get("error", "missing")),
		}
	var payload: Dictionary = read_result.get("payload", {}) as Dictionary
	return {
		"slots": _duplicate_array(payload.get("slots", [])),
		"saved_at_unix_sec": int(payload.get("saved_at_unix_sec", 0)),
		"error": "",
	}

func save_favorites(stations: Array, saved_at_unix_sec: int = -1) -> Dictionary:
	return _write_json_file(build_favorites_path(), {
		"schema_version": USER_SCHEMA_VERSION,
		"saved_at_unix_sec": _resolve_timestamp(saved_at_unix_sec),
		"stations": _duplicate_array(stations),
	})

func load_favorites() -> Dictionary:
	var read_result := _read_json_file(build_favorites_path())
	if not bool(read_result.get("success", false)):
		return {
			"stations": [],
			"error": str(read_result.get("error", "missing")),
		}
	var payload: Dictionary = read_result.get("payload", {}) as Dictionary
	return {
		"stations": _duplicate_array(payload.get("stations", [])),
		"saved_at_unix_sec": int(payload.get("saved_at_unix_sec", 0)),
		"error": "",
	}

func save_recents(stations: Array, saved_at_unix_sec: int = -1) -> Dictionary:
	return _write_json_file(build_recents_path(), {
		"schema_version": USER_SCHEMA_VERSION,
		"saved_at_unix_sec": _resolve_timestamp(saved_at_unix_sec),
		"stations": _duplicate_array(stations),
	})

func load_recents() -> Dictionary:
	var read_result := _read_json_file(build_recents_path())
	if not bool(read_result.get("success", false)):
		return {
			"stations": [],
			"error": str(read_result.get("error", "missing")),
		}
	var payload: Dictionary = read_result.get("payload", {}) as Dictionary
	return {
		"stations": _duplicate_array(payload.get("stations", [])),
		"saved_at_unix_sec": int(payload.get("saved_at_unix_sec", 0)),
		"error": "",
	}

func save_session_state(state: Dictionary, saved_at_unix_sec: int = -1) -> Dictionary:
	return _write_json_file(build_session_state_path(), {
		"schema_version": USER_SCHEMA_VERSION,
		"saved_at_unix_sec": _resolve_timestamp(saved_at_unix_sec),
		"state": state.duplicate(true),
	})

func load_session_state() -> Dictionary:
	var read_result := _read_json_file(build_session_state_path())
	if not bool(read_result.get("success", false)):
		return {
			"error": str(read_result.get("error", "missing")),
		}
	var payload: Dictionary = read_result.get("payload", {}) as Dictionary
	var state: Dictionary = (payload.get("state", {}) as Dictionary).duplicate(true)
	state["saved_at_unix_sec"] = int(payload.get("saved_at_unix_sec", 0))
	state["error"] = ""
	return state

func _write_json_file(path: String, payload: Dictionary) -> Dictionary:
	var make_dir_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if make_dir_error != OK:
		return {
			"success": false,
			"path": path,
			"error": "mkdir_failed",
		}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"path": path,
			"error": "open_failed",
		}
	file.store_string(JSON.stringify(payload, "  ") + "\n")
	return {
		"success": true,
		"path": path,
		"error": "",
	}

func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"success": false,
			"path": path,
			"error": "missing",
		}
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return {
			"success": false,
			"path": path,
			"error": "empty",
		}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {
			"success": false,
			"path": path,
			"error": "invalid_json",
		}
	var payload: Dictionary = parsed
	if int(payload.get("schema_version", -1)) != USER_SCHEMA_VERSION:
		return {
			"success": false,
			"path": path,
			"error": "schema_mismatch",
		}
	return {
		"success": true,
		"path": path,
		"payload": payload.duplicate(true),
		"error": "",
	}

func _resolve_timestamp(unix_sec: int) -> int:
	return unix_sec if unix_sec >= 0 else int(Time.get_unix_time_from_system())

func _duplicate_array(values: Variant) -> Array:
	return (values as Array).duplicate(true) if values is Array else []
