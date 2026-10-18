extends RefCounted

# Roof access for plan landmarks: a ground pad that lifts the player to the
# landmark roof. Kept as a tiny API so the walkthrough E2E can drive it.

static func try_travel(player: Node3D, access: Node3D) -> bool:
	if player == null or access == null:
		return false
	var base := access.global_position
	if player.global_position.distance_to(base) > 3.0:
		return false
	var roof_local: Vector3 = access.get_meta("roof_local", Vector3(0.0, 100.0, 0.0))
	var target := access.to_global(roof_local)
	if player.has_method("teleport_to_world_position"):
		player.call("teleport_to_world_position", target)
	else:
		player.global_position = target
	return true
