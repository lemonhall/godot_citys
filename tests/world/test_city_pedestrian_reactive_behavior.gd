extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller = CityPedestrianTierController.new()
	controller.setup(config, world_data)

	if not T.require_true(self, controller.has_method("set_player_context"), "Tier controller must expose set_player_context() for proximity-driven reactive behavior"):
		return
	if not T.require_true(self, controller.has_method("notify_explosion_event"), "Tier controller must expose notify_explosion_event() for reactive behavior validation"):
		return

	var origin := Vector3.ZERO
	streamer.update_for_world_position(origin)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin, 0.25)
	var baseline_snapshot: Dictionary = controller.get_global_snapshot()
	var candidate: Dictionary = _pick_candidate_state(baseline_snapshot)
	if not T.require_true(self, not candidate.is_empty(), "Reactive behavior test requires at least one pedestrian candidate near the origin"):
		return

	var pedestrian_id := str(candidate.get("pedestrian_id", ""))
	var player_position: Vector3 = candidate.get("world_position", Vector3.ZERO) + Vector3(0.8, 0.0, 0.8)
	controller.set_player_context(player_position, Vector3(14.0, 0.0, 0.0))
	controller.update_active_chunks(streamer.get_active_chunk_entries(), player_position, 0.25)
	var proximity_state: Dictionary = controller.get_state_snapshot(pedestrian_id)
	if not T.require_true(self, str(proximity_state.get("tier", "")) == "tier3", "A pedestrian inside the player nearfield must promote into Tier 3"):
		return
	if not T.require_true(self, ["yield", "sidestep"].has(str(proximity_state.get("reaction_state", ""))), "Player proximity must trigger a wait-or-yield reaction state"):
		return

	controller.notify_explosion_event(candidate.get("world_position", Vector3.ZERO) + Vector3(2.0, 0.0, 0.0), 10.0)
	controller.set_player_context(player_position, Vector3.ZERO)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), player_position, 0.25)
	var explosion_state: Dictionary = controller.get_state_snapshot(pedestrian_id)
	print("CITY_PEDESTRIAN_REACTIVE_BEHAVIOR %s" % JSON.stringify(explosion_state))

	if not T.require_true(self, ["panic", "flee"].has(str(explosion_state.get("reaction_state", ""))), "Explosion proximity must escalate the pedestrian into panic-or-flee state"):
		return
	if not T.require_true(self, str(explosion_state.get("tier", "")) == "tier3", "Reactive explosion response must stay within Tier 3 nearfield agents"):
		return

	T.pass_and_quit(self)

func _pick_candidate_state(snapshot: Dictionary) -> Dictionary:
	for tier_key in ["tier2_states", "tier1_states"]:
		var states: Array = snapshot.get(tier_key, [])
		if not states.is_empty():
			return states[0]
	return {}
