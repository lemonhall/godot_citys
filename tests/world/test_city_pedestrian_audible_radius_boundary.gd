extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianReactionModel := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd")
const CityPedestrianState := preload("res://city_game/world/pedestrians/simulation/CityPedestrianState.gd")

const EVENT_ORIGIN := Vector3.ZERO
const REACTION_RADIUS_M := 500.0
const OUTSIDE_RADIUS_M := 500.5
const INSIDE_RADIUS_M := 499.5

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _run_gunshot_boundary():
		return
	if not _run_casualty_boundary():
		return
	T.pass_and_quit(self)

func _run_gunshot_boundary() -> bool:
	var reaction_model := CityPedestrianReactionModel.new()
	reaction_model.set_player_context(EVENT_ORIGIN, Vector3.ZERO)
	reaction_model.notify_projectile_event(EVENT_ORIGIN, Vector3.RIGHT, 36.0)
	var inside_state := _build_state("gunshot_inside", INSIDE_RADIUS_M)
	var edge_state := _build_state("gunshot_edge", REACTION_RADIUS_M)
	var outside_state := _build_state("gunshot_outside", OUTSIDE_RADIUS_M)
	var active_states := [inside_state, edge_state, outside_state]
	var budget_contract := {
		"gunshot_radius_m": REACTION_RADIUS_M,
		"flee_min_distance_m": REACTION_RADIUS_M,
		"player_near_radius_m": 6.5,
		"player_personal_space_m": 3.25,
	}

	reaction_model.update_reactions(active_states, budget_contract, 0.0)
	print("CITY_PEDESTRIAN_GUNSHOT_RADIUS_BOUNDARY %s" % JSON.stringify({
		"inside": inside_state.to_snapshot(),
		"edge": edge_state.to_snapshot(),
		"outside": outside_state.to_snapshot(),
	}))

	if not T.require_true(self, str(inside_state.reaction_state) == "panic", "Gunshot at 499.5m must trigger panic"):
		return false
	if not T.require_true(self, str(edge_state.reaction_state) == "panic", "Gunshot at exactly 500m must still trigger panic"):
		return false
	if not T.require_true(self, str(outside_state.reaction_state) == "none", "Gunshot beyond 500m must stay calm"):
		return false
	return true

func _run_casualty_boundary() -> bool:
	var reaction_model := CityPedestrianReactionModel.new()
	reaction_model.set_player_context(EVENT_ORIGIN, Vector3.ZERO)
	reaction_model.notify_casualty_event(EVENT_ORIGIN, REACTION_RADIUS_M)
	var inside_state := _build_state("casualty_inside", -INSIDE_RADIUS_M)
	var edge_state := _build_state("casualty_edge", -REACTION_RADIUS_M)
	var outside_state := _build_state("casualty_outside", -OUTSIDE_RADIUS_M)
	var active_states := [inside_state, edge_state, outside_state]
	var budget_contract := {
		"casualty_witness_radius_m": REACTION_RADIUS_M,
		"flee_min_distance_m": REACTION_RADIUS_M,
		"flee_scatter_angle_deg": 42.0,
		"player_near_radius_m": 6.5,
		"player_personal_space_m": 3.25,
	}

	reaction_model.update_reactions(active_states, budget_contract, 0.0)
	print("CITY_PEDESTRIAN_CASUALTY_RADIUS_BOUNDARY %s" % JSON.stringify({
		"inside": inside_state.to_snapshot(),
		"edge": edge_state.to_snapshot(),
		"outside": outside_state.to_snapshot(),
		"inside_target_distance_m": inside_state.world_position.distance_to(inside_state.flee_target_position),
		"edge_target_distance_m": edge_state.world_position.distance_to(edge_state.flee_target_position),
	}))

	if not T.require_true(self, str(inside_state.reaction_state) == "flee", "Casualty at 499.5m must trigger flee"):
		return false
	if not T.require_true(self, str(edge_state.reaction_state) == "flee", "Casualty at exactly 500m must still trigger flee"):
		return false
	if not T.require_true(self, str(outside_state.reaction_state) == "none", "Casualty beyond 500m must stay calm"):
		return false
	if not T.require_true(self, inside_state.world_position.distance_to(inside_state.flee_target_position) >= REACTION_RADIUS_M - 0.05, "Inside casualty witness must be assigned a 500m flee target"):
		return false
	if not T.require_true(self, edge_state.world_position.distance_to(edge_state.flee_target_position) >= REACTION_RADIUS_M - 0.05, "Edge casualty witness must be assigned a 500m flee target"):
		return false
	return true

func _build_state(label: String, start_x: float) -> CityPedestrianState:
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
		"world_position": Vector3(start_x, 0.0, 0.0),
		"lane_points": [
			Vector3(start_x - 50.0, 0.0, 0.0),
			Vector3(start_x + 50.0, 0.0, 0.0),
		],
		"lane_length_m": 100.0,
		"tint": Color(0.7, 0.74, 0.78, 1.0),
	})
	return state
