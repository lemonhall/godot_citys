extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REACTIVE_MIN_DISTANCE_M := 220.0
const REACTIVE_MAX_DISTANCE_M := 380.0
const CALM_MIN_DISTANCE_M := 420.0
const ORIGIN_CLEARANCE_M := 24.0
const GRENADE_TARGET_OFFSET := Vector3(12.0, 0.0, 0.0)
const SEARCH_POSITIONS := [
	Vector3(-1280.0, 1.1, -1024.0),
	Vector3(-2048.0, 1.1, 0.0),
	Vector3(-2048.0, 1.1, -768.0),
	Vector3(-1792.0, 1.1, -768.0),
	Vector3(-2048.0, 1.1, -512.0),
	Vector3(-1200.0, 1.1, 26.0),
	Vector3(-900.0, 1.1, 26.0),
	Vector3(-600.0, 1.1, 26.0),
	Vector3(-300.0, 1.1, 26.0),
	Vector3(300.0, 1.1, 26.0),
	Vector3(600.0, 1.1, 26.0),
	Vector3(768.0, 1.1, 26.0),
	Vector3(1024.0, 1.1, 26.0),
	Vector3(1536.0, 1.1, 26.0),
	Vector3(1792.0, 1.1, 512.0),
	Vector3(2048.0, 1.1, 768.0),
	Vector3(2304.0, 1.1, 896.0),
	Vector3.ZERO,
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for live wide-area threat chain")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Live wide-area threat chain requires Player node"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "PlayerController must expose request_primary_fire() for live wide-area threat chain"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for live wide-area threat chain"):
		return
	if not T.require_true(self, player.has_method("set_grenade_ready_active"), "PlayerController must expose set_grenade_ready_active() for live wide-area threat chain"):
		return
	if not T.require_true(self, player.has_method("request_grenade_throw"), "PlayerController must expose request_grenade_throw() for live wide-area threat chain"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for live wide-area threat chain"):
		return

	var gunshot_cluster := await _find_distance_ring_in_world(world, player, Vector3.ZERO)
	if not T.require_true(self, not gunshot_cluster.is_empty(), "Live wide-area threat chain needs a sampled gunshot witness between 220m and 380m plus a calm outsider beyond 420m"):
		return
	var gunshot_result := await _run_live_gunshot_chain(world, player, gunshot_cluster)
	print("CITY_PEDESTRIAN_LIVE_WIDE_GUNSHOT %s" % JSON.stringify(gunshot_result))

	var grenade_cluster := await _find_distance_ring_in_world(world, player, GRENADE_TARGET_OFFSET)
	if not T.require_true(self, not grenade_cluster.is_empty(), "Live wide-area threat chain needs a sampled grenade witness between 220m and 380m plus a calm outsider beyond 420m"):
		return
	var grenade_result := await _run_live_grenade_chain(world, player, grenade_cluster)
	print("CITY_PEDESTRIAN_LIVE_WIDE_GRENADE %s" % JSON.stringify(grenade_result))

	var failures: PackedStringArray = []
	if not bool(gunshot_result.get("fired", false)):
		failures.append("gunshot_not_fired")
	if not bool(gunshot_result.get("reactive_reactive", false)):
		failures.append("gunshot_reactive_not_reactive")
	if not bool(gunshot_result.get("far_stays_calm", false)):
		failures.append("gunshot_far_not_calm")
	if not bool(grenade_result.get("throw_started", false)):
		failures.append("grenade_throw_not_started")
	if not bool(grenade_result.get("exploded", false)):
		failures.append("grenade_not_exploded")
	if not bool(grenade_result.get("reactive_survived", false)):
		failures.append("grenade_reactive_did_not_survive")
	if not bool(grenade_result.get("reactive_reactive", false)):
		failures.append("grenade_reactive_not_reactive")
	if not bool(grenade_result.get("far_stays_calm", false)):
		failures.append("grenade_far_not_calm")
	if not failures.is_empty():
		T.fail_and_quit(self, "Live wide-area threat chain failures: %s" % ", ".join(failures))
		return

	world.queue_free()
	T.pass_and_quit(self)

func _run_live_gunshot_chain(world, player, cluster: Dictionary) -> Dictionary:
	var origin_position: Vector3 = cluster.get("origin_position", Vector3.ZERO)
	player.teleport_to_world_position(origin_position)
	player.set_weapon_mode("rifle")
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame
	await _orient_player_to_target(player, origin_position + Vector3(36.0, 22.0, 0.0))
	var fired: bool = player.request_primary_fire()
	for _frame_index in range(18):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame
	var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var reactive_state := _find_state(snapshot, str(cluster.get("reactive_id", "")))
	var far_state := _find_state(snapshot, str(cluster.get("far_id", "")))
	return {
		"cluster": cluster,
		"fired": fired,
		"reactive": reactive_state,
		"far": far_state,
		"reactive_reactive": ["panic", "flee"].has(str(reactive_state.get("reaction_state", ""))),
		"far_stays_calm": not ["panic", "flee"].has(str(far_state.get("reaction_state", ""))),
		"snapshot": snapshot,
	}

func _run_live_grenade_chain(world, player, cluster: Dictionary) -> Dictionary:
	var player_position: Vector3 = cluster.get("player_position", Vector3.ZERO)
	var explosion_position: Vector3 = cluster.get("event_position", Vector3.ZERO)
	player.teleport_to_world_position(player_position)
	player.set_weapon_mode("grenade")
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame
	var best_pitch := await _find_best_grenade_pitch(player, explosion_position)
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.rotation.x = best_pitch
	player.set_grenade_ready_active(true)
	await process_frame
	var throw_started: bool = player.request_grenade_throw()
	var grenade := _latest_live_grenade(world)
	var exploded := false
	for _frame_index in range(180):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame
		if grenade == null or not is_instance_valid(grenade):
			break
		if grenade.has_method("has_exploded") and grenade.has_exploded():
			exploded = true
			break
	for _post_index in range(18):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame
	var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var reactive_state := _find_state(snapshot, str(cluster.get("reactive_id", "")))
	var far_state := _find_state(snapshot, str(cluster.get("far_id", "")))
	return {
		"cluster": cluster,
		"throw_started": throw_started,
		"exploded": exploded,
		"reactive": reactive_state,
		"far": far_state,
		"reactive_survived": not reactive_state.is_empty(),
		"reactive_reactive": ["panic", "flee"].has(str(reactive_state.get("reaction_state", ""))),
		"far_stays_calm": not ["panic", "flee"].has(str(far_state.get("reaction_state", ""))),
		"snapshot": snapshot,
	}

func _latest_live_grenade(world) -> Node3D:
	var grenade_root := world.get_node_or_null("CombatRoot/Grenades") as Node3D
	if grenade_root == null or grenade_root.get_child_count() <= 0:
		return null
	return grenade_root.get_child(grenade_root.get_child_count() - 1) as Node3D

func _find_best_grenade_pitch(player, target_world_position: Vector3) -> float:
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig == null:
		return deg_to_rad(-24.0)
	await _orient_player_to_target(player, target_world_position)
	player.set_grenade_ready_active(true)
	await process_frame
	var best_pitch := camera_rig.rotation.x
	var best_error := INF
	for pitch_deg in range(-58, 19, 2):
		camera_rig.rotation.x = deg_to_rad(float(pitch_deg))
		await process_frame
		var preview_state: Dictionary = player.get_grenade_preview_state()
		if not bool(preview_state.get("visible", false)):
			continue
		var landing_point: Vector3 = preview_state.get("landing_point", Vector3.ZERO)
		var landing_error := landing_point.distance_to(target_world_position)
		if landing_error < best_error:
			best_error = landing_error
			best_pitch = camera_rig.rotation.x
	return best_pitch

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

func _find_distance_ring_in_world(world, player, event_offset: Vector3) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var player_position: Vector3 = search_position_variant
		player.teleport_to_world_position(player_position)
		world.update_streaming_for_position(player_position, 0.25)
		await process_frame
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var cluster := _pick_distance_ring(snapshot, player_position, event_offset)
		if not cluster.is_empty():
			return cluster
	return {}

func _pick_distance_ring(snapshot: Dictionary, player_position: Vector3, event_offset: Vector3) -> Dictionary:
	var event_position := player_position + event_offset
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
		"player_position": player_position,
		"origin_position": player_position,
		"event_position": event_position,
		"reactive_id": str(reactive_candidate.get("pedestrian_id", "")),
		"reactive_distance_m": event_position.distance_to(reactive_candidate.get("world_position", Vector3.ZERO)),
		"far_id": str(far_candidate.get("pedestrian_id", "")),
		"far_distance_m": event_position.distance_to(far_candidate.get("world_position", Vector3.ZERO)),
	}

func _collect_states(snapshot: Dictionary) -> Array:
	var states: Array = []
	for tier_key in ["tier2_states", "tier1_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			states.append(state_variant)
	return states

func _find_state(snapshot: Dictionary, pedestrian_id: String) -> Dictionary:
	for tier_key in ["tier1_states", "tier2_states", "tier3_states"]:
		var states: Array = snapshot.get(tier_key, [])
		for state_variant in states:
			var state: Dictionary = state_variant
			if str(state.get("pedestrian_id", "")) == pedestrian_id:
				return state
	return {}

func _nearest_distance_to_states(states: Array, world_position: Vector3) -> float:
	var best_distance := INF
	for state_variant in states:
		var state: Dictionary = state_variant
		best_distance = minf(best_distance, world_position.distance_to(state.get("world_position", Vector3.ZERO)))
	return best_distance

func _is_expected_mid_ring_responder(state: Dictionary) -> bool:
	return posmod(int(state.get("seed", 0)), 10) < 4

func _is_calm_state(state: Dictionary) -> bool:
	return str(state.get("reaction_state", "none")) == "none" and str(state.get("life_state", "alive")) == "alive"
