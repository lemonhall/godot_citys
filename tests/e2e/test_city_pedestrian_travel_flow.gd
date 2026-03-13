extends SceneTree

const T := preload("res://tests/_test_util.gd")

const PROJECTILE_WITNESS_RADIUS_M := 18.0
const CALM_MIN_DISTANCE_M := 520.0
const SEARCH_POSITIONS := [
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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian travel flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for crowd travel validation"):
		return
	if not T.require_true(self, world.has_method("fire_player_projectile_toward"), "CityPrototype must expose fire_player_projectile_toward() for pedestrian reactive E2E"):
		return

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for pedestrian travel flow"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for pedestrian travel flow"):
		return

	var seen_chunk_ids: Dictionary = {}
	var peak_tier3_count := 0
	for step in range(9):
		var travel_position := Vector3(-1200.0 + float(step) * 300.0, 1.1, 26.0)
		player.teleport_to_world_position(travel_position)
		world.update_streaming_for_position(travel_position)
		await process_frame

		var streaming_snapshot: Dictionary = world.get_streaming_snapshot()
		var pedestrian_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var current_chunk_id := str(streaming_snapshot.get("current_chunk_id", ""))
		if not T.require_true(self, current_chunk_id != "", "Pedestrian travel flow must report current_chunk_id"):
			return
		seen_chunk_ids[current_chunk_id] = true
		peak_tier3_count = maxi(peak_tier3_count, int(pedestrian_snapshot.get("tier3_count", 0)))

		if not T.require_true(self, int(pedestrian_snapshot.get("tier3_count", 0)) <= 24, "Pedestrian travel flow must keep Tier 3 agents within the hard cap of 24"):
			return
		if not T.require_true(self, int(pedestrian_snapshot.get("duplicate_page_load_count", 0)) == 0, "Pedestrian travel flow must not duplicate page loads across 8-chunk travel"):
			return

		if step == 4:
			var cluster := await _find_projectile_cluster_in_world(world, player)
			if not T.require_true(self, not cluster.is_empty(), "Pedestrian travel flow requires a visible witness cluster with a calm outsider beyond 520m for mixed travel + combat validation"):
				return
			var reactive_position: Vector3 = cluster.get("center_position", Vector3.ZERO) + Vector3(-4.0, 0.0, -4.0)
			player.teleport_to_world_position(reactive_position)
			world.update_streaming_for_position(reactive_position)
			await process_frame
			var baseline_active_state_count := int(world.get_pedestrian_runtime_snapshot().get("active_state_count", 0))
			var refreshed_target := _find_state(world.get_pedestrian_runtime_snapshot(), str(cluster.get("center_id", "")))
			if not T.require_true(self, not refreshed_target.is_empty(), "Travel flow must keep the selected direct-hit victim live until the projectile is fired"):
				return
			var target_id := str(cluster.get("center_id", ""))
			var fired_projectile := false
			for _burst_index in range(3):
				var live_target := _find_state(world.get_pedestrian_runtime_snapshot(), target_id)
				if live_target.is_empty():
					break
				var projectile = world.fire_player_projectile_toward(_resolve_projectile_aim_position(live_target))
				if not T.require_true(self, projectile != null, "Reactive projectile validation must spawn a projectile during travel flow"):
					return
				fired_projectile = true
				for _frame_index in range(8):
					await physics_frame
					world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
					await process_frame
					pedestrian_snapshot = world.get_pedestrian_runtime_snapshot()
					peak_tier3_count = maxi(peak_tier3_count, int(pedestrian_snapshot.get("tier3_count", 0)))
			if not T.require_true(self, fired_projectile, "Travel flow must fire at least one live projectile during the reactive validation step"):
				return
			var projectile_killed := _find_state(pedestrian_snapshot, target_id).is_empty()
			var projectile_caused_casualty := projectile_killed or int(pedestrian_snapshot.get("active_state_count", 0)) < baseline_active_state_count
			if not T.require_true(self, projectile_caused_casualty, "Travel flow mixed combat step must still resolve a local pedestrian casualty"):
				return
			var witness_a := _find_state(pedestrian_snapshot, str(cluster.get("witness_a_id", "")))
			var witness_b := _find_state(pedestrian_snapshot, str(cluster.get("witness_b_id", "")))
			var far_state := _find_state(pedestrian_snapshot, str(cluster.get("far_id", "")))
			if not T.require_true(self, ["panic", "flee"].has(str(witness_a.get("reaction_state", ""))), "Travel flow projectile kill must push witness A into panic-or-flee state"):
				return
			if not T.require_true(self, ["panic", "flee"].has(str(witness_b.get("reaction_state", ""))), "Travel flow projectile kill must push witness B into panic-or-flee state"):
				return
			if not T.require_true(self, not ["panic", "flee"].has(str(far_state.get("reaction_state", ""))), "Travel flow projectile kill must keep pedestrians beyond 500m out of the witness panic response"):
				return

	if not T.require_true(self, seen_chunk_ids.size() >= 8, "Pedestrian travel flow must cross at least 8 unique chunks"):
		return
	if not T.require_true(self, peak_tier3_count > 0, "Travel flow must trigger at least one Tier 3 pedestrian reaction during the mixed travel + combat scenario"):
		return

	var final_pedestrian_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	print("CITY_PEDESTRIAN_TRAVEL_FLOW %s" % JSON.stringify(final_pedestrian_snapshot))

	world.queue_free()
	T.pass_and_quit(self)

func _pick_candidate_state(snapshot: Dictionary) -> Dictionary:
	for tier_key in ["tier2_states", "tier1_states"]:
		var states: Array = snapshot.get(tier_key, [])
		if not states.is_empty():
			return states[0]
	return {}

func _pick_projectile_cluster(snapshot: Dictionary) -> Dictionary:
	var states: Array = []
	for tier_key in ["tier2_states", "tier1_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			states.append(state_variant)
	for center_variant in states:
		var center: Dictionary = center_variant
		var center_position: Vector3 = center.get("world_position", Vector3.ZERO)
		var witness_candidates: Array = []
		var far_candidate := {}
		for other_variant in states:
			var other: Dictionary = other_variant
			if str(other.get("pedestrian_id", "")) == str(center.get("pedestrian_id", "")):
				continue
			var distance_m := center_position.distance_to(other.get("world_position", Vector3.ZERO))
			if distance_m > 1.5 and distance_m <= PROJECTILE_WITNESS_RADIUS_M:
				witness_candidates.append(other)
			elif far_candidate.is_empty() and distance_m >= CALM_MIN_DISTANCE_M:
				far_candidate = other
		if witness_candidates.size() < 2 or far_candidate.is_empty():
			continue
		if not _has_clear_shot(center, states, center_position + Vector3(2.0, 0.0, 2.0)):
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

func _find_state(snapshot: Dictionary, pedestrian_id: String) -> Dictionary:
	for tier_key in ["tier1_states", "tier2_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
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
