extends SceneTree

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const LIVE_OBSERVATION_FRAMES := 360
const NEUTRAL_ZONE_Z_M := 8.0
const SEEDS := [10101, 20202, 30303, 40404, 50505, 60606, 70707, 80808, 90909, 424242]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn") as PackedScene
	for seed in SEEDS:
		var world := scene.instantiate()
		root.add_child(world)
		await process_frame
		world.debug_set_soccer_match_seed(seed)
		var player := world.get_node("Player")
		player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
		var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
		var start_contract: Dictionary = mounted_venue.get_match_start_contract()
		var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
		var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", SOCCER_WORLD_POSITION)
		player.teleport_to_world_position((start_contract.get("world_position", Vector3.ZERO) as Vector3) + Vector3.UP)
		await _wait_for_match_state(world, "in_progress")
		world.debug_set_soccer_ball_state(kickoff_anchor + Vector3(0.0, 0.6, 0.0), Vector3.ZERO)
		var neutral_in_play_frames := 0
		var neutral_in_play_streak := 0
		var longest_neutral_in_play_streak := 0
		var last_touch_team_id := ""
		var team_switches := 0
		var kick_count := 0
		var pass_count := 0
		var keeper_distribution_count := 0
		var last_touch_action_kind := ""
		for _frame in range(LIVE_OBSERVATION_FRAMES):
			await physics_frame
			await process_frame
			var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
			var game_state := str(runtime_state.get("game_state", ""))
			var ball_world_position: Vector3 = runtime_state.get("last_ball_world_position", Vector3.ZERO)
			var ball_local_position := mounted_venue.to_local(ball_world_position)
			var in_neutral_zone := absf(ball_local_position.z) <= NEUTRAL_ZONE_Z_M
			if game_state == "in_play" and in_neutral_zone:
				neutral_in_play_frames += 1
				neutral_in_play_streak += 1
				longest_neutral_in_play_streak = maxi(longest_neutral_in_play_streak, neutral_in_play_streak)
			elif game_state == "in_play":
				neutral_in_play_streak = 0
			else:
				neutral_in_play_streak = 0
			var ai_debug: Dictionary = runtime_state.get("ai_debug_state", {})
			kick_count = maxi(kick_count, int(ai_debug.get("kick_count", 0)))
			pass_count = maxi(pass_count, int(ai_debug.get("pass_count", 0)))
			keeper_distribution_count = maxi(keeper_distribution_count, int(ai_debug.get("goalkeeper_distribution_count", 0)))
			last_touch_action_kind = str(ai_debug.get("last_touch_action_kind", last_touch_action_kind))
			var touch_team_id := str(ai_debug.get("last_touch_team_id", ""))
			if touch_team_id != "" and last_touch_team_id != "" and touch_team_id != last_touch_team_id:
				team_switches += 1
			if touch_team_id != "":
				last_touch_team_id = touch_team_id
		var final_state: Dictionary = world.get_soccer_venue_runtime_state()
		print(
			"SEED ", seed,
			" neutral_frames=", neutral_in_play_frames,
			" longest=", longest_neutral_in_play_streak,
			" switches=", team_switches,
			" kicks=", kick_count,
			" passes=", pass_count,
			" distributions=", keeper_distribution_count,
			" last_action=", last_touch_action_kind,
			" score=", final_state.get("home_score", 0), ":", final_state.get("away_score", 0)
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

func _wait_for_match_state(world, expected_state: String) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == expected_state:
			return runtime_state
	return world.get_soccer_venue_runtime_state()
