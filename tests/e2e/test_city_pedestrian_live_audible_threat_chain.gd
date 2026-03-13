extends SceneTree

const T := preload("res://tests/_test_util.gd")

const GUNSHOT_RADIUS_M := 24.0
const PLAYER_NEAR_RADIUS_M := 6.5
const LETHAL_RADIUS_M := 4.0
const AUDIBLE_GRENADE_RADIUS_M := 20.0
const CALM_MIN_DISTANCE_M := 420.0
const GRENADE_THROW_DISTANCE_M := 8.0
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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for live audible threat chain")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Live audible threat chain requires Player node"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "PlayerController must expose request_primary_fire() for live audible threat chain"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for live audible threat chain"):
		return
	if not T.require_true(self, player.has_method("set_grenade_ready_active"), "PlayerController must expose set_grenade_ready_active() for live audible threat chain"):
		return
	if not T.require_true(self, player.has_method("request_grenade_throw"), "PlayerController must expose request_grenade_throw() for live audible threat chain"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for live audible threat chain"):
		return

	var gunshot_cluster := await _find_gunshot_cluster_in_world(world, player)
	if not T.require_true(self, not gunshot_cluster.is_empty(), "Live audible threat chain needs a real-player gunshot cluster with two nearby witnesses and a calm outsider beyond 420m"):
		return
	var gunshot_result := await _run_live_gunshot_chain(world, player, gunshot_cluster)
	print("CITY_PEDESTRIAN_LIVE_GUNSHOT_CHAIN %s" % JSON.stringify(gunshot_result))

	var grenade_cluster := await _find_grenade_sound_cluster_in_world(world, player)
	if not T.require_true(self, not grenade_cluster.is_empty(), "Live audible threat chain needs a non-lethal grenade witness cluster with a reactive witness and a calm outsider beyond 420m"):
		return
	var grenade_result := await _run_live_grenade_sound_chain(world, player, grenade_cluster)
	print("CITY_PEDESTRIAN_LIVE_GRENADE_SOUND_CHAIN %s" % JSON.stringify(grenade_result))

	var failures: PackedStringArray = []
	if not bool(gunshot_result.get("fired", false)):
		failures.append("gunshot_not_fired")
	if not bool(gunshot_result.get("center_survived", false)):
		failures.append("gunshot_center_did_not_survive")
	if not bool(gunshot_result.get("witness_a_reactive", false)):
		failures.append("gunshot_witness_a_not_reactive")
	if not bool(gunshot_result.get("witness_b_reactive", false)):
		failures.append("gunshot_witness_b_not_reactive")
	if not bool(gunshot_result.get("far_stays_calm", false)):
		failures.append("gunshot_far_not_calm")
	if not bool(grenade_result.get("throw_started", false)):
		failures.append("grenade_throw_not_started")
	if not bool(grenade_result.get("exploded", false)):
		failures.append("grenade_not_exploded")
	if not bool(grenade_result.get("reactive_survived", false)):
		failures.append("grenade_reactive_witness_did_not_survive")
	if not bool(grenade_result.get("reactive_reactive", false)):
		failures.append("grenade_reactive_witness_not_reactive")
	if not bool(grenade_result.get("far_stays_calm", false)):
		failures.append("grenade_far_not_calm")
	if not failures.is_empty():
		T.fail_and_quit(self, "Live audible threat chain failures: %s" % ", ".join(failures))
		return

	world.queue_free()
	T.pass_and_quit(self)

func _run_live_gunshot_chain(world, player, cluster: Dictionary) -> Dictionary:
	var center_id := str(cluster.get("center_id", ""))
	var witness_a_id := str(cluster.get("witness_a_id", ""))
	var witness_b_id := str(cluster.get("witness_b_id", ""))
	var far_id := str(cluster.get("far_id", ""))
	var center_position: Vector3 = cluster.get("center_position", Vector3.ZERO)
	var shooter_position: Vector3 = cluster.get("shooter_position", Vector3.ZERO)
	player.teleport_to_world_position(shooter_position)
	player.set_weapon_mode("rifle")
	world.update_streaming_for_position(player.global_position, 0.1)
	for _settle_index in range(2):
		await physics_frame
		await process_frame

	var baseline_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var aim_target := shooter_position + (shooter_position - center_position).normalized() * 40.0 + Vector3.UP * 18.0
	await _orient_player_to_target(player, aim_target)
	var fired: bool = player.request_primary_fire()
	for _frame_index in range(12):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame

	var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var center_state := _find_state(snapshot, center_id)
	var witness_a := _find_state(snapshot, witness_a_id)
	var witness_b := _find_state(snapshot, witness_b_id)
	var far_state := _find_state(snapshot, far_id)
	return {
		"cluster": cluster,
		"fired": fired,
		"aim_target": aim_target,
		"baseline_center": _find_state(baseline_snapshot, center_id),
		"baseline_witness_a": _find_state(baseline_snapshot, witness_a_id),
		"baseline_witness_b": _find_state(baseline_snapshot, witness_b_id),
		"baseline_far": _find_state(baseline_snapshot, far_id),
		"center": center_state,
		"witness_a": witness_a,
		"witness_b": witness_b,
		"far": far_state,
		"center_survived": not center_state.is_empty(),
		"witness_a_reactive": ["panic", "flee"].has(str(witness_a.get("reaction_state", ""))),
		"witness_b_reactive": ["panic", "flee"].has(str(witness_b.get("reaction_state", ""))),
		"far_stays_calm": not ["panic", "flee"].has(str(far_state.get("reaction_state", ""))),
		"snapshot": snapshot,
	}

func _run_live_grenade_sound_chain(world, player, cluster: Dictionary) -> Dictionary:
	var reactive_id := str(cluster.get("reactive_id", ""))
	var far_id := str(cluster.get("far_id", ""))
	var explosion_position: Vector3 = cluster.get("explosion_position", Vector3.ZERO)
	var throw_origin: Vector3 = cluster.get("throw_origin", Vector3.ZERO)
	player.teleport_to_world_position(throw_origin)
	player.set_weapon_mode("grenade")
	world.update_streaming_for_position(player.global_position, 0.1)
	for _settle_index in range(2):
		await physics_frame
		await process_frame

	var baseline_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var best_pitch := await _find_best_grenade_pitch(player, explosion_position)
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.rotation.x = best_pitch
	player.set_grenade_ready_active(true)
	await process_frame
	var preview_state: Dictionary = player.get_grenade_preview_state()
	var landing_point: Vector3 = preview_state.get("landing_point", Vector3.ZERO)
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
	for _post_index in range(12):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame

	var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var reactive_state := _find_state(snapshot, reactive_id)
	var far_state := _find_state(snapshot, far_id)
	return {
		"cluster": cluster,
		"throw_started": throw_started,
		"exploded": exploded,
		"landing_point": landing_point,
		"landing_error_m": landing_point.distance_to(explosion_position),
		"baseline_reactive": _find_state(baseline_snapshot, reactive_id),
		"baseline_far": _find_state(baseline_snapshot, far_id),
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

func _find_gunshot_cluster_in_world(world, player) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		player.teleport_to_world_position(search_position)
		world.update_streaming_for_position(search_position, 0.25)
		await process_frame
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var cluster := _pick_gunshot_cluster(snapshot)
		if not cluster.is_empty():
			return cluster
	return {}

func _find_grenade_sound_cluster_in_world(world, player) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		player.teleport_to_world_position(search_position)
		world.update_streaming_for_position(search_position, 0.25)
		await process_frame
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var cluster := _pick_grenade_sound_cluster(snapshot)
		if not cluster.is_empty():
			return cluster
	return {}

func _pick_gunshot_cluster(snapshot: Dictionary) -> Dictionary:
	var states := _collect_states(snapshot)
	for center_variant in states:
		var center: Dictionary = center_variant
		if not _is_calm_state(center):
			continue
		var center_id := str(center.get("pedestrian_id", ""))
		var center_position: Vector3 = center.get("world_position", Vector3.ZERO)
		var witness_candidates: Array = []
		for other_variant in states:
			var other: Dictionary = other_variant
			if str(other.get("pedestrian_id", "")) == center_id:
				continue
			if not _is_calm_state(other):
				continue
			var distance_m := center_position.distance_to(other.get("world_position", Vector3.ZERO))
			if distance_m > 1.5 and distance_m <= 18.0:
				witness_candidates.append(other)
		if witness_candidates.size() < 2:
			continue
		witness_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return center_position.distance_to(a.get("world_position", Vector3.ZERO)) < center_position.distance_to(b.get("world_position", Vector3.ZERO))
		)
		for witness_a_index in range(mini(4, witness_candidates.size())):
			for witness_b_index in range(witness_a_index + 1, mini(6, witness_candidates.size())):
				var witness_a: Dictionary = witness_candidates[witness_a_index]
				var witness_b: Dictionary = witness_candidates[witness_b_index]
				var shooter_position := _pick_gunshot_shooter_position(
					center_position,
					witness_a.get("world_position", Vector3.ZERO),
					witness_b.get("world_position", Vector3.ZERO)
				)
				if not _is_finite_position(shooter_position):
					continue
				var far_candidate := _pick_far_candidate(
					states,
					[center_id, str(witness_a.get("pedestrian_id", "")), str(witness_b.get("pedestrian_id", ""))],
					shooter_position,
					CALM_MIN_DISTANCE_M
				)
				if far_candidate.is_empty():
					continue
				return {
					"center_id": center_id,
					"center_position": center_position,
					"witness_a_id": str(witness_a.get("pedestrian_id", "")),
					"witness_b_id": str(witness_b.get("pedestrian_id", "")),
					"far_id": str(far_candidate.get("pedestrian_id", "")),
					"shooter_position": shooter_position,
				}
	return {}

func _pick_grenade_sound_cluster(snapshot: Dictionary) -> Dictionary:
	var states := _collect_states(snapshot)
	for reactive_variant in states:
		var reactive: Dictionary = reactive_variant
		if not _is_calm_state(reactive):
			continue
		var reactive_id := str(reactive.get("pedestrian_id", ""))
		var reactive_position: Vector3 = reactive.get("world_position", Vector3.ZERO)
		for ring_radius_m in [14.0, 16.0, 18.0]:
			for angle_deg in range(0, 360, 30):
				var angle_rad := deg_to_rad(float(angle_deg))
				var direction := Vector3(cos(angle_rad), 0.0, sin(angle_rad))
				var explosion_position: Vector3 = reactive_position - direction * ring_radius_m
				if _nearest_distance_to_states(states, explosion_position) <= LETHAL_RADIUS_M + 0.75:
					continue
				var throw_origin: Vector3 = explosion_position - direction * GRENADE_THROW_DISTANCE_M + Vector3.UP * 1.1
				if _nearest_distance_to_states(states, throw_origin) <= PLAYER_NEAR_RADIUS_M + 1.0:
					continue
				var far_candidate := _pick_far_candidate(
					states,
					[reactive_id],
					explosion_position,
					CALM_MIN_DISTANCE_M
				)
				if not far_candidate.is_empty() and not _is_calm_state(far_candidate):
					far_candidate = {}
				if far_candidate.is_empty():
					continue
				return {
					"reactive_id": reactive_id,
					"reactive_position": reactive_position,
					"far_id": str(far_candidate.get("pedestrian_id", "")),
					"explosion_position": explosion_position,
					"throw_origin": throw_origin,
					"reactive_distance_m": ring_radius_m,
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

func _pick_far_candidate(states: Array, excluded_ids: Array, reference_position: Vector3, min_distance_m: float) -> Dictionary:
	for state_variant in states:
		var state: Dictionary = state_variant
		if excluded_ids.has(str(state.get("pedestrian_id", ""))):
			continue
		if reference_position.distance_to(state.get("world_position", Vector3.ZERO)) >= min_distance_m:
			return state
	return {}

func _pick_gunshot_shooter_position(center_position: Vector3, witness_a_position: Vector3, witness_b_position: Vector3) -> Vector3:
	for radius_m in [8.5, 10.0, 12.0, 14.0]:
		for angle_deg in range(0, 360, 15):
			var angle_rad := deg_to_rad(float(angle_deg))
			var candidate: Vector3 = center_position + Vector3(cos(angle_rad), 0.0, sin(angle_rad)) * radius_m
			var distance_to_a: float = candidate.distance_to(witness_a_position)
			var distance_to_b: float = candidate.distance_to(witness_b_position)
			if distance_to_a <= PLAYER_NEAR_RADIUS_M + 1.0 or distance_to_b <= PLAYER_NEAR_RADIUS_M + 1.0:
				continue
			if distance_to_a >= GUNSHOT_RADIUS_M - 0.5 or distance_to_b >= GUNSHOT_RADIUS_M - 0.5:
				continue
			return candidate + Vector3.UP * 1.1
	return Vector3(INF, INF, INF)

func _nearest_distance_to_states(states: Array, world_position: Vector3) -> float:
	var best_distance := INF
	for state_variant in states:
		var state: Dictionary = state_variant
		best_distance = minf(best_distance, world_position.distance_to(state.get("world_position", Vector3.ZERO)))
	return best_distance

func _is_finite_position(world_position: Vector3) -> bool:
	return is_finite(world_position.x) and is_finite(world_position.y) and is_finite(world_position.z)

func _is_calm_state(state: Dictionary) -> bool:
	return str(state.get("reaction_state", "none")) == "none" and str(state.get("life_state", "alive")) == "alive"
