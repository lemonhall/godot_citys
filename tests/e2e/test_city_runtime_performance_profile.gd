extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for runtime profiling")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "CityPrototype must expose get_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "CityPrototype must expose reset_performance_profile()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for runtime profiling"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must support teleport_to_world_position() for runtime profiling"):
		return
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "PlayerController must support advance_toward_world_position() for runtime profiling movement"):
		return

	world.build_minimap_snapshot()
	world.build_minimap_snapshot()
	world.reset_performance_profile()
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var target_position := Vector3(768.0, player.global_position.y, 26.0)
	var wall_frame_samples: Array[int] = []
	for step in range(48):
		player.advance_toward_world_position(target_position, 16.0)
		var frame_started := Time.get_ticks_usec()
		await process_frame
		var frame_usec := Time.get_ticks_usec() - frame_started
		wall_frame_samples.append(frame_usec)
		print("CITY_PROFILE_FRAME step=%d frame_usec=%d" % [step, frame_usec])

	var profile: Dictionary = world.get_performance_profile()
	profile["wall_frame_avg_usec"] = _average_usec(wall_frame_samples)
	profile["wall_frame_max_usec"] = _max_usec(wall_frame_samples)
	profile["wall_frame_sample_count"] = wall_frame_samples.size()
	print("CITY_PROFILE_REPORT %s" % JSON.stringify(profile))

	if not T.require_true(self, int(profile.get("world_generation_usec", 0)) > 0, "Performance profile must include startup world generation time"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_sample_count", 0)) > 0, "Performance profile must include update_streaming samples"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_max_usec", 0)) > 0, "Performance profile must include update_streaming max usec"):
		return
	if not T.require_true(self, int(profile.get("frame_step_sample_count", 0)) > 0, "Performance profile must include frame step samples during movement"):
		return
	if not T.require_true(self, int(profile.get("wall_frame_sample_count", 0)) > 0, "Runtime profiling test must collect wall-clock frame samples during movement"):
		return
	if not T.require_true(self, int(profile.get("minimap_request_count", 0)) > 0, "Performance profile must include minimap request counts"):
		return
	if not T.require_true(self, int(profile.get("streaming_mount_setup_max_usec", 0)) > 0, "Performance profile must include streaming mount setup maxima"):
		return
	if not T.require_true(self, int(profile.get("streaming_terrain_async_dispatch_sample_count", 0)) > 0, "Performance profile must include terrain async dispatch samples"):
		return
	if not T.require_true(self, int(profile.get("streaming_terrain_async_complete_sample_count", 0)) > 0, "Performance profile must include completed terrain async samples"):
		return
	if not T.require_true(self, int(profile.get("streaming_terrain_commit_sample_count", 0)) > 0, "Performance profile must include terrain commit samples"):
		return
	for required_key in [
		"crowd_active_state_count",
		"crowd_step_usec",
		"crowd_reaction_usec",
		"crowd_rank_usec",
		"crowd_snapshot_rebuild_usec",
		"crowd_chunk_commit_usec",
		"crowd_tier1_transform_writes",
	]:
		if not T.require_true(self, profile.has(required_key), "Runtime performance profile must expose %s" % required_key):
			return
	if not T.require_true(self, int(profile.get("streaming_mount_setup_avg_usec", 0)) <= 16000, "M3 runtime profile must keep mount setup average at or below 16000 usec"):
		return
	if not T.require_true(self, int(profile.get("wall_frame_avg_usec", 0)) <= 16667, "Warm traversal must keep average wall-frame time at or below the 16.67ms redline"):
		return
	if not T.require_true(self, int(profile.get("ped_tier1_count", 0)) >= 24, "Warm runtime profile must raise ped_tier1_count to at least 24 instead of staying at the M6 sparse baseline"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _average_usec(samples: Array[int]) -> int:
	if samples.is_empty():
		return 0
	var total := 0
	for sample in samples:
		total += sample
	return int(round(float(total) / float(samples.size())))

func _max_usec(samples: Array[int]) -> int:
	var current_max := 0
	for sample in samples:
		current_max = maxi(current_max, sample)
	return current_max
