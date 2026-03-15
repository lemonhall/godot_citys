extends RefCounted

const CityPlaceIndex := preload("res://city_game/world/model/CityPlaceIndex.gd")

const CACHE_SCHEMA_VERSION := 2
const CACHE_DIRECTORY := "user://cache/world/place_index"

func build_world_signature(config) -> String:
	return "v%d_seed%d_w%d_d%d_c%d_ds%d" % [
		CACHE_SCHEMA_VERSION,
		int(config.base_seed),
		int(config.world_width_m),
		int(config.world_depth_m),
		int(config.chunk_size_m),
		int(config.district_size_m),
	]

func build_cache_path(_config, world_signature: String) -> String:
	return "%s/place_index_%s.bin" % [CACHE_DIRECTORY, world_signature]

func load_place_index(config) -> Dictionary:
	var world_signature := build_world_signature(config)
	var cache_path := build_cache_path(config, world_signature)
	if not FileAccess.file_exists(cache_path):
		return {
			"hit": false,
			"path": cache_path,
			"world_signature": world_signature,
			"size_bytes": 0,
			"error": "missing",
		}
	var file := FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		return {
			"hit": false,
			"path": cache_path,
			"world_signature": world_signature,
			"size_bytes": 0,
			"error": "open_failed",
		}
	var payload_variant: Variant = file.get_var(false)
	var size_bytes := int(file.get_length())
	if not (payload_variant is Dictionary):
		return {
			"hit": false,
			"path": cache_path,
			"world_signature": world_signature,
			"size_bytes": size_bytes,
			"error": "invalid_payload",
		}
	var payload: Dictionary = payload_variant
	if int(payload.get("schema_version", -1)) != CACHE_SCHEMA_VERSION:
		return {
			"hit": false,
			"path": cache_path,
			"world_signature": world_signature,
			"size_bytes": size_bytes,
			"error": "schema_mismatch",
		}
	if str(payload.get("world_signature", "")) != world_signature:
		return {
			"hit": false,
			"path": cache_path,
			"world_signature": world_signature,
			"size_bytes": size_bytes,
			"error": "signature_mismatch",
		}
	var place_index := CityPlaceIndex.new()
	place_index.load_from_cache_payload(payload.get("place_index", {}))
	place_index.set_cache_contract({
		"path": cache_path,
		"world_signature": world_signature,
	})
	return {
		"hit": true,
		"path": cache_path,
		"world_signature": world_signature,
		"size_bytes": size_bytes,
		"place_index": place_index,
		"error": "",
	}

func save_place_index(config, place_index: CityPlaceIndex) -> Dictionary:
	var world_signature := build_world_signature(config)
	var cache_path := build_cache_path(config, world_signature)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(CACHE_DIRECTORY)
	if make_dir_error != OK:
		return {
			"success": false,
			"path": cache_path,
			"world_signature": world_signature,
			"size_bytes": 0,
			"error": "mkdir_failed",
		}
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"path": cache_path,
			"world_signature": world_signature,
			"size_bytes": 0,
			"error": "open_failed",
		}
	place_index.set_cache_contract({
		"path": cache_path,
		"world_signature": world_signature,
	})
	file.store_var({
		"schema_version": CACHE_SCHEMA_VERSION,
		"world_signature": world_signature,
		"place_index": place_index.to_cache_payload(),
	}, false)
	return {
		"success": true,
		"path": cache_path,
		"world_signature": world_signature,
		"size_bytes": int(file.get_position()),
		"error": "",
	}
