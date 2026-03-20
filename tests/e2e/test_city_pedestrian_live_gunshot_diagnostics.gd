extends SceneTree

const T := preload("res://tests/_test_util.gd")

const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 180
const SAMPLE_COUNT := 96
const REACTIVE_MIN_DISTANCE_M := 220.0
const REACTIVE_MAX_DISTANCE_M := 380.0
const CALM_MIN_DISTANCE_M := 420.0
const ORIGIN_CLEARANCE_M := 24.0
const SHOT_STEPS := [4, 36, 68]
const SEARCH_POSITIONS := [
	Vector3(300.0, 1.1, 26.0),
	Vector3(768.0, 1.1, 26.0),
	Vector3(1536.0, 1.1, 26.0),
	Vector3(2048.0, 1.1, 768.0),
	Vector3(-600.0, 1.1, 26.0),
	Vector3.ZERO,
]
const REPORT_ROOT_DIR := "res://reports/v35/runtime_jitter/diagnostics"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for live gunshot diagnostics")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "Live gunshot diagnostics need get_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "Live gunshot diagnostics need reset_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("set_performance_diagnostics_enabled"), "Live gunshot diagnostics need set_performance_diagnostics_enabled()"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "Live gunshot diagnostics need get_pedestrian_runtime_snapshot()"):
		return
	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "Live gunshot diagnostics need get_streaming_snapshot()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Live gunshot diagnostics require Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "Live gunshot diagnostics require teleport_to_world_position()"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "Live gunshot diagnostics require request_primary_fire()"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "Live gunshot diagnostics require set_weapon_mode()"):
		return

	var cluster := await _find_distance_ring_in_world(world, player)
	if not T.require_true(self, not cluster.is_empty(), "Live gunshot diagnostics need a sampled witness cluster"):
		return

	var origin_position: Vector3 = _resolve_grounded_position(world, player, cluster.get("origin_position", Vector3.ZERO))
	player.teleport_to_world_position(origin_position)
	player.set_weapon_mode("rifle")
	world.set_performance_diagnostics_enabled(true)
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame
	await _orient_player_to_target(player, origin_position + Vector3(36.0, 22.0, 0.0))
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "Live gunshot diagnostics could not reach a stable idle streaming window before sampling")
		return
	world.reset_performance_profile()

	var frame_records: Array[Dictionary] = []
	var shots_fired := 0
	for step in range(SAMPLE_COUNT):
		if SHOT_STEPS.has(step):
			if player.request_primary_fire():
				shots_fired += 1
		var frame_started_usec := Time.get_ticks_usec()
		await process_frame
		var frame_usec := Time.get_ticks_usec() - frame_started_usec
		var profile: Dictionary = world.get_performance_profile()
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		frame_records.append({
			"step": step,
			"frame_usec": frame_usec,
			"update_streaming_last_usec": int(profile.get("update_streaming_last_usec", -1)),
			"renderer_sync_last_usec": int(profile.get("update_streaming_renderer_sync_last_usec", -1)),
			"renderer_sync_queue_last_usec": int(profile.get("update_streaming_renderer_sync_queue_last_usec", -1)),
			"renderer_sync_crowd_last_usec": int(profile.get("update_streaming_renderer_sync_crowd_last_usec", -1)),
			"renderer_sync_traffic_last_usec": int(profile.get("update_streaming_renderer_sync_traffic_last_usec", -1)),
			"frame_step_last_usec": int(profile.get("frame_step_last_usec", -1)),
			"crowd_update_last_usec": int(profile.get("crowd_update_last_usec", -1)),
			"crowd_update_avg_usec": int(profile.get("crowd_update_avg_usec", 0)),
			"crowd_spawn_last_usec": int(profile.get("crowd_spawn_last_usec", -1)),
			"crowd_render_commit_last_usec": int(profile.get("crowd_render_commit_last_usec", -1)),
			"traffic_update_avg_usec": int(profile.get("traffic_update_avg_usec", 0)),
			"traffic_update_last_usec": int(profile.get("traffic_update_last_usec", -1)),
			"traffic_spawn_last_usec": int(profile.get("traffic_spawn_last_usec", -1)),
			"traffic_render_commit_last_usec": int(profile.get("traffic_render_commit_last_usec", -1)),
			"crowd_reaction_usec": int(profile.get("crowd_reaction_usec", 0)),
			"crowd_threat_broadcast_usec": int(profile.get("crowd_threat_broadcast_usec", 0)),
			"crowd_rank_usec": int(profile.get("crowd_rank_usec", 0)),
			"crowd_snapshot_rebuild_usec": int(profile.get("crowd_snapshot_rebuild_usec", 0)),
			"crowd_threat_candidate_count": int(profile.get("crowd_threat_candidate_count", 0)),
			"crowd_chunk_commit_usec": int(profile.get("crowd_chunk_commit_usec", 0)),
			"traffic_chunk_commit_usec": int(profile.get("traffic_chunk_commit_usec", 0)),
			"traffic_snapshot_rebuild_usec": int(profile.get("traffic_snapshot_rebuild_usec", 0)),
			"crowd_tier1_transform_writes": int(profile.get("crowd_tier1_transform_writes", 0)),
			"crowd_assignment_decision": str(profile.get("crowd_assignment_decision", "")),
			"crowd_assignment_rebuild_reason": str(profile.get("crowd_assignment_rebuild_reason", "")),
			"crowd_assignment_player_velocity_mps": float(profile.get("crowd_assignment_player_velocity_mps", 0.0)),
			"crowd_assignment_raw_player_velocity_mps": float(profile.get("crowd_assignment_raw_player_velocity_mps", 0.0)),
			"scenario_violent_count": _count_violent_reactions(snapshot),
		})

	var profile: Dictionary = world.get_performance_profile()
	var report := {
		"scenario": "live_gunshot_diagnostics",
		"display_backend": DisplayServer.get_name(),
		"os_name": OS.get_name(),
		"shots_fired": shots_fired,
		"profile": profile.duplicate(true),
		"frame_records": frame_records,
		"top_frame_spikes": _top_frame_spikes(frame_records, 8),
	}
	var report_path := _write_report(report, "live_gunshot_diagnostics")
	print("CITY_PEDESTRIAN_LIVE_GUNSHOT_DIAGNOSTICS %s" % JSON.stringify({
		"report_path": report_path,
		"display_backend": report.get("display_backend", ""),
		"wall_frame_avg_usec": int(profile.get("wall_frame_avg_usec", 0)),
		"frame_step_avg_usec": int(profile.get("frame_step_avg_usec", 0)),
		"crowd_update_avg_usec": int(profile.get("crowd_update_avg_usec", 0)),
		"renderer_sync_avg_usec": int(profile.get("update_streaming_renderer_sync_avg_usec", 0)),
		"shots_fired": shots_fired,
	}))

	if not T.require_true(self, report_path != "", "Live gunshot diagnostics must persist a JSON report artifact"):
		return
	for required_key in [
		"frame_step_last_usec",
		"hud_refresh_last_usec",
		"minimap_build_last_usec",
		"update_streaming_renderer_sync_queue_last_usec",
		"crowd_update_last_usec",
		"crowd_spawn_last_usec",
		"crowd_render_commit_last_usec",
		"traffic_update_last_usec",
		"traffic_spawn_last_usec",
		"traffic_render_commit_last_usec",
	]:
		if not T.require_true(self, profile.has(required_key), "Live gunshot diagnostics profile must expose %s" % required_key):
			return
	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_queue_sample_count", 0)) > 0, "Live gunshot diagnostics must record renderer sync queue samples"):
		return
	if not T.require_true(self, shots_fired >= 3, "Live gunshot diagnostics must fire the scenario weapon multiple times"):
		return
	if not T.require_true(self, _count_rebuild_reason(frame_records, "interval_elapsed") <= 3, "Live gunshot diagnostics must not keep forcing interval-based assignment rebuilds while the player is stationary"):
		return
	if not T.require_true(self, frame_records.size() == SAMPLE_COUNT, "Live gunshot diagnostics must capture every frame record"):
		return
	if not T.require_true(self, (report.get("top_frame_spikes", []) as Array).size() > 0, "Live gunshot diagnostics must capture spike frames"):
		return

	world.set_performance_diagnostics_enabled(false)
	world.queue_free()
	T.pass_and_quit(self)

func _find_distance_ring_in_world(world, player) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var player_position := _resolve_grounded_position(world, player, search_position_variant)
		player.teleport_to_world_position(player_position)
		world.update_streaming_for_position(player_position, 0.25)
		await process_frame
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var cluster := _pick_distance_ring(snapshot, player_position)
		if not cluster.is_empty():
			return cluster
	return {}

func _pick_distance_ring(snapshot: Dictionary, player_position: Vector3) -> Dictionary:
	var event_position := player_position
	var states := _collect_states(snapshot)
	if _nearest_distance_to_states(states, event_position) <= ORIGIN_CLEARANCE_M:
		return {}
	var reactive_candidate := {}
	var far_candidate := {}
	for state_variant in states:
		var state: Dictionary = state_variant
		if not _is_calm_state(state):
			continue
		var distance_m := event_position.distance_to(state.get("world_position", Vector3.ZERO))
		if reactive_candidate.is_empty() and distance_m >= REACTIVE_MIN_DISTANCE_M and distance_m <= REACTIVE_MAX_DISTANCE_M and _is_expected_mid_ring_responder(state):
			reactive_candidate = state
		elif far_candidate.is_empty() and distance_m >= CALM_MIN_DISTANCE_M:
			far_candidate = state
		if not reactive_candidate.is_empty() and not far_candidate.is_empty():
			break
	if reactive_candidate.is_empty() or far_candidate.is_empty():
		return {}
	return {
		"origin_position": player_position,
		"reactive_id": str(reactive_candidate.get("pedestrian_id", "")),
		"far_id": str(far_candidate.get("pedestrian_id", "")),
	}

func _collect_states(snapshot: Dictionary) -> Array:
	var states: Array = []
	for tier_key in ["tier2_states", "tier1_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			states.append(state_variant)
	return states

func _nearest_distance_to_states(states: Array, event_position: Vector3) -> float:
	var nearest_distance := INF
	for state_variant in states:
		var state: Dictionary = state_variant
		var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
		nearest_distance = minf(nearest_distance, event_position.distance_to(world_position))
	return nearest_distance

func _is_calm_state(state: Dictionary) -> bool:
	if str(state.get("life_state", "alive")) != "alive":
		return false
	return str(state.get("reaction_state", "none")) == "none"

func _is_expected_mid_ring_responder(state: Dictionary) -> bool:
	return posmod(int(state.get("seed", 0)), 10) < 4

func _count_violent_reactions(snapshot: Dictionary) -> int:
	var violent_count := 0
	for tier_key in ["tier1_states", "tier2_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			var state: Dictionary = state_variant
			var reaction_state := str(state.get("reaction_state", ""))
			if reaction_state == "panic" or reaction_state == "flee":
				violent_count += 1
	return violent_count

func _top_frame_spikes(frame_records: Array[Dictionary], limit: int) -> Array[Dictionary]:
	var sorted_records := frame_records.duplicate(true)
	sorted_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("frame_usec", 0)) > int(b.get("frame_usec", 0))
	)
	var top_records: Array[Dictionary] = []
	for index in range(mini(limit, sorted_records.size())):
		top_records.append((sorted_records[index] as Dictionary).duplicate(true))
	return top_records

func _count_rebuild_reason(frame_records: Array[Dictionary], reason: String) -> int:
	var count := 0
	for record_variant in frame_records:
		var record: Dictionary = record_variant
		if str(record.get("crowd_assignment_rebuild_reason", "")) == reason:
			count += 1
	return count

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

func _resolve_grounded_position(world, player, world_position: Vector3) -> Vector3:
	var standing_height := 1.0
	if player != null and player.has_method("_estimate_standing_height"):
		standing_height = float(player._estimate_standing_height())
	if world != null and world.has_method("_resolve_surface_world_position"):
		var grounded_position: Vector3 = world._resolve_surface_world_position(world_position, standing_height)
		return grounded_position + Vector3.UP * 0.05
	return Vector3(world_position.x, world_position.y + standing_height, world_position.z)
