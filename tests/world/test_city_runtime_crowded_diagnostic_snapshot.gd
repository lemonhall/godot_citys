extends SceneTree

const T := preload("res://tests/_test_util.gd")
const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 180

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for crowded runtime diagnostics")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "Crowded runtime diagnostics require get_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "Crowded runtime diagnostics require reset_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "Crowded runtime diagnostics require get_streaming_snapshot()"):
		return
	if not T.require_true(self, world.has_method("set_performance_diagnostics_enabled"), "Crowded runtime diagnostics require set_performance_diagnostics_enabled()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Crowded runtime diagnostics require Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "Crowded runtime diagnostics require teleport_to_world_position()"):
		return
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "Crowded runtime diagnostics require advance_toward_world_position()"):
		return

	world.build_minimap_snapshot()
	world.build_minimap_snapshot()
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "Crowded runtime diagnostics could not reach a stable idle streaming window before sampling")
		return

	var start_position: Vector3 = player.global_position
	var target_position := Vector3(768.0, player.global_position.y, 26.0)
	if not await _prime_warm_traversal(world, player, start_position, target_position, 16.0):
		T.fail_and_quit(self, "Crowded runtime diagnostics could not stabilize the warm traversal corridor before sampling")
		return

	world.set_performance_diagnostics_enabled(true)
	world.reset_performance_profile()
	var wall_frame_samples: Array[int] = []
	for step in range(48):
		player.advance_toward_world_position(target_position, 16.0)
		var frame_started := Time.get_ticks_usec()
		await process_frame
		var frame_usec := Time.get_ticks_usec() - frame_started
		wall_frame_samples.append(frame_usec)
		print("CITY_CROWDED_DIAG_FRAME step=%d frame_usec=%d" % [step, frame_usec])

	var profile: Dictionary = world.get_performance_profile()
	var report := {
		"wall_frame_avg_usec": _average_usec(wall_frame_samples),
		"wall_frame_max_usec": _max_usec(wall_frame_samples),
		"frame_step_avg_usec": int(profile.get("frame_step_avg_usec", 0)),
		"update_streaming_avg_usec": int(profile.get("update_streaming_avg_usec", 0)),
		"update_streaming_renderer_sync_avg_usec": int(profile.get("update_streaming_renderer_sync_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_avg_usec": int(profile.get("update_streaming_renderer_sync_queue_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_mount_avg_usec": int(profile.get("update_streaming_renderer_sync_queue_mount_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_prepare_avg_usec": int(profile.get("update_streaming_renderer_sync_queue_prepare_avg_usec", 0)),
		"update_streaming_renderer_sync_lod_avg_usec": int(profile.get("update_streaming_renderer_sync_lod_avg_usec", 0)),
		"update_streaming_renderer_sync_crowd_avg_usec": int(profile.get("update_streaming_renderer_sync_crowd_avg_usec", 0)),
		"update_streaming_renderer_sync_traffic_avg_usec": int(profile.get("update_streaming_renderer_sync_traffic_avg_usec", 0)),
		"crowd_update_avg_usec": int(profile.get("crowd_update_avg_usec", 0)),
		"crowd_spawn_avg_usec": int(profile.get("crowd_spawn_avg_usec", 0)),
		"crowd_render_commit_avg_usec": int(profile.get("crowd_render_commit_avg_usec", 0)),
		"crowd_snapshot_rebuild_usec": int(profile.get("crowd_snapshot_rebuild_usec", 0)),
		"crowd_chunk_commit_usec": int(profile.get("crowd_chunk_commit_usec", 0)),
		"traffic_update_avg_usec": int(profile.get("traffic_update_avg_usec", 0)),
		"traffic_spawn_avg_usec": int(profile.get("traffic_spawn_avg_usec", 0)),
		"traffic_render_commit_avg_usec": int(profile.get("traffic_render_commit_avg_usec", 0)),
		"traffic_snapshot_rebuild_usec": int(profile.get("traffic_snapshot_rebuild_usec", 0)),
		"traffic_chunk_commit_usec": int(profile.get("traffic_chunk_commit_usec", 0)),
		"ped_tier1_count": int(profile.get("ped_tier1_count", 0)),
		"ped_tier2_count": int(profile.get("ped_tier2_count", 0)),
		"ped_tier3_count": int(profile.get("ped_tier3_count", 0)),
		"veh_tier1_count": int(profile.get("veh_tier1_count", 0)),
		"veh_tier2_count": int(profile.get("veh_tier2_count", 0)),
		"veh_tier3_count": int(profile.get("veh_tier3_count", 0)),
		"crowd_assignment_decision": str(profile.get("crowd_assignment_decision", "")),
		"crowd_assignment_rebuild_reason": str(profile.get("crowd_assignment_rebuild_reason", "")),
	}
	print("CITY_CROWDED_DIAG_REPORT %s" % JSON.stringify(report))

	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_queue_sample_count", 0)) > 0, "Crowded runtime diagnostics must record queue subphase samples"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_crowd_sample_count", 0)) > 0, "Crowded runtime diagnostics must record crowd sync subphase samples"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_traffic_sample_count", 0)) > 0, "Crowded runtime diagnostics must record traffic sync subphase samples"):
		return

	world.set_performance_diagnostics_enabled(false)
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
