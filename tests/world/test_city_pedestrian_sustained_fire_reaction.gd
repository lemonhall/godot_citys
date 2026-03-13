extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianReactionModel := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd")
const CityPedestrianState := preload("res://city_game/world/pedestrians/simulation/CityPedestrianState.gd")

const PLAYER_POSITION := Vector3.ZERO
const SHOT_RANGE_M := 36.0
const VIOLENT_REACTIONS := ["panic", "flee"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var reaction_model := CityPedestrianReactionModel.new()
	var state := _build_state("burst_witness", Vector3(0.0, 0.0, 6.0))
	var active_states := [state]
	var budget_contract := _build_budget_contract()

	reaction_model.set_player_context(PLAYER_POSITION, Vector3.ZERO)
	reaction_model.notify_projectile_event(PLAYER_POSITION, Vector3.RIGHT, SHOT_RANGE_M)
	reaction_model.update_reactions(active_states, budget_contract, 0.0)
	if not T.require_true(self, str(state.reaction_state) == "panic", "Initial off-path gunshot must push the witness into panic before burst-fire hold validation"):
		return

	var reaction_history: Array[String] = [str(state.reaction_state)]
	for path_z in [5.0, 5.2, 4.8, 5.1]:
		state.step(0.12)
		reaction_model.notify_projectile_event(Vector3(0.0, 0.0, path_z), Vector3.RIGHT, SHOT_RANGE_M)
		reaction_model.update_reactions(active_states, budget_contract, 0.12)
		reaction_history.append(str(state.reaction_state))

	print("CITY_PEDESTRIAN_SUSTAINED_FIRE_REACTION %s" % JSON.stringify({
		"reaction_history": reaction_history,
		"final_snapshot": state.to_snapshot(),
	}))

	for reaction_state in reaction_history:
		if not T.require_true(self, VIOLENT_REACTIONS.has(reaction_state), "Burst-fire hold must keep witnesses in panic/flee instead of downgrading to sidestep/walk"):
			return

	T.pass_and_quit(self)

func _build_budget_contract() -> Dictionary:
	return {
		"violent_witness_core_radius_m": 200.0,
		"violent_witness_outer_response_ratio": 0.4,
		"gunshot_radius_m": 400.0,
		"projectile_reaction_radius_m": 4.5,
		"flee_duration_min_sec": 20.0,
		"flee_duration_max_sec": 35.0,
		"flee_scatter_angle_deg": 42.0,
		"player_near_radius_m": 6.5,
		"player_personal_space_m": 3.25,
		"player_fast_speed_mps": 10.0,
	}

func _build_state(label: String, start_position: Vector3) -> CityPedestrianState:
	var state := CityPedestrianState.new()
	state.setup({
		"pedestrian_id": label,
		"chunk_id": "chunk:test",
		"page_id": "page:test",
		"spawn_slot_id": "slot:%s" % label,
		"road_id": "road:test",
		"lane_ref_id": "lane:%s" % label,
		"route_signature": "route:%s" % label,
		"archetype_id": "resident",
		"archetype_signature": "resident:v0",
		"seed": label.hash(),
		"height_m": 1.75,
		"radius_m": 0.28,
		"speed_mps": 1.25,
		"stride_phase": 0.0,
		"route_progress": 0.5,
		"world_position": start_position,
		"lane_points": [
			start_position + Vector3(-50.0, 0.0, 0.0),
			start_position + Vector3(50.0, 0.0, 0.0),
		],
		"lane_length_m": 100.0,
		"tint": Color(0.7, 0.74, 0.78, 1.0),
	})
	return state
