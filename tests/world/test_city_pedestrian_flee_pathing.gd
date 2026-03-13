extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianReactionModel := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd")
const CityPedestrianState := preload("res://city_game/world/pedestrians/simulation/CityPedestrianState.gd")

const PLAYER_POSITION := Vector3.ZERO
const EXPLOSION_CENTER := Vector3.ZERO
const FLEE_MIN_DURATION_SEC := 20
const FLEE_MAX_DURATION_SEC := 35
const FLEE_SPEED_MULTIPLIER := 4.0
const MAX_SIMULATION_STEPS := 48
const STEP_SEC := 1.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var reaction_model := CityPedestrianReactionModel.new()
	reaction_model.set_player_context(PLAYER_POSITION, Vector3.ZERO)
	reaction_model.notify_explosion_event(EXPLOSION_CENTER, 4.0, 12.0)

	var state_a := _build_state("a", 96, Vector3(6.0, 0.0, -1.2))
	var state_b := _build_state("b", 111, Vector3(6.0, 0.0, 1.2))
	var active_states := [state_a, state_b]
	var budget_contract := {
		"flee_duration_min_sec": FLEE_MIN_DURATION_SEC,
		"flee_duration_max_sec": FLEE_MAX_DURATION_SEC,
		"explosion_reaction_radius_m": 18.0,
		"player_near_radius_m": 6.5,
		"player_personal_space_m": 3.25,
	}

	reaction_model.update_reactions(active_states, budget_contract, 0.0)
	if not T.require_true(self, str(state_a.reaction_state) == "flee", "Explosion flee pathing test requires pedestrian A to enter flee state"):
		return
	if not T.require_true(self, str(state_b.reaction_state) == "flee", "Explosion flee pathing test requires pedestrian B to enter flee state"):
		return
	if not T.require_true(self, float(state_a.reaction_timer_sec) >= float(FLEE_MIN_DURATION_SEC), "Pedestrian A must start with at least a 20s flee timer budget"):
		return
	if not T.require_true(self, float(state_b.reaction_timer_sec) <= float(FLEE_MAX_DURATION_SEC) + 0.25, "Pedestrian B must start within the 35s flee timer ceiling"):
		return

	var start_a: Vector3 = state_a.world_position
	var start_b: Vector3 = state_b.world_position
	var first_second_start_a: Vector3 = start_a
	var first_second_start_b: Vector3 = start_b
	state_a.step(STEP_SEC)
	state_b.step(STEP_SEC)
	var first_second_distance_a := state_a.world_position.distance_to(first_second_start_a)
	var first_second_distance_b := state_b.world_position.distance_to(first_second_start_b)
	var expected_first_second_distance := float(state_a.speed_mps) * FLEE_SPEED_MULTIPLIER
	if not T.require_true(self, first_second_distance_a >= expected_first_second_distance - 0.1, "Pedestrian A must sprint at roughly 4x base speed during flee"):
		return
	if not T.require_true(self, first_second_distance_b >= expected_first_second_distance - 0.1, "Pedestrian B must sprint at roughly 4x base speed during flee"):
		return

	var previous_player_distance_a := state_a.world_position.distance_to(PLAYER_POSITION)
	var previous_player_distance_b := state_b.world_position.distance_to(PLAYER_POSITION)
	var last_moving_step_a := 1
	var last_moving_step_b := 1

	for step_index in range(MAX_SIMULATION_STEPS - 1):
		var previous_position_a := state_a.world_position
		var previous_position_b := state_b.world_position
		state_a.step(STEP_SEC)
		state_b.step(STEP_SEC)
		if state_a.world_position.distance_to(previous_position_a) > 0.05:
			last_moving_step_a = step_index + 2
		if state_b.world_position.distance_to(previous_position_b) > 0.05:
			last_moving_step_b = step_index + 2
		var player_distance_a := state_a.world_position.distance_to(PLAYER_POSITION)
		var player_distance_b := state_b.world_position.distance_to(PLAYER_POSITION)
		if not T.require_true(self, player_distance_a + 0.05 >= previous_player_distance_a, "Flee pathing must not pull pedestrian A back toward the player"):
			return
		if not T.require_true(self, player_distance_b + 0.05 >= previous_player_distance_b, "Flee pathing must not pull pedestrian B back toward the player"):
			return
		previous_player_distance_a = player_distance_a
		previous_player_distance_b = player_distance_b
		if not state_a.is_reactive() and not state_b.is_reactive():
			break

	var displacement_a := state_a.world_position - start_a
	var displacement_b := state_b.world_position - start_b
	print("CITY_PEDESTRIAN_FLEE_PATHING %s" % JSON.stringify({
		"state_a": state_a.to_snapshot(),
		"state_b": state_b.to_snapshot(),
		"displacement_a_m": displacement_a.length(),
		"displacement_b_m": displacement_b.length(),
		"last_moving_step_a": last_moving_step_a,
		"last_moving_step_b": last_moving_step_b,
	}))

	if not T.require_true(self, last_moving_step_a >= FLEE_MIN_DURATION_SEC, "Pedestrian A must keep fleeing for at least 20 simulated seconds before stopping"):
		return
	if not T.require_true(self, last_moving_step_b >= FLEE_MIN_DURATION_SEC, "Pedestrian B must keep fleeing for at least 20 simulated seconds before stopping"):
		return
	if not T.require_true(self, last_moving_step_a <= FLEE_MAX_DURATION_SEC, "Pedestrian A must stop by the 35s flee timer ceiling"):
		return
	if not T.require_true(self, last_moving_step_b <= FLEE_MAX_DURATION_SEC, "Pedestrian B must stop by the 35s flee timer ceiling"):
		return
	if not T.require_true(self, state_a.world_position.distance_to(PLAYER_POSITION) >= previous_player_distance_a, "Pedestrian A must end farther from the player than the final simulated path sample"):
		return
	if not T.require_true(self, state_b.world_position.distance_to(PLAYER_POSITION) >= previous_player_distance_b, "Pedestrian B must end farther from the player than the final simulated path sample"):
		return
	if not T.require_true(self, displacement_a.normalized().dot(displacement_b.normalized()) < 0.98, "Crowd flee response must scatter instead of sending every witness along the same direction"):
		return
	if not T.require_true(self, last_moving_step_a < last_moving_step_b, "Deterministic flee tick budget must produce varied stop times instead of every witness stopping on the same second"):
		return

	var parked_a := state_a.world_position
	var parked_b := state_b.world_position
	for _settle_index in range(5):
		state_a.step(STEP_SEC)
		state_b.step(STEP_SEC)
	if not T.require_true(self, state_a.world_position.distance_to(parked_a) <= 0.05, "Pedestrian A must stop once the flee distance budget is exhausted"):
		return
	if not T.require_true(self, state_b.world_position.distance_to(parked_b) <= 0.05, "Pedestrian B must stop once the flee distance budget is exhausted"):
		return

	T.pass_and_quit(self)

func _build_state(label: String, seed_value: int, start_position: Vector3) -> CityPedestrianState:
	var state := CityPedestrianState.new()
	state.setup({
		"pedestrian_id": "flee:%s" % label,
		"chunk_id": "chunk:test",
		"page_id": "page:test",
		"spawn_slot_id": "slot:%s" % label,
		"road_id": "road:test",
		"lane_ref_id": "lane:%s" % label,
		"route_signature": "route:%s" % label,
		"archetype_id": "resident",
		"archetype_signature": "resident:v0",
		"seed": seed_value,
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
