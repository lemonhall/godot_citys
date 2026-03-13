extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LETHAL_RADIUS_M := 4.0
const THREAT_RADIUS_M := 12.0
const PROJECTILE_WITNESS_RADIUS_M := 18.0
const EXPLOSION_WITNESS_RADIUS_M := 20.0
const CALM_MIN_DISTANCE_M := 520.0
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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for live pedestrian combat chain")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Live combat chain requires Player node"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "PlayerController must expose request_primary_fire() for live combat chain"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for live combat chain"):
		return
	if not T.require_true(self, player.has_method("set_grenade_ready_active"), "PlayerController must expose set_grenade_ready_active() for live combat chain"):
		return
	if not T.require_true(self, player.has_method("request_grenade_throw"), "PlayerController must expose request_grenade_throw() for live combat chain"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for live combat chain"):
		return

	var projectile_cluster := await _find_projectile_cluster_in_world(world, player)
	if not T.require_true(self, not projectile_cluster.is_empty(), "Live combat chain needs a projectile cluster with two witnesses and one calm outsider beyond 520m"):
		return

	var projectile_result := await _run_live_projectile_chain(world, player, projectile_cluster)
	print("CITY_PEDESTRIAN_LIVE_PROJECTILE_CHAIN %s" % JSON.stringify(_summarize_projectile_result(projectile_result)))

	var explosion_cluster := await _find_explosion_cluster_in_world(world, player)
	if not T.require_true(self, not explosion_cluster.is_empty(), "Live combat chain needs an explosion cluster with threat-ring, witness-ring and a calm outsider beyond 520m"):
		return

	var grenade_result := await _run_live_grenade_chain(world, player, explosion_cluster)
	print("CITY_PEDESTRIAN_LIVE_GRENADE_CHAIN %s" % JSON.stringify(_summarize_grenade_result(grenade_result)))

	var failures: PackedStringArray = []
	if not bool(projectile_result.get("projectile_caused_casualty", false)):
		failures.append("projectile_no_casualty")
	if not bool(projectile_result.get("witness_a_reactive", false)):
		failures.append("projectile_witness_a_not_reactive")
	if not bool(projectile_result.get("witness_b_reactive", false)):
		failures.append("projectile_witness_b_not_reactive")
	if not bool(projectile_result.get("far_stays_calm", false)):
		failures.append("projectile_far_not_calm")
	if not bool(grenade_result.get("grenade_killed_center", false)):
		failures.append("grenade_no_lethal_kill")
	if not bool(grenade_result.get("threat_reactive", false)):
		failures.append("grenade_threat_not_reactive")
	if not bool(grenade_result.get("witness_reactive", false)):
		failures.append("grenade_witness_not_reactive")
	if not bool(grenade_result.get("far_stays_calm", false)):
		failures.append("grenade_far_not_calm")
	if not failures.is_empty():
		T.fail_and_quit(self, "Live combat chain failures: %s" % ", ".join(failures))
		return

	world.queue_free()
	T.pass_and_quit(self)

func _run_live_projectile_chain(world, player, cluster: Dictionary) -> Dictionary:
	var target_id := str(cluster.get("center_id", ""))
	var witness_a_id := str(cluster.get("witness_a_id", ""))
	var witness_b_id := str(cluster.get("witness_b_id", ""))
	var far_id := str(cluster.get("far_id", ""))
	var target_position: Vector3 = cluster.get("center_position", Vector3.ZERO)
	var shooter_position := target_position + Vector3(-4.0, 1.1, -4.0)
	player.teleport_to_world_position(shooter_position)
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame
	await _orient_player_to_target(player, _resolve_projectile_aim_position(_find_state(world.get_pedestrian_runtime_snapshot(), target_id)))

	var baseline_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var baseline_active_state_count := int(baseline_snapshot.get("active_state_count", 0))
	var target_state := _find_state(baseline_snapshot, target_id)
	var initial_target_position := _resolve_projectile_aim_position(target_state)
	var spawn_origin: Vector3 = player.get_projectile_spawn_transform().origin if player.has_method("get_projectile_spawn_transform") else player.global_position
	var aim_target_world: Vector3 = player.get_aim_target_world_position() if player.has_method("get_aim_target_world_position") else initial_target_position
	var projectile_direction: Vector3 = player.get_projectile_direction() if player.has_method("get_projectile_direction") else (initial_target_position - spawn_origin).normalized()
	var fired := false
	for _burst_index in range(4):
		var live_target := _find_state(world.get_pedestrian_runtime_snapshot(), target_id)
		if live_target.is_empty():
			break
		await _orient_player_to_target(player, _resolve_projectile_aim_position(live_target))
		if not player.request_primary_fire():
			await process_frame
			continue
		fired = true
		for _frame_index in range(10):
			await physics_frame
			world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
			await process_frame
	var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var projectile_killed := not _snapshot_contains_pedestrian(snapshot, target_id)
	var projectile_caused_casualty := projectile_killed or int(snapshot.get("active_state_count", 0)) < baseline_active_state_count
	var witness_a := _find_state(snapshot, witness_a_id)
	var witness_b := _find_state(snapshot, witness_b_id)
	var far_state := _find_state(snapshot, far_id)
	return {
		"cluster": cluster,
		"fired": fired,
		"spawn_origin": spawn_origin,
		"aim_target_world": aim_target_world,
		"projectile_direction": projectile_direction,
		"initial_target_position": initial_target_position,
		"projectile_target_clearance_m": _distance_to_segment(initial_target_position, spawn_origin, spawn_origin + projectile_direction * 36.0),
		"projectile_caused_casualty": projectile_caused_casualty,
		"projectile_killed": projectile_killed,
		"witness_a": witness_a,
		"witness_b": witness_b,
		"far": far_state,
		"witness_a_reactive": ["panic", "flee"].has(str(witness_a.get("reaction_state", ""))),
		"witness_b_reactive": ["panic", "flee"].has(str(witness_b.get("reaction_state", ""))),
		"far_stays_calm": not ["panic", "flee"].has(str(far_state.get("reaction_state", ""))),
		"snapshot": snapshot,
	}

func _run_live_grenade_chain(world, player, cluster: Dictionary) -> Dictionary:
	var center_id := str(cluster.get("center_id", ""))
	var center_position: Vector3 = cluster.get("center_position", Vector3.ZERO)
	var threat_id := str(cluster.get("threat_id", ""))
	var witness_id := str(cluster.get("witness_id", ""))
	var far_id := str(cluster.get("far_id", ""))
	var throw_origin := center_position + Vector3(-11.0, 1.1, -8.0)
	player.teleport_to_world_position(throw_origin)
	player.set_weapon_mode("grenade")
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame
	var live_center_state := _find_state(world.get_pedestrian_runtime_snapshot(), center_id)
	if not live_center_state.is_empty():
		center_position = live_center_state.get("world_position", center_position)
	var best_pitch := await _find_best_grenade_pitch(player, center_position)
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.rotation.x = best_pitch
	player.set_grenade_ready_active(true)
	await process_frame
	var preview_state: Dictionary = player.get_grenade_preview_state()
	var landing_point: Vector3 = preview_state.get("landing_point", Vector3.ZERO)
	var center_state_at_throw := _find_state(world.get_pedestrian_runtime_snapshot(), center_id)
	var center_position_at_throw: Vector3 = center_position if center_state_at_throw.is_empty() else center_state_at_throw.get("world_position", center_position)
	if not player.request_grenade_throw():
		return {
			"cluster": cluster,
			"throw_started": false,
			"landing_point": landing_point,
			"center_position_at_throw": center_position_at_throw,
			"snapshot": world.get_pedestrian_runtime_snapshot(),
		}
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
	for _settle_index in range(12):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame
	var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var center_dead := not _snapshot_contains_pedestrian(snapshot, center_id)
	var surviving_center_state := _find_state(snapshot, center_id)
	var threat_state := _find_state(snapshot, threat_id)
	var witness_state := _find_state(snapshot, witness_id)
	var far_state := _find_state(snapshot, far_id)
	return {
		"cluster": cluster,
		"throw_started": true,
		"exploded": exploded,
		"landing_point": landing_point,
		"landing_error_m": landing_point.distance_to(center_position),
		"center_position_at_throw": center_position_at_throw,
		"center_distance_to_landing_m": landing_point.distance_to(center_position_at_throw),
		"grenade_killed_center": center_dead,
		"center_state": surviving_center_state,
		"threat_state": threat_state,
		"witness_state": witness_state,
		"far_state": far_state,
		"threat_reactive": ["panic", "flee"].has(str(threat_state.get("reaction_state", ""))),
		"witness_reactive": ["panic", "flee"].has(str(witness_state.get("reaction_state", ""))),
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
		var preview_state := _predict_grenade_preview_state(player)
		if not bool(preview_state.get("visible", false)):
			continue
		var landing_point: Vector3 = preview_state.get("landing_point", Vector3.ZERO)
		var landing_error := landing_point.distance_to(target_world_position)
		if landing_error < best_error:
			best_error = landing_error
			best_pitch = camera_rig.rotation.x
	return best_pitch

func _predict_grenade_preview_state(player) -> Dictionary:
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state if player != null and player.get_world_3d() != null else null
	if space_state == null:
		return {
			"visible": false,
			"landing_point": Vector3.ZERO,
		}
	var current_position: Vector3 = player.get_grenade_spawn_transform().origin
	var current_velocity: Vector3 = player.get_grenade_launch_velocity()
	var landing_point := current_position
	for _step_index in range(int(player.grenade_preview_max_steps)):
		var next_velocity := current_velocity + Vector3.DOWN * float(player.grenade_gravity_mps2) * float(player.grenade_preview_step_sec)
		var next_position := current_position + (current_velocity + next_velocity) * 0.5 * float(player.grenade_preview_step_sec)
		var query := PhysicsRayQueryParameters3D.create(current_position, next_position)
		query.collide_with_areas = false
		query.exclude = [player.get_rid()]
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty():
			return {
				"visible": true,
				"landing_point": hit.get("position", next_position),
			}
		landing_point = next_position
		current_position = next_position
		current_velocity = next_velocity
	return {
		"visible": true,
		"landing_point": landing_point,
	}

func _summarize_projectile_result(result: Dictionary) -> Dictionary:
	return {
		"center_id": str((result.get("cluster", {}) as Dictionary).get("center_id", "")),
		"projectile_killed": bool(result.get("projectile_killed", false)),
		"projectile_caused_casualty": bool(result.get("projectile_caused_casualty", false)),
		"witness_a_reactive": bool(result.get("witness_a_reactive", false)),
		"witness_b_reactive": bool(result.get("witness_b_reactive", false)),
		"far_stays_calm": bool(result.get("far_stays_calm", false)),
	}

func _summarize_grenade_result(result: Dictionary) -> Dictionary:
	return {
		"center_id": str((result.get("cluster", {}) as Dictionary).get("center_id", "")),
		"landing_error_m": float(result.get("landing_error_m", -1.0)),
		"center_distance_to_landing_m": float(result.get("center_distance_to_landing_m", -1.0)),
		"grenade_killed_center": bool(result.get("grenade_killed_center", false)),
		"threat_reactive": bool(result.get("threat_reactive", false)),
		"witness_reactive": bool(result.get("witness_reactive", false)),
		"far_stays_calm": bool(result.get("far_stays_calm", false)),
	}

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

func _find_projectile_cluster_in_world(world, player) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		player.teleport_to_world_position(search_position)
		world.update_streaming_for_position(search_position, 0.25)
		await process_frame
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var cluster := _pick_projectile_cluster(snapshot)
		if not cluster.is_empty():
			return cluster
	return {}

func _find_explosion_cluster_in_world(world, player) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		player.teleport_to_world_position(search_position)
		world.update_streaming_for_position(search_position, 0.25)
		await process_frame
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var cluster := _pick_explosion_cluster(snapshot)
		if not cluster.is_empty():
			return cluster
	return {}

func _pick_projectile_cluster(snapshot: Dictionary) -> Dictionary:
	var states := _collect_states(snapshot)
	for center_variant in states:
		var center: Dictionary = center_variant
		if not _is_calm_state(center):
			continue
		var center_position: Vector3 = center.get("world_position", Vector3.ZERO)
		var witness_candidates: Array = []
		var far_candidate := {}
		for other_variant in states:
			var other: Dictionary = other_variant
			if str(other.get("pedestrian_id", "")) == str(center.get("pedestrian_id", "")):
				continue
			if not _is_calm_state(other):
				continue
			var distance_m := center_position.distance_to(other.get("world_position", Vector3.ZERO))
			if distance_m > 1.5 and distance_m <= PROJECTILE_WITNESS_RADIUS_M:
				witness_candidates.append(other)
			elif far_candidate.is_empty() and distance_m >= CALM_MIN_DISTANCE_M:
				far_candidate = other
		if witness_candidates.size() < 2 or far_candidate.is_empty():
			continue
		if not _has_clear_shot(center, states, center_position + Vector3(-4.0, 0.0, -4.0)):
			continue
		witness_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return center_position.distance_to(a.get("world_position", Vector3.ZERO)) < center_position.distance_to(b.get("world_position", Vector3.ZERO))
		)
		return {
			"center_id": str(center.get("pedestrian_id", "")),
			"center_position": center_position,
			"witness_a_id": str((witness_candidates[0] as Dictionary).get("pedestrian_id", "")),
			"witness_b_id": str((witness_candidates[1] as Dictionary).get("pedestrian_id", "")),
			"far_id": str(far_candidate.get("pedestrian_id", "")),
		}
	return {}

func _pick_explosion_cluster(snapshot: Dictionary) -> Dictionary:
	var states := _collect_states(snapshot)
	for center_variant in states:
		var center: Dictionary = center_variant
		if not _is_calm_state(center):
			continue
		var center_position: Vector3 = center.get("world_position", Vector3.ZERO)
		var threat_candidate := {}
		var witness_candidate := {}
		var far_candidate := {}
		for other_variant in states:
			var other: Dictionary = other_variant
			if str(other.get("pedestrian_id", "")) == str(center.get("pedestrian_id", "")):
				continue
			if not _is_calm_state(other):
				continue
			var distance_m := center_position.distance_to(other.get("world_position", Vector3.ZERO))
			if threat_candidate.is_empty() and distance_m > LETHAL_RADIUS_M + 0.75 and distance_m <= THREAT_RADIUS_M - 0.75:
				threat_candidate = other
			elif witness_candidate.is_empty() and distance_m > THREAT_RADIUS_M + 0.75 and distance_m <= EXPLOSION_WITNESS_RADIUS_M - 0.75:
				witness_candidate = other
			elif far_candidate.is_empty() and distance_m >= CALM_MIN_DISTANCE_M:
				far_candidate = other
		if threat_candidate.is_empty() or witness_candidate.is_empty() or far_candidate.is_empty():
			continue
		return {
			"center_id": str(center.get("pedestrian_id", "")),
			"center_position": center_position,
			"threat_id": str(threat_candidate.get("pedestrian_id", "")),
			"witness_id": str(witness_candidate.get("pedestrian_id", "")),
			"far_id": str(far_candidate.get("pedestrian_id", "")),
		}
	return {}

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

func _snapshot_contains_pedestrian(snapshot: Dictionary, pedestrian_id: String) -> bool:
	return not _find_state(snapshot, pedestrian_id).is_empty()

func _resolve_projectile_aim_position(state: Dictionary) -> Vector3:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var height_m := float(state.get("height_m", 1.75))
	return world_position + Vector3.UP * maxf(height_m * 0.5, 0.9)

func _distance_to_segment(point: Vector3, start_position: Vector3, end_position: Vector3) -> float:
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(start_position)
	var t := clampf((point - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_to(start_position + segment * t)

func _has_clear_shot(center: Dictionary, states: Array, shooter_position: Vector3) -> bool:
	var target_id := str(center.get("pedestrian_id", ""))
	var target_position: Vector3 = center.get("world_position", Vector3.ZERO)
	var shooter_2d := Vector2(shooter_position.x, shooter_position.z)
	var target_2d := Vector2(target_position.x, target_position.z)
	var segment := target_2d - shooter_2d
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.001:
		return false
	for other_variant in states:
		var other: Dictionary = other_variant
		if str(other.get("pedestrian_id", "")) == target_id:
			continue
		var other_position: Vector3 = other.get("world_position", Vector3.ZERO)
		var point_2d := Vector2(other_position.x, other_position.z)
		var t := clampf((point_2d - shooter_2d).dot(segment) / segment_length_squared, 0.0, 1.0)
		if t >= 0.98:
			continue
		var closest_point := shooter_2d + segment * t
		if point_2d.distance_to(closest_point) <= 0.6:
			return false
	return true

func _is_calm_state(state: Dictionary) -> bool:
	return str(state.get("reaction_state", "none")) == "none" and str(state.get("life_state", "alive")) == "alive"
