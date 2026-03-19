extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TENNIS_CHUNK_ID := "chunk_158_140"
const TENNIS_VENUE_ID := "venue:v28:tennis_court:chunk_158_140"
const TENNIS_PROP_ID := "prop:v28:tennis_ball:chunk_158_140"
const TENNIS_WORLD_POSITION := Vector3(5489.46, 20.62, 1029.73)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis AI return contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis AI return contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_tennis_venue_runtime_state"), "Tennis AI return contract requires get_tennis_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Tennis AI return contract requires the formal primary interaction entrypoint"):
		return
	if not T.require_true(self, world.has_method("get_interactive_prop_interaction_state"), "Tennis AI return contract requires shared interactive prop prompt introspection"):
		return
	var hud_node := world.get_node_or_null("Hud")
	if not T.require_true(self, hud_node != null and hud_node.has_method("get_focus_message_state"), "Tennis AI return contract requires HUD focus message introspection"):
		return
	if not T.require_true(self, hud_node.has_method("get_tennis_feedback_audio_state"), "Tennis AI return contract requires tennis feedback audio introspection"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Tennis AI return contract requires mounted tennis venue start contract"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_tennis_court_contract"), "Tennis AI return contract requires tennis court contract on the mounted venue"):
		return
	var opponent_node := mounted_venue.get_node_or_null("OpponentRoot/away_opponent_1")
	if not T.require_true(self, opponent_node != null and opponent_node.has_method("get_tennis_visual_state"), "Tennis AI return contract requires mounted opponent tennis visual introspection"):
		return
	if not T.require_true(self, player.has_method("get_tennis_visual_state"), "Tennis AI return contract requires player tennis visual introspection"):
		return
	var mounted_ball: Node3D = await _wait_for_mounted_ball(world)
	if not T.require_true(self, mounted_ball != null, "Tennis AI return contract requires the mounted tennis ball before live exchange checks"):
		return

	await _start_match(world, mounted_venue, player)
	var player_visual_state: Dictionary = player.get_tennis_visual_state()
	if not T.require_true(self, bool(player_visual_state.get("equipped_visible", false)), "Tennis AI return contract must surface the player racket once the live match enters pre-serve state"):
		return
	if not T.require_true(self, float(player_visual_state.get("target_length_m", 0.0)) >= 0.66 and float(player_visual_state.get("target_length_m", 0.0)) <= 0.74, "Tennis AI return contract must keep the equipped racket near a real-world adult length around 0.69m"):
		return
	player.teleport_to_world_position(mounted_ball.global_position + Vector3(-1.2, 0.95, 0.0))
	await _pump_frames(10)
	var pre_serve_prompt_state: Dictionary = world.get_interactive_prop_interaction_state()
	if not T.require_true(self, bool(pre_serve_prompt_state.get("visible", false)), "Tennis AI return contract must surface a visible shared prompt during the pre-serve window"):
		return
	if not T.require_true(self, str(pre_serve_prompt_state.get("prompt_text", "")).contains("发球"), "Tennis AI return contract pre-serve prompt must tell the player to serve"):
		return
	var serve_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(serve_result.get("success", false)), "Tennis AI return contract must allow the player to trigger a real serve through the shared interaction entrypoint"):
		return
	player_visual_state = player.get_tennis_visual_state()
	if not T.require_true(self, int(player_visual_state.get("swing_count", 0)) >= 1, "Tennis AI return contract must trigger a visible player swing when the opening serve is performed"):
		return
	if not T.require_true(self, int(player_visual_state.get("swing_sound_count", 0)) >= 1, "Tennis AI return contract must trigger audible player swing feedback when the opening serve is performed"):
		return
	if not T.require_true(self, str(player_visual_state.get("last_swing_style", "")) == "serve", "Tennis AI return contract must tag the opening player swing as a serve-style visual"):
		return
	var rally_state: Dictionary = await _wait_for_match_state(world, "rally")
	if not T.require_true(self, str(rally_state.get("last_hitter_side", "")) == "home", "Tennis AI return contract must preserve the player as last_hitter_side after the opening serve"):
		return
	var player_receive_anchor: Vector3 = player.global_position

	var ai_return_state: Dictionary = await _wait_for_ai_return(world)
	if not T.require_true(self, str(ai_return_state.get("last_hitter_side", "")) == "away", "Tennis AI return contract must let the away side perform a formal return instead of remaining idle"):
		return
	if not T.require_true(self, bool(ai_return_state.get("landing_marker_visible", false)), "Tennis AI return contract must expose landing_marker_visible after the AI sends the ball back to the player side"):
		return
	var landing_marker_world_position_variant: Variant = ai_return_state.get("landing_marker_world_position", null)
	if not T.require_true(self, landing_marker_world_position_variant is Vector3, "Tennis AI return contract must expose landing_marker_world_position as Vector3"):
		return
	var landing_marker_world_position := landing_marker_world_position_variant as Vector3
	if not T.require_true(self, bool(mounted_venue.is_world_point_in_play_bounds(landing_marker_world_position)), "Tennis AI return contract landing marker must stay inside formal in-play bounds"):
		return
	if not T.require_true(self, mounted_venue.to_local(landing_marker_world_position).z > 0.0, "Tennis AI return contract landing marker must move onto the player/home side after the AI return"):
		return
	if not T.require_true(self, str(ai_return_state.get("auto_footwork_assist_state", "")) != "idle", "Tennis AI return contract must surface a non-idle auto_footwork_assist_state while the player is preparing to receive"):
		return
	if not T.require_true(self, str(ai_return_state.get("strike_window_state", "")) == "tracking" or str(ai_return_state.get("strike_window_state", "")) == "ready", "Tennis AI return contract must surface a readable strike_window_state while the ball is coming back"):
		return
	var auto_move_distance := await _measure_player_receive_drift(world, player, player_receive_anchor)
	if not T.require_true(self, auto_move_distance <= 0.25, "Tennis AI return contract must not auto-walk the player into the receive ring anymore"):
		return
	var opponent_visual_state: Dictionary = opponent_node.get_tennis_visual_state()
	if not T.require_true(self, int(opponent_visual_state.get("swing_count", 0)) >= 1, "Tennis AI return contract must trigger a visible opponent swing when the AI sends the ball back"):
		return
	if not T.require_true(self, int(opponent_visual_state.get("swing_sound_count", 0)) >= 1, "Tennis AI return contract must trigger audible opponent swing feedback when the AI sends the ball back"):
		return
	if not T.require_true(self, str(opponent_visual_state.get("last_swing_style", "")) == "forehand" or str(opponent_visual_state.get("last_swing_style", "")) == "backhand", "Tennis AI return contract AI return visual must resolve to a readable tennis swing style"):
		return
	player.teleport_to_world_position(landing_marker_world_position + Vector3.UP * _estimate_standing_height(player))
	await _pump_frames(8)
	var ready_bundle := await _wait_for_ready_receive_prompt(world, hud_node)
	var ready_runtime_state: Dictionary = ready_bundle.get("runtime_state", {})
	var ready_prompt_state: Dictionary = ready_bundle.get("prompt_state", {})
	var focus_message_state: Dictionary = ready_bundle.get("focus_message_state", {})
	var feedback_audio_state: Dictionary = ready_bundle.get("feedback_audio_state", {})
	if not T.require_true(self, str(ready_runtime_state.get("strike_window_state", "")) == "ready", "Tennis AI return contract must eventually open a formal ready strike window for the player return"):
		return
	if not T.require_true(self, bool(ready_prompt_state.get("visible", false)), "Tennis AI return contract must keep the shared prompt visible when the ready strike window opens"):
		return
	if not T.require_true(self, str(ready_prompt_state.get("prompt_text", "")).contains("回球"), "Tennis AI return contract ready prompt must tell the player to return the ball"):
		return
	if not T.require_true(self, bool(focus_message_state.get("visible", false)), "Tennis AI return contract must surface a focus message when the ready strike window opens"):
		return
	if not T.require_true(self, str(focus_message_state.get("text", "")).contains("回球") or str(focus_message_state.get("text", "")).contains("READY"), "Tennis AI return contract ready focus message must explain that the player can now return the ball"):
		return
	if not T.require_true(self, int(feedback_audio_state.get("play_count", 0)) >= 1, "Tennis AI return contract must trigger at least one tennis feedback audio event before the player return window is consumed"):
		return
	if not T.require_true(self, str(feedback_audio_state.get("last_event_kind", "")) == "ready", "Tennis AI return contract ready window must map to a ready feedback audio event"):
		return

	var return_result: Dictionary = await _attempt_player_return(world)
	if not T.require_true(self, bool(return_result.get("success", false)), "Tennis AI return contract must let the player convert the shared prompt into a formal legal return after the AI shot"):
		return
	player_visual_state = player.get_tennis_visual_state()
	if not T.require_true(self, int(player_visual_state.get("swing_count", 0)) >= 2, "Tennis AI return contract must trigger another visible player swing when the player returns the AI shot"):
		return
	if not T.require_true(self, int(player_visual_state.get("swing_sound_count", 0)) >= 2, "Tennis AI return contract must trigger another audible player swing cue when the player returns the AI shot"):
		return
	if not T.require_true(self, str(player_visual_state.get("last_swing_style", "")) == "forehand" or str(player_visual_state.get("last_swing_style", "")) == "backhand", "Tennis AI return contract player return visual must resolve to a readable forehand/backhand swing instead of a generic pose"):
		return
	var home_return_state: Dictionary = await _wait_for_last_hitter(world, "home")
	if not T.require_true(self, str(home_return_state.get("planned_target_side", "")) == "away", "Tennis player return planner must send the ball back toward the away side by default"):
		return
	if not T.require_true(self, not bool(home_return_state.get("landing_marker_visible", true)), "Tennis player return contract must hide the incoming landing marker after the player has struck the ball"):
		return
	var second_ai_return_state: Dictionary = await _wait_for_ai_return(world)
	if not T.require_true(self, str(second_ai_return_state.get("last_hitter_side", "")) == "away", "Tennis AI return contract must support a second consecutive AI return after the player keeps the rally alive"):
		return
	var second_landing_variant: Variant = second_ai_return_state.get("landing_marker_world_position", null)
	if not T.require_true(self, second_landing_variant is Vector3, "Tennis AI return contract must expose a second landing marker position as Vector3 on the next rally beat"):
		return
	var second_landing_world_position := second_landing_variant as Vector3
	player.teleport_to_world_position(second_landing_world_position + Vector3.UP * _estimate_standing_height(player))
	await _pump_frames(8)
	var second_ready_bundle := await _wait_for_ready_receive_prompt(world, hud_node)
	var second_ready_runtime_state: Dictionary = second_ready_bundle.get("runtime_state", {})
	var second_planned_world_position_variant: Variant = second_ai_return_state.get("planned_target_world_position", Vector3.ZERO)
	var second_planned_world_position := second_planned_world_position_variant as Vector3 if second_planned_world_position_variant is Vector3 else Vector3.ZERO
	var second_bounce_probe: Dictionary = second_ready_runtime_state.get("debug_last_bounce_probe", {})
	var second_bounce_event: Dictionary = second_ready_runtime_state.get("debug_last_bounce_event", {})
	var second_live_out_world_position: Variant = second_ready_runtime_state.get("debug_last_live_out_world_position", Vector3.ZERO)
	var second_ready_summary := "strike=%s reason=%s winner=%s target=%s bounces_home=%s match=%s landing=%s planned=%s" % [
		str(second_ready_runtime_state.get("strike_window_state", "")),
		str(second_ready_runtime_state.get("point_end_reason", "")),
		str(second_ready_runtime_state.get("point_winner_side", "")),
		str(second_ready_runtime_state.get("target_side", "")),
		str(second_ready_runtime_state.get("ball_bounce_count_home", 0)),
		str(second_ready_runtime_state.get("match_state", "")),
		str(second_ai_return_state.get("landing_marker_world_position", Vector3.ZERO)),
		str(second_planned_world_position),
	]
	second_ready_summary += " planned_in=%s probe=%s bounce=%s live_out=%s" % [
		str(mounted_venue.is_world_point_in_play_bounds(second_planned_world_position)),
		str(second_bounce_probe),
		str(second_bounce_event),
		str(second_live_out_world_position),
	]
	if not T.require_true(self, str(second_ready_runtime_state.get("strike_window_state", "")) == "ready", "Tennis AI return contract must reopen READY on the second receive ring instead of becoming impossible on rally #2 | %s" % second_ready_summary):
		return
	var second_return_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(second_return_result.get("success", false)), "Tennis AI return contract must let the player convert the second ready receive ring into another legal return"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", TENNIS_WORLD_POSITION)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "pre_serve")

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

func _wait_for_mounted_ball(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(TENNIS_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_interactive_prop_node"):
			continue
		var mounted_ball: Variant = chunk_scene.find_scene_interactive_prop_node(TENNIS_PROP_ID)
		if mounted_ball != null:
			return mounted_ball
	return null

func _wait_for_match_state(world, expected_state: String) -> Dictionary:
	for _frame in range(360):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == expected_state:
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _wait_for_ai_return(world) -> Dictionary:
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("last_hitter_side", "")) == "away" and bool(runtime_state.get("landing_marker_visible", false)):
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _attempt_player_return(world) -> Dictionary:
	var repositioned := false
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		var interaction_state: Dictionary = world.get_interactive_prop_interaction_state()
		if not repositioned and bool(runtime_state.get("landing_marker_visible", false)):
			var strike_anchor_variant: Variant = runtime_state.get("landing_marker_world_position", Vector3.ZERO)
			if strike_anchor_variant is Vector3:
				var strike_anchor := strike_anchor_variant as Vector3
				var player: Node3D = world.get_node_or_null("Player") as Node3D
				if player != null and player.has_method("teleport_to_world_position"):
					player.teleport_to_world_position(strike_anchor + Vector3.UP * _estimate_standing_height(player))
					repositioned = true
		if str(runtime_state.get("strike_window_state", "")) != "ready":
			continue
		if not bool(interaction_state.get("visible", false)):
			continue
		return world.handle_primary_interaction()
	return {
		"success": false,
		"error": "player_return_window_timeout",
	}

func _wait_for_ready_receive_prompt(world, hud_node) -> Dictionary:
	var first_terminal_state: Dictionary = {}
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		var prompt_state: Dictionary = world.get_interactive_prop_interaction_state()
		var match_state := str(runtime_state.get("match_state", ""))
		if (match_state == "point_result" or match_state == "game_break" or match_state == "final") and first_terminal_state.is_empty():
			first_terminal_state = runtime_state.duplicate(true)
		if str(runtime_state.get("strike_window_state", "")) != "ready":
			continue
		if not bool(prompt_state.get("visible", false)):
			continue
		var focus_message_state: Dictionary = hud_node.get_focus_message_state()
		var feedback_audio_state: Dictionary = hud_node.get_tennis_feedback_audio_state()
		return {
			"runtime_state": runtime_state,
			"prompt_state": prompt_state,
			"focus_message_state": focus_message_state,
			"feedback_audio_state": feedback_audio_state,
		}
	if not first_terminal_state.is_empty():
		return {
			"runtime_state": first_terminal_state,
			"prompt_state": world.get_interactive_prop_interaction_state(),
			"focus_message_state": hud_node.get_focus_message_state(),
			"feedback_audio_state": hud_node.get_tennis_feedback_audio_state(),
		}
	return {
		"runtime_state": world.get_tennis_venue_runtime_state(),
		"prompt_state": world.get_interactive_prop_interaction_state(),
		"focus_message_state": hud_node.get_focus_message_state(),
		"feedback_audio_state": hud_node.get_tennis_feedback_audio_state(),
	}

func _wait_for_last_hitter(world, expected_side: String) -> Dictionary:
	for _frame in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("last_hitter_side", "")) == expected_side:
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _pump_frames(frame_count: int = 4) -> void:
	for _frame in range(frame_count):
		await physics_frame
		await process_frame

func _measure_player_receive_drift(world, player, anchor: Vector3) -> float:
	for _frame in range(24):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("strike_window_state", "")) == "ready":
			break
	var player_world_position: Vector3 = player.global_position
	return Vector2(player_world_position.x - anchor.x, player_world_position.z - anchor.z).length()

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
