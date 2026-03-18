extends SceneTree

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const MAX_MATCH_OBSERVATION_FRAMES := 22000
const SIMULATION_TIME_SCALE := 8.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = SIMULATION_TIME_SCALE
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player := world.get_node("Player")
	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	player.teleport_to_world_position((start_contract.get("world_position", Vector3.ZERO) as Vector3) + Vector3.UP)
	var last_scoreline := "0:0"
	var last_distribution_count := 0
	for frame_idx in range(MAX_MATCH_OBSERVATION_FRAMES):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		var match_state := str(runtime_state.get("match_state", ""))
		var home_score := int(runtime_state.get("home_score", 0))
		var away_score := int(runtime_state.get("away_score", 0))
		var scoreline := "%d:%d" % [home_score, away_score]
		var clock_text := str(runtime_state.get("match_hud_state", {}).get("clock_text", ""))
		var ai_debug: Dictionary = runtime_state.get("ai_debug_state", {})
		var distribution_count := int(ai_debug.get("goalkeeper_distribution_count", 0))
		if scoreline != last_scoreline:
			print("GOAL frame=", frame_idx, " clock=", clock_text, " score=", scoreline, " last_touch=", ai_debug.get("last_touch_team_id", ""), "/", ai_debug.get("last_touch_role_id", ""), " distributions=", distribution_count)
			last_scoreline = scoreline
		if distribution_count != last_distribution_count:
			print("KEEPER_DISTRIBUTION frame=", frame_idx, " clock=", clock_text, " score=", scoreline, " by=", ai_debug.get("last_distribution_team_id", ""), "/", ai_debug.get("last_distribution_player_id", ""))
			last_distribution_count = distribution_count
		if frame_idx % 600 == 0:
			var ball_local := mounted_venue.to_local(runtime_state.get("last_ball_world_position", Vector3.ZERO))
			print("TICK frame=", frame_idx, " clock=", clock_text, " score=", scoreline, " ball=", ball_local, " touch=", ai_debug.get("last_touch_team_id", ""), "/", ai_debug.get("last_touch_role_id", ""), " distributions=", distribution_count)
		if match_state == "final":
			print("FINAL score=", scoreline, " distributions=", distribution_count)
			break
	world.queue_free()
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
