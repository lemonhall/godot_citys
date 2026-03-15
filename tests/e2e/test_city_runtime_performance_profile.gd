extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CURRENT_LITE_WARM_TIER1_MIN := 150
const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 180

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
	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "CityPrototype must expose get_streaming_snapshot()"):
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
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "Runtime profiling could not reach a stable idle streaming window before sampling")
		return
	var start_position: Vector3 = player.global_position
	var target_position := Vector3(768.0, player.global_position.y, 26.0)
	if not await _prime_warm_traversal(world, player, start_position, target_position, 16.0):
		T.fail_and_quit(self, "Runtime profiling could not stabilize the warm traversal corridor before sampling")
		return
	world.reset_performance_profile()
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
	if not T.require_true(self, profile.has("streaming_terrain_async_dispatch_sample_count"), "Performance profile must include terrain async dispatch sample field"):
		return
	if not T.require_true(self, profile.has("streaming_terrain_async_complete_sample_count"), "Performance profile must include terrain async completion sample field"):
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
	if not T.require_true(self, int(profile.get("wall_frame_avg_usec", 0)) <= 11000, "M4 warm runtime profile must keep average wall-frame time at or below 11000 usec"):
		return
	if not T.require_true(self, int(profile.get("streaming_mount_setup_avg_usec", 0)) <= 5500, "M4 warm runtime profile must keep mount setup average at or below 5500 usec"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_avg_usec", 0)) <= 10000, "M4 warm runtime profile must keep update_streaming average at or below 10000 usec"):
		return
	if not T.require_true(self, int(profile.get("wall_frame_avg_usec", 0)) <= 16667, "Warm traversal must keep average wall-frame time at or below the 16.67ms redline"):
		return
	if not T.require_true(self, int(profile.get("ped_tier1_count", 0)) >= CURRENT_LITE_WARM_TIER1_MIN, "Warm runtime profile must keep ped_tier1_count at or above the frozen lite warm runtime baseline"):
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
