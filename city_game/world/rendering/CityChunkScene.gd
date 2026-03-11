extends Node3D

const CityChunkMultimeshBuilder := preload("res://city_game/world/rendering/CityChunkMultimeshBuilder.gd")
const CityChunkHlodBuilder := preload("res://city_game/world/rendering/CityChunkHlodBuilder.gd")
const CityChunkOccluderBuilder := preload("res://city_game/world/rendering/CityChunkOccluderBuilder.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityRoadMeshBuilder := preload("res://city_game/world/rendering/CityRoadMeshBuilder.gd")
const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")
const CityGroundRoadOverlayShader := preload("res://city_game/world/rendering/CityGroundRoadOverlay.gdshader")

const LOD_NEAR := "near"
const LOD_MID := "mid"
const LOD_FAR := "far"
const SURFACE_DETAIL_FULL := "full"
const SURFACE_DETAIL_COARSE := "coarse"

const NEAR_THRESHOLD_M := 880.0
const MID_THRESHOLD_M := 1600.0
const TERRAIN_GRID_STEPS := 12

var _chunk_data: Dictionary = {}
var _profile: Dictionary = {}
var _setup_profile: Dictionary = {}
var _current_lod_mode := LOD_NEAR
var _current_surface_detail_mode := SURFACE_DETAIL_FULL
var _building_collision_shapes: Array[CollisionShape3D] = []
var _building_collisions_enabled := true

func setup(chunk_data: Dictionary) -> void:
	_chunk_data = chunk_data.duplicate(true)
	_profile = (chunk_data.get("prepared_profile", {}) as Dictionary).duplicate(true)
	if _profile.is_empty():
		_profile = CityChunkProfileBuilder.build_profile(_chunk_data)
	_current_lod_mode = _normalize_lod_mode(str(_chunk_data.get("initial_lod_mode", LOD_NEAR)))
	_current_surface_detail_mode = _resolve_surface_detail_mode_for_lod(_current_lod_mode)
	name = str(_chunk_data.get("chunk_id", "ChunkScene"))
	position = _chunk_data.get("chunk_center", Vector3.ZERO)
	_rebuild()

func set_lod_mode(mode: String) -> void:
	var normalized_mode := _normalize_lod_mode(mode)
	var target_surface_detail_mode := _resolve_surface_detail_mode_for_lod(normalized_mode)
	if target_surface_detail_mode != _current_surface_detail_mode:
		_apply_ground_surface_detail_mode(target_surface_detail_mode)
	_current_lod_mode = normalized_mode
	var near_group := get_node_or_null("NearGroup") as Node3D
	var mid_proxy := get_node_or_null("MidProxy") as Node3D
	var far_proxy := get_node_or_null("FarProxy") as Node3D
	if near_group != null:
		near_group.visible = normalized_mode == LOD_NEAR
	if mid_proxy != null:
		mid_proxy.visible = normalized_mode == LOD_MID
	if far_proxy != null:
		far_proxy.visible = normalized_mode == LOD_FAR
	_set_building_collisions_enabled(normalized_mode == LOD_NEAR)

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

func get_setup_profile() -> Dictionary:
	return _setup_profile.duplicate(true)

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

func get_building_count() -> int:
	return int(_profile.get("building_count", 0))

func get_building_archetype_ids() -> Array:
	return (_profile.get("building_archetype_ids", []) as Array).duplicate()

func get_road_collision_shape_count() -> int:
	var road_overlay := get_node_or_null("NearGroup/RoadOverlay") as Node
	if road_overlay != null and road_overlay.has_meta("road_collision_shape_count"):
		return int(road_overlay.get_meta("road_collision_shape_count"))
	return 0

func get_bridge_collision_shape_count() -> int:
	var road_overlay := get_node_or_null("NearGroup/RoadOverlay") as Node
	if road_overlay != null and road_overlay.has_meta("bridge_collision_shape_count"):
		return int(road_overlay.get_meta("bridge_collision_shape_count"))
	return 0

func get_bridge_min_clearance_m() -> float:
	return float(_profile.get("bridge_min_clearance_m", 0.0))

func get_bridge_deck_thickness_m() -> float:
	return float(_profile.get("bridge_deck_thickness_m", 0.0))

func get_min_building_road_clearance_m() -> float:
	return float(_profile.get("min_building_road_clearance_m", 0.0))

func get_min_prop_road_clearance_m() -> float:
	var prop_multimesh := get_prop_multimesh()
	if prop_multimesh != null and prop_multimesh.has_meta("min_road_clearance_m"):
		return float(prop_multimesh.get_meta("min_road_clearance_m"))
	return 0.0

func get_renderer_stats() -> Dictionary:
	var prop_multimesh := get_prop_multimesh()
	return {
		"chunk_id": str(_chunk_data.get("chunk_id", "")),
		"lod_mode": _current_lod_mode,
		"visual_variant_id": get_visual_variant_id(),
		"profile_signature": get_profile_signature(),
		"setup_profile": get_setup_profile(),
		"multimesh_instance_count": prop_multimesh.multimesh.instance_count if prop_multimesh != null else 0,
		"near_child_count": get_node("NearGroup").get_child_count(),
		"road_segment_count": (_profile.get("road_segments", []) as Array).size(),
		"curved_road_segment_count": int(_profile.get("curved_road_segment_count", 0)),
		"non_axis_road_segment_count": int(_profile.get("non_axis_road_segment_count", 0)),
		"bridge_count": int(_profile.get("bridge_count", 0)),
		"road_mesh_mode": str(_profile.get("road_mesh_mode", "ribbon")),
		"road_template_counts": (_profile.get("road_template_counts", {}) as Dictionary).duplicate(true),
		"road_collision_shape_count": get_road_collision_shape_count(),
		"bridge_collision_shape_count": get_bridge_collision_shape_count(),
		"bridge_min_clearance_m": get_bridge_min_clearance_m(),
		"bridge_deck_thickness_m": get_bridge_deck_thickness_m(),
		"terrain_relief_m": get_terrain_relief_m(),
		"building_collision_shape_count": get_building_collision_shape_count(),
		"building_count": get_building_count(),
	}

func _rebuild() -> void:
	var rebuild_started_usec := Time.get_ticks_usec()
	for child in get_children():
		remove_child(child)
		child.free()
	_building_collision_shapes.clear()

	var chunk_size_m := float(_chunk_data.get("chunk_size_m", 256.0))
	var setup_profile := {
		"ground_usec": 0,
		"ground_mesh_usec": 0,
		"ground_collision_usec": 0,
		"ground_material_usec": 0,
		"ground_mask_textures_usec": 0,
		"ground_mask_cache_hit": false,
		"ground_mask_cache_load_usec": 0,
		"ground_mask_cache_write_usec": 0,
		"ground_shader_material_usec": 0,
		"road_overlay_usec": 0,
		"buildings_usec": 0,
		"props_usec": 0,
		"proxies_usec": 0,
		"occluder_usec": 0,
		"set_lod_usec": 0,
	}

	var phase_started_usec := Time.get_ticks_usec()
	var ground_result := _build_ground_body(chunk_size_m, _profile)
	add_child(ground_result.get("body"))
	setup_profile["ground_usec"] = Time.get_ticks_usec() - phase_started_usec
	setup_profile["ground_mesh_usec"] = int(ground_result.get("mesh_usec", 0))
	setup_profile["ground_collision_usec"] = int(ground_result.get("collision_usec", 0))
	setup_profile["ground_material_usec"] = int(ground_result.get("material_usec", 0))
	setup_profile["ground_mask_textures_usec"] = int(ground_result.get("mask_textures_usec", 0))
	setup_profile["ground_mask_cache_hit"] = bool(ground_result.get("mask_cache_hit", false))
	setup_profile["ground_mask_cache_load_usec"] = int(ground_result.get("mask_cache_load_usec", 0))
	setup_profile["ground_mask_cache_write_usec"] = int(ground_result.get("mask_cache_write_usec", 0))
	setup_profile["ground_shader_material_usec"] = int(ground_result.get("shader_material_usec", 0))

	var near_group := Node3D.new()
	near_group.name = "NearGroup"
	add_child(near_group)

	phase_started_usec = Time.get_ticks_usec()
	var road_overlay := CityRoadMeshBuilder.build_road_overlay(_profile, _chunk_data)
	near_group.add_child(road_overlay)
	setup_profile["road_overlay_usec"] = Time.get_ticks_usec() - phase_started_usec
	var props := Node3D.new()
	props.name = "Props"
	near_group.add_child(props)

	phase_started_usec = Time.get_ticks_usec()
	for building in _profile.get("buildings", []):
		near_group.add_child(_build_building(building))
	setup_profile["buildings_usec"] = Time.get_ticks_usec() - phase_started_usec

	phase_started_usec = Time.get_ticks_usec()
	props.add_child(CityChunkMultimeshBuilder.build_street_lamps(_profile))
	setup_profile["props_usec"] = Time.get_ticks_usec() - phase_started_usec

	phase_started_usec = Time.get_ticks_usec()
	add_child(CityChunkHlodBuilder.build_mid_proxy(_profile))
	add_child(CityChunkHlodBuilder.build_far_proxy(_profile))
	setup_profile["proxies_usec"] = Time.get_ticks_usec() - phase_started_usec

	phase_started_usec = Time.get_ticks_usec()
	add_child(CityChunkOccluderBuilder.build_chunk_occluder(chunk_size_m))
	setup_profile["occluder_usec"] = Time.get_ticks_usec() - phase_started_usec

	phase_started_usec = Time.get_ticks_usec()
	set_lod_mode(_current_lod_mode)
	setup_profile["set_lod_usec"] = Time.get_ticks_usec() - phase_started_usec
	setup_profile["total_usec"] = Time.get_ticks_usec() - rebuild_started_usec
	_setup_profile = setup_profile

func _build_building(building: Dictionary) -> Node3D:
	var collision_size: Vector3 = building.get("collision_size", building.get("size", Vector3(18.0, 24.0, 18.0)))
	var building_root := _build_static_box(
		str(building.get("name", "Building")),
		building.get("center", Vector3.ZERO),
		building.get("size", Vector3(18.0, 24.0, 18.0)),
		building.get("main_color", Color(0.72, 0.74, 0.78, 1.0)),
		float(building.get("yaw_rad", 0.0)),
		collision_size
	)
	var size: Vector3 = building.get("size", Vector3.ONE)
	var accent: Color = building.get("accent_color", Color(0.52, 0.58, 0.66, 1.0))
	var roof: Color = building.get("roof_color", accent)
	var archetype_id := str(building.get("archetype_id", "mass"))
	match archetype_id:
		"slab":
			_add_local_box(building_root, "FinWest", Vector3(-size.x * 0.34, 0.0, 0.0), Vector3(0.9, size.y * 0.92, size.z + 0.2), accent)
			_add_local_box(building_root, "FinEast", Vector3(size.x * 0.34, 0.0, 0.0), Vector3(0.9, size.y * 0.92, size.z + 0.2), accent)
		"needle":
			_add_local_box(building_root, "Crown", Vector3(0.0, size.y * 0.38, 0.0), Vector3(size.x * 0.56, maxf(size.y * 0.16, 2.6), size.z * 0.56), roof)
			_add_local_box(building_root, "Spire", Vector3(0.0, size.y * 0.5 + 1.8, 0.0), Vector3(size.x * 0.18, 3.6, size.z * 0.18), accent)
		"courtyard":
			_add_local_box(building_root, "WingNorth", Vector3(0.0, 0.0, -size.z * 0.28), Vector3(size.x, size.y * 0.22, size.z * 0.22), accent)
			_add_local_box(building_root, "WingSouth", Vector3(0.0, 0.0, size.z * 0.28), Vector3(size.x, size.y * 0.22, size.z * 0.22), accent)
			_add_local_box(building_root, "RoofFrame", Vector3(0.0, size.y * 0.36, 0.0), Vector3(size.x * 0.82, maxf(size.y * 0.08, 1.4), size.z * 0.82), roof)
		"podium_tower":
			_add_local_box(building_root, "Podium", Vector3(0.0, -size.y * 0.34, 0.0), Vector3(size.x * 1.9, maxf(size.y * 0.24, 5.0), size.z * 1.9), accent)
			_add_local_box(building_root, "Cap", Vector3(0.0, size.y * 0.4, 0.0), Vector3(size.x * 0.5, maxf(size.y * 0.1, 1.6), size.z * 0.5), roof)
		"step_midrise":
			_add_local_box(building_root, "SetbackA", Vector3(0.0, size.y * 0.2, 0.0), Vector3(size.x * 0.78, maxf(size.y * 0.2, 2.0), size.z * 0.78), accent)
			_add_local_box(building_root, "SetbackB", Vector3(0.0, size.y * 0.38, 0.0), Vector3(size.x * 0.56, maxf(size.y * 0.14, 1.6), size.z * 0.56), roof)
		"midrise_bar":
			_add_local_box(building_root, "RoofUnitA", Vector3(-size.x * 0.18, size.y * 0.36, 0.0), Vector3(size.x * 0.22, maxf(size.y * 0.12, 1.4), size.z * 0.24), roof)
			_add_local_box(building_root, "RoofUnitB", Vector3(size.x * 0.18, size.y * 0.36, 0.0), Vector3(size.x * 0.22, maxf(size.y * 0.12, 1.4), size.z * 0.24), accent)
		"industrial":
			_add_local_box(building_root, "SawToothA", Vector3(-size.x * 0.18, size.y * 0.28, 0.0), Vector3(size.x * 0.24, maxf(size.y * 0.18, 1.8), size.z * 0.88), roof)
			_add_local_box(building_root, "SawToothB", Vector3(size.x * 0.18, size.y * 0.2, 0.0), Vector3(size.x * 0.24, maxf(size.y * 0.14, 1.6), size.z * 0.88), accent)
	return building_root

func _build_static_box(node_name: String, center: Vector3, size: Vector3, color: Color, yaw_rad: float = 0.0, collision_size: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.rotation.y = yaw_rad

	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = collision_size if collision_size != Vector3.ZERO else size
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

func _add_local_box(parent: Node3D, node_name: String, local_center: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = local_center
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

func _build_ground_body(chunk_size_m: float, profile: Dictionary) -> Dictionary:
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundBody"

	var mesh_started_usec := Time.get_ticks_usec()
	var terrain_mesh := _build_terrain_mesh(chunk_size_m)
	var mesh_usec := Time.get_ticks_usec() - mesh_started_usec
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var collision_started_usec := Time.get_ticks_usec()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(terrain_mesh.get_faces())
	var collision_usec := Time.get_ticks_usec() - collision_started_usec
	collision_shape.shape = shape
	ground_body.add_child(collision_shape)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = terrain_mesh
	var material_started_usec := Time.get_ticks_usec()
	var material_result := _build_ground_material(chunk_size_m, profile, _current_surface_detail_mode)
	mesh_instance.material_override = material_result.get("material")
	var material_usec := Time.get_ticks_usec() - material_started_usec
	ground_body.add_child(mesh_instance)
	return {
		"body": ground_body,
		"mesh_usec": mesh_usec,
		"collision_usec": collision_usec,
		"material_usec": material_usec,
		"mask_textures_usec": int(material_result.get("mask_textures_usec", 0)),
		"mask_cache_hit": bool(material_result.get("mask_cache_hit", false)),
		"mask_cache_load_usec": int(material_result.get("mask_cache_load_usec", 0)),
		"mask_cache_write_usec": int(material_result.get("mask_cache_write_usec", 0)),
		"shader_material_usec": int(material_result.get("shader_material_usec", 0)),
	}

func _build_ground_material(chunk_size_m: float, profile: Dictionary, detail_mode: String = SURFACE_DETAIL_FULL) -> Dictionary:
	var palette: Dictionary = profile.get("palette", {})
	var mask_started_usec := Time.get_ticks_usec()
	var overlay_textures: Dictionary = CityRoadMaskBuilder.build_surface_textures(profile, chunk_size_m, detail_mode)
	var mask_textures_usec := Time.get_ticks_usec() - mask_started_usec
	var material_started_usec := Time.get_ticks_usec()
	var material := ShaderMaterial.new()
	material.shader = CityGroundRoadOverlayShader
	material.set_shader_parameter("chunk_size_m", chunk_size_m)
	material.set_shader_parameter("ground_color", palette.get("ground", Color(0.12549, 0.333333, 0.168627, 1.0)))
	material.set_shader_parameter("road_color", palette.get("road", Color(0.16, 0.17, 0.19, 1.0)))
	material.set_shader_parameter("stripe_color", palette.get("stripe", Color(0.9, 0.8, 0.5, 1.0)))
	material.set_shader_parameter("stripe_enabled", detail_mode == SURFACE_DETAIL_FULL)
	material.set_shader_parameter("road_mask_texture", overlay_textures.get("road_mask_texture"))
	material.set_shader_parameter("stripe_mask_texture", overlay_textures.get("stripe_mask_texture"))
	return {
		"material": material,
		"mask_textures_usec": mask_textures_usec,
		"mask_cache_hit": bool((overlay_textures.get("mask_profile_stats", {}) as Dictionary).get("cache_hit", false)),
		"mask_cache_load_usec": int((overlay_textures.get("mask_profile_stats", {}) as Dictionary).get("cache_load_usec", 0)),
		"mask_cache_write_usec": int((overlay_textures.get("mask_profile_stats", {}) as Dictionary).get("cache_write_usec", 0)),
		"shader_material_usec": Time.get_ticks_usec() - material_started_usec,
	}

func _apply_ground_surface_detail_mode(detail_mode: String) -> void:
	var mesh_instance := get_node_or_null("GroundBody/MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return
	var chunk_size_m := float(_chunk_data.get("chunk_size_m", 256.0))
	var material_result := _build_ground_material(chunk_size_m, _profile, detail_mode)
	mesh_instance.material_override = material_result.get("material")
	_current_surface_detail_mode = detail_mode

func _resolve_surface_detail_mode_for_lod(mode: String) -> String:
	return SURFACE_DETAIL_FULL if mode == LOD_NEAR else SURFACE_DETAIL_COARSE

func _normalize_lod_mode(mode: String) -> String:
	if mode == LOD_MID or mode == LOD_FAR:
		return mode
	return LOD_NEAR

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
	var shaped_height := CityChunkGroundSampler.sample_height(Vector2(local_x, local_z), _chunk_data, _profile)
	return Vector3(local_x, shaped_height, local_z)

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
