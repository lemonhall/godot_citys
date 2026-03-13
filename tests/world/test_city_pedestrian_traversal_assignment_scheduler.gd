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

	var frame_delta := 1.0 / 60.0
	streamer.update_for_world_position(Vector3.ZERO)
	var current_chunk_key: Vector2i = streamer.get_current_chunk_key()
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_size := float(config.chunk_size_m)
	var origin := Vector3(
		bounds.position.x + (float(current_chunk_key.x) + 0.5) * chunk_size,
		0.0,
		bounds.position.y + (float(current_chunk_key.y) + 0.5) * chunk_size
	)
	streamer.update_for_world_position(origin)
	var origin_entries: Array = streamer.get_active_chunk_entries()
	if not T.require_true(self, origin_entries.size() > 0, "Traversal assignment scheduler test requires origin active chunk entries"):
		return

	var first_summary: Dictionary = controller.update_active_chunks(origin_entries, origin, frame_delta)
	if not T.require_true(self, int(first_summary.get("tier2_count", -1)) == 0 and int(first_summary.get("tier3_count", -1)) == 0, "Traversal assignment scheduler test requires a farfield-only origin frame"):
		return

	var max_reaction_usec := 0
	var max_rank_usec := 0
	var max_snapshot_rebuild_usec := 0
	var last_profile := {}
	for move_index in range(6):
		var moved_position := origin + Vector3(6.0 * float(move_index + 1), 0.0, 0.0)
		streamer.update_for_world_position(moved_position)
		var moved_entries: Array = streamer.get_active_chunk_entries()
		if not T.require_true(self, _same_chunk_ids(origin_entries, moved_entries), "Traversal assignment scheduler test requires same-window movement across the farfield throttle horizon"):
			return
		var moved_summary: Dictionary = controller.update_active_chunks(moved_entries, moved_position, frame_delta)
		var moved_profile: Dictionary = moved_summary.get("profile_stats", {})
		last_profile = moved_profile.duplicate(true)
		max_reaction_usec = maxi(max_reaction_usec, int(moved_profile.get("crowd_reaction_usec", 0)))
		max_rank_usec = maxi(max_rank_usec, int(moved_profile.get("crowd_rank_usec", 0)))
		max_snapshot_rebuild_usec = maxi(max_snapshot_rebuild_usec, int(moved_profile.get("crowd_snapshot_rebuild_usec", 0)))

	print("CITY_PEDESTRIAN_TRAVERSAL_ASSIGNMENT_SCHEDULER first=%s last=%s max_reaction=%d max_rank=%d max_snapshot=%d" % [
		JSON.stringify(first_summary),
		JSON.stringify(last_profile),
		max_reaction_usec,
		max_rank_usec,
		max_snapshot_rebuild_usec,
	])

	if not T.require_true(self, int((last_profile as Dictionary).get("crowd_active_state_count", 0)) > 0, "Traversal assignment scheduler test requires active crowd states after movement"):
		return
	if not T.require_true(self, max_reaction_usec == 0, "Farfield same-window traversal must skip reaction passes across multiple small movements when no threat or nearfield state emerged"):
		return
	if not T.require_true(self, max_rank_usec == 0, "Farfield same-window traversal must skip re-ranking across multiple small movements when the active window is unchanged"):
		return
	if not T.require_true(self, max_snapshot_rebuild_usec == 0, "Farfield same-window traversal must skip snapshot rebuild across multiple small movements when the active window is unchanged"):
		return

	T.pass_and_quit(self)

func _same_chunk_ids(lhs_entries: Array, rhs_entries: Array) -> bool:
	var lhs_ids := _chunk_ids_for_entries(lhs_entries)
	var rhs_ids := _chunk_ids_for_entries(rhs_entries)
	lhs_ids.sort()
	rhs_ids.sort()
	if lhs_ids.size() != rhs_ids.size():
		return false
	for item_index in range(lhs_ids.size()):
		if lhs_ids[item_index] != rhs_ids[item_index]:
			return false
	return true

func _chunk_ids_for_entries(entries: Array) -> Array[String]:
	var ids: Array[String] = []
	for entry_variant in entries:
		ids.append(str((entry_variant as Dictionary).get("chunk_id", "")))
	return ids
