extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for building serviceability export contract")
		return

	var test_paths := _make_test_paths("world")
	var world := (scene as PackedScene).instantiate()
	if not T.require_true(self, world.has_method("configure_building_serviceability_paths"), "CityPrototype must expose configure_building_serviceability_paths() for deterministic export paths"):
		return
	world.configure_building_serviceability_paths(
		test_paths.get("preferred_scene_root", ""),
		test_paths.get("fallback_scene_root", ""),
		test_paths.get("registry_path", "")
	)
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("request_export_from_last_building_inspection"), "CityPrototype must expose request_export_from_last_building_inspection() for v16 export requests"):
		return
	if not T.require_true(self, world.has_method("get_building_export_state"), "CityPrototype must expose get_building_export_state() for async export introspection"):
		return
	if not T.require_true(self, world.has_method("get_building_override_entry"), "CityPrototype must expose get_building_override_entry() for registry validation"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("set_weapon_mode"), "Building serviceability export requires Player weapon switching"):
		return
	if not T.require_true(self, player.has_method("request_laser_designator_fire"), "Building serviceability export requires laser request API"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_focus_message_state"), "Building serviceability export requires HUD focus message introspection"):
		return

	var building: StaticBody3D = null
	for _frame in range(24):
		building = _find_sample_building(world, player)
		if building != null:
			break
		await process_frame
	if not T.require_true(self, building != null, "Building serviceability export requires a nearfield building target"):
		return
	if not T.require_true(self, building.has_meta("city_inspection_payload"), "Building serviceability export requires building inspection payload metadata"):
		return
	var building_payload: Dictionary = building.get_meta("city_inspection_payload", {})
	var building_id := str(building_payload.get("building_id", ""))
	if not T.require_true(self, building_id != "", "Building serviceability export requires a formal building_id in the payload"):
		return

	player.set_weapon_mode("laser_designator")
	_aim_player_at_world_position(player, building.global_position)
	await process_frame

	var started: bool = player.request_laser_designator_fire()
	await process_frame
	if not T.require_true(self, started, "Building serviceability export requires a successful laser inspection request"):
		return

	var inspection_result: Dictionary = world.get_last_laser_designator_result() if world.has_method("get_last_laser_designator_result") else {}
	if not T.require_true(self, str(inspection_result.get("inspection_kind", "")) == "building", "Building serviceability export requires a building inspection result before KP+ export"):
		return

	var export_request: Dictionary = world.request_export_from_last_building_inspection()
	if not T.require_true(self, bool(export_request.get("accepted", false)), "A recent building inspection must allow one export request to start"):
		return
	var duplicate_request: Dictionary = world.request_export_from_last_building_inspection()
	if not T.require_true(self, not bool(duplicate_request.get("accepted", true)), "A second export request while the first one is still running must be rejected"):
		return

	var running_state: Dictionary = world.get_building_export_state()
	if not T.require_true(self, bool(running_state.get("running", false)), "Export state must enter running while the async export job is active"):
		return
	if not T.require_true(self, str(running_state.get("building_id", "")) == building_id, "Export state must preserve the building_id being exported"):
		return

	var completed_state := await _wait_for_export_completion(world)
	if not T.require_true(self, str(completed_state.get("status", "")) == "completed", "Building export job must eventually complete successfully"):
		return

	var scene_path := str(completed_state.get("scene_path", ""))
	var manifest_path := str(completed_state.get("manifest_path", ""))
	if not T.require_true(self, scene_path != "", "Completed building export must expose a non-empty scene_path"):
		return
	if not T.require_true(self, manifest_path != "", "Completed building export must expose a non-empty manifest_path"):
		return
	if not T.require_true(self, FileAccess.file_exists(_globalize_path(scene_path)), "Exported building scene file must exist on disk"):
		return
	if not T.require_true(self, FileAccess.file_exists(_globalize_path(manifest_path)), "Exported building manifest file must exist on disk"):
		return
	if not T.require_true(self, ResourceLoader.exists(scene_path, "PackedScene"), "Exported building scene path must be loadable as a PackedScene"):
		return

	var manifest_variant = JSON.parse_string(FileAccess.get_file_as_string(_globalize_path(manifest_path)))
	if not T.require_true(self, manifest_variant is Dictionary, "Exported building manifest must parse as a Dictionary JSON payload"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("building_id", "")) == building_id, "Exported building manifest must preserve the same building_id"):
		return
	if not T.require_true(self, str(manifest.get("scene_path", "")) == scene_path, "Exported building manifest must preserve the saved scene_path"):
		return
	if not T.require_true(self, not (manifest.get("generation_locator", {}) as Dictionary).is_empty(), "Exported building manifest must retain the original generation_locator sidecar"):
		return
	if not T.require_true(self, not (manifest.get("source_building_contract", {}) as Dictionary).is_empty(), "Exported building manifest must retain the original source building contract"):
		return

	var exported_scene := load(scene_path)
	if not T.require_true(self, exported_scene != null and exported_scene is PackedScene, "Exported building scene must load back as PackedScene"):
		return
	var exported_root := (exported_scene as PackedScene).instantiate()
	if not T.require_true(self, exported_root is Node3D, "Exported building scene must instantiate as a Node3D root"):
		return
	if not T.require_true(self, _scene_contains_generated_building(exported_root), "Exported building scene must contain the reconstructed generated building shell instead of an empty root"):
		return

	var registry_entry: Dictionary = world.get_building_override_entry(building_id)
	if not T.require_true(self, not registry_entry.is_empty(), "Completed building export must persist a non-empty override registry entry"):
		return
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == scene_path, "Override registry entry must point at the exported scene_path"):
		return
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == manifest_path, "Override registry entry must point at the exported manifest_path"):
		return

	var message_state: Dictionary = hud.get_focus_message_state()
	if not T.require_true(self, bool(message_state.get("visible", false)), "Building export completion must surface a visible HUD Toast"):
		return
	if not T.require_true(self, str(message_state.get("text", "")).find("重构") >= 0 or str(message_state.get("text", "")).find("export") >= 0, "Building export completion Toast must mention the reconstruction/export result"):
		return

	var repeated_started: bool = player.request_laser_designator_fire()
	await process_frame
	if not T.require_true(self, repeated_started, "Repeated export protection still requires a fresh building inspection request"):
		return
	var repeated_export_request: Dictionary = world.request_export_from_last_building_inspection()
	if not T.require_true(self, not bool(repeated_export_request.get("accepted", true)), "A building that already has an exported override must reject silent overwrite requests"):
		return

	if exported_root is Node:
		(exported_root as Node).queue_free()
	world.queue_free()
	await process_frame

	var exit_paths := _make_test_paths("exit")
	var exit_world := (scene as PackedScene).instantiate()
	exit_world.configure_building_serviceability_paths(
		exit_paths.get("preferred_scene_root", ""),
		exit_paths.get("fallback_scene_root", ""),
		exit_paths.get("registry_path", "")
	)
	root.add_child(exit_world)
	await process_frame

	var exit_player := exit_world.get_node_or_null("Player")
	if not T.require_true(self, exit_player != null and exit_player.has_method("set_weapon_mode"), "Shutdown persistence test requires Player node"):
		return
	var exit_building: StaticBody3D = null
	for _frame in range(24):
		exit_building = _find_sample_building(exit_world, exit_player)
		if exit_building != null:
			break
		await process_frame
	if not T.require_true(self, exit_building != null, "Shutdown persistence test requires a nearfield building target"):
		return
	var exit_payload: Dictionary = exit_building.get_meta("city_inspection_payload", {})
	var exit_building_id := str(exit_payload.get("building_id", ""))
	if not T.require_true(self, exit_building_id != "", "Shutdown persistence test requires a formal building_id"):
		return
	exit_player.set_weapon_mode("laser_designator")
	_aim_player_at_world_position(exit_player, exit_building.global_position)
	await process_frame
	var exit_started: bool = exit_player.request_laser_designator_fire()
	await process_frame
	if not T.require_true(self, exit_started, "Shutdown persistence test requires a successful laser inspection request"):
		return
	var exit_export_request: Dictionary = exit_world.request_export_from_last_building_inspection()
	if not T.require_true(self, bool(exit_export_request.get("accepted", false)), "Shutdown persistence test requires the export request to start before queue_free"):
		return
	exit_world.queue_free()
	for _frame in range(12):
		await process_frame

	var exit_registry_path := str(exit_paths.get("registry_path", ""))
	if not T.require_true(self, FileAccess.file_exists(_globalize_path(exit_registry_path)), "World shutdown during export must still persist the override registry to disk"):
		return
	var exit_registry_variant = JSON.parse_string(FileAccess.get_file_as_string(_globalize_path(exit_registry_path)))
	if not T.require_true(self, exit_registry_variant is Dictionary, "Shutdown export registry must remain valid JSON"):
		return
	var exit_registry_payload: Dictionary = exit_registry_variant
	var exit_entries: Dictionary = exit_registry_payload.get("entries", {})
	if not T.require_true(self, exit_entries.has(exit_building_id), "World shutdown during export must keep the building override entry instead of dropping it on exit"):
		return
	T.pass_and_quit(self)

func _wait_for_export_completion(world) -> Dictionary:
	for _frame in range(180):
		await process_frame
		var state: Dictionary = world.get_building_export_state()
		if not bool(state.get("running", false)):
			return state
	return world.get_building_export_state()

func _make_test_paths(scope: String) -> Dictionary:
	var unique_id := "%s_%d" % [scope, Time.get_ticks_msec()]
	var base_root := "user://serviceability_tests/%s" % unique_id
	return {
		"preferred_scene_root": "%s/generated" % base_root,
		"fallback_scene_root": "%s/generated_fallback" % base_root,
		"registry_path": "%s/generated/building_override_registry.json" % base_root,
	}

func _globalize_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path

func _scene_contains_generated_building(scene_root) -> bool:
	if scene_root == null or not (scene_root is Node):
		return false
	var node := scene_root as Node
	if str(node.get_meta("city_building_id", "")) != "":
		return true
	for child in node.get_children():
		if _scene_contains_generated_building(child):
			return true
	return false

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
