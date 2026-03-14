extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world: Dictionary = CityWorldGenerator.new().generate_world(config)
	if not T.require_true(self, world.has("vehicle_query"), "World data must include vehicle_query"):
		return

	var vehicle_query = world["vehicle_query"]
	if not T.require_true(self, vehicle_query.has_method("get_lane_graph"), "vehicle_query must expose get_lane_graph()"):
		return
	var lane_graph = vehicle_query.get_lane_graph()
	if not T.require_true(self, lane_graph != null, "vehicle lane_graph must exist"):
		return
	if not T.require_true(self, lane_graph.has_method("get_lane_count"), "vehicle lane_graph must expose get_lane_count()"):
		return
	if not T.require_true(self, lane_graph.has_method("get_lanes_intersecting_rect"), "vehicle lane_graph must expose get_lanes_intersecting_rect()"):
		return
	if not T.require_true(self, lane_graph.has_method("get_lane_by_id"), "vehicle lane_graph must expose get_lane_by_id()"):
		return
	if not T.require_true(self, lane_graph.has_method("get_lane_ids_for_road"), "vehicle lane_graph must expose get_lane_ids_for_road()"):
		return
	if not T.require_true(self, lane_graph.get_lane_count() > 0, "vehicle lane_graph must contain lanes"):
		return

	var center_chunk := _center_chunk(config)
	var chunk_rect := _build_chunk_rect(config, center_chunk)
	var chunk_lanes: Array = lane_graph.get_lanes_intersecting_rect(chunk_rect.grow(float(config.chunk_size_m) * 0.25))
	if not T.require_true(self, not chunk_lanes.is_empty(), "Center chunk lane query must return drivable lanes"):
		return

	var road_graph = world.get("road_graph")
	var sample_edge: Dictionary = _find_semantic_road_edge(road_graph, chunk_rect.grow(float(config.chunk_size_m)))
	if not T.require_true(self, not sample_edge.is_empty(), "Center area must expose a semantic road edge for lane graph checks"):
		return

	var lane_schema: Dictionary = (sample_edge.get("section_semantics", {}) as Dictionary).get("lane_schema", {})
	var expected_lane_count := int(lane_schema.get("forward_lane_count", 0)) + int(lane_schema.get("backward_lane_count", 0))
	var road_id := str(sample_edge.get("road_id", sample_edge.get("edge_id", "")))
	var lane_ids: Array = lane_graph.get_lane_ids_for_road(road_id)
	if not T.require_true(self, lane_ids.size() == expected_lane_count, "Vehicle lane graph must derive lane count directly from section_semantics lane_schema"):
		return

	for lane_id_variant in lane_ids:
		var lane_id := str(lane_id_variant)
		var lane: Dictionary = lane_graph.get_lane_by_id(lane_id)
		if not T.require_true(self, str(lane.get("road_id", "")) == road_id, "Vehicle lane must preserve source road_id"):
			return
		if not T.require_true(self, str(lane.get("lane_type", "")) == "driving", "Vehicle lane graph must only expose driving lanes"):
			return
		if not T.require_true(self, str(lane.get("direction_mode", "")) == str(lane_schema.get("direction_mode", "")), "Vehicle lane direction_mode must come from section_semantics lane_schema"):
			return
		if not T.require_true(self, float(lane.get("path_length_m", 0.0)) > 1.0, "Vehicle lane must expose path_length_m"):
			return
		if not T.require_true(self, (lane.get("points", []) as Array).size() >= 2, "Vehicle lane must expose travel points"):
			return

	T.pass_and_quit(self)

func _center_chunk(config: CityWorldConfig) -> Vector2i:
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	return Vector2i(
		int(floor(float(chunk_grid.x) * 0.5)),
		int(floor(float(chunk_grid.y) * 0.5))
	)

func _build_chunk_rect(config: CityWorldConfig, chunk_key: Vector2i) -> Rect2:
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_size := float(config.chunk_size_m)
	var chunk_origin := Vector2(
		bounds.position.x + float(chunk_key.x) * chunk_size,
		bounds.position.y + float(chunk_key.y) * chunk_size
	)
	return Rect2(chunk_origin, Vector2.ONE * chunk_size)

func _find_semantic_road_edge(road_graph, rect: Rect2) -> Dictionary:
	for edge_variant in road_graph.get_edges_intersecting_rect(rect):
		var edge: Dictionary = edge_variant
		var section_semantics: Dictionary = edge.get("section_semantics", {})
		var lane_schema: Dictionary = section_semantics.get("lane_schema", {})
		if lane_schema.is_empty():
			continue
		var lane_count := int(lane_schema.get("forward_lane_count", 0)) + int(lane_schema.get("backward_lane_count", 0))
		if lane_count <= 0:
			continue
		return edge
	return {}
