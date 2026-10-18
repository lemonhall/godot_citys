extends SceneTree

# Visual QA probe for the procedural city building generator.
#
# Renders a fixed gallery of generated buildings with the same environment /
# lighting as the main city, then saves a PNG so model changes can be judged
# without booting the whole 70km world.
#
# Run (windowed, not headless):
#   & $godot --path $project --script res://tests/e2e/debug_capture_building_gallery.gd
# Optional user args:
#   -- --out=<absolute-or-user-path> --view=street|aerial|closeup

const CityToyVisualStyleRef := preload("res://city_game/world/rendering/CityToyVisualStyle.gd")

const OUTPUT_DEFAULT := "user://debug/building_gallery.png"

const CASE_SPECS := [
	{
		"name": "TowerA",
		"center": Vector3(-34.0, 0.0, -30.0),
		"size": Vector3(22.0, 96.0, 22.0),
		"main": Color(0.36, 0.42, 0.50),
		"accent": Color(0.20, 0.24, 0.30),
		"roof": Color(0.15, 0.17, 0.20),
		"archetype": "podium_tower",
	},
	{
		"name": "TowerB",
		"center": Vector3(4.0, 0.0, -46.0),
		"size": Vector3(18.0, 132.0, 18.0),
		"main": Color(0.42, 0.40, 0.37),
		"accent": Color(0.18, 0.19, 0.21),
		"roof": Color(0.18, 0.19, 0.21),
		"archetype": "step_midrise",
	},
	{
		"name": "SlabA",
		"center": Vector3(38.0, 0.0, -26.0),
		"size": Vector3(34.0, 58.0, 16.0),
		"main": Color(0.48, 0.45, 0.40),
		"accent": Color(0.34, 0.30, 0.28),
		"roof": Color(0.20, 0.20, 0.22),
		"archetype": "slab",
	},
	{
		"name": "MidriseA",
		"center": Vector3(-30.0, 0.0, 18.0),
		"size": Vector3(26.0, 26.0, 20.0),
		"main": Color(0.55, 0.51, 0.44),
		"accent": Color(0.38, 0.34, 0.30),
		"roof": Color(0.24, 0.22, 0.22),
		"archetype": "midrise_bar",
	},
	{
		"name": "NeedleA",
		"center": Vector3(14.0, 0.0, 16.0),
		"size": Vector3(14.0, 150.0, 14.0),
		"main": Color(0.37, 0.41, 0.47),
		"accent": Color(0.26, 0.28, 0.32),
		"roof": Color(0.16, 0.17, 0.19),
		"archetype": "needle",
	},
	{
		"name": "LowA",
		"center": Vector3(46.0, 0.0, 22.0),
		"size": Vector3(20.0, 12.0, 18.0),
		"main": Color(0.56, 0.46, 0.34),
		"accent": Color(0.42, 0.30, 0.22),
		"roof": Color(0.28, 0.24, 0.22),
		"archetype": "courtyard",
	},
]

func _init() -> void:
	call_deferred("_run")

func _user_arg(key: String, fallback: String) -> String:
	var prefix := "--%s=" % key
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return fallback

func _run() -> void:
	var view := _user_arg("view", "street")
	var output_path := _user_arg("out", OUTPUT_DEFAULT)
	var only := _user_arg("only", "")

	var world := Node3D.new()
	world.name = "GalleryWorld"
	root.add_child(world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	CityToyVisualStyleRef.configure_environment(environment)
	environment.tonemap_exposure = float(_user_arg("exposure", "0.92"))
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.16
	environment.adjustment_saturation = 1.20
	environment.adjustment_brightness = 1.0
	environment.ambient_light_energy = float(_user_arg("ambient", "0.85"))
	if _user_arg("ssao", "0") == "1":
		environment.ssao_enabled = true
		environment.ssao_radius = 2.4
		environment.ssao_intensity = 2.6
		environment.ssao_power = 1.6
	environment_node.environment = environment
	world.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-26.0, 48.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.72, 1.0)
	sun.light_energy = 2.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 420.0
	world.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22.0, 138.0, 0.0)
	fill.light_color = Color(0.82, 0.90, 1.0, 1.0)
	fill.light_energy = 0.55
	world.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(460.0, 460.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.24, 0.25, 0.26, 1.0)
	ground_material.roughness = 0.95
	ground.material_override = ground_material
	ground.position = Vector3(0.0, 0.0, 0.0)
	world.add_child(ground)

	var builder = load("res://city_game/world/serviceability/CityBuildingSceneBuilder.gd")
	for spec_variant in CASE_SPECS:
		var spec: Dictionary = spec_variant
		if only != "" and str(spec["name"]) != only:
			continue
		var center2d: Vector3 = spec["center"]
		var size: Vector3 = spec["size"]
		var anchor := Vector3(
			center2d.x,
			size.y * 0.5,
			center2d.z
		)
		var body: StaticBody3D = builder.build_runtime_building({
			"name": str(spec["name"]),
			"building_id": "gallery_%s" % str(spec["name"]),
			"center": anchor,
			"size": size,
			"main_color": spec["main"],
			"accent_color": spec["accent"],
			"roof_color": spec["roof"],
			"archetype_id": str(spec["archetype"]),
			"yaw_rad": 0.0,
		})
		if body == null:
			push_error("Failed to build gallery case %s" % str(spec["name"]))
			quit(1)
			return
		world.add_child(body)

	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.far = 1200.0
	world.add_child(camera)
	camera.current = true

	match view:
		"aerial":
			camera.position = Vector3(-118.0, 168.0, 132.0)
			camera.look_at_from_position(camera.position, Vector3(0.0, 46.0, -6.0), Vector3.UP)
		"closeup":
			camera.position = Vector3(-46.0, 7.0, 6.0)
			camera.look_at_from_position(camera.position, Vector3(-34.0, 30.0, -30.0), Vector3.UP)
		"facade":
			camera.fov = 42.0
			camera.position = Vector3(4.0, 56.0, -12.0)
			camera.look_at_from_position(camera.position, Vector3(4.0, 56.0, -46.0), Vector3.UP)
		"front":
			camera.fov = 55.0
			camera.position = Vector3(4.0, 6.0, 10.0)
			camera.look_at_from_position(camera.position, Vector3(4.0, 26.0, -46.0), Vector3.UP)
		_:
			camera.position = Vector3(-8.0, 4.6, 72.0)
			camera.look_at_from_position(camera.position, Vector3(-2.0, 40.0, -34.0), Vector3.UP)

	for _frame in range(24):
		await process_frame

	var image := root.get_viewport().get_texture().get_image()
	var output_global := output_path
	if output_path.begins_with("user://") or output_path.begins_with("res://"):
		output_global = ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(output_global.get_base_dir())
	var save_error := image.save_png(output_global)
	if save_error != OK:
		push_error("Failed to save gallery capture: %s" % str(save_error))
		quit(1)
		return
	print("BUILDING_GALLERY_CAPTURE %s" % output_global)
	quit()
