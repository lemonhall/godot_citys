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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer goal detection contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer goal detection contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_soccer_venue_runtime_state"), "Soccer goal detection contract requires get_soccer_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer goal detection contract requires debug_set_soccer_ball_state()"):
		return
	if not T.require_true(self, world.has_method("debug_force_soccer_ball_reset"), "Soccer goal detection contract requires debug_force_soccer_ball_reset()"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 3.0, 6.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Soccer goal detection contract must mount the soccer venue before goal checks"):
		return
	var mounted_ball: Variant = await _wait_for_mounted_ball(world)
	if not T.require_true(self, mounted_ball != null, "Soccer goal detection contract must mount the v25 soccer ball before goal checks"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_goal_contracts"), "Soccer goal detection contract requires get_goal_contracts() on the mounted venue"):
		return

	var goal_contracts: Dictionary = mounted_venue.get_goal_contracts()
	if not T.require_true(self, goal_contracts.has("goal_a") and goal_contracts.has("goal_b"), "Soccer goal detection contract must expose both goal_a and goal_b contracts"):
		return
	var goal_a: Dictionary = goal_contracts.get("goal_a", {})
	var goal_center: Vector3 = goal_a.get("world_center", Vector3.ZERO)
	var approach_sign: float = float(goal_a.get("approach_sign_z", 0.0))
	var scoring_side: String = str(goal_a.get("scoring_side", ""))
	if not T.require_true(self, scoring_side == "home", "Soccer goal detection contract freezes goal_a as the home scoring target"):
		return
	if not T.require_true(self, absf(approach_sign) >= 0.9, "Soccer goal detection contract must expose a stable approach_sign_z for anti-backdoor checks"):
		return

	var score_result: Dictionary = world.debug_set_soccer_ball_state(goal_center, Vector3(0.0, 0.0, approach_sign * 1.3))
	if not T.require_true(self, bool(score_result.get("success", false)), "Soccer goal detection contract must allow synthetic ball placement into the goal volume for deterministic validation"):
		return
	var runtime_state: Dictionary = await _wait_for_score(world, "home", 1)
	if not T.require_true(self, int(runtime_state.get("home_score", 0)) == 1, "Entering goal_a from the valid field-facing direction must increment home_score exactly once"):
		return
	if not T.require_true(self, str(runtime_state.get("last_scored_side", "")) == "home", "Goal detection contract must preserve last_scored_side = home after a goal_a score"):
		return

	await _wait_for_game_state(world, "idle")
	await _settle_frames(8)
	runtime_state = world.get_soccer_venue_runtime_state()
	if not T.require_true(self, int(runtime_state.get("home_score", 0)) == 1, "Goal detection contract must not keep incrementing while the ball remains near the same goal volume"):
		return

	var backdoor_result: Dictionary = world.debug_set_soccer_ball_state(goal_center, Vector3(0.0, 0.0, -approach_sign * 1.3))
	if not T.require_true(self, bool(backdoor_result.get("success", false)), "Soccer goal detection contract must allow synthetic backdoor goal placement for anti-cheat validation"):
		return
	await _settle_frames(24)
	runtime_state = world.get_soccer_venue_runtime_state()
	if not T.require_true(self, int(runtime_state.get("home_score", 0)) == 1, "A ball entering the goal volume from behind must not be counted as a valid goal"):
		return
	if not T.require_true(self, str(runtime_state.get("bound_ball_prop_id", "")) == SOCCER_PROP_ID, "Goal detection contract must stay bound to the formal v25 soccer ball prop instead of spawning a hidden match ball"):
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

func _wait_for_score(world, scoring_side: String, expected_score: int) -> Dictionary:
	for _frame in range(90):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		var score: int = int(runtime_state.get("home_score", 0)) if scoring_side == "home" else int(runtime_state.get("away_score", 0))
		if score >= expected_score:
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
