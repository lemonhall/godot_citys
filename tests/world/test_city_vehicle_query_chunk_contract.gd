extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world: Dictionary = CityWorldGenerator.new().generate_world(config)
	var vehicle_query = world.get("vehicle_query")
	var road_graph = world.get("road_graph")
	if not T.require_true(self, vehicle_query != null, "World data must include vehicle_query"):
		return
	if not T.require_true(self, road_graph != null, "World data must include road_graph"):
		return
	if not T.require_true(self, vehicle_query.has_method("get_lane_graph"), "vehicle_query must expose get_lane_graph()"):
		return

	var lane_graph = vehicle_query.get_lane_graph()
	if not T.require_true(self, lane_graph.has_method("get_boundary_connectors_for_rect"), "vehicle lane_graph must expose get_boundary_connectors_for_rect()"):
		return

	var center_chunk := _center_chunk(config)
	var center_query: Dictionary = vehicle_query.get_vehicle_query_for_chunk(center_chunk)
	if not T.require_true(self, not (center_query.get("lane_ids", []) as Array).is_empty(), "Center chunk query must expose lane_ids"):
		return
	if not T.require_true(self, not (center_query.get("spawn_slots", []) as Array).is_empty(), "Center chunk query must expose spawn_slots"):
		return

	var spawn_slots: Array = center_query.get("spawn_slots", [])
	var check_count := mini(spawn_slots.size(), 8)
	for slot_index in range(check_count):
		var slot: Dictionary = spawn_slots[slot_index]
		var lane: Dictionary = lane_graph.get_lane_by_id(str(slot.get("lane_ref_id", "")))
		if not T.require_true(self, str(lane.get("lane_type", "")) == "driving", "Vehicle spawn slots must bind to driving lanes"):
			return
		var road_edge: Dictionary = road_graph.get_edge_by_id(str(slot.get("road_id", "")))
		if not T.require_true(self, not road_edge.is_empty(), "Vehicle spawn slots must resolve back to shared road graph edges"):
			return
		var surface_half_width := float((road_edge.get("section_semantics", {}) as Dictionary).get("edge_profile", {}).get("surface_half_width_m", road_edge.get("width_m", 0.0) * 0.5))
		var world_position: Vector3 = slot.get("world_position", Vector3.ZERO)
		var centerline_distance := _distance_to_polyline(Vector2(world_position.x, world_position.z), road_edge.get("points", []))
		if not T.require_true(self, centerline_distance <= surface_half_width + 1.5, "Vehicle spawn anchors must stay on drivable road surface instead of sidewalk/crossing offsets"):
			return

	var chunk_pair := _find_connected_chunk_pair(config, lane_graph)
	if not T.require_true(self, not chunk_pair.is_empty(), "Vehicle lane graph must expose at least one center-adjacent chunk pair with east/west boundary connectors"):
		return
	var left_chunk: Vector2i = chunk_pair.get("left_chunk", center_chunk)
	var right_chunk: Vector2i = chunk_pair.get("right_chunk", center_chunk + Vector2i.RIGHT)
	var right_query: Dictionary = vehicle_query.get_vehicle_query_for_chunk(right_chunk)
	if not T.require_true(self, not (right_query.get("lane_ids", []) as Array).is_empty(), "Adjacent connected chunk query must also expose lane_ids"):
		return
	var left_rect := _build_chunk_rect(config, left_chunk)
	var right_rect := _build_chunk_rect(config, right_chunk)
	var left_connectors: Dictionary = lane_graph.get_boundary_connectors_for_rect(left_rect)
	var right_connectors: Dictionary = lane_graph.get_boundary_connectors_for_rect(right_rect)
	var left_east: Array = left_connectors.get("east", [])
	var right_west: Array = right_connectors.get("west", [])
	if not T.require_true(self, _connector_signature(left_east) == _connector_signature(right_west), "Vehicle lane graph must stay continuous across chunk boundaries"):
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

func _distance_to_polyline(position: Vector2, points: Array) -> float:
	var best_distance := INF
	for point_index in range(points.size() - 1):
		var a: Vector2 = points[point_index]
		var b: Vector2 = points[point_index + 1]
		var nearest := Geometry2D.get_closest_point_to_segment(position, a, b)
		best_distance = minf(best_distance, position.distance_to(nearest))
	return best_distance

func _connector_signature(connectors: Array) -> PackedStringArray:
	var signature := PackedStringArray()
	for connector_variant in connectors:
		var connector: Dictionary = connector_variant
		signature.append("%s:%d" % [
			str(connector.get("lane_id", "")),
			int(round(float(connector.get("offset", 0.0)) * 10.0)),
		])
	return signature

func _find_connected_chunk_pair(config: CityWorldConfig, lane_graph) -> Dictionary:
	var center_chunk := _center_chunk(config)
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	for offset_x in range(-2, 3):
		for offset_y in range(-2, 3):
			var left_chunk := center_chunk + Vector2i(offset_x, offset_y)
			if left_chunk.x < 0 or left_chunk.y < 0:
				continue
			var right_chunk := left_chunk + Vector2i.RIGHT
			if right_chunk.x >= chunk_grid.x or right_chunk.y >= chunk_grid.y:
				continue
			var left_rect := _build_chunk_rect(config, left_chunk)
			var right_rect := _build_chunk_rect(config, right_chunk)
			var left_connectors: Dictionary = lane_graph.get_boundary_connectors_for_rect(left_rect)
			var right_connectors: Dictionary = lane_graph.get_boundary_connectors_for_rect(right_rect)
			var left_east: Array = left_connectors.get("east", [])
			var right_west: Array = right_connectors.get("west", [])
			if left_east.is_empty() or right_west.is_empty():
				continue
			if _connector_signature(left_east) == _connector_signature(right_west):
				return {
					"left_chunk": left_chunk,
					"right_chunk": right_chunk,
				}
	return {}
