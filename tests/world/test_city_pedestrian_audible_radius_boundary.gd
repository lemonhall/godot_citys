extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianReactionModel := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd")
const CityPedestrianState := preload("res://city_game/world/pedestrians/simulation/CityPedestrianState.gd")

const EVENT_ORIGIN := Vector3.ZERO
const CORE_RADIUS_M := 200.0
const OUTER_RADIUS_M := 400.0
const CORE_INSIDE_RADIUS_M := 199.5
const MID_RING_REACTIVE_RADIUS_M := 260.0
const MID_RING_CALM_RADIUS_M := 320.0
const OUTSIDE_RADIUS_M := 400.5
const MID_RING_REACTIVE_SEED := 103
const MID_RING_CALM_SEED := 104
const MIN_FLEE_DURATION_SEC := 20.0
const MAX_FLEE_DURATION_SEC := 35.0

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
	var inside_state := _build_state("gunshot_inside", CORE_INSIDE_RADIUS_M, 120)
	var mid_reactive_state := _build_state("gunshot_mid_reactive", MID_RING_REACTIVE_RADIUS_M, MID_RING_REACTIVE_SEED)
	var mid_calm_state := _build_state("gunshot_mid_calm", MID_RING_CALM_RADIUS_M, MID_RING_CALM_SEED)
	var outside_state := _build_state("gunshot_outside", OUTSIDE_RADIUS_M)
	var active_states := [inside_state, mid_reactive_state, mid_calm_state, outside_state]
	var budget_contract := {
		"violent_witness_core_radius_m": CORE_RADIUS_M,
		"violent_witness_outer_response_ratio": 0.4,
		"gunshot_radius_m": OUTER_RADIUS_M,
		"flee_duration_min_sec": MIN_FLEE_DURATION_SEC,
		"flee_duration_max_sec": MAX_FLEE_DURATION_SEC,
		"player_near_radius_m": 6.5,
		"player_personal_space_m": 3.25,
	}

	reaction_model.update_reactions(active_states, budget_contract, 0.0)
	print("CITY_PEDESTRIAN_GUNSHOT_RADIUS_BOUNDARY %s" % JSON.stringify({
		"inside": inside_state.to_snapshot(),
		"mid_reactive": mid_reactive_state.to_snapshot(),
		"mid_calm": mid_calm_state.to_snapshot(),
		"outside": outside_state.to_snapshot(),
	}))

	if not T.require_true(self, str(inside_state.reaction_state) == "panic", "Gunshot inside 200m core radius must always trigger panic"):
		return false
	if not T.require_true(self, str(mid_reactive_state.reaction_state) == "panic", "Gunshot inside the 200m-400m ring must still trigger panic for deterministic sampled witnesses"):
		return false
	if not T.require_true(self, str(mid_calm_state.reaction_state) == "none", "Gunshot inside the 200m-400m ring must leave unsampled witnesses calm"):
		return false
	if not T.require_true(self, str(outside_state.reaction_state) == "none", "Gunshot beyond 400m must stay calm"):
		return false
	if not T.require_true(self, float(mid_reactive_state.reaction_timer_sec) >= MIN_FLEE_DURATION_SEC, "Sampled gunshot witness must carry at least a 20s flee timer budget"):
		return false
	if not T.require_true(self, float(mid_reactive_state.reaction_timer_sec) <= MAX_FLEE_DURATION_SEC + 0.25, "Sampled gunshot witness must not exceed the 35s flee timer ceiling"):
		return false
	return true

func _run_casualty_boundary() -> bool:
	var reaction_model := CityPedestrianReactionModel.new()
	reaction_model.set_player_context(EVENT_ORIGIN, Vector3.ZERO)
	reaction_model.notify_casualty_event(EVENT_ORIGIN, OUTER_RADIUS_M)
	var inside_state := _build_state("casualty_inside", -CORE_INSIDE_RADIUS_M, 144)
	var mid_reactive_state := _build_state("casualty_mid_reactive", -MID_RING_REACTIVE_RADIUS_M, MID_RING_REACTIVE_SEED)
	var mid_calm_state := _build_state("casualty_mid_calm", -MID_RING_CALM_RADIUS_M, MID_RING_CALM_SEED)
	var outside_state := _build_state("casualty_outside", -OUTSIDE_RADIUS_M)
	var active_states := [inside_state, mid_reactive_state, mid_calm_state, outside_state]
	var budget_contract := {
		"violent_witness_core_radius_m": CORE_RADIUS_M,
		"violent_witness_outer_response_ratio": 0.4,
		"casualty_witness_radius_m": OUTER_RADIUS_M,
		"flee_duration_min_sec": MIN_FLEE_DURATION_SEC,
		"flee_duration_max_sec": MAX_FLEE_DURATION_SEC,
		"flee_scatter_angle_deg": 42.0,
		"player_near_radius_m": 6.5,
		"player_personal_space_m": 3.25,
	}

	reaction_model.update_reactions(active_states, budget_contract, 0.0)
	print("CITY_PEDESTRIAN_CASUALTY_RADIUS_BOUNDARY %s" % JSON.stringify({
		"inside": inside_state.to_snapshot(),
		"mid_reactive": mid_reactive_state.to_snapshot(),
		"mid_calm": mid_calm_state.to_snapshot(),
		"outside": outside_state.to_snapshot(),
		"inside_target_distance_m": inside_state.world_position.distance_to(inside_state.flee_target_position),
		"mid_reactive_target_distance_m": mid_reactive_state.world_position.distance_to(mid_reactive_state.flee_target_position),
	}))

	if not T.require_true(self, str(inside_state.reaction_state) == "flee", "Casualty inside 200m core radius must always trigger flee"):
		return false
	if not T.require_true(self, str(mid_reactive_state.reaction_state) == "flee", "Casualty inside the 200m-400m ring must still trigger flee for deterministic sampled witnesses"):
		return false
	if not T.require_true(self, str(mid_calm_state.reaction_state) == "none", "Casualty inside the 200m-400m ring must leave unsampled witnesses calm"):
		return false
	if not T.require_true(self, str(outside_state.reaction_state) == "none", "Casualty beyond 400m must stay calm"):
		return false
	if not T.require_true(self, float(inside_state.reaction_timer_sec) >= MIN_FLEE_DURATION_SEC, "Core casualty witness must keep at least a 20s flee timer budget"):
		return false
	if not T.require_true(self, float(mid_reactive_state.reaction_timer_sec) <= MAX_FLEE_DURATION_SEC + 0.25, "Mid-ring casualty witness must stay within the 35s flee timer ceiling"):
		return false
	if not T.require_true(self, inside_state.world_position.distance_to(inside_state.flee_target_position) < 200.0, "Core casualty witness must no longer be assigned a legacy 500m flee target"):
		return false
	if not T.require_true(self, mid_reactive_state.world_position.distance_to(mid_reactive_state.flee_target_position) < 200.0, "Mid-ring casualty witness must no longer be assigned a legacy 500m flee target"):
		return false
	return true

func _build_state(label: String, start_x: float, seed_value: int = 0) -> CityPedestrianState:
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
		"seed": seed_value if seed_value != 0 else label.hash(),
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
