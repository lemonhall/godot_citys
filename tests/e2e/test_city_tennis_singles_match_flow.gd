extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TENNIS_CHUNK_ID := "chunk_158_140"
const TENNIS_VENUE_ID := "venue:v28:tennis_court:chunk_158_140"
const TENNIS_PROP_ID := "prop:v28:tennis_ball:chunk_158_140"
const TENNIS_WORLD_POSITION := Vector3(5489.46, 20.62, 1029.73)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis singles match flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis singles match flow requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_tennis_venue_runtime_state"), "Tennis singles match flow requires get_tennis_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("get_tennis_match_hud_state"), "Tennis singles match flow requires get_tennis_match_hud_state()"):
		return
	if not T.require_true(self, world.has_method("debug_award_tennis_point"), "Tennis singles match flow requires deterministic point award API"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Tennis singles match flow requires the formal primary interaction entrypoint"):
		return
	if not T.require_true(self, world.has_method("get_interactive_prop_interaction_state"), "Tennis singles match flow requires shared interactive prop prompt introspection"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Tennis singles match flow requires the mounted venue start ring contract"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_tennis_court_contract"), "Tennis singles match flow requires tennis court metadata on the mounted venue"):
		return

	var mounted_ball: Node3D = await _wait_for_mounted_ball(world)
	if not T.require_true(self, mounted_ball != null, "Tennis singles match flow must mount the formal tennis ball prop in chunk_158_140"):
		return

	await _start_match(world, mounted_venue, player)
	var hud_state: Dictionary = world.get_tennis_match_hud_state()
	if not T.require_true(self, bool(hud_state.get("visible", false)), "Starting the tennis singles match must surface a visible tennis HUD"):
		return
	await _play_live_exchange(world, mounted_venue, mounted_ball, player)
	hud_state = world.get_tennis_match_hud_state()
	if not T.require_true(self, hud_state.has("strike_window_state"), "Tennis singles match flow HUD must expose strike_window_state after the live exchange upgrade"):
		return
	if not T.require_true(self, hud_state.has("auto_footwork_assist_state"), "Tennis singles match flow HUD must expose auto_footwork_assist_state after the live exchange upgrade"):
		return

	for _point in range(4):
		var point_result: Dictionary = world.debug_award_tennis_point("home", "test_e2e_point")
		if not T.require_true(self, bool(point_result.get("success", false)), "Tennis singles match flow must allow deterministic home point progression"):
			return
		await _pump_frames()

	var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
	if not T.require_true(self, int(runtime_state.get("home_games", 0)) == 1, "Tennis singles match flow must advance the home side to 1 game after four won points"):
		return
	if not T.require_true(self, bool(runtime_state.get("ambient_simulation_frozen", false)), "Tennis singles match flow must keep ambient freeze active while the player remains in the venue"):
		return

	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract()
	var standing_height := _estimate_standing_height(player)
	var release_buffer_m := float(court_contract.get("release_buffer_m", 14.0))
	var singles_width_m := float(court_contract.get("singles_width_m", 8.23))
	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(singles_width_m * 0.5 + release_buffer_m + 6.0, standing_height, 0.0))

	runtime_state = await _wait_for_match_state(world, "idle")
	if not T.require_true(self, int(runtime_state.get("home_games", -1)) == 0 and int(runtime_state.get("away_games", -1)) == 0, "Leaving the tennis release bounds in the end-to-end flow must reset the game score back to 0-0"):
		return
	hud_state = world.get_tennis_match_hud_state()
	if not T.require_true(self, not bool(hud_state.get("visible", true)), "Leaving the tennis release bounds must hide the tennis HUD block in the end-to-end flow"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", TENNIS_WORLD_POSITION)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "pre_serve")

func _play_live_exchange(world, mounted_venue: Node3D, mounted_ball: Node3D, player) -> void:
	player.teleport_to_world_position(mounted_ball.global_position + Vector3(-1.2, 0.95, 0.0))
	await _pump_frames(10)
	var serve_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(serve_result.get("success", false)), "Tennis singles match flow must let the player trigger the opening serve via shared primary interaction"):
		return
	var serve_target_variant: Variant = serve_result.get("planned_target_world_position", null)
	if not T.require_true(self, serve_target_variant is Vector3, "Tennis singles match flow must expose the planned serve target as Vector3 through the live interaction result"):
		return
	var serve_target := serve_target_variant as Vector3
	if not T.require_true(self, str(serve_result.get("planned_target_side", "")) == "away", "Tennis singles match flow serve planner must target the away side by default"):
		return
	if not T.require_true(self, mounted_venue.get_service_box_id_for_world_point(serve_target) == "service_box_deuce_away", "Tennis singles match flow must keep the default serve inside the expected service box"):
		return
	var serve_state: Dictionary = await _wait_for_match_state(world, "rally")
	if not T.require_true(self, str(serve_state.get("match_state", "")) == "rally", "Tennis singles match flow must advance the opening legal serve into rally state"):
		return
	var ai_return_state: Dictionary = await _wait_for_ai_return(world)
	if not T.require_true(self, bool(ai_return_state.get("landing_marker_visible", false)), "Tennis singles match flow must surface a landing marker after the AI return"):
		return
	var return_result: Dictionary = await _attempt_player_return(world)
	if not T.require_true(self, bool(return_result.get("success", false)), "Tennis singles match flow must let the player return the AI shot through the same shared interaction entrypoint"):
		return
	var home_return_state: Dictionary = await _wait_for_last_hitter(world, "home")
	if not T.require_true(self, str(home_return_state.get("planned_target_side", "")) == "away", "Tennis singles match flow player return planner must send the ball back toward the away side"):
		return
	if not T.require_true(self, not bool(home_return_state.get("landing_marker_visible", true)), "Tennis singles match flow must clear the incoming landing marker after the player strikes the return"):
		return

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
		var mounted_ball: Variant = chunk_scene.find_scene_interactive_prop_node(TENNIS_PROP_ID)
		if mounted_ball != null:
			return mounted_ball
	return null

func _wait_for_match_state(world, expected_state: String) -> Dictionary:
	for _frame in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == expected_state:
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _wait_for_ai_return(world) -> Dictionary:
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("last_hitter_side", "")) == "away" and bool(runtime_state.get("landing_marker_visible", false)):
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _attempt_player_return(world) -> Dictionary:
	var repositioned := false
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		var interaction_state: Dictionary = world.get_interactive_prop_interaction_state()
		if not repositioned and bool(runtime_state.get("landing_marker_visible", false)):
			var strike_anchor_variant: Variant = runtime_state.get("landing_marker_world_position", Vector3.ZERO)
			if strike_anchor_variant is Vector3:
				var strike_anchor := strike_anchor_variant as Vector3
				var player: Node3D = world.get_node_or_null("Player") as Node3D
				if player != null and player.has_method("teleport_to_world_position"):
					player.teleport_to_world_position(strike_anchor + Vector3.UP * _estimate_standing_height(player))
					repositioned = true
		if str(runtime_state.get("strike_window_state", "")) != "ready":
			continue
		if not bool(interaction_state.get("visible", false)):
			continue
		return world.handle_primary_interaction()
	return {
		"success": false,
		"error": "player_return_window_timeout",
	}

func _wait_for_last_hitter(world, expected_side: String) -> Dictionary:
	for _frame in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("last_hitter_side", "")) == expected_side:
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _pump_frames(frame_count: int = 4) -> void:
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
