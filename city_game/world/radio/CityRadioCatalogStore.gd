extends RefCounted
class_name CityRadioCatalogStore

const CACHE_SCHEMA_VERSION := 1
const CACHE_DIRECTORY := "user://cache/radio"
const COUNTRIES_DIRECTORY := "user://cache/radio/countries"
const DEFAULT_CATALOG_TTL_SEC := 72 * 3600
const DEFAULT_RESOLVE_CACHE_TTL_SEC := 6 * 3600

func build_countries_index_path() -> String:
	return "%s/countries.index.json" % CACHE_DIRECTORY

func build_countries_meta_path() -> String:
	return "%s/countries.meta.json" % CACHE_DIRECTORY

func build_country_station_index_path(country_code: String) -> String:
	return "%s/%s/stations.index.json" % [COUNTRIES_DIRECTORY, _normalize_country_code(country_code)]

func build_country_station_meta_path(country_code: String) -> String:
	return "%s/%s/stations.meta.json" % [COUNTRIES_DIRECTORY, _normalize_country_code(country_code)]

func build_stream_resolve_cache_path() -> String:
	return "%s/stream_resolve_cache.json" % CACHE_DIRECTORY

func save_countries_index(countries: Array, fetched_at_unix_sec: int = -1, ttl_sec: int = DEFAULT_CATALOG_TTL_SEC) -> Dictionary:
	var index_path := build_countries_index_path()
	var meta_path := build_countries_meta_path()
	var resolved_fetched_at := _resolve_timestamp(fetched_at_unix_sec)
	var countries_copy := _duplicate_array(countries)
	var index_payload := {
		"schema_version": CACHE_SCHEMA_VERSION,
		"countries": countries_copy,
	}
	var meta_payload := {
		"schema_version": CACHE_SCHEMA_VERSION,
		"fetched_at_unix_sec": resolved_fetched_at,
		"ttl_sec": max(ttl_sec, 0),
		"country_count": countries_copy.size(),
	}
	var index_result := _write_json_file(index_path, index_payload)
	if not bool(index_result.get("success", false)):
		return index_result
	var meta_result := _write_json_file(meta_path, meta_payload)
	if not bool(meta_result.get("success", false)):
		return meta_result
	return {
		"success": true,
		"index_path": index_path,
		"meta_path": meta_path,
		"error": "",
	}

func load_countries_index(now_unix_sec: int = -1) -> Dictionary:
	var index_result := _read_json_file(build_countries_index_path())
	if not bool(index_result.get("success", false)):
		return _build_miss_result(index_result, "countries")
	var meta_result := _read_json_file(build_countries_meta_path())
	if not bool(meta_result.get("success", false)):
		return _build_miss_result(meta_result, "countries")
	var index_payload: Dictionary = index_result.get("payload", {}) as Dictionary
	var meta_payload: Dictionary = meta_result.get("payload", {}) as Dictionary
	if int(index_payload.get("schema_version", -1)) != CACHE_SCHEMA_VERSION or int(meta_payload.get("schema_version", -1)) != CACHE_SCHEMA_VERSION:
		return {
			"hit": false,
			"stale": false,
			"countries": [],
			"error": "schema_mismatch",
		}
	var stale := _is_stale(meta_payload, now_unix_sec)
	return {
		"hit": true,
		"stale": stale,
		"countries": _duplicate_array(index_payload.get("countries", [])),
		"meta": meta_payload.duplicate(true),
		"error": "",
	}

func delete_countries_index() -> Dictionary:
	var index_result := _delete_file_if_exists(build_countries_index_path())
	if not bool(index_result.get("success", false)):
		return index_result
	var meta_result := _delete_file_if_exists(build_countries_meta_path())
	if not bool(meta_result.get("success", false)):
		return meta_result
	return {
		"success": true,
		"error": "",
	}

func save_country_station_page(country_code: String, stations: Array, fetched_at_unix_sec: int = -1, ttl_sec: int = DEFAULT_CATALOG_TTL_SEC) -> Dictionary:
	var normalized_country_code := _normalize_country_code(country_code)
	var index_path := build_country_station_index_path(normalized_country_code)
	var meta_path := build_country_station_meta_path(normalized_country_code)
	var resolved_fetched_at := _resolve_timestamp(fetched_at_unix_sec)
	var stations_copy := _duplicate_array(stations)
	var index_payload := {
		"schema_version": CACHE_SCHEMA_VERSION,
		"country_code": normalized_country_code,
		"stations": stations_copy,
	}
	var meta_payload := {
		"schema_version": CACHE_SCHEMA_VERSION,
		"country_code": normalized_country_code,
		"fetched_at_unix_sec": resolved_fetched_at,
		"ttl_sec": max(ttl_sec, 0),
		"station_count": stations_copy.size(),
	}
	var index_result := _write_json_file(index_path, index_payload)
	if not bool(index_result.get("success", false)):
		return index_result
	var meta_result := _write_json_file(meta_path, meta_payload)
	if not bool(meta_result.get("success", false)):
		return meta_result
	return {
		"success": true,
		"index_path": index_path,
		"meta_path": meta_path,
		"error": "",
	}

func load_country_station_page(country_code: String, now_unix_sec: int = -1) -> Dictionary:
	var normalized_country_code := _normalize_country_code(country_code)
	var index_result := _read_json_file(build_country_station_index_path(normalized_country_code))
	if not bool(index_result.get("success", false)):
		return {
			"hit": false,
			"stale": false,
			"stations": [],
			"error": str(index_result.get("error", "missing")),
		}
	var meta_result := _read_json_file(build_country_station_meta_path(normalized_country_code))
	if not bool(meta_result.get("success", false)):
		return {
			"hit": false,
			"stale": false,
			"stations": [],
			"error": str(meta_result.get("error", "missing")),
		}
	var index_payload: Dictionary = index_result.get("payload", {}) as Dictionary
	var meta_payload: Dictionary = meta_result.get("payload", {}) as Dictionary
	if int(index_payload.get("schema_version", -1)) != CACHE_SCHEMA_VERSION or int(meta_payload.get("schema_version", -1)) != CACHE_SCHEMA_VERSION:
		return {
			"hit": false,
			"stale": false,
			"stations": [],
			"error": "schema_mismatch",
		}
	return {
		"hit": true,
		"stale": _is_stale(meta_payload, now_unix_sec),
		"stations": _duplicate_array(index_payload.get("stations", [])),
		"meta": meta_payload.duplicate(true),
		"error": "",
	}

func delete_country_station_page(country_code: String) -> Dictionary:
	var normalized_country_code := _normalize_country_code(country_code)
	var index_result := _delete_file_if_exists(build_country_station_index_path(normalized_country_code))
	if not bool(index_result.get("success", false)):
		return index_result
	var meta_result := _delete_file_if_exists(build_country_station_meta_path(normalized_country_code))
	if not bool(meta_result.get("success", false)):
		return meta_result
	return {
		"success": true,
		"error": "",
	}

func save_stream_resolve_cache(entries: Dictionary, fetched_at_unix_sec: int = -1, ttl_sec: int = DEFAULT_RESOLVE_CACHE_TTL_SEC) -> Dictionary:
	var cache_path := build_stream_resolve_cache_path()
	var payload := {
		"schema_version": CACHE_SCHEMA_VERSION,
		"fetched_at_unix_sec": _resolve_timestamp(fetched_at_unix_sec),
		"ttl_sec": max(ttl_sec, 0),
		"entries": entries.duplicate(true),
	}
	return _write_json_file(cache_path, payload)

func load_stream_resolve_cache(now_unix_sec: int = -1) -> Dictionary:
	var read_result := _read_json_file(build_stream_resolve_cache_path())
	if not bool(read_result.get("success", false)):
		return {
			"hit": false,
			"stale": false,
			"entries": {},
			"error": str(read_result.get("error", "missing")),
		}
	var payload: Dictionary = read_result.get("payload", {}) as Dictionary
	if int(payload.get("schema_version", -1)) != CACHE_SCHEMA_VERSION:
		return {
			"hit": false,
			"stale": false,
			"entries": {},
			"error": "schema_mismatch",
		}
	return {
		"hit": true,
		"stale": _is_stale(payload, now_unix_sec),
		"entries": (payload.get("entries", {}) as Dictionary).duplicate(true),
		"error": "",
	}

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
	return {
		"success": true,
		"path": path,
		"payload": (parsed as Dictionary).duplicate(true),
		"error": "",
	}

func _delete_file_if_exists(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"success": true,
			"path": path,
			"error": "",
		}
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if remove_error != OK:
		return {
			"success": false,
			"path": path,
			"error": "remove_failed",
		}
	return {
		"success": true,
		"path": path,
		"error": "",
	}

func _build_miss_result(read_result: Dictionary, key: String) -> Dictionary:
	return {
		"hit": false,
		"stale": false,
		key: [] if key == "countries" else {},
		"error": str(read_result.get("error", "missing")),
	}

func _is_stale(meta_payload: Dictionary, now_unix_sec: int) -> bool:
	var fetched_at_unix_sec := int(meta_payload.get("fetched_at_unix_sec", 0))
	var ttl_sec := int(meta_payload.get("ttl_sec", 0))
	if fetched_at_unix_sec <= 0 or ttl_sec <= 0:
		return true
	var resolved_now := _resolve_timestamp(now_unix_sec)
	return resolved_now > fetched_at_unix_sec + ttl_sec

func _resolve_timestamp(unix_sec: int) -> int:
	return unix_sec if unix_sec >= 0 else int(Time.get_unix_time_from_system())

func _normalize_country_code(country_code: String) -> String:
	var normalized := country_code.strip_edges().to_upper()
	return normalized if normalized != "" else "UNSPECIFIED"

func _duplicate_array(values: Variant) -> Array:
	return (values as Array).duplicate(true) if values is Array else []
