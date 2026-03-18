extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer match reset-on-exit contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer match reset-on-exit contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_soccer_match_hud_state"), "Soccer match reset-on-exit contract requires get_soccer_match_hud_state()"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_match_clock_remaining_sec"), "Soccer match reset-on-exit contract requires deterministic clock override"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer match reset-on-exit contract requires deterministic ball placement"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Soccer match reset-on-exit contract requires the mounted venue start ring contract"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_goal_contracts"), "Soccer match reset-on-exit contract requires goal contracts on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_play_surface_contract"), "Soccer match reset-on-exit contract requires play surface metadata"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_match_roster_state"), "Soccer match reset-on-exit contract requires roster introspection on the mounted venue"):
		return

	await _start_match(world, mounted_venue, player)
	await _score_goal(world, mounted_venue, "away")
	var clock_result: Dictionary = world.debug_set_soccer_match_clock_remaining_sec(42.0)
	if not T.require_true(self, bool(clock_result.get("success", false)), "Soccer match reset-on-exit contract must allow clock override before exit reset validation"):
		return

	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", Vector3.ZERO)
	var release_buffer_m := float(play_surface.get("release_buffer_m", 24.0))
	var half_length := float((play_surface.get("surface_size", Vector3.ZERO) as Vector3).z) * 0.5
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(kickoff_anchor + Vector3(0.0, standing_height, half_length + release_buffer_m + 6.0))

	var runtime_state: Dictionary = await _wait_for_match_state(world, "idle")
	if not T.require_true(self, int(runtime_state.get("home_score", -1)) == 0 and int(runtime_state.get("away_score", -1)) == 0, "Walking out of the soccer freeze circle must reset both scores back to 0:0"):
		return
	if not T.require_true(self, is_equal_approx(float(runtime_state.get("match_clock_remaining_sec", -1.0)), 300.0), "Walking out of the soccer freeze circle must restore the full 05:00 match clock"):
		return
	var hud_state: Dictionary = world.get_soccer_match_hud_state()
	if not T.require_true(self, not bool(hud_state.get("visible", true)), "Walking out of the soccer freeze circle must hide the match HUD block"):
		return
	var scoreboard_state: Dictionary = (runtime_state.get("scoreboard_state", {}) as Dictionary).duplicate(true)
	if not T.require_true(self, not bool(scoreboard_state.get("winner_highlight_visible", true)), "Walking out of the soccer freeze circle must clear any winner highlight from the scoreboard"):
		return
	if not T.require_true(self, str(scoreboard_state.get("winner_highlight_side", "invalid")) == "", "Walking out of the soccer freeze circle must clear the highlighted winner side"):
		return
	var roster_state: Dictionary = mounted_venue.get_match_roster_state()
	if not T.require_true(self, int(roster_state.get("idle_player_count", 0)) == 10, "Walking out of the soccer freeze circle must return every match player to idle anchors"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", Vector3.ZERO)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "in_progress")

func _score_goal(world, mounted_venue: Node3D, scoring_side: String) -> void:
	var goal_contracts: Dictionary = mounted_venue.get_goal_contracts()
	var goal_key := "goal_a" if scoring_side == "home" else "goal_b"
	var goal_contract: Dictionary = goal_contracts.get(goal_key, {})
	var goal_center: Vector3 = goal_contract.get("world_center", Vector3.ZERO)
	var approach_sign: float = float(goal_contract.get("approach_sign_z", 0.0))
	var score_result: Dictionary = world.debug_set_soccer_ball_state(goal_center, Vector3(0.0, 0.0, approach_sign * 1.3))
	if not bool(score_result.get("success", false)):
		return
	await _wait_for_score(world, scoring_side, 1)

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

func _wait_for_match_state(world, expected_state: String) -> Dictionary:
	for _frame in range(150):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == expected_state:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

func _wait_for_score(world, scoring_side: String, expected_score: int) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		var score: int = int(runtime_state.get("home_score", 0)) if scoring_side == "home" else int(runtime_state.get("away_score", 0))
		if score >= expected_score:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

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
