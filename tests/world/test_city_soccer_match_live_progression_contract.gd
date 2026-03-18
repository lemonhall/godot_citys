extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const LIVE_OBSERVATION_FRAMES := 360
const NEUTRAL_ZONE_Z_M := 8.0
const MAX_NEUTRAL_IN_PLAY_FRAMES := 180
const MAX_NEUTRAL_IN_PLAY_STREAK := 96
const MAX_TEAM_SWITCHES := 5

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer match live progression contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer match live progression contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer match live progression contract requires deterministic ball placement"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Soccer match live progression contract requires the mounted venue start ring contract"):
		return

	await _start_match(world, mounted_venue, player)
	if not T.require_true(self, mounted_venue.has_method("get_play_surface_contract"), "Soccer match live progression contract requires play surface metadata for deterministic center-ball setup"):
		return
	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", SOCCER_WORLD_POSITION)
	var reset_ball_result: Dictionary = world.debug_set_soccer_ball_state(kickoff_anchor + Vector3(0.0, 0.6, 0.0), Vector3.ZERO)
	if not T.require_true(self, bool(reset_ball_result.get("success", false)), "Soccer match live progression contract must allow deterministic center-ball setup before live-play observation"):
		return

	var progression_metrics := await _observe_live_progression(world, mounted_venue)
	if not T.require_true(self, int(progression_metrics.get("kick_count", 0)) >= 4, "Soccer match live progression contract requires multiple AI touches during the observed open-play window"):
		return
	if not T.require_true(self, int(progression_metrics.get("neutral_in_play_frames", 0)) <= MAX_NEUTRAL_IN_PLAY_FRAMES, "Soccer match live progression contract must not leave the ball trapped around midfield for most of live play"):
		return
	if not T.require_true(self, int(progression_metrics.get("longest_neutral_in_play_streak", 0)) <= MAX_NEUTRAL_IN_PLAY_STREAK, "Soccer match live progression contract must break center-circle tug-of-war streaks instead of letting one midfield scrum run forever"):
		return
	if not T.require_true(self, int(progression_metrics.get("team_switches", 0)) <= MAX_TEAM_SWITCHES, "Soccer match live progression contract must not alternate last-touch control between red and blue every few kicks in midfield"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", Vector3.ZERO)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "in_progress")

func _observe_live_progression(world, mounted_venue: Node3D) -> Dictionary:
	var neutral_in_play_frames := 0
	var neutral_in_play_streak := 0
	var longest_neutral_in_play_streak := 0
	var last_touch_team_id := ""
	var team_switches := 0
	var kick_count := 0
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
		var touch_team_id := str(ai_debug.get("last_touch_team_id", ""))
		if touch_team_id != "" and last_touch_team_id != "" and touch_team_id != last_touch_team_id:
			team_switches += 1
		if touch_team_id != "":
			last_touch_team_id = touch_team_id
	return {
		"kick_count": kick_count,
		"neutral_in_play_frames": neutral_in_play_frames,
		"longest_neutral_in_play_streak": longest_neutral_in_play_streak,
		"team_switches": team_switches,
	}

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
