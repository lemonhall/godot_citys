extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const LETHAL_RADIUS_M := 4.0
const THREAT_RADIUS_M := 12.0
const CALM_MIN_DISTANCE_M := 420.0
const SEARCH_POSITIONS := [
	Vector3(-1280.0, 0.0, -1024.0),
	Vector3(-2048.0, 0.0, 0.0),
	Vector3(-2048.0, 0.0, -768.0),
	Vector3(-1792.0, 0.0, -768.0),
	Vector3(-2048.0, 0.0, -512.0),
	Vector3.ZERO,
	Vector3(-1200.0, 0.0, 26.0),
	Vector3(-600.0, 0.0, 26.0),
	Vector3(768.0, 0.0, 26.0),
	Vector3(1792.0, 0.0, 512.0),
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var chunk_streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)

	if not T.require_true(self, controller.has_method("resolve_explosion_impact"), "Tier controller must expose resolve_explosion_impact() for lethal-radius kill and threat-radius flee validation"):
		return

	var cluster_search := _find_explosion_cluster(chunk_streamer, controller)
	var baseline_snapshot: Dictionary = cluster_search.get("snapshot", {})
	var cluster: Dictionary = cluster_search.get("cluster", {})
	if not T.require_true(self, not cluster.is_empty(), "Grenade kill-and-flee test requires a center victim, a threat-ring pedestrian and a calm outsider beyond 420m"):
		return

	var center_position: Vector3 = cluster.get("center_position", Vector3.ZERO)
	var player_position := center_position + Vector3(2.0, 0.0, 2.0)
	controller.set_player_context(player_position, Vector3.ZERO)
	var explosion_result: Dictionary = controller.resolve_explosion_impact(center_position, LETHAL_RADIUS_M, THREAT_RADIUS_M)
	controller.update_active_chunks(chunk_streamer.get_active_chunk_entries(), player_position, 0.1)

	var lethal_id := str(cluster.get("lethal_id", ""))
	var threat_id := str(cluster.get("threat_id", ""))
	var far_id := str(cluster.get("far_id", ""))
	var lethal_snapshot: Dictionary = controller.get_state_snapshot(lethal_id)
	var threat_snapshot: Dictionary = controller.get_state_snapshot(threat_id)
	var far_snapshot: Dictionary = controller.get_state_snapshot(far_id)
	var post_explosion_snapshot: Dictionary = controller.get_global_snapshot()

	print("CITY_PEDESTRIAN_GRENADE_KILL_AND_FLEE %s" % JSON.stringify({
		"explosion_result": explosion_result,
		"cluster": cluster,
		"lethal_snapshot": lethal_snapshot,
		"threat_snapshot": threat_snapshot,
		"far_snapshot": far_snapshot,
		"global_snapshot": post_explosion_snapshot,
	}))

	if not T.require_true(self, str(lethal_snapshot.get("life_state", "")) == "dead", "Explosion lethal radius must kill the direct victim pedestrian"):
		return
	if not T.require_true(self, ["panic", "flee"].has(str(threat_snapshot.get("reaction_state", ""))), "Explosion threat radius must push nearby survivors into panic-or-flee state"):
		return
	if not T.require_true(self, str(threat_snapshot.get("life_state", "alive")) == "alive", "Threat-radius survivors must stay alive instead of being incorrectly deleted"):
		return
	if not T.require_true(self, not ["panic", "flee"].has(str(far_snapshot.get("reaction_state", ""))), "Pedestrians beyond 400m must stay calm instead of joining a full-map panic cascade"):
		return
	if not T.require_true(self, str(far_snapshot.get("life_state", "alive")) == "alive", "Pedestrians outside the threat radius must remain alive"):
		return
	if not T.require_true(self, int(post_explosion_snapshot.get("tier3_count", 0)) <= int(post_explosion_snapshot.get("tier3_budget", 24)), "Explosion flee response must stay within the Tier 3 hard cap"):
		return
	if not T.require_true(self, int(post_explosion_snapshot.get("active_state_count", 0)) <= int(baseline_snapshot.get("active_state_count", 0)), "Explosion resolution must not leak new active pedestrians into the live roster"):
		return

	T.pass_and_quit(self)

func _find_explosion_cluster(chunk_streamer: CityChunkStreamer, controller: CityPedestrianTierController) -> Dictionary:
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		chunk_streamer.update_for_world_position(search_position)
		controller.update_active_chunks(chunk_streamer.get_active_chunk_entries(), search_position, 0.25)
		var snapshot: Dictionary = controller.get_global_snapshot()
		var cluster := _pick_explosion_cluster(snapshot)
		if not cluster.is_empty():
			return {
				"snapshot": snapshot,
				"cluster": cluster,
			}
	return {
		"snapshot": {},
		"cluster": {},
	}

func _pick_explosion_cluster(snapshot: Dictionary) -> Dictionary:
	var states := _collect_states(snapshot)
	for center_variant in states:
		var center: Dictionary = center_variant
		var center_position: Vector3 = center.get("world_position", Vector3.ZERO)
		var threat_candidate := {}
		var far_candidate := {}
		for other_variant in states:
			var other: Dictionary = other_variant
			if str(other.get("pedestrian_id", "")) == str(center.get("pedestrian_id", "")):
				continue
			var distance_m := center_position.distance_to(other.get("world_position", Vector3.ZERO))
			if threat_candidate.is_empty() and distance_m > LETHAL_RADIUS_M + 0.75 and distance_m <= THREAT_RADIUS_M - 0.75:
				threat_candidate = other
			elif far_candidate.is_empty() and distance_m >= CALM_MIN_DISTANCE_M:
				far_candidate = other
		if threat_candidate.is_empty() or far_candidate.is_empty():
			continue
		return {
			"center_position": center_position,
			"lethal_id": str(center.get("pedestrian_id", "")),
			"threat_id": str(threat_candidate.get("pedestrian_id", "")),
			"far_id": str(far_candidate.get("pedestrian_id", "")),
		}
	return {}

func _collect_states(snapshot: Dictionary) -> Array:
	var states: Array = []
	for tier_key in ["tier2_states", "tier1_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			states.append(state_variant)
	return states
