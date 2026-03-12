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
	var chunk_streamer := CityChunkStreamer.new(config, world_data)
	var controller := CityPedestrianTierController.new()
	controller.setup(config, world_data)

	if not T.require_true(self, controller.has_method("resolve_projectile_hit"), "Tier controller must expose resolve_projectile_hit() for direct-hit civilian kill validation"):
		return

	var origin := Vector3.ZERO
	chunk_streamer.update_for_world_position(origin)
	controller.update_active_chunks(chunk_streamer.get_active_chunk_entries(), origin, 0.25)
	var baseline_snapshot: Dictionary = controller.get_global_snapshot()
	var candidate := _pick_candidate_state(baseline_snapshot)
	if not T.require_true(self, not candidate.is_empty(), "Projectile kill test requires an active pedestrian candidate"):
		return

	var pedestrian_id := str(candidate.get("pedestrian_id", ""))
	var candidate_position: Vector3 = candidate.get("world_position", Vector3.ZERO)
	var player_position := candidate_position + Vector3(2.0, 0.0, 2.0)
	controller.set_player_context(player_position, Vector3.ZERO)
	var hit_result: Dictionary = controller.resolve_projectile_hit(
		candidate_position + Vector3(-14.0, 0.9, 0.0),
		candidate_position + Vector3(14.0, 0.9, 0.0),
		1.0,
		Vector3.RIGHT * 180.0
	)
	controller.update_active_chunks(chunk_streamer.get_active_chunk_entries(), player_position, 0.1)
	var dead_snapshot: Dictionary = controller.get_state_snapshot(pedestrian_id)
	var post_hit_snapshot: Dictionary = controller.get_global_snapshot()

	print("CITY_PEDESTRIAN_PROJECTILE_KILL %s" % JSON.stringify({
		"hit_result": hit_result,
		"state_snapshot": dead_snapshot,
		"global_snapshot": post_hit_snapshot,
	}))

	if not T.require_true(self, str(hit_result.get("pedestrian_id", "")) == pedestrian_id, "Projectile direct-hit resolution must report the struck pedestrian"):
		return
	if not T.require_true(self, str(dead_snapshot.get("life_state", "")) == "dead", "Projectile direct hit must mark the struck pedestrian as dead"):
		return
	if not T.require_true(self, not _snapshot_contains_pedestrian(post_hit_snapshot, pedestrian_id), "Projectile direct-hit victim must leave the live crowd roster and active render set"):
		return
	if not T.require_true(self, int(post_hit_snapshot.get("active_state_count", 0)) < int(baseline_snapshot.get("active_state_count", 0)), "Projectile direct-hit kill must shrink the live active-state count instead of leaving ghost pedestrians behind"):
		return

	T.pass_and_quit(self)

func _pick_candidate_state(snapshot: Dictionary) -> Dictionary:
	for tier_key in ["tier2_states", "tier1_states"]:
		var states: Array = snapshot.get(tier_key, [])
		if not states.is_empty():
			return states[0]
	return {}

func _snapshot_contains_pedestrian(snapshot: Dictionary, pedestrian_id: String) -> bool:
	for tier_key in ["tier1_states", "tier2_states", "tier3_states"]:
		var states: Array = snapshot.get(tier_key, [])
		for state_variant in states:
			var state: Dictionary = state_variant
			if str(state.get("pedestrian_id", "")) == pedestrian_id:
				return true
	return false
