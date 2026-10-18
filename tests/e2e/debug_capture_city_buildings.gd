extends SceneTree

# In-world capture probe for the procedural city buildings.
#
# Usage:
#   & $godot --path $project --script res://tests/e2e/debug_capture_city_buildings.gd -- --mode=street
#   & $godot --path $project --script res://tests/e2e/debug_capture_city_buildings.gd -- --mode=aerial

const OUTPUT_DEFAULT := "user://debug/city_building_capture.png"

func _init() -> void:
	call_deferred("_run")

func _user_arg(key: String, fallback: String) -> String:
	var prefix := "--%s=" % key
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return fallback

func _run() -> void:
	var mode := _user_arg("mode", "street")
	var output_path := _user_arg("out", OUTPUT_DEFAULT)

	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		push_error("Missing CityPrototype.tscn")
		quit(1)
		return
	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var requested_origin := Vector3(float(_user_arg("x", "0")), 0.0, float(_user_arg("z", "0")))

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")
	var player := world.get_node_or_null("Player") as Node3D
	if player != null:
		player.set_process(false)
		player.set_physics_process(false)
		if requested_origin != Vector3.ZERO and player.has_method("teleport_to_world_position"):
			player.teleport_to_world_position(requested_origin + Vector3(0.0, 1.1, 0.0))
	var hud := world.get_node_or_null("Hud") as CanvasLayer
	if hud != null:
		hud.visible = false
	var debug_overlay := world.get_node_or_null("DebugOverlay") as CanvasLayer
	if debug_overlay != null:
		debug_overlay.visible = false

	# Let the streamer mount the near chunks around the spawn.
	for _frame in range(260):
		await process_frame

	var renderer := world.get_node_or_null("ChunkRenderer")
	var building_roots: Array[Node] = []
	if renderer != null:
		building_roots = renderer.find_children("ServiceBuildingRoot", "", true, false)

	var camera := Camera3D.new()
	camera.name = "ProbeCamera"
	camera.far = 6000.0
	world.add_child(camera)
	camera.current = true

	if mode == "aerial":
		camera.fov = 55.0
		camera.position = requested_origin + Vector3(-160.0, 260.0, 420.0)
		camera.look_at_from_position(camera.position, requested_origin + Vector3(-40.0, 40.0, -40.0), Vector3.UP)
	elif mode == "road":
		camera.fov = 62.0
		var road_point := Vector3.ZERO
		var road_direction := Vector3.RIGHT
		var best_distance := INF
		if renderer != null:
			for chunk_id in renderer.get_chunk_ids():
				var chunk_scene = renderer.get_chunk_scene(str(chunk_id))
				if chunk_scene == null:
					continue
				var profile = chunk_scene.get("_profile")
				if not (profile is Dictionary):
					continue
				var chunk_data = chunk_scene.get("_chunk_data")
				var chunk_center := Vector3.ZERO
				if chunk_data is Dictionary:
					chunk_center = (chunk_data as Dictionary).get("chunk_center", Vector3.ZERO)
				for segment_variant in (profile as Dictionary).get("road_segments", []):
					var points: Array = (segment_variant as Dictionary).get("points", [])
					for point_index in range(points.size() - 1):
						var start_point: Vector3 = points[point_index]
						var end_point: Vector3 = points[point_index + 1]
						var midpoint := chunk_center + (start_point + end_point) * 0.5
						var distance := Vector2(midpoint.x - requested_origin.x, midpoint.z - requested_origin.z).length()
						if distance < best_distance:
							best_distance = distance
							road_point = midpoint
							road_direction = (end_point - start_point).normalized()
			var sidewalks := renderer.find_children("Sidewalks", "", true, false)
			var trees := renderer.find_children("StreetTrees", "", true, false)
			var benches := renderer.find_children("Benches", "", true, false)
			var bins := renderer.find_children("Bins", "", true, false)
			print("BUILDING_CAPTURE road=%s distance=%.1f sidewalks=%d trees=%d benches=%d bins=%d" % [str(road_point), best_distance, sidewalks.size(), trees.size(), benches.size(), bins.size()])
			var ground_bodies := renderer.find_children("GroundBody", "", true, false)
			if not ground_bodies.is_empty():
				var ground_mesh := (ground_bodies[0] as Node).get_node_or_null("MeshInstance3D") as MeshInstance3D
				if ground_mesh != null and ground_mesh.material_override is ShaderMaterial:
					var ground_material := ground_mesh.material_override as ShaderMaterial
					print("BUILDING_CAPTURE ground_detail=%s center=%s" % [
						str(ground_material.get_shader_parameter("detail_texture")),
						str(ground_material.get_shader_parameter("chunk_center_world")),
					])
		camera.position = road_point - road_direction * 42.0 + Vector3(0.0, 6.5, 0.0)
		camera.look_at_from_position(camera.position, road_point + road_direction * 42.0 + Vector3(0.0, 2.0, 0.0), Vector3.UP)
	else:
		if building_roots.is_empty():
			push_error("No streamed building roots found for street capture")
			quit(1)
			return
		var focus := Vector3.ZERO
		var camera_position := Vector3.ZERO
		var best_clearance := -INF
		for building_root in building_roots:
			var node_3d := building_root as Node3D
			if node_3d == null:
				continue
			var candidate_focus := node_3d.global_position
			var candidate_camera := _find_clear_street_position(candidate_focus, building_roots)
			var clearance := _clearance_to_buildings(candidate_camera, building_roots)
			if clearance > best_clearance:
				best_clearance = clearance
				focus = candidate_focus
				camera_position = candidate_camera
		print("BUILDING_CAPTURE focus=%s camera=%s clearance=%.1f" % [str(focus), str(camera_position), best_clearance])
		camera.fov = 62.0
		camera.position = camera_position
		camera.look_at_from_position(camera_position, focus + Vector3(0.0, 18.0, 0.0), Vector3.UP)

	for _frame in range(20):
		await process_frame

	var image := root.get_viewport().get_texture().get_image()
	var output_global := output_path
	if output_path.begins_with("user://") or output_path.begins_with("res://"):
		output_global = ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(output_global.get_base_dir())
	var save_error := image.save_png(output_global)
	if save_error != OK:
		push_error("Failed to save city capture: %s" % str(save_error))
		quit(1)
		return
	print("CITY_BUILDING_CAPTURE %s" % output_global)
	quit()

func _find_clear_street_position(focus: Vector3, building_roots: Array[Node]) -> Vector3:
	var best := focus + Vector3(38.0, 7.0, 38.0)
	var best_clearance := -INF
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		for radius in [34.0, 44.0, 56.0]:
			var candidate := focus + Vector3(cos(angle) * radius, 7.0, sin(angle) * radius)
			var clearance := _clearance_to_buildings(candidate, building_roots)
			if clearance > best_clearance:
				best_clearance = clearance
				best = candidate
	return best

func _clearance_to_buildings(point: Vector3, building_roots: Array[Node]) -> float:
	var clearance := INF
	for building_root in building_roots:
		var node_3d := building_root as Node3D
		if node_3d == null:
			continue
		clearance = minf(clearance, point.distance_to(node_3d.global_position))
	return clearance
