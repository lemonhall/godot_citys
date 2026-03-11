extends Node3D

const CityChunkMultimeshBuilder := preload("res://city_game/world/rendering/CityChunkMultimeshBuilder.gd")
const CityChunkHlodBuilder := preload("res://city_game/world/rendering/CityChunkHlodBuilder.gd")
const CityChunkOccluderBuilder := preload("res://city_game/world/rendering/CityChunkOccluderBuilder.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

const LOD_NEAR := "near"
const LOD_MID := "mid"
const LOD_FAR := "far"

const NEAR_THRESHOLD_M := 440.0
const MID_THRESHOLD_M := 900.0
const TERRAIN_GRID_STEPS := 12

var _chunk_data: Dictionary = {}
var _profile: Dictionary = {}
var _current_lod_mode := LOD_NEAR
var _building_collision_shapes: Array[CollisionShape3D] = []
var _building_collisions_enabled := true

func setup(chunk_data: Dictionary) -> void:
	_chunk_data = chunk_data.duplicate(true)
	_profile = CityChunkProfileBuilder.build_profile(_chunk_data)
	name = str(_chunk_data.get("chunk_id", "ChunkScene"))
	position = _chunk_data.get("chunk_center", Vector3.ZERO)
	_rebuild()

func set_lod_mode(mode: String) -> void:
	_current_lod_mode = mode
	var near_group := get_node_or_null("NearGroup") as Node3D
	var mid_proxy := get_node_or_null("MidProxy") as Node3D
	var far_proxy := get_node_or_null("FarProxy") as Node3D
	if near_group != null:
		near_group.visible = mode == LOD_NEAR
	if mid_proxy != null:
		mid_proxy.visible = mode == LOD_MID
	if far_proxy != null:
		far_proxy.visible = mode == LOD_FAR
	_set_building_collisions_enabled(mode == LOD_NEAR)

func update_lod_for_distance(distance_m: float) -> void:
	if distance_m < NEAR_THRESHOLD_M:
		set_lod_mode(LOD_NEAR)
	elif distance_m < MID_THRESHOLD_M:
		set_lod_mode(LOD_MID)
	else:
		set_lod_mode(LOD_FAR)

func get_current_lod_mode() -> String:
	return _current_lod_mode

func get_profile_signature() -> String:
	return str(_profile.get("signature", ""))

func get_visual_variant_id() -> String:
	return str(_profile.get("variant_id", ""))

func get_lod_signature(_mode: String) -> String:
	return get_profile_signature()

func get_lod_contract() -> Dictionary:
	return {
		"chunk_id": str(_chunk_data.get("chunk_id", "")),
		"variant_id": get_visual_variant_id(),
		"profile_signature": get_profile_signature(),
		"modes": [LOD_NEAR, LOD_MID, LOD_FAR],
		"near_threshold_m": NEAR_THRESHOLD_M,
		"mid_threshold_m": MID_THRESHOLD_M,
	}

func get_prop_multimesh() -> MultiMeshInstance3D:
	return get_node("NearGroup/Props/StreetLamps") as MultiMeshInstance3D

func get_ground_body() -> StaticBody3D:
	return get_node_or_null("GroundBody") as StaticBody3D

func get_road_boundary_connectors() -> Dictionary:
	return (_profile.get("road_boundary_connectors", {}) as Dictionary).duplicate(true)

func get_building_collision_shape_count() -> int:
	return _building_collision_shapes.size()

func are_building_collisions_enabled() -> bool:
	return _building_collisions_enabled

func get_terrain_relief_m() -> float:
	return float(_profile.get("terrain_relief_m", 0.0))

func get_renderer_stats() -> Dictionary:
	var prop_multimesh := get_prop_multimesh()
	return {
		"chunk_id": str(_chunk_data.get("chunk_id", "")),
		"lod_mode": _current_lod_mode,
		"visual_variant_id": get_visual_variant_id(),
		"profile_signature": get_profile_signature(),
		"multimesh_instance_count": prop_multimesh.multimesh.instance_count if prop_multimesh != null else 0,
		"near_child_count": get_node("NearGroup").get_child_count(),
		"road_segment_count": (_profile.get("road_segments", []) as Array).size(),
		"curved_road_segment_count": int(_profile.get("curved_road_segment_count", 0)),
		"terrain_relief_m": get_terrain_relief_m(),
		"building_collision_shape_count": get_building_collision_shape_count(),
	}

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_building_collision_shapes.clear()

	var chunk_size_m := float(_chunk_data.get("chunk_size_m", 256.0))

	add_child(_build_ground_body(chunk_size_m, _profile))

	var near_group := Node3D.new()
	near_group.name = "NearGroup"
	add_child(near_group)

	near_group.add_child(_build_road_overlay(_profile))
	var props := Node3D.new()
	props.name = "Props"
	near_group.add_child(props)

	near_group.add_child(_build_podium(_profile.get("podium", {})))
	for tower in _profile.get("towers", []):
		near_group.add_child(_build_tower(tower))
	props.add_child(CityChunkMultimeshBuilder.build_street_lamps(_profile))

	add_child(CityChunkHlodBuilder.build_mid_proxy(_profile))
	add_child(CityChunkHlodBuilder.build_far_proxy(_profile))
	add_child(CityChunkOccluderBuilder.build_chunk_occluder(chunk_size_m))

	set_lod_mode(LOD_NEAR)

func _build_tower(tower: Dictionary) -> Node3D:
	var tower_root := Node3D.new()
	tower_root.name = str(tower.get("name", "Tower"))

	var center: Vector3 = tower.get("center", Vector3.ZERO)
	var size: Vector3 = tower.get("size", Vector3.ONE)
	var color: Color = tower.get("main_color", Color(0.74, 0.74, 0.78, 1.0))
	tower_root.add_child(_build_static_box("%s_Body" % tower_root.name, center, size, color))

	var band_color: Color = tower.get("band_color", color)
	var band_width := float(tower.get("band_width", 2.0))
	var band_count := int(tower.get("band_count", 2))
	for band_index in range(band_count):
		var band_y := center.y - size.y * 0.3 + float(band_index) * size.y * 0.28
		var band_size := Vector3(size.x + 0.15, maxf(size.y * 0.06, 1.6), band_width)
		var north_center := Vector3(center.x, band_y, center.z - size.z * 0.5 + band_width * 0.5)
		var south_center := Vector3(center.x, band_y, center.z + size.z * 0.5 - band_width * 0.5)
		tower_root.add_child(_build_box_instance("%s_BandNorth_%d" % [tower_root.name, band_index], north_center, band_size, band_color))
		tower_root.add_child(_build_box_instance("%s_BandSouth_%d" % [tower_root.name, band_index], south_center, band_size, band_color))
	return tower_root

func _build_podium(podium: Dictionary) -> StaticBody3D:
	return _build_static_box(
		"NearPodium",
		podium.get("center", Vector3.ZERO),
		podium.get("size", Vector3(68.0, 4.0, 62.0)),
		podium.get("color", Color(0.45, 0.47, 0.5, 1.0))
	)

func _build_static_box(name: String, center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = center

	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)
	_building_collision_shapes.append(collision_shape)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	return body

func _build_box_instance(name: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh_instance.material_override = material
	return mesh_instance

func _build_road_overlay(profile: Dictionary) -> Node3D:
	var road_root := Node3D.new()
	road_root.name = "RoadOverlay"
	var palette: Dictionary = profile.get("palette", {})
	var road_color: Color = palette.get("road", Color(0.16, 0.17, 0.19, 1.0))
	var stripe_color: Color = palette.get("stripe", Color(0.9, 0.8, 0.5, 1.0))

	for segment_index in range((profile.get("road_segments", []) as Array).size()):
		var segment: Dictionary = profile["road_segments"][segment_index]
		var points: Array = segment.get("points", [])
		var width := float(segment.get("width", 10.0))
		var is_arterial := str(segment.get("class", "secondary")) == "arterial" or width >= 12.0
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			var surface := _build_road_piece(
				"Road_%d_%d" % [segment_index, point_index],
				a,
				b,
				width,
				_tint_color(road_color, -0.04 if is_arterial else 0.0),
				0.10,
				0.05
			)
			if surface != null:
				road_root.add_child(surface)
			if is_arterial:
				var stripe := _build_road_piece(
					"Stripe_%d_%d" % [segment_index, point_index],
					a,
					b,
					0.8,
					stripe_color,
					0.03,
					0.11
				)
				if stripe != null:
					road_root.add_child(stripe)
	return road_root

func _build_road_piece(name: String, a: Vector3, b: Vector3, width: float, color: Color, height: float, y_offset: float) -> MeshInstance3D:
	var planar_delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := planar_delta.length()
	if length <= 1.0:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.position = Vector3(
		(a.x + b.x) * 0.5,
		(a.y + b.y) * 0.5 + y_offset,
		(a.z + b.z) * 0.5
	)
	mesh_instance.rotation.y = atan2(planar_delta.x, planar_delta.z)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, length)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh_instance.material_override = material
	return mesh_instance

func _build_ground_body(chunk_size_m: float, profile: Dictionary) -> StaticBody3D:
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundBody"

	var terrain_mesh := _build_terrain_mesh(chunk_size_m)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(terrain_mesh.get_faces())
	collision_shape.shape = shape
	ground_body.add_child(collision_shape)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = terrain_mesh
	var material := StandardMaterial3D.new()
	var palette: Dictionary = profile.get("palette", {})
	material.albedo_color = palette.get("ground", Color(0.12549, 0.333333, 0.168627, 1.0))
	material.roughness = 1.0
	mesh_instance.material_override = material
	ground_body.add_child(mesh_instance)
	return ground_body

func _build_terrain_mesh(chunk_size_m: float) -> ArrayMesh:
	var half_size := chunk_size_m * 0.5
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x_index in range(TERRAIN_GRID_STEPS):
		for z_index in range(TERRAIN_GRID_STEPS):
			var x0 := lerpf(-half_size, half_size, float(x_index) / float(TERRAIN_GRID_STEPS))
			var x1 := lerpf(-half_size, half_size, float(x_index + 1) / float(TERRAIN_GRID_STEPS))
			var z0 := lerpf(-half_size, half_size, float(z_index) / float(TERRAIN_GRID_STEPS))
			var z1 := lerpf(-half_size, half_size, float(z_index + 1) / float(TERRAIN_GRID_STEPS))

			var v00 := _sample_ground_vertex(x0, z0)
			var v10 := _sample_ground_vertex(x1, z0)
			var v01 := _sample_ground_vertex(x0, z1)
			var v11 := _sample_ground_vertex(x1, z1)

			_add_triangle(surface_tool, v00, v10, v11, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE)
			_add_triangle(surface_tool, v00, v11, v01, Vector2.ZERO, Vector2.ONE, Vector2.UP)
	surface_tool.generate_normals()
	return surface_tool.commit()

func _sample_ground_vertex(local_x: float, local_z: float) -> Vector3:
	var chunk_center: Vector3 = _chunk_data.get("chunk_center", Vector3.ZERO)
	var world_seed := int(_chunk_data.get("world_seed", _chunk_data.get("chunk_seed", 0)))
	var world_x := chunk_center.x + local_x
	var world_z := chunk_center.z + local_z
	return Vector3(local_x, CityTerrainSampler.sample_height(world_x, world_z, world_seed), local_z)

func _add_triangle(surface_tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	surface_tool.set_uv(uv_a)
	surface_tool.add_vertex(a)
	surface_tool.set_uv(uv_b)
	surface_tool.add_vertex(b)
	surface_tool.set_uv(uv_c)
	surface_tool.add_vertex(c)

func _set_building_collisions_enabled(enabled: bool) -> void:
	_building_collisions_enabled = enabled
	for collision_shape in _building_collision_shapes:
		collision_shape.disabled = not enabled

func _tint_color(color: Color, delta: float) -> Color:
	if delta >= 0.0:
		return color.lerp(Color.WHITE, delta)
	return color.lerp(Color.BLACK, -delta)
