extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer minigame goal flow")
		return

	var world = (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer minigame goal flow requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_soccer_venue_runtime_state"), "Soccer minigame goal flow requires get_soccer_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer minigame goal flow requires debug_set_soccer_ball_state()"):
		return
	if not T.require_true(self, world.has_method("is_ambient_simulation_frozen"), "Soccer minigame goal flow requires ambient freeze introspection"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 1.2, 0.0))
	var runtime_state: Dictionary = await _wait_for_ambient_freeze(world, true)
	if not T.require_true(self, bool(runtime_state.get("ambient_simulation_frozen", false)), "Entering the soccer venue must activate ambient freeze in the end-to-end flow"):
		return

	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Soccer minigame goal flow must mount the venue before goal setup"):
		return
	var goal_b: Dictionary = mounted_venue.get_goal_contracts().get("goal_b", {})
	var goal_center: Vector3 = goal_b.get("world_center", Vector3.ZERO)
	var approach_sign: float = float(goal_b.get("approach_sign_z", 0.0))
	if not T.require_true(self, absf(approach_sign) >= 0.9, "Soccer minigame goal flow requires stable goal_b approach metadata"):
		return

	var score_result: Dictionary = world.debug_set_soccer_ball_state(goal_center, Vector3(0.0, 0.0, approach_sign * 1.3))
	if not T.require_true(self, bool(score_result.get("success", false)), "Soccer minigame goal flow must allow deterministic goal setup through the shared soccer ball binding"):
		return

	runtime_state = await _wait_for_score(world, "away", 1)
	if not T.require_true(self, int(runtime_state.get("away_score", 0)) == 1, "Scoring into goal_b must increment away_score in the end-to-end goal flow"):
		return
	var scoreboard_state: Dictionary = (runtime_state.get("scoreboard_state", {}) as Dictionary).duplicate(true)
	if not T.require_true(self, str(scoreboard_state.get("game_state_label", "")) == "GOAL AWAY", "The goal flow must surface GOAL AWAY on the runtime scoreboard label immediately after scoring"):
		return

	runtime_state = await _wait_for_game_state(world, "idle")
	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", Vector3.ZERO)
	var mounted_ball: Variant = await _wait_for_mounted_ball(world)
	if not T.require_true(self, mounted_ball != null, "Soccer minigame goal flow must keep the original soccer ball mounted through reset"):
		return
	var kickoff_ball_offset := _resolve_kickoff_ball_offset(runtime_state)
	if not T.require_true(self, mounted_ball.global_position.distance_to(kickoff_anchor + kickoff_ball_offset) <= 0.16, "After a goal the same soccer ball must reset back onto the raised venue kickoff surface instead of dropping back to the old terrain height"):
		return
	if not T.require_true(self, int(runtime_state.get("away_score", 0)) == 1 and int(runtime_state.get("home_score", 0)) == 0, "Resetting after a goal must preserve the scored 0:1 match state"):
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
		var mounted_ball: Variant = chunk_scene.find_scene_interactive_prop_node("prop:v25:soccer_ball:chunk_129_139")
		if mounted_ball != null:
			return mounted_ball
	return null

func _wait_for_ambient_freeze(world, expected_state: bool) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if bool(runtime_state.get("ambient_simulation_frozen", false)) == expected_state and bool(world.is_ambient_simulation_frozen()) == expected_state:
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

func _wait_for_game_state(world, game_state: String) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if str(runtime_state.get("game_state", "")) == game_state:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

func _resolve_kickoff_ball_offset(runtime_state: Dictionary) -> Vector3:
	var kickoff_ball_offset_variant: Variant = runtime_state.get("kickoff_ball_offset", Vector3(0.0, 0.6, 0.0))
	if kickoff_ball_offset_variant is Vector3:
		return kickoff_ball_offset_variant as Vector3
	return Vector3(0.0, 0.6, 0.0)
