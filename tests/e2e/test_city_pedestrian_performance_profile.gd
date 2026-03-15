extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CURRENT_LITE_WARM_TIER1_MIN := 150
const CURRENT_LITE_FIRST_VISIT_TIER1_MIN := 220
const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 180

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var warm_profile := await _run_profile("CITY_PEDESTRIAN_WARM", true, Vector3(768.0, 0.0, 26.0), 16.0)
	if warm_profile.is_empty():
		return
	if not T.require_true(self, int(warm_profile.get("wall_frame_avg_usec", 0)) <= 16667, "Pedestrian warm traversal must keep average wall-frame time at or below the 16.67ms redline"):
		return
	if not T.require_true(self, int(warm_profile.get("ped_tier1_count", 0)) >= CURRENT_LITE_WARM_TIER1_MIN, "Pedestrian warm traversal must keep ped_tier1_count at or above the frozen lite warm runtime baseline"):
		return

	var first_visit_profile := await _run_profile("CITY_PEDESTRIAN_FIRST_VISIT", false, Vector3(2048.0, 0.0, 768.0), 24.0)
	if first_visit_profile.is_empty():
		return
	if not T.require_true(self, int(first_visit_profile.get("wall_frame_avg_usec", 0)) <= 16667, "Pedestrian first-visit traversal must keep average wall-frame time at or below the 16.67ms redline"):
		return
	if not T.require_true(self, int(first_visit_profile.get("ped_tier1_count", 0)) >= CURRENT_LITE_FIRST_VISIT_TIER1_MIN, "Pedestrian first-visit traversal must keep ped_tier1_count at or above the frozen lite first-visit runtime baseline"):
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
	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "CityPrototype must expose get_streaming_snapshot() for pedestrian performance profiling"):
		return {}

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Pedestrian performance profiling requires Player node"):
		return {}
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "PlayerController must support advance_toward_world_position() for pedestrian performance profiling"):
		return {}
	if warm_minimap and not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must support teleport_to_world_position() for warm pedestrian performance profiling"):
		return {}

	if warm_minimap:
		world.build_minimap_snapshot()
		world.build_minimap_snapshot()

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "Pedestrian performance profiling could not reach a stable idle streaming window before sampling")
		world.queue_free()
		return {}

	var target_position := Vector3(target_world_position.x, player.global_position.y, target_world_position.z)
	var start_position: Vector3 = player.global_position
	if warm_minimap:
		if not await _prime_warm_traversal(world, player, start_position, target_position, step_distance):
			T.fail_and_quit(self, "Pedestrian warm profiling could not stabilize the warm traversal corridor before sampling")
			world.queue_free()
			return {}
	world.reset_performance_profile()
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

func _wait_for_streaming_idle(world) -> bool:
	var idle_frames := 0
	for _frame_index in range(STREAMING_IDLE_MAX_FRAMES):
		await process_frame
		var snapshot: Dictionary = world.get_streaming_snapshot()
		var pending_total := (
			int(snapshot.get("pending_prepare_count", 0))
			+ int(snapshot.get("pending_surface_async_count", 0))
			+ int(snapshot.get("queued_surface_async_count", 0))
			+ int(snapshot.get("pending_terrain_async_count", 0))
			+ int(snapshot.get("queued_terrain_async_count", 0))
			+ int(snapshot.get("pending_mount_count", 0))
			+ int(snapshot.get("pending_retire_count", 0))
		)
		if pending_total == 0:
			idle_frames += 1
			if idle_frames >= STREAMING_IDLE_STABLE_FRAMES:
				return true
		else:
			idle_frames = 0
	return false

func _prime_warm_traversal(world, player, start_position: Vector3, target_position: Vector3, step_distance: float) -> bool:
	for _step in range(48):
		player.advance_toward_world_position(target_position, step_distance)
		await process_frame
	if not await _wait_for_streaming_idle(world):
		return false
	player.teleport_to_world_position(start_position)
	world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
	return await _wait_for_streaming_idle(world)
