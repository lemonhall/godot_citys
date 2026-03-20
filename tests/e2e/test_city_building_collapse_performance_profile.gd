extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REPORT_ROOT_DIR := "res://reports/v34/building_collapse/performance"
const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 240
const PRE_SEGMENT_FRAMES := 96
const BURST_SEGMENT_FRAMES := 144
const SETTLE_SEGMENT_FRAMES := 144

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Main-world building collapse performance profile requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "Main-world collapse performance profile requires get_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "Main-world collapse performance profile requires reset_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "Main-world collapse performance profile requires get_streaming_snapshot()"):
		return
	if not T.require_true(self, world.has_method("set_performance_diagnostics_enabled"), "Main-world collapse performance profile requires set_performance_diagnostics_enabled()"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Main-world collapse performance profile requires get_chunk_renderer()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Main-world collapse performance profile requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "Main-world collapse performance profile requires player teleport support"):
		return

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")
	world.set_performance_diagnostics_enabled(true)

	var target_runtime = await _await_target_runtime(player)
	if not T.require_true(self, target_runtime != null, "Main-world collapse performance profile requires a near destructible building runtime"):
		return
	if not T.require_true(self, target_runtime.has_method("get_state"), "Main-world collapse performance profile requires target get_state()"):
		return
	if not T.require_true(self, target_runtime.has_method("get_debug_state"), "Main-world collapse performance profile requires target get_debug_state()"):
		return
	if not T.require_true(self, target_runtime.has_method("apply_damage"), "Main-world collapse performance profile requires target apply_damage()"):
		return
	if not T.require_true(self, target_runtime.has_method("get_primary_target_world_position"), "Main-world collapse performance profile requires a target aim point"):
		return

	var target_world_position: Vector3 = target_runtime.get_primary_target_world_position()
	var camera_anchor := Vector3(target_world_position.x - 32.0, player.global_position.y, target_world_position.z - 32.0)
	player.teleport_to_world_position(camera_anchor)
	await process_frame
	world.update_streaming_for_position(player.global_position, 0.0)
	await _orient_player_to_target(player, target_world_position + Vector3.UP * 14.0)
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "Main-world collapse performance profile could not reach a stable idle streaming window before capture")
		return

	var hit_world_position: Vector3 = target_world_position + Vector3.UP * 14.0
	var prepare_result: Dictionary = target_runtime.apply_damage(4100.0, hit_world_position)
	if not T.require_true(self, bool(prepare_result.get("accepted", false)), "Main-world collapse performance profile requires the fracture-prepare hit to be accepted"):
		return
	if not await _wait_for_damage_state(target_runtime, "collapse_ready", 240):
		T.fail_and_quit(self, "Main-world collapse performance profile could not reach collapse_ready before capture")
		return
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "Main-world collapse performance profile could not re-stabilize after fracture preparation")
		return

	var pre_segment := await _capture_segment("pre_collapse", world, target_runtime, PRE_SEGMENT_FRAMES)
	var collapse_result: Dictionary = target_runtime.apply_damage(5600.0, hit_world_position)
	if not T.require_true(self, bool(collapse_result.get("accepted", false)), "Main-world collapse performance profile requires the collapse-trigger hit to be accepted"):
		return
	var burst_segment := await _capture_segment("collapse_burst", world, target_runtime, BURST_SEGMENT_FRAMES)
	var settle_segment := await _capture_segment("post_collapse_settle", world, target_runtime, SETTLE_SEGMENT_FRAMES)

	var report := {
		"scenario": "city_building_collapse_main_world",
		"display_backend": DisplayServer.get_name(),
		"os_name": OS.get_name(),
		"segments": [pre_segment, burst_segment, settle_segment],
	}
	var report_path := _write_report(report, "city_building_collapse_profile")
	print("CITY_BUILDING_COLLAPSE_PERFORMANCE_REPORT %s" % JSON.stringify({
		"report_path": report_path,
		"display_backend": report.get("display_backend", ""),
		"pre_wall_frame_avg_usec": int(pre_segment.get("wall_frame_avg_usec", 0)),
		"burst_wall_frame_avg_usec": int(burst_segment.get("wall_frame_avg_usec", 0)),
		"settle_wall_frame_avg_usec": int(settle_segment.get("wall_frame_avg_usec", 0)),
		"burst_update_streaming_avg_usec": int(burst_segment.get("update_streaming_avg_usec", 0)),
		"burst_dynamic_chunk_count": int(burst_segment.get("dynamic_chunk_count", -1)),
		"settle_sleeping_ratio": float(settle_segment.get("dynamic_chunk_sleeping_ratio", -1.0)),
	}))

	if not T.require_true(self, report_path != "", "Main-world collapse performance profile must persist a JSON report artifact"):
		return
	var segments: Array = report.get("segments", [])
	if not T.require_true(self, segments.size() == 3, "Main-world collapse performance profile must emit the frozen three segments"):
		return
	for segment_variant in segments:
		var segment: Dictionary = segment_variant
		for required_key in [
			"segment_name",
			"frame_count",
			"wall_frame_avg_usec",
			"wall_frame_max_usec",
			"fps_avg",
			"fps_min",
			"render_total_draw_calls_in_frame",
			"render_total_objects_in_frame",
			"dynamic_chunk_count",
			"dynamic_chunk_sleeping_count",
			"dynamic_chunk_shadow_caster_count",
			"dynamic_chunk_sleeping_ratio",
			"dynamic_chunk_airborne_count",
			"dynamic_chunk_sleeping_airborne_count",
			"update_streaming_avg_usec",
			"update_streaming_renderer_sync_avg_usec",
			"crowd_update_avg_usec",
			"traffic_update_avg_usec",
			"active_rendered_chunk_count",
			"multimesh_instance_total",
		]:
			if not T.require_true(self, segment.has(required_key), "Main-world collapse performance segment must expose %s" % required_key):
				return
		if not T.require_true(self, int(segment.get("frame_count", 0)) > 0, "Main-world collapse performance segments must capture at least one frame"):
			return
		for required_int_key in [
			"dynamic_chunk_count",
			"dynamic_chunk_sleeping_count",
			"dynamic_chunk_shadow_caster_count",
			"dynamic_chunk_airborne_count",
			"dynamic_chunk_sleeping_airborne_count",
		]:
			if not T.require_true(self, int(segment.get(required_int_key, -1)) >= 0, "Main-world collapse performance profile must provide a real %s value instead of a placeholder" % required_int_key):
				return
		for required_float_key in [
			"dynamic_chunk_peak_linear_speed_mps",
			"dynamic_chunk_total_linear_speed_mps",
			"dynamic_chunk_sleeping_ratio",
		]:
			if not T.require_true(self, float(segment.get(required_float_key, -1.0)) >= 0.0, "Main-world collapse performance profile must provide a real %s value instead of a placeholder" % required_float_key):
				return
	if not T.require_true(self, int(pre_segment.get("dynamic_chunk_count", -1)) == 0, "Main-world pre-collapse segment must sample the intact/crack stage before debris spawns"):
		return
	if not T.require_true(self, int(burst_segment.get("dynamic_chunk_count", -1)) > 0, "Main-world collapse burst segment must sample live debris chunks"):
		return
	if not T.require_true(self, int(settle_segment.get("dynamic_chunk_count", -1)) > 0, "Main-world post-collapse settle segment must still sample residual debris before cleanup"):
		return
	if not T.require_true(self, int(burst_segment.get("dynamic_chunk_shadow_caster_count", -1)) == 0, "Main-world debris chunks must not stay as one shadow-casting mesh each during the burst window"):
		return
	if not T.require_true(self, int(settle_segment.get("dynamic_chunk_shadow_caster_count", -1)) == 0, "Main-world debris chunks must not keep per-chunk dynamic shadows during the settle window"):
		return

	world.set_performance_diagnostics_enabled(false)
	world.queue_free()
	T.pass_and_quit(self)

func _capture_segment(segment_name: String, world, target_runtime, frame_count: int) -> Dictionary:
	world.reset_performance_profile()
	var frame_samples: Array[int] = []
	var last_draw_calls := 0
	var last_objects := 0
	var last_primitives := 0
	var fps_sum := 0.0
	var fps_min := 0.0
	var fps_max := 0.0
	for frame_index in range(frame_count):
		var frame_started_usec := Time.get_ticks_usec()
		await process_frame
		var frame_usec := maxi(Time.get_ticks_usec() - frame_started_usec, 1)
		frame_samples.append(frame_usec)
		var fps := 1000000.0 / float(frame_usec)
		fps_sum += fps
		fps_min = fps if frame_index == 0 else minf(fps_min, fps)
		fps_max = fps if frame_index == 0 else maxf(fps_max, fps)
		last_draw_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		last_objects = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		last_primitives = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var debug_state: Dictionary = target_runtime.get_debug_state()
	var state: Dictionary = target_runtime.get_state()
	var profile: Dictionary = world.get_performance_profile()
	var renderer_stats := {}
	var chunk_renderer = world.get_chunk_renderer()
	if chunk_renderer != null and chunk_renderer.has_method("get_renderer_stats"):
		renderer_stats = chunk_renderer.get_renderer_stats()
	return {
		"segment_name": segment_name,
		"frame_count": frame_samples.size(),
		"wall_frame_avg_usec": _average_usec(frame_samples),
		"wall_frame_max_usec": _max_usec(frame_samples),
		"wall_frame_min_usec": _min_usec(frame_samples),
		"fps_avg": fps_sum / float(max(frame_samples.size(), 1)),
		"fps_min": fps_min,
		"fps_max": fps_max,
		"render_total_draw_calls_in_frame": last_draw_calls,
		"render_total_objects_in_frame": last_objects,
		"render_total_primitives_in_frame": last_primitives,
		"damage_state": str(state.get("damage_state", "")),
		"dynamic_chunk_count": int(debug_state.get("dynamic_chunk_count", -1)),
		"dynamic_chunk_sleeping_count": int(debug_state.get("dynamic_chunk_sleeping_count", -1)),
		"dynamic_chunk_mesh_instance_count": int(debug_state.get("dynamic_chunk_mesh_instance_count", -1)),
		"dynamic_chunk_collision_shape_count": int(debug_state.get("dynamic_chunk_collision_shape_count", -1)),
		"dynamic_chunk_shadow_caster_count": int(debug_state.get("dynamic_chunk_shadow_caster_count", -1)),
		"dynamic_chunk_peak_linear_speed_mps": float(debug_state.get("dynamic_chunk_peak_linear_speed_mps", -1.0)),
		"dynamic_chunk_total_linear_speed_mps": float(debug_state.get("dynamic_chunk_total_linear_speed_mps", -1.0)),
		"dynamic_chunk_sleeping_ratio": float(debug_state.get("dynamic_chunk_sleeping_ratio", -1.0)),
		"dynamic_chunk_airborne_count": int(debug_state.get("dynamic_chunk_airborne_count", -1)),
		"dynamic_chunk_sleeping_airborne_count": int(debug_state.get("dynamic_chunk_sleeping_airborne_count", -1)),
		"update_streaming_avg_usec": int(profile.get("update_streaming_avg_usec", 0)),
		"update_streaming_renderer_sync_avg_usec": int(profile.get("update_streaming_renderer_sync_avg_usec", 0)),
		"crowd_update_avg_usec": int(profile.get("crowd_update_avg_usec", 0)),
		"traffic_update_avg_usec": int(profile.get("traffic_update_avg_usec", 0)),
		"active_rendered_chunk_count": int(renderer_stats.get("active_rendered_chunk_count", 0)),
		"multimesh_instance_total": int(renderer_stats.get("multimesh_instance_total", 0)),
	}

func _await_target_runtime(player) -> Variant:
	if player == null:
		return null
	for _frame in range(240):
		await process_frame
		var best_runtime = _find_nearest_destructible_runtime(player)
		if best_runtime != null:
			return best_runtime
	return null

func _find_nearest_destructible_runtime(player) -> Variant:
	var nearest_runtime = null
	var nearest_distance := INF
	for runtime_variant in get_nodes_in_group("city_destructible_building"):
		var runtime_node := runtime_variant as Node3D
		if runtime_node == null or not is_instance_valid(runtime_node):
			continue
		if not runtime_node.has_method("get_primary_target_world_position"):
			continue
		var target_world_position: Vector3 = runtime_node.get_primary_target_world_position()
		var distance_m: float = player.global_position.distance_to(target_world_position)
		if distance_m < nearest_distance:
			nearest_distance = distance_m
			nearest_runtime = runtime_node
	return nearest_runtime

func _wait_for_damage_state(target_runtime, expected_state: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await process_frame
		var state: Dictionary = target_runtime.get_state()
		if str(state.get("damage_state", "")) == expected_state:
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

func _orient_player_to_target(player, target_world_position: Vector3) -> void:
	var planar_target := Vector3(target_world_position.x, player.global_position.y, target_world_position.z)
	player.look_at(planar_target, Vector3.UP)
	await process_frame
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if camera_rig == null:
		return
	var aim_origin: Vector3 = camera.global_position if camera != null else player.global_position + Vector3.UP * 1.6
	var to_target: Vector3 = target_world_position - aim_origin
	var planar_length := Vector2(to_target.x, to_target.z).length()
	if planar_length <= 0.0001:
		return
	camera_rig.rotation.x = clampf(atan2(to_target.y, planar_length), deg_to_rad(-68.0), deg_to_rad(35.0))
	await process_frame

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

func _min_usec(samples: Array[int]) -> int:
	if samples.is_empty():
		return 0
	var current_min := samples[0]
	for sample in samples:
		current_min = mini(current_min, sample)
	return current_min

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
