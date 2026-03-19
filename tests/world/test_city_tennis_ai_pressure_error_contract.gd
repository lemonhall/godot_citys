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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis AI pressure error contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis AI pressure error contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_tennis_venue_runtime_state"), "Tennis AI pressure error contract requires get_tennis_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Tennis AI pressure error contract requires the formal primary interaction entrypoint"):
		return
	if not T.require_true(self, world.has_method("get_interactive_prop_interaction_state"), "Tennis AI pressure error contract requires shared interactive prop prompt introspection"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Tennis AI pressure error contract requires mounted tennis venue start contract"):
		return
	var mounted_ball: Node3D = await _wait_for_mounted_ball(world)
	if not T.require_true(self, mounted_ball != null, "Tennis AI pressure error contract requires the mounted tennis ball before live exchange checks"):
		return

	await _start_match(world, mounted_venue, player)
	player.teleport_to_world_position(mounted_ball.global_position + Vector3(-1.2, 0.95, 0.0))
	await _pump_frames(10)
	var serve_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(serve_result.get("success", false)), "Tennis AI pressure error contract must allow the player to trigger a real serve through the shared interaction entrypoint"):
		return

	var pressure_result: Dictionary = await _play_until_ai_pressure_error(world, player)
	var result_summary := "winner=%s reason=%s rally=%s state=%s" % [
		str(pressure_result.get("point_winner_side", "")),
		str(pressure_result.get("point_end_reason", "")),
		str(pressure_result.get("rally_shot_count", 0)),
		str(pressure_result.get("match_state", "")),
	]
	if not T.require_true(self, str(pressure_result.get("point_winner_side", "")) == "home", "Tennis AI pressure error contract must eventually award the pressured rally to the home side | %s" % result_summary):
		return
	if not T.require_true(self, str(pressure_result.get("point_end_reason", "")) == "out", "Tennis AI pressure error contract must resolve the pressured rally via an AI out error | %s" % result_summary):
		return
	if not T.require_true(self, int(pressure_result.get("rally_shot_count", 0)) >= 5, "Tennis AI pressure error contract must only introduce the deterministic AI miss after a real rally has been established"):
		return
	var pressure_target_variant: Variant = pressure_result.get("planned_target_world_position", Vector3.ZERO)
	if not T.require_true(self, pressure_target_variant is Vector3, "Tennis AI pressure error contract must preserve the pressured miss landing target as Vector3"):
		return
	var pressure_target := pressure_target_variant as Vector3
	if not T.require_true(self, not bool(mounted_venue.is_world_point_in_play_bounds(pressure_target)), "Tennis AI pressure error contract AI out balls must miss the first landing inside the formal in-play bounds"):
		return
	if not T.require_true(self, mounted_venue.to_local(pressure_target).z > 0.0, "Tennis AI pressure error contract AI pressure misses must still target the player/home side before missing long or wide"):
		return
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract()
	var surface_top_y := float(court_contract.get("surface_top_y", mounted_ball.global_position.y))
	if not T.require_true(self, mounted_ball.global_position.y <= surface_top_y + 2.0, "Tennis AI pressure error contract should not score an AI out while the ball is still obviously high in the air"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", TENNIS_WORLD_POSITION)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "pre_serve")

func _play_until_ai_pressure_error(world, player) -> Dictionary:
	for _exchange in range(6):
		var runtime_state: Dictionary = await _wait_for_ai_return_or_point_result(world)
		var match_state := str(runtime_state.get("match_state", ""))
		if match_state == "point_result" or match_state == "game_break" or match_state == "final":
			return runtime_state
		var return_result: Dictionary = await _attempt_player_return(world, player)
		if not bool(return_result.get("success", false)):
			return {
				"point_winner_side": "",
				"point_end_reason": str(return_result.get("error", "player_return_failed")),
				"rally_shot_count": int(runtime_state.get("rally_shot_count", 0)),
			}
	return world.get_tennis_venue_runtime_state()

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
	for _frame in range(360):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == expected_state:
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _wait_for_ai_return_or_point_result(world) -> Dictionary:
	for _frame in range(720):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		var match_state := str(runtime_state.get("match_state", ""))
		if match_state == "point_result" or match_state == "game_break" or match_state == "final":
			return runtime_state
		if str(runtime_state.get("last_hitter_side", "")) == "away" and bool(runtime_state.get("landing_marker_visible", false)):
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _attempt_player_return(world, player) -> Dictionary:
	var repositioned := false
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		var interaction_state: Dictionary = world.get_interactive_prop_interaction_state()
		if not repositioned and bool(runtime_state.get("landing_marker_visible", false)) and player != null and player.has_method("teleport_to_world_position"):
			var strike_anchor_variant: Variant = runtime_state.get("landing_marker_world_position", Vector3.ZERO)
			if strike_anchor_variant is Vector3:
				var strike_anchor := strike_anchor_variant as Vector3
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
