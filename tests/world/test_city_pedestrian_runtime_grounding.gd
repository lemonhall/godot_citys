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
	var sampled_states: Array = []
	for probe_chunk_key in probe_chunk_keys:
		pedestrian_streamer.sync_active_chunks([{
			"chunk_id": config.format_chunk_id(probe_chunk_key),
			"chunk_key": probe_chunk_key,
		}])
		var active_states: Array = pedestrian_streamer.get_active_states()
		if active_states.is_empty():
			continue
		sampled_states = active_states.slice(0, mini(active_states.size(), 12))
		if not sampled_states.is_empty():
			break

	if not T.require_true(self, not sampled_states.is_empty(), "Flat-ground runtime grounding test requires at least one active pedestrian state"):
		return

	var peak_abs_ground_y := 0.0
	var peak_abs_state_y := 0.0
	var peak_ground_error_m := 0.0
	for state in sampled_states:
		var runtime_ground_y := _sample_runtime_ground_height(config, world_data, state.world_position)
		peak_abs_ground_y = maxf(peak_abs_ground_y, absf(runtime_ground_y))
		peak_abs_state_y = maxf(peak_abs_state_y, absf(state.world_position.y))
		peak_ground_error_m = maxf(peak_ground_error_m, absf(runtime_ground_y - state.world_position.y))
		for _step_index in range(6):
			state.queue_step(0.2)
			state.step(state.flush_queued_step())
			pedestrian_streamer.ground_state(state)
			runtime_ground_y = _sample_runtime_ground_height(config, world_data, state.world_position)
			peak_abs_ground_y = maxf(peak_abs_ground_y, absf(runtime_ground_y))
			peak_abs_state_y = maxf(peak_abs_state_y, absf(state.world_position.y))
			peak_ground_error_m = maxf(peak_ground_error_m, absf(runtime_ground_y - state.world_position.y))

	if not T.require_true(self, peak_abs_ground_y <= 0.05, "Flat-ground runtime must keep pedestrian ground close to y=0 across active sidewalk updates"):
		return
	if not T.require_true(self, peak_abs_state_y <= 0.05, "Flat-ground runtime must keep pedestrian world_position.y close to the shared y=0 plane"):
		return
	if not T.require_true(self, peak_ground_error_m <= 0.05, "Pedestrian height must stay glued to flat runtime ground"):
		return

	print("CITY_PEDESTRIAN_RUNTIME_GROUNDING %s" % JSON.stringify({
		"sampled_state_count": sampled_states.size(),
		"peak_abs_ground_y": peak_abs_ground_y,
		"peak_abs_state_y": peak_abs_state_y,
		"peak_ground_error_m": peak_ground_error_m,
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
