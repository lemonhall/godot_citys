extends RefCounted

const CityDistrictGraph := preload("res://city_game/world/model/CityDistrictGraph.gd")
const CityRoadGraph := preload("res://city_game/world/model/CityRoadGraph.gd")
const CityBlockLayout := preload("res://city_game/world/model/CityBlockLayout.gd")

func generate_world(config) -> Dictionary:
	var district_graph = _build_district_graph(config)
	var road_graph = _build_road_graph(config, district_graph)
	var block_layout = _build_block_layout(config)
	return {
		"seed": config.base_seed,
		"district_graph": district_graph,
		"road_graph": road_graph,
		"block_layout": block_layout,
		"summary": _build_summary(config, district_graph, road_graph, block_layout),
	}

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
					"from": source_id,
					"to": to_id_h,
					"class": horizontal_class,
					"seed": config.derive_seed("road_h", Vector2i(x, y)),
					"width_m": 22.0 if horizontal_class == "arterial" else 14.0,
					"points": _build_edge_points(
						config,
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
					"from": source_id,
					"to": to_id_v,
					"class": vertical_class,
					"seed": config.derive_seed("road_v", Vector2i(x, y)),
					"width_m": 20.0 if vertical_class == "arterial" else 12.0,
					"points": _build_edge_points(
						config,
						road_graph.get_node_by_id(source_id).get("center", Vector2.ZERO),
						road_graph.get_node_by_id(to_id_v).get("center", Vector2.ZERO),
						false,
						config.derive_seed("road_v", Vector2i(x, y)),
						vertical_class
					),
				})
				_attach_edge_bounds(road_graph.edges[-1])
	return road_graph

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
	if horizontal:
		if edge_key.y % 4 == 0 or edge_key.y == district_grid.y / 2:
			return "arterial"
	else:
		if edge_key.x % 4 == 0 or edge_key.x == district_grid.x / 2:
			return "arterial"
	return "secondary"

func _build_edge_points(config, from_center: Vector2, to_center: Vector2, horizontal: bool, seed: int, road_class: String) -> Array[Vector2]:
	var direction := (to_center - from_center).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var curve_scale := 56.0 if road_class == "arterial" else 28.0
	var seed_factor := float(seed % 1024) / 1024.0
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
