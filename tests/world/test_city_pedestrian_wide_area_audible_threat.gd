extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const REACTION_RADIUS_M := 500.0
const REACTIVE_MIN_DISTANCE_M := 350.0
const REACTIVE_MAX_DISTANCE_M := 480.0
const CALM_MIN_DISTANCE_M := 520.0
const ORIGIN_CLEARANCE_M := 24.0
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
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var projectile_runtime := _setup_runtime()
	var projectile_cluster := _find_distance_ring(projectile_runtime)
	if not T.require_true(self, not projectile_cluster.is_empty(), "Wide-area audible threat test requires a gunshot witness between 350m and 480m plus a calm outsider beyond 520m"):
		return

	var projectile_streamer: CityChunkStreamer = projectile_runtime.get("streamer")
	var projectile_controller: CityPedestrianTierController = projectile_runtime.get("controller")
	var projectile_origin: Vector3 = projectile_cluster.get("origin_position", Vector3.ZERO)
	projectile_streamer.update_for_world_position(projectile_origin)
	projectile_controller.set_player_context(projectile_origin, Vector3.ZERO)
	projectile_controller.update_active_chunks(projectile_streamer.get_active_chunk_entries(), projectile_origin, 0.25)
	projectile_controller.notify_projectile_event(projectile_origin, Vector3.RIGHT, 36.0)
	for _frame_index in range(6):
		projectile_controller.update_active_chunks(projectile_streamer.get_active_chunk_entries(), projectile_origin, 0.1)
	var projectile_reactive := projectile_controller.get_state_snapshot(str(projectile_cluster.get("reactive_id", "")))
	var projectile_far := projectile_controller.get_state_snapshot(str(projectile_cluster.get("far_id", "")))
	print("CITY_PEDESTRIAN_WIDE_GUNSHOT %s" % JSON.stringify({
		"cluster": projectile_cluster,
		"reactive": projectile_reactive,
		"far": projectile_far,
		"global_snapshot": projectile_controller.get_global_snapshot(),
	}))

	if not T.require_true(self, ["panic", "flee"].has(str(projectile_reactive.get("reaction_state", ""))), "Gunshot within 500m must push the far witness into panic-or-flee state even without a hit"):
		return
	if not T.require_true(self, not ["panic", "flee"].has(str(projectile_far.get("reaction_state", ""))), "Gunshot beyond 500m must keep outsiders calm"):
		return

	var explosion_runtime := _setup_runtime()
	var explosion_cluster := _find_distance_ring(explosion_runtime)
	if not T.require_true(self, not explosion_cluster.is_empty(), "Wide-area audible threat test requires an explosion witness between 350m and 480m plus a calm outsider beyond 520m"):
		return

	var explosion_streamer: CityChunkStreamer = explosion_runtime.get("streamer")
	var explosion_controller: CityPedestrianTierController = explosion_runtime.get("controller")
	var explosion_origin: Vector3 = explosion_cluster.get("origin_position", Vector3.ZERO)
	explosion_streamer.update_for_world_position(explosion_origin)
	explosion_controller.set_player_context(explosion_origin, Vector3.ZERO)
	explosion_controller.update_active_chunks(explosion_streamer.get_active_chunk_entries(), explosion_origin, 0.25)
	var explosion_result := explosion_controller.resolve_explosion_impact(explosion_origin, 4.0, 12.0)
	for _frame_index in range(6):
		explosion_controller.update_active_chunks(explosion_streamer.get_active_chunk_entries(), explosion_origin, 0.1)
	var explosion_reactive := explosion_controller.get_state_snapshot(str(explosion_cluster.get("reactive_id", "")))
	var explosion_far := explosion_controller.get_state_snapshot(str(explosion_cluster.get("far_id", "")))
	print("CITY_PEDESTRIAN_WIDE_EXPLOSION %s" % JSON.stringify({
		"cluster": explosion_cluster,
		"explosion_result": explosion_result,
		"reactive": explosion_reactive,
		"far": explosion_far,
		"global_snapshot": explosion_controller.get_global_snapshot(),
	}))

	if not T.require_true(self, ["panic", "flee"].has(str(explosion_reactive.get("reaction_state", ""))), "Grenade explosion within 500m must push the far witness into panic-or-flee state even without a lethal kill"):
		return
	if not T.require_true(self, str(explosion_reactive.get("life_state", "alive")) == "alive", "Wide-area explosion witness must stay alive; this test is about audio panic, not casualty"):
		return
	if not T.require_true(self, not ["panic", "flee"].has(str(explosion_far.get("reaction_state", ""))), "Grenade explosion beyond 500m must keep outsiders calm"):
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

func _find_distance_ring(runtime: Dictionary) -> Dictionary:
	var streamer: CityChunkStreamer = runtime.get("streamer")
	var controller: CityPedestrianTierController = runtime.get("controller")
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		streamer.update_for_world_position(search_position)
		controller.update_active_chunks(streamer.get_active_chunk_entries(), search_position, 0.25)
		var cluster := _pick_distance_ring(controller.get_global_snapshot(), search_position)
		if not cluster.is_empty():
			return cluster
	return {}

func _pick_distance_ring(snapshot: Dictionary, origin_position: Vector3) -> Dictionary:
	var states := _collect_states(snapshot)
	if _nearest_distance_to_states(states, origin_position) <= ORIGIN_CLEARANCE_M:
		return {}
	var reactive_candidate := {}
	var far_candidate := {}
	for state_variant in states:
		var state: Dictionary = state_variant
		var distance_m := origin_position.distance_to(state.get("world_position", Vector3.ZERO))
		if reactive_candidate.is_empty() and distance_m >= REACTIVE_MIN_DISTANCE_M and distance_m <= REACTIVE_MAX_DISTANCE_M:
			reactive_candidate = state
		elif far_candidate.is_empty() and distance_m >= CALM_MIN_DISTANCE_M:
			far_candidate = state
		if not reactive_candidate.is_empty() and not far_candidate.is_empty():
			break
	if reactive_candidate.is_empty() or far_candidate.is_empty():
		return {}
	return {
		"origin_position": origin_position,
		"reactive_id": str(reactive_candidate.get("pedestrian_id", "")),
		"reactive_distance_m": origin_position.distance_to(reactive_candidate.get("world_position", Vector3.ZERO)),
		"far_id": str(far_candidate.get("pedestrian_id", "")),
		"far_distance_m": origin_position.distance_to(far_candidate.get("world_position", Vector3.ZERO)),
	}

func _collect_states(snapshot: Dictionary) -> Array:
	var states: Array = []
	for tier_key in ["tier2_states", "tier1_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			states.append(state_variant)
	return states

func _nearest_distance_to_states(states: Array, world_position: Vector3) -> float:
	var best_distance := INF
	for state_variant in states:
		var state: Dictionary = state_variant
		best_distance = minf(best_distance, world_position.distance_to(state.get("world_position", Vector3.ZERO)))
	return best_distance
