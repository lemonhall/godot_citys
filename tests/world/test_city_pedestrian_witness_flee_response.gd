extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const LETHAL_RADIUS_M := 4.0
const THREAT_RADIUS_M := 12.0
const PROJECTILE_WITNESS_RADIUS_M := 18.0
const EXPLOSION_WITNESS_RADIUS_M := 20.0
const CALM_MIN_DISTANCE_M := 420.0
const SEARCH_POSITIONS := [
	Vector3(-1280.0, 0.0, -1024.0),
	Vector3(-2048.0, 0.0, 0.0),
	Vector3(-2048.0, 0.0, -768.0),
	Vector3(-1792.0, 0.0, -768.0),
	Vector3(-2048.0, 0.0, -512.0),
	Vector3(-1200.0, 0.0, 26.0),
	Vector3(-900.0, 0.0, 26.0),
	Vector3(-600.0, 0.0, 26.0),
	Vector3(-300.0, 0.0, 26.0),
	Vector3(300.0, 0.0, 26.0),
	Vector3(600.0, 0.0, 26.0),
	Vector3(768.0, 0.0, 26.0),
	Vector3(1024.0, 0.0, 26.0),
	Vector3(1536.0, 0.0, 26.0),
	Vector3(1792.0, 0.0, 512.0),
	Vector3(2048.0, 0.0, 768.0),
	Vector3(2304.0, 0.0, 896.0),
	Vector3.ZERO,
	Vector3(-768.0, 0.0, 26.0),
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var projectile_runtime := _setup_runtime()
	var projectile_cluster := _find_projectile_cluster(projectile_runtime)
	if not T.require_true(self, not projectile_cluster.is_empty(), "Witness flee response test requires a projectile cluster with a victim, two nearby witnesses and a calm outsider beyond 420m"):
		return

	var projectile_streamer: CityChunkStreamer = projectile_runtime.get("streamer")
	var projectile_controller: CityPedestrianTierController = projectile_runtime.get("controller")
	var projectile_center_position: Vector3 = projectile_cluster.get("center_position", Vector3.ZERO)
	var projectile_player_position := projectile_center_position + Vector3(2.0, 0.0, 2.0)
	projectile_streamer.update_for_world_position(projectile_player_position)
	projectile_controller.set_player_context(projectile_player_position, Vector3.ZERO)
	projectile_controller.update_active_chunks(projectile_streamer.get_active_chunk_entries(), projectile_player_position, 0.25)
	var projectile_center_state := projectile_controller.get_state_snapshot(str(projectile_cluster.get("center_id", "")))
	var projectile_aim_position := _resolve_projectile_aim_position(projectile_center_state)
	projectile_controller.notify_projectile_event(
		projectile_player_position,
		projectile_aim_position - projectile_player_position,
		36.0
	)
	var hit_result: Dictionary = projectile_controller.resolve_projectile_hit(
		projectile_aim_position + Vector3(-14.0, 0.0, 0.0),
		projectile_aim_position + Vector3(14.0, 0.0, 0.0),
		1.0,
		Vector3.RIGHT * 180.0
	)
	for _frame_index in range(4):
		projectile_controller.update_active_chunks(projectile_streamer.get_active_chunk_entries(), projectile_player_position, 0.1)

	var projectile_center_id := str(projectile_cluster.get("center_id", ""))
	var projectile_witness_a := projectile_controller.get_state_snapshot(str(projectile_cluster.get("witness_a_id", "")))
	var projectile_witness_b := projectile_controller.get_state_snapshot(str(projectile_cluster.get("witness_b_id", "")))
	var projectile_far := projectile_controller.get_state_snapshot(str(projectile_cluster.get("far_id", "")))
	var projectile_snapshot: Dictionary = projectile_controller.get_global_snapshot()
	print("CITY_PEDESTRIAN_WITNESS_PROJECTILE %s" % JSON.stringify({
		"cluster": projectile_cluster,
		"hit_result": hit_result,
		"witness_a": projectile_witness_a,
		"witness_b": projectile_witness_b,
		"far": projectile_far,
		"global_snapshot": projectile_snapshot,
	}))

	if not T.require_true(self, str(hit_result.get("pedestrian_id", "")) == projectile_center_id, "Projectile witness response must keep the direct-hit victim deterministic instead of striking a bystander"):
		return
	if not T.require_true(self, ["panic", "flee"].has(str(projectile_witness_a.get("reaction_state", ""))), "Projectile direct-hit casualty must push witness A into panic-or-flee state"):
		return
	if not T.require_true(self, ["panic", "flee"].has(str(projectile_witness_b.get("reaction_state", ""))), "Projectile direct-hit casualty must push witness B into panic-or-flee state"):
		return
	if not T.require_true(self, not ["panic", "flee"].has(str(projectile_far.get("reaction_state", ""))), "Projectile witness response must keep pedestrians beyond 400m calm"):
		return
	if not T.require_true(self, int(projectile_snapshot.get("tier3_count", 0)) <= int(projectile_snapshot.get("tier3_budget", 24)), "Projectile witness response must stay within the Tier 3 hard cap"):
		return

	var explosion_runtime := _setup_runtime()
	var explosion_cluster := _find_explosion_cluster(explosion_runtime)
	if not T.require_true(self, not explosion_cluster.is_empty(), "Witness flee response test requires an explosion cluster with threat-ring, witness-ring and a calm outsider beyond 420m"):
		return

	var explosion_streamer: CityChunkStreamer = explosion_runtime.get("streamer")
	var explosion_controller: CityPedestrianTierController = explosion_runtime.get("controller")
	var explosion_center_position: Vector3 = explosion_cluster.get("center_position", Vector3.ZERO)
	var explosion_player_position := explosion_center_position + Vector3(2.0, 0.0, 2.0)
	explosion_streamer.update_for_world_position(explosion_player_position)
	explosion_controller.set_player_context(explosion_player_position, Vector3.ZERO)
	explosion_controller.update_active_chunks(explosion_streamer.get_active_chunk_entries(), explosion_player_position, 0.25)
	var explosion_result: Dictionary = explosion_controller.resolve_explosion_impact(explosion_center_position, LETHAL_RADIUS_M, THREAT_RADIUS_M)
	for _frame_index in range(4):
		explosion_controller.update_active_chunks(explosion_streamer.get_active_chunk_entries(), explosion_player_position, 0.1)

	var threat_snapshot := explosion_controller.get_state_snapshot(str(explosion_cluster.get("threat_id", "")))
	var witness_snapshot := explosion_controller.get_state_snapshot(str(explosion_cluster.get("witness_id", "")))
	var far_snapshot := explosion_controller.get_state_snapshot(str(explosion_cluster.get("far_id", "")))
	var explosion_snapshot: Dictionary = explosion_controller.get_global_snapshot()
	print("CITY_PEDESTRIAN_WITNESS_EXPLOSION %s" % JSON.stringify({
		"cluster": explosion_cluster,
		"explosion_result": explosion_result,
		"threat_snapshot": threat_snapshot,
		"witness_snapshot": witness_snapshot,
		"far_snapshot": far_snapshot,
		"global_snapshot": explosion_snapshot,
	}))

	if not T.require_true(self, int(explosion_result.get("killed_count", 0)) >= 1, "Explosion witness response must still kill at least one lethal-radius pedestrian"):
		return
	if not T.require_true(self, ["panic", "flee"].has(str(threat_snapshot.get("reaction_state", ""))), "Explosion threat-ring survivor must still enter panic-or-flee state"):
		return
	if not T.require_true(self, ["panic", "flee"].has(str(witness_snapshot.get("reaction_state", ""))), "Explosion witness-ring survivor must enter panic-or-flee state even outside the direct threat radius"):
		return
	if not T.require_true(self, not ["panic", "flee"].has(str(far_snapshot.get("reaction_state", ""))), "Explosion witness response must keep pedestrians beyond 400m calm"):
		return
	if not T.require_true(self, int(explosion_snapshot.get("tier3_count", 0)) <= int(explosion_snapshot.get("tier3_budget", 24)), "Explosion witness response must stay within the Tier 3 hard cap"):
		return

	T.pass_and_quit(self)

func _setup_runtime() -> Dictionary:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)
	return {
		"streamer": streamer,
		"controller": controller,
	}

func _find_projectile_cluster(runtime: Dictionary) -> Dictionary:
	var streamer: CityChunkStreamer = runtime.get("streamer")
	var controller: CityPedestrianTierController = runtime.get("controller")
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		streamer.update_for_world_position(search_position)
		controller.update_active_chunks(streamer.get_active_chunk_entries(), search_position, 0.25)
		var cluster := _pick_projectile_cluster(controller.get_global_snapshot())
		if not cluster.is_empty():
			return cluster
	return {}

func _find_explosion_cluster(runtime: Dictionary) -> Dictionary:
	var streamer: CityChunkStreamer = runtime.get("streamer")
	var controller: CityPedestrianTierController = runtime.get("controller")
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		streamer.update_for_world_position(search_position)
		controller.update_active_chunks(streamer.get_active_chunk_entries(), search_position, 0.25)
		var cluster := _pick_explosion_cluster(controller.get_global_snapshot())
		if not cluster.is_empty():
			return cluster
	return {}

func _pick_projectile_cluster(snapshot: Dictionary) -> Dictionary:
	var states := _collect_states(snapshot)
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
		var center_position: Vector3 = center.get("world_position", Vector3.ZERO)
		var threat_candidate := {}
		var witness_candidate := {}
		var far_candidate := {}
		for other_variant in states:
			var other: Dictionary = other_variant
			if str(other.get("pedestrian_id", "")) == str(center.get("pedestrian_id", "")):
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

func _resolve_projectile_aim_position(state: Dictionary) -> Vector3:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var height_m := float(state.get("height_m", 1.75))
	return world_position + Vector3.UP * maxf(height_m * 0.5, 0.9)
