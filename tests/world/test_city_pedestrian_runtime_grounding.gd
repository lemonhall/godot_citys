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
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var budget := CityPedestrianBudget.new()
	budget.setup(config)
	var pedestrian_streamer := CityPedestrianStreamer.new()
	pedestrian_streamer.setup(config, world_data, budget.get_contract())

	var probe_chunk_keys := _build_probe_chunk_keys(config)
	var best_roadbed_candidate := {}
	var best_slope_candidate := {}
	for probe_chunk_key in probe_chunk_keys:
		pedestrian_streamer.sync_active_chunks([{
			"chunk_id": config.format_chunk_id(probe_chunk_key),
			"chunk_key": probe_chunk_key,
		}])
		var active_states: Array = pedestrian_streamer.get_active_states()
		if active_states.is_empty():
			continue
		if best_roadbed_candidate.is_empty():
			best_roadbed_candidate = _find_best_roadbed_candidate(config, world_data, active_states)
		if best_slope_candidate.is_empty():
			best_slope_candidate = _find_best_slope_candidate(config, world_data, pedestrian_streamer, active_states)
		if not best_roadbed_candidate.is_empty() and not best_slope_candidate.is_empty():
			break

	if not T.require_true(self, not best_roadbed_candidate.is_empty(), "Runtime grounding test requires a roadbed-influenced pedestrian candidate"):
		return
	if not T.require_true(self, float(best_roadbed_candidate.get("ground_error_m", INF)) <= 0.05, "Roadbed-influenced pedestrian height must stay within 0.05m of runtime chunk ground"):
		return
	if not T.require_true(self, not best_slope_candidate.is_empty(), "Runtime grounding test requires a sloped sidewalk pedestrian candidate"):
		return
	if not T.require_true(self, float(best_slope_candidate.get("peak_ground_error_m", INF)) <= 0.05, "Moving pedestrian height must stay within 0.05m of runtime chunk ground on sloped sidewalks"):
		return

	print("CITY_PEDESTRIAN_RUNTIME_GROUNDING %s" % JSON.stringify({
		"roadbed_candidate": best_roadbed_candidate,
		"slope_candidate": best_slope_candidate,
	}))
	T.pass_and_quit(self)

func _build_probe_chunk_keys(config: CityWorldConfig) -> Array[Vector2i]:
	var center_chunk := Vector2i(
		int(floor(float(config.get_chunk_grid_size().x) * 0.5)),
		int(floor(float(config.get_chunk_grid_size().y) * 0.5))
	)
	var probe_chunk_keys: Array[Vector2i] = []
	for radius in range(0, 8):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				var chunk_key := Vector2i(
					clampi(center_chunk.x + offset_x, 0, config.get_chunk_grid_size().x - 1),
					clampi(center_chunk.y + offset_y, 0, config.get_chunk_grid_size().y - 1)
				)
				if probe_chunk_keys.has(chunk_key):
					continue
				probe_chunk_keys.append(chunk_key)
	return probe_chunk_keys

func _find_best_roadbed_candidate(config: CityWorldConfig, world_data: Dictionary, active_states: Array) -> Dictionary:
	var best_candidate := {}
	var best_surface_delta := -INF
	for state_variant in active_states:
		var state = state_variant
		var runtime_ground_y := _sample_runtime_ground_height(config, world_data, state.world_position)
		var base_ground_y := CityTerrainSampler.sample_height(state.world_position.x, state.world_position.z, int(config.base_seed))
		var surface_delta_m := absf(runtime_ground_y - base_ground_y)
		if surface_delta_m < 0.08:
			continue
		if surface_delta_m > best_surface_delta:
			best_surface_delta = surface_delta_m
			best_candidate = {
				"pedestrian_id": state.pedestrian_id,
				"surface_delta_m": surface_delta_m,
				"ground_error_m": absf(runtime_ground_y - state.world_position.y),
			}
	return best_candidate

func _find_best_slope_candidate(config: CityWorldConfig, world_data: Dictionary, pedestrian_streamer: CityPedestrianStreamer, active_states: Array) -> Dictionary:
	var best_candidate := {}
	var best_expected_height_delta := -INF
	for state_variant in active_states:
		var state = state_variant
		var start_runtime_ground_y := _sample_runtime_ground_height(config, world_data, state.world_position)
		var peak_ground_error_m := absf(start_runtime_ground_y - state.world_position.y)
		var peak_expected_height_delta := 0.0
		for _step_index in range(10):
			state.queue_step(0.2)
			state.step(state.flush_queued_step())
			pedestrian_streamer.ground_state(state)
			var runtime_ground_y := _sample_runtime_ground_height(config, world_data, state.world_position)
			peak_ground_error_m = maxf(peak_ground_error_m, absf(runtime_ground_y - state.world_position.y))
			peak_expected_height_delta = maxf(peak_expected_height_delta, absf(runtime_ground_y - start_runtime_ground_y))
		if peak_expected_height_delta < 0.12:
			continue
		if peak_expected_height_delta > best_expected_height_delta:
			best_expected_height_delta = peak_expected_height_delta
			best_candidate = {
				"pedestrian_id": state.pedestrian_id,
				"expected_height_delta_m": peak_expected_height_delta,
				"peak_ground_error_m": peak_ground_error_m,
			}
	return best_candidate

func _sample_runtime_ground_height(config: CityWorldConfig, world_data: Dictionary, world_position: Vector3) -> float:
	var chunk_key := CityChunkKey.world_to_chunk_key(config, world_position)
	var chunk_payload := _build_chunk_payload(config, world_data, chunk_key)
	var profile := _get_runtime_ground_profile(config, world_data, chunk_key)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := Vector2(world_position.x - chunk_center.x, world_position.z - chunk_center.z)
	return CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile)

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
