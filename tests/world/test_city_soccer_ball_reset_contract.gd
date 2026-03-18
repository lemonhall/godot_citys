extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_PROP_ID := "prop:v25:soccer_ball:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer ball reset contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer ball reset contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer ball reset contract requires debug_set_soccer_ball_state()"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Soccer ball reset contract requires the shared primary interaction entrypoint"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 3.0, 6.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	var mounted_ball: Variant = await _wait_for_mounted_ball(world)
	if not T.require_true(self, mounted_venue != null and mounted_ball != null, "Soccer ball reset contract must mount both the venue and the v25 soccer ball before reset checks"):
		return
	if not T.require_true(self, mounted_ball is Node3D, "Soccer ball reset contract requires the mounted soccer ball to be a Node3D"):
		return
	var mounted_ball_node := mounted_ball as Node3D

	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var surface_size: Vector3 = play_surface.get("surface_size", Vector3.ZERO)
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", Vector3.ZERO)
	var runtime_state: Dictionary = await _wait_for_ball_bound(world)
	var kickoff_ball_offset := _resolve_kickoff_ball_offset(runtime_state)
	var expected_reset_position := kickoff_anchor + kickoff_ball_offset
	if not await _wait_for_ball_near_position(mounted_ball_node, expected_reset_position):
		runtime_state = world.get_soccer_venue_runtime_state()
	if not T.require_true(self, mounted_ball_node.global_position.distance_to(expected_reset_position) <= 0.16, "Initial venue activation must pull the original soccer ball up onto the raised kickoff surface instead of leaving it buried on the old terrain height"):
		return

	var outside_world_position: Vector3 = expected_reset_position + Vector3(surface_size.x * 0.5 + 7.0, 0.0, 0.0)
	var out_result: Dictionary = world.debug_set_soccer_ball_state(outside_world_position, Vector3.ZERO)
	if not T.require_true(self, bool(out_result.get("success", false)), "Soccer ball reset contract must allow deterministic out-of-bounds setup"):
		return

	runtime_state = await _wait_for_last_result(world, "out_of_bounds")
	if not T.require_true(self, str(runtime_state.get("last_result_state", "")) == "out_of_bounds", "Leaving the playable floor must enter the out_of_bounds result path instead of letting the ball roll away forever"):
		return
	runtime_state = await _wait_for_game_state(world, "idle")
	if not T.require_true(self, str(runtime_state.get("game_state", "")) == "idle", "Out-of-bounds recovery must return the venue runtime to idle after reset"):
		return

	kickoff_ball_offset = _resolve_kickoff_ball_offset(runtime_state)
	expected_reset_position = kickoff_anchor + kickoff_ball_offset
	var ball_reset_distance: float = mounted_ball_node.global_position.distance_to(expected_reset_position)
	if not T.require_true(self, ball_reset_distance <= 0.16, "Ball reset contract must move the original soccer ball back to the kickoff point instead of leaving it outside the venue"):
		return
	if mounted_ball_node is RigidBody3D:
		var rigid_ball := mounted_ball_node as RigidBody3D
		if not T.require_true(self, rigid_ball.linear_velocity.length() <= 0.01, "Ball reset contract must zero linear velocity during reset"):
			return
		if not T.require_true(self, rigid_ball.angular_velocity.length() <= 0.01, "Ball reset contract must zero angular velocity during reset"):
			return

	player.teleport_to_world_position(mounted_ball_node.global_position + Vector3(-0.95, 0.95, 0.0))
	await _settle_frames(8)
	var kick_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(kick_result.get("success", false)), "Ball reset contract must preserve the existing v25 kick interaction after an out-of-bounds reset"):
		return
	if not T.require_true(self, str(kick_result.get("prop_id", "")) == SOCCER_PROP_ID, "Ball reset contract must continue operating on the original soccer prop after reset"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(SOCCER_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(SOCCER_VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null

func _wait_for_mounted_ball(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(SOCCER_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_interactive_prop_node"):
			continue
		var mounted_ball: Variant = chunk_scene.find_scene_interactive_prop_node(SOCCER_PROP_ID)
		if mounted_ball != null:
			return mounted_ball
	return null

func _wait_for_ball_bound(world) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if bool(runtime_state.get("ball_bound", false)):
			return runtime_state
	return world.get_soccer_venue_runtime_state()

func _wait_for_last_result(world, result_state: String) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if str(runtime_state.get("last_result_state", "")) == result_state:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

func _wait_for_game_state(world, game_state: String) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if str(runtime_state.get("game_state", "")) == game_state:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

func _settle_frames(frame_count: int = 8) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _wait_for_ball_near_position(ball_node: Node3D, target_world_position: Vector3, tolerance_m: float = 0.16) -> bool:
	for _frame in range(180):
		await physics_frame
		await process_frame
		if ball_node.global_position.distance_to(target_world_position) <= tolerance_m:
			return true
	return ball_node.global_position.distance_to(target_world_position) <= tolerance_m

func _resolve_kickoff_ball_offset(runtime_state: Dictionary) -> Vector3:
	var kickoff_ball_offset_variant: Variant = runtime_state.get("kickoff_ball_offset", Vector3(0.0, 0.6, 0.0))
	if kickoff_ball_offset_variant is Vector3:
		return kickoff_ball_offset_variant as Vector3
	return Vector3(0.0, 0.6, 0.0)
