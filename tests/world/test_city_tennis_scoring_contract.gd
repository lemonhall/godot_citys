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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis scoring contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis scoring contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_tennis_venue_runtime_state"), "Tennis scoring contract requires get_tennis_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("get_tennis_match_hud_state"), "Tennis scoring contract requires get_tennis_match_hud_state()"):
		return
	if not T.require_true(self, world.has_method("debug_award_tennis_point"), "Tennis scoring contract requires deterministic point award API"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Tennis scoring contract requires mounted tennis venue start contract"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_scoreboard_state"), "Tennis scoring contract requires world scoreboard introspection"):
		return

	await _start_match(world, mounted_venue, player)
	var point_result: Dictionary = world.debug_award_tennis_point("home", "test_point_home_1")
	if not T.require_true(self, bool(point_result.get("success", false)), "Tennis scoring contract must allow deterministic point award for the home side"):
		return
	await _pump_frames()
	var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
	if not T.require_true(self, str(runtime_state.get("home_point_label", "")) == "15" and str(runtime_state.get("away_point_label", "")) == "0", "After one home point the tennis score must read 15-0"):
		return

	point_result = world.debug_award_tennis_point("away", "test_point_away_1")
	if not T.require_true(self, bool(point_result.get("success", false)), "Tennis scoring contract must allow deterministic point award for the away side"):
		return
	await _pump_frames()
	runtime_state = world.get_tennis_venue_runtime_state()
	if not T.require_true(self, str(runtime_state.get("home_point_label", "")) == "15" and str(runtime_state.get("away_point_label", "")) == "15", "After one point each the tennis score must read 15-15"):
		return

	for _point in range(3):
		point_result = world.debug_award_tennis_point("home", "test_point_home_game")
		if not T.require_true(self, bool(point_result.get("success", false)), "Tennis scoring contract must allow the home side to close out a no-ad game"):
			return
		await _pump_frames()
	runtime_state = world.get_tennis_venue_runtime_state()
	if not T.require_true(self, int(runtime_state.get("home_games", 0)) == 1 and int(runtime_state.get("away_games", 0)) == 0, "Winning four no-ad points from 15-15 must advance the home game score to 1-0"):
		return
	if not T.require_true(self, str(runtime_state.get("home_point_label", "")) == "0" and str(runtime_state.get("away_point_label", "")) == "0", "Starting the next tennis game must reset point labels back to 0-0"):
		return
	if not T.require_true(self, str(runtime_state.get("server_side", "")) == "away", "After one completed game the tennis server side must rotate to away"):
		return

	for _game in range(3):
		for _point in range(4):
			point_result = world.debug_award_tennis_point("home", "test_point_home_match")
			if not T.require_true(self, bool(point_result.get("success", false)), "Tennis scoring contract must allow deterministic home match progression"):
				return
			await _pump_frames()
	runtime_state = world.get_tennis_venue_runtime_state()
	if not T.require_true(self, int(runtime_state.get("home_games", 0)) == 4, "Closing out the short-format tennis match must advance home_games to 4"):
		return
	if not T.require_true(self, str(runtime_state.get("winner_side", "")) == "home", "Closing out the short-format tennis match must declare home as winner"):
		return
	var scoreboard_state: Dictionary = mounted_venue.get_scoreboard_state()
	if not T.require_true(self, str(scoreboard_state.get("winner_side", "")) == "home", "Tennis scoring contract must propagate the winner side to the world scoreboard"):
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
