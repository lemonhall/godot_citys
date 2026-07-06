extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var style_script := load("res://city_game/world/rendering/CityToyVisualStyle.gd")
	if not T.require_true(self, style_script != null, "Toy visual style script must exist"):
		return

	if not T.require_true(self, style_script.LEGO_BUILDING_PALETTE.size() == 6, "Screenshot toy palette must keep the six-color lego set"):
		return
	if not T.require_true(self, style_script.LEGO_BUILDING_PALETTE.has(Color(0.92, 0.92, 0.86, 1.0)), "Screenshot toy palette must still include the cream/white brick color"):
		return

	var material: StandardMaterial3D = style_script.get_material(Color(0.86, 0.04, 0.07, 1.0), "building")
	if not T.require_true(self, material != null, "Toy material factory must return a StandardMaterial3D"):
		return
	if not T.require_true(self, material.clearcoat_enabled, "Toy plastic material must enable clearcoat"):
		return
	if not T.require_true(self, material.clearcoat >= 0.85, "Toy plastic material must keep a strong glossy clearcoat"):
		return
	if not T.require_true(self, material.roughness <= 0.18, "Toy plastic material must stay smooth enough for jelly-like highlights"):
		return

	var mesh: Mesh = style_script.get_rounded_box_mesh(Vector3(12.0, 16.0, 10.0))
	if not T.require_true(self, mesh is ArrayMesh, "Toy rounded box mesh factory must return a real bevel ArrayMesh, not a subdivided BoxMesh"):
		return
	if not T.require_true(self, mesh.get_surface_count() >= 1, "Toy bevel mesh must contain renderable surfaces"):
		return
	var mesh_arrays := (mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	if not T.require_true(self, vertices.size() >= 72, "Toy bevel mesh must have enough explicit vertices for chamfered edges and corners"):
		return

	var building_script := load("res://city_game/world/serviceability/CityBuildingSceneBuilder.gd")
	if not T.require_true(self, building_script != null, "Building scene builder must load"):
		return
	var building: StaticBody3D = building_script.build_runtime_building({
		"name": "ToyContractBuilding",
		"center": Vector3.ZERO,
		"size": Vector3(18.0, 24.0, 18.0),
		"main_color": Color(0.04, 0.26, 0.78, 1.0),
		"accent_color": Color(0.95, 0.74, 0.08, 1.0),
		"roof_color": Color(0.92, 0.92, 0.86, 1.0),
		"archetype_id": "slab",
	})
	root.add_child(building)
	await process_frame
	if not T.require_true(self, int(building.get_meta("roof_stud_count", 0)) > 0, "Toy building must keep roof studs in the screenshot state"):
		return
	if not T.require_true(self, int(building.get_meta("facade_stud_count", 0)) > 0, "Toy building must keep facade studs in the screenshot state"):
		return
	if not T.require_true(self, building.has_node("LegoRoofStuds"), "Toy building must expose roof stud multimesh node"):
		return
	if not T.require_true(self, building.has_node("LegoFacadeStuds"), "Toy building must expose facade stud multimesh node"):
		return
	var body_mesh := building.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not T.require_true(self, body_mesh != null and body_mesh.mesh is ArrayMesh, "Generated toy building body must use the real bevel mesh"):
		return
	building.queue_free()
	T.pass_and_quit(self)
