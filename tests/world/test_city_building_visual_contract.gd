extends SceneTree

# v62 building visual contract: the procedural generator must produce real
# merged geometry, procedural facade materials, and a detail batch instead of
# the retired block-toy shell.

const T := preload("res://tests/_test_util.gd")
const MassingBuilder := preload("res://city_game/world/rendering/buildings/CityBuildingMassingBuilder.gd")
const SceneBuilder := preload("res://city_game/world/serviceability/CityBuildingSceneBuilder.gd")

const ARCHETYPES := [
	"slab",
	"needle",
	"courtyard",
	"podium_tower",
	"step_midrise",
	"midrise_bar",
	"industrial",
	"row_house",
	"residential_tower",
	"hotel_tower",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for archetype in ARCHETYPES:
		var building := _make_building(archetype, 424242)
		var visual := MassingBuilder.build(building)
		var facade_mesh: ArrayMesh = visual.get("facade_mesh", null)
		if not T.require_true(self, facade_mesh != null, "%s must produce a merged facade mesh" % archetype):
			return
		var arrays := facade_mesh.surface_get_arrays(0)
		if not T.require_true(self, arrays[Mesh.ARRAY_VERTEX] != null, "%s facade must carry positions" % archetype):
			return
		if not T.require_true(self, arrays[Mesh.ARRAY_NORMAL] != null, "%s facade must carry normals" % archetype):
			return
		if not T.require_true(self, arrays[Mesh.ARRAY_COLOR] != null, "%s facade must carry baked AO vertex colors" % archetype):
			return
		if not T.require_true(self, arrays[Mesh.ARRAY_TEX_UV] != null, "%s facade must carry facade-module UVs" % archetype):
			return
		if not T.require_true(self, int(visual.get("triangle_count", 0)) >= 150, "%s must exceed 150 triangles of real geometry" % archetype):
			return
		var detail_boxes = visual.get("detail_boxes", null)
		if not T.require_true(self, detail_boxes != null and detail_boxes.count() >= 8, "%s must emit a detail instance batch" % archetype):
			return

		var body: StaticBody3D = SceneBuilder.build_runtime_building(_make_local_building(archetype))
		if not T.require_true(self, body != null, "%s must build a StaticBody3D" % archetype):
			return
		if not T.require_true(self, body.has_meta("city_generated_building"), "%s body must keep city_generated_building metadata" % archetype):
			return
		var facade_instance := body.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if not T.require_true(self, facade_instance != null and facade_instance.mesh is ArrayMesh, "%s must expose the merged facade mesh on MeshInstance3D" % archetype):
			return
		if not T.require_true(self, facade_instance.material_override is ShaderMaterial, "%s facade must use the procedural facade ShaderMaterial" % archetype):
			return
		var facade_material := facade_instance.material_override as ShaderMaterial
		if not T.require_true(
			self,
			facade_material.get_shader_parameter("facade_style") != null,
			"%s facade material must expose facade_style" % archetype
		):
			return
		var detail_instance := body.get_node_or_null("DetailBoxes") as MultiMeshInstance3D
		if not T.require_true(self, detail_instance != null and detail_instance.multimesh != null, "%s must expose the DetailBoxes MultiMesh" % archetype):
			return
		if not T.require_true(self, detail_instance.multimesh.instance_count >= 8, "%s detail MultiMesh must carry instances" % archetype):
			return
		if not T.require_true(self, body.get_node_or_null("LegoRoofStuds") == null, "%s must not bring back the retired stud nodes" % archetype):
			return
		# Rooftop equipment must rise above the massing roof line. Read the
		# authored batch (the dummy renderer does not round-trip MultiMesh data).
		var roof_y := float((_make_local_building(archetype).get("size", Vector3.ONE) as Vector3).y) * 0.5
		var highest := -INF
		for instance_transform in detail_boxes.transforms:
			var transform: Transform3D = instance_transform
			highest = maxf(highest, transform.origin.y + transform.basis.y.length() * 0.5)
		var detail_cylinders = visual.get("detail_cylinders", null)
		if detail_cylinders != null:
			for instance_transform in detail_cylinders.transforms:
				var transform: Transform3D = instance_transform
				highest = maxf(highest, transform.origin.y + transform.basis.y.length() * 0.5)
		if not T.require_true(self, highest > roof_y - 0.5, "%s rooftop detail must reach the roof line instead of being buried" % archetype):
			return
		body.free()

	# Determinism: identical contract -> identical geometry counts.
	var a := MassingBuilder.build(_make_building("podium_tower", 777))
	var b := MassingBuilder.build(_make_building("podium_tower", 777))
	if not T.require_true(
		self,
		int(a.get("triangle_count", 0)) == int(b.get("triangle_count", 0))
			and int(a.get("detail_box_count", 0)) == int(b.get("detail_box_count", 0)),
		"Repeated builds of the same contract must be deterministic"
	):
		return

	var service_root := SceneBuilder.build_service_scene_root(_make_building("midrise_bar", 99))
	if not T.require_true(self, service_root != null and service_root.has_meta("city_service_scene_root"), "Service scene root must keep its metadata"):
		return
	var generated := service_root.get_node_or_null("GeneratedBuilding")
	if not T.require_true(self, generated is StaticBody3D, "Service scene must keep GeneratedBuilding as a StaticBody3D"):
		return
	service_root.free()

	T.pass_and_quit(self)

func _make_building(archetype: String, seed_value: int) -> Dictionary:
	return {
		"name": "VisualContract_%s" % archetype,
		"building_id": "visual_contract_%s" % archetype,
		"archetype_id": archetype,
		"center": Vector3(200.0, 17.0, -140.0),
		"size": Vector3(26.0, 34.0, 22.0),
		"collision_size": Vector3(26.0, 34.0, 22.0),
		"yaw_rad": 0.35,
		"main_color": Color(0.58, 0.52, 0.44, 1.0),
		"accent_color": Color(0.26, 0.22, 0.19, 1.0),
		"roof_color": Color(0.24, 0.24, 0.25, 1.0),
		"detail_seed": seed_value,
	}

func _make_local_building(archetype: String) -> Dictionary:
	var building := _make_building(archetype, 424242)
	var size: Vector3 = building.get("size", Vector3.ONE)
	building["center"] = Vector3(0.0, size.y * 0.5, 0.0)
	building["yaw_rad"] = 0.0
	return building
