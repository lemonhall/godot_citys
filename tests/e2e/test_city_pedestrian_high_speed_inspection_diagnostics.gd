extends SceneTree

const T := preload("res://tests/_test_util.gd")

const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 180
const STEP_DISTANCE_M := 32.0
const SAMPLE_COUNT := 48
const REPORT_ROOT_DIR := "res://reports/v35/runtime_jitter/diagnostics"
const WAYPOINTS := [
	Vector3(-600.0, 1.1, 26.0),
	Vector3(0.0, 1.1, 26.0),
	Vector3(768.0, 1.1, 26.0),
	Vector3(1536.0, 1.1, 26.0),
	Vector3(1536.0, 1.1, 26.0),
	Vector3(768.0, 1.1, 26.0),
	Vector3(0.0, 1.1, 26.0),
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for high-speed inspection diagnostics")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "High-speed inspection diagnostics need get_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "High-speed inspection diagnostics need reset_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("set_performance_diagnostics_enabled"), "High-speed inspection diagnostics need set_performance_diagnostics_enabled()"):
		return
	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "High-speed inspection diagnostics need get_streaming_snapshot()"):
		return
	if not T.require_true(self, world.has_method("set_control_mode"), "High-speed inspection diagnostics need set_control_mode()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "High-speed inspection diagnostics require Player node"):
		return
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "High-speed inspection diagnostics require advance_toward_world_position()"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "High-speed inspection diagnostics require teleport_to_world_position()"):
		return

	world.build_minimap_snapshot()
	world.build_minimap_snapshot()
	world.set_control_mode("inspection")
	world.set_performance_diagnostics_enabled(true)
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "High-speed inspection diagnostics could not reach a stable idle streaming window before sampling")
		return
	var start_position: Vector3 = player.global_position
	if not await _prime_waypoint_corridor(world, player, start_position):
		T.fail_and_quit(self, "High-speed inspection diagnostics could not stabilize the corridor before sampling")
		return
	world.reset_performance_profile()

	var frame_records: Array[Dictionary] = []
	var waypoint_index := 0
	var target_position := _resolve_target_position(world, player, WAYPOINTS[waypoint_index])
	for step in range(SAMPLE_COUNT):
		if player.advance_toward_world_position(target_position, STEP_DISTANCE_M):
			waypoint_index = (waypoint_index + 1) % WAYPOINTS.size()
			target_position = _resolve_target_position(world, player, WAYPOINTS[waypoint_index])
		var frame_started_usec := Time.get_ticks_usec()
		await process_frame
		var frame_usec := Time.get_ticks_usec() - frame_started_usec
		var profile: Dictionary = world.get_performance_profile()
		var snapshot: Dictionary = world.get_streaming_snapshot()
		frame_records.append({
			"step": step,
			"frame_usec": frame_usec,
			"current_chunk_id": str(snapshot.get("current_chunk_id", "")),
			"active_chunk_count": int(snapshot.get("active_chunk_count", 0)),
			"update_streaming_last_usec": int(profile.get("update_streaming_last_usec", -1)),
			"renderer_sync_last_usec": int(profile.get("update_streaming_renderer_sync_last_usec", -1)),
			"renderer_sync_queue_last_usec": int(profile.get("update_streaming_renderer_sync_queue_last_usec", -1)),
			"renderer_sync_queue_prepare_last_usec": int(profile.get("update_streaming_renderer_sync_queue_prepare_last_usec", -1)),
			"renderer_sync_queue_mount_last_usec": int(profile.get("update_streaming_renderer_sync_queue_mount_last_usec", -1)),
			"frame_step_last_usec": int(profile.get("frame_step_last_usec", -1)),
			"hud_refresh_last_usec": int(profile.get("hud_refresh_last_usec", -1)),
			"minimap_build_last_usec": int(profile.get("minimap_build_last_usec", -1)),
			"minimap_request_count": int(profile.get("minimap_request_count", 0)),
			"minimap_rebuild_count": int(profile.get("minimap_rebuild_count", 0)),
			"crowd_assignment_decision": str(profile.get("crowd_assignment_decision", "")),
			"crowd_assignment_rebuild_reason": str(profile.get("crowd_assignment_rebuild_reason", "")),
			"crowd_assignment_player_velocity_mps": float(profile.get("crowd_assignment_player_velocity_mps", 0.0)),
			"crowd_assignment_raw_player_velocity_mps": float(profile.get("crowd_assignment_raw_player_velocity_mps", 0.0)),
		})

	var profile: Dictionary = world.get_performance_profile()
	var report := {
		"scenario": "inspection_high_speed_diagnostics",
		"display_backend": DisplayServer.get_name(),
		"os_name": OS.get_name(),
		"profile": profile.duplicate(true),
		"frame_records": frame_records,
		"top_frame_spikes": _top_frame_spikes(frame_records, 8),
	}
	var report_path := _write_report(report, "inspection_high_speed_diagnostics")
	print("CITY_PEDESTRIAN_HIGH_SPEED_DIAGNOSTICS %s" % JSON.stringify({
		"report_path": report_path,
		"display_backend": report.get("display_backend", ""),
		"wall_frame_avg_usec": int(profile.get("wall_frame_avg_usec", 0)),
		"renderer_sync_avg_usec": int(profile.get("update_streaming_renderer_sync_avg_usec", 0)),
		"hud_refresh_avg_usec": int(profile.get("hud_refresh_avg_usec", 0)),
		"minimap_build_avg_usec": int(profile.get("minimap_build_avg_usec", 0)),
		"top_frame_usec": int(((report.get("top_frame_spikes", []) as Array)[0] as Dictionary).get("frame_usec", 0)) if not (report.get("top_frame_spikes", []) as Array).is_empty() else 0,
	}))

	if not T.require_true(self, report_path != "", "High-speed inspection diagnostics must persist a JSON report artifact"):
		return
	for required_key in [
		"frame_step_last_usec",
		"hud_refresh_last_usec",
		"minimap_build_last_usec",
		"update_streaming_renderer_sync_queue_last_usec",
		"update_streaming_renderer_sync_queue_prepare_last_usec",
		"update_streaming_renderer_sync_queue_mount_last_usec",
	]:
		if not T.require_true(self, profile.has(required_key), "High-speed inspection diagnostics profile must expose %s" % required_key):
			return
	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_queue_sample_count", 0)) > 0, "High-speed inspection diagnostics must record renderer sync queue samples"):
		return
	if not T.require_true(self, int(profile.get("hud_refresh_sample_count", 0)) > 0, "High-speed inspection diagnostics must record HUD refresh samples"):
		return
	if not T.require_true(self, int(profile.get("minimap_request_count", 0)) > 0, "High-speed inspection diagnostics must record minimap requests"):
		return
	if DisplayServer.get_name() != "headless":
		if not T.require_true(
			self,
			int(profile.get("minimap_request_count", 0)) < int(profile.get("hud_refresh_sample_count", 0)),
			"Rendered high-speed inspection diagnostics must decouple minimap requests from every HUD refresh"
		):
			return
	if not T.require_true(self, frame_records.size() == SAMPLE_COUNT, "High-speed inspection diagnostics must capture every frame record"):
		return
	if not T.require_true(self, (report.get("top_frame_spikes", []) as Array).size() > 0, "High-speed inspection diagnostics must capture spike frames"):
		return
	if not T.require_true(
		self,
		_has_assignment_reason(frame_records, "inspection_farfield_throttle"),
		"High-speed inspection diagnostics must prove the inspection farfield throttle actually engages during stable traversal"
	):
		return

	world.set_performance_diagnostics_enabled(false)
	world.queue_free()
	T.pass_and_quit(self)

func _resolve_target_position(world, player, waypoint: Vector3) -> Vector3:
	return _resolve_grounded_position(world, player, waypoint)

func _top_frame_spikes(frame_records: Array[Dictionary], limit: int) -> Array[Dictionary]:
	var sorted_records := frame_records.duplicate(true)
	sorted_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("frame_usec", 0)) > int(b.get("frame_usec", 0))
	)
	var top_records: Array[Dictionary] = []
	for index in range(mini(limit, sorted_records.size())):
		top_records.append((sorted_records[index] as Dictionary).duplicate(true))
	return top_records

func _has_assignment_reason(frame_records: Array[Dictionary], reason: String) -> bool:
	for frame_record_variant in frame_records:
		var frame_record: Dictionary = frame_record_variant
		if str(frame_record.get("crowd_assignment_rebuild_reason", "")) == reason:
			return true
	return false

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

func _prime_waypoint_corridor(world, player, start_position: Vector3) -> bool:
	var waypoint_index := 0
	var target_position := _resolve_target_position(world, player, WAYPOINTS[waypoint_index])
	for _step in range(SAMPLE_COUNT):
		if player.advance_toward_world_position(target_position, STEP_DISTANCE_M):
			waypoint_index = (waypoint_index + 1) % WAYPOINTS.size()
			target_position = _resolve_target_position(world, player, WAYPOINTS[waypoint_index])
		await process_frame
	if not await _wait_for_streaming_idle(world):
		return false
	player.teleport_to_world_position(start_position)
	world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
	return await _wait_for_streaming_idle(world)

func _resolve_grounded_position(world, player, world_position: Vector3) -> Vector3:
	var standing_height := 1.0
	if player != null and player.has_method("_estimate_standing_height"):
		standing_height = float(player._estimate_standing_height())
	if world != null and world.has_method("_resolve_surface_world_position"):
		var grounded_position: Vector3 = world._resolve_surface_world_position(world_position, standing_height)
		return grounded_position + Vector3.UP * 0.05
	return Vector3(world_position.x, world_position.y + standing_height, world_position.z)

func _write_report(report: Dictionary, file_stem: String) -> String:
	var dir_path := ProjectSettings.globalize_path(REPORT_ROOT_DIR)
	if DirAccess.make_dir_recursive_absolute(dir_path) != OK:
		return ""
	var backend_tag := str(report.get("display_backend", "unknown")).strip_edges().to_lower()
	var report_path := "%s/%s_%s.json" % [dir_path, file_stem, backend_tag]
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(report, "\t"))
	file.flush()
	return report_path
