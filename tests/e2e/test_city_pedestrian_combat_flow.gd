extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LETHAL_RADIUS_M := 4.0
const THREAT_RADIUS_M := 12.0
const PROJECTILE_WITNESS_RADIUS_M := 18.0
const EXPLOSION_WITNESS_RADIUS_M := 20.0
const CALM_MIN_DISTANCE_M := 420.0
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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian combat flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for pedestrian combat flow"):
		return
	if not T.require_true(self, world.has_method("fire_player_projectile_toward"), "CityPrototype must expose fire_player_projectile_toward() for pedestrian combat flow"):
		return
	if not T.require_true(self, world.has_method("resolve_pedestrian_explosion"), "CityPrototype must expose resolve_pedestrian_explosion() for grenade casualty/flee flow"):
		return

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Pedestrian combat flow requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for pedestrian combat flow"):
		return

	var projectile_cluster := await _find_projectile_cluster_in_world(world, player)
	if not T.require_true(self, not projectile_cluster.is_empty(), "Pedestrian combat flow requires a live projectile cluster with two nearby witnesses and a calm outsider beyond 420m"):
		return

	var target_id := str(projectile_cluster.get("center_id", ""))
	var target_position: Vector3 = projectile_cluster.get("center_position", Vector3.ZERO)
	player.teleport_to_world_position(target_position + Vector3(-4.0, 1.1, -4.0))
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame
	var baseline_cluster_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var baseline_active_state_count := int(baseline_cluster_snapshot.get("active_state_count", 0))
	var refreshed_target := _find_state(world.get_pedestrian_runtime_snapshot(), target_id)
	if not T.require_true(self, not refreshed_target.is_empty(), "Pedestrian combat flow must keep the selected direct-hit victim live until the projectile is fired"):
		return
	target_position = _resolve_projectile_aim_position(refreshed_target)

	var fired_projectile := false
	for _burst_index in range(3):
		var live_target := _find_state(world.get_pedestrian_runtime_snapshot(), target_id)
		if live_target.is_empty():
			break
		target_position = _resolve_projectile_aim_position(live_target)
		var projectile = world.fire_player_projectile_toward(target_position)
		if not T.require_true(self, projectile != null, "Pedestrian combat flow must spawn a real projectile for the direct-hit phase"):
			return
		fired_projectile = true
		for _frame_index in range(8):
			await physics_frame
			world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
			await process_frame
	if not T.require_true(self, fired_projectile, "Pedestrian combat flow must fire at least one live projectile during the direct-hit phase"):
		return
	var post_projectile_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var projectile_killed := not _snapshot_contains_pedestrian(post_projectile_snapshot, target_id)
	var projectile_caused_casualty := projectile_killed or int(post_projectile_snapshot.get("active_state_count", 0)) < baseline_active_state_count
	if not T.require_true(self, projectile_caused_casualty, "Projectile combat flow must resolve at least one local pedestrian casualty instead of devolving into a no-impact burst"):
		return
	var projectile_witness_a := _find_state(post_projectile_snapshot, str(projectile_cluster.get("witness_a_id", "")))
	var projectile_witness_b := _find_state(post_projectile_snapshot, str(projectile_cluster.get("witness_b_id", "")))
	var projectile_far := _find_state(post_projectile_snapshot, str(projectile_cluster.get("far_id", "")))
	if not T.require_true(self, ["panic", "flee"].has(str(projectile_witness_a.get("reaction_state", ""))), "Projectile combat flow must push witness A into panic-or-flee state after the direct-hit casualty"):
		return
	if not T.require_true(self, ["panic", "flee"].has(str(projectile_witness_b.get("reaction_state", ""))), "Projectile combat flow must push witness B into panic-or-flee state after the direct-hit casualty"):
		return
	if not T.require_true(self, not ["panic", "flee"].has(str(projectile_far.get("reaction_state", ""))), "Projectile combat flow must keep pedestrians beyond 400m out of the witness panic response"):
		return

	var cluster := await _find_explosion_cluster_in_world(world, player)
	if not T.require_true(self, not cluster.is_empty(), "Pedestrian combat flow requires a follow-up explosion cluster with threat-ring, witness-ring and a calm outsider beyond 420m"):
		return

	var center_position: Vector3 = cluster.get("center_position", Vector3.ZERO)
	player.teleport_to_world_position(center_position + Vector3(2.0, 1.1, 2.0))
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame

	var explosion_result: Dictionary = world.resolve_pedestrian_explosion(center_position, LETHAL_RADIUS_M, THREAT_RADIUS_M)
	for _frame_index in range(6):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame

	var final_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var threat_state := _find_state(final_snapshot, str(cluster.get("threat_id", "")))
	var witness_state := _find_state(final_snapshot, str(cluster.get("witness_id", "")))
	var far_state := _find_state(final_snapshot, str(cluster.get("far_id", "")))
	print("CITY_PEDESTRIAN_COMBAT_FLOW %s" % JSON.stringify({
		"projectile_cluster": projectile_cluster,
		"post_projectile_snapshot": post_projectile_snapshot,
		"explosion_result": explosion_result,
		"cluster": cluster,
		"final_snapshot": final_snapshot,
	}))

	if not T.require_true(self, int(explosion_result.get("killed_count", 0)) >= 1, "Explosion combat flow must kill at least one pedestrian inside the lethal radius"):
		return
	if not T.require_true(self, ["panic", "flee"].has(str(threat_state.get("reaction_state", ""))), "Explosion combat flow must push nearby survivors into panic-or-flee state"):
		return
	if not T.require_true(self, ["panic", "flee"].has(str(witness_state.get("reaction_state", ""))), "Explosion combat flow must push witness-ring survivors into panic-or-flee state even outside the direct threat radius"):
		return
	if not T.require_true(self, not ["panic", "flee"].has(str(far_state.get("reaction_state", ""))), "Explosion combat flow must keep pedestrians beyond 400m out of the panic response"):
		return
	if not T.require_true(self, int(final_snapshot.get("tier3_count", 0)) <= 24, "Pedestrian combat flow must keep Tier 3 agents within the hard cap of 24"):
		return
	if not T.require_true(self, int(final_snapshot.get("duplicate_page_load_count", 0)) == 0, "Pedestrian combat flow must not introduce duplicate page loads or travel-time count leaks"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _pick_candidate_state(snapshot: Dictionary) -> Dictionary:
	for tier_key in ["tier2_states", "tier1_states"]:
		var states: Array = snapshot.get(tier_key, [])
		if not states.is_empty():
			return states[0]
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

func _snapshot_contains_pedestrian(snapshot: Dictionary, pedestrian_id: String) -> bool:
	return not _find_state(snapshot, pedestrian_id).is_empty()

func _find_state(snapshot: Dictionary, pedestrian_id: String) -> Dictionary:
	for tier_key in ["tier1_states", "tier2_states", "tier3_states"]:
		var states: Array = snapshot.get(tier_key, [])
		for state_variant in states:
			var state: Dictionary = state_variant
			if str(state.get("pedestrian_id", "")) == pedestrian_id:
				return state
	return {}

func _resolve_projectile_aim_position(state: Dictionary) -> Vector3:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var height_m := float(state.get("height_m", 1.75))
	return world_position + Vector3.UP * maxf(height_m * 0.5, 0.9)

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
