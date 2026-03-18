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
	world.debug_set_soccer_ball_state(kickoff_anchor + Vector3(0.0, 0.6, 35.0), Vector3(0.0, 0.0, 8.8))
	for frame_idx in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		var roster_state: Dictionary = mounted_venue.get_match_roster_state()
		var keeper_intent := ""
		for player_entry_variant in roster_state.get("players", []):
			var player_entry: Dictionary = player_entry_variant
			if str(player_entry.get("team_id", "")) != "home":
				continue
			if str(player_entry.get("role_id", "")) != "goalkeeper":
				continue
			var state: Dictionary = player_entry.get("state", {})
			keeper_intent = str(state.get("intent_kind", ""))
			break
		var ai_debug: Dictionary = runtime_state.get("ai_debug_state", {})
		var ball_local := mounted_venue.to_local(runtime_state.get("last_ball_world_position", Vector3.ZERO))
		print(
			"FRAME ", frame_idx,
			" KEEPER_INTENT ", keeper_intent,
			" GK_PHASE ", ai_debug.get("goalkeeper_control_phase", ""),
			" GK_PLAYER ", ai_debug.get("goalkeeper_control_player_id", ""),
			" TOUCH ", ai_debug.get("last_touch_team_id", ""), "/", ai_debug.get("last_touch_role_id", ""),
			" SCORE ", runtime_state.get("home_score", 0), ":", runtime_state.get("away_score", 0),
			" BALL_LOCAL ", ball_local,
			" MATCH_SEED ", ai_debug.get("match_seed", 0)
		)
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
