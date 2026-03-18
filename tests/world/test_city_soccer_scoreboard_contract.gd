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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer scoreboard contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer scoreboard contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_soccer_venue_runtime_state"), "Soccer scoreboard contract requires get_soccer_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer scoreboard contract requires debug_set_soccer_ball_state()"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 3.0, 6.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Soccer scoreboard contract must mount the soccer venue before scoreboard checks"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_scoreboard_contract"), "Soccer scoreboard contract requires get_scoreboard_contract() on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_scoreboard_state"), "Soccer scoreboard contract requires get_scoreboard_state() on the mounted venue"):
		return

	var scoreboard_contract: Dictionary = mounted_venue.get_scoreboard_contract()
	var scoreboard_state: Dictionary = mounted_venue.get_scoreboard_state()
	if not T.require_true(self, int(scoreboard_state.get("home_score", -1)) == 0 and int(scoreboard_state.get("away_score", -1)) == 0, "Soccer scoreboard contract must boot with a clean 0:0 scoreboard state"):
		return
	if not T.require_true(self, str(scoreboard_state.get("game_state_label", "")) == "READY", "Soccer scoreboard contract must boot with READY as the initial scoreboard label"):
		return
	if not T.require_true(self, float((scoreboard_contract.get("panel_size", Vector3.ZERO) as Vector3).x) >= 5.0, "Soccer scoreboard contract must expose a large world-space panel instead of a tiny decorative widget"):
		return

	var goal_b: Dictionary = mounted_venue.get_goal_contracts().get("goal_b", {})
	var goal_center: Vector3 = goal_b.get("world_center", Vector3.ZERO)
	var approach_sign: float = float(goal_b.get("approach_sign_z", 0.0))
	var score_result: Dictionary = world.debug_set_soccer_ball_state(goal_center, Vector3(0.0, 0.0, approach_sign * 1.3))
	if not T.require_true(self, bool(score_result.get("success", false)), "Soccer scoreboard contract must allow deterministic goal_b scoring setup"):
		return

	var runtime_state: Dictionary = await _wait_for_away_score(world, 1)
	scoreboard_state = mounted_venue.get_scoreboard_state()
	if not T.require_true(self, int(runtime_state.get("away_score", 0)) == 1, "Scoring into goal_b must increment away_score in the runtime state"):
		return
	if not T.require_true(self, int(scoreboard_state.get("away_score", 0)) == 1, "Scoring into goal_b must also update the world-space scoreboard away_score"):
		return
	if not T.require_true(self, int(scoreboard_state.get("home_score", 0)) == int(runtime_state.get("home_score", 0)), "Scoreboard contract must keep home_score synchronized with runtime state"):
		return
	if not T.require_true(self, str(scoreboard_state.get("game_state_label", "")) == str((runtime_state.get("scoreboard_state", {}) as Dictionary).get("game_state_label", "")), "Scoreboard contract must mirror the runtime game_state_label instead of becoming a static decoration"):
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

func _wait_for_away_score(world, expected_score: int) -> Dictionary:
	for _frame in range(90):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if int(runtime_state.get("away_score", 0)) >= expected_score:
			return runtime_state
	return world.get_soccer_venue_runtime_state()
