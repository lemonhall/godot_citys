extends SceneTree

# Material probe for the v62 building kit: verifies MultiMesh instance custom
# data colors, the facade shader styles and the glass shader in isolation.

const OUTPUT_DEFAULT := "user://debug/building_material_probe.png"
const MassingBuilder := preload("res://city_game/world/rendering/buildings/CityBuildingMassingBuilder.gd")
const DetailBatch := preload("res://city_game/world/rendering/buildings/CityBuildingDetailBatch.gd")
const MeshBuilder := preload("res://city_game/world/rendering/buildings/CityBuildingMeshBuilder.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.42, 0.76, 1.0, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.98, 0.92, 1.0)
	environment.ambient_light_energy = 0.56
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment_node.environment = environment
	world.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.84, 1.0)
	sun.light_energy = 2.4
	sun.shadow_enabled = true
	world.add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.30, 0.30, 0.30, 1.0)
	ground_material.roughness = 0.9
	ground.material_override = ground_material
	world.add_child(ground)

	# Custom-data colored detail boxes.
	var batch := DetailBatch.new()
	batch.add_box(Vector3(-9.0, 1.5, 0.0), Vector3(2.4, 3.0, 2.4), Color(0.7, 0.1, 0.1).srgb_to_linear())
	batch.add_box(Vector3(-6.0, 1.5, 0.0), Vector3(2.4, 3.0, 2.4), Color(0.1, 0.6, 0.2).srgb_to_linear())
	batch.add_box(Vector3(-3.0, 1.5, 0.0), Vector3(2.4, 3.0, 2.4), Color(0.1, 0.2, 0.7).srgb_to_linear())
	batch.add_box(Vector3(0.0, 1.5, 0.0), Vector3(2.4, 3.0, 2.4), Color(0.85, 0.8, 0.7).srgb_to_linear())
	var batch_node := batch.build("ProbeBoxes", MassingBuilder.unit_box_mesh(), MassingBuilder.shared_trim_material())
	world.add_child(batch_node)

	# Facade shader on a flat box, one style per column.
	var styles := [0, 1, 2, 3, 4, 6]
	for index in range(styles.size()):
		var mesh_builder := MeshBuilder.new()
		mesh_builder.configure(3.0, 3.0, 3.6, -3.0, -1.5, -12.0)
		mesh_builder.add_box_sides(Vector3(0.0, 0.0, 0.0), Vector3(6.0, 24.0, 3.0), 0.75, 1.0)
		var material := ShaderMaterial.new()
		material.shader = MassingBuilder.FACADE_SHADER
		material.set_shader_parameter("wall_color", Color(0.52, 0.50, 0.46))
		material.set_shader_parameter("trim_color", Color(1.0, 0.0, 0.0))
		material.set_shader_parameter("glass_color", Color(0.03, 0.05, 0.075))
		material.set_shader_parameter("sky_color", MassingBuilder.SKY_COLOR)
		material.set_shader_parameter("facade_style", float(styles[index]))
		material.set_shader_parameter("detail_seed", float(index * 37 + 11))
		material.set_shader_parameter("lit_ratio", 0.25)
		material.set_shader_parameter("grime", 0.4)
		var instance := MeshInstance3D.new()
		instance.name = "FacadeStyle%d" % styles[index]
		instance.mesh = mesh_builder.commit(null)
		instance.material_override = material
		instance.position = Vector3(5.0 + float(index) * 7.0, 12.0, 0.0)
		world.add_child(instance)

	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.position = Vector3(12.0, 11.0, 46.0)
	world.add_child(camera)
	camera.current = true
	camera.look_at_from_position(camera.position, Vector3(8.0, 10.0, 0.0), Vector3.UP)

	for _frame in range(20):
		await process_frame

	var image := root.get_viewport().get_texture().get_image()
	var output_global := ProjectSettings.globalize_path(OUTPUT_DEFAULT)
	DirAccess.make_dir_recursive_absolute(output_global.get_base_dir())
	image.save_png(output_global)
	print("MATERIAL_PROBE %s" % output_global)
	quit()
