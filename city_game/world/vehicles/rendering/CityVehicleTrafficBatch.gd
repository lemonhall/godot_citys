extends MultiMeshInstance3D

const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")
const PROXY_GLB_PATH := "res://city_game/assets/vehicles/proxy/tier1_proxy.glb"
const PROXY_GROUND_CLEARANCE_M := 0.02
const PROXY_SCALE_PROFILE := {
	"length_scale": 1.0,
	"width_scale": 1.0,
	"height_scale": 1.0,
}
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
static var _shared_vehicle_mesh_source := ""

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
	set_meta("vehicle_tier1_visual_source", _get_shared_vehicle_mesh_source())
	set_meta("vehicle_tier1_proxy_scale_profile", PROXY_SCALE_PROFILE.duplicate(true))

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
	var instance_basis := Basis.from_euler(Vector3(0.0, yaw, 0.0))
	return Transform3D(
		instance_basis,
		Vector3(local_position.x, local_position.y + PROXY_GROUND_CLEARANCE_M, local_position.z)
	)

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
	var proxy_glb_mesh := _build_proxy_glb_mesh()
	if proxy_glb_mesh != null:
		_shared_vehicle_mesh = proxy_glb_mesh
		_shared_vehicle_mesh_source = "proxy_glb:%s" % PROXY_GLB_PATH
		return _shared_vehicle_mesh
	_shared_vehicle_mesh_source = "primitive_proxy:fallback"
	_shared_vehicle_mesh = _build_fallback_proxy_mesh()
	return _shared_vehicle_mesh

static func _get_shared_vehicle_mesh_source() -> String:
	if _shared_vehicle_mesh_source == "":
		_get_shared_vehicle_mesh()
	return _shared_vehicle_mesh_source

static func _build_proxy_glb_mesh() -> ArrayMesh:
	var scene_resource := load(PROXY_GLB_PATH)
	var packed_scene := scene_resource as PackedScene
	if packed_scene == null:
		return null
	var instance_variant = packed_scene.instantiate()
	var model_root := instance_variant as Node
	if model_root == null:
		return null
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var appended_surface_count := _append_asset_mesh_surfaces(model_root, surface_tool, Transform3D.IDENTITY)
	model_root.free()
	if appended_surface_count <= 0:
		return null
	surface_tool.generate_normals()
	var raw_mesh := surface_tool.commit()
	if raw_mesh == null:
		return null
	return _align_proxy_mesh_to_ground_center(raw_mesh)

static func _append_asset_mesh_surfaces(node: Node, surface_tool: SurfaceTool, parent_transform: Transform3D) -> int:
	var appended_surface_count := 0
	var node_transform := parent_transform
	var node_3d := node as Node3D
	if node_3d != null:
		node_transform = parent_transform * node_3d.transform
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var source_mesh: Mesh = mesh_instance.mesh
		for surface_index in range(source_mesh.get_surface_count()):
			surface_tool.append_from(source_mesh, surface_index, node_transform)
			appended_surface_count += 1
	for child_variant in node.get_children():
		var child_node := child_variant as Node
		if child_node == null:
			continue
		appended_surface_count += _append_asset_mesh_surfaces(child_node, surface_tool, node_transform)
	return appended_surface_count

static func _align_proxy_mesh_to_ground_center(source_mesh: ArrayMesh) -> ArrayMesh:
	if source_mesh == null:
		return null
	var source_aabb := source_mesh.get_aabb()
	if source_aabb.size.x <= 0.001 or source_aabb.size.y <= 0.001 or source_aabb.size.z <= 0.001:
		return source_mesh
	var center := source_aabb.get_center()
	var translation := Vector3(-center.x, -source_aabb.position.y, -center.z)
	if translation.is_zero_approx():
		return source_mesh
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normalization_transform := Transform3D(Basis.IDENTITY, translation)
	for surface_index in range(source_mesh.get_surface_count()):
		surface_tool.append_from(source_mesh, surface_index, normalization_transform)
	surface_tool.generate_normals()
	return surface_tool.commit()

static func _build_fallback_proxy_mesh() -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.0, 0.52, 1.0)
	surface_tool.append_from(body_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.24, 0.0)))
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(0.68, 0.48, 0.46)
	surface_tool.append_from(cabin_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.26, -0.08)))
	surface_tool.generate_normals()
	return surface_tool.commit()

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
