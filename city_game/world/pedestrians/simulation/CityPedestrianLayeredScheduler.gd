extends RefCounted

const CityPedestrianFarfieldRuntime := preload("res://city_game/world/pedestrians/simulation/CityPedestrianFarfieldRuntime.gd")
const CityPedestrianMidfieldRuntime := preload("res://city_game/world/pedestrians/simulation/CityPedestrianMidfieldRuntime.gd")
const CityPedestrianNearfieldRuntime := preload("res://city_game/world/pedestrians/simulation/CityPedestrianNearfieldRuntime.gd")

var _farfield_runtime := CityPedestrianFarfieldRuntime.new()
var _midfield_runtime := CityPedestrianMidfieldRuntime.new()
var _nearfield_runtime := CityPedestrianNearfieldRuntime.new()

func build_context(active_states: Array, player_position: Vector3, budget_contract: Dictionary, threat_regions: Array, player_context: Dictionary = {}) -> Dictionary:
	var farfield_states: Array = []
	var midfield_states: Array = []
	var nearfield_states: Array = []
	var assignment_candidate_states: Array = []
	var threat_candidate_states: Array = []
	var suppress_player_midfield := _is_inspection_context(player_context)
	for state_variant in active_states:
		var state = state_variant
		if state == null or not state.is_alive():
			continue
		if _nearfield_runtime.includes_state(state, player_position, budget_contract):
			nearfield_states.append(state)
			assignment_candidate_states.append(state)
			threat_candidate_states.append(state)
			continue
		if _midfield_runtime.includes_state(state, player_position, budget_contract, threat_regions, _nearfield_runtime, suppress_player_midfield):
			midfield_states.append(state)
			assignment_candidate_states.append(state)
			threat_candidate_states.append(state)
			continue
		if _farfield_runtime.includes_state(state, player_position, budget_contract, threat_regions, _nearfield_runtime, _midfield_runtime, suppress_player_midfield):
			farfield_states.append(state)
	return {
		"farfield_states": farfield_states,
		"midfield_states": midfield_states,
		"nearfield_states": nearfield_states,
		"assignment_candidate_states": assignment_candidate_states,
		"threat_candidate_states": threat_candidate_states,
	}

func _is_inspection_context(player_context: Dictionary) -> bool:
	if player_context.is_empty():
		return false
	var control_mode := str(player_context.get("control_mode", ""))
	if control_mode == "inspection":
		return true
	var speed_profile := str(player_context.get("speed_profile", ""))
	return speed_profile == "inspection"
