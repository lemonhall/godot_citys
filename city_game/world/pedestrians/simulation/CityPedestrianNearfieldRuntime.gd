extends RefCounted

func includes_state(state, player_position: Vector3, budget_contract: Dictionary) -> bool:
	if state == null or not state.is_alive():
		return false
	var nearfield_radius_m := float(budget_contract.get("tier2_radius_m", 96.0))
	return _planar_distance_to(player_position, state.world_position) <= nearfield_radius_m

func _planar_distance_to(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
