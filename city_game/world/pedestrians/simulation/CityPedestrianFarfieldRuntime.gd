extends RefCounted

func includes_state(state, player_position: Vector3, budget_contract: Dictionary, threat_regions: Array, nearfield_runtime, midfield_runtime, suppress_player_midfield: bool = false) -> bool:
	if state == null or not state.is_alive():
		return false
	if nearfield_runtime != null and nearfield_runtime.includes_state(state, player_position, budget_contract):
		return false
	if midfield_runtime != null and midfield_runtime.includes_state(state, player_position, budget_contract, threat_regions, nearfield_runtime, suppress_player_midfield):
		return false
	return true
