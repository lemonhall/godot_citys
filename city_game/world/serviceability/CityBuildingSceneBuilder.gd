extends RefCounted

const BUILDING_ORNAMENT_OVERLAP_M := 0.08

static var _shared_box_shape_cache: Dictionary = {}
static var _shared_box_mesh_cache: Dictionary = {}
static var _shared_box_material_cache: Dictionary = {}

static func build_runtime_building(building: Dictionary, apply_inspection_payload: bool = true) -> StaticBody3D:
	var collision_size: Vector3 = building.get("collision_size", building.get("size", Vector3(18.0, 24.0, 18.0)))
	var building_root := _build_static_box(
		str(building.get("name", "Building")),
		building.get("center", Vector3.ZERO),
		building.get("size", Vector3(18.0, 24.0, 18.0)),
		building.get("main_color", Color(0.72, 0.74, 0.78, 1.0)),
		float(building.get("yaw_rad", 0.0)),
		collision_size
	)
	var building_id := str(building.get("building_id", ""))
	if building_id != "":
		building_root.set_meta("city_building_id", building_id)
	building_root.set_meta("city_generated_building", true)
	var inspection_payload: Dictionary = building.get("inspection_payload", {})
	if apply_inspection_payload and not inspection_payload.is_empty():
		building_root.set_meta("city_inspection_payload", inspection_payload.duplicate(true))
	var size: Vector3 = building.get("size", Vector3.ONE)
	var accent: Color = building.get("accent_color", Color(0.52, 0.58, 0.66, 1.0))
	var roof: Color = building.get("roof_color", accent)
	var archetype_id := str(building.get("archetype_id", "mass"))
	match archetype_id:
		"slab":
			var fin_size := Vector3(0.9, size.y * 0.92, size.z + 0.2)
			_add_side_box(building_root, "FinWest", size, "west", 0.0, 0.0, fin_size, accent)
			_add_side_box(building_root, "FinEast", size, "east", 0.0, 0.0, fin_size, accent)
		"needle":
			var crown_size := Vector3(size.x * 0.56, maxf(size.y * 0.16, 2.6), size.z * 0.56)
			var spire_size := Vector3(size.x * 0.18, 3.6, size.z * 0.18)
			_add_roof_box(building_root, "Crown", size, Vector2.ZERO, crown_size, roof)
			_add_roof_stack_box(building_root, "Spire", size, Vector2.ZERO, crown_size.y - BUILDING_ORNAMENT_OVERLAP_M, spire_size, accent)
		"courtyard":
			var wing_size := Vector3(size.x, size.y * 0.22, size.z * 0.22)
			var roof_frame_size := Vector3(size.x * 0.82, maxf(size.y * 0.08, 1.4), size.z * 0.82)
			_add_side_box(building_root, "WingNorth", size, "north", 0.0, 0.0, wing_size, accent)
			_add_side_box(building_root, "WingSouth", size, "south", 0.0, 0.0, wing_size, accent)
			_add_roof_box(building_root, "RoofFrame", size, Vector2.ZERO, roof_frame_size, roof)
		"podium_tower":
			var podium_size := Vector3(size.x * 1.9, maxf(size.y * 0.24, 5.0), size.z * 1.9)
			var cap_size := Vector3(size.x * 0.5, maxf(size.y * 0.1, 1.6), size.z * 0.5)
			_add_ground_box(building_root, "Podium", size, Vector2.ZERO, podium_size, accent)
			_add_roof_box(building_root, "Cap", size, Vector2.ZERO, cap_size, roof)
		"step_midrise":
			var setback_a_size := Vector3(size.x * 0.78, maxf(size.y * 0.2, 2.0), size.z * 0.78)
			var setback_b_size := Vector3(size.x * 0.56, maxf(size.y * 0.14, 1.6), size.z * 0.56)
			_add_roof_box(building_root, "SetbackA", size, Vector2.ZERO, setback_a_size, accent)
			_add_roof_stack_box(building_root, "SetbackB", size, Vector2.ZERO, setback_a_size.y - BUILDING_ORNAMENT_OVERLAP_M, setback_b_size, roof)
		"midrise_bar":
			var roof_unit_size := Vector3(size.x * 0.22, maxf(size.y * 0.12, 1.4), size.z * 0.24)
			_add_roof_box(building_root, "RoofUnitA", size, Vector2(-size.x * 0.18, 0.0), roof_unit_size, roof)
			_add_roof_box(building_root, "RoofUnitB", size, Vector2(size.x * 0.18, 0.0), roof_unit_size, accent)
		"industrial":
			var sawtooth_a_size := Vector3(size.x * 0.24, maxf(size.y * 0.18, 1.8), size.z * 0.88)
			var sawtooth_b_size := Vector3(size.x * 0.24, maxf(size.y * 0.14, 1.6), size.z * 0.88)
			_add_roof_box(building_root, "SawToothA", size, Vector2(-size.x * 0.18, 0.0), sawtooth_a_size, roof)
			_add_roof_box(building_root, "SawToothB", size, Vector2(size.x * 0.18, 0.0), sawtooth_b_size, accent)
	return building_root

static func build_service_scene_root(building: Dictionary) -> Node3D:
	var building_id := str(building.get("building_id", ""))
	var display_name := str(building.get("display_name", ""))
	var service_root := Node3D.new()
	service_root.name = "ServiceBuildingRoot"
	service_root.set_meta("city_service_scene_root", true)
	if building_id != "":
		service_root.set_meta("city_building_id", building_id)
	if display_name != "":
		service_root.set_meta("city_building_display_name", display_name)
	var local_contract := to_service_local_building_contract(building)
	var generated_building := build_runtime_building(local_contract)
	generated_building.name = "GeneratedBuilding"
	service_root.add_child(generated_building)
	_assign_owner_recursive(service_root, service_root)
	return service_root

static func to_service_local_building_contract(building: Dictionary) -> Dictionary:
	var local_contract: Dictionary = building.duplicate(true)
	var size: Vector3 = local_contract.get("size", Vector3(18.0, 24.0, 18.0))
	local_contract["center"] = Vector3(0.0, size.y * 0.5, 0.0)
	local_contract["center_2d"] = Vector2.ZERO
	local_contract["yaw_rad"] = 0.0
	return local_contract

static func resolve_ground_anchor(building: Dictionary) -> Vector3:
	var center: Vector3 = building.get("center", Vector3.ZERO)
	var size: Vector3 = building.get("size", Vector3(18.0, 24.0, 18.0))
	return Vector3(center.x, center.y - size.y * 0.5, center.z)

static func collect_collision_shapes(root: Node) -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	_collect_collision_shapes_recursive(root, shapes)
	return shapes

static func apply_inspection_payload_recursive(root: Node, payload: Dictionary) -> void:
	if root == null or payload.is_empty():
		return
	var building_id := str(payload.get("building_id", ""))
	if building_id != "" and not root.has_meta("city_building_id"):
		root.set_meta("city_building_id", building_id)
	if root is CollisionObject3D:
		root.set_meta("city_inspection_payload", payload.duplicate(true))
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		apply_inspection_payload_recursive(child_node, payload)

static func _assign_owner_recursive(root: Node, owner: Node) -> void:
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		child_node.owner = owner
		_assign_owner_recursive(child_node, owner)

static func _collect_collision_shapes_recursive(root: Node, shapes: Array[CollisionShape3D]) -> void:
	if root == null:
		return
	if root is CollisionShape3D:
		shapes.append(root as CollisionShape3D)
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		_collect_collision_shapes_recursive(child_node, shapes)

static func _build_static_box(node_name: String, center: Vector3, size: Vector3, color: Color, yaw_rad: float = 0.0, collision_size: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.rotation.y = yaw_rad

	var collision_shape := CollisionShape3D.new()
	var shape := _get_shared_box_shape(collision_size if collision_size != Vector3.ZERO else size)
	collision_shape.shape = shape
	body.add_child(collision_shape)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := _get_shared_box_mesh(size)
	mesh_instance.mesh = mesh
	var material := _get_shared_box_material(color)
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	return body

static func _add_local_box(parent: Node3D, node_name: String, local_center: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = local_center
	var mesh := _get_shared_box_mesh(size)
	mesh_instance.mesh = mesh
	var material := _get_shared_box_material(color)
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

static func _get_shared_box_shape(size: Vector3) -> BoxShape3D:
	var key := _vector3_cache_key(size)
	if _shared_box_shape_cache.has(key):
		return _shared_box_shape_cache[key]
	var shape := BoxShape3D.new()
	shape.size = size
	_shared_box_shape_cache[key] = shape
	return shape

static func _get_shared_box_mesh(size: Vector3) -> BoxMesh:
	var key := _vector3_cache_key(size)
	if _shared_box_mesh_cache.has(key):
		return _shared_box_mesh_cache[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	_shared_box_mesh_cache[key] = mesh
	return mesh

static func _get_shared_box_material(color: Color) -> StandardMaterial3D:
	var key := _color_cache_key(color)
	if _shared_box_material_cache.has(key):
		return _shared_box_material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	_shared_box_material_cache[key] = material
	return material

static func _vector3_cache_key(value: Vector3) -> String:
	return "%.3f|%.3f|%.3f" % [value.x, value.y, value.z]

static func _color_cache_key(value: Color) -> String:
	return "%.4f|%.4f|%.4f|%.4f" % [value.r, value.g, value.b, value.a]

static func _add_roof_box(parent: Node3D, node_name: String, base_size: Vector3, roof_offset_xz: Vector2, size: Vector3, color: Color) -> void:
	_add_local_box(
		parent,
		node_name,
		Vector3(
			roof_offset_xz.x,
			base_size.y * 0.5 + size.y * 0.5 - BUILDING_ORNAMENT_OVERLAP_M,
			roof_offset_xz.y
		),
		size,
		color
	)

static func _add_roof_stack_box(parent: Node3D, node_name: String, base_size: Vector3, roof_offset_xz: Vector2, stack_height_m: float, size: Vector3, color: Color) -> void:
	_add_local_box(
		parent,
		node_name,
		Vector3(
			roof_offset_xz.x,
			base_size.y * 0.5 + stack_height_m + size.y * 0.5 - BUILDING_ORNAMENT_OVERLAP_M,
			roof_offset_xz.y
		),
		size,
		color
	)

static func _add_ground_box(parent: Node3D, node_name: String, base_size: Vector3, ground_offset_xz: Vector2, size: Vector3, color: Color) -> void:
	_add_local_box(
		parent,
		node_name,
		Vector3(
			ground_offset_xz.x,
			-base_size.y * 0.5 + size.y * 0.5 - BUILDING_ORNAMENT_OVERLAP_M,
			ground_offset_xz.y
		),
		size,
		color
	)

static func _add_side_box(parent: Node3D, node_name: String, base_size: Vector3, side: String, lateral_offset_m: float, vertical_offset_m: float, size: Vector3, color: Color) -> void:
	var local_center := Vector3.ZERO
	match side:
		"west":
			local_center = Vector3(-base_size.x * 0.5 - size.x * 0.5 + BUILDING_ORNAMENT_OVERLAP_M, vertical_offset_m, lateral_offset_m)
		"east":
			local_center = Vector3(base_size.x * 0.5 + size.x * 0.5 - BUILDING_ORNAMENT_OVERLAP_M, vertical_offset_m, lateral_offset_m)
		"north":
			local_center = Vector3(lateral_offset_m, vertical_offset_m, -base_size.z * 0.5 - size.z * 0.5 + BUILDING_ORNAMENT_OVERLAP_M)
		"south":
			local_center = Vector3(lateral_offset_m, vertical_offset_m, base_size.z * 0.5 + size.z * 0.5 - BUILDING_ORNAMENT_OVERLAP_M)
		_:
			local_center = Vector3(lateral_offset_m, vertical_offset_m, 0.0)
	_add_local_box(parent, node_name, local_center, size, color)
