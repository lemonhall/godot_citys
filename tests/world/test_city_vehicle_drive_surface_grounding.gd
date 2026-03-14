extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityVehicleStreamer := preload("res://city_game/world/vehicles/streaming/CityVehicleStreamer.gd")
const CityVehicleState := preload("res://city_game/world/vehicles/simulation/CityVehicleState.gd")
const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

const HEIGHT_EPSILON_M := 0.18
const BRIDGE_CLEARANCE_MIN_M := 4.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var vehicle_query = world_data.get("vehicle_query")
	if not T.require_true(self, vehicle_query != null and vehicle_query.has_method("get_vehicle_query_for_chunk"), "Drive-surface grounding validation requires vehicle_query"):
		return

	var sample_result := _find_grounding_samples(config, world_data, vehicle_query)
	if not T.require_true(self, not sample_result.is_empty(), "Drive-surface grounding validation requires at least one sampled spawn slot"):
		return

	var road_sample: Dictionary = sample_result.get("road_sample", {})
	var bridge_sample: Dictionary = sample_result.get("bridge_sample", {})
	if not T.require_true(self, not road_sample.is_empty(), "Drive-surface grounding validation requires at least one non-bridge vehicle sample"):
		return
	if not T.require_true(self, not bridge_sample.is_empty(), "Drive-surface grounding validation requires at least one bridge vehicle sample"):
		return

	var streamer := CityVehicleStreamer.new()
	streamer.setup(config, world_data, {})

	var grounded_road_state := _ground_sample(streamer, road_sample)
	var grounded_bridge_state := _ground_sample(streamer, bridge_sample)

	var expected_road_y := float(road_sample.get("expected_surface_y", 0.0))
	var expected_bridge_y := float(bridge_sample.get("expected_surface_y", 0.0))
	if not T.require_true(self, absf(grounded_road_state.world_position.y - expected_road_y) <= HEIGHT_EPSILON_M, "Vehicle ground_state must stay aligned to sampled road surface height on normal roads"):
		return
	if not T.require_true(self, absf(grounded_bridge_state.world_position.y - expected_bridge_y) <= HEIGHT_EPSILON_M, "Vehicle ground_state must stay aligned to sampled road surface height on bridge decks"):
		return

	var bridge_world_position: Vector3 = bridge_sample.get("world_position", Vector3.ZERO)
	var terrain_y := CityTerrainSampler.sample_height(bridge_world_position.x, bridge_world_position.z, int(config.base_seed))
	if not T.require_true(self, grounded_bridge_state.world_position.y - terrain_y >= BRIDGE_CLEARANCE_MIN_M, "Bridge vehicles must stay clearly above terrain instead of collapsing back onto the ground mesh"):
		return

	print("CITY_VEHICLE_DRIVE_SURFACE_GROUNDING %s" % JSON.stringify({
		"road_expected_y": expected_road_y,
		"road_grounded_y": grounded_road_state.world_position.y,
		"bridge_expected_y": expected_bridge_y,
		"bridge_grounded_y": grounded_bridge_state.world_position.y,
		"bridge_terrain_y": terrain_y,
	}))

	T.pass_and_quit(self)

func _find_grounding_samples(config: CityWorldConfig, world_data: Dictionary, vehicle_query) -> Dictionary:
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	var center_chunk := Vector2i(chunk_grid.x / 2, chunk_grid.y / 2)
	var road_sample: Dictionary = {}
	var bridge_sample: Dictionary = {}
	for offset_y in range(-6, 7):
		for offset_x in range(-6, 7):
			var chunk_key := center_chunk + Vector2i(offset_x, offset_y)
			if chunk_key.x < 0 or chunk_key.y < 0 or chunk_key.x >= chunk_grid.x or chunk_key.y >= chunk_grid.y:
				continue
			var chunk_payload := _make_chunk_payload(config, world_data, chunk_key)
			var road_layout: Dictionary = CityRoadLayoutBuilder.build_chunk_roads(chunk_payload)
			var segments: Array = road_layout.get("segments", [])
			var chunk_query: Dictionary = vehicle_query.get_vehicle_query_for_chunk(chunk_key)
			for slot_variant in chunk_query.get("spawn_slots", []):
				var slot: Dictionary = slot_variant
				var matched_segment := _find_matching_segment(segments, slot)
				if matched_segment.is_empty():
					continue
				var expected_surface_y := _sample_segment_surface_height(matched_segment, _world_to_local_point(chunk_payload, slot.get("world_position", Vector3.ZERO)))
				var sample := {
					"chunk_payload": chunk_payload,
					"slot": slot.duplicate(true),
					"segment": matched_segment.duplicate(true),
					"expected_surface_y": expected_surface_y,
					"world_position": slot.get("world_position", Vector3.ZERO),
				}
				if bool(matched_segment.get("bridge", false)) and bridge_sample.is_empty():
					bridge_sample = sample
				elif not bool(matched_segment.get("bridge", false)) and road_sample.is_empty():
					road_sample = sample
				if not road_sample.is_empty() and not bridge_sample.is_empty():
					return {
						"road_sample": road_sample,
						"bridge_sample": bridge_sample,
					}
	return {
		"road_sample": road_sample,
		"bridge_sample": bridge_sample,
	}

func _ground_sample(streamer: CityVehicleStreamer, sample: Dictionary) -> CityVehicleState:
	var slot: Dictionary = sample.get("slot", {})
	var state := CityVehicleState.new()
	state.setup({
		"vehicle_id": "grounding:%s" % str(slot.get("spawn_slot_id", "")),
		"chunk_id": str((sample.get("chunk_payload", {}) as Dictionary).get("chunk_id", "")),
		"page_id": "grounding",
		"spawn_slot_id": str(slot.get("spawn_slot_id", "")),
		"road_id": str(slot.get("road_id", "")),
		"lane_ref_id": str(slot.get("lane_ref_id", "")),
		"world_position": slot.get("world_position", Vector3.ZERO),
		"lane_points": [],
		"lane_length_m": 1.0,
		"distance_along_lane_m": 0.0,
	})
	streamer.ground_state(state)
	return state

func _find_matching_segment(segments: Array, slot: Dictionary) -> Dictionary:
	var slot_road_id := str(slot.get("road_id", ""))
	var slot_position: Vector3 = slot.get("world_position", Vector3.ZERO)
	var best_segment := {}
	var best_distance := INF
	for segment_variant in segments:
		if not segment_variant is Dictionary:
			continue
		var segment: Dictionary = segment_variant
		if str(segment.get("road_id", "")) != slot_road_id:
			continue
		var distance := _distance_to_segment_polyline(slot_position, segment.get("points", []))
		if distance < best_distance:
			best_distance = distance
			best_segment = segment
	if best_segment.is_empty():
		return {}
	return best_segment

func _sample_segment_surface_height(segment: Dictionary, local_point: Vector2) -> float:
	var points: Array = segment.get("points", [])
	if points.size() < 2:
		return 0.0
	var best_distance := INF
	var best_height := 0.0
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var a_2d := Vector2(a.x, a.z)
		var b_2d := Vector2(b.x, b.z)
		var nearest := Geometry2D.get_closest_point_to_segment(local_point, a_2d, b_2d)
		var distance := local_point.distance_to(nearest)
		if distance >= best_distance:
			continue
		var segment_2d := b_2d - a_2d
		var segment_length_sq := segment_2d.length_squared()
		var t := 0.0 if segment_length_sq <= 0.001 else clampf((nearest - a_2d).dot(segment_2d) / segment_length_sq, 0.0, 1.0)
		best_distance = distance
		best_height = lerpf(a.y, b.y, t)
	return best_height

func _distance_to_segment_polyline(world_position: Vector3, points: Array) -> float:
	var best_distance := INF
	var local_point := Vector2(world_position.x, world_position.z)
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var nearest := Geometry2D.get_closest_point_to_segment(local_point, Vector2(a.x, a.z), Vector2(b.x, b.z))
		best_distance = minf(best_distance, local_point.distance_to(nearest))
	return best_distance

func _world_to_local_point(chunk_payload: Dictionary, world_position: Vector3) -> Vector2:
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	return Vector2(world_position.x - chunk_center.x, world_position.z - chunk_center.z)

func _make_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i) -> Dictionary:
	var bounds: Rect2 = config.get_world_bounds()
	return {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": Vector3(
			bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
			0.0,
			bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
		),
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"world_seed": config.base_seed,
		"road_graph": world_data.get("road_graph"),
	}
