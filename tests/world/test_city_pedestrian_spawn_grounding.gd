extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world: Dictionary = CityWorldGenerator.new().generate_world(config)
	var pedestrian_query = world.get("pedestrian_query")
	if not T.require_true(self, pedestrian_query != null, "World data must include pedestrian_query"):
		return
	if not T.require_true(self, pedestrian_query.has_method("get_lane_graph"), "pedestrian_query must expose get_lane_graph()"):
		return

	var lane_graph = pedestrian_query.get_lane_graph()
	var road_graph = world.get("road_graph")
	if not T.require_true(self, road_graph != null, "World data must include road_graph"):
		return
	if not T.require_true(self, road_graph.has_method("get_edge_by_id"), "road_graph must expose get_edge_by_id()"):
		return

	var chunk_query: Dictionary = pedestrian_query.get_pedestrian_query_for_chunk(_center_chunk(config))
	var spawn_slots: Array = chunk_query.get("spawn_slots", [])
	if not T.require_true(self, not spawn_slots.is_empty(), "Spawn grounding test requires spawn_slots"):
		return

	var sample_count := mini(spawn_slots.size(), 12)
	for slot_index in range(sample_count):
		var spawn_slot: Dictionary = spawn_slots[slot_index]
		if not T.require_true(self, spawn_slot.has("world_position"), "spawn_slot must expose world_position"):
			return
		if not T.require_true(self, spawn_slot.has("road_clearance_m"), "spawn_slot must expose road_clearance_m"):
			return
		var lane: Dictionary = lane_graph.get_lane_by_id(str(spawn_slot.get("lane_ref_id", "")))
		if not T.require_true(self, str(lane.get("lane_type", "")) == "sidewalk", "spawn_slot lane must be sidewalk"):
			return
		if not T.require_true(self, str(spawn_slot.get("road_class", "")) != "expressway_elevated", "spawn_slot must not bind to expressway lane"):
			return

		var road_edge: Dictionary = road_graph.get_edge_by_id(str(spawn_slot.get("road_id", "")))
		if not T.require_true(self, not road_edge.is_empty(), "spawn_slot road_id must resolve to road edge"):
			return
		var world_position: Vector3 = spawn_slot.get("world_position", Vector3.ZERO)
		var centerline_distance := _distance_to_polyline(Vector2(world_position.x, world_position.z), road_edge.get("points", []))
		var minimum_clearance := float(road_edge.get("width_m", 0.0)) * 0.5 + 1.0
		if not T.require_true(self, float(spawn_slot.get("road_clearance_m", 0.0)) >= minimum_clearance, "spawn_slot road_clearance_m must stay outside drivable roadbed"):
			return
		if not T.require_true(self, centerline_distance >= minimum_clearance, "spawn_slot world_position must stay outside drivable roadbed"):
			return

	T.pass_and_quit(self)

func _center_chunk(config: CityWorldConfig) -> Vector2i:
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	return Vector2i(
		int(floor(float(chunk_grid.x) * 0.5)),
		int(floor(float(chunk_grid.y) * 0.5))
	)

func _distance_to_polyline(point: Vector2, polyline: Array) -> float:
	var best_distance := INF
	for point_index in range(polyline.size() - 1):
		var a_variant = polyline[point_index]
		var b_variant = polyline[point_index + 1]
		var a2 := Vector2(a_variant.x, a_variant.y if a_variant is Vector2 else a_variant.z)
		var b2 := Vector2(b_variant.x, b_variant.y if b_variant is Vector2 else b_variant.z)
		var nearest := Geometry2D.get_closest_point_to_segment(point, a2, b2)
		best_distance = minf(best_distance, point.distance_to(nearest))
	return best_distance
