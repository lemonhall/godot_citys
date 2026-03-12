extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")
const CityPedestrianBudget := preload("res://city_game/world/pedestrians/streaming/CityPedestrianBudget.gd")
const CityPedestrianStreamer := preload("res://city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd")

var _runtime_ground_profile_cache: Dictionary = {}

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

	var budget := CityPedestrianBudget.new()
	budget.setup(config)
	var pedestrian_streamer := CityPedestrianStreamer.new()
	pedestrian_streamer.setup(config, world, budget.get_contract())

	var candidate_result: Dictionary = _find_chunk_runtime_grounding_candidate(config, world, pedestrian_query, pedestrian_streamer)
	if not T.require_true(self, not candidate_result.is_empty(), "Spawn grounding test requires at least one sidewalk pedestrian near a roadbed-aware runtime surface"):
		return
	var chunk_query: Dictionary = candidate_result.get("chunk_query", {})
	var runtime_candidate: Dictionary = candidate_result.get("runtime_candidate", {})
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

	if not T.require_true(self, float(runtime_candidate.get("spawn_error_m", INF)) <= 0.05, "Spawned pedestrian height must already match chunk ground surface within 0.05m"):
		return
	if not T.require_true(self, float(runtime_candidate.get("step_error_m", INF)) <= 0.05, "Pedestrian height must stay glued to chunk ground after the first runtime step"):
		return

	T.pass_and_quit(self)

func _center_chunk(config: CityWorldConfig) -> Vector2i:
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	return Vector2i(
		int(floor(float(chunk_grid.x) * 0.5)),
		int(floor(float(chunk_grid.y) * 0.5))
	)

func _build_probe_chunk_keys(config: CityWorldConfig) -> Array[Vector2i]:
	var center_chunk := _center_chunk(config)
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	var probe_chunk_keys: Array[Vector2i] = []
	for radius in range(0, 8):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				var chunk_key := Vector2i(
					clampi(center_chunk.x + offset_x, 0, chunk_grid.x - 1),
					clampi(center_chunk.y + offset_y, 0, chunk_grid.y - 1)
				)
				if probe_chunk_keys.has(chunk_key):
					continue
				probe_chunk_keys.append(chunk_key)
	return probe_chunk_keys

func _find_chunk_runtime_grounding_candidate(config: CityWorldConfig, world_data: Dictionary, pedestrian_query, pedestrian_streamer: CityPedestrianStreamer) -> Dictionary:
	for chunk_key in _build_probe_chunk_keys(config):
		var chunk_query: Dictionary = pedestrian_query.get_pedestrian_query_for_chunk(chunk_key)
		if (chunk_query.get("spawn_slots", []) as Array).is_empty():
			continue
		pedestrian_streamer.sync_active_chunks([{
			"chunk_id": str(chunk_query.get("chunk_id", "")),
			"chunk_key": chunk_key,
		}])
		var active_states: Array = pedestrian_streamer.get_active_states()
		if active_states.is_empty():
			continue
		var runtime_candidate: Dictionary = _find_runtime_grounding_candidate(config, world_data, pedestrian_streamer, active_states)
		if not runtime_candidate.is_empty():
			return {
				"chunk_query": chunk_query,
				"runtime_candidate": runtime_candidate,
			}
	return {}

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

func _find_runtime_grounding_candidate(config: CityWorldConfig, world_data: Dictionary, pedestrian_streamer: CityPedestrianStreamer, active_states: Array) -> Dictionary:
	var best_candidate := {}
	var best_surface_delta := -INF
	for state_variant in active_states:
		var state = state_variant
		var spawn_expected_y := _sample_runtime_ground_height(config, world_data, state.world_position)
		var spawn_error_m := absf(spawn_expected_y - state.world_position.y)
		var roadbed_delta_m := absf(_sample_surface_delta(config, world_data, state.world_position))
		if roadbed_delta_m < 0.08:
			continue

		state.queue_step(0.25)
		state.step(state.flush_queued_step())
		pedestrian_streamer.ground_state(state)
		var step_expected_y := _sample_runtime_ground_height(config, world_data, state.world_position)
		var step_error_m := absf(step_expected_y - state.world_position.y)
		if roadbed_delta_m > best_surface_delta:
			best_surface_delta = roadbed_delta_m
			best_candidate = {
				"pedestrian_id": state.pedestrian_id,
				"roadbed_delta_m": roadbed_delta_m,
				"spawn_error_m": spawn_error_m,
				"step_error_m": step_error_m,
			}
	return best_candidate

func _sample_runtime_ground_height(config: CityWorldConfig, world_data: Dictionary, world_position: Vector3) -> float:
	var chunk_key := CityChunkKey.world_to_chunk_key(config, world_position)
	var chunk_payload := _build_chunk_payload(config, world_data, chunk_key)
	var profile := _get_runtime_ground_profile(config, world_data, chunk_key)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := Vector2(world_position.x - chunk_center.x, world_position.z - chunk_center.z)
	return CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile)

func _sample_surface_delta(config: CityWorldConfig, world_data: Dictionary, world_position: Vector3) -> float:
	var chunk_key := CityChunkKey.world_to_chunk_key(config, world_position)
	var chunk_payload := _build_chunk_payload(config, world_data, chunk_key)
	var profile := _get_runtime_ground_profile(config, world_data, chunk_key)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := Vector2(world_position.x - chunk_center.x, world_position.z - chunk_center.z)
	return CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile) - CityTerrainSampler.sample_height(world_position.x, world_position.z, int(config.base_seed))

func _build_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i) -> Dictionary:
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
		"world_seed": int(config.base_seed),
		"road_graph": world_data.get("road_graph"),
	}

func _get_runtime_ground_profile(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i) -> Dictionary:
	var chunk_id := config.format_chunk_id(chunk_key)
	if _runtime_ground_profile_cache.has(chunk_id):
		return _runtime_ground_profile_cache[chunk_id]
	var chunk_payload := _build_chunk_payload(config, world_data, chunk_key)
	var profile := {
		"road_segments": (CityRoadLayoutBuilder.build_chunk_roads(chunk_payload).get("segments", []) as Array).duplicate(true),
	}
	_runtime_ground_profile_cache[chunk_id] = profile
	return profile
