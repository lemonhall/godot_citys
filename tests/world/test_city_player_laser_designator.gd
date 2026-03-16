extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for laser designator contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Laser designator contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for laser weapon switching"):
		return
	if not T.require_true(self, player.has_method("get_weapon_mode"), "PlayerController must expose get_weapon_mode() for laser weapon verification"):
		return
	if not T.require_true(self, player.has_method("request_laser_designator_fire"), "PlayerController must expose request_laser_designator_fire() for laser left-click contract"):
		return
	if not T.require_true(self, player.has_method("get_pitch_limits_degrees"), "Laser designator test requires player pitch limits for deterministic aiming"):
		return
	if not T.require_true(self, world.has_method("get_last_laser_designator_result"), "CityPrototype must expose get_last_laser_designator_result() for inspection verification"):
		return
	if not T.require_true(self, world.has_method("get_last_laser_designator_clipboard_text"), "CityPrototype must expose get_last_laser_designator_clipboard_text() for clipboard verification"):
		return
	if not T.require_true(self, world.has_method("get_building_generation_contract"), "CityPrototype must expose get_building_generation_contract() for future building replacement anchoring"):
		return
	if not T.require_true(self, world.has_method("inspect_laser_designator_segment"), "CityPrototype must expose inspect_laser_designator_segment() for deterministic chunk inspection verification"):
		return
	if not T.require_true(self, world.has_method("get_active_laser_beam_count"), "CityPrototype must expose get_active_laser_beam_count() for beam verification"):
		return
	if not T.require_true(self, world.has_method("get_active_projectile_count"), "Laser designator regression test requires projectile count introspection"):
		return
	if not T.require_true(self, world.has_method("get_active_grenade_count"), "Laser designator regression test requires grenade count introspection"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "Laser designator contract requires Hud node"):
		return
	if not T.require_true(self, hud.has_method("get_focus_message_state"), "PrototypeHud must expose get_focus_message_state() for inspection message verification"):
		return
	if not T.require_true(self, hud.has_method("get_crosshair_state"), "PrototypeHud must expose get_crosshair_state() for laser HUD verification"):
		return

	player.set_weapon_mode("laser_designator")
	await process_frame

	if not T.require_true(self, player.get_weapon_mode() == "laser_designator", "Laser designator must be a formal third weapon mode"):
		return

	player.set_aim_down_sights_active(true)
	for _frame in range(8):
		await process_frame
	var crosshair_state: Dictionary = hud.get_crosshair_state()
	if not T.require_true(self, bool(crosshair_state.get("visible", false)), "Laser designator mode must keep the screen-space crosshair visible"):
		return
	if not T.require_true(self, bool(crosshair_state.get("aim_down_sights_active", false)), "Laser designator mode must be allowed to reuse ADS/crosshair state"):
		return

	var projectile_count_before := int(world.get_active_projectile_count())
	var grenade_count_before := int(world.get_active_grenade_count())
	var rifle_fire_started: bool = player.request_primary_fire()
	await process_frame
	if not T.require_true(self, not rifle_fire_started, "Laser designator mode must not keep firing rifle bullets"):
		return
	if not T.require_true(self, int(world.get_active_projectile_count()) == projectile_count_before, "Laser designator mode must not spawn projectile nodes"):
		return
	if not T.require_true(self, int(world.get_active_grenade_count()) == grenade_count_before, "Laser designator mode must not spawn grenade nodes"):
		return

	var building: StaticBody3D = null
	for _frame in range(24):
		building = _find_sample_building(world, player)
		if building != null:
			break
		await process_frame
	if not T.require_true(self, building != null, "Laser designator contract requires at least one nearfield building target"):
		return
	if not T.require_true(self, building.has_meta("city_inspection_payload"), "Nearfield building collider must expose city_inspection_payload metadata for v15 inspection"):
		return

	var building_payload: Dictionary = building.get_meta("city_inspection_payload", {})
	if not T.require_true(self, str(building_payload.get("building_id", "")) != "", "Nearfield building payload must expose a formal non-empty building_id"):
		return
	if not T.require_true(self, str(building_payload.get("display_name", "")) != "", "Nearfield building payload must expose a formal non-empty unique display_name"):
		return
	if not T.require_true(self, str(building_payload.get("address_label", "")) != "", "Nearfield building payload must preserve the human-readable address label alongside the unique building name"):
		return
	if not _require_active_building_identity_uniqueness(world):
		return
	var building_target := building.global_position
	_aim_player_at_world_position(player, building_target)
	await process_frame

	var beam_count_before := int(world.get_active_laser_beam_count())
	var laser_started: bool = player.request_laser_designator_fire()
	await process_frame
	if not T.require_true(self, laser_started, "Laser designator mode must accept left-click fire requests"):
		return
	if not T.require_true(self, int(world.get_active_laser_beam_count()) == beam_count_before + 1, "Each laser fire request must spawn one active beam pulse"):
		return

	var building_result: Dictionary = world.get_last_laser_designator_result()
	if not T.require_true(self, str(building_result.get("inspection_kind", "")) == "building", "Laser hitting a building must resolve to building inspection kind"):
		return
	if not T.require_true(self, str(building_result.get("building_id", "")) != "", "Laser building inspection must surface a non-empty formal building_id"):
		return
	if not T.require_true(self, str(building_result.get("display_name", "")) != "", "Laser building inspection must surface a non-empty deterministic display_name"):
		return
	if not T.require_true(self, str(building_result.get("address_label", "")) != "", "Laser building inspection must preserve the human-readable address label"):
		return
	if not T.require_true(self, str(building_result.get("place_id", "")) != "", "Laser building inspection must preserve a non-empty deterministic place_id"):
		return
	if not T.require_true(self, str(building_result.get("chunk_id", "")) != "", "Laser building inspection must preserve source chunk_id metadata"):
		return
	if not T.require_true(self, building_result.has("chunk_key"), "Laser building inspection must preserve source chunk_key metadata"):
		return
	var building_generation_contract: Dictionary = world.get_building_generation_contract(str(building_result.get("building_id", "")))
	if not T.require_true(self, not building_generation_contract.is_empty(), "Laser building inspection building_id must resolve back to streamed generation parameters"):
		return
	if not T.require_true(self, str(building_generation_contract.get("building_id", "")) == str(building_result.get("building_id", "")), "Generation contract lookup must round-trip the same building_id"):
		return

	var message_state: Dictionary = hud.get_focus_message_state()
	if not T.require_true(self, bool(message_state.get("visible", false)), "Laser building inspection must show a HUD focus message"):
		return
	if not T.require_true(self, str(message_state.get("text", "")).find(str(building_result.get("display_name", ""))) >= 0, "Laser building inspection message must include the resolved building label"):
		return
	var building_clipboard_text := str(world.get_last_laser_designator_clipboard_text())
	if not T.require_true(self, building_clipboard_text.find(str(building_result.get("display_name", ""))) >= 0, "Laser building inspection must refresh clipboard text to the same building label"):
		return
	if not T.require_true(self, building_clipboard_text.find(str(building_result.get("building_id", ""))) >= 0, "Laser building inspection clipboard text must include the formal building_id for later paste/export workflows"):
		return

	var ground_sample: Dictionary = _find_vertical_ground_sample(world, player.global_position)
	if not T.require_true(self, not ground_sample.is_empty(), "Laser designator contract requires a deterministic ground sample for chunk inspection"):
		return
	var ground_origin: Vector3 = ground_sample.get("origin", Vector3.ZERO)
	var ground_target: Vector3 = ground_sample.get("target", Vector3.ZERO)
	var ground_result_started: Dictionary = world.inspect_laser_designator_segment(ground_origin, ground_target)
	await process_frame
	if not T.require_true(self, not ground_result_started.is_empty(), "Laser designator must support a second inspection result within the active HUD timeout window"):
		return

	var chunk_result: Dictionary = world.get_last_laser_designator_result()
	if not T.require_true(self, str(chunk_result.get("inspection_kind", "")) == "chunk", "Laser hitting the ground must resolve to chunk inspection kind"):
		return
	if not T.require_true(self, str(chunk_result.get("chunk_id", "")) != "", "Chunk inspection must expose non-empty chunk_id"):
		return
	if not T.require_true(self, chunk_result.has("chunk_key"), "Chunk inspection must expose chunk_key"):
		return

	message_state = hud.get_focus_message_state()
	if not T.require_true(self, bool(message_state.get("visible", false)), "Chunk inspection must also show a HUD focus message"):
		return
	if not T.require_true(self, str(message_state.get("text", "")).find(str(chunk_result.get("chunk_id", ""))) >= 0, "Chunk inspection message must include the resolved chunk_id"):
		return
	if not T.require_true(self, float(message_state.get("remaining_sec", 0.0)) >= 9.0, "A second inspection within the 10 second window must immediately refresh the HUD message lifetime"):
		return
	var chunk_clipboard_text := str(world.get_last_laser_designator_clipboard_text())
	if not T.require_true(self, chunk_clipboard_text.find(str(chunk_result.get("chunk_id", ""))) >= 0, "Chunk inspection must refresh clipboard text to the current chunk info"):
		return
	if not T.require_true(self, chunk_clipboard_text != building_clipboard_text, "A second inspection result must replace the prior clipboard text instead of leaving the first value latched for 10 seconds"):
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

func _find_vertical_ground_sample(world, center_world_position: Vector3) -> Dictionary:
	if world == null or not world.has_method("_perform_laser_designator_trace"):
		return {}
	var directions := [
		Vector2.ZERO,
		Vector2(0.0, -1.0),
		Vector2(1.0, 0.0),
		Vector2(-1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(0.707, -0.707),
		Vector2(-0.707, -0.707),
		Vector2(0.707, 0.707),
		Vector2(-0.707, 0.707),
	]
	for distance_m in [0.0, 28.0, 56.0, 84.0, 112.0, 140.0]:
		for direction_variant in directions:
			var direction: Vector2 = direction_variant
			var sample_origin := Vector3(
				center_world_position.x + direction.x * distance_m,
				center_world_position.y + 180.0,
				center_world_position.z + direction.y * distance_m
			)
			var sample_target := sample_origin + Vector3.DOWN * 320.0
			var hit: Dictionary = world._perform_laser_designator_trace(sample_origin, sample_target)
			if hit.is_empty():
				continue
			var collider := hit.get("collider") as Node
			if collider == null or not collider.has_meta("city_inspection_payload"):
				return {
					"origin": sample_origin,
					"target": sample_target,
					"hit_position": hit.get("position", sample_target),
				}
	return {}

func _require_active_building_identity_uniqueness(world) -> bool:
	var payloads := _collect_active_building_payloads(world)
	if not T.require_true(self, payloads.size() > 0, "Laser designator contract requires at least one active building payload for uniqueness verification"):
		return false
	var seen_building_ids: Dictionary = {}
	var seen_display_names: Dictionary = {}
	for payload_variant in payloads:
		var payload: Dictionary = payload_variant
		var building_id := str(payload.get("building_id", ""))
		var display_name := str(payload.get("display_name", ""))
		if not T.require_true(self, building_id != "", "Every active building payload must expose a non-empty building_id"):
			return false
		if not T.require_true(self, display_name != "", "Every active building payload must expose a non-empty unique display_name"):
			return false
		if not T.require_true(self, not seen_building_ids.has(building_id), "Active streamed building_id values must stay globally unique within the mounted city window"):
			return false
		if not T.require_true(self, not seen_display_names.has(display_name), "Active streamed building display_name values must stay globally unique within the mounted city window"):
			return false
		seen_building_ids[building_id] = true
		seen_display_names[display_name] = true
	return true

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
		for child in near_group.get_children():
			var body := child as StaticBody3D
			if body == null or not body.has_meta("city_inspection_payload"):
				continue
			payloads.append(body.get_meta("city_inspection_payload", {}))
	return payloads
