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

	if not T.require_true(self, controller.has_method("get_state_snapshot"), "Tier controller must expose get_state_snapshot() for identity continuity validation"):
		return

	var origin := Vector3.ZERO
	streamer.update_for_world_position(origin)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin, 0.25)

	var initial_snapshot: Dictionary = controller.get_global_snapshot()
	var tier1_states: Array = initial_snapshot.get("tier1_states", [])
	if not T.require_true(self, not tier1_states.is_empty(), "Identity continuity test requires at least one Tier 1 pedestrian state"):
		return

	var promoted_candidate: Dictionary = tier1_states[0]
	var pedestrian_id := str(promoted_candidate.get("pedestrian_id", ""))
	var target_world_position: Vector3 = promoted_candidate.get("world_position", Vector3.ZERO)
	var initial_state_snapshot: Dictionary = controller.get_state_snapshot(pedestrian_id)
	if not T.require_true(self, str(initial_state_snapshot.get("tier", "")) == "tier1", "Selected continuity candidate must begin in Tier 1"):
		return

	streamer.update_for_world_position(target_world_position)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), target_world_position, 0.25)
	var promoted_state_snapshot: Dictionary = controller.get_state_snapshot(pedestrian_id)
	if not T.require_true(self, str(promoted_state_snapshot.get("tier", "")) == "tier3", "Approaching the candidate must promote it into Tier 3 once reactive nearfield takes over"):
		return
	if not T.require_true(self, ["yield", "sidestep"].has(str(promoted_state_snapshot.get("reaction_state", ""))), "Reactive nearfield promotion must attach a proximity reaction state"):
		return
	if not T.require_true(self, str(promoted_state_snapshot.get("pedestrian_id", "")) == pedestrian_id, "Pedestrian ID must remain stable after promotion"):
		return
	if not T.require_true(self, str(promoted_state_snapshot.get("route_signature", "")) == str(initial_state_snapshot.get("route_signature", "")), "Route signature must remain stable after promotion"):
		return
	if not T.require_true(self, str(promoted_state_snapshot.get("archetype_signature", "")) == str(initial_state_snapshot.get("archetype_signature", "")), "Archetype signature must remain stable after promotion"):
		return

	streamer.update_for_world_position(origin)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin, 0.25)
	var demoted_state_snapshot: Dictionary = controller.get_state_snapshot(pedestrian_id)
	print("CITY_PEDESTRIAN_IDENTITY_CONTINUITY %s" % JSON.stringify(demoted_state_snapshot))

	if not T.require_true(self, str(demoted_state_snapshot.get("tier", "")) == "tier1", "Moving away from the candidate must demote it back into Tier 1 after the reactive nearfield is cleared"):
		return
	if not T.require_true(self, str(demoted_state_snapshot.get("reaction_state", "")) == "none", "Leaving the reactive nearfield must clear the transient proximity reaction"):
		return
	if not T.require_true(self, str(demoted_state_snapshot.get("pedestrian_id", "")) == pedestrian_id, "Pedestrian ID must remain stable after demotion"):
		return
	if not T.require_true(self, str(demoted_state_snapshot.get("route_signature", "")) == str(initial_state_snapshot.get("route_signature", "")), "Route signature must remain stable after demotion"):
		return
	if not T.require_true(self, str(demoted_state_snapshot.get("archetype_signature", "")) == str(initial_state_snapshot.get("archetype_signature", "")), "Archetype signature must remain stable after demotion"):
		return

	T.pass_and_quit(self)
