extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")

const MAIN_BUILDING_MESH_NAME := "MeshInstance3D"
const EMBED_TOLERANCE_M := 0.05

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var chunk_scene := CityChunkScene.new()
	root.add_child(chunk_scene)
	await process_frame

	for building in _sample_buildings():
		var building_root := chunk_scene.call("_build_building", building) as StaticBody3D
		if not T.require_true(self, building_root != null, "Building scene must be constructable for ornament embedding review"):
			return
		var base_mesh := building_root.get_node_or_null(MAIN_BUILDING_MESH_NAME) as MeshInstance3D
		if not T.require_true(self, base_mesh != null, "Building root must keep the main MeshInstance3D for ornament embedding review"):
			return
		var base_box := base_mesh.mesh as BoxMesh
		if not T.require_true(self, base_box != null, "Building main mesh must stay a BoxMesh for ornament embedding review"):
			return
		var base_half := base_box.size * 0.5

		for child in building_root.get_children():
			var ornament := child as MeshInstance3D
			if ornament == null or ornament.name == MAIN_BUILDING_MESH_NAME:
				continue
			var ornament_box := ornament.mesh as BoxMesh
			if not T.require_true(self, ornament_box != null, "Building ornament %s must stay a BoxMesh for embedding review" % ornament.name):
				return
			var ornament_half := ornament_box.size * 0.5
			var local_center := ornament.position
			var fully_embedded := (
				absf(local_center.x) + ornament_half.x <= base_half.x - EMBED_TOLERANCE_M
				and absf(local_center.y) + ornament_half.y <= base_half.y - EMBED_TOLERANCE_M
				and absf(local_center.z) + ornament_half.z <= base_half.z - EMBED_TOLERANCE_M
			)
			if not T.require_true(
				self,
				not fully_embedded,
				"Building ornament %s/%s must not be fully embedded inside the main tower volume or it will produce z-fighting and shadow flicker" % [
					str(building.get("archetype_id", "unknown")),
					String(ornament.name),
				]
			):
				return
		building_root.free()

	chunk_scene.queue_free()
	T.pass_and_quit(self)

func _sample_buildings() -> Array[Dictionary]:
	return [
		_make_building("slab", Vector3(24.0, 30.0, 40.0)),
		_make_building("needle", Vector3(20.0, 70.0, 22.0)),
		_make_building("courtyard", Vector3(36.0, 28.0, 36.0)),
		_make_building("podium_tower", Vector3(22.0, 48.0, 22.0)),
		_make_building("step_midrise", Vector3(30.0, 28.0, 34.0)),
		_make_building("midrise_bar", Vector3(24.0, 22.0, 48.0)),
		_make_building("industrial", Vector3(40.0, 16.0, 52.0)),
	]

func _make_building(archetype_id: String, size: Vector3) -> Dictionary:
	return {
		"name": "Review_%s" % archetype_id,
		"archetype_id": archetype_id,
		"center": Vector3.ZERO,
		"size": size,
		"collision_size": size,
		"yaw_rad": 0.0,
		"main_color": Color(0.72, 0.72, 0.72, 1.0),
		"accent_color": Color(0.55, 0.44, 0.38, 1.0),
		"roof_color": Color(0.40, 0.44, 0.48, 1.0),
	}
