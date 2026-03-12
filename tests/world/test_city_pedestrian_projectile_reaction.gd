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

	if not T.require_true(self, controller.has_method("notify_projectile_event"), "Tier controller must expose notify_projectile_event() for projectile reaction validation"):
		return

	var origin := Vector3.ZERO
	streamer.update_for_world_position(origin)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin, 0.25)
	var baseline_snapshot: Dictionary = controller.get_global_snapshot()
	var candidate: Dictionary = _pick_candidate_state(baseline_snapshot)
	if not T.require_true(self, not candidate.is_empty(), "Projectile reaction test requires at least one pedestrian candidate"):
		return

	var pedestrian_id := str(candidate.get("pedestrian_id", ""))
	var candidate_position: Vector3 = candidate.get("world_position", Vector3.ZERO)
	var player_reaction_position := candidate_position + Vector3(2.0, 0.0, 2.0)
	controller.set_player_context(player_reaction_position, Vector3.ZERO)
	controller.notify_projectile_event(candidate_position + Vector3(-12.0, 0.0, 0.0), Vector3.RIGHT, 24.0)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), player_reaction_position, 0.1)
	var projectile_state: Dictionary = controller.get_state_snapshot(pedestrian_id)
	print("CITY_PEDESTRIAN_PROJECTILE_REACTION %s" % JSON.stringify(projectile_state))

	if not T.require_true(self, str(projectile_state.get("tier", "")) == "tier3", "Projectile near-miss must promote the affected pedestrian into Tier 3"):
		return
	if not T.require_true(self, ["sidestep", "panic", "flee"].has(str(projectile_state.get("reaction_state", ""))), "Projectile near-miss must trigger a dodge-or-panic reaction state"):
		return

	T.pass_and_quit(self)

func _pick_candidate_state(snapshot: Dictionary) -> Dictionary:
	for tier_key in ["tier2_states", "tier1_states"]:
		var states: Array = snapshot.get(tier_key, [])
		if not states.is_empty():
			return states[0]
	return {}
