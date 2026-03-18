extends SceneTree

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const MAX_MATCH_OBSERVATION_FRAMES := 22000
const SAMPLE_MATCH_COUNT := 10
const MAX_SINGLE_TEAM_SCORE := 9
const MAX_GOAL_DIFFERENCE := 6
const SIMULATION_TIME_SCALE := 8.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = SIMULATION_TIME_SCALE
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	for sample_index in range(SAMPLE_MATCH_COUNT):
		var world := (scene as PackedScene).instantiate()
		root.add_child(world)
		await process_frame
		var player := world.get_node("Player")
		player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
		var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
		var start_contract: Dictionary = mounted_venue.get_match_start_contract()
		player.teleport_to_world_position((start_contract.get("world_position", Vector3.ZERO) as Vector3) + Vector3.UP)
		var final_runtime_state := await _wait_for_match_state(world, "final", MAX_MATCH_OBSERVATION_FRAMES)
		var match_state := str(final_runtime_state.get("match_state", ""))
		var home_score := int(final_runtime_state.get("home_score", 0))
		var away_score := int(final_runtime_state.get("away_score", 0))
		var ai_debug: Dictionary = final_runtime_state.get("ai_debug_state", {})
		var success: bool = match_state == "final" and home_score <= MAX_SINGLE_TEAM_SCORE and away_score <= MAX_SINGLE_TEAM_SCORE and abs(home_score - away_score) <= MAX_GOAL_DIFFERENCE
		print(
			"SAMPLE ", sample_index + 1,
			" success=", success,
			" state=", match_state,
			" score=", home_score, ":", away_score,
			" kicks=", ai_debug.get("kick_count", 0),
			" passes=", ai_debug.get("pass_count", 0),
			" distributions=", ai_debug.get("goalkeeper_distribution_count", 0),
			" seed=", final_runtime_state.get("match_seed", 0)
		)
		world.queue_free()
		await process_frame
	quit()

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
