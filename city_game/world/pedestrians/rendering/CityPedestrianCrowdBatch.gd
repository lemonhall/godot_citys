extends MultiMeshInstance3D

const PROXY_SCENE_PATH := "res://city_game/assets/pedestrians/civilians/business_man.glb"
const PROXY_GROUND_CLEARANCE_M := 0.02
const PROXY_UNIFORM_SCALE := 2.02
const PROXY_SCALE_PROFILE := {
	"height_scale": PROXY_UNIFORM_SCALE,
	"width_scale": PROXY_UNIFORM_SCALE,
	"depth_scale": PROXY_UNIFORM_SCALE,
}

static var _shared_proxy_mesh: ArrayMesh = null
static var _shared_proxy_mesh_source := ""
static var _shared_proxy_material: StandardMaterial3D = null

var _cached_instance_transforms: Array = []
var _cached_instance_state_ids: Array[String] = []

func _init() -> void:
	name = "PedestrianBatch"
	var crowd_multimesh := MultiMesh.new()
	crowd_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	crowd_multimesh.mesh = _get_shared_proxy_mesh()
	multimesh = crowd_multimesh
	material_override = _get_shared_proxy_material()
	set_meta("pedestrian_tier1_visual_source", _get_shared_proxy_mesh_source())
	set_meta("pedestrian_tier1_proxy_scale_profile", PROXY_SCALE_PROFILE.duplicate(true))

func configure_from_states(states: Array, chunk_center: Vector3) -> int:
	if multimesh == null:
		return 0
	var state_by_id: Dictionary = {}
	var incoming_state_ids: Array[String] = []
	for state_index in range(states.size()):
		var state = states[state_index]
		var state_id := _state_slot_id(state, state_index)
		if state_by_id.has(state_id):
			continue
		state_by_id[state_id] = state
		incoming_state_ids.append(state_id)
	var next_slot_state_ids := _build_next_slot_state_ids(incoming_state_ids, state_by_id)
	var instance_count_changed := multimesh.instance_count != next_slot_state_ids.size()
	if instance_count_changed:
		multimesh.instance_count = next_slot_state_ids.size()
	var previous_cache_size := _cached_instance_transforms.size()
	if previous_cache_size < next_slot_state_ids.size():
		_cached_instance_transforms.resize(next_slot_state_ids.size())
	var transform_write_count := 0
	for state_index in range(next_slot_state_ids.size()):
		var state_id := next_slot_state_ids[state_index]
		var state = state_by_id.get(state_id)
		var instance_transform := _build_instance_transform(state, chunk_center)
		var cached_transform = _cached_instance_transforms[state_index]
		var requires_write := instance_count_changed or state_index >= previous_cache_size or not _transforms_equal(cached_transform, instance_transform)
		if requires_write:
			multimesh.set_instance_transform(state_index, instance_transform)
			_cached_instance_transforms[state_index] = instance_transform
			transform_write_count += 1
	if _cached_instance_transforms.size() > next_slot_state_ids.size():
		_cached_instance_transforms.resize(next_slot_state_ids.size())
	_cached_instance_state_ids = next_slot_state_ids
	set_meta("pedestrian_tier1_count", next_slot_state_ids.size())
	set_meta("pedestrian_tier1_transform_write_count", transform_write_count)
	return transform_write_count

func _build_next_slot_state_ids(incoming_state_ids: Array[String], state_by_id: Dictionary) -> Array[String]:
	var next_slot_state_ids: Array[String] = []
	var included_ids: Dictionary = {}
	for cached_id in _cached_instance_state_ids:
		if not state_by_id.has(cached_id) or included_ids.has(cached_id):
			continue
		next_slot_state_ids.append(cached_id)
		included_ids[cached_id] = true
	for state_id in incoming_state_ids:
		if included_ids.has(state_id):
			continue
		next_slot_state_ids.append(state_id)
		included_ids[state_id] = true
	return next_slot_state_ids

func _state_slot_id(state, state_index: int) -> String:
	var pedestrian_id := _state_pedestrian_id(state)
	if pedestrian_id != "":
		return pedestrian_id
	return "__slot_%d" % state_index

func _build_instance_transform(state, chunk_center: Vector3) -> Transform3D:
	var world_position := _state_world_position(state)
	var local_position := world_position - chunk_center
	var heading := _state_heading(state)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	var yaw := atan2(heading.x, heading.z)
	var instance_basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(
		Vector3(PROXY_UNIFORM_SCALE, PROXY_UNIFORM_SCALE, PROXY_UNIFORM_SCALE)
	)
	return Transform3D(
		instance_basis,
		Vector3(local_position.x, local_position.y + PROXY_GROUND_CLEARANCE_M, local_position.z)
	)

func _state_world_position(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("world_position", Vector3.ZERO)
	return state.world_position if state != null else Vector3.ZERO

func _state_pedestrian_id(state) -> String:
	if state is Dictionary:
		return str((state as Dictionary).get("pedestrian_id", ""))
	return str(state.pedestrian_id) if state != null else ""

func _state_heading(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("heading", Vector3.FORWARD)
	return state.heading if state != null else Vector3.FORWARD

func _transforms_equal(lhs, rhs) -> bool:
	if not lhs is Transform3D or not rhs is Transform3D:
		return false
	var left: Transform3D = lhs
	var right: Transform3D = rhs
	return left.origin.is_equal_approx(right.origin) \
		and left.basis.x.is_equal_approx(right.basis.x) \
		and left.basis.y.is_equal_approx(right.basis.y) \
		and left.basis.z.is_equal_approx(right.basis.z)

static func _get_shared_proxy_mesh() -> ArrayMesh:
	if _shared_proxy_mesh != null:
		return _shared_proxy_mesh
	var proxy_mesh := _build_proxy_scene_mesh()
	if proxy_mesh != null:
		_shared_proxy_mesh = proxy_mesh
		_shared_proxy_mesh_source = "proxy_scene:%s" % PROXY_SCENE_PATH
		return _shared_proxy_mesh
	_shared_proxy_mesh_source = "primitive_proxy:fallback"
	_shared_proxy_mesh = _build_fallback_proxy_mesh()
	return _shared_proxy_mesh

static func _get_shared_proxy_mesh_source() -> String:
	if _shared_proxy_mesh_source == "":
		_get_shared_proxy_mesh()
	return _shared_proxy_mesh_source

static func _build_proxy_scene_mesh() -> ArrayMesh:
	var scene_resource := load(PROXY_SCENE_PATH)
	var packed_scene := scene_resource as PackedScene
	if packed_scene == null:
		return null
	var instance_variant = packed_scene.instantiate()
	var proxy_root := instance_variant as Node
	if proxy_root == null:
		return null
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var appended_surface_count := _append_proxy_mesh_surfaces(proxy_root, surface_tool, Transform3D.IDENTITY)
	proxy_root.free()
	if appended_surface_count <= 0:
		return null
	surface_tool.generate_normals()
	var raw_mesh := surface_tool.commit()
	if raw_mesh == null:
		return null
	return _align_proxy_mesh_to_ground_center(raw_mesh)

static func _append_proxy_mesh_surfaces(node: Node, surface_tool: SurfaceTool, parent_transform: Transform3D) -> int:
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
		appended_surface_count += _append_proxy_mesh_surfaces(child_node, surface_tool, node_transform)
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
	var translation_transform := Transform3D(Basis.IDENTITY, translation)
	for surface_index in range(source_mesh.get_surface_count()):
		surface_tool.append_from(source_mesh, surface_index, translation_transform)
	surface_tool.generate_normals()
	return surface_tool.commit()

static func _build_fallback_proxy_mesh() -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.72, 1.18, 0.36)
	surface_tool.append_from(torso_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.02, 0.0)))
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.42, 0.42, 0.42)
	surface_tool.append_from(head_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.89, 0.0)))
	var pelvis_mesh := BoxMesh.new()
	pelvis_mesh.size = Vector3(0.62, 0.34, 0.32)
	surface_tool.append_from(pelvis_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.20, 0.0)))
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.18, 1.10, 0.18)
	surface_tool.append_from(arm_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(-0.45, 1.93, 0.0)))
	surface_tool.append_from(arm_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.45, 1.93, 0.0)))
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.22, 1.02, 0.22)
	surface_tool.append_from(leg_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(-0.17, 0.51, 0.0)))
	surface_tool.append_from(leg_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.17, 0.51, 0.0)))
	surface_tool.generate_normals()
	return surface_tool.commit()

static func _get_shared_proxy_material() -> StandardMaterial3D:
	if _shared_proxy_material != null:
		return _shared_proxy_material
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.52, 0.56, 1.0)
	material.roughness = 1.0
	_shared_proxy_material = material
	return _shared_proxy_material
