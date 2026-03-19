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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis reset-on-exit contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis reset-on-exit contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_tennis_venue_runtime_state"), "Tennis reset-on-exit contract requires get_tennis_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("get_tennis_match_hud_state"), "Tennis reset-on-exit contract requires get_tennis_match_hud_state()"):
		return
	if not T.require_true(self, world.has_method("debug_award_tennis_point"), "Tennis reset-on-exit contract requires deterministic point award API"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Tennis reset-on-exit contract requires mounted tennis venue start contract"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_tennis_court_contract"), "Tennis reset-on-exit contract requires tennis court contract on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_scoreboard_state"), "Tennis reset-on-exit contract requires world scoreboard introspection"):
		return

	await _start_match(world, mounted_venue, player)
	for _point in range(4):
		var point_result: Dictionary = world.debug_award_tennis_point("home", "test_dirty_state")
		if not T.require_true(self, bool(point_result.get("success", false)), "Tennis reset-on-exit contract must allow deterministic dirtying of match state"):
			return
		await _pump_frames()

	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract()
	var standing_height := _estimate_standing_height(player)
	var release_buffer_m := float(court_contract.get("release_buffer_m", 14.0))
	var singles_width_m := float(court_contract.get("singles_width_m", 8.23))
	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(singles_width_m * 0.5 + release_buffer_m + 6.0, standing_height, 0.0))

	var runtime_state: Dictionary = await _wait_for_match_state(world, "idle")
	if not T.require_true(self, int(runtime_state.get("home_games", -1)) == 0 and int(runtime_state.get("away_games", -1)) == 0, "Leaving the tennis release bounds must reset the game score back to 0-0"):
		return
	if not T.require_true(self, str(runtime_state.get("home_point_label", "")) == "0" and str(runtime_state.get("away_point_label", "")) == "0", "Leaving the tennis release bounds must reset the point score back to 0-0"):
		return
	if not T.require_true(self, str(runtime_state.get("winner_side", "invalid")) == "", "Leaving the tennis release bounds must clear the winner side"):
		return
	var hud_state: Dictionary = world.get_tennis_match_hud_state()
	if not T.require_true(self, not bool(hud_state.get("visible", true)), "Leaving the tennis release bounds must hide the tennis HUD block"):
		return
	var scoreboard_state: Dictionary = mounted_venue.get_scoreboard_state()
	if not T.require_true(self, str(scoreboard_state.get("winner_side", "invalid")) == "", "Leaving the tennis release bounds must clear the world scoreboard winner side"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", TENNIS_WORLD_POSITION)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	for _frame in range(180):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == "pre_serve":
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

func _wait_for_match_state(world, expected_state: String) -> Dictionary:
	for _frame in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == expected_state:
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
