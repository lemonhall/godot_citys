extends Node3D

@export var block_columns := 4
@export var block_rows := 4
@export var block_span := 18.0
@export var road_width := 8.0
@export var building_padding := 2.5

var _block_count := 0

func _ready() -> void:
	_rebuild_city()

func get_block_count() -> int:
	return _block_count

func get_city_summary() -> String:
	return "%d x %d blocks generated for the first city slice" % [block_columns, block_rows]

func _rebuild_city() -> void:
	for child in get_children():
		child.queue_free()

	_block_count = 0
	var spacing := block_span + road_width
	var origin := Vector3(
		-float(block_columns - 1) * spacing * 0.5,
		0.0,
		-float(block_rows - 1) * spacing * 0.5
	)

	_add_road_grid(origin, spacing)

	for x in block_columns:
		for z in block_rows:
			var center := Vector3(
				origin.x + float(x) * spacing,
				0.0,
				origin.z + float(z) * spacing
			)
			_add_block(x, z, center)
			_block_count += 1

func _add_road_grid(origin: Vector3, spacing: float) -> void:
	var total_width := float(block_columns - 1) * spacing + block_span + road_width * 2.0
	var total_depth := float(block_rows - 1) * spacing + block_span + road_width * 2.0
	var road_color := Color(0.11, 0.12, 0.14, 1.0)
	var lane_color := Color(0.92, 0.79, 0.27, 1.0)

	for column in block_columns + 1:
		var x := origin.x - block_span * 0.5 - road_width * 0.5 + float(column) * spacing
		_add_decal_box(
			"Road_NS_%d" % column,
			Vector3(road_width, 0.08, total_depth),
			Vector3(x, 0.04, origin.z + float(block_rows - 1) * spacing * 0.5),
			road_color
		)
		_add_decal_box(
			"Lane_NS_%d" % column,
			Vector3(0.35, 0.09, total_depth),
			Vector3(x, 0.045, origin.z + float(block_rows - 1) * spacing * 0.5),
			lane_color
		)

	for row in block_rows + 1:
		var z := origin.z - block_span * 0.5 - road_width * 0.5 + float(row) * spacing
		_add_decal_box(
			"Road_EW_%d" % row,
			Vector3(total_width, 0.08, road_width),
			Vector3(origin.x + float(block_columns - 1) * spacing * 0.5, 0.04, z),
			road_color
		)
		_add_decal_box(
			"Lane_EW_%d" % row,
			Vector3(total_width, 0.09, 0.35),
			Vector3(origin.x + float(block_columns - 1) * spacing * 0.5, 0.045, z),
			lane_color
		)

func _add_block(grid_x: int, grid_z: int, center: Vector3) -> void:
	var podium_size := Vector3(block_span, 0.4, block_span)
	_add_decal_box(
		"Podium_%d_%d" % [grid_x, grid_z],
		podium_size,
		center + Vector3(0.0, 0.2, 0.0),
		Color(0.72, 0.72, 0.68, 1.0)
	)

	var height_seed := float(((grid_x + 1) * 11 + (grid_z + 3) * 7) % 8)
	var building_height := 10.0 + height_seed * 2.0
	var building_size := Vector3(
		block_span - building_padding * 2.0,
		building_height,
		block_span - building_padding * 2.0
	)
	var accent := Color(
		0.22 + float(grid_x) * 0.08,
		0.34 + float(grid_z) * 0.05,
		0.46 + float((grid_x + grid_z) % 3) * 0.07,
		1.0
	)
	_add_static_box(
		"Tower_%d_%d" % [grid_x, grid_z],
		building_size,
		center + Vector3(0.0, building_height * 0.5, 0.0),
		accent
	)

func _add_static_box(node_name: String, size: Vector3, center: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _make_box_mesh(size)
	mesh_instance.material_override = _make_material(color)
	body.add_child(mesh_instance)

	add_child(body)

func _add_decal_box(node_name: String, size: Vector3, center: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = center
	mesh_instance.mesh = _make_box_mesh(size)
	mesh_instance.material_override = _make_material(color)
	add_child(mesh_instance)

func _make_box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
