extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REDLINE_USEC := 16667
const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 180
const SAMPLE_COUNT := 96
const MIN_TIER1_COUNT := 160
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

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for live gunshot performance")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "Live gunshot performance needs CityPrototype.get_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "Live gunshot performance needs CityPrototype.reset_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "Live gunshot performance needs CityPrototype.get_pedestrian_runtime_snapshot()"):
		return
	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "Live gunshot performance needs CityPrototype.get_streaming_snapshot()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Live gunshot performance requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "Live gunshot performance requires Player.teleport_to_world_position()"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "Live gunshot performance requires Player.request_primary_fire()"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "Live gunshot performance requires Player.set_weapon_mode()"):
		return

	var cluster := await _find_distance_ring_in_world(world, player)
	if not T.require_true(self, not cluster.is_empty(), "Live gunshot performance needs a sampled witness in the 200m-400m ring plus a calm outsider beyond 400m"):
		return

	var origin_position: Vector3 = cluster.get("origin_position", Vector3.ZERO)
	player.teleport_to_world_position(origin_position)
	player.set_weapon_mode("rifle")
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame
	await _orient_player_to_target(player, origin_position + Vector3(36.0, 22.0, 0.0))
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "Live gunshot performance could not reach a stable idle streaming window before sampling")
		return
	world.reset_performance_profile()

	var wall_frame_samples: Array[int] = []
	var tier1_samples: Array[int] = []
	var violent_counts: Array[int] = []
	var reactive_became_violent := false
	var far_stayed_calm := true
	var shots_fired := 0
	for step in range(SAMPLE_COUNT):
		if SHOT_STEPS.has(step):
			if player.request_primary_fire():
				shots_fired += 1
		var frame_started := Time.get_ticks_usec()
		await process_frame
		var frame_usec := Time.get_ticks_usec() - frame_started
		wall_frame_samples.append(frame_usec)
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		tier1_samples.append(int(snapshot.get("tier1_count", 0)))
		violent_counts.append(_count_violent_reactions(snapshot))
		var reactive_state := _find_state(snapshot, str(cluster.get("reactive_id", "")))
		var far_state := _find_state(snapshot, str(cluster.get("far_id", "")))
		reactive_became_violent = reactive_became_violent or _is_violent_state(reactive_state)
		far_stayed_calm = far_stayed_calm and (far_state.is_empty() or not _is_violent_state(far_state))

	var profile: Dictionary = world.get_performance_profile()
	profile["wall_frame_avg_usec"] = _average_usec(wall_frame_samples)
	profile["wall_frame_max_usec"] = _max_usec(wall_frame_samples)
	profile["wall_frame_sample_count"] = wall_frame_samples.size()
	profile["scenario_avg_tier1_count"] = _average_int(tier1_samples)
	profile["scenario_max_violent_count"] = _max_int(violent_counts)
	profile["scenario_shots_fired"] = shots_fired
	profile["scenario_reactive_became_violent"] = reactive_became_violent
	profile["scenario_far_stayed_calm"] = far_stayed_calm
	print("CITY_PEDESTRIAN_LIVE_GUNSHOT_PERFORMANCE_REPORT %s" % JSON.stringify(profile))

	if not T.require_true(self, int(profile.get("wall_frame_avg_usec", 0)) <= REDLINE_USEC, "Live gunshot threat chain must keep average wall-frame time at or below the 16.67ms redline"):
		return
	if not T.require_true(self, int(profile.get("scenario_shots_fired", 0)) >= 3, "Live gunshot performance must fire multiple shots to create a real audible panic chain"):
		return
	if not T.require_true(self, int(profile.get("scenario_avg_tier1_count", 0)) >= MIN_TIER1_COUNT, "Live gunshot performance must keep a real lite crowd loaded instead of profiling an empty combat lane"):
		return
	if not T.require_true(self, bool(profile.get("scenario_reactive_became_violent", false)), "Live gunshot performance must observe at least one sampled witness enter panic/flee"):
		return
	if not T.require_true(self, bool(profile.get("scenario_far_stayed_calm", false)), "Live gunshot performance must keep sampled far outsiders calm while the panic chain stays local"):
		return
	if not T.require_true(self, int(profile.get("scenario_max_violent_count", 0)) > 0, "Live gunshot performance must record a non-zero panic/flee witness count"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _find_distance_ring_in_world(world, player) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var player_position: Vector3 = search_position_variant
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

func _find_state(snapshot: Dictionary, pedestrian_id: String) -> Dictionary:
	for tier_key in ["tier1_states", "tier2_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			var state: Dictionary = state_variant
			if str(state.get("pedestrian_id", "")) == pedestrian_id:
				return state
	return {}

func _count_violent_reactions(snapshot: Dictionary) -> int:
	var violent_count := 0
	for tier_key in ["tier1_states", "tier2_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			var state: Dictionary = state_variant
			if _is_violent_state(state):
				violent_count += 1
	return violent_count

func _is_violent_state(state: Dictionary) -> bool:
	var reaction_state := str(state.get("reaction_state", ""))
	return reaction_state == "panic" or reaction_state == "flee"

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
