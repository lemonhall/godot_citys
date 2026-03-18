extends SceneTree

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player := world.get_node("Player")
	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", SOCCER_WORLD_POSITION)
	player.teleport_to_world_position((start_contract.get("world_position", Vector3.ZERO) as Vector3) + Vector3.UP)
	for _i in range(30):
		await physics_frame
		await process_frame
	world.debug_set_soccer_ball_state(kickoff_anchor + Vector3(0.0, 0.6, 0.0), Vector3.ZERO)
	var neutral_frames := 0
	var neutral_in_play_frames := 0
	var in_play_frames := 0
	var max_abs_z := 0.0
	var last_team := ""
	var team_switches := 0
	for frame_idx in range(720):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		var ball_world: Vector3 = runtime_state.get("last_ball_world_position", Vector3.ZERO)
		var ball_local := mounted_venue.to_local(ball_world)
		var game_state := str(runtime_state.get("game_state", ""))
		var home_score := int(runtime_state.get("home_score", 0))
		var away_score := int(runtime_state.get("away_score", 0))
		var abs_z := absf(ball_local.z)
		max_abs_z = maxf(max_abs_z, abs_z)
		if abs_z <= 8.0:
			neutral_frames += 1
			if game_state == "in_play":
				neutral_in_play_frames += 1
		if game_state == "in_play":
			in_play_frames += 1
		var ai_debug: Dictionary = runtime_state.get("ai_debug_state", {})
		var touch_team := str(ai_debug.get("last_touch_team_id", ""))
		if touch_team != "" and last_team != "" and touch_team != last_team:
			team_switches += 1
		if touch_team != "":
			last_team = touch_team
		if frame_idx % 30 == 0:
			print("FRAME ", frame_idx, " STATE ", game_state, " SCORE ", home_score, ":", away_score, " BALL_LOCAL ", ball_local, " MAX_Z ", max_abs_z, " TOUCH ", touch_team, " KICKS ", ai_debug.get("kick_count", 0), " SWITCHES ", team_switches)
	print("SUMMARY neutral_frames=", neutral_frames, " neutral_in_play_frames=", neutral_in_play_frames, " in_play_frames=", in_play_frames, " max_abs_z=", max_abs_z, " team_switches=", team_switches, " score=", world.get_soccer_venue_runtime_state().get("home_score", 0), ":", world.get_soccer_venue_runtime_state().get("away_score", 0))
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
