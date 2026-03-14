extends RefCounted

const CityRoadGraph := preload("res://city_game/world/model/CityRoadGraph.gd")

const CACHE_SCHEMA_VERSION := 12
const CACHE_DIRECTORY := "user://cache/world"

func build_cache_signature(config) -> String:
	return "v%d_seed%d_w%d_d%d_ds%d" % [
		CACHE_SCHEMA_VERSION,
		int(config.base_seed),
		int(config.world_width_m),
		int(config.world_depth_m),
		int(config.district_size_m),
	]

func build_cache_path(config) -> String:
	return "%s/road_graph_%s.bin" % [CACHE_DIRECTORY, build_cache_signature(config)]

func load_graph(config) -> Dictionary:
	var cache_path := build_cache_path(config)
	var signature := build_cache_signature(config)
	if not FileAccess.file_exists(cache_path):
		return {
			"hit": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": 0,
			"error": "missing",
		}

	var file := FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		return {
			"hit": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": 0,
			"error": "open_failed",
		}

	var payload_variant: Variant = file.get_var(false)
	var size_bytes := int(file.get_length())
	if not (payload_variant is Dictionary):
		return {
			"hit": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": size_bytes,
			"error": "invalid_payload",
		}

	var payload: Dictionary = payload_variant
	if int(payload.get("schema_version", -1)) != CACHE_SCHEMA_VERSION:
		return {
			"hit": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": size_bytes,
			"error": "schema_mismatch",
		}
	if str(payload.get("signature", "")) != signature:
		return {
			"hit": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": size_bytes,
			"error": "signature_mismatch",
		}

	var graph_payload: Dictionary = payload.get("road_graph", {})
	var road_graph := CityRoadGraph.new()
	road_graph.load_from_cache_payload(graph_payload)
	return {
		"hit": true,
		"path": cache_path,
		"signature": signature,
		"size_bytes": size_bytes,
		"road_graph": road_graph,
		"error": "",
	}

func save_graph(config, road_graph: CityRoadGraph) -> Dictionary:
	var cache_path := build_cache_path(config)
	var signature := build_cache_signature(config)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(CACHE_DIRECTORY)
	if make_dir_error != OK:
		return {
			"success": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": 0,
			"error": "mkdir_failed",
		}

	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"path": cache_path,
			"signature": signature,
			"size_bytes": 0,
			"error": "open_failed",
		}

	var payload := {
		"schema_version": CACHE_SCHEMA_VERSION,
		"signature": signature,
		"road_graph": road_graph.to_cache_payload(),
	}
	file.store_var(payload, false)
	return {
		"success": true,
		"path": cache_path,
		"signature": signature,
		"size_bytes": int(file.get_position()),
		"error": "",
	}
