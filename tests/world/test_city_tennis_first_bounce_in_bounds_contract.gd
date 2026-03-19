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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis first bounce in-bounds contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis first bounce in-bounds contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Tennis first bounce in-bounds contract requires the formal primary interaction entrypoint"):
		return
	if not T.require_true(self, world.has_method("get_tennis_venue_runtime_state"), "Tennis first bounce in-bounds contract requires get_tennis_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("debug_set_tennis_ball_state"), "Tennis first bounce in-bounds contract requires debug_set_tennis_ball_state()"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Tennis first bounce in-bounds contract requires mounted tennis venue start contract"):
		return
	var mounted_ball: Node3D = await _wait_for_mounted_ball(world)
	if not T.require_true(self, mounted_ball != null, "Tennis first bounce in-bounds contract requires the mounted tennis ball"):
		return

	await _start_match(world, mounted_venue, player)
	player.teleport_to_world_position(mounted_ball.global_position + Vector3(-1.2, 0.95, 0.0))
	await _pump_frames(10)
	var serve_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(serve_result.get("success", false)), "Tennis first bounce in-bounds contract must allow the opening player serve"):
		return
	var ai_return_state: Dictionary = await _wait_for_ai_return(world)
	if not T.require_true(self, str(ai_return_state.get("last_hitter_side", "")) == "away", "Tennis first bounce in-bounds contract setup requires an away live shot toward the player side"):
		return
	var planned_target_variant: Variant = ai_return_state.get("planned_target_world_position", null)
	if not T.require_true(self, planned_target_variant is Vector3, "Tennis first bounce in-bounds contract must expose the AI bounce target as Vector3"):
		return
	var planned_target_world_position := planned_target_variant as Vector3
	if not T.require_true(self, bool(mounted_venue.is_world_point_in_play_bounds(planned_target_world_position)), "Tennis first bounce in-bounds contract setup requires the AI bounce target to stay inside legal in-play bounds"):
		return
	if not T.require_true(self, mounted_venue.to_local(planned_target_world_position).z > 0.0, "Tennis first bounce in-bounds contract setup requires the AI bounce target to be on the home/player side"):
		return

	var debug_result: Dictionary = world.debug_set_tennis_ball_state(planned_target_world_position + Vector3.UP * 1.5, Vector3(0.0, -11.0, 0.0), Vector3.ZERO)
	if not T.require_true(self, bool(debug_result.get("success", false)), "Tennis first bounce in-bounds contract must allow direct seeded bounce-state setup"):
		return
	var post_bounce_state: Dictionary = await _wait_for_first_home_bounce_or_terminal(world)
	var post_bounce_summary := "match=%s reason=%s winner=%s strike=%s target=%s bounces_home=%s planned=%s" % [
		str(post_bounce_state.get("match_state", "")),
		str(post_bounce_state.get("point_end_reason", "")),
		str(post_bounce_state.get("point_winner_side", "")),
		str(post_bounce_state.get("strike_window_state", "")),
		str(post_bounce_state.get("target_side", "")),
		str(post_bounce_state.get("ball_bounce_count_home", 0)),
		str(post_bounce_state.get("planned_target_world_position", Vector3.ZERO)),
	]
	if not T.require_true(self, int(post_bounce_state.get("ball_bounce_count_home", 0)) >= 1, "Tennis first bounce in-bounds contract must register the first legal home-side bounce | %s" % post_bounce_summary):
		return
	if not T.require_true(self, str(post_bounce_state.get("point_end_reason", "")) == "", "Tennis first bounce in-bounds contract must not call a legal first home-side bounce 'out' | %s" % post_bounce_summary):
		return
	if not T.require_true(self, str(post_bounce_state.get("point_winner_side", "")) == "", "Tennis first bounce in-bounds contract must not award the point immediately after a legal first home-side bounce | %s" % post_bounce_summary):
		return
	if not T.require_true(self, str(post_bounce_state.get("match_state", "")) == "rally", "Tennis first bounce in-bounds contract must keep the rally live after a legal first home-side bounce | %s" % post_bounce_summary):
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

func _wait_for_ai_return(world) -> Dictionary:
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("last_hitter_side", "")) == "away":
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _wait_for_first_home_bounce_or_terminal(world) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if int(runtime_state.get("ball_bounce_count_home", 0)) >= 1:
			return runtime_state
		var match_state := str(runtime_state.get("match_state", ""))
		if match_state == "point_result" or match_state == "game_break" or match_state == "final":
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
