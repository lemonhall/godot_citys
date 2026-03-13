extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REDLINE_USEC := 16667
const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 180
const STEP_DISTANCE_M := 32.0
const SAMPLE_COUNT := 48
const MIN_AVG_TIER1_COUNT := 180
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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for high-speed inspection performance")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "High-speed inspection performance needs CityPrototype.get_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "High-speed inspection performance needs CityPrototype.reset_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "High-speed inspection performance needs CityPrototype.get_streaming_snapshot()"):
		return
	if not T.require_true(self, world.has_method("set_control_mode"), "High-speed inspection performance needs CityPrototype.set_control_mode()"):
		return
	if not T.require_true(self, world.has_method("get_control_mode"), "High-speed inspection performance needs CityPrototype.get_control_mode()"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "High-speed inspection performance needs CityPrototype.get_pedestrian_runtime_snapshot()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "High-speed inspection performance requires Player node"):
		return
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "High-speed inspection performance requires Player.advance_toward_world_position()"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "High-speed inspection performance requires Player.teleport_to_world_position()"):
		return
	if not T.require_true(self, player.has_method("get_speed_profile"), "High-speed inspection performance requires Player.get_speed_profile()"):
		return
	if not T.require_true(self, player.has_method("get_walk_speed_mps"), "High-speed inspection performance requires Player.get_walk_speed_mps()"):
		return

	world.build_minimap_snapshot()
	world.build_minimap_snapshot()
	world.set_control_mode("inspection")
	if not T.require_true(self, world.get_control_mode() == "inspection", "Scenario must stay in inspection mode"):
		return
	if not T.require_true(self, player.get_speed_profile() == "inspection", "Player must switch into inspection speed profile for the high-speed scenario"):
		return
	if not T.require_true(self, float(player.get_walk_speed_mps()) >= 80.0, "Inspection profile must keep its fast-traversal walk speed"):
		return
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "High-speed inspection performance could not reach a stable idle streaming window before sampling")
		return
	var start_position: Vector3 = player.global_position
	if not await _prime_waypoint_corridor(world, player, start_position):
		T.fail_and_quit(self, "High-speed inspection performance could not stabilize the inspection corridor before sampling")
		return
	world.reset_performance_profile()

	var wall_frame_samples: Array[int] = []
	var tier1_samples: Array[int] = []
	var violent_counts: Array[int] = []
	var waypoint_index := 0
	var target_position := _resolve_target_position(player, WAYPOINTS[waypoint_index])
	for _step in range(SAMPLE_COUNT):
		if player.advance_toward_world_position(target_position, STEP_DISTANCE_M):
			waypoint_index = (waypoint_index + 1) % WAYPOINTS.size()
			target_position = _resolve_target_position(player, WAYPOINTS[waypoint_index])
		var frame_started := Time.get_ticks_usec()
		await process_frame
		var frame_usec := Time.get_ticks_usec() - frame_started
		wall_frame_samples.append(frame_usec)
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		tier1_samples.append(int(snapshot.get("tier1_count", 0)))
		violent_counts.append(_count_violent_reactions(snapshot))

	var profile: Dictionary = world.get_performance_profile()
	profile["wall_frame_avg_usec"] = _average_usec(wall_frame_samples)
	profile["wall_frame_max_usec"] = _max_usec(wall_frame_samples)
	profile["wall_frame_sample_count"] = wall_frame_samples.size()
	profile["scenario_avg_tier1_count"] = _average_int(tier1_samples)
	profile["scenario_max_violent_count"] = _max_int(violent_counts)
	profile["scenario_step_distance_m"] = STEP_DISTANCE_M
	profile["scenario_waypoint_count"] = WAYPOINTS.size()
	print("CITY_PEDESTRIAN_HIGH_SPEED_INSPECTION_REPORT %s" % JSON.stringify(profile))

	if not T.require_true(self, int(profile.get("wall_frame_avg_usec", 0)) <= REDLINE_USEC, "High-speed inspection traversal must keep average wall-frame time at or below the 16.67ms redline"):
		return
	if not T.require_true(self, int(profile.get("scenario_avg_tier1_count", 0)) >= MIN_AVG_TIER1_COUNT, "High-speed inspection traversal must keep a real lite crowd resident instead of profiling an empty corridor"):
		return
	if not T.require_true(self, int(profile.get("scenario_max_violent_count", 0)) == 0, "High-speed inspection traversal must not accidentally trigger panic/flee during a non-threatening inspection pass"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _resolve_target_position(player, waypoint: Vector3) -> Vector3:
	return Vector3(waypoint.x, player.global_position.y, waypoint.z)

func _count_violent_reactions(snapshot: Dictionary) -> int:
	var violent_count := 0
	for tier_key in ["tier1_states", "tier2_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			var state: Dictionary = state_variant
			var reaction_state := str(state.get("reaction_state", ""))
			if reaction_state == "panic" or reaction_state == "flee":
				violent_count += 1
	return violent_count

func _average_usec(samples: Array[int]) -> int:
	if samples.is_empty():
		return 0
	var total := 0
	for sample in samples:
		total += sample
	return int(round(float(total) / float(samples.size())))

func _average_int(samples: Array[int]) -> int:
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

func _max_int(samples: Array[int]) -> int:
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

func _prime_waypoint_corridor(world, player, start_position: Vector3) -> bool:
	var waypoint_index := 0
	var target_position := _resolve_target_position(player, WAYPOINTS[waypoint_index])
	for _step in range(SAMPLE_COUNT):
		if player.advance_toward_world_position(target_position, STEP_DISTANCE_M):
			waypoint_index = (waypoint_index + 1) % WAYPOINTS.size()
			target_position = _resolve_target_position(player, WAYPOINTS[waypoint_index])
		await process_frame
	if not await _wait_for_streaming_idle(world):
		return false
	player.teleport_to_world_position(start_position)
	world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
	return await _wait_for_streaming_idle(world)
