extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityArtilleryBallisticsScript := preload("res://city_game/combat/artillery/CityArtilleryBallistics.gd")

const TENNIS_CHUNK_ID := "chunk_158_140"
const TENNIS_VENUE_ID := "venue:v28:tennis_court:chunk_158_140"
const TENNIS_WORLD_POSITION := Vector3(5489.46, 20.62, 1029.73)
const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)
const TARGET_SURFACE_OFFSET_M := 0.1
const EXPECTED_RANGE_MIN_M := 4000.0
const EXPECTED_RANGE_MAX_M := 7000.0
const MISSION_TARGET_TOLERANCE_M := 2.0
const LIVE_SOLUTION_TARGET_TOLERANCE_M := 2.0
const IMPACT_TO_PREDICTION_TOLERANCE_M := 2.5

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for artillery tennis-court hit flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("request_artillery_fire_mission_from_world_point"), "Artillery tennis-court hit flow requires the formal artillery mission planning API"):
		return
	if not T.require_true(self, world.has_method("get_artillery_fire_mission_state"), "Artillery tennis-court hit flow requires artillery fire-mission state introspection"):
		return
	if not T.require_true(self, world.has_method("get_last_artillery_shell_explosion_result"), "Artillery tennis-court hit flow requires live shell explosion introspection"):
		return
	if not T.require_true(self, world.has_method("get_active_world_howitzer"), "Artillery tennis-court hit flow requires active world howitzer introspection"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Artillery tennis-court hit flow requires chunk renderer introspection so the target venue can be verified"):
		return

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Artillery tennis-court hit flow requires the formal PlayerController teleport API"):
		return

	var spawn_world_position := player.global_position
	var spawn_rotation_y := player.rotation.y
	var standing_height := _estimate_standing_height(player)

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, standing_height, 10.0))
	await _settle_frames(12)

	var mounted_venue: Node3D = await _wait_for_mounted_venue(world, 240)
	if not T.require_true(self, mounted_venue != null, "Artillery tennis-court hit flow requires the target tennis venue to mount so the court bounds can be verified"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_tennis_court_contract"), "Artillery tennis-court hit flow requires get_tennis_court_contract() on the mounted tennis venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("is_world_point_in_play_bounds"), "Artillery tennis-court hit flow requires the mounted tennis venue play-bounds query"):
		return

	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract()
	var target_world_position := Vector3(
		mounted_venue.global_position.x,
		float(court_contract.get("surface_top_y", mounted_venue.global_position.y)) + TARGET_SURFACE_OFFSET_M,
		mounted_venue.global_position.z
	)
	if not T.require_true(self, bool(mounted_venue.is_world_point_in_play_bounds(target_world_position)), "The tennis-court artillery target fixture must resolve to a point inside the formal tennis play bounds instead of an arbitrary nearby empty lot"):
		return

	player.teleport_to_world_position(spawn_world_position)
	player.rotation.y = spawn_rotation_y
	await _settle_frames(12)

	var planning_origin := player.global_position
	var mission_contract := world.request_artillery_fire_mission_from_world_point(target_world_position) as Dictionary
	if not T.require_true(self, not mission_contract.is_empty(), "Planning artillery onto the tennis court must return a formal mission contract instead of silently failing"):
		return

	var mission_state := world.get_artillery_fire_mission_state() as Dictionary
	var solution_state: Dictionary = mission_state.get("solution_state", {})
	if not T.require_true(self, not bool(solution_state.get("solved", false)), "The tennis-court artillery flow must keep the mission pending after target marking instead of solving firing data before a real spawned howitzer is being operated"):
		return
	if not T.require_true(self, str(solution_state.get("reason", "")) == "requires_live_howitzer_operation", "Pending tennis-court artillery state must explain that the live howitzer still needs to be spawned and operated before solving firing data"):
		return
	if not T.require_true(self, (mission_state.get("resolved_battery_snapshot", {}) as Dictionary).is_empty(), "Before the howitzer is spawned and operated, the tennis-court flow must not fabricate a live solved battery snapshot"):
		return

	var battery_snapshot: Dictionary = mission_state.get("battery_snapshot", {})
	var planned_spawn_root_world_position := battery_snapshot.get("spawn_root_world_position", Vector3.ZERO) as Vector3
	var planned_spawn_horizontal_distance_m := _horizontal_distance(planning_origin, planned_spawn_root_world_position)
	if not T.require_true(self, planned_spawn_horizontal_distance_m >= 4.0 and planned_spawn_horizontal_distance_m <= 18.0, "The artillery tennis-court fixture must still place the battery near the spawn area instead of relocating it far away (spawn_distance=%0.2fm)" % planned_spawn_horizontal_distance_m):
		return

	var spawned: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, spawned, "The planned tennis-court fire mission must still allow summoning the world howitzer"):
		return
	await _settle_frames(10)

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("set_axis_angles_degrees") and howitzer.has_method("get_firing_solution_snapshot"), "The tennis-court artillery flow requires the summoned howitzer runtime and its live firing solution snapshot API"):
		return
	if not T.require_true(self, howitzer.global_position.distance_to(planned_spawn_root_world_position) <= 0.75, "The summoned howitzer must reuse the planned spawn snapshot for the tennis-court mission instead of drifting away from the spawn-area battery plan"):
		return

	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.teleport_to_world_position(anchor_world + APPROACH_OFFSET)
	await _settle_frames()

	_press_key(world, KEY_E)
	await _settle_frames()

	mission_state = await _wait_for_solved_fire_mission(world, 120)
	solution_state = mission_state.get("solution_state", {})
	if not T.require_true(self, bool(solution_state.get("solved", false)), "After entering操炮状态, the tennis-court artillery flow must solve firing data from the real spawned howitzer instead of keeping the mission pending"):
		return
	var planned_range_m := float(solution_state.get("horizontal_distance_m", 0.0))
	if not T.require_true(self, planned_range_m >= EXPECTED_RANGE_MIN_M and planned_range_m <= EXPECTED_RANGE_MAX_M, "The tennis-court artillery fixture must stay in the intended ~5km band once solved from the real spawned gun instead of accidentally becoming a short-range shot (range=%0.2fm)" % planned_range_m):
		return
	var mission_predicted_impact := solution_state.get("predicted_impact_world_position", Vector3.INF) as Vector3
	if not T.require_true(self, mission_predicted_impact.distance_to(target_world_position) <= MISSION_TARGET_TOLERANCE_M, "The live-howitzer inverse-solver stage already misses the tennis-court target before any shell is launched (solver_delta=%0.2fm)" % mission_predicted_impact.distance_to(target_world_position)):
		return

	var desired_world_bearing_deg := float(solution_state.get("world_bearing_deg", 0.0))
	var desired_pitch_deg := float(solution_state.get("pitch_deg", 0.0))
	howitzer.set_axis_angles_degrees(0.0, desired_pitch_deg)
	await _settle_frames(8)
	var zero_yaw_snapshot := howitzer.get_firing_solution_snapshot() as Dictionary
	var zero_yaw_world_bearing_deg := float(zero_yaw_snapshot.get("world_bearing_deg", 0.0))
	howitzer.set_axis_angles_degrees(1.0, desired_pitch_deg)
	await _settle_frames(8)
	var plus_one_yaw_snapshot := howitzer.get_firing_solution_snapshot() as Dictionary
	var plus_one_yaw_world_bearing_deg := float(plus_one_yaw_snapshot.get("world_bearing_deg", 0.0))
	var positive_step_world_bearing_delta_deg := _shortest_bearing_delta_deg(zero_yaw_world_bearing_deg, plus_one_yaw_world_bearing_deg)
	if not T.require_true(self, absf(positive_step_world_bearing_delta_deg) >= 0.5, "The live howitzer yaw response must change the HUD/world bearing by a readable amount so the tennis-court aiming fixture can solve the local traverse direction (step_delta=%0.2f)" % positive_step_world_bearing_delta_deg):
		return
	var desired_world_bearing_delta_deg := _shortest_bearing_delta_deg(zero_yaw_world_bearing_deg, desired_world_bearing_deg)
	var local_yaw_sign := 1.0 if positive_step_world_bearing_delta_deg >= 0.0 else -1.0
	var local_yaw_deg := fposmod(desired_world_bearing_delta_deg * local_yaw_sign + 360.0, 360.0)
	howitzer.set_axis_angles_degrees(local_yaw_deg, desired_pitch_deg)
	await _settle_frames(8)

	var ballistics = CityArtilleryBallisticsScript.new()
	if not T.require_true(self, ballistics != null and ballistics.has_method("predict_impact_from_firing_solution"), "The tennis-court artillery hit flow requires the shared artillery ballistics predictor to evaluate the live howitzer solution"):
		return
	var live_firing_solution := howitzer.get_firing_solution_snapshot() as Dictionary
	var live_world_bearing_deg := float(live_firing_solution.get("world_bearing_deg", 0.0))
	var live_world_bearing_delta_deg := _shortest_bearing_delta_deg(desired_world_bearing_deg, live_world_bearing_deg)
	if not T.require_true(self, absf(live_world_bearing_delta_deg) <= 0.15, "After dialing the mission solution into the live howitzer, the HUD/world bearing must match the planned artillery bearing instead of drifting to a different heading (planned=%0.2f zero_yaw=%0.2f plus_one=%0.2f step_delta=%0.2f local_yaw=%0.2f live=%0.2f delta=%0.2f)" % [desired_world_bearing_deg, zero_yaw_world_bearing_deg, plus_one_yaw_world_bearing_deg, positive_step_world_bearing_delta_deg, local_yaw_deg, live_world_bearing_deg, live_world_bearing_delta_deg]):
		return
	if not T.require_true(self, absf(float(live_firing_solution.get("pitch_deg", 0.0)) - desired_pitch_deg) <= 0.05, "After dialing the mission solution into the live howitzer, the live pitch must still match the planned artillery pitch"):
		return
	var field_driven_firing_solution := live_firing_solution.duplicate(true)
	field_driven_firing_solution.erase("muzzle_direction_world")
	var field_driven_prediction := ballistics.predict_impact_from_firing_solution(field_driven_firing_solution, {
		"impact_plane_y": target_world_position.y,
	}) as Dictionary
	if not T.require_true(self, bool(field_driven_prediction.get("valid", false)), "The live artillery bearing/pitch readout must still define a valid ballistic prediction when evaluated directly against the tennis-court surface plane"):
		return
	var field_driven_impact := field_driven_prediction.get("impact_world_position", Vector3.INF) as Vector3
	if not T.require_true(self, field_driven_impact.distance_to(target_world_position) <= LIVE_SOLUTION_TARGET_TOLERANCE_M, "The live artillery HUD bearing/pitch already fails to round-trip back to the tennis-court target even before the shell snapshot's muzzle direction is considered (field_delta=%0.2fm)" % field_driven_impact.distance_to(target_world_position)):
		return
	var live_prediction := ballistics.predict_impact_from_firing_solution(live_firing_solution, {
		"impact_plane_y": target_world_position.y,
	}) as Dictionary
	if not T.require_true(self, bool(live_prediction.get("valid", false)), "The live howitzer firing solution must still produce a valid ballistic impact prediction against the tennis-court surface plane"):
		return
	var live_predicted_impact := live_prediction.get("impact_world_position", Vector3.INF) as Vector3
	var live_muzzle_direction_world := live_firing_solution.get("muzzle_direction_world", Vector3.ZERO) as Vector3
	var live_direction_pitch_deg := rad_to_deg(asin(clampf(live_muzzle_direction_world.normalized().y, -1.0, 1.0))) if live_muzzle_direction_world.length_squared() > 0.0001 else 0.0
	if not T.require_true(self, live_predicted_impact.distance_to(target_world_position) <= LIVE_SOLUTION_TARGET_TOLERANCE_M, "The live howitzer firing solution diverges from the planned tennis-court target before shell launch, which points to a mismatch inside the shell snapshot itself (field_delta=%0.2fm live_delta=%0.2fm muzzle_pitch=%0.2f displayed_pitch=%0.2f)" % [field_driven_impact.distance_to(target_world_position), live_predicted_impact.distance_to(target_world_position), live_direction_pitch_deg, desired_pitch_deg]):
		return

	var space_event := _build_key_event(KEY_SPACE, true)
	Input.parse_input_event(space_event)
	world._unhandled_input(space_event)
	await _settle_frames(8)
	_release_live_key(KEY_SPACE)

	var explosion_result := await _wait_for_shell_explosion(world, 360)
	if not T.require_true(self, not explosion_result.is_empty(), "The tennis-court artillery flow must reach a live shell explosion result instead of stopping at muzzle presentation"):
		return

	mounted_venue = await _wait_for_mounted_venue(world, 240)
	if not T.require_true(self, mounted_venue != null, "During the tennis-court artillery observer/impact flow, the target chunk must actually mount the tennis venue instead of rendering an empty ground placeholder"):
		return

	var impact_world_position := explosion_result.get("world_position", Vector3.INF) as Vector3
	if not T.require_true(self, bool(mounted_venue.is_world_point_in_play_bounds(live_predicted_impact)), "The live howitzer solution predicts a point outside the tennis play bounds, so the aim chain is already wrong before impact"):
		return
	if not T.require_true(self, bool(mounted_venue.is_world_point_in_play_bounds(impact_world_position)), "The artillery shell explodes outside the tennis play bounds, so the full chain still misses the actual target court (impact=%s target=%s)" % [str(impact_world_position), str(target_world_position)]):
		return
	if not T.require_true(self, impact_world_position.distance_to(live_predicted_impact) <= IMPACT_TO_PREDICTION_TOLERANCE_M, "The shell explosion lands too far from the live firing solution prediction, which points to a shell/impact-stage mismatch after aiming is already solved (impact_delta=%0.2fm)" % impact_world_position.distance_to(live_predicted_impact)):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world: Node, max_frames: int) -> Variant:
	var chunk_renderer = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(max_frames):
		await physics_frame
		await process_frame
		var chunk_scene = chunk_renderer.get_chunk_scene(TENNIS_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var venue = chunk_scene.find_scene_minigame_venue_node(TENNIS_VENUE_ID)
		if venue != null:
			return venue
	return null

func _wait_for_shell_explosion(world: Node, max_frames: int) -> Dictionary:
	for _frame in range(max_frames):
		await physics_frame
		await process_frame
		var result := world.get_last_artillery_shell_explosion_result() as Dictionary
		if not result.is_empty():
			return result
	return {}

func _wait_for_solved_fire_mission(world: Node, max_frames: int) -> Dictionary:
	for _frame in range(max_frames):
		await physics_frame
		await process_frame
		var state := world.get_artillery_fire_mission_state() as Dictionary
		var solution_state: Dictionary = state.get("solution_state", {})
		if bool(solution_state.get("solved", false)):
			return state
	return world.get_artillery_fire_mission_state() as Dictionary

func _build_key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.pressed = pressed
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	return key_event

func _press_key(target: Node, keycode: Key) -> void:
	target._unhandled_input(_build_key_event(keycode, true))

func _release_live_key(keycode: Key) -> void:
	Input.parse_input_event(_build_key_event(keycode, false))

func _settle_frames(frame_count: int = 6) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _estimate_standing_height(player: CharacterBody3D) -> float:
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _shortest_bearing_delta_deg(from_bearing_deg: float, to_bearing_deg: float) -> float:
	return fposmod(to_bearing_deg - from_bearing_deg + 540.0, 360.0) - 180.0
