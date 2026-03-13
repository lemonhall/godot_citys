extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var warm_profile := await _run_profile("CITY_PEDESTRIAN_WARM", true, Vector3(768.0, 0.0, 26.0), 16.0)
	if warm_profile.is_empty():
		return
	if not T.require_true(self, int(warm_profile.get("wall_frame_avg_usec", 0)) <= 16667, "Pedestrian warm traversal must keep average wall-frame time at or below the 16.67ms redline"):
		return
	if not T.require_true(self, int(warm_profile.get("ped_tier1_count", 0)) >= 24, "Pedestrian warm traversal must raise ped_tier1_count to at least 24 instead of staying at the M6 sparse baseline"):
		return

	var first_visit_profile := await _run_profile("CITY_PEDESTRIAN_FIRST_VISIT", false, Vector3(2048.0, 0.0, 768.0), 24.0)
	if first_visit_profile.is_empty():
		return
	if not T.require_true(self, int(first_visit_profile.get("wall_frame_avg_usec", 0)) <= 16667, "Pedestrian first-visit traversal must keep average wall-frame time at or below the 16.67ms redline"):
		return
	if not T.require_true(self, int(first_visit_profile.get("ped_tier1_count", 0)) >= 52, "Pedestrian first-visit traversal must raise ped_tier1_count to at least 52 instead of staying at the M6 sparse baseline"):
		return

	T.pass_and_quit(self)

func _run_profile(report_prefix: String, warm_minimap: bool, target_world_position: Vector3, step_distance: float) -> Dictionary:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian performance profiling")
		return {}

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "CityPrototype must expose get_performance_profile() for pedestrian performance profiling"):
		return {}
	if not T.require_true(self, world.has_method("reset_performance_profile"), "CityPrototype must expose reset_performance_profile() for pedestrian performance profiling"):
		return {}

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Pedestrian performance profiling requires Player node"):
		return {}
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "PlayerController must support advance_toward_world_position() for pedestrian performance profiling"):
		return {}

	if warm_minimap:
		world.build_minimap_snapshot()
		world.build_minimap_snapshot()

	world.reset_performance_profile()
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var target_position := Vector3(target_world_position.x, player.global_position.y, target_world_position.z)
	var wall_frame_samples: Array[int] = []
	for step in range(48):
		player.advance_toward_world_position(target_position, step_distance)
		var frame_started := Time.get_ticks_usec()
		await process_frame
		var frame_usec := Time.get_ticks_usec() - frame_started
		wall_frame_samples.append(frame_usec)

	var profile: Dictionary = world.get_performance_profile()
	for required_key in [
		"pedestrian_mode",
		"crowd_update_avg_usec",
		"crowd_spawn_avg_usec",
		"crowd_render_commit_avg_usec",
		"crowd_active_state_count",
		"crowd_step_usec",
		"crowd_reaction_usec",
		"crowd_rank_usec",
		"crowd_snapshot_rebuild_usec",
		"crowd_chunk_commit_usec",
		"crowd_tier1_transform_writes",
		"ped_tier0_count",
		"ped_tier1_count",
		"ped_tier2_count",
		"ped_tier3_count",
		"ped_page_cache_hit_count",
		"ped_page_cache_miss_count",
	]:
		if not T.require_true(self, profile.has(required_key), "Pedestrian performance profile must expose %s" % required_key):
			world.queue_free()
			return {}

	profile["wall_frame_avg_usec"] = _average_usec(wall_frame_samples)
	profile["wall_frame_max_usec"] = _max_usec(wall_frame_samples)
	profile["wall_frame_sample_count"] = wall_frame_samples.size()
	print("%s_REPORT %s" % [report_prefix, JSON.stringify(profile)])

	if not T.require_true(self, str(profile.get("pedestrian_mode", "")) == "lite", "Pedestrian performance profiling must stay in lite mode"):
		world.queue_free()
		return {}
	if not T.require_true(self, int(profile.get("ped_tier0_count", 0)) + int(profile.get("ped_tier1_count", 0)) + int(profile.get("ped_tier2_count", 0)) + int(profile.get("ped_tier3_count", 0)) > 0, "Pedestrian performance profiling must keep real pedestrians active instead of zero-density placeholders"):
		world.queue_free()
		return {}

	world.queue_free()
	for _frame_index in range(4):
		await process_frame
	return profile

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
