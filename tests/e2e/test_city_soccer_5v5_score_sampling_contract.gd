extends SceneTree

const T := preload("res://tests/_test_util.gd")

# Slow acceptance test:
# Runs 10 full 5:00 autonomous matches and rejects a degenerate all-identical score distribution.

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const SAMPLE_MATCH_COUNT := 10
const MAX_MATCH_OBSERVATION_FRAMES := 22000
const MAX_SINGLE_TEAM_SCORE := 9
const MAX_GOAL_DIFFERENCE := 6

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer score sampling contract")
		return

	var scorelines: Array[String] = []
	for _sample_index in range(SAMPLE_MATCH_COUNT):
		var sample_result := await _run_single_match(scene)
		if not T.require_true(self, bool(sample_result.get("success", false)), "Soccer score sampling contract requires every sampled match to reach a valid final state"):
			return
		scorelines.append(str(sample_result.get("scoreline", "0:0")))

	var distinct_scorelines := {}
	for scoreline in scorelines:
		distinct_scorelines[scoreline] = true
	if not T.require_true(self, distinct_scorelines.size() >= 2, "Ten sampled autonomous matches must not all finish with the exact same scoreline"):
		return

	T.pass_and_quit(self)

func _run_single_match(scene: PackedScene) -> Dictionary:
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if player == null or not player.has_method("teleport_to_world_position"):
		world.queue_free()
		return {"success": false, "error": "missing_player"}

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if mounted_venue == null or not mounted_venue.has_method("get_match_start_contract"):
		world.queue_free()
		return {"success": false, "error": "missing_venue"}

	await _start_match(world, mounted_venue, player)
	var final_runtime_state := await _wait_for_match_state(world, "final", MAX_MATCH_OBSERVATION_FRAMES)
	var match_state := str(final_runtime_state.get("match_state", ""))
	var home_score := int(final_runtime_state.get("home_score", 0))
	var away_score := int(final_runtime_state.get("away_score", 0))
	world.queue_free()
	return {
		"success": match_state == "final" and home_score <= MAX_SINGLE_TEAM_SCORE and away_score <= MAX_SINGLE_TEAM_SCORE and abs(home_score - away_score) <= MAX_GOAL_DIFFERENCE,
		"scoreline": "%d:%d" % [home_score, away_score],
	}

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", Vector3.ZERO)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "in_progress", 180)

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

func _wait_for_match_state(world, expected_state: String, frame_budget: int) -> Dictionary:
	for _frame in range(frame_budget):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == expected_state:
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
