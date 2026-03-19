extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TENNIS_CHUNK_ID := "chunk_158_140"
const TENNIS_VENUE_ID := "venue:v28:tennis_court:chunk_158_140"
const TENNIS_PROP_ID := "prop:v28:tennis_ball:chunk_158_140"
const TENNIS_WORLD_POSITION := Vector3(5489.46, 20.62, 1029.73)
const REQUIRED_PLAYER_RETURNS := 20

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis rally durability contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis rally durability contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_tennis_venue_runtime_state"), "Tennis rally durability contract requires get_tennis_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Tennis rally durability contract requires the formal primary interaction entrypoint"):
		return
	if not T.require_true(self, world.has_method("debug_set_tennis_ai_pressure_error_kind"), "Tennis rally durability contract requires a deterministic AI pressure debug override API"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Tennis rally durability contract requires mounted tennis venue start contract"):
		return
	var mounted_ball: Node3D = await _wait_for_mounted_ball(world)
	if not T.require_true(self, mounted_ball != null, "Tennis rally durability contract requires the mounted tennis ball"):
		return

	var debug_override_result: Dictionary = world.debug_set_tennis_ai_pressure_error_kind("disabled")
	if not T.require_true(self, bool(debug_override_result.get("success", false)), "Tennis rally durability contract must allow disabling AI pressure misses for deterministic soak verification"):
		return

	await _start_match(world, mounted_venue, player)
	player.teleport_to_world_position(mounted_ball.global_position + Vector3(-1.2, 0.95, 0.0))
	await _pump_frames(10)
	var serve_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(serve_result.get("success", false)), "Tennis rally durability contract must allow the opening player serve"):
		return

	for rally_index in range(REQUIRED_PLAYER_RETURNS):
		var ai_return_state: Dictionary = await _wait_for_ai_return_or_terminal(world)
		var ai_match_state := str(ai_return_state.get("match_state", ""))
		if ai_match_state == "point_result" or ai_match_state == "game_break" or ai_match_state == "final":
			T.fail_and_quit(self, "Tennis rally durability contract must keep the rally alive until %d player returns are completed | round=%d summary=%s" % [
				REQUIRED_PLAYER_RETURNS,
				rally_index + 1,
				_build_runtime_summary(ai_return_state),
			])
			return
		var strike_anchor_variant: Variant = ai_return_state.get("landing_marker_world_position", Vector3.ZERO)
		if not T.require_true(self, strike_anchor_variant is Vector3, "Tennis rally durability contract must expose a landing marker position for rally round %d" % [rally_index + 1]):
			return
		var strike_anchor := strike_anchor_variant as Vector3
		player.teleport_to_world_position(strike_anchor + Vector3.UP * _estimate_standing_height(player))
		await _pump_frames(6)
		var ready_bundle := await _wait_for_ready_or_terminal(world)
		var ready_runtime_state: Dictionary = ready_bundle.get("runtime_state", {})
		if str(ready_runtime_state.get("match_state", "")) == "point_result" or str(ready_runtime_state.get("match_state", "")) == "game_break" or str(ready_runtime_state.get("match_state", "")) == "final":
			T.fail_and_quit(self, "Tennis rally durability contract must reopen a playable receive window through round %d before the point ends | summary=%s" % [
				rally_index + 1,
				_build_runtime_summary(ready_runtime_state),
			])
			return
		if not T.require_true(self, str(ready_runtime_state.get("strike_window_state", "")) == "ready", "Tennis rally durability contract must expose READY before the player return on round %d | %s" % [rally_index + 1, _build_runtime_summary(ready_runtime_state)]):
			return
		var return_result: Dictionary = world.handle_primary_interaction()
		if not T.require_true(self, bool(return_result.get("success", false)), "Tennis rally durability contract must let the player convert the blue-ring receive window into a valid return on round %d | %s" % [rally_index + 1, str(return_result)]):
			return
		var home_return_state: Dictionary = await _wait_for_last_hitter_or_terminal(world, "home")
		var home_match_state := str(home_return_state.get("match_state", ""))
		if home_match_state == "point_result" or home_match_state == "game_break" or home_match_state == "final":
			T.fail_and_quit(self, "Tennis rally durability contract must keep the exchange alive after the player return on round %d | summary=%s" % [
				rally_index + 1,
				_build_runtime_summary(home_return_state),
			])
			return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", TENNIS_WORLD_POSITION)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "pre_serve")

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

func _wait_for_ai_return_or_terminal(world) -> Dictionary:
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

func _wait_for_ready_or_terminal(world) -> Dictionary:
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		var match_state := str(runtime_state.get("match_state", ""))
		if match_state == "point_result" or match_state == "game_break" or match_state == "final":
			return {
				"runtime_state": runtime_state,
			}
		if str(runtime_state.get("strike_window_state", "")) == "ready":
			return {
				"runtime_state": runtime_state,
			}
	return {
		"runtime_state": world.get_tennis_venue_runtime_state(),
	}

func _wait_for_last_hitter_or_terminal(world, expected_side: String) -> Dictionary:
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		var match_state := str(runtime_state.get("match_state", ""))
		if match_state == "point_result" or match_state == "game_break" or match_state == "final":
			return runtime_state
		if str(runtime_state.get("last_hitter_side", "")) == expected_side:
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _build_runtime_summary(runtime_state: Dictionary) -> String:
	return "match=%s last=%s winner=%s reason=%s target=%s bounces_home=%s strike=%s planned=%s probe=%s bounce=%s" % [
		str(runtime_state.get("match_state", "")),
		str(runtime_state.get("last_hitter_side", "")),
		str(runtime_state.get("point_winner_side", "")),
		str(runtime_state.get("point_end_reason", "")),
		str(runtime_state.get("target_side", "")),
		str(runtime_state.get("ball_bounce_count_home", 0)),
		str(runtime_state.get("strike_window_state", "")),
		str(runtime_state.get("planned_target_world_position", Vector3.ZERO)),
		str(runtime_state.get("debug_last_bounce_probe", {})),
		str(runtime_state.get("debug_last_bounce_event", {})),
	]

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
