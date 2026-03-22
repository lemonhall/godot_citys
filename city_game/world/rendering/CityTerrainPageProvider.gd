extends RefCounted

const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityTerrainGridTemplate := preload("res://city_game/world/rendering/CityTerrainGridTemplate.gd")
const CityTerrainPageLayout := preload("res://city_game/world/rendering/CityTerrainPageLayout.gd")
const CityLakeRegionDefinition := preload("res://city_game/world/features/lake/CityLakeRegionDefinition.gd")

var _config
var _world_data: Dictionary = {}
var _layout := CityTerrainPageLayout.new()
var _template_catalog := CityTerrainGridTemplate.new()
var _runtime_pages: Dictionary = {}
var _terrain_region_entries: Dictionary = {}

func setup(config, world_data: Dictionary) -> void:
	_config = config
	_world_data = world_data
	_runtime_pages.clear()
	_terrain_region_entries.clear()

func clear() -> void:
	_runtime_pages.clear()

func set_terrain_region_entries(entries: Dictionary) -> void:
	_terrain_region_entries = entries.duplicate(true)
	_runtime_pages.clear()

func get_terrain_region_entries_snapshot() -> Dictionary:
	return _terrain_region_entries.duplicate(true)

func get_runtime_page_count() -> int:
	return _runtime_pages.size()

func has_runtime_bundle(runtime_key: String) -> bool:
	return _runtime_pages.has(runtime_key)

func get_runtime_bundle(runtime_key: String) -> Dictionary:
	if not _runtime_pages.has(runtime_key):
		return {}
	return _runtime_pages[runtime_key]

func store_runtime_bundle(runtime_key: String, runtime_bundle: Dictionary) -> Dictionary:
	if _runtime_pages.has(runtime_key):
		return _runtime_pages[runtime_key]
	_runtime_pages[runtime_key] = runtime_bundle.duplicate(true)
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
	var page_request := build_page_request(chunk_data, grid_steps)
	var page_header: Dictionary = page_request.get("page_header", {})
	var runtime_key := str(page_header.get("runtime_key", ""))
	if has_runtime_bundle(runtime_key):
		return build_chunk_binding(page_header, get_runtime_bundle(runtime_key), true)
	var runtime_bundle := prepare_page_bundle(page_request)
	store_runtime_bundle(runtime_key, runtime_bundle)
	return build_chunk_binding(page_header, runtime_bundle, false)

func build_chunk_binding(page_header: Dictionary, runtime_bundle: Dictionary, runtime_hit: bool) -> Dictionary:
	return build_chunk_binding_from_bundle(page_header, runtime_bundle, runtime_hit)

static func build_chunk_binding_from_bundle(page_header: Dictionary, runtime_bundle: Dictionary, runtime_hit: bool) -> Dictionary:
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

func build_page_request(chunk_data: Dictionary, grid_steps: int, page_header: Dictionary = {}) -> Dictionary:
	var header := page_header if not page_header.is_empty() else build_chunk_page_header(chunk_data, grid_steps)
	var world_seed := int(chunk_data.get("world_seed", chunk_data.get("chunk_seed", 0)))
	var world_bounds := Rect2()
	if _config != null:
		world_bounds = _config.get_world_bounds()
	return {
		"page_header": header.duplicate(true),
		"page_contract": (header.get("page_contract", {}) as Dictionary).duplicate(true),
		"chunk_size_m": float(header.get("chunk_size_m", 256.0)),
		"grid_steps": int(header.get("grid_steps", grid_steps)),
		"world_seed": world_seed,
		"world_bounds": world_bounds,
		"road_graph": _world_data.get("road_graph"),
		"terrain_region_entries": get_terrain_region_entries_snapshot(),
	}

static func prepare_page_bundle(page_request: Dictionary) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var page_header: Dictionary = page_request.get("page_header", {})
	var page_contract: Dictionary = page_request.get("page_contract", {})
	var chunk_size_m := float(page_request.get("chunk_size_m", page_header.get("chunk_size_m", 256.0)))
	var chunk_grid_steps := int(page_request.get("grid_steps", page_header.get("grid_steps", 12)))
	var world_seed := int(page_request.get("world_seed", 0))
	var world_bounds: Rect2 = page_request.get("world_bounds", Rect2())
	var road_graph = page_request.get("road_graph")
	var terrain_region_entries: Dictionary = (page_request.get("terrain_region_entries", {}) as Dictionary).duplicate(true)
	var chunks_per_page := int(page_contract.get("chunks_per_page", CityTerrainPageLayout.CHUNKS_PER_PAGE))
	var page_grid_steps := chunk_grid_steps * chunks_per_page
	var page_heights := PackedFloat32Array()
	page_heights.resize((page_grid_steps + 1) * (page_grid_steps + 1))
	var page_normals := PackedVector3Array()
	page_normals.resize(page_heights.size())
	var template_catalog := CityTerrainGridTemplate.new()

	var origin_chunk_key: Vector2i = page_contract.get("page_origin_chunk_key", Vector2i.ZERO)
	for local_y in range(chunks_per_page):
		for local_x in range(chunks_per_page):
			var chunk_key := origin_chunk_key + Vector2i(local_x, local_y)
			var chunk_center := _chunk_center_from_key_static(chunk_key, chunk_size_m, world_bounds)
			var road_layout: Dictionary = CityRoadLayoutBuilder.build_chunk_roads({
				"chunk_key": chunk_key,
				"chunk_center": chunk_center,
				"chunk_size_m": chunk_size_m,
				"world_seed": world_seed,
				"road_graph": road_graph,
			})
			var chunk_samples := _build_chunk_samples_static(
				template_catalog,
				chunk_center,
				chunk_size_m,
				world_seed,
				chunk_grid_steps,
				road_layout.get("segments", []),
				terrain_region_entries
			)
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

static func _extract_chunk_samples(page_heights: PackedFloat32Array, page_normals: PackedVector3Array, page_grid_steps: int, chunk_slot: Vector2i, chunk_grid_steps: int) -> Dictionary:
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
	return _build_chunk_samples_static(_template_catalog, chunk_center, chunk_size_m, world_seed, chunk_grid_steps, road_segments, _terrain_region_entries)

static func _build_chunk_samples_static(template_catalog: CityTerrainGridTemplate, chunk_center: Vector3, chunk_size_m: float, world_seed: int, chunk_grid_steps: int, road_segments: Array, terrain_region_entries: Dictionary = {}) -> Dictionary:
	var template: Dictionary = template_catalog.get_template(chunk_size_m, chunk_grid_steps)
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
	if not terrain_region_entries.is_empty():
		_apply_terrain_region_carves(local_points, heights, chunk_center, terrain_region_entries)
	return {
		"heights": heights,
		"normals": _build_normals(heights, chunk_grid_steps + 1, chunk_size_m),
	}

static func _apply_terrain_region_carves(local_points: PackedVector2Array, heights: PackedFloat32Array, chunk_center: Vector3, terrain_region_entries: Dictionary) -> void:
	if local_points.is_empty() or heights.is_empty() or terrain_region_entries.is_empty():
		return
	for point_index in range(local_points.size()):
		var local_point := local_points[point_index]
		var carved_height := heights[point_index]
		var sample_world_position := Vector3(
			chunk_center.x + local_point.x,
			0.0,
			chunk_center.z + local_point.y
		)
		for entry_variant in terrain_region_entries.values():
			if not (entry_variant is Dictionary):
				continue
			var entry: Dictionary = entry_variant
			var lake_contract_variant = entry.get("lake_runtime_contract", {})
			if not (lake_contract_variant is Dictionary):
				continue
			var lake_contract: Dictionary = lake_contract_variant as Dictionary
			var sample: Dictionary = CityLakeRegionDefinition.sample_depth_from_contract(lake_contract, sample_world_position)
			if not bool(sample.get("inside_region", false)):
				continue
			carved_height = minf(carved_height, float(sample.get("floor_y_m", carved_height)))
		heights[point_index] = carved_height

static func _merge_chunk_samples_into_page(page_heights: PackedFloat32Array, page_normals: PackedVector3Array, chunk_heights: PackedFloat32Array, chunk_normals: PackedVector3Array, page_grid_steps: int, chunk_grid_steps: int, chunk_slot: Vector2i) -> void:
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

static func _build_normals(heights: PackedFloat32Array, row_stride: int, world_size_m: float) -> PackedVector3Array:
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
	return _chunk_center_from_key_static(chunk_key, chunk_size_m, bounds)

static func _chunk_center_from_key_static(chunk_key: Vector2i, chunk_size_m: float, bounds: Rect2) -> Vector3:
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * chunk_size_m,
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * chunk_size_m
	)
