extends RefCounted

func includes_state(state, player_position: Vector3, budget_contract: Dictionary, threat_regions: Array, nearfield_runtime, suppress_player_midfield: bool = false) -> bool:
	if state == null or not state.is_alive():
		return false
	if nearfield_runtime != null and nearfield_runtime.includes_state(state, player_position, budget_contract):
		return false
	var midfield_radius_m := float(budget_contract.get("violent_witness_core_radius_m", 200.0))
	if not suppress_player_midfield and _planar_distance_to(player_position, state.world_position) <= midfield_radius_m:
		return true
	for threat_region_variant in threat_regions:
		var threat_region: Dictionary = threat_region_variant
		if _state_inside_threat_region(state, threat_region):
			return true
	return false

func _state_inside_threat_region(state, threat_region: Dictionary) -> bool:
	var region_radius_m := float(threat_region.get("radius_m", 0.0))
	if region_radius_m <= 0.0:
		return false
	var region_position: Vector3 = threat_region.get("position", Vector3.ZERO)
	return _planar_distance_to(region_position, state.world_position) <= region_radius_m

func _planar_distance_to(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
