extends RefCounted

const CityDistrictGraph := preload("res://city_game/world/model/CityDistrictGraph.gd")
const CityRoadGraph := preload("res://city_game/world/model/CityRoadGraph.gd")
const CityBlockLayout := preload("res://city_game/world/model/CityBlockLayout.gd")
const CityReferenceRoadGraphBuilder := preload("res://city_game/world/generation/CityReferenceRoadGraphBuilder.gd")
const CityRoadGraphCache := preload("res://city_game/world/generation/CityRoadGraphCache.gd")

var _last_generation_profile: Dictionary = {}

func generate_world(config) -> Dictionary:
	var total_started_usec := Time.get_ticks_usec()
	var district_started_usec := Time.get_ticks_usec()
	var district_graph = _build_district_graph(config)
	var district_usec := Time.get_ticks_usec() - district_started_usec
	var road_result := _build_or_load_road_graph(config, district_graph)
	var road_graph: CityRoadGraph = road_result.get("road_graph")
	var road_usec := int(road_result.get("total_usec", 0))
	var block_started_usec := Time.get_ticks_usec()
	var block_layout = _build_block_layout(config)
	var block_usec := Time.get_ticks_usec() - block_started_usec
	_last_generation_profile = {
		"district_usec": district_usec,
		"road_graph_usec": road_usec,
		"road_graph_build_usec": int(road_result.get("build_usec", 0)),
		"road_graph_cache_hit": bool(road_result.get("cache_hit", false)),
		"road_graph_cache_load_usec": int(road_result.get("cache_load_usec", 0)),
		"road_graph_cache_write_usec": int(road_result.get("cache_write_usec", 0)),
		"road_graph_cache_path": str(road_result.get("cache_path", "")),
		"road_graph_cache_signature": str(road_result.get("cache_signature", "")),
		"road_graph_cache_size_bytes": int(road_result.get("cache_size_bytes", 0)),
		"road_graph_cache_error": str(road_result.get("cache_error", "")),
		"block_layout_usec": block_usec,
		"total_usec": Time.get_ticks_usec() - total_started_usec,
		"district_count": district_graph.get_district_count(),
		"road_edge_count": road_graph.get_edge_count(),
		"block_count": block_layout.get_block_count(),
		"parcel_count": block_layout.get_parcel_count(),
	}
	return {
		"seed": config.base_seed,
		"district_graph": district_graph,
		"road_graph": road_graph,
		"block_layout": block_layout,
		"generation_profile": _last_generation_profile.duplicate(true),
		"summary": _build_summary(config, district_graph, road_graph, block_layout),
	}

func get_last_generation_profile() -> Dictionary:
	return _last_generation_profile.duplicate(true)

func get_road_graph_cache_path(config) -> String:
	return CityRoadGraphCache.new().build_cache_path(config)

func _build_district_graph(config):
	var graph = CityDistrictGraph.new()
	var district_grid: Vector2i = config.get_district_grid_size()
	var bounds: Rect2 = config.get_world_bounds()

	for x in district_grid.x:
		for y in district_grid.y:
			var center: Vector2 = Vector2(
				bounds.position.x + config.district_size_m * (float(x) + 0.5),
				bounds.position.y + config.district_size_m * (float(y) + 0.5)
			)
			graph.add_district({
				"district_id": config.format_district_id(Vector2i(x, y)),
				"district_key": Vector2i(x, y),
				"center": center,
				"seed": config.derive_seed("district", Vector2i(x, y)),
			})
	return graph

func _build_road_graph(config, district_graph):
	var road_graph = CityRoadGraph.new()
	var district_grid: Vector2i = config.get_district_grid_size()
	var district_ids: Array[String] = district_graph.get_district_ids()

	for district in district_graph.districts:
		var district_key: Vector2i = district.get("district_key", Vector2i.ZERO)
		var road_anchor: Vector2 = _build_road_anchor(config, district.get("center", Vector2.ZERO), district_key)
		road_graph.add_node({
			"district_id": district["district_id"],
			"district_key": district_key,
			"center": road_anchor,
		})

	for x in district_grid.x:
		for y in district_grid.y:
			var source_id: String = district_ids[y + x * district_grid.y]
			if x + 1 < district_grid.x:
				var to_id_h: String = config.format_district_id(Vector2i(x + 1, y))
				var horizontal_class: String = _resolve_road_class(district_grid, Vector2i(x, y), true)
				road_graph.add_edge({
					"edge_id": "road_h_%02d_%02d" % [x, y],
					"road_id": "road_h_%02d_%02d" % [x, y],
					"from": source_id,
					"to": to_id_h,
					"class": horizontal_class,
					"display_name": _build_road_name(horizontal_class, true, y),
					"seed": config.derive_seed("road_h", Vector2i(x, y)),
					"width_m": _resolve_width_for_class(horizontal_class),
					"points": _build_edge_points(
						road_graph.get_node_by_id(source_id).get("center", Vector2.ZERO),
						road_graph.get_node_by_id(to_id_h).get("center", Vector2.ZERO),
						true,
						config.derive_seed("road_h", Vector2i(x, y)),
						horizontal_class
					),
				})
				_attach_edge_bounds(road_graph.edges[-1])
			if y + 1 < district_grid.y:
				var to_id_v: String = config.format_district_id(Vector2i(x, y + 1))
				var vertical_class: String = _resolve_road_class(district_grid, Vector2i(x, y), false)
				road_graph.add_edge({
					"edge_id": "road_v_%02d_%02d" % [x, y],
					"road_id": "road_v_%02d_%02d" % [x, y],
					"from": source_id,
					"to": to_id_v,
					"class": vertical_class,
					"display_name": _build_road_name(vertical_class, false, x),
					"seed": config.derive_seed("road_v", Vector2i(x, y)),
					"width_m": _resolve_width_for_class(vertical_class),
					"points": _build_edge_points(
						road_graph.get_node_by_id(source_id).get("center", Vector2.ZERO),
						road_graph.get_node_by_id(to_id_v).get("center", Vector2.ZERO),
						false,
						config.derive_seed("road_v", Vector2i(x, y)),
						vertical_class
					),
				})
				_attach_edge_bounds(road_graph.edges[-1])
	for district in district_graph.districts:
		_append_district_collector_roads(config, road_graph, district)
	CityReferenceRoadGraphBuilder.new().build_overlay(config, road_graph)
	return road_graph

func _build_or_load_road_graph(config, district_graph) -> Dictionary:
	var cache := CityRoadGraphCache.new()
	var cache_path := cache.build_cache_path(config)
	var cache_signature := cache.build_cache_signature(config)
	var cache_load_started_usec := Time.get_ticks_usec()
	var cached_result := cache.load_graph(config)
	var cache_load_usec := Time.get_ticks_usec() - cache_load_started_usec
	if bool(cached_result.get("hit", false)):
		return {
			"road_graph": cached_result.get("road_graph"),
			"total_usec": cache_load_usec,
			"build_usec": 0,
			"cache_hit": true,
			"cache_load_usec": cache_load_usec,
			"cache_write_usec": 0,
			"cache_path": str(cached_result.get("path", cache_path)),
			"cache_signature": str(cached_result.get("signature", cache_signature)),
			"cache_size_bytes": int(cached_result.get("size_bytes", 0)),
			"cache_error": "",
		}

	var build_started_usec := Time.get_ticks_usec()
	var road_graph = _build_road_graph(config, district_graph)
	var build_usec := Time.get_ticks_usec() - build_started_usec
	var cache_write_started_usec := Time.get_ticks_usec()
	var save_result := cache.save_graph(config, road_graph)
	var cache_write_usec := Time.get_ticks_usec() - cache_write_started_usec
	var write_success := bool(save_result.get("success", false))
	return {
		"road_graph": road_graph,
		"total_usec": build_usec + cache_write_usec,
		"build_usec": build_usec,
		"cache_hit": false,
		"cache_load_usec": cache_load_usec,
		"cache_write_usec": cache_write_usec,
		"cache_path": str(save_result.get("path", cache_path)),
		"cache_signature": str(save_result.get("signature", cache_signature)),
		"cache_size_bytes": int(save_result.get("size_bytes", 0)),
		"cache_error": "" if write_success else str(save_result.get("error", str(cached_result.get("error", "")))),
	}

func _build_block_layout(config):
	var layout = CityBlockLayout.new()
	layout.setup(config)
	return layout

func _build_summary(config, district_graph, road_graph, block_layout) -> String:
	return "%dkm x %dkm seed %d | %d districts | %d roads | %d blocks | %d parcels" % [
		int(config.world_width_m / 1000),
		int(config.world_depth_m / 1000),
		config.base_seed,
		district_graph.get_district_count(),
		road_graph.get_edge_count(),
		block_layout.get_block_count(),
		block_layout.get_parcel_count(),
	]

func _build_road_anchor(config, center: Vector2, district_key: Vector2i) -> Vector2:
	var x_scale := 4200.0 + float(config.derive_seed("road_anchor_scale_x", district_key) % 1700)
	var y_scale := 3900.0 + float(config.derive_seed("road_anchor_scale_y", district_key) % 1900)
	var x_wave := sin(center.y / y_scale + float(district_key.x) * 0.13) * 92.0
	var x_wave_secondary := sin(center.x / 8300.0 + float(district_key.y) * 0.11) * 28.0
	var y_wave := cos(center.x / x_scale + float(district_key.y) * 0.09) * 84.0
	var y_wave_secondary := sin(center.y / 7600.0 + float(district_key.x) * 0.17) * 24.0
	return center + Vector2(x_wave + x_wave_secondary, y_wave + y_wave_secondary)

func _resolve_road_class(district_grid: Vector2i, edge_key: Vector2i, horizontal: bool) -> String:
	var middle_row := int(floor(float(district_grid.y) * 0.5))
	var middle_column := int(floor(float(district_grid.x) * 0.5))
	if horizontal:
		if edge_key.y == middle_row or edge_key.y % 9 == 0:
			return "expressway_elevated"
		if edge_key.y % 4 == 0:
			return "arterial"
	else:
		if edge_key.x == middle_column or edge_key.x % 9 == 0:
			return "expressway_elevated"
		if edge_key.x % 4 == 0:
			return "arterial"
	return "secondary"

func _resolve_width_for_class(road_class: String) -> float:
	match road_class:
		"expressway_elevated":
			return 34.0
		"arterial":
			return 22.0
		"collector":
			return 11.0
	return 11.0

func _build_edge_points(from_center: Vector2, to_center: Vector2, horizontal: bool, edge_seed: int, road_class: String) -> Array[Vector2]:
	var direction := (to_center - from_center).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var curve_scale := 56.0 if road_class == "arterial" else 28.0
	var seed_factor := float(edge_seed % 1024) / 1024.0
	var curve_bias := sin(seed_factor * TAU + from_center.x / 8100.0 + to_center.y / 6700.0)
	if not horizontal:
		curve_bias = cos(seed_factor * TAU + from_center.y / 7900.0 + to_center.x / 6900.0)
	var control := from_center.lerp(to_center, 0.5) + normal * curve_bias * curve_scale
	var shoulder_pull := 0.22 if road_class == "arterial" else 0.16
	return [
		from_center,
		from_center.lerp(control, shoulder_pull),
		control,
		to_center.lerp(control, shoulder_pull),
		to_center,
	]

func _attach_edge_bounds(edge: Dictionary) -> void:
	var points: Array = edge.get("points", [])
	if points.is_empty():
		edge["bounds"] = Rect2()
		return
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in points:
		var world_point: Vector2 = point
		min_x = minf(min_x, world_point.x)
		min_y = minf(min_y, world_point.y)
		max_x = maxf(max_x, world_point.x)
		max_y = maxf(max_y, world_point.y)
	edge["bounds"] = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _append_district_collector_roads(config, road_graph: CityRoadGraph, district: Dictionary) -> void:
	var district_key: Vector2i = district.get("district_key", Vector2i.ZERO)
	var district_id := str(district.get("district_id", ""))
	var district_center: Vector2 = district.get("center", Vector2.ZERO)
	var hub := _build_district_local_hub(config, district_center, district_key)
	for side in ["west", "east", "north", "south"]:
		var portal := _build_district_boundary_portal(config, district_key, side)
		var edge_seed: int = int(config.derive_seed("district_collector_%s" % side, district_key))
		var edge := {
			"edge_id": "%s_collector_%s" % [district_id, side],
			"road_id": "%s_collector_%s" % [district_id, side],
			"from": district_id,
			"to": district_id,
			"class": "collector",
			"display_name": "%s Connector" % district_id,
			"seed": edge_seed,
			"width_m": 11.0,
			"points": _build_boundary_to_hub_points(portal, hub, side, edge_seed),
		}
		road_graph.add_edge(edge)
		_attach_edge_bounds(road_graph.edges[-1])

func _build_district_local_hub(config, district_center: Vector2, district_key: Vector2i) -> Vector2:
	var jitter_x := sin(float(config.derive_seed("district_hub_x", district_key) % 4096) * 0.017) * 138.0
	var jitter_y := cos(float(config.derive_seed("district_hub_y", district_key) % 4096) * 0.019) * 132.0
	return district_center + Vector2(jitter_x, jitter_y)

func _build_district_boundary_portal(config, district_key: Vector2i, side: String) -> Vector2:
	var bounds: Rect2 = config.get_world_bounds()
	var district_size := float(config.district_size_m)
	var district_min := Vector2(
		bounds.position.x + float(district_key.x) * district_size,
		bounds.position.y + float(district_key.y) * district_size
	)
	var district_max := district_min + Vector2.ONE * district_size
	var offset_ratio := _boundary_offset_ratio(config, district_key, side)

	match side:
		"west":
			return Vector2(district_min.x, lerpf(district_min.y + district_size * 0.18, district_max.y - district_size * 0.18, offset_ratio))
		"east":
			return Vector2(district_max.x, lerpf(district_min.y + district_size * 0.18, district_max.y - district_size * 0.18, offset_ratio))
		"north":
			return Vector2(lerpf(district_min.x + district_size * 0.18, district_max.x - district_size * 0.18, offset_ratio), district_min.y)
		"south":
			return Vector2(lerpf(district_min.x + district_size * 0.18, district_max.x - district_size * 0.18, offset_ratio), district_max.y)
	return district_min + Vector2.ONE * district_size * 0.5

func _boundary_offset_ratio(config, district_key: Vector2i, side: String) -> float:
	if side == "west" or side == "east":
		var boundary_x := district_key.x if side == "west" else district_key.x + 1
		var boundary_seed: int = int(config.derive_seed("district_boundary_v", Vector2i(boundary_x, district_key.y)))
		return 0.5 + sin(float(boundary_seed % 8192) * 0.013) * 0.22
	var boundary_y := district_key.y if side == "north" else district_key.y + 1
	var horizontal_seed: int = int(config.derive_seed("district_boundary_h", Vector2i(district_key.x, boundary_y)))
	return 0.5 + cos(float(horizontal_seed % 8192) * 0.015) * 0.22

func _build_boundary_to_hub_points(portal: Vector2, hub: Vector2, side: String, edge_seed: int) -> Array[Vector2]:
	var inward := Vector2.ZERO
	var lateral := Vector2.ZERO
	match side:
		"west":
			inward = Vector2.RIGHT
			lateral = Vector2.UP
		"east":
			inward = Vector2.LEFT
			lateral = Vector2.UP
		"north":
			inward = Vector2.DOWN
			lateral = Vector2.RIGHT
		"south":
			inward = Vector2.UP
			lateral = Vector2.RIGHT
	var shoulder := 132.0 + float(edge_seed % 60)
	var lateral_bias := sin(float(edge_seed % 4096) * 0.011) * 96.0
	var start_control := portal + inward * shoulder + lateral * lateral_bias * 0.28
	var end_control := portal.lerp(hub, 0.62) + lateral * lateral_bias
	return [
		portal,
		start_control,
		end_control,
		hub,
	]

func _build_road_name(road_class: String, horizontal: bool, index: int) -> String:
	var prefix := "Skyway" if road_class == "expressway_elevated" else ("Avenue" if road_class == "arterial" else "Street")
	var axis := "E" if horizontal else "N"
	return "%s %s%02d" % [prefix, axis, index]
