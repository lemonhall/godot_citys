extends RefCounted

const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityTerrainGridTemplate := preload("res://city_game/world/rendering/CityTerrainGridTemplate.gd")
const CityTerrainPageLayout := preload("res://city_game/world/rendering/CityTerrainPageLayout.gd")

var _config
var _world_data: Dictionary = {}
var _layout := CityTerrainPageLayout.new()
var _template_catalog := CityTerrainGridTemplate.new()
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

func build_chunk_page_header(chunk_data: Dictionary, grid_steps: int) -> Dictionary:
	var chunk_key: Vector2i = chunk_data.get("chunk_key", Vector2i.ZERO)
	var chunk_size_m := float(chunk_data.get("chunk_size_m", 256.0))
	var page_contract: Dictionary = _layout.build_chunk_contract(chunk_key, chunk_size_m)
	return {
		"page_contract": page_contract,
		"page_key": page_contract.get("page_key", Vector2i.ZERO),
		"chunk_key": chunk_key,
		"chunk_size_m": chunk_size_m,
		"grid_steps": grid_steps,
		"runtime_key": _build_runtime_key(page_contract, chunk_size_m, grid_steps, int(chunk_data.get("world_seed", chunk_data.get("chunk_seed", 0)))),
	}

func resolve_chunk_sample_binding(chunk_data: Dictionary, grid_steps: int) -> Dictionary:
	var page_header := build_chunk_page_header(chunk_data, grid_steps)
	var runtime_key := str(page_header.get("runtime_key", ""))
	if has_runtime_bundle(runtime_key):
		return build_chunk_binding(page_header, get_runtime_bundle(runtime_key), true)
	var runtime_bundle := _build_page_bundle(page_header, int(chunk_data.get("world_seed", chunk_data.get("chunk_seed", 0))))
	_runtime_pages[runtime_key] = runtime_bundle
	return build_chunk_binding(page_header, runtime_bundle, false)

func build_chunk_binding(page_header: Dictionary, runtime_bundle: Dictionary, runtime_hit: bool) -> Dictionary:
	var page_contract: Dictionary = page_header.get("page_contract", {})
	var chunk_samples := _extract_chunk_samples(
		runtime_bundle.get("page_heights", PackedFloat32Array()),
		runtime_bundle.get("page_normals", PackedVector3Array()),
		int(runtime_bundle.get("page_grid_steps", 0)),
		page_contract.get("chunk_slot", Vector2i.ZERO),
		int(page_header.get("grid_steps", 0))
	)
	return {
		"runtime_key": str(page_header.get("runtime_key", "")),
		"page_contract": page_contract.duplicate(true),
		"page_key": page_header.get("page_key", Vector2i.ZERO),
		"grid_steps": int(page_header.get("grid_steps", 0)),
		"heights": chunk_samples.get("heights", PackedFloat32Array()),
		"normals": chunk_samples.get("normals", PackedVector3Array()),
		"runtime_hit": runtime_hit,
		"build_usec": 0 if runtime_hit else int(runtime_bundle.get("build_usec", 0)),
	}

func _build_page_bundle(page_header: Dictionary, world_seed: int) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var page_contract: Dictionary = page_header.get("page_contract", {})
	var chunk_size_m := float(page_header.get("chunk_size_m", 256.0))
	var chunk_grid_steps := int(page_header.get("grid_steps", 12))
	var chunks_per_page := int(page_contract.get("chunks_per_page", CityTerrainPageLayout.CHUNKS_PER_PAGE))
	var page_grid_steps := chunk_grid_steps * chunks_per_page
	var page_heights := PackedFloat32Array()
	page_heights.resize((page_grid_steps + 1) * (page_grid_steps + 1))
	var page_normals := PackedVector3Array()
	page_normals.resize(page_heights.size())

	var origin_chunk_key: Vector2i = page_contract.get("page_origin_chunk_key", Vector2i.ZERO)
	for local_y in range(chunks_per_page):
		for local_x in range(chunks_per_page):
			var chunk_key := origin_chunk_key + Vector2i(local_x, local_y)
			var chunk_center := _chunk_center_from_key(chunk_key, chunk_size_m)
			var road_layout: Dictionary = CityRoadLayoutBuilder.build_chunk_roads({
				"chunk_key": chunk_key,
				"chunk_center": chunk_center,
				"chunk_size_m": chunk_size_m,
				"world_seed": world_seed,
				"road_graph": _world_data.get("road_graph"),
			})
			var chunk_samples := _build_chunk_samples(chunk_center, chunk_size_m, world_seed, chunk_grid_steps, road_layout.get("segments", []))
			_merge_chunk_samples_into_page(
				page_heights,
				page_normals,
				chunk_samples.get("heights", PackedFloat32Array()),
				chunk_samples.get("normals", PackedVector3Array()),
				page_grid_steps,
				chunk_grid_steps,
				Vector2i(local_x, local_y)
			)
	return {
		"runtime_key": str(page_header.get("runtime_key", "")),
		"page_key": page_contract.get("page_key", Vector2i.ZERO),
		"page_grid_steps": page_grid_steps,
		"page_heights": page_heights,
		"page_normals": page_normals,
		"build_usec": Time.get_ticks_usec() - started_usec,
	}

func _extract_chunk_samples(page_heights: PackedFloat32Array, page_normals: PackedVector3Array, page_grid_steps: int, chunk_slot: Vector2i, chunk_grid_steps: int) -> Dictionary:
	var page_row_stride := page_grid_steps + 1
	var chunk_row_stride := chunk_grid_steps + 1
	var start_x := chunk_slot.x * chunk_grid_steps
	var start_z := chunk_slot.y * chunk_grid_steps
	var heights := PackedFloat32Array()
	heights.resize(chunk_row_stride * chunk_row_stride)
	var normals := PackedVector3Array()
	normals.resize(chunk_row_stride * chunk_row_stride)
	var write_index := 0
	for x_index in range(chunk_row_stride):
		for z_index in range(chunk_row_stride):
			var page_index := (start_x + x_index) * page_row_stride + (start_z + z_index)
			heights[write_index] = page_heights[page_index]
			normals[write_index] = page_normals[page_index]
			write_index += 1
	return {
		"heights": heights,
		"normals": normals,
	}

func _build_runtime_key(page_contract: Dictionary, chunk_size_m: float, grid_steps: int, world_seed: int) -> String:
	var page_key: Vector2i = page_contract.get("page_key", Vector2i.ZERO)
	var chunks_per_page := int(page_contract.get("chunks_per_page", CityTerrainPageLayout.CHUNKS_PER_PAGE))
	return "terrain_page_v1_seed%d_key%d_%d_cpp%d_chunk%d_grid%d" % [
		world_seed,
		page_key.x,
		page_key.y,
		chunks_per_page,
		int(round(chunk_size_m)),
		grid_steps,
	]

func _build_chunk_samples(chunk_center: Vector3, chunk_size_m: float, world_seed: int, chunk_grid_steps: int, road_segments: Array) -> Dictionary:
	var template: Dictionary = _template_catalog.get_template(chunk_size_m, chunk_grid_steps)
	var local_points: PackedVector2Array = template.get("local_points", PackedVector2Array())
	var heights := PackedFloat32Array()
	heights.resize(local_points.size())
	var chunk_payload := {
		"chunk_center": chunk_center,
		"chunk_size_m": chunk_size_m,
		"world_seed": world_seed,
	}
	var profile := {
		"road_segments": road_segments,
	}
	for point_index in range(local_points.size()):
		heights[point_index] = CityChunkGroundSampler.sample_height(local_points[point_index], chunk_payload, profile)
	return {
		"heights": heights,
		"normals": _build_normals(heights, chunk_grid_steps + 1, chunk_size_m),
	}

func _merge_chunk_samples_into_page(page_heights: PackedFloat32Array, page_normals: PackedVector3Array, chunk_heights: PackedFloat32Array, chunk_normals: PackedVector3Array, page_grid_steps: int, chunk_grid_steps: int, chunk_slot: Vector2i) -> void:
	var page_row_stride := page_grid_steps + 1
	var chunk_row_stride := chunk_grid_steps + 1
	var start_x := chunk_slot.x * chunk_grid_steps
	var start_z := chunk_slot.y * chunk_grid_steps
	for x_index in range(chunk_row_stride):
		for z_index in range(chunk_row_stride):
			var page_index := (start_x + x_index) * page_row_stride + (start_z + z_index)
			var chunk_index := x_index * chunk_row_stride + z_index
			page_heights[page_index] = chunk_heights[chunk_index]
			page_normals[page_index] = chunk_normals[chunk_index]

func _build_normals(heights: PackedFloat32Array, row_stride: int, world_size_m: float) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(heights.size())
	var grid_steps := row_stride - 1
	var cell_size_m := world_size_m / float(maxi(grid_steps, 1))
	for x_index in range(row_stride):
		for z_index in range(row_stride):
			var left_x := maxi(x_index - 1, 0)
			var right_x := mini(x_index + 1, grid_steps)
			var down_z := maxi(z_index - 1, 0)
			var up_z := mini(z_index + 1, grid_steps)
			var center_index := x_index * row_stride + z_index
			var left_height := heights[left_x * row_stride + z_index]
			var right_height := heights[right_x * row_stride + z_index]
			var down_height := heights[x_index * row_stride + down_z]
			var up_height := heights[x_index * row_stride + up_z]
			var span_x := maxf(float(right_x - left_x) * cell_size_m, 0.001)
			var span_z := maxf(float(up_z - down_z) * cell_size_m, 0.001)
			var tangent_x := Vector3(span_x, right_height - left_height, 0.0)
			var tangent_z := Vector3(0.0, up_height - down_height, span_z)
			normals[center_index] = tangent_z.cross(tangent_x).normalized()
	return normals

func _chunk_center_from_key(chunk_key: Vector2i, chunk_size_m: float) -> Vector3:
	var bounds: Rect2 = _config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * chunk_size_m,
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * chunk_size_m
	)
