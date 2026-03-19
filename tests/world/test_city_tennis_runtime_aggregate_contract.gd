extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TENNIS_CHUNK_ID := "chunk_158_140"
const TENNIS_VENUE_ID := "venue:v28:tennis_court:chunk_158_140"
const TENNIS_WORLD_POSITION := Vector3(5489.46, 20.62, 1029.73)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis runtime aggregate contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis runtime aggregate contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_tennis_venue_runtime_state"), "Tennis runtime aggregate contract requires get_tennis_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("get_soccer_venue_runtime_state"), "Tennis runtime aggregate contract must preserve soccer runtime introspection"):
		return
	if not T.require_true(self, world.has_method("is_ambient_simulation_frozen"), "Tennis runtime aggregate contract requires world-level ambient freeze introspection"):
		return
	if not T.require_true(self, world.has_method("get_tennis_match_hud_state"), "Tennis runtime aggregate contract requires tennis HUD state introspection"):
		return
	var hud_node := world.get_node_or_null("Hud")
	if not T.require_true(self, hud_node != null and hud_node.has_method("get_tennis_feedback_audio_state"), "Tennis runtime aggregate contract requires tennis HUD feedback audio introspection"):
		return
	if not T.require_true(self, world.get_node_or_null("Hud/Root/TennisMatchHud/Margin/VBox/Assist") != null, "Tennis runtime aggregate contract requires a concrete Assist label in the tennis HUD view"):
		return
	if not T.require_true(self, world.get_node_or_null("Hud/Root/TennisMatchHud/Margin/VBox/Coach") != null, "Tennis runtime aggregate contract requires a concrete Coach label in the tennis HUD view"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 0.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Tennis runtime aggregate contract must mount the tennis venue before runtime checks"):
		return

	var freeze_active := await _wait_for_freeze_state(world, true)
	if not T.require_true(self, freeze_active, "Entering the tennis court playable area must activate world-level ambient freeze aggregation"):
		return
	var tennis_state: Dictionary = world.get_tennis_venue_runtime_state()
	if not T.require_true(self, bool(tennis_state.get("ambient_simulation_frozen", false)), "Tennis runtime aggregate contract must expose frozen state through the tennis runtime snapshot"):
		return
	if not T.require_true(self, player.has_method("get_tennis_visual_state"), "Tennis runtime aggregate contract requires player tennis visual introspection"):
		return
	var player_visual_state: Dictionary = player.get_tennis_visual_state()
	if not T.require_true(self, bool(player_visual_state.get("racket_present", false)), "Tennis runtime aggregate contract must equip the player with a racket visual"):
		return
	if not T.require_true(self, bool(player_visual_state.get("equipped_visible", false)), "Tennis runtime aggregate contract must surface the player racket visual while the player is inside the tennis venue runtime"):
		return
	var opponent_node := mounted_venue.get_node_or_null("OpponentRoot/away_opponent_1")
	if not T.require_true(self, opponent_node != null and opponent_node.has_method("get_tennis_visual_state"), "Tennis runtime aggregate contract requires opponent tennis visual introspection"):
		return
	var opponent_visual_state: Dictionary = opponent_node.get_tennis_visual_state()
	if not T.require_true(self, bool(opponent_visual_state.get("racket_present", false)), "Tennis runtime aggregate contract must equip the away opponent with a racket visual"):
		return
	if not T.require_true(self, tennis_state.has("landing_marker_visible"), "Tennis runtime aggregate contract must expose landing_marker_visible in the runtime snapshot"):
		return
	if not T.require_true(self, tennis_state.has("landing_marker_world_position"), "Tennis runtime aggregate contract must expose landing_marker_world_position in the runtime snapshot"):
		return
	if not T.require_true(self, tennis_state.has("auto_footwork_assist_state"), "Tennis runtime aggregate contract must expose auto_footwork_assist_state in the runtime snapshot"):
		return
	if not T.require_true(self, tennis_state.has("strike_window_state"), "Tennis runtime aggregate contract must expose strike_window_state in the runtime snapshot"):
		return
	if not T.require_true(self, tennis_state.has("strike_quality_feedback"), "Tennis runtime aggregate contract must expose strike_quality_feedback in the runtime snapshot"):
		return
	if not T.require_true(self, tennis_state.has("feedback_event_token"), "Tennis runtime aggregate contract must expose feedback_event_token in the runtime snapshot"):
		return
	if not T.require_true(self, tennis_state.has("feedback_event_kind"), "Tennis runtime aggregate contract must expose feedback_event_kind in the runtime snapshot"):
		return
	if not T.require_true(self, tennis_state.has("feedback_event_text"), "Tennis runtime aggregate contract must expose feedback_event_text in the runtime snapshot"):
		return
	if not T.require_true(self, tennis_state.has("feedback_event_tone"), "Tennis runtime aggregate contract must expose feedback_event_tone in the runtime snapshot"):
		return
	if not T.require_true(self, tennis_state.has("rally_shot_count"), "Tennis runtime aggregate contract must expose rally_shot_count in the runtime snapshot"):
		return
	var hud_state: Dictionary = world.get_tennis_match_hud_state()
	if not T.require_true(self, hud_state.has("auto_footwork_assist_state"), "Tennis runtime aggregate contract must propagate auto_footwork_assist_state to the HUD snapshot"):
		return
	if not T.require_true(self, hud_state.has("strike_window_state"), "Tennis runtime aggregate contract must propagate strike_window_state to the HUD snapshot"):
		return
	if not T.require_true(self, hud_state.has("strike_quality_feedback"), "Tennis runtime aggregate contract must propagate strike_quality_feedback to the HUD snapshot"):
		return
	if not T.require_true(self, hud_state.has("coach_text"), "Tennis runtime aggregate contract must propagate coach_text to the HUD snapshot"):
		return
	if not T.require_true(self, hud_state.has("coach_tone"), "Tennis runtime aggregate contract must propagate coach_tone to the HUD snapshot"):
		return
	if not T.require_true(self, hud_state.has("feedback_event_token"), "Tennis runtime aggregate contract must propagate feedback_event_token to the HUD snapshot"):
		return
	if not T.require_true(self, hud_state.has("feedback_event_kind"), "Tennis runtime aggregate contract must propagate feedback_event_kind to the HUD snapshot"):
		return
	if not T.require_true(self, hud_state.has("feedback_event_text"), "Tennis runtime aggregate contract must propagate feedback_event_text to the HUD snapshot"):
		return
	if not T.require_true(self, hud_state.has("feedback_event_tone"), "Tennis runtime aggregate contract must propagate feedback_event_tone to the HUD snapshot"):
		return
	var feedback_audio_state: Dictionary = hud_node.get_tennis_feedback_audio_state()
	if not T.require_true(self, feedback_audio_state.has("play_count"), "Tennis runtime aggregate contract must expose tennis feedback audio play_count for verification"):
		return
	if not T.require_true(self, feedback_audio_state.has("last_event_kind"), "Tennis runtime aggregate contract must expose tennis feedback audio last_event_kind for verification"):
		return
	var soccer_state: Dictionary = world.get_soccer_venue_runtime_state()
	if not T.require_true(self, soccer_state is Dictionary, "Tennis runtime aggregate contract must keep soccer runtime access alive while tennis is enabled"):
		return

	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var release_buffer_m := float(court_contract.get("release_buffer_m", 28.0))
	var singles_width_m := float(court_contract.get("singles_width_m", 8.23 * 7.5))
	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(singles_width_m * 0.5 + release_buffer_m + 6.0, 2.0, 0.0))
	var freeze_released := await _wait_for_freeze_state(world, false)
	if not T.require_true(self, freeze_released, "Leaving the tennis release bounds must release world-level ambient freeze aggregation"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(TENNIS_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(TENNIS_VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null

func _wait_for_freeze_state(world, expected_state: bool) -> bool:
	for _frame in range(180):
		await physics_frame
		await process_frame
		if bool(world.is_ambient_simulation_frozen()) == expected_state:
			return true
	return bool(world.is_ambient_simulation_frozen()) == expected_state
