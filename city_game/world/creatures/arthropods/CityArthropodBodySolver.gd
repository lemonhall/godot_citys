extends RefCounted
class_name CityArthropodBodySolver

func solve_body_target(leg_states: Array, body_clearance_m: float) -> Dictionary:
	var grounded_positions: Array[Vector3] = []
	var normal_sum := Vector3.ZERO
	for leg_variant in leg_states:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		if not bool(leg_state.get("is_grounded", false)):
			continue
		grounded_positions.append(leg_state.get("locked_foothold", Vector3.ZERO))
		var surface_normal: Vector3 = leg_state.get("surface_normal", Vector3.UP)
		normal_sum += surface_normal
	var support_center := Vector3.ZERO
	for grounded_position in grounded_positions:
		support_center += grounded_position
	if not grounded_positions.is_empty():
		support_center /= float(grounded_positions.size())
	var resolved_up := Vector3.UP if normal_sum.length_squared() <= 0.0001 else normal_sum.normalized()
	return {
		"origin": support_center + resolved_up * maxf(body_clearance_m, 0.0),
		"support_center": support_center,
		"up": resolved_up,
		"grounded_leg_count": grounded_positions.size(),
	}
