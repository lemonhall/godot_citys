extends MultiMeshInstance3D

const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")
const BODY_COLOR_PALETTES := {
	"civilian": [
		Color(0.76, 0.79, 0.84, 1.0),
		Color(0.64, 0.69, 0.76, 1.0),
		Color(0.73, 0.72, 0.68, 1.0),
		Color(0.60, 0.62, 0.66, 1.0),
		Color(0.69, 0.74, 0.71, 1.0),
	],
	"service": [
		Color(0.44, 0.54, 0.82, 1.0),
		Color(0.78, 0.82, 0.88, 1.0),
		Color(0.36, 0.42, 0.70, 1.0),
	],
	"commercial": [
		Color(0.82, 0.66, 0.36, 1.0),
		Color(0.74, 0.58, 0.30, 1.0),
		Color(0.68, 0.62, 0.52, 1.0),
	],
}

static var _shared_vehicle_mesh: ArrayMesh = null
static var _shared_vehicle_material: StandardMaterial3D = null

var _cached_instance_transforms: Array = []
var _cached_instance_colors: Array = []

func _init() -> void:
	name = "VehicleBatch"
	var vehicle_multimesh := MultiMesh.new()
	vehicle_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	vehicle_multimesh.use_colors = true
	vehicle_multimesh.mesh = _get_shared_vehicle_mesh()
	multimesh = vehicle_multimesh
	material_override = _get_shared_vehicle_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func configure_from_states(states: Array, chunk_center: Vector3, visual_catalog: CityVehicleVisualCatalog = null) -> int:
	if multimesh == null:
		return 0
	var instance_count_changed := multimesh.instance_count != states.size()
	if instance_count_changed:
		multimesh.instance_count = states.size()
	var previous_transform_cache_size := _cached_instance_transforms.size()
	if previous_transform_cache_size < states.size():
		_cached_instance_transforms.resize(states.size())
	var previous_color_cache_size := _cached_instance_colors.size()
	if previous_color_cache_size < states.size():
		_cached_instance_colors.resize(states.size())
	var transform_write_count := 0
	for state_index in range(states.size()):
		var state = states[state_index]
		var instance_transform := _build_instance_transform(state, chunk_center, visual_catalog)
		var cached_transform = _cached_instance_transforms[state_index]
		var transform_requires_write := instance_count_changed or state_index >= previous_transform_cache_size or not _transforms_equal(cached_transform, instance_transform)
		if transform_requires_write:
			multimesh.set_instance_transform(state_index, instance_transform)
			_cached_instance_transforms[state_index] = instance_transform
			transform_write_count += 1
		var instance_color := _resolve_instance_color(state, visual_catalog)
		var cached_color = _cached_instance_colors[state_index]
		var color_requires_write := instance_count_changed or state_index >= previous_color_cache_size or not _colors_equal(cached_color, instance_color)
		if color_requires_write:
			multimesh.set_instance_color(state_index, instance_color)
			_cached_instance_colors[state_index] = instance_color
	set_meta("vehicle_tier1_count", states.size())
	set_meta("vehicle_tier1_transform_write_count", transform_write_count)
	if _cached_instance_transforms.size() > states.size():
		_cached_instance_transforms.resize(states.size())
	if _cached_instance_colors.size() > states.size():
		_cached_instance_colors.resize(states.size())
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
	var vehicle_width := maxf(float(dimensions.get("width_m", 1.9)), 0.6)
	var vehicle_height := maxf(float(dimensions.get("height_m", 1.5)), 0.6)
	var vehicle_length := maxf(float(dimensions.get("length_m", 4.4)), 1.2)
	var instance_basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3(
		vehicle_width,
		vehicle_height,
		vehicle_length
	))
	return Transform3D(
		instance_basis,
		Vector3(local_position.x, local_position.y + vehicle_height * 0.5 + 0.02, local_position.z)
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

func _resolve_instance_color(state, visual_catalog: CityVehicleVisualCatalog) -> Color:
	var role := _state_role(state)
	var palette: Array = BODY_COLOR_PALETTES.get(role, BODY_COLOR_PALETTES["civilian"])
	if palette.is_empty():
		return Color(0.72, 0.76, 0.82, 1.0)
	var seed_value := _state_seed(state)
	var model_hash: int = abs(_state_model_id(state).hash())
	var palette_index: int = int(posmod(seed_value + model_hash * 3, palette.size()))
	var base_color: Color = palette[palette_index]
	if visual_catalog == null:
		return base_color
	return base_color.lerp(visual_catalog.resolve_role_color(role), 0.18)

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

func _state_role(state) -> String:
	if state is Dictionary:
		return str((state as Dictionary).get("traffic_role", "civilian"))
	return str(state.traffic_role) if state != null else "civilian"

func _state_model_id(state) -> String:
	if state is Dictionary:
		return str((state as Dictionary).get("model_id", ""))
	return str(state.model_id) if state != null else ""

func _state_seed(state) -> int:
	if state is Dictionary:
		return int((state as Dictionary).get("seed", 0))
	return int(state.seed_value) if state != null else 0

func _transforms_equal(lhs, rhs) -> bool:
	if not lhs is Transform3D or not rhs is Transform3D:
		return false
	var left: Transform3D = lhs
	var right: Transform3D = rhs
	return left.origin.is_equal_approx(right.origin) \
		and left.basis.x.is_equal_approx(right.basis.x) \
		and left.basis.y.is_equal_approx(right.basis.y) \
		and left.basis.z.is_equal_approx(right.basis.z)

func _colors_equal(lhs, rhs) -> bool:
	if not lhs is Color or not rhs is Color:
		return false
	var left: Color = lhs
	var right: Color = rhs
	return is_equal_approx(left.r, right.r) \
		and is_equal_approx(left.g, right.g) \
		and is_equal_approx(left.b, right.b) \
		and is_equal_approx(left.a, right.a)

static func _get_shared_vehicle_mesh() -> ArrayMesh:
	if _shared_vehicle_mesh != null:
		return _shared_vehicle_mesh
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.0, 0.52, 1.0)
	surface_tool.append_from(body_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.24, 0.0)))
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(0.68, 0.48, 0.46)
	surface_tool.append_from(cabin_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.26, -0.08)))
	surface_tool.generate_normals()
	_shared_vehicle_mesh = surface_tool.commit()
	return _shared_vehicle_mesh

static func _get_shared_vehicle_material() -> StandardMaterial3D:
	if _shared_vehicle_material != null:
		return _shared_vehicle_material
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	material.metallic = 0.04
	_shared_vehicle_material = material
	return _shared_vehicle_material
