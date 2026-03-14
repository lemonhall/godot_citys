extends MultiMeshInstance3D

const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")

var _cached_instance_transforms: Array = []

func _init() -> void:
	name = "VehicleBatch"
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var vehicle_multimesh := MultiMesh.new()
	vehicle_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	vehicle_multimesh.mesh = mesh
	multimesh = vehicle_multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.06, 0.08, 0.28)
	material.roughness = 1.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func configure_from_states(states: Array, chunk_center: Vector3, visual_catalog: CityVehicleVisualCatalog = null) -> int:
	if multimesh == null:
		return 0
	var instance_count_changed := multimesh.instance_count != states.size()
	if instance_count_changed:
		multimesh.instance_count = states.size()
	var previous_cache_size := _cached_instance_transforms.size()
	if previous_cache_size < states.size():
		_cached_instance_transforms.resize(states.size())
	var transform_write_count := 0
	for state_index in range(states.size()):
		var state = states[state_index]
		var instance_transform := _build_instance_transform(state, chunk_center, visual_catalog)
		var cached_transform = _cached_instance_transforms[state_index]
		var requires_write := instance_count_changed or state_index >= previous_cache_size or not _transforms_equal(cached_transform, instance_transform)
		if requires_write:
			multimesh.set_instance_transform(state_index, instance_transform)
			_cached_instance_transforms[state_index] = instance_transform
			transform_write_count += 1
	set_meta("vehicle_tier1_count", states.size())
	set_meta("vehicle_tier1_transform_write_count", transform_write_count)
	if _cached_instance_transforms.size() > states.size():
		_cached_instance_transforms.resize(states.size())
	return transform_write_count

func _build_instance_transform(state, chunk_center: Vector3, visual_catalog: CityVehicleVisualCatalog) -> Transform3D:
	var world_position := _state_world_position(state)
	var local_position := world_position - chunk_center
	var heading := _state_heading(state)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	var yaw := atan2(heading.x, heading.z)
	var dimensions := _resolve_dimensions(state, visual_catalog)
	var shadow_width := float(dimensions.get("width_m", 1.9)) * 1.6
	var shadow_length := float(dimensions.get("length_m", 4.4)) * 1.9
	var instance_basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3(
		shadow_width,
		1.0,
		shadow_length
	))
	instance_basis = Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)) * instance_basis
	return Transform3D(
		instance_basis,
		Vector3(local_position.x, local_position.y + 0.08, local_position.z)
	)

func _resolve_dimensions(state, visual_catalog: CityVehicleVisualCatalog) -> Dictionary:
	var dimensions := {
		"length_m": _state_length_m(state),
		"width_m": _state_width_m(state),
		"height_m": _state_height_m(state),
	}
	if visual_catalog == null:
		return dimensions
	if dimensions["length_m"] > 0.0 and dimensions["width_m"] > 0.0 and dimensions["height_m"] > 0.0:
		return dimensions
	return visual_catalog.resolve_dimensions_m(visual_catalog.select_entry_for_state(state))

func _state_world_position(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("world_position", Vector3.ZERO)
	return state.world_position if state != null else Vector3.ZERO

func _state_heading(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("heading", Vector3.FORWARD)
	return state.heading if state != null else Vector3.FORWARD

func _state_length_m(state) -> float:
	if state is Dictionary:
		return float((state as Dictionary).get("length_m", 4.4))
	return float(state.length_m) if state != null else 4.4

func _state_width_m(state) -> float:
	if state is Dictionary:
		return float((state as Dictionary).get("width_m", 1.9))
	return float(state.width_m) if state != null else 1.9

func _state_height_m(state) -> float:
	if state is Dictionary:
		return float((state as Dictionary).get("height_m", 1.5))
	return float(state.height_m) if state != null else 1.5

func _transforms_equal(lhs, rhs) -> bool:
	if not lhs is Transform3D or not rhs is Transform3D:
		return false
	var left: Transform3D = lhs
	var right: Transform3D = rhs
	return left.origin.is_equal_approx(right.origin) \
		and left.basis.x.is_equal_approx(right.basis.x) \
		and left.basis.y.is_equal_approx(right.basis.y) \
		and left.basis.z.is_equal_approx(right.basis.z)
