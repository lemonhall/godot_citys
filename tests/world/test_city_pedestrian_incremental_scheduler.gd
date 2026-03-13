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
	streamer.update_for_world_position(origin)
	var active_entries: Array = streamer.get_active_chunk_entries()
	if not T.require_true(self, active_entries.size() > 0, "Incremental scheduler test requires at least one active chunk entry"):
		return

	var frame_delta := 1.0 / 60.0
	var first_summary: Dictionary = controller.update_active_chunks(active_entries, origin, frame_delta)
	var first_profile: Dictionary = first_summary.get("profile_stats", {})
	var second_summary: Dictionary = controller.update_active_chunks(active_entries, origin, frame_delta)
	var second_profile: Dictionary = second_summary.get("profile_stats", {})

	print("CITY_PEDESTRIAN_INCREMENTAL_SCHEDULER first=%s second=%s" % [
		JSON.stringify(first_profile),
		JSON.stringify(second_profile),
	])

	if not T.require_true(self, int(first_profile.get("crowd_active_state_count", 0)) > 0, "Incremental scheduler test requires active pedestrian states on the first update"):
		return
	if not T.require_true(self, int(first_profile.get("crowd_reaction_usec", 0)) > 0, "Initial crowd update must execute reaction work before incremental reuse can be validated"):
		return
	if not T.require_true(self, int(first_profile.get("crowd_rank_usec", 0)) > 0, "Initial crowd update must execute rank work before incremental reuse can be validated"):
		return
	if not T.require_true(self, int(first_profile.get("crowd_snapshot_rebuild_usec", 0)) > 0, "Initial crowd update must rebuild chunk snapshots before incremental reuse can be validated"):
		return
	if not T.require_true(self, int(second_profile.get("crowd_active_state_count", 0)) == int(first_profile.get("crowd_active_state_count", 0)), "Stable-frame incremental reuse must preserve active state counts"):
		return
	if not T.require_true(self, int(second_summary.get("tier1_count", -1)) == int(first_summary.get("tier1_count", -2)), "Stable-frame incremental reuse must preserve Tier 1 counts"):
		return
	if not T.require_true(self, int(second_summary.get("tier2_count", -1)) == int(first_summary.get("tier2_count", -2)), "Stable-frame incremental reuse must preserve Tier 2 counts"):
		return
	if not T.require_true(self, int(second_summary.get("tier3_count", -1)) == int(first_summary.get("tier3_count", -2)), "Stable-frame incremental reuse must preserve Tier 3 counts"):
		return
	if not T.require_true(self, int(second_profile.get("crowd_step_usec", 0)) >= 0, "Incremental scheduler test must keep crowd step profiling intact on continuous frames"):
		return
	if not T.require_true(self, int(second_profile.get("crowd_reaction_usec", -1)) == 0, "Stable-frame crowd updates must skip full reaction passes when no threat or player movement changed between continuous frames"):
		return
	if not T.require_true(self, int(second_profile.get("crowd_rank_usec", -1)) == 0, "Stable-frame crowd updates must skip full re-ranking when no threat or player movement changed between continuous frames"):
		return
	if not T.require_true(self, int(second_profile.get("crowd_snapshot_rebuild_usec", -1)) == 0, "Stable-frame crowd updates must skip chunk snapshot rebuilds when assignments are unchanged between continuous frames"):
		return

	T.pass_and_quit(self)
