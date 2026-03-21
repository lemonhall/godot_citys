extends SceneTree

const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const WARM_TARGET_POSITION := Vector3(768.0, 0.0, 26.0)
const FIRST_VISIT_TARGET_POSITION := Vector3(2048.0, 0.0, 768.0)
const WARM_STEP_DISTANCE_M := 16.0
const FIRST_VISIT_STEP_DISTANCE_M := 24.0
const PROFILE_STEP_COUNT := 48
const STEP_DISTANCE_M := 32.0
const SAMPLE_COUNT := 48
const INSPECTION_WAYPOINTS := [
	Vector3(-600.0, 1.1, 26.0),
	Vector3(0.0, 1.1, 26.0),
	Vector3(768.0, 1.1, 26.0),
	Vector3(1536.0, 1.1, 26.0),
	Vector3(1536.0, 1.1, 26.0),
	Vector3(768.0, 1.1, 26.0),
	Vector3(0.0, 1.1, 26.0),
]
const CANDIDATES := [
	{"local": 0.140, "arterial": 0.500},
	{"local": 0.145, "arterial": 0.500},
	{"local": 0.150, "arterial": 0.500},
	{"local": 0.155, "arterial": 0.500},
	{"local": 0.140, "arterial": 0.560},
	{"local": 0.145, "arterial": 0.560},
	{"local": 0.150, "arterial": 0.560},
	{"local": 0.155, "arterial": 0.560},
	{"local": 0.140, "arterial": 0.600},
	{"local": 0.145, "arterial": 0.600},
	{"local": 0.150, "arterial": 0.600},
	{"local": 0.155, "arterial": 0.600},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for candidate_variant in CANDIDATES:
		var candidate: Dictionary = candidate_variant
		var config := CityWorldConfig.new()
		var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
		var query = world_data.get("pedestrian_query")
		if query == null:
			continue
		if query.get("_pedestrian_config") == null:
			continue
		query._pedestrian_config.road_class_density["local"] = float(candidate.get("local", 0.14))
		query._pedestrian_config.road_class_density["arterial"] = float(candidate.get("arterial", 0.5))

		var warm_snapshot := _run_profile_snapshot(config, world_data, WARM_TARGET_POSITION, WARM_STEP_DISTANCE_M)
		var first_visit_snapshot := _run_profile_snapshot(config, world_data, FIRST_VISIT_TARGET_POSITION, FIRST_VISIT_STEP_DISTANCE_M)
		var inspection_summary := _run_inspection_snapshot(config, world_data)
		print(JSON.stringify({
			"local": float(candidate.get("local", 0.14)),
			"arterial": float(candidate.get("arterial", 0.5)),
			"warm_tier1": int(warm_snapshot.get("tier1_count", 0)),
			"warm_active": int(warm_snapshot.get("active_state_count", 0)),
			"first_tier1": int(first_visit_snapshot.get("tier1_count", 0)),
			"first_active": int(first_visit_snapshot.get("active_state_count", 0)),
			"first_tier2": int(first_visit_snapshot.get("tier2_count", 0)),
			"inspection_avg_tier1": int(inspection_summary.get("scenario_avg_tier1_count", 0)),
			"inspection_last_tier1": int(inspection_summary.get("tier1_count", 0)),
			"inspection_active": int(inspection_summary.get("active_state_count", 0)),
		}))
	quit()

func _run_profile_snapshot(config, world_data: Dictionary, target_world_position: Vector3, step_distance_m: float) -> Dictionary:
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)
	var current_position := Vector3.ZERO
	for _step in range(PROFILE_STEP_COUNT):
		current_position = current_position.move_toward(target_world_position, step_distance_m)
		streamer.update_for_world_position(current_position)
		controller.set_player_context(current_position, Vector3.ZERO, {})
		controller.update_active_chunks(streamer.get_active_chunk_entries(), current_position, 1.0 / 60.0)
	return controller.get_global_snapshot()

func _run_inspection_snapshot(config, world_data: Dictionary) -> Dictionary:
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)
	var current_position := INSPECTION_WAYPOINTS[0]
	var waypoint_index := 0
	var target_position: Vector3 = INSPECTION_WAYPOINTS[waypoint_index]
	var tier1_samples: Array[int] = []
	var last_position := current_position
	for _step in range(SAMPLE_COUNT):
		current_position = current_position.move_toward(target_position, STEP_DISTANCE_M)
		if current_position.distance_to(target_position) <= 0.001:
			waypoint_index = (waypoint_index + 1) % INSPECTION_WAYPOINTS.size()
			target_position = INSPECTION_WAYPOINTS[waypoint_index]
		var velocity := (current_position - last_position) / (1.0 / 60.0)
		last_position = current_position
		streamer.update_for_world_position(current_position)
		controller.set_player_context(current_position, velocity, {
			"control_mode": "inspection",
			"speed_profile": "inspection",
			"max_context_speed_mps": 180.0,
		})
		controller.update_active_chunks(streamer.get_active_chunk_entries(), current_position, 1.0 / 60.0)
		var snapshot: Dictionary = controller.get_global_snapshot()
		tier1_samples.append(int(snapshot.get("tier1_count", 0)))
	var summary := controller.get_global_snapshot().duplicate(true)
	summary["scenario_avg_tier1_count"] = _average_int(tier1_samples)
	return summary

func _average_int(samples: Array[int]) -> int:
	if samples.is_empty():
		return 0
	var total := 0
	for sample in samples:
		total += sample
	return int(round(float(total) / float(samples.size())))
