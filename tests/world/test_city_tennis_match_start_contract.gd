extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TENNIS_CHUNK_ID := "chunk_158_140"
const TENNIS_VENUE_ID := "venue:v28:tennis_court:chunk_158_140"
const TENNIS_WORLD_POSITION := Vector3(5489.46, 20.62, 1029.73)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis match start contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis match start contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_tennis_venue_runtime_state"), "Tennis match start contract requires get_tennis_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("get_tennis_match_hud_state"), "Tennis match start contract requires get_tennis_match_hud_state()"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Tennis match start contract requires the formal primary interaction entrypoint"):
		return
	if not T.require_true(self, world.has_method("get_interactive_prop_interaction_state"), "Tennis match start contract requires shared interactive prop prompt introspection"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Tennis match start contract requires the mounted venue start ring contract"):
		return
	var mounted_ball: Node3D = await _wait_for_mounted_ball(world)
	if not T.require_true(self, mounted_ball != null, "Tennis match start contract requires the mounted tennis ball before serve interaction checks"):
		return

	var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
	if not T.require_true(self, str(runtime_state.get("match_state", "")) == "idle", "Standing outside the tennis start ring must not begin the match"):
		return

	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_world_position: Vector3 = start_contract.get("world_position", TENNIS_WORLD_POSITION)
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var home_server_anchor: Dictionary = court_contract.get("home_deuce_server_anchor", {})
	var home_server_world_position: Vector3 = home_server_anchor.get("world_position", TENNIS_WORLD_POSITION)
	if not T.require_true(self, start_world_position.distance_to(home_server_world_position) <= 14.0, "Tennis match start contract must keep the start ring close enough to the home serve area to begin play immediately"):
		return
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_world_position + Vector3.UP * standing_height)

	runtime_state = await _wait_for_match_state(world, "pre_serve")
	if not T.require_true(self, str(runtime_state.get("match_state", "")) == "pre_serve", "Entering the tennis start ring must begin the match in pre_serve state"):
		return
	if not T.require_true(self, str(runtime_state.get("server_side", "")) == "home", "Tennis match start contract must open with the home/player side serving"):
		return
	if not T.require_true(self, str(runtime_state.get("expected_service_box_id", "")) == "service_box_deuce_away", "Opening tennis serve must target the away deuce service box by default"):
		return

	var hud_state: Dictionary = world.get_tennis_match_hud_state()
	if not T.require_true(self, bool(hud_state.get("visible", false)), "Starting the tennis match must surface a visible tennis HUD"):
		return
	if not T.require_true(self, str(hud_state.get("home_point_label", "")) == "0" and str(hud_state.get("away_point_label", "")) == "0", "Tennis match HUD must start at point score 0-0"):
		return
	if not T.require_true(self, str(hud_state.get("server_side", "")) == "home", "Tennis match HUD must expose the opening server side"):
		return

	player.teleport_to_world_position(mounted_ball.global_position + Vector3(-1.2, 0.95, 0.0))
	await _settle_frames()
	var interaction_state: Dictionary = world.get_interactive_prop_interaction_state()
	if not T.require_true(self, bool(interaction_state.get("visible", false)), "Tennis pre-serve state must expose the shared ball interaction prompt while the player is near the ball"):
		return
	var serve_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(serve_result.get("success", false)), "Tennis pre-serve interaction must let the player trigger a formal serve through the primary interaction entrypoint"):
		return
	var serve_target_world_position_variant: Variant = serve_result.get("planned_target_world_position", null)
	if not T.require_true(self, serve_target_world_position_variant is Vector3, "Tennis serve planner must expose planned_target_world_position through the serve interaction result"):
		return
	var serve_target_world_position := serve_target_world_position_variant as Vector3
	if not T.require_true(self, str(serve_result.get("planned_target_side", "")) == "away", "Tennis serve planner must target the away side instead of launching a generic forward impulse"):
		return
	if not T.require_true(self, mounted_venue.get_service_box_id_for_world_point(serve_target_world_position) == "service_box_deuce_away", "Tennis serve planner must land the default opening serve in the expected away deuce service box"):
		return
	if not T.require_true(self, bool(mounted_venue.is_world_point_in_play_bounds(serve_target_world_position)), "Tennis serve planner must keep the default opening serve inside formal in-play bounds"):
		return
	runtime_state = await _wait_for_match_state(world, "rally")
	if not T.require_true(self, str(runtime_state.get("match_state", "")) == "rally", "Tennis serve planner must advance the opening legal serve into rally state"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(TENNIS_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(TENNIS_VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null

func _wait_for_mounted_ball(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(TENNIS_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_interactive_prop_node"):
			continue
		var mounted_ball: Variant = chunk_scene.find_scene_interactive_prop_node("prop:v28:tennis_ball:chunk_158_140")
		if mounted_ball != null:
			return mounted_ball
	return null

func _wait_for_match_state(world, expected_state: String) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == expected_state:
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _settle_frames(frame_count: int = 8) -> void:
	for _frame in range(frame_count):
		await physics_frame
		await process_frame

func _estimate_standing_height(player) -> float:
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
