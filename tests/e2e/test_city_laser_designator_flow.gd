extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for laser designator flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("set_weapon_mode"), "Laser designator flow requires Player weapon switching"):
		return
	if not T.require_true(self, player.has_method("request_laser_designator_fire"), "Laser designator flow requires left-click request API"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_focus_message_state"), "Laser designator flow requires HUD focus message introspection"):
		return
	if not T.require_true(self, world.has_method("get_last_laser_designator_result"), "Laser designator flow requires last laser result introspection"):
		return
	if not T.require_true(self, world.has_method("get_last_laser_designator_clipboard_text"), "Laser designator flow requires clipboard introspection"):
		return

	var building: StaticBody3D = null
	for _frame in range(24):
		building = _find_sample_building(world, player)
		if building != null:
			break
		await process_frame
	if not T.require_true(self, building != null, "Laser designator flow requires a nearfield building target"):
		return
	if not T.require_true(self, building.has_meta("city_inspection_payload"), "Laser designator flow requires building inspection payload metadata"):
		return
	var building_payload: Dictionary = building.get_meta("city_inspection_payload", {})
	if not T.require_true(self, str(building_payload.get("building_id", "")) != "", "Laser designator flow requires a formal building_id in the building inspection payload"):
		return
	if not T.require_true(self, str(building_payload.get("display_name", "")) != "", "Laser designator flow requires a formal unique building display_name in the payload"):
		return

	player.set_weapon_mode("laser_designator")
	_aim_player_at_world_position(player, building.global_position)
	await process_frame

	var started: bool = player.request_laser_designator_fire()
	await process_frame
	if not T.require_true(self, started, "Laser designator flow must accept the player fire request in laser mode"):
		return

	var result: Dictionary = world.get_last_laser_designator_result()
	if not T.require_true(self, str(result.get("inspection_kind", "")) == "building", "Laser designator flow must resolve the aimed building into building inspection state"):
		return
	if not T.require_true(self, str(result.get("building_id", "")) == str(building_payload.get("building_id", "")), "Laser designator flow must preserve the same building_id from collider payload into runtime inspection result"):
		return

	var message_state: Dictionary = hud.get_focus_message_state()
	if not T.require_true(self, bool(message_state.get("visible", false)), "Laser designator flow must show a visible HUD focus message after inspection"):
		return
	if not T.require_true(self, str(message_state.get("text", "")).find(str(building_payload.get("display_name", ""))) >= 0, "Laser designator flow HUD message must include the resolved building display_name"):
		return
	if not T.require_true(self, str(world.get_last_laser_designator_clipboard_text()).find(str(building_payload.get("display_name", ""))) >= 0, "Laser designator flow must copy the resolved inspection text into the clipboard contract"):
		return
	if not T.require_true(self, str(world.get_last_laser_designator_clipboard_text()).find(str(building_payload.get("building_id", ""))) >= 0, "Laser designator flow clipboard contract must include the formal building_id for later reuse"):
		return

	await create_timer(10.25).timeout
	await process_frame

	message_state = hud.get_focus_message_state()
	if not T.require_true(self, not bool(message_state.get("visible", true)), "Laser designator flow HUD message must auto-clear after 10 seconds"):
		return
	if not T.require_true(self, str(message_state.get("text", "")) == "", "Laser designator flow must fully clear the expired HUD message text"):
		return

	world.queue_free()
	T.pass_and_quit(self)

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
	var space_state = world.get_world_3d().direct_space_state if world.get_world_3d() != null else null
	if space_state == null:
		return false
	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var origin: Vector3 = camera.global_position if camera != null else player.global_position + Vector3.UP * 1.4
	var exclusions: Array[RID] = []
	if player is CollisionObject3D:
		exclusions.append((player as CollisionObject3D).get_rid())
	var generated_city := world.get_node_or_null("GeneratedCity") as Node
	for _attempt in range(8):
		var query := PhysicsRayQueryParameters3D.create(origin, building.global_position)
		query.collide_with_areas = false
		query.exclude = exclusions
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			return false
		var collider := hit.get("collider") as Node
		if collider == building:
			return true
		if collider != null and generated_city != null and (collider == generated_city or generated_city.is_ancestor_of(collider)):
			if collider is CollisionObject3D:
				exclusions.append((collider as CollisionObject3D).get_rid())
				continue
		return false
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
