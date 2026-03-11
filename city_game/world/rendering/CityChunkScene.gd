extends Node3D

const CityChunkMultimeshBuilder := preload("res://city_game/world/rendering/CityChunkMultimeshBuilder.gd")
const CityChunkHlodBuilder := preload("res://city_game/world/rendering/CityChunkHlodBuilder.gd")
const CityChunkOccluderBuilder := preload("res://city_game/world/rendering/CityChunkOccluderBuilder.gd")

const LOD_NEAR := "near"
const LOD_MID := "mid"
const LOD_FAR := "far"

var _chunk_data: Dictionary = {}
var _current_lod_mode := LOD_NEAR

func setup(chunk_data: Dictionary) -> void:
	_chunk_data = chunk_data.duplicate(true)
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

func get_lod_contract() -> Dictionary:
	return {
		"chunk_id": str(_chunk_data.get("chunk_id", "")),
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
		"multimesh_instance_count": prop_multimesh.multimesh.instance_count if prop_multimesh != null else 0,
		"near_child_count": get_node("NearGroup").get_child_count(),
	}

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var chunk_size_m := float(_chunk_data.get("chunk_size_m", 256.0))

	add_child(_build_ground_body(chunk_size_m))

	var near_group := Node3D.new()
	near_group.name = "NearGroup"
	add_child(near_group)

	var props := Node3D.new()
	props.name = "Props"
	near_group.add_child(props)

	near_group.add_child(_build_tower("NearTowerA", Vector3(-36.0, 10.0, -28.0), Vector3(26.0, 20.0, 24.0), Color(0.74, 0.74, 0.78, 1.0)))
	near_group.add_child(_build_tower("NearTowerB", Vector3(28.0, 14.0, 24.0), Vector3(20.0, 28.0, 18.0), Color(0.62, 0.68, 0.74, 1.0)))
	near_group.add_child(_build_tower("NearPodium", Vector3(0.0, 2.0, 0.0), Vector3(chunk_size_m * 0.42, 4.0, chunk_size_m * 0.42), Color(0.45, 0.47, 0.5, 1.0)))
	props.add_child(CityChunkMultimeshBuilder.build_street_lamps(chunk_size_m))

	add_child(CityChunkHlodBuilder.build_mid_proxy(chunk_size_m))
	add_child(CityChunkHlodBuilder.build_far_proxy(chunk_size_m))
	add_child(CityChunkOccluderBuilder.build_chunk_occluder(chunk_size_m))

	set_lod_mode(LOD_NEAR)

func _build_tower(name: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
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

func _build_ground_body(chunk_size_m: float) -> StaticBody3D:
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
	material.albedo_color = Color(0.12549, 0.333333, 0.168627, 1.0)
	material.roughness = 1.0
	mesh_instance.material_override = material
	ground_body.add_child(mesh_instance)
	return ground_body
