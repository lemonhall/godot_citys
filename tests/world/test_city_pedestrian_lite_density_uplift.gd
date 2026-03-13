extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const WARM_TARGET_POSITION := Vector3(768.0, 0.0, 26.0)
const FIRST_VISIT_TARGET_POSITION := Vector3(2048.0, 0.0, 768.0)
const WARM_STEP_DISTANCE_M := 16.0
const FIRST_VISIT_STEP_DISTANCE_M := 24.0
const PROFILE_STEP_COUNT := 48

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var warm_snapshot := _run_profile_snapshot(WARM_TARGET_POSITION, WARM_STEP_DISTANCE_M)
	if warm_snapshot.is_empty():
		return
	print("CITY_PEDESTRIAN_LITE_DENSITY_WARM %s" % JSON.stringify(warm_snapshot))
	if not T.require_true(self, int(warm_snapshot.get("tier1_count", 0)) >= 24, "lite density uplift warm traversal must raise tier1_count to at least 24 instead of staying at the M6 sparse baseline"):
		return
	if not T.require_true(self, int(warm_snapshot.get("duplicate_page_load_count", 0)) == 0, "lite density uplift warm traversal must not introduce duplicate page loads"):
		return

	var first_visit_snapshot := _run_profile_snapshot(FIRST_VISIT_TARGET_POSITION, FIRST_VISIT_STEP_DISTANCE_M)
	if first_visit_snapshot.is_empty():
		return
	print("CITY_PEDESTRIAN_LITE_DENSITY_FIRST_VISIT %s" % JSON.stringify(first_visit_snapshot))
	if not T.require_true(self, int(first_visit_snapshot.get("tier1_count", 0)) >= 52, "lite density uplift first-visit traversal must raise tier1_count to at least 52 instead of staying at the M6 sparse baseline"):
		return
	if not T.require_true(self, int(first_visit_snapshot.get("duplicate_page_load_count", 0)) == 0, "lite density uplift first-visit traversal must not introduce duplicate page loads"):
		return
	if not T.require_true(self, int(first_visit_snapshot.get("tier3_count", 0)) <= int(first_visit_snapshot.get("tier3_budget", 24)), "lite density uplift must keep Tier 3 within the hard cap while density increases"):
		return

	T.pass_and_quit(self)

func _run_profile_snapshot(target_world_position: Vector3, step_distance_m: float) -> Dictionary:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)

	var current_position := Vector3.ZERO
	for _step in range(PROFILE_STEP_COUNT):
		current_position = current_position.move_toward(target_world_position, step_distance_m)
		streamer.update_for_world_position(current_position)
		controller.update_active_chunks(streamer.get_active_chunk_entries(), current_position, 1.0 / 60.0)
	return controller.get_global_snapshot()
