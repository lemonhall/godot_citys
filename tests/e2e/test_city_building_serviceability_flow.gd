extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for building serviceability flow")
		return

	var test_paths := _make_test_paths("e2e")
	var world: Node = await _instantiate_world(scene, test_paths)
	if world == null:
		return

	if not T.require_true(self, world.has_method("find_building_override_node"), "CityPrototype must expose find_building_override_node() for next-session override validation"):
		return
	if not T.require_true(self, world.has_method("get_building_export_state"), "CityPrototype must expose get_building_export_state() for export flow introspection"):
		return

	var player: Node = world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("set_weapon_mode"), "Building serviceability flow requires Player weapon switching"):
		return
	if not T.require_true(self, player.has_method("request_laser_designator_fire"), "Building serviceability flow requires laser request API"):
		return

	var hud: Node = world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_focus_message_state"), "Building serviceability flow requires HUD focus message introspection"):
		return

	var building: StaticBody3D = null
	for _frame in range(24):
		building = _find_sample_building(world, player)
		if building != null:
			break
		await process_frame
	if not T.require_true(self, building != null, "Building serviceability flow requires a nearfield building target"):
		return

	var building_payload: Dictionary = building.get_meta("city_inspection_payload", {})
	var building_id := str(building_payload.get("building_id", ""))
	if not T.require_true(self, building_id != "", "Building serviceability flow requires a formal building_id payload"):
		return

	player.set_weapon_mode("laser_designator")
	_aim_player_at_world_position(player, building.global_position)
	await process_frame

	var laser_started: bool = player.request_laser_designator_fire()
	await process_frame
	if not T.require_true(self, laser_started, "Building serviceability flow must start from a successful laser inspection request"):
		return

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_KP_ADD
	key_event.physical_keycode = KEY_KP_ADD
	world._unhandled_input(key_event)
	await process_frame

	var running_state: Dictionary = world.get_building_export_state()
	if not T.require_true(self, bool(running_state.get("running", false)), "KP+ after a recent building inspection must start the async export job"):
		return

	var completed_state := await _wait_for_export_completion(world)
	if not T.require_true(self, str(completed_state.get("status", "")) == "completed", "Building serviceability flow export job must complete successfully"):
		return

	var scene_path := str(completed_state.get("scene_path", ""))
	if not T.require_true(self, scene_path != "", "Building serviceability flow must expose the exported scene path on completion"):
		return

	var message_state: Dictionary = hud.get_focus_message_state()
	if not T.require_true(self, bool(message_state.get("visible", false)), "Building serviceability flow must show a completion Toast"):
		return
	if not T.require_true(self, str(message_state.get("text", "")).find("重构") >= 0 or str(message_state.get("text", "")).find("export") >= 0, "Building serviceability flow completion Toast must describe the export result"):
		return

	world.queue_free()
	await process_frame

	var next_world: Node = await _instantiate_world(scene, test_paths)
	if next_world == null:
		return

	var override_node: Node = await _wait_for_override_node(next_world, building_id)
	if not T.require_true(self, override_node != null, "A second world session must mount the exported override scene for the same building_id"):
		return
	if not T.require_true(self, bool(override_node.get_meta("city_building_override", false)), "Mounted override node must advertise city_building_override metadata"):
		return
	if not T.require_true(self, str(override_node.get_meta("city_building_override_scene_path", "")) == scene_path, "Mounted override node must point back at the exported scene path"):
		return

	var active_payloads := _collect_active_building_payloads(next_world)
	var other_building_id := _find_other_building_id(active_payloads, building_id)
	if other_building_id != "":
		if not T.require_true(self, next_world.find_building_override_node(other_building_id) == null, "Buildings without override entries must continue using procedural nearfield roots"):
			return

	next_world.queue_free()
	T.pass_and_quit(self)

func _instantiate_world(scene: PackedScene, test_paths: Dictionary) -> Node:
	var world := scene.instantiate()
	if not T.require_true(self, world.has_method("configure_building_serviceability_paths"), "CityPrototype must expose configure_building_serviceability_paths() before world add_child"):
		return null
	world.configure_building_serviceability_paths(
		test_paths.get("preferred_scene_root", ""),
		test_paths.get("fallback_scene_root", ""),
		test_paths.get("registry_path", "")
	)
	root.add_child(world)
	await process_frame
	return world

func _wait_for_export_completion(world) -> Dictionary:
	for _frame in range(180):
		await process_frame
		var state: Dictionary = world.get_building_export_state()
		if not bool(state.get("running", false)):
			return state
	return world.get_building_export_state()

func _wait_for_override_node(world, building_id: String) -> Node:
	for _frame in range(60):
		var node = world.find_building_override_node(building_id)
		if node != null:
			return node
		await process_frame
	return world.find_building_override_node(building_id)

func _collect_active_building_payloads(world) -> Array:
	var payloads: Array = []
	var chunk_renderer = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else world.get_node_or_null("ChunkRenderer")
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_ids") or not chunk_renderer.has_method("get_chunk_scene"):
		return payloads
	for chunk_id_variant in chunk_renderer.get_chunk_ids():
		var chunk_scene = chunk_renderer.get_chunk_scene(str(chunk_id_variant))
		if chunk_scene == null:
			continue
		var near_group := chunk_scene.get_node_or_null("NearGroup") as Node3D
		if near_group == null:
			continue
		_collect_payloads_recursive(near_group, payloads)
	return payloads

func _collect_payloads_recursive(node: Node, payloads: Array) -> void:
	if node == null:
		return
	if node.has_meta("city_inspection_payload"):
		payloads.append(node.get_meta("city_inspection_payload", {}))
	for child in node.get_children():
		_collect_payloads_recursive(child, payloads)

func _find_other_building_id(payloads: Array, target_building_id: String) -> String:
	for payload_variant in payloads:
		var payload: Dictionary = payload_variant
		var candidate := str(payload.get("building_id", ""))
		if candidate != "" and candidate != target_building_id:
			return candidate
	return ""

func _make_test_paths(scope: String) -> Dictionary:
	var unique_id := "%s_%d" % [scope, Time.get_ticks_msec()]
	var base_root := "user://serviceability_tests/%s" % unique_id
	return {
		"preferred_scene_root": "%s/generated" % base_root,
		"fallback_scene_root": "%s/generated_fallback" % base_root,
		"registry_path": "%s/generated/building_override_registry.json" % base_root,
	}

func _find_sample_building(world, player) -> StaticBody3D:
	var chunk_renderer = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else world.get_node_or_null("ChunkRenderer")
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_ids") or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	var fallback_building: StaticBody3D = null
	for chunk_id_variant in chunk_renderer.get_chunk_ids():
		var chunk_scene = chunk_renderer.get_chunk_scene(str(chunk_id_variant))
		if chunk_scene == null:
			continue
		var near_group := chunk_scene.get_node_or_null("NearGroup") as Node3D
		if near_group == null:
			continue
		for child in near_group.get_children():
			var body := child as StaticBody3D
			if body == null:
				continue
			if fallback_building == null:
				fallback_building = body
			if _can_trace_building(world, player, body):
				return body
	return fallback_building

func _can_trace_building(world, player, building: StaticBody3D) -> bool:
	if world == null or player == null or building == null:
		return false
	_aim_player_at_world_position(player, building.global_position)
	if player.has_method("get_aim_trace_segment") and world.has_method("_perform_laser_designator_trace"):
		var trace_segment: Dictionary = player.get_aim_trace_segment()
		var hit_via_runtime: Dictionary = world._perform_laser_designator_trace(
			trace_segment.get("origin", Vector3.ZERO),
			trace_segment.get("target", Vector3.ZERO)
		)
		return hit_via_runtime.get("collider", null) == building
	return false

func _aim_player_at_world_position(player, target_world_position: Vector3) -> void:
	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig == null:
		return
	var aim_origin: Vector3 = camera.global_position if camera != null else player.global_position + Vector3.UP * 1.4
	var delta: Vector3 = target_world_position - aim_origin
	var planar_length := maxf(Vector2(delta.x, delta.z).length(), 0.001)
	player.rotation.y = atan2(-delta.x, -delta.z)
	var pitch_limits: Dictionary = player.get_pitch_limits_degrees()
	var min_pitch := deg_to_rad(float(pitch_limits.get("min", -68.0)))
	var max_pitch := deg_to_rad(float(pitch_limits.get("max", 35.0)))
	camera_rig.rotation.x = clampf(-atan2(delta.y, planar_length), min_pitch, max_pitch)
