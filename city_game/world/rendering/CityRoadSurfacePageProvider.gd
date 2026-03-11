extends RefCounted

const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")
const CityRoadSurfacePageLayout := preload("res://city_game/world/rendering/CityRoadSurfacePageLayout.gd")
const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const PAGE_MASK_RESOLUTION := 512

var _config
var _world_data: Dictionary = {}
var _layout := CityRoadSurfacePageLayout.new()
var _runtime_pages: Dictionary = {}

func setup(config, world_data: Dictionary) -> void:
	_config = config
	_world_data = world_data
	_runtime_pages.clear()

func clear() -> void:
	_runtime_pages.clear()

func get_runtime_page_count() -> int:
	return _runtime_pages.size()

func has_runtime_bundle(runtime_key: String) -> bool:
	return _runtime_pages.has(runtime_key)

func get_runtime_bundle(runtime_key: String) -> Dictionary:
	if not _runtime_pages.has(runtime_key):
		return {}
	return _runtime_pages[runtime_key]

func build_chunk_page_header(chunk_data: Dictionary, detail_mode: String) -> Dictionary:
	var chunk_key: Vector2i = chunk_data.get("chunk_key", Vector2i.ZERO)
	var chunk_size_m := float(chunk_data.get("chunk_size_m", 256.0))
	var page_contract: Dictionary = _layout.build_chunk_contract(chunk_key, chunk_size_m)
	return {
		"page_contract": page_contract,
		"page_key": page_contract.get("page_key", Vector2i.ZERO),
		"uv_rect": page_contract.get("uv_rect", Rect2(Vector2.ZERO, Vector2.ONE)),
		"chunk_key": chunk_key,
		"chunk_size_m": chunk_size_m,
		"detail_mode": detail_mode,
		"runtime_key": _build_runtime_key(page_contract, detail_mode, chunk_size_m),
	}

func build_page_request(chunk_data: Dictionary, detail_mode: String, page_header: Dictionary = {}) -> Dictionary:
	var header := page_header if not page_header.is_empty() else build_chunk_page_header(chunk_data, detail_mode)
	var request := header.duplicate(true)
	request["surface_request"] = _build_page_surface_request(
		header.get("page_contract", {}),
		float(header.get("chunk_size_m", 256.0)),
		str(header.get("detail_mode", detail_mode)),
		int(chunk_data.get("world_seed", chunk_data.get("chunk_seed", 0)))
	)
	return request

func store_runtime_bundle(runtime_key: String, surface_data: Dictionary) -> Dictionary:
	if _runtime_pages.has(runtime_key):
		return _runtime_pages[runtime_key]
	var committed: Dictionary = CityRoadMaskBuilder.commit_surface_textures(surface_data)
	var bundle := {
		"runtime_key": runtime_key,
		"page_key": surface_data.get("page_key", Vector2i.ZERO),
		"road_mask_texture": committed.get("road_mask_texture"),
		"stripe_mask_texture": committed.get("stripe_mask_texture"),
		"mask_profile_stats": (committed.get("mask_profile_stats", {}) as Dictionary).duplicate(true),
		"commit_usec": int((committed.get("mask_profile_stats", {}) as Dictionary).get("commit_total_usec", 0)),
	}
	_runtime_pages[runtime_key] = bundle
	return bundle

func build_chunk_binding(page_header: Dictionary, runtime_bundle: Dictionary, runtime_hit: bool) -> Dictionary:
	var stats: Dictionary = (runtime_bundle.get("mask_profile_stats", {}) as Dictionary).duplicate(true)
	stats["runtime_hit"] = runtime_hit
	return {
		"runtime_key": str(page_header.get("runtime_key", "")),
		"page_contract": (page_header.get("page_contract", {}) as Dictionary).duplicate(true),
		"page_key": page_header.get("page_key", Vector2i.ZERO),
		"uv_rect": page_header.get("uv_rect", Rect2(Vector2.ZERO, Vector2.ONE)),
		"detail_mode": str(page_header.get("detail_mode", CityRoadMaskBuilder.DETAIL_MODE_FULL)),
		"road_mask_texture": runtime_bundle.get("road_mask_texture"),
		"stripe_mask_texture": runtime_bundle.get("stripe_mask_texture"),
		"mask_profile_stats": stats,
		"commit_usec": 0 if runtime_hit else int(runtime_bundle.get("commit_usec", 0)),
		"runtime_hit": runtime_hit,
	}

func resolve_chunk_surface_binding(chunk_data: Dictionary, detail_mode: String) -> Dictionary:
	var page_header := build_chunk_page_header(chunk_data, detail_mode)
	var runtime_key := str(page_header.get("runtime_key", ""))
	if has_runtime_bundle(runtime_key):
		return build_chunk_binding(page_header, get_runtime_bundle(runtime_key), true)
	var page_request := build_page_request(chunk_data, detail_mode, page_header)
	var surface_data := CityRoadMaskBuilder.prepare_surface_data(page_request.get("surface_request", {}))
	var runtime_bundle := store_runtime_bundle(runtime_key, surface_data)
	return build_chunk_binding(page_header, runtime_bundle, false)

func _build_runtime_key(page_contract: Dictionary, detail_mode: String, chunk_size_m: float) -> String:
	var page_key: Vector2i = page_contract.get("page_key", Vector2i.ZERO)
	var chunks_per_page := int(page_contract.get("chunks_per_page", CityRoadSurfacePageLayout.CHUNKS_PER_PAGE))
	return "page_%d_%d_cpp%d_chunk%d_mode%s" % [
		page_key.x,
		page_key.y,
		chunks_per_page,
		int(round(chunk_size_m)),
		detail_mode,
	]

func _build_page_surface_request(page_contract: Dictionary, chunk_size_m: float, detail_mode: String, world_seed: int) -> Dictionary:
	var chunks_per_page := int(page_contract.get("chunks_per_page", CityRoadSurfacePageLayout.CHUNKS_PER_PAGE))
	var page_origin_chunk_key: Vector2i = page_contract.get("page_origin_chunk_key", Vector2i.ZERO)
	var mask_resolution := PAGE_MASK_RESOLUTION
	var surface_segments: Array = []
	var chunk_signatures := PackedStringArray()

	for local_y in range(chunks_per_page):
		for local_x in range(chunks_per_page):
			var page_chunk_key := page_origin_chunk_key + Vector2i(local_x, local_y)
			var road_layout: Dictionary = CityRoadLayoutBuilder.build_chunk_roads({
				"chunk_key": page_chunk_key,
				"chunk_center": _chunk_center_from_key(page_chunk_key, chunk_size_m),
				"chunk_size_m": chunk_size_m,
				"world_seed": world_seed,
				"road_graph": _world_data.get("road_graph"),
			})
			chunk_signatures.append("%d,%d=%s" % [page_chunk_key.x, page_chunk_key.y, str(road_layout.get("signature", ""))])
			var chunk_offset := Vector3(float(local_x) * chunk_size_m, 0.0, float(local_y) * chunk_size_m)
			for road_segment in road_layout.get("segments", []):
				var segment_dict: Dictionary = (road_segment as Dictionary).duplicate(true)
				var shifted_points: Array = []
				for point in segment_dict.get("points", []):
					var local_point: Vector3 = point
					shifted_points.append(Vector3(
						local_point.x + chunk_offset.x,
						local_point.y,
						local_point.z + chunk_offset.z
					))
				segment_dict["points"] = shifted_points
				surface_segments.append(segment_dict)

	return {
		"surface_scope": "page",
		"cache_signature": _build_page_cache_signature(page_contract, chunk_size_m, detail_mode, mask_resolution, chunk_signatures),
		"surface_segments": surface_segments,
		"surface_world_size_m": float(page_contract.get("page_world_size_m", chunk_size_m)),
		"mask_resolution": mask_resolution,
		"detail_mode": detail_mode,
		"uv_rect": Rect2(Vector2.ZERO, Vector2.ONE),
		"page_key": page_contract.get("page_key", Vector2i.ZERO),
	}

func _build_page_cache_signature(page_contract: Dictionary, chunk_size_m: float, detail_mode: String, mask_resolution: int, chunk_signatures: PackedStringArray) -> String:
	var page_key: Vector2i = page_contract.get("page_key", Vector2i.ZERO)
	var chunks_per_page := int(page_contract.get("chunks_per_page", CityRoadSurfacePageLayout.CHUNKS_PER_PAGE))
	return "page_v1_res%d_chunk%d_cpp%d_mode%s_key%d_%d_%s" % [
		mask_resolution,
		int(round(chunk_size_m)),
		chunks_per_page,
		detail_mode,
		page_key.x,
		page_key.y,
		"|".join(chunk_signatures),
	]

func _chunk_center_from_key(chunk_key: Vector2i, chunk_size_m: float) -> Vector3:
	if _config == null:
		return Vector3.ZERO
	var bounds: Rect2 = _config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * chunk_size_m,
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * chunk_size_m
	)
