extends Node3D

const CityChunkMultimeshBuilder := preload("res://city_game/world/rendering/CityChunkMultimeshBuilder.gd")
const CityChunkHlodBuilder := preload("res://city_game/world/rendering/CityChunkHlodBuilder.gd")
const CityChunkOccluderBuilder := preload("res://city_game/world/rendering/CityChunkOccluderBuilder.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")

const LOD_NEAR := "near"
const LOD_MID := "mid"
const LOD_FAR := "far"

var _chunk_data: Dictionary = {}
var _profile: Dictionary = {}
var _current_lod_mode := LOD_NEAR

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

func update_lod_for_distance(distance_m: float) -> void:
	if distance_m < 220.0:
		set_lod_mode(LOD_NEAR)
	elif distance_m < 520.0:
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
		"near_threshold_m": 220.0,
		"mid_threshold_m": 520.0,
	}

func get_prop_multimesh() -> MultiMeshInstance3D:
	return get_node("NearGroup/Props/StreetLamps") as MultiMeshInstance3D

func get_ground_body() -> StaticBody3D:
	return get_node_or_null("GroundBody") as StaticBody3D

func get_renderer_stats() -> Dictionary:
	var prop_multimesh := get_prop_multimesh()
	return {
		"chunk_id": str(_chunk_data.get("chunk_id", "")),
		"lod_mode": _current_lod_mode,
		"visual_variant_id": get_visual_variant_id(),
		"profile_signature": get_profile_signature(),
		"multimesh_instance_count": prop_multimesh.multimesh.instance_count if prop_multimesh != null else 0,
		"near_child_count": get_node("NearGroup").get_child_count(),
	}

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var chunk_size_m := float(_chunk_data.get("chunk_size_m", 256.0))

	add_child(_build_ground_body(chunk_size_m, _profile))

	var near_group := Node3D.new()
	near_group.name = "NearGroup"
	add_child(near_group)

	near_group.add_child(_build_avenue_overlay(chunk_size_m, _profile))
	var props := Node3D.new()
	props.name = "Props"
	near_group.add_child(props)

	near_group.add_child(_build_podium(_profile.get("podium", {})))
	for tower in _profile.get("towers", []):
		near_group.add_child(_build_tower(tower))
	props.add_child(CityChunkMultimeshBuilder.build_street_lamps(chunk_size_m, _profile))

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
	var body := _build_box_instance("%s_Body" % tower_root.name, center, size, color)
	tower_root.add_child(body)

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

func _build_podium(podium: Dictionary) -> MeshInstance3D:
	return _build_box_instance(
		"NearPodium",
		podium.get("center", Vector3.ZERO),
		podium.get("size", Vector3(92.0, 4.0, 92.0)),
		podium.get("color", Color(0.45, 0.47, 0.5, 1.0))
	)

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

func _build_avenue_overlay(chunk_size_m: float, profile: Dictionary) -> Node3D:
	var avenue_root := Node3D.new()
	avenue_root.name = "AvenueOverlay"
	var avenue: Dictionary = profile.get("avenue", {})
	var palette: Dictionary = profile.get("palette", {})
	var axis := str(avenue.get("axis", "z"))
	var width := float(avenue.get("width", 28.0))
	var offset := float(avenue.get("offset", 0.0))
	var stripe_color: Color = palette.get("stripe", Color(0.9, 0.8, 0.5, 1.0))
	var road_color: Color = palette.get("road", Color(0.16, 0.17, 0.19, 1.0))
	var plaza_depth := float(avenue.get("plaza_depth", chunk_size_m * 0.18))

	var road_size := Vector3(chunk_size_m, 0.08, width)
	var road_center := Vector3(0.0, 0.05, offset)
	if axis == "z":
		road_size = Vector3(width, 0.08, chunk_size_m)
		road_center = Vector3(offset, 0.05, 0.0)
	avenue_root.add_child(_build_box_instance("RoadSurface", road_center, road_size, road_color))

	var stripe_size := Vector3(chunk_size_m * 0.88, 0.03, 0.9)
	var stripe_center := Vector3(0.0, 0.1, offset)
	if axis == "z":
		stripe_size = Vector3(0.9, 0.03, chunk_size_m * 0.88)
		stripe_center = Vector3(offset, 0.1, 0.0)
	avenue_root.add_child(_build_box_instance("RoadStripe", stripe_center, stripe_size, stripe_color))

	var plaza_size := Vector3(chunk_size_m * 0.18, 0.06, plaza_depth)
	var plaza_center := Vector3(0.0, 0.08, offset)
	if axis == "z":
		plaza_size = Vector3(plaza_depth, 0.06, chunk_size_m * 0.18)
		plaza_center = Vector3(offset, 0.08, 0.0)
	avenue_root.add_child(_build_box_instance("Plaza", plaza_center, plaza_size, _tint_color(road_color, 0.06)))
	return avenue_root

func _build_ground_body(chunk_size_m: float, profile: Dictionary) -> StaticBody3D:
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundBody"
	ground_body.position.y = -0.5

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = BoxShape3D.new()
	(collision_shape.shape as BoxShape3D).size = Vector3(chunk_size_m, 1.0, chunk_size_m)
	ground_body.add_child(collision_shape)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(chunk_size_m, 1.0, chunk_size_m)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	var palette: Dictionary = profile.get("palette", {})
	material.albedo_color = palette.get("ground", Color(0.12549, 0.333333, 0.168627, 1.0))
	material.roughness = 1.0
	mesh_instance.material_override = material
	ground_body.add_child(mesh_instance)
	return ground_body

func _tint_color(color: Color, delta: float) -> Color:
	if delta >= 0.0:
		return color.lerp(Color.WHITE, delta)
	return color.lerp(Color.BLACK, -delta)
