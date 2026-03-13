extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)

	var origin := Vector3.ZERO
	var frame_delta := 1.0 / 60.0
	streamer.update_for_world_position(origin)
	var active_entries: Array = streamer.get_active_chunk_entries()
	if not T.require_true(self, active_entries.size() > 0, "Step scheduler test requires at least one active chunk entry"):
		return

	controller.update_active_chunks(active_entries, origin, frame_delta)
	var second_summary: Dictionary = controller.update_active_chunks(active_entries, origin, frame_delta)
	var second_profile: Dictionary = second_summary.get("profile_stats", {})

	var due_summary := {}
	var due_profile := {}
	var max_due_step_usec := 0
	for _frame_index in range(8):
		due_summary = controller.update_active_chunks(active_entries, origin, frame_delta)
		due_profile = (due_summary.get("profile_stats", {}) as Dictionary).duplicate(true)
		max_due_step_usec = maxi(max_due_step_usec, int(due_profile.get("crowd_step_usec", 0)))

	print("CITY_PEDESTRIAN_STEP_SCHEDULER second_summary=%s second=%s due_summary=%s due=%s" % [
		JSON.stringify(second_summary),
		JSON.stringify(second_profile),
		JSON.stringify(due_summary),
		JSON.stringify(due_profile),
	])

	if not T.require_true(self, int(second_profile.get("crowd_active_state_count", 0)) > 0, "Step scheduler test requires active pedestrian states"):
		return
	if not T.require_true(self, int(second_summary.get("tier2_count", -1)) == 0 and int(second_summary.get("tier3_count", -1)) == 0, "Step scheduler origin probe expects a pure Tier 1/Tier 0 frame without reactive nearfield states"):
		return
	if not T.require_true(self, int(second_profile.get("crowd_step_usec", -1)) == 0, "Tier 1/Tier 0 scheduler must skip step work on sub-interval frames instead of scanning all active states every frame"):
		return
	if not T.require_true(self, max_due_step_usec > 0, "Tier 1/Tier 0 scheduler must still execute deferred step work once the interval budget is reached"):
		return

	T.pass_and_quit(self)
