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
		road_graph.add_node({
			"district_id": district["district_id"],
			"center": district["center"],
		})

	for x in district_grid.x:
		for y in district_grid.y:
			var source_id: String = district_ids[y + x * district_grid.y]
			if x + 1 < district_grid.x:
				road_graph.add_edge({
					"edge_id": "road_h_%02d_%02d" % [x, y],
					"from": source_id,
					"to": config.format_district_id(Vector2i(x + 1, y)),
					"class": "arterial",
					"seed": config.derive_seed("road_h", Vector2i(x, y)),
				})
			if y + 1 < district_grid.y:
				road_graph.add_edge({
					"edge_id": "road_v_%02d_%02d" % [x, y],
					"from": source_id,
					"to": config.format_district_id(Vector2i(x, y + 1)),
					"class": "secondary",
					"seed": config.derive_seed("road_v", Vector2i(x, y)),
				})
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
