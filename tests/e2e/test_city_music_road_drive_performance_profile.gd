extends SceneTree

const T := preload("res://tests/_test_util.gd")

const MANIFEST_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/landmark_manifest.json"
const MUSIC_ROAD_LANDMARK_ID := "landmark:v23:music_road:chunk_136_136"
const SEGMENT_COUNT := 12
const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 240
const LANDMARK_MOUNT_MAX_FRAMES := 240
const CAPTURE_TARGET_FRAME_COUNT := 1200
const MAX_CAPTURE_FRAMES := 1600
const DEFAULT_PROFILE_MODE := "first_visit"
const PROFILE_MODE_WARM := "warm"
const DEFAULT_DIAGNOSTICS_ENABLED := false
const DEFAULT_MUTE_NOTE_PLAYBACK := false
const DEFAULT_HIDE_KEY_VISUALS := false
const REPORT_ROOT_DIR := "res://reports/v23/music_road/performance"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for music road drive performance profile")
		return

	var args := _parse_cli_args(OS.get_cmdline_user_args())
	var profile_mode := str(args.get("profile_mode", DEFAULT_PROFILE_MODE))
	var diagnostics_enabled := bool(args.get("diagnostics_enabled", DEFAULT_DIAGNOSTICS_ENABLED))
	var mute_note_playback := bool(args.get("mute_note_playback", DEFAULT_MUTE_NOTE_PLAYBACK))
	var hide_key_visuals := bool(args.get("hide_key_visuals", DEFAULT_HIDE_KEY_VISUALS))
	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "Music road drive performance profile requires get_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "Music road drive performance profile requires reset_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "Music road drive performance profile requires get_streaming_snapshot()"):
		return
	if not T.require_true(self, world.has_method("get_music_road_runtime_state"), "Music road drive performance profile requires get_music_road_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Music road drive performance profile requires get_chunk_renderer()"):
		return
	if world.has_method("set_control_mode"):
		world.set_control_mode("player")
	if world.has_method("set_performance_diagnostics_enabled"):
		world.set_performance_diagnostics_enabled(diagnostics_enabled)

	var manifest := _load_json_dict(MANIFEST_PATH)
	if manifest.is_empty():
		T.fail_and_quit(self, "Music road drive performance profile requires a decodable landmark manifest")
		return
	var definition_path := str(manifest.get("music_road_definition_path", "")).strip_edges()
	var definition := _load_json_dict(definition_path)
	if definition.is_empty():
		T.fail_and_quit(self, "Music road drive performance profile requires a decodable music_road_definition")
		return

	var road_origin := _decode_vector3(manifest.get("world_position", null))
	var road_length_m := float(definition.get("road_length_m", 0.0))
	var target_speed_mps := float(definition.get("target_speed_mps", 0.0))
	var forward_direction := _resolve_forward_direction(float(manifest.get("yaw_rad", 0.0)))
	if not T.require_true(self, road_length_m > 0.0 and target_speed_mps > 0.0, "Music road drive performance profile requires road_length_m and target_speed_mps"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Music road drive performance profile requires player teleport support"):
		return
	if not T.require_true(self, player.has_method("enter_vehicle_drive_mode"), "Music road drive performance profile requires drive-mode entry support"):
		return
	var standing_height := _estimate_standing_height(player)
	var start_position := road_origin + Vector3.UP * standing_height - forward_direction * 6.0
	player.teleport_to_world_position(start_position)
	await process_frame
	world.update_streaming_for_position(player.global_position, 0.0)
	var mounted_landmark = await _wait_for_landmark_mount(world)
	if not T.require_true(self, mounted_landmark != null, "Music road drive performance profile requires the authored landmark to mount near the profiling start"):
		return
	if profile_mode == PROFILE_MODE_WARM:
		if not await _prime_music_road_corridor(world, player, road_origin, forward_direction, standing_height, road_length_m):
			T.fail_and_quit(self, "Music road warm drive performance profile could not stabilize the authored corridor before capture")
			return
		mounted_landmark = await _wait_for_landmark_mount(world)
		if mounted_landmark == null:
			T.fail_and_quit(self, "Music road warm drive performance profile lost the mounted landmark after warm priming")
			return
	if not _configure_landmark_debug_toggles(mounted_landmark, mute_note_playback, hide_key_visuals):
		T.fail_and_quit(self, "Music road drive performance profile could not configure landmark note playback mode")
		return

	player.teleport_to_world_position(start_position)
	await process_frame
	player.enter_vehicle_drive_mode({
		"vehicle_id": "veh:test:music_road_profile",
		"model_id": "sports_car_a",
		"heading": forward_direction,
		"world_position": road_origin - forward_direction * 6.0,
		"length_m": 4.4,
		"width_m": 1.9,
		"height_m": 1.6,
		"speed_mps": 0.0,
	})
	await process_frame
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "Music road drive performance profile could not reach a stable idle streaming window before capture")
		return

	world.reset_performance_profile()
	var report := await _capture_drive_profile(world, player, mounted_landmark, road_origin, forward_direction, standing_height, road_length_m, target_speed_mps, profile_mode, diagnostics_enabled, mute_note_playback, hide_key_visuals)
	if report.is_empty():
		T.fail_and_quit(self, "Music road drive performance profile capture returned an empty report")
		return

	var report_path := _write_report(report)
	var overall: Dictionary = report.get("overall", {})
	var completed_run: Dictionary = report.get("completed_run", {})
	var landmark_debug_state: Dictionary = report.get("landmark_debug_state", {})
	var note_player_state: Dictionary = landmark_debug_state.get("note_player", {})
	print("MUSIC_ROAD_DRIVE_PROFILE %s" % JSON.stringify({
		"profile_mode": report.get("profile_mode", DEFAULT_PROFILE_MODE),
		"diagnostics_enabled": report.get("diagnostics_enabled", DEFAULT_DIAGNOSTICS_ENABLED),
		"mute_note_playback": report.get("mute_note_playback", DEFAULT_MUTE_NOTE_PLAYBACK),
		"hide_key_visuals": report.get("hide_key_visuals", DEFAULT_HIDE_KEY_VISUALS),
		"display_backend": report.get("display_backend", ""),
		"report_path": report_path,
		"frame_count": int(overall.get("frame_count", 0)),
		"wall_frame_avg_usec": int(overall.get("wall_frame_avg_usec", 0)),
		"wall_frame_max_usec": int(overall.get("wall_frame_max_usec", 0)),
		"fps_avg": float(overall.get("fps_avg", 0.0)),
		"fps_min": float(overall.get("fps_min", 0.0)),
		"song_success": bool(completed_run.get("song_success", false)),
		"triggered_note_count": int(completed_run.get("triggered_note_count", 0)),
		"note_player_triggered_note_count": int(note_player_state.get("triggered_note_count", 0)),
		"played_note_count": int(note_player_state.get("played_note_count", 0)),
		"suppressed_note_count": int(note_player_state.get("suppressed_note_count", 0)),
	}))

	if not T.require_true(self, int(overall.get("frame_count", 0)) > 0, "Music road drive performance profile must capture at least one rendered frame"):
		return
	if not T.require_true(self, (report.get("segment_reports", []) as Array).size() == SEGMENT_COUNT, "Music road drive performance profile must emit the frozen segment count"):
		return
	if not T.require_true(self, float(overall.get("fps_avg", 0.0)) > 0.0, "Music road drive performance profile must compute a positive average FPS"):
		return
	if not T.require_true(self, note_player_state.has("active_voice_count") and note_player_state.has("peak_active_voice_count"), "Music road drive performance profile must expose active voice telemetry for dense-segment diagnosis"):
		return
	if not T.require_true(self, int(completed_run.get("triggered_note_count", 0)) > 0, "Music road drive performance profile must exercise note triggering during the traversal"):
		return
	if mute_note_playback:
		if not T.require_true(self, note_player_state.get("playback_enabled", true) == false, "Music road drive performance profile mute mode must disable landmark playback"):
			return
		if not T.require_true(self, int(note_player_state.get("triggered_note_count", 0)) > 0, "Music road drive performance profile mute mode must still forward triggered note events into the note player"):
			return
		if not T.require_true(self, int(note_player_state.get("played_note_count", 0)) == 0, "Music road drive performance profile mute mode must suppress audible note playback"):
			return
		if not T.require_true(self, int(note_player_state.get("suppressed_note_count", 0)) > 0, "Music road drive performance profile mute mode must expose suppressed note telemetry"):
			return
	else:
		if not T.require_true(self, int(note_player_state.get("played_note_count", 0)) > 0, "Music road drive performance profile audible mode must play notes during the traversal"):
			return
	if hide_key_visuals:
		if not T.require_true(self, landmark_debug_state.get("key_visuals_enabled", true) == false, "Music road drive performance profile hidden-key mode must disable the key visuals on the mounted landmark"):
			return
		if not T.require_true(self, int(landmark_debug_state.get("visible_key_instance_count", -1)) == 0, "Music road drive performance profile hidden-key mode must hide visible key instances during capture"):
			return
	if report_path == "":
		T.fail_and_quit(self, "Music road drive performance profile must persist a JSON report artifact")
		return

	world.queue_free()
	T.pass_and_quit(self)

func _parse_cli_args(args: PackedStringArray) -> Dictionary:
	var profile_mode := DEFAULT_PROFILE_MODE
	var diagnostics_enabled := DEFAULT_DIAGNOSTICS_ENABLED
	var mute_note_playback := DEFAULT_MUTE_NOTE_PLAYBACK
	var hide_key_visuals := DEFAULT_HIDE_KEY_VISUALS
	for arg in args:
		if arg.begins_with("--profile-mode="):
			var value := str(arg.substr("--profile-mode=".length())).strip_edges().to_lower()
			if value != "":
				profile_mode = value
		elif arg.begins_with("--diagnostics="):
			var value := str(arg.substr("--diagnostics=".length())).strip_edges().to_lower()
			diagnostics_enabled = value == "1" or value == "true" or value == "yes" or value == "on"
		elif arg.begins_with("--mute-note-playback="):
			var value := str(arg.substr("--mute-note-playback=".length())).strip_edges().to_lower()
			mute_note_playback = value == "1" or value == "true" or value == "yes" or value == "on"
		elif arg.begins_with("--hide-key-visuals="):
			var value := str(arg.substr("--hide-key-visuals=".length())).strip_edges().to_lower()
			hide_key_visuals = value == "1" or value == "true" or value == "yes" or value == "on"
	return {
		"profile_mode": profile_mode,
		"diagnostics_enabled": diagnostics_enabled,
		"mute_note_playback": mute_note_playback,
		"hide_key_visuals": hide_key_visuals,
	}

func _capture_drive_profile(world, player, mounted_landmark, road_origin: Vector3, forward_direction: Vector3, standing_height: float, road_length_m: float, target_speed_mps: float, profile_mode: String, diagnostics_enabled: bool, mute_note_playback: bool, hide_key_visuals: bool) -> Dictionary:
	var segment_reports: Array[Dictionary] = []
	for segment_index in range(SEGMENT_COUNT):
		var segment_start_m := road_length_m * float(segment_index) / float(SEGMENT_COUNT)
		var segment_end_m := road_length_m * float(segment_index + 1) / float(SEGMENT_COUNT)
		segment_reports.append({
			"segment_index": segment_index,
			"segment_start_m": segment_start_m,
			"segment_end_m": segment_end_m,
			"frame_count": 0,
			"wall_frame_total_usec": 0,
			"wall_frame_max_usec": 0,
			"wall_frame_min_usec": 0,
			"fps_sum": 0.0,
			"fps_max": 0.0,
			"fps_min": 0.0,
			"end_snapshot": {},
		})

	var overall_frame_samples: Array[int] = []
	var current_distance_m := -6.0
	var capture_step_m := maxf(road_length_m / float(CAPTURE_TARGET_FRAME_COUNT), 0.5)
	var frame_index := 0
	while current_distance_m < road_length_m + 8.0 and frame_index < MAX_CAPTURE_FRAMES:
		current_distance_m += capture_step_m
		var playback_position := road_origin + forward_direction * current_distance_m + Vector3.UP * standing_height
		player.teleport_to_world_position(playback_position)
		var frame_started_usec := Time.get_ticks_usec()
		await process_frame
		var frame_usec: int = maxi(Time.get_ticks_usec() - frame_started_usec, 1)
		overall_frame_samples.append(frame_usec)
		frame_index += 1
		var distance_ratio := clampf(current_distance_m / maxf(road_length_m, 0.0001), 0.0, 0.999999)
		var segment_index := mini(int(floor(distance_ratio * float(SEGMENT_COUNT))), SEGMENT_COUNT - 1)
		var segment: Dictionary = segment_reports[segment_index]
		_append_segment_frame(segment, frame_usec)
		var landmark_state := _capture_landmark_snapshot(mounted_landmark)
		segment["end_snapshot"] = _capture_runtime_snapshot(world, landmark_state, current_distance_m)
		segment_reports[segment_index] = segment

	var overall_profile: Dictionary = world.get_performance_profile()
	var runtime_state: Dictionary = world.get_music_road_runtime_state()
	var completed_run: Dictionary = runtime_state.get("last_completed_run", {})
	var landmark_state := _capture_landmark_snapshot(mounted_landmark)
	for segment_index in range(segment_reports.size()):
		var segment: Dictionary = segment_reports[segment_index]
		_finalize_segment(segment)
		if (segment.get("end_snapshot", {}) as Dictionary).is_empty():
			segment["end_snapshot"] = _capture_runtime_snapshot(world, landmark_state, float(segment.get("segment_end_m", 0.0)))
		segment_reports[segment_index] = segment
	return {
		"profile_mode": profile_mode,
		"diagnostics_enabled": diagnostics_enabled,
		"mute_note_playback": mute_note_playback,
		"hide_key_visuals": hide_key_visuals,
		"display_backend": DisplayServer.get_name(),
		"os_name": OS.get_name(),
		"road_length_m": road_length_m,
		"target_speed_mps": target_speed_mps,
		"frame_budget_fps": 60.0,
		"simulation_kind": "synthetic_drive_vehicle_teleport",
		"capture_step_m": capture_step_m,
		"overall": _build_overall_summary(overall_frame_samples, overall_profile),
		"completed_run": completed_run.duplicate(true),
		"performance_profile": overall_profile.duplicate(true),
		"landmark_debug_state": landmark_state,
		"segment_reports": segment_reports,
	}

func _configure_landmark_debug_toggles(mounted_landmark, mute_note_playback: bool, hide_key_visuals: bool) -> bool:
	if mounted_landmark == null:
		return false
	if not mounted_landmark.has_method("set_note_playback_enabled"):
		return false
	mounted_landmark.set_note_playback_enabled(not mute_note_playback)
	if not mounted_landmark.has_method("set_key_visuals_enabled"):
		return false
	mounted_landmark.set_key_visuals_enabled(not hide_key_visuals)
	return true

func _append_segment_frame(segment: Dictionary, frame_usec: int) -> void:
	var current_count := int(segment.get("frame_count", 0)) + 1
	var current_total := int(segment.get("wall_frame_total_usec", 0)) + frame_usec
	var current_max := maxi(int(segment.get("wall_frame_max_usec", 0)), frame_usec)
	var current_min := frame_usec
	if int(segment.get("frame_count", 0)) > 0:
		current_min = mini(int(segment.get("wall_frame_min_usec", frame_usec)), frame_usec)
	var fps := 1000000.0 / float(max(frame_usec, 1))
	var fps_max := maxf(float(segment.get("fps_max", 0.0)), fps)
	var fps_min := fps
	if int(segment.get("frame_count", 0)) > 0:
		fps_min = minf(float(segment.get("fps_min", fps)), fps)
	segment["frame_count"] = current_count
	segment["wall_frame_total_usec"] = current_total
	segment["wall_frame_max_usec"] = current_max
	segment["wall_frame_min_usec"] = current_min
	segment["fps_sum"] = float(segment.get("fps_sum", 0.0)) + fps
	segment["fps_max"] = fps_max
	segment["fps_min"] = fps_min

func _finalize_segment(segment: Dictionary) -> void:
	var frame_count := int(segment.get("frame_count", 0))
	if frame_count <= 0:
		segment["wall_frame_avg_usec"] = 0
		segment["fps_avg"] = 0.0
		return
	segment["wall_frame_avg_usec"] = int(round(float(segment.get("wall_frame_total_usec", 0)) / float(frame_count)))
	segment["fps_avg"] = float(segment.get("fps_sum", 0.0)) / float(frame_count)

func _build_overall_summary(frame_samples: Array[int], overall_profile: Dictionary) -> Dictionary:
	var total_usec := 0
	var max_usec := 0
	var min_usec := 0
	var fps_sum := 0.0
	var fps_min := 0.0
	var fps_max := 0.0
	for sample_index in range(frame_samples.size()):
		var frame_usec: int = maxi(frame_samples[sample_index], 1)
		total_usec += frame_usec
		max_usec = maxi(max_usec, frame_usec)
		min_usec = frame_usec if sample_index == 0 else mini(min_usec, frame_usec)
		var fps := 1000000.0 / float(frame_usec)
		fps_sum += fps
		fps_max = maxf(fps_max, fps)
		fps_min = fps if sample_index == 0 else minf(fps_min, fps)
	return {
		"frame_count": frame_samples.size(),
		"wall_frame_avg_usec": int(round(float(total_usec) / float(max(frame_samples.size(), 1)))),
		"wall_frame_max_usec": max_usec,
		"wall_frame_min_usec": min_usec,
		"fps_avg": fps_sum / float(max(frame_samples.size(), 1)),
		"fps_min": fps_min,
		"fps_max": fps_max,
		"update_streaming_avg_usec": int(overall_profile.get("update_streaming_avg_usec", 0)),
		"update_streaming_renderer_sync_avg_usec": int(overall_profile.get("update_streaming_renderer_sync_avg_usec", 0)),
		"crowd_update_avg_usec": int(overall_profile.get("crowd_update_avg_usec", 0)),
		"traffic_update_avg_usec": int(overall_profile.get("traffic_update_avg_usec", 0)),
		"crowd_active_state_count": int(overall_profile.get("crowd_active_state_count", 0)),
		"traffic_active_state_count": int(overall_profile.get("traffic_active_state_count", 0)),
	}

func _capture_runtime_snapshot(world, landmark_state: Dictionary, distance_m: float) -> Dictionary:
	var profile: Dictionary = world.get_performance_profile()
	var renderer_stats := {}
	var chunk_aggregate_stats := {
		"building_count_total": 0,
		"near_child_count_total": 0,
		"terrain_current_vertex_count_total": 0,
		"road_segment_count_total": 0,
	}
	if world.has_method("get_chunk_renderer"):
		var chunk_renderer = world.get_chunk_renderer()
		if chunk_renderer != null and chunk_renderer.has_method("get_renderer_stats"):
			renderer_stats = chunk_renderer.get_renderer_stats()
		if chunk_renderer != null and chunk_renderer.has_method("get_chunk_ids") and chunk_renderer.has_method("get_chunk_scene"):
			for chunk_id_variant in chunk_renderer.get_chunk_ids():
				var chunk_scene = chunk_renderer.get_chunk_scene(str(chunk_id_variant))
				var chunk_stats := {}
				if chunk_scene != null and chunk_scene.has_method("get_renderer_stats"):
					chunk_stats = chunk_scene.get_renderer_stats()
				chunk_aggregate_stats["building_count_total"] = int(chunk_aggregate_stats.get("building_count_total", 0)) + int(chunk_stats.get("building_count", 0))
				chunk_aggregate_stats["near_child_count_total"] = int(chunk_aggregate_stats.get("near_child_count_total", 0)) + int(chunk_stats.get("near_child_count", 0))
				chunk_aggregate_stats["terrain_current_vertex_count_total"] = int(chunk_aggregate_stats.get("terrain_current_vertex_count_total", 0)) + int(chunk_stats.get("terrain_current_vertex_count", 0))
				chunk_aggregate_stats["road_segment_count_total"] = int(chunk_aggregate_stats.get("road_segment_count_total", 0)) + int(chunk_stats.get("road_segment_count", 0))
	return {
		"distance_m": snappedf(distance_m, 0.01),
		"render_total_objects_in_frame": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"render_total_primitives_in_frame": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"render_total_draw_calls_in_frame": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"update_streaming_avg_usec": int(profile.get("update_streaming_avg_usec", 0)),
		"update_streaming_renderer_sync_avg_usec": int(profile.get("update_streaming_renderer_sync_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_avg_usec": int(profile.get("update_streaming_renderer_sync_queue_avg_usec", 0)),
		"update_streaming_renderer_sync_crowd_avg_usec": int(profile.get("update_streaming_renderer_sync_crowd_avg_usec", 0)),
		"update_streaming_renderer_sync_traffic_avg_usec": int(profile.get("update_streaming_renderer_sync_traffic_avg_usec", 0)),
		"crowd_update_avg_usec": int(profile.get("crowd_update_avg_usec", 0)),
		"traffic_update_avg_usec": int(profile.get("traffic_update_avg_usec", 0)),
		"crowd_active_state_count": int(profile.get("crowd_active_state_count", 0)),
		"traffic_active_state_count": int(profile.get("traffic_active_state_count", 0)),
		"ped_tier1_count": int(profile.get("ped_tier1_count", 0)),
		"veh_tier1_count": int(profile.get("veh_tier1_count", 0)),
		"active_rendered_chunk_count": int(renderer_stats.get("active_rendered_chunk_count", 0)),
		"multimesh_instance_total": int(renderer_stats.get("multimesh_instance_total", 0)),
		"pedestrian_multimesh_instance_total": int(renderer_stats.get("pedestrian_multimesh_instance_total", 0)),
		"vehicle_multimesh_instance_total": int(renderer_stats.get("vehicle_multimesh_instance_total", 0)),
		"building_count_total": int(chunk_aggregate_stats.get("building_count_total", 0)),
		"near_child_count_total": int(chunk_aggregate_stats.get("near_child_count_total", 0)),
		"terrain_current_vertex_count_total": int(chunk_aggregate_stats.get("terrain_current_vertex_count_total", 0)),
		"road_segment_count_total": int(chunk_aggregate_stats.get("road_segment_count_total", 0)),
		"road_render_mesh_instance_count_total": int((renderer_stats.get("road_runtime_guard_totals", {}) as Dictionary).get("render_mesh_instance_count_total", 0)),
		"road_render_multimesh_instance_count_total": int((renderer_stats.get("road_runtime_guard_totals", {}) as Dictionary).get("render_multimesh_instance_count_total", 0)),
		"lod_mode_counts": (renderer_stats.get("lod_mode_counts", {}) as Dictionary).duplicate(true),
		"visible_key_instance_count": int(landmark_state.get("visible_key_instance_count", 0)),
		"visual_instance_count": int(landmark_state.get("visual_instance_count", 0)),
		"render_backend": str(landmark_state.get("render_backend", "")),
		"note_player_active_voice_count": int((landmark_state.get("note_player", {}) as Dictionary).get("active_voice_count", 0)),
		"note_player_peak_active_voice_count": int((landmark_state.get("note_player", {}) as Dictionary).get("peak_active_voice_count", 0)),
		"last_completed_run": (landmark_state.get("last_completed_run", {}) as Dictionary).duplicate(true),
	}

func _capture_landmark_snapshot(mounted_landmark) -> Dictionary:
	if mounted_landmark == null or not mounted_landmark.has_method("get_music_road_debug_state"):
		return {}
	var debug_state: Dictionary = mounted_landmark.get_music_road_debug_state()
	var runtime_state: Dictionary = mounted_landmark.get_music_road_runtime_state() if mounted_landmark.has_method("get_music_road_runtime_state") else {}
	var note_player_state: Dictionary = runtime_state.get("note_player", {})
	debug_state["note_player"] = note_player_state.duplicate(true)
	return debug_state

func _wait_for_landmark_mount(world) -> Variant:
	for _frame_index in range(LANDMARK_MOUNT_MAX_FRAMES):
		await process_frame
		var chunk_renderer = world.get_chunk_renderer()
		if chunk_renderer != null and chunk_renderer.has_method("find_scene_landmark_node"):
			var mounted_landmark = chunk_renderer.find_scene_landmark_node(MUSIC_ROAD_LANDMARK_ID)
			if mounted_landmark != null:
				return mounted_landmark
	return null

func _prime_music_road_corridor(world, player, road_origin: Vector3, forward_direction: Vector3, standing_height: float, road_length_m: float) -> bool:
	var start_position := road_origin + Vector3.UP * standing_height - forward_direction * 24.0
	var end_position := road_origin + Vector3.UP * standing_height + forward_direction * (road_length_m + 24.0)
	player.teleport_to_world_position(start_position)
	await process_frame
	while not player.advance_toward_world_position(end_position, 28.0):
		await process_frame
	if not await _wait_for_streaming_idle(world):
		return false
	player.teleport_to_world_position(start_position)
	await process_frame
	return await _wait_for_streaming_idle(world)

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

func _write_report(report: Dictionary) -> String:
	var dir_path := ProjectSettings.globalize_path(REPORT_ROOT_DIR)
	if DirAccess.make_dir_recursive_absolute(dir_path) != OK:
		return ""
	var profile_mode := str(report.get("profile_mode", DEFAULT_PROFILE_MODE)).strip_edges().to_lower()
	var diagnostics_tag := "diag_on" if bool(report.get("diagnostics_enabled", false)) else "diag_off"
	var mute_tag := "mute_on" if bool(report.get("mute_note_playback", false)) else "mute_off"
	var key_visual_tag := "keys_off" if bool(report.get("hide_key_visuals", false)) else "keys_on"
	var backend_tag := str(report.get("display_backend", "unknown")).strip_edges().to_lower()
	var report_path := "%s/music_road_drive_profile_%s_%s_%s_%s_%s.json" % [dir_path, profile_mode, diagnostics_tag, mute_tag, key_visual_tag, backend_tag]
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(report, "\t"))
	file.flush()
	return report_path

func _load_json_dict(resource_path: String) -> Dictionary:
	if resource_path.strip_edges() == "":
		return {}
	var global_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(global_path):
		return {}
	var text := FileAccess.get_file_as_string(global_path)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return (parsed as Dictionary).duplicate(true)

func _estimate_standing_height(player) -> float:
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0

func _decode_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var payload: Dictionary = value
	return Vector3(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("z", 0.0))
	)

func _resolve_forward_direction(yaw_rad: float) -> Vector3:
	var forward := Vector3.BACK.rotated(Vector3.UP, yaw_rad)
	forward.y = 0.0
	return forward.normalized()
