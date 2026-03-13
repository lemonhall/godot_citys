extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const INSPECTION_VELOCITY := Vector3(96.0, 0.0, 0.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)

	var origin := Vector3.ZERO
	streamer.update_for_world_position(origin)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin, 0.25)
	var baseline_snapshot: Dictionary = controller.get_global_snapshot()
	var candidate := _pick_candidate_state(baseline_snapshot)
	if not T.require_true(self, not candidate.is_empty(), "Inspection non-threat test requires a pedestrian candidate near the origin"):
		return

	var pedestrian_id := str(candidate.get("pedestrian_id", ""))
	var player_position: Vector3 = candidate.get("world_position", Vector3.ZERO) + Vector3(0.8, 0.0, 0.8)
	controller.set_player_context(player_position, INSPECTION_VELOCITY, {"control_mode": "inspection"})
	controller.update_active_chunks(streamer.get_active_chunk_entries(), player_position, 0.25)
	var inspection_state: Dictionary = controller.get_state_snapshot(pedestrian_id)
	print("CITY_PEDESTRIAN_INSPECTION_NON_THREAT_BASELINE %s" % JSON.stringify(inspection_state))

	if not T.require_true(self, str(inspection_state.get("tier", "")) == "tier3", "Inspection proximity must still promote the nearby pedestrian into Tier 3"):
		return
	if not T.require_true(self, str(inspection_state.get("reaction_state", "")) == "yield", "Inspection high-speed approach must stay non-threatening and only request a gentle yield"):
		return

	var gunshot_origin: Vector3 = candidate.get("world_position", Vector3.ZERO) + Vector3(0.0, 0.0, -12.0)
	controller.notify_projectile_event(gunshot_origin, Vector3.RIGHT, 36.0)
	controller.set_player_context(player_position, INSPECTION_VELOCITY, {"control_mode": "inspection"})
	controller.update_active_chunks(streamer.get_active_chunk_entries(), player_position, 0.12)
	var gunshot_state: Dictionary = controller.get_state_snapshot(pedestrian_id)
	print("CITY_PEDESTRIAN_INSPECTION_NON_THREAT_GUNSHOT %s" % JSON.stringify(gunshot_state))

	if not T.require_true(self, ["panic", "flee"].has(str(gunshot_state.get("reaction_state", ""))), "Inspection mode must not suppress real projectile/gunshot panic responses"):
		return

	T.pass_and_quit(self)

func _pick_candidate_state(snapshot: Dictionary) -> Dictionary:
	for tier_key in ["tier2_states", "tier1_states"]:
		var states: Array = snapshot.get(tier_key, [])
		if not states.is_empty():
			return states[0]
	return {}
