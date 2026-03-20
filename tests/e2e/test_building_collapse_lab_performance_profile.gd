extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/BuildingCollapseLab.tscn"
const REPORT_ROOT_DIR := "res://reports/v34/building_collapse/performance"
const PRE_SEGMENT_FRAMES := 96
const BURST_SEGMENT_FRAMES := 144
const SETTLE_SEGMENT_FRAMES := 144

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if scene == null:
		T.fail_and_quit(self, "Building collapse lab performance profile requires the dedicated lab scene")
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame

	if not T.require_true(self, lab.has_method("get_target_building_runtime"), "Lab performance profile requires get_target_building_runtime()"):
		return
	if not T.require_true(self, lab.has_method("reset_lab_state"), "Lab performance profile requires reset_lab_state()"):
		return

	var target_runtime = lab.call("get_target_building_runtime")
	if not T.require_true(self, target_runtime != null, "Lab performance profile requires the target building runtime"):
		return
	if not T.require_true(self, target_runtime.has_method("get_state"), "Lab performance profile requires target get_state()"):
		return
	if not T.require_true(self, target_runtime.has_method("get_debug_state"), "Lab performance profile requires target get_debug_state()"):
		return
	if not T.require_true(self, target_runtime.has_method("apply_damage"), "Lab performance profile requires target apply_damage()"):
		return
	if not T.require_true(self, target_runtime.has_method("get_primary_target_world_position"), "Lab performance profile requires a target aim point"):
		return

	var hit_world_position: Vector3 = target_runtime.get_primary_target_world_position() + Vector3.UP * 14.0
	var prepare_result: Dictionary = target_runtime.apply_damage(4100.0, hit_world_position)
	if not T.require_true(self, bool(prepare_result.get("accepted", false)), "Lab performance profile requires the fracture-prepare hit to be accepted"):
		return
	if not await _wait_for_damage_state(target_runtime, "collapse_ready", 240):
		T.fail_and_quit(self, "Lab performance profile could not reach collapse_ready before capture")
		return

	var pre_segment := await _capture_segment("pre_collapse", target_runtime, PRE_SEGMENT_FRAMES)
	var collapse_result: Dictionary = target_runtime.apply_damage(5600.0, hit_world_position)
	if not T.require_true(self, bool(collapse_result.get("accepted", false)), "Lab performance profile requires the collapse-trigger hit to be accepted"):
		return
	var burst_segment := await _capture_segment("collapse_burst", target_runtime, BURST_SEGMENT_FRAMES)
	var settle_segment := await _capture_segment("post_collapse_settle", target_runtime, SETTLE_SEGMENT_FRAMES)

	var report := {
		"scenario": "building_collapse_lab",
		"display_backend": DisplayServer.get_name(),
		"os_name": OS.get_name(),
		"segments": [pre_segment, burst_segment, settle_segment],
	}
	var report_path := _write_report(report, "building_collapse_lab_profile")
	print("BUILDING_COLLAPSE_LAB_PERFORMANCE_REPORT %s" % JSON.stringify({
		"report_path": report_path,
		"display_backend": report.get("display_backend", ""),
		"pre_wall_frame_avg_usec": int(pre_segment.get("wall_frame_avg_usec", 0)),
		"burst_wall_frame_avg_usec": int(burst_segment.get("wall_frame_avg_usec", 0)),
		"settle_wall_frame_avg_usec": int(settle_segment.get("wall_frame_avg_usec", 0)),
		"burst_dynamic_chunk_count": int(burst_segment.get("dynamic_chunk_count", -1)),
		"settle_dynamic_chunk_sleeping_count": int(settle_segment.get("dynamic_chunk_sleeping_count", -1)),
		"burst_draw_calls": int(burst_segment.get("render_total_draw_calls_in_frame", -1)),
	}))

	if not T.require_true(self, report_path != "", "Lab performance profile must persist a JSON report artifact"):
		return
	var segments: Array = report.get("segments", [])
	if not T.require_true(self, segments.size() == 3, "Lab performance profile must emit the frozen three segments"):
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
			"dynamic_chunk_mesh_instance_count",
			"dynamic_chunk_collision_shape_count",
			"dynamic_chunk_shadow_caster_count",
			"dynamic_chunk_peak_linear_speed_mps",
			"dynamic_chunk_total_linear_speed_mps",
			"dynamic_chunk_sleeping_ratio",
			"dynamic_chunk_airborne_count",
			"dynamic_chunk_sleeping_airborne_count",
		]:
			if not T.require_true(self, segment.has(required_key), "Lab performance profile segment must expose %s" % required_key):
				return
		if not T.require_true(self, int(segment.get("frame_count", 0)) > 0, "Lab performance profile segments must capture at least one frame"):
			return
		for required_int_key in [
			"dynamic_chunk_count",
			"dynamic_chunk_sleeping_count",
			"dynamic_chunk_mesh_instance_count",
			"dynamic_chunk_collision_shape_count",
			"dynamic_chunk_shadow_caster_count",
			"dynamic_chunk_airborne_count",
			"dynamic_chunk_sleeping_airborne_count",
		]:
			if not T.require_true(self, int(segment.get(required_int_key, -1)) >= 0, "Lab performance profile must provide a real %s value instead of a placeholder" % required_int_key):
				return
		for required_float_key in [
			"dynamic_chunk_peak_linear_speed_mps",
			"dynamic_chunk_total_linear_speed_mps",
			"dynamic_chunk_sleeping_ratio",
		]:
			if not T.require_true(self, float(segment.get(required_float_key, -1.0)) >= 0.0, "Lab performance profile must provide a real %s value instead of a placeholder" % required_float_key):
				return
	if not T.require_true(self, int(pre_segment.get("dynamic_chunk_count", -1)) == 0, "Pre-collapse segment must sample the intact/crack stage before debris spawns"):
		return
	if not T.require_true(self, int(burst_segment.get("dynamic_chunk_count", -1)) > 0, "Collapse burst segment must sample live debris chunks"):
		return
	if not T.require_true(self, int(settle_segment.get("dynamic_chunk_count", -1)) > 0, "Post-collapse settle segment must still sample residual debris before cleanup"):
		return
	if not T.require_true(self, int(burst_segment.get("dynamic_chunk_shadow_caster_count", -1)) == 0, "Debris chunks must not stay as one shadow-casting mesh each during the burst window"):
		return
	if not T.require_true(self, int(settle_segment.get("dynamic_chunk_shadow_caster_count", -1)) == 0, "Debris chunks must not keep per-chunk dynamic shadows during the settle window"):
		return

	lab.queue_free()
	T.pass_and_quit(self)

func _capture_segment(segment_name: String, target_runtime, frame_count: int) -> Dictionary:
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
	}

func _wait_for_damage_state(target_runtime, expected_state: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await process_frame
		var state: Dictionary = target_runtime.get_state()
		if str(state.get("damage_state", "")) == expected_state:
			return true
	return false

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
