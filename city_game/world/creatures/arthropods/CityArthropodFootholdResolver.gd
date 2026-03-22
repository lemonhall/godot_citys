extends RefCounted
class_name CityArthropodFootholdResolver

var _resolver: Callable = Callable()

func configure(resolver: Callable = Callable()) -> void:
	_resolver = resolver

func resolve_foothold(leg_id: String, desired_foothold: Vector3, fallback_surface_normal: Vector3 = Vector3.UP) -> Dictionary:
	if _resolver.is_valid():
		return _normalize_resolution(_resolver.call(leg_id, desired_foothold), desired_foothold, fallback_surface_normal)
	var projected := desired_foothold
	projected.y = 0.0
	return {
		"success": true,
		"leg_id": leg_id,
		"world_position": projected,
		"surface_normal": fallback_surface_normal.normalized(),
		"source": "flat_ground_projection",
	}

func _normalize_resolution(result: Variant, desired_foothold: Vector3, fallback_surface_normal: Vector3) -> Dictionary:
	if result is Vector3:
		return {
			"success": true,
			"world_position": result,
			"surface_normal": fallback_surface_normal.normalized(),
			"source": "callable_vector3",
		}
	if result is Dictionary:
		var resolved: Dictionary = (result as Dictionary).duplicate(true)
		if not resolved.has("world_position"):
			resolved["world_position"] = desired_foothold
		if not resolved.has("surface_normal"):
			resolved["surface_normal"] = fallback_surface_normal.normalized()
		if not resolved.has("success"):
			resolved["success"] = true
		return resolved
	return {
		"success": false,
		"error": "unresolved_foothold",
		"world_position": desired_foothold,
		"surface_normal": fallback_surface_normal.normalized(),
	}
