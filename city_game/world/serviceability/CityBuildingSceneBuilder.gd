extends RefCounted

# Authoring entry point for procedurally generated city buildings.
#
# v62 replaces the old block-toy building with the CityBuildingMassingBuilder
# kit: layered massing, procedural facade, storefront glazing and a MultiMesh
# detail batch. The public contract is unchanged:
#   - build_runtime_building() -> StaticBody3D with `city_generated_building`
#   - build_service_scene_root() -> Node3D with `city_service_scene_root`
#   - one BoxShape3D collision per generated building
#   - building_id / inspection payload metadata stays on the nodes

const CityBuildingMassingBuilder := preload("res://city_game/world/rendering/buildings/CityBuildingMassingBuilder.gd")

const DEFAULT_SIZE := Vector3(18.0, 24.0, 18.0)

static var _shared_box_shape_cache: Dictionary = {}

static func build_runtime_building(building: Dictionary, apply_inspection_payload: bool = true) -> StaticBody3D:
	var size: Vector3 = building.get("size", DEFAULT_SIZE)
	var center: Vector3 = building.get("center", Vector3.ZERO)
	var collision_size: Vector3 = building.get("collision_size", size)
	var body := StaticBody3D.new()
	body.name = str(building.get("name", "Building"))
	body.position = center
	body.rotation.y = float(building.get("yaw_rad", 0.0))

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "Collision"
	collision_shape.shape = _get_shared_box_shape(collision_size if collision_size != Vector3.ZERO else size)
	body.add_child(collision_shape)

	var visual := CityBuildingMassingBuilder.build(building)
	var facade_mesh: ArrayMesh = visual.get("facade_mesh", null)
	if facade_mesh != null:
		var facade_instance := MeshInstance3D.new()
		facade_instance.name = "MeshInstance3D"
		facade_instance.mesh = facade_mesh
		facade_instance.material_override = visual.get("facade_material", null)
		body.add_child(facade_instance)

	var glass_mesh: ArrayMesh = visual.get("glass_mesh", null)
	if glass_mesh != null:
		var glass_instance := MeshInstance3D.new()
		glass_instance.name = "GlassMesh"
		glass_instance.mesh = glass_mesh
		body.add_child(glass_instance)

	var detail_boxes = visual.get("detail_boxes", null)
	if detail_boxes != null:
		var boxes_instance: MultiMeshInstance3D = detail_boxes.build(
			"DetailBoxes",
			CityBuildingMassingBuilder.unit_box_mesh(),
			CityBuildingMassingBuilder.shared_trim_material()
		)
		if boxes_instance != null:
			body.add_child(boxes_instance)

	var detail_cylinders = visual.get("detail_cylinders", null)
	if detail_cylinders != null:
		var cylinders_instance: MultiMeshInstance3D = detail_cylinders.build(
			"DetailCylinders",
			CityBuildingMassingBuilder.unit_cylinder_mesh(),
			CityBuildingMassingBuilder.shared_trim_material()
		)
		if cylinders_instance != null:
			body.add_child(cylinders_instance)

	var building_id := str(building.get("building_id", ""))
	if building_id != "":
		body.set_meta("city_building_id", building_id)
	body.set_meta("city_generated_building", true)
	body.set_meta("city_building_main_color", building.get("main_color", Color(0.55, 0.57, 0.59, 1.0)))
	body.set_meta("city_building_visual_style", int(visual.get("style", 0)))
	body.set_meta("city_building_detail_box_count", int(visual.get("detail_box_count", 0)))
	body.set_meta("city_building_triangle_count", int(visual.get("triangle_count", 0)))
	body.set_meta("city_building_floor_count", int(visual.get("floor_count", 0)))
	body.set_meta("city_building_bay_count", int(visual.get("bay_count_x", 0)))
	body.set_meta("city_building_bay_m", float(visual.get("bay_m", 0.0)))
	body.set_meta("city_building_floor_m", float(visual.get("floor_m", 0.0)))
	var inspection_payload: Dictionary = building.get("inspection_payload", {})
	if apply_inspection_payload and not inspection_payload.is_empty():
		body.set_meta("city_inspection_payload", inspection_payload.duplicate(true))
	return body

static func build_service_scene_root(building: Dictionary, assign_owner_recursive: bool = false) -> Node3D:
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
	if assign_owner_recursive:
		_assign_owner_recursive(service_root, service_root)
	return service_root

static func to_service_local_building_contract(building: Dictionary) -> Dictionary:
	var local_contract: Dictionary = building.duplicate(true)
	var size: Vector3 = local_contract.get("size", DEFAULT_SIZE)
	local_contract["center"] = Vector3(0.0, size.y * 0.5, 0.0)
	local_contract["center_2d"] = Vector2.ZERO
	local_contract["yaw_rad"] = 0.0
	return local_contract

static func resolve_ground_anchor(building: Dictionary) -> Vector3:
	var center: Vector3 = building.get("center", Vector3.ZERO)
	var size: Vector3 = building.get("size", DEFAULT_SIZE)
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

static func _get_shared_box_shape(size: Vector3) -> BoxShape3D:
	var key := "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if _shared_box_shape_cache.has(key):
		return _shared_box_shape_cache[key]
	var shape := BoxShape3D.new()
	shape.size = size
	_shared_box_shape_cache[key] = shape
	return shape
