extends RefCounted

const DEFAULT_RELEASE_BUFFER_M := 24.0
const GOAL_RESULT_LINGER_SEC := 0.75
const OUT_OF_BOUNDS_LINGER_SEC := 0.45
const IN_PLAY_SPEED_THRESHOLD_MPS := 0.35
const IN_PLAY_DISTANCE_THRESHOLD_M := 0.45
const DEFAULT_BALL_CENTER_OFFSET := Vector3(0.0, 0.6, 0.0)
const ACTIVE_VENUE_SCAN_RADIUS_M := 768.0
const MATCH_DURATION_SEC := 300.0
const MATCH_SURFACE_SIZE_FALLBACK := Vector3(74.0, 0.36, 118.0)
const MATCH_GOAL_WIDTH_FALLBACK_M := 7.32
const MATCH_PLAYER_FIELD_MARGIN_M := 4.5
const MATCH_FIELD_PLAYER_SPEED_MPS := 9.8
const MATCH_GOALKEEPER_SPEED_MPS := 10.6
const MATCH_AI_TOUCH_RADIUS_M := 2.35
const MATCH_AI_TOUCH_COOLDOWN_SEC := 0.28
const MATCH_AI_FIELD_PLAYER_KICK_SPEED_MPS := 16.5
const MATCH_AI_GOALKEEPER_KICK_SPEED_MPS := 18.5
const MATCH_AI_TOUCH_LIFT_MPS := 1.25
const MATCH_AI_NEUTRAL_ZONE_BUFFER_M := 8.0
const MATCH_AI_POSSESSION_WINDOW_SEC := 1.45
const MATCH_AI_POSSESSION_BREAK_ADVANTAGE_M := 0.72
const MATCH_AI_SHOT_DISTANCE_WINDOW_M := 21.5
const MATCH_AI_PROGRESS_DISTANCE_WINDOW_M := 36.0
const MATCH_AI_SHOT_TOUCH_COOLDOWN_SEC := 0.82
const MATCH_AI_KICKOFF_PROTECTION_SEC := 2.2
const MATCH_GOALKEEPER_SECURE_BALL_SPEED_MAX_MPS := 11.2
const MATCH_GOALKEEPER_SECURE_TOUCH_RADIUS_M := 3.08
const MATCH_GOALKEEPER_SECURE_HOLD_SEC := 0.72
const MATCH_GOALKEEPER_DISTRIBUTION_WINDUP_SEC := 0.12
const MATCH_GOALKEEPER_CONTROL_BALL_HEIGHT_M := 1.55
const MATCH_GOALKEEPER_DISTRIBUTION_SPEED_MPS := 18.2
const MATCH_GOALKEEPER_DISTRIBUTION_LIFT_MPS := 1.05
const MATCH_GOALKEEPER_DISTRIBUTION_ADVANCE_M := 34.0
const MATCH_GOALKEEPER_DISTRIBUTION_TOUCH_COOLDOWN_SEC := 2.0
const MATCH_STATE_IDLE := "idle"
const MATCH_STATE_IN_PROGRESS := "in_progress"
const MATCH_STATE_FINAL := "final"

var _entries_by_venue_id: Dictionary = {}
var _active_venue_id := ""
var _game_state := "idle"
var _state_timer_sec := 0.0
var _home_score := 0
var _away_score := 0
var _last_scored_side := ""
var _last_result_state := ""
var _ambient_simulation_frozen := false
var _bound_ball_prop_id := ""
var _ball_bound := false
var _kickoff_ball_offset := DEFAULT_BALL_CENTER_OFFSET
var _has_kickoff_ball_offset := false
var _kickoff_surface_sync_ball_instance_id := 0
var _kickoff_surface_synced := false
var _last_ball_world_position := Vector3.ZERO
var _match_state := MATCH_STATE_IDLE
var _match_clock_remaining_sec := MATCH_DURATION_SEC
var _winner_side := ""
var _match_player_contracts: Array = []
var _match_player_states: Dictionary = {}
var _match_countdown_armed := false
var _match_clock_tick_accumulator_sec := 0.0
var _last_ai_touch_cooldown_sec := 0.0
var _ai_possession_team_id := ""
var _ai_possession_player_id := ""
var _ai_possession_timer_sec := 0.0
var _ai_touch_streak_team_id := ""
var _ai_touch_streak_player_id := ""
var _ai_touch_streak_count := 0
var _ai_carry_streak_team_id := ""
var _ai_carry_streak_player_id := ""
var _ai_carry_streak_count := 0
var _kickoff_team_id := "home"
var _kickoff_protection_timer_sec := 0.0
var _pending_restart_team_id := ""
var _match_session_serial := 0
var _match_team_profiles: Dictionary = {}
var _goalkeeper_control_state := {
	"team_id": "",
	"player_id": "",
	"phase": "",
	"timer_sec": 0.0,
}
var _match_rng := RandomNumberGenerator.new()
var _match_seed := 0
var _forced_match_seed := 0
var _ai_debug_state := {
	"kick_count": 0,
	"pass_count": 0,
	"last_touch_player_id": "",
	"last_touch_team_id": "",
	"last_touch_role_id": "",
	"last_touch_action_kind": "",
	"goalkeeper_distribution_count": 0,
	"last_distribution_player_id": "",
	"last_distribution_team_id": "",
	"last_distribution_role_id": "",
	"control_team_id": "",
	"control_player_id": "",
	"control_time_remaining_sec": 0.0,
	"kickoff_team_id": "",
	"kickoff_time_remaining_sec": 0.0,
	"goalkeeper_control_team_id": "",
	"goalkeeper_control_player_id": "",
	"goalkeeper_control_phase": "",
	"goalkeeper_control_time_remaining_sec": 0.0,
	"match_seed": 0,
}
var _scoreboard_state := {
	"home_score": 0,
	"away_score": 0,
	"game_state": "idle",
	"game_state_label": "READY",
	"last_scored_side": "",
	"winner_highlight_visible": false,
	"winner_highlight_side": "",
}
var _match_hud_state := {
	"visible": false,
	"match_state": MATCH_STATE_IDLE,
	"home_score": 0,
	"away_score": 0,
	"home_team_color_id": "red",
	"away_team_color_id": "blue",
	"clock_text": "05:00",
	"winner_side": "",
}

func configure(entries: Dictionary) -> void:
	_entries_by_venue_id = entries.duplicate(true)
	_kickoff_ball_offset = DEFAULT_BALL_CENTER_OFFSET
	_has_kickoff_ball_offset = false
	_kickoff_surface_sync_ball_instance_id = 0
	_kickoff_surface_synced = false
	if _active_venue_id == "" or not _entries_by_venue_id.has(_active_venue_id):
		_active_venue_id = _resolve_default_venue_id()
	_reset_runtime_state()
	_refresh_scoreboard_state()
	_refresh_match_hud_state()

func update(chunk_renderer: Node, player_node: Node3D, delta: float) -> Dictionary:
	var entry := _resolve_active_entry()
	if entry.is_empty():
		_handle_unavailable_runtime()
		return get_state()
	if not _is_player_near_active_venue(entry, player_node):
		_handle_unavailable_runtime(str(entry.get("primary_ball_prop_id", "")))
		return get_state()
	var mounted_venue := _resolve_mounted_venue(chunk_renderer, entry)
	var ball_node := _resolve_bound_ball(chunk_renderer, entry)
	var kickoff_anchor := _resolve_kickoff_anchor(entry, mounted_venue)
	_ensure_match_roster(mounted_venue)
	_ensure_play_surface_collision_isolation(ball_node, mounted_venue)
	_refresh_kickoff_surface_sync_tracking(ball_node)
	_capture_kickoff_ball_offset(ball_node, kickoff_anchor)
	_update_ambient_freeze(player_node, mounted_venue)
	if mounted_venue == null or ball_node == null:
		_refresh_scoreboard_state()
		_refresh_match_hud_state()
		_sync_match_visual_state(mounted_venue)
		return get_state()
	_maybe_sync_ball_to_kickoff_surface(ball_node, kickoff_anchor)

	var player_world_position := player_node.global_position if player_node != null else Vector3.ZERO
	var in_release_bounds := mounted_venue.has_method("is_world_point_in_release_bounds") and bool(mounted_venue.is_world_point_in_release_bounds(player_world_position))
	if not in_release_bounds and _has_dirty_match_session():
		_perform_full_match_reset(ball_node, kickoff_anchor)
		_refresh_scoreboard_state()
		_sync_scoreboard_display(mounted_venue)
		_refresh_match_hud_state()
		_sync_match_visual_state(mounted_venue)
		return get_state()

	if _match_state == MATCH_STATE_IDLE and _can_player_start_match(player_world_position, mounted_venue):
		_start_match(ball_node, kickoff_anchor)

	var ball_world_position := _get_ball_world_position(ball_node)
	var ball_linear_velocity := _get_ball_linear_velocity(ball_node)
	_advance_ball_game_state(mounted_venue, ball_node, ball_world_position, ball_linear_velocity, kickoff_anchor, delta)
	if _match_state == MATCH_STATE_IN_PROGRESS:
		_advance_match_ai(ball_node, mounted_venue, delta)
		_advance_match_clock(delta)
	elif _match_state == MATCH_STATE_FINAL:
		_update_final_match_player_states()
	else:
		_update_idle_match_player_states()

	_last_ball_world_position = _get_ball_world_position(ball_node)
	_refresh_scoreboard_state()
	_sync_scoreboard_display(mounted_venue)
	_refresh_match_hud_state()
	_sync_match_visual_state(mounted_venue)
	return get_state()

func get_state() -> Dictionary:
	var entry := _resolve_active_entry()
	return {
		"active_venue_id": _active_venue_id,
		"venue_entry_count": _entries_by_venue_id.size(),
		"primary_ball_prop_id": str(entry.get("primary_ball_prop_id", "")),
		"bound_ball_prop_id": _bound_ball_prop_id,
		"ball_bound": _ball_bound,
		"game_state": _game_state,
		"home_score": _home_score,
		"away_score": _away_score,
		"last_scored_side": _last_scored_side,
		"last_result_state": _last_result_state,
		"ambient_simulation_frozen": _ambient_simulation_frozen,
		"scoreboard_state": _scoreboard_state.duplicate(true),
		"kickoff_ball_offset": _kickoff_ball_offset,
		"last_ball_world_position": _last_ball_world_position,
		"match_state": _match_state,
		"match_clock_remaining_sec": _match_clock_remaining_sec,
		"winner_side": _winner_side,
		"match_hud_state": _match_hud_state.duplicate(true),
		"match_player_count": _match_player_contracts.size(),
		"ai_debug_state": _ai_debug_state.duplicate(true),
		"match_seed": _match_seed,
	}

func get_match_hud_state() -> Dictionary:
	return _match_hud_state.duplicate(true)

func is_ambient_simulation_frozen() -> bool:
	return _ambient_simulation_frozen

func debug_set_ball_state(chunk_renderer: Node, world_position: Vector3, linear_velocity: Vector3 = Vector3.ZERO, angular_velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	var entry := _resolve_active_entry()
	if entry.is_empty():
		return {"success": false, "error": "missing_entry"}
	var ball_node := _resolve_bound_ball(chunk_renderer, entry)
	if ball_node == null:
		return {"success": false, "error": "missing_ball"}
	if ball_node is Node3D:
		(ball_node as Node3D).global_position = world_position
	if ball_node is RigidBody3D:
		var rigid_ball := ball_node as RigidBody3D
		rigid_ball.linear_velocity = linear_velocity
		rigid_ball.angular_velocity = angular_velocity
		rigid_ball.sleeping = linear_velocity.length_squared() <= 0.0001 and angular_velocity.length_squared() <= 0.0001
	_last_ai_touch_cooldown_sec = 0.0
	_clear_ai_possession()
	_clear_ai_touch_streaks()
	_clear_goalkeeper_control()
	_last_ball_world_position = world_position
	if _game_state == "idle" and (linear_velocity.length() > 0.0 or world_position.distance_to(_resolve_kickoff_anchor(entry, _resolve_mounted_venue(chunk_renderer, entry)) + _kickoff_ball_offset) > 0.05):
		_set_game_state("in_play", 0.0)
	_sync_ai_control_debug_state()
	_refresh_scoreboard_state()
	_refresh_match_hud_state()
	return {
		"success": true,
		"ball_world_position": world_position,
	}

func debug_force_reset_ball(chunk_renderer: Node) -> Dictionary:
	var entry := _resolve_active_entry()
	if entry.is_empty():
		return {"success": false, "error": "missing_entry"}
	var ball_node := _resolve_bound_ball(chunk_renderer, entry)
	if ball_node == null:
		return {"success": false, "error": "missing_ball"}
	_last_ai_touch_cooldown_sec = 0.0
	_clear_ai_possession()
	_clear_ai_touch_streaks()
	_clear_goalkeeper_control()
	_perform_ball_reset(ball_node, _resolve_kickoff_anchor(entry, _resolve_mounted_venue(chunk_renderer, entry)))
	_set_game_state("idle", 0.0)
	_sync_ai_control_debug_state()
	_refresh_scoreboard_state()
	_refresh_match_hud_state()
	return {"success": true}

func notify_manual_ball_interaction(prop_id: String = "", _player_node: Node3D = null) -> Dictionary:
	var normalized_prop_id := str(prop_id).strip_edges()
	if normalized_prop_id != "" and normalized_prop_id != _bound_ball_prop_id:
		return {
			"success": false,
			"error": "prop_mismatch",
		}
	_last_ai_touch_cooldown_sec = 0.32
	_clear_ai_possession()
	_clear_ai_touch_streaks()
	_clear_goalkeeper_control()
	_set_game_state("in_play", 0.0)
	_sync_ai_control_debug_state()
	return {
		"success": true,
		"game_state": _game_state,
	}

func debug_set_match_seed(match_seed_value: int) -> Dictionary:
	_forced_match_seed = maxi(match_seed_value, 0)
	return {
		"success": true,
		"match_seed": _forced_match_seed,
	}

func debug_set_match_clock_remaining_sec(seconds: float) -> Dictionary:
	if _match_state == MATCH_STATE_IDLE:
		return {"success": false, "error": "match_inactive"}
	_match_clock_remaining_sec = clampf(seconds, 0.0, MATCH_DURATION_SEC)
	if _match_clock_remaining_sec <= 0.0:
		_end_match()
	_match_clock_tick_accumulator_sec = 0.0
	_refresh_scoreboard_state()
	_refresh_match_hud_state()
	return {
		"success": true,
		"match_state": _match_state,
		"match_clock_remaining_sec": _match_clock_remaining_sec,
	}

func debug_advance_match_time(delta_sec: float) -> Dictionary:
	if _match_state == MATCH_STATE_IDLE:
		return {"success": false, "error": "match_inactive"}
	if _match_state != MATCH_STATE_FINAL:
		_match_clock_remaining_sec = maxf(_match_clock_remaining_sec - maxf(delta_sec, 0.0), 0.0)
		if _match_clock_remaining_sec <= 0.0:
			_end_match()
	_match_clock_tick_accumulator_sec = 0.0
	_refresh_scoreboard_state()
	_refresh_match_hud_state()
	return {
		"success": true,
		"match_state": _match_state,
		"match_clock_remaining_sec": _match_clock_remaining_sec,
	}

func _handle_unavailable_runtime(bound_ball_prop_id: String = "") -> void:
	_ball_bound = false
	_bound_ball_prop_id = bound_ball_prop_id
	_ambient_simulation_frozen = false
	_kickoff_surface_sync_ball_instance_id = 0
	_kickoff_surface_synced = false
	if _has_dirty_match_session():
		_reset_runtime_state()
	_refresh_scoreboard_state()
	_refresh_match_hud_state()

func _reset_runtime_state() -> void:
	_home_score = 0
	_away_score = 0
	_last_scored_side = ""
	_last_result_state = ""
	_set_game_state("idle", 0.0)
	_match_state = MATCH_STATE_IDLE
	_match_clock_remaining_sec = MATCH_DURATION_SEC
	_match_countdown_armed = false
	_match_clock_tick_accumulator_sec = 0.0
	_winner_side = ""
	_last_ai_touch_cooldown_sec = 0.0
	_clear_ai_possession()
	_clear_ai_touch_streaks()
	_kickoff_team_id = "home"
	_kickoff_protection_timer_sec = 0.0
	_pending_restart_team_id = ""
	_match_team_profiles.clear()
	_clear_goalkeeper_control()
	_match_rng.seed = 0
	_match_seed = 0
	_forced_match_seed = 0
	_ai_debug_state = {
		"kick_count": 0,
		"pass_count": 0,
		"last_touch_player_id": "",
		"last_touch_team_id": "",
		"last_touch_role_id": "",
		"last_touch_action_kind": "",
		"goalkeeper_distribution_count": 0,
		"last_distribution_player_id": "",
		"last_distribution_team_id": "",
		"last_distribution_role_id": "",
		"control_team_id": "",
		"control_player_id": "",
		"control_time_remaining_sec": 0.0,
		"kickoff_team_id": "",
		"kickoff_time_remaining_sec": 0.0,
		"goalkeeper_control_team_id": "",
		"goalkeeper_control_player_id": "",
		"goalkeeper_control_phase": "",
		"goalkeeper_control_time_remaining_sec": 0.0,
		"match_seed": 0,
	}
	_reset_match_player_states()

func _resolve_default_venue_id() -> String:
	var sorted_ids: Array[String] = []
	for venue_id_variant in _entries_by_venue_id.keys():
		sorted_ids.append(str(venue_id_variant))
	sorted_ids.sort()
	for venue_id in sorted_ids:
		var entry: Dictionary = (_entries_by_venue_id.get(venue_id, {}) as Dictionary).duplicate(true)
		if str(entry.get("game_kind", "")) == "soccer_pitch":
			return venue_id
	return sorted_ids[0] if not sorted_ids.is_empty() else ""

func _resolve_active_entry() -> Dictionary:
	if _active_venue_id == "":
		return {}
	return (_entries_by_venue_id.get(_active_venue_id, {}) as Dictionary).duplicate(true)

func _resolve_mounted_venue(chunk_renderer: Node, entry: Dictionary) -> Node3D:
	if chunk_renderer == null or not chunk_renderer.has_method("find_scene_minigame_venue_node"):
		return null
	var venue_id := str(entry.get("venue_id", "")).strip_edges()
	if venue_id == "":
		return null
	return chunk_renderer.find_scene_minigame_venue_node(venue_id) as Node3D

func _resolve_bound_ball(chunk_renderer: Node, entry: Dictionary) -> Node3D:
	_ball_bound = false
	_bound_ball_prop_id = str(entry.get("primary_ball_prop_id", "")).strip_edges()
	if _bound_ball_prop_id == "" or chunk_renderer == null or not chunk_renderer.has_method("find_scene_interactive_prop_node"):
		return null
	var ball_node := chunk_renderer.find_scene_interactive_prop_node(_bound_ball_prop_id) as Node3D
	_ball_bound = ball_node != null
	return ball_node

func _resolve_kickoff_anchor(entry: Dictionary, mounted_venue: Node3D) -> Vector3:
	if mounted_venue != null and mounted_venue.has_method("get_play_surface_contract"):
		var surface_contract: Dictionary = mounted_venue.get_play_surface_contract()
		var surface_kickoff_anchor_variant: Variant = surface_contract.get("kickoff_anchor", Vector3.ZERO)
		if surface_kickoff_anchor_variant is Vector3:
			return surface_kickoff_anchor_variant as Vector3
	var entry_kickoff_anchor_variant: Variant = entry.get("world_position", Vector3.ZERO)
	if entry_kickoff_anchor_variant is Vector3:
		return entry_kickoff_anchor_variant as Vector3
	return Vector3.ZERO

func _capture_kickoff_ball_offset(ball_node: Node3D, kickoff_anchor: Vector3) -> void:
	if ball_node == null or _has_kickoff_ball_offset:
		return
	var measured_offset := ball_node.global_position - kickoff_anchor
	var plausible_vertical_offset := measured_offset.y >= 0.2 and measured_offset.y <= 1.5
	var plausible_lateral_offset := absf(measured_offset.x) <= 0.16 and absf(measured_offset.z) <= 0.16
	_kickoff_ball_offset = measured_offset
	if not plausible_vertical_offset or not plausible_lateral_offset or _kickoff_ball_offset.length_squared() <= 0.0001:
		_kickoff_ball_offset = DEFAULT_BALL_CENTER_OFFSET
	_has_kickoff_ball_offset = true

func _refresh_kickoff_surface_sync_tracking(ball_node: Node3D) -> void:
	if ball_node == null or not is_instance_valid(ball_node):
		_kickoff_surface_sync_ball_instance_id = 0
		_kickoff_surface_synced = false
		return
	var instance_id := ball_node.get_instance_id()
	if _kickoff_surface_sync_ball_instance_id == instance_id:
		return
	_kickoff_surface_sync_ball_instance_id = instance_id
	_kickoff_surface_synced = false

func _maybe_sync_ball_to_kickoff_surface(ball_node: Node3D, kickoff_anchor: Vector3) -> void:
	if ball_node == null or _kickoff_surface_synced or _game_state != "idle":
		return
	var kickoff_ball_world_position := kickoff_anchor + _kickoff_ball_offset
	var ball_world_position := _get_ball_world_position(ball_node)
	var kickoff_lateral_distance_m := Vector2(
		ball_world_position.x - kickoff_ball_world_position.x,
		ball_world_position.z - kickoff_ball_world_position.z
	).length()
	var below_surface := ball_world_position.y < kickoff_ball_world_position.y - 0.18
	if below_surface and kickoff_lateral_distance_m <= 4.0:
		_perform_ball_reset(ball_node, kickoff_anchor)
		_set_game_state("idle", 0.0)
	_last_ball_world_position = _get_ball_world_position(ball_node)
	_kickoff_surface_synced = true

func _is_player_near_active_venue(entry: Dictionary, player_node: Node3D) -> bool:
	if player_node == null or not is_instance_valid(player_node):
		return false
	return player_node.global_position.distance_squared_to(_resolve_entry_world_position(entry)) <= ACTIVE_VENUE_SCAN_RADIUS_M * ACTIVE_VENUE_SCAN_RADIUS_M

func _update_ambient_freeze(player_node: Node3D, mounted_venue: Node3D) -> void:
	if player_node == null or not is_instance_valid(player_node) or mounted_venue == null:
		_ambient_simulation_frozen = false
		return
	var player_world_position := player_node.global_position
	var in_play := mounted_venue.has_method("is_world_point_in_play_bounds") and bool(mounted_venue.is_world_point_in_play_bounds(player_world_position))
	if in_play:
		_ambient_simulation_frozen = true
		return
	var in_release_bounds := mounted_venue.has_method("is_world_point_in_release_bounds") and bool(mounted_venue.is_world_point_in_release_bounds(player_world_position))
	if not in_release_bounds:
		_ambient_simulation_frozen = false

func _ensure_play_surface_collision_isolation(ball_node: Node3D, mounted_venue: Node3D) -> void:
	if ball_node == null or mounted_venue == null:
		return
	if not (ball_node is CollisionObject3D):
		return
	if not mounted_venue.has_method("get_play_surface_collision_layer_value"):
		return
	var collision_layer_value := int(mounted_venue.get_play_surface_collision_layer_value())
	if collision_layer_value <= 0:
		return
	var collision_object := ball_node as CollisionObject3D
	if collision_object.collision_layer != collision_layer_value:
		collision_object.collision_layer = collision_layer_value
	if collision_object.collision_mask != collision_layer_value:
		collision_object.collision_mask = collision_layer_value

func _advance_ball_game_state(mounted_venue: Node3D, ball_node: Node3D, ball_world_position: Vector3, ball_linear_velocity: Vector3, kickoff_anchor: Vector3, delta: float) -> void:
	match _game_state:
		"goal_scored":
			_state_timer_sec = maxf(_state_timer_sec - maxf(delta, 0.0), 0.0)
			if _state_timer_sec <= 0.0:
				_set_game_state("idle", 0.0)
		"out_of_bounds":
			_state_timer_sec = maxf(_state_timer_sec - maxf(delta, 0.0), 0.0)
			if _state_timer_sec <= 0.0:
				_set_game_state("idle", 0.0)
		_:
			if _match_state == MATCH_STATE_FINAL:
				return
			var goal_event := _resolve_goal_event(mounted_venue, ball_world_position, ball_linear_velocity)
			if not goal_event.is_empty():
				_apply_goal_event(goal_event)
				_perform_ball_reset(ball_node, kickoff_anchor)
				_arm_match_restart(_pending_restart_team_id)
			elif _is_ball_out_of_bounds(mounted_venue, ball_world_position):
				_last_result_state = "out_of_bounds"
				_perform_ball_reset(ball_node, kickoff_anchor)
				_arm_match_restart(_resolve_out_of_bounds_restart_team_id())
				_set_game_state("out_of_bounds", OUT_OF_BOUNDS_LINGER_SEC)
			elif _game_state == "idle" and _is_ball_in_play(ball_world_position, ball_linear_velocity, kickoff_anchor):
				_set_game_state("in_play", 0.0)
			elif _game_state == "in_play" and ball_linear_velocity.length() <= 0.01 and ball_world_position.distance_to(kickoff_anchor + _kickoff_ball_offset) <= 0.12:
				_set_game_state("idle", 0.0)

func _resolve_goal_event(mounted_venue: Node3D, ball_world_position: Vector3, ball_linear_velocity: Vector3) -> Dictionary:
	if mounted_venue == null or not mounted_venue.has_method("evaluate_goal_hit"):
		return {}
	var goal_event: Dictionary = mounted_venue.evaluate_goal_hit(ball_world_position, ball_linear_velocity)
	return goal_event.duplicate(true)

func _is_ball_out_of_bounds(mounted_venue: Node3D, ball_world_position: Vector3) -> bool:
	if mounted_venue == null or not mounted_venue.has_method("is_world_point_in_play_bounds"):
		return false
	return not bool(mounted_venue.is_world_point_in_play_bounds(ball_world_position))

func _is_ball_in_play(ball_world_position: Vector3, ball_linear_velocity: Vector3, kickoff_anchor: Vector3) -> bool:
	if ball_linear_velocity.length() >= IN_PLAY_SPEED_THRESHOLD_MPS:
		return true
	return ball_world_position.distance_to(kickoff_anchor + _kickoff_ball_offset) >= IN_PLAY_DISTANCE_THRESHOLD_M

func _apply_goal_event(goal_event: Dictionary) -> void:
	var scoring_side := str(goal_event.get("scoring_side", "")).strip_edges()
	if scoring_side == "home":
		_home_score += 1
		_pending_restart_team_id = "away"
	elif scoring_side == "away":
		_away_score += 1
		_pending_restart_team_id = "home"
	else:
		return
	_last_scored_side = scoring_side
	_last_result_state = "goal_scored"
	_set_game_state("goal_scored", GOAL_RESULT_LINGER_SEC)

func _perform_ball_reset(ball_node: Node3D, kickoff_anchor: Vector3) -> void:
	if ball_node == null:
		return
	var reset_position := kickoff_anchor + _kickoff_ball_offset
	ball_node.global_position = reset_position
	if ball_node is RigidBody3D:
		var rigid_ball := ball_node as RigidBody3D
		rigid_ball.linear_velocity = Vector3.ZERO
		rigid_ball.angular_velocity = Vector3.ZERO
		rigid_ball.sleeping = true
	_last_ball_world_position = reset_position

func _set_game_state(game_state: String, timer_sec: float) -> void:
	_game_state = game_state
	_state_timer_sec = maxf(timer_sec, 0.0)

func _refresh_scoreboard_state() -> void:
	_scoreboard_state = {
		"home_score": _home_score,
		"away_score": _away_score,
		"game_state": _game_state,
		"match_state": _match_state,
		"game_state_label": _build_game_state_label(),
		"last_scored_side": _last_scored_side,
		"winner_highlight_visible": _match_state == MATCH_STATE_FINAL and _winner_side != "",
		"winner_highlight_side": _winner_side if _match_state == MATCH_STATE_FINAL else "",
	}

func _sync_scoreboard_display(mounted_venue: Node3D) -> void:
	if mounted_venue == null or not mounted_venue.has_method("set_scoreboard_state"):
		return
	mounted_venue.set_scoreboard_state(_scoreboard_state.duplicate(true))

func _build_game_state_label() -> String:
	if _match_state == MATCH_STATE_FINAL:
		return "FINAL"
	match _game_state:
		"in_play":
			return "MATCH" if _match_state == MATCH_STATE_IN_PROGRESS else "IN PLAY"
		"goal_scored":
			if _last_scored_side == "home":
				return "GOAL HOME"
			if _last_scored_side == "away":
				return "GOAL AWAY"
			return "GOAL"
		"out_of_bounds":
			return "OUT"
		_:
			return "MATCH" if _match_state == MATCH_STATE_IN_PROGRESS else "READY"

func _refresh_match_hud_state() -> void:
	_match_hud_state = {
		"visible": _match_state != MATCH_STATE_IDLE,
		"match_state": _match_state,
		"home_score": _home_score,
		"away_score": _away_score,
		"home_team_color_id": "red",
		"away_team_color_id": "blue",
		"clock_text": _format_match_clock(_match_clock_remaining_sec),
		"winner_side": _winner_side,
	}

func _format_match_clock(seconds: float) -> String:
	var whole_seconds := maxi(ceili(maxf(seconds, 0.0)), 0)
	var minutes := int(floor(float(whole_seconds) / 60.0))
	var remaining_seconds := whole_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]

func _can_player_start_match(player_world_position: Vector3, mounted_venue: Node3D) -> bool:
	if mounted_venue == null or player_world_position == Vector3.INF:
		return false
	if mounted_venue.has_method("is_world_point_in_match_start_ring"):
		return bool(mounted_venue.is_world_point_in_match_start_ring(player_world_position))
	if mounted_venue.has_method("get_match_start_contract"):
		var start_contract: Dictionary = mounted_venue.get_match_start_contract()
		return player_world_position.distance_squared_to(start_contract.get("world_position", Vector3.ZERO)) <= pow(float(start_contract.get("trigger_radius_m", 0.0)), 2.0)
	return false

func _start_match(ball_node: Node3D, kickoff_anchor: Vector3) -> void:
	_home_score = 0
	_away_score = 0
	_last_scored_side = ""
	_last_result_state = ""
	_winner_side = ""
	_match_state = MATCH_STATE_IN_PROGRESS
	_match_clock_remaining_sec = MATCH_DURATION_SEC
	_match_countdown_armed = false
	_match_clock_tick_accumulator_sec = 0.0
	_last_ai_touch_cooldown_sec = 0.0
	_clear_ai_possession()
	_clear_ai_touch_streaks()
	_match_session_serial += 1
	_seed_match_rng()
	_match_team_profiles = _build_match_team_profiles(_match_session_serial)
	_kickoff_team_id = _resolve_match_opening_kickoff_team_id()
	_kickoff_protection_timer_sec = MATCH_AI_KICKOFF_PROTECTION_SEC
	_pending_restart_team_id = ""
	_clear_goalkeeper_control()
	_ai_debug_state = {
		"kick_count": 0,
		"pass_count": 0,
		"last_touch_player_id": "",
		"last_touch_team_id": "",
		"last_touch_role_id": "",
		"last_touch_action_kind": "",
		"goalkeeper_distribution_count": 0,
		"last_distribution_player_id": "",
		"last_distribution_team_id": "",
		"last_distribution_role_id": "",
		"control_team_id": "",
		"control_player_id": "",
		"control_time_remaining_sec": 0.0,
		"kickoff_team_id": _kickoff_team_id,
		"kickoff_time_remaining_sec": _kickoff_protection_timer_sec,
		"goalkeeper_control_team_id": "",
		"goalkeeper_control_player_id": "",
		"goalkeeper_control_phase": "",
		"goalkeeper_control_time_remaining_sec": 0.0,
		"match_seed": _match_seed,
	}
	_set_game_state("idle", 0.0)
	_reset_match_player_states()
	_perform_ball_reset(ball_node, kickoff_anchor)
	_sync_ai_control_debug_state()

func _perform_full_match_reset(ball_node: Node3D, kickoff_anchor: Vector3) -> void:
	_reset_runtime_state()
	_perform_ball_reset(ball_node, kickoff_anchor)

func _advance_match_clock(delta: float) -> void:
	if _match_state != MATCH_STATE_IN_PROGRESS:
		return
	if not _match_countdown_armed:
		_match_countdown_armed = true
		return
	_match_clock_tick_accumulator_sec += maxf(delta, 0.0)
	while _match_clock_tick_accumulator_sec >= 1.0 and _match_state == MATCH_STATE_IN_PROGRESS:
		_match_clock_tick_accumulator_sec -= 1.0
		_match_clock_remaining_sec = maxf(_match_clock_remaining_sec - 1.0, 0.0)
		if _match_clock_remaining_sec <= 0.0:
			_end_match()

func _end_match() -> void:
	_match_state = MATCH_STATE_FINAL
	_match_clock_remaining_sec = 0.0
	_match_countdown_armed = false
	_match_clock_tick_accumulator_sec = 0.0
	_winner_side = _resolve_winner_side()
	_clear_goalkeeper_control()
	_sync_ai_control_debug_state()
	_update_final_match_player_states()

func _resolve_winner_side() -> String:
	if _home_score > _away_score:
		return "home"
	if _away_score > _home_score:
		return "away"
	return ""

func _has_dirty_match_session() -> bool:
	return _match_state != MATCH_STATE_IDLE \
		or _winner_side != "" \
		or _home_score != 0 \
		or _away_score != 0 \
		or not is_equal_approx(_match_clock_remaining_sec, MATCH_DURATION_SEC)

func _ensure_match_roster(mounted_venue: Node3D) -> void:
	if mounted_venue == null or not mounted_venue.has_method("get_match_player_contracts"):
		return
	var roster_contracts: Array = mounted_venue.get_match_player_contracts()
	var roster_changed := roster_contracts.size() != _match_player_contracts.size()
	if not roster_changed:
		for contract_index in range(roster_contracts.size()):
			var incoming_contract: Dictionary = roster_contracts[contract_index]
			var existing_contract: Dictionary = _match_player_contracts[contract_index]
			if str(incoming_contract.get("player_id", "")) != str(existing_contract.get("player_id", "")):
				roster_changed = true
				break
	if roster_changed:
		_match_player_contracts = roster_contracts.duplicate(true)
		_reset_match_player_states()
	elif _match_player_states.size() != _match_player_contracts.size():
		_reset_match_player_states()

func _reset_match_player_states() -> void:
	_match_player_states.clear()
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		_match_player_states[str(player_contract.get("player_id", ""))] = _build_default_match_player_state(player_contract)

func _build_default_match_player_state(player_contract: Dictionary) -> Dictionary:
	var anchor_position: Vector3 = player_contract.get("local_anchor_position", Vector3.ZERO)
	return {
		"player_id": str(player_contract.get("player_id", "")),
		"team_id": str(player_contract.get("team_id", "")),
		"role_id": str(player_contract.get("role_id", "field_player")),
		"team_color_id": str(player_contract.get("team_color_id", "")),
		"local_position": anchor_position,
		"move_target": anchor_position,
		"world_position": anchor_position,
		"intent_kind": "hold_shape",
		"facing_direction": player_contract.get("idle_facing_direction", Vector3.FORWARD),
		"animation_state": "idle",
		"kick_requested": false,
		"stamina_norm": 1.0,
	}

func _update_idle_match_player_states() -> void:
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		var player_id := str(player_contract.get("player_id", ""))
		_match_player_states[player_id] = _build_default_match_player_state(player_contract)

func _update_final_match_player_states() -> void:
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		var player_id := str(player_contract.get("player_id", ""))
		var player_state: Dictionary = (_match_player_states.get(player_id, _build_default_match_player_state(player_contract)) as Dictionary).duplicate(true)
		var team_id := str(player_contract.get("team_id", ""))
		player_state["move_target"] = player_state.get("local_position", player_contract.get("local_anchor_position", Vector3.ZERO))
		player_state["world_position"] = player_state.get("local_position", player_contract.get("local_anchor_position", Vector3.ZERO))
		player_state["intent_kind"] = "final_idle"
		player_state["animation_state"] = "work" if _winner_side != "" and team_id == _winner_side else "idle"
		player_state["kick_requested"] = false
		_match_player_states[player_id] = player_state

func _advance_match_ai(ball_node: Node3D, mounted_venue: Node3D, delta: float) -> void:
	if mounted_venue == null or _match_player_contracts.is_empty():
		return
	_last_ai_touch_cooldown_sec = maxf(_last_ai_touch_cooldown_sec - maxf(delta, 0.0), 0.0)
	_ai_possession_timer_sec = maxf(_ai_possession_timer_sec - maxf(delta, 0.0), 0.0)
	_kickoff_protection_timer_sec = maxf(_kickoff_protection_timer_sec - maxf(delta, 0.0), 0.0)
	if _ai_possession_timer_sec <= 0.0:
		_clear_ai_possession()
	if _game_state == "goal_scored" or _game_state == "out_of_bounds":
		_clear_ai_possession()
		_sync_ai_control_debug_state()
		_reform_match_players_to_restart_shape()
		return
	var ball_local_position := mounted_venue.to_local(_get_ball_world_position(ball_node))
	var surface_size := _resolve_match_surface_size(mounted_venue)
	var team_role_plans := _resolve_team_role_plans(ball_local_position, surface_size)
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		var player_id := str(player_contract.get("player_id", ""))
		var team_id := str(player_contract.get("team_id", ""))
		var team_role_plan: Dictionary = team_role_plans.get(team_id, {})
		var intent_kind := _resolve_match_player_intent_kind(player_contract, team_role_plan)
		var player_state: Dictionary = (_match_player_states.get(player_id, _build_default_match_player_state(player_contract)) as Dictionary).duplicate(true)
		var player_profile := _resolve_match_player_profile(player_contract)
		var current_local_position: Vector3 = player_state.get("local_position", player_contract.get("local_anchor_position", Vector3.ZERO))
		var desired_local_position := _resolve_match_player_desired_local_position(player_contract, ball_local_position, surface_size, intent_kind)
		if player_id == str(_goalkeeper_control_state.get("player_id", "")):
			var goalkeeper_control_phase := str(_goalkeeper_control_state.get("phase", ""))
			if goalkeeper_control_phase == "secure" or goalkeeper_control_phase == "distribute":
				desired_local_position = current_local_position
		var next_stamina_norm := _resolve_next_match_player_stamina_norm(player_state, player_profile, intent_kind, delta)
		var speed_mps := _resolve_match_player_speed_mps(player_contract, player_profile, intent_kind, next_stamina_norm)
		var next_local_position := current_local_position.move_toward(desired_local_position, speed_mps * maxf(delta, 0.0))
		var facing_direction := desired_local_position - current_local_position
		if facing_direction.length_squared() <= 0.0001:
			facing_direction = ball_local_position - next_local_position
		facing_direction.y = 0.0
		if facing_direction.length_squared() <= 0.0001:
			facing_direction = player_contract.get("idle_facing_direction", Vector3.FORWARD)
		player_state["local_position"] = next_local_position
		player_state["move_target"] = desired_local_position
		player_state["world_position"] = mounted_venue.to_global(next_local_position)
		player_state["intent_kind"] = intent_kind
		player_state["facing_direction"] = facing_direction.normalized()
		player_state["animation_state"] = "run" if next_local_position.distance_to(current_local_position) > 0.03 else "idle"
		player_state["kick_requested"] = false
		player_state["stamina_norm"] = next_stamina_norm
		_match_player_states[player_id] = player_state
	_maybe_apply_ai_touch(ball_node, mounted_venue, ball_local_position, _get_ball_linear_velocity(ball_node), surface_size, delta)
	_sync_ai_control_debug_state()

func _hold_match_players_idle() -> void:
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		var player_id := str(player_contract.get("player_id", ""))
		var player_state: Dictionary = (_match_player_states.get(player_id, _build_default_match_player_state(player_contract)) as Dictionary).duplicate(true)
		player_state["move_target"] = player_state.get("local_position", player_contract.get("local_anchor_position", Vector3.ZERO))
		player_state["world_position"] = player_state.get("local_position", player_contract.get("local_anchor_position", Vector3.ZERO))
		player_state["intent_kind"] = "hold_shape"
		player_state["animation_state"] = "idle"
		player_state["kick_requested"] = false
		_match_player_states[player_id] = player_state

func _reform_match_players_to_restart_shape() -> void:
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		var player_id := str(player_contract.get("player_id", ""))
		var player_state := _build_default_match_player_state(player_contract)
		player_state["intent_kind"] = "hold_shape"
		player_state["animation_state"] = "idle"
		_match_player_states[player_id] = player_state

func _resolve_match_player_profile(player_contract: Dictionary) -> Dictionary:
	var role_id := str(player_contract.get("role_id", "field_player"))
	var team_id := str(player_contract.get("team_id", "home"))
	var lane_index := int(player_contract.get("lane_index", 0))
	var anchor_position: Vector3 = player_contract.get("local_anchor_position", Vector3.ZERO)
	var lateral_bias := clampf(signf(anchor_position.x) * 0.36, -0.36, 0.36)
	if role_id == "goalkeeper":
		return _apply_match_player_personality(player_contract, _finalize_match_player_profile(team_id, {
			"cruise_speed_mps": 8.9,
			"sprint_bonus_mps": 1.55,
			"touch_radius_m": MATCH_AI_TOUCH_RADIUS_M + 0.42,
			"kick_speed_scale": 1.08,
			"shot_bias_x": 0.0,
			"carry_bias_x": 0.0,
			"ball_security_bias": 0.02,
			"tackle_bias": 0.0,
			"keeper_claim_bias": 0.24,
			"pass_bias": 0.0,
			"pass_speed_scale": 1.0,
			"stamina_recovery_per_sec": 0.22,
			"stamina_drain_run_per_sec": 0.12,
			"stamina_drain_press_per_sec": 0.2,
		}))
	match lane_index:
		1:
			return _apply_match_player_personality(player_contract, _finalize_match_player_profile(team_id, {
				"cruise_speed_mps": 9.0,
				"sprint_bonus_mps": 1.9,
				"touch_radius_m": MATCH_AI_TOUCH_RADIUS_M - 0.05,
				"kick_speed_scale": 0.97,
				"shot_bias_x": -0.34,
				"carry_bias_x": -0.9,
				"ball_security_bias": 0.04,
				"tackle_bias": 0.16,
				"pass_bias": 0.18,
				"pass_speed_scale": 1.03,
				"stamina_recovery_per_sec": 0.18,
				"stamina_drain_run_per_sec": 0.2,
				"stamina_drain_press_per_sec": 0.3,
			}))
		2:
			return _apply_match_player_personality(player_contract, _finalize_match_player_profile(team_id, {
				"cruise_speed_mps": 8.95,
				"sprint_bonus_mps": 1.8,
				"touch_radius_m": MATCH_AI_TOUCH_RADIUS_M,
				"kick_speed_scale": 0.99,
				"shot_bias_x": 0.28,
				"carry_bias_x": 0.72,
				"ball_security_bias": 0.06,
				"tackle_bias": 0.11,
				"pass_bias": 0.16,
				"pass_speed_scale": 1.02,
				"stamina_recovery_per_sec": 0.19,
				"stamina_drain_run_per_sec": 0.19,
				"stamina_drain_press_per_sec": 0.28,
			}))
		3:
			return _apply_match_player_personality(player_contract, _finalize_match_player_profile(team_id, {
				"cruise_speed_mps": 8.7,
				"sprint_bonus_mps": 1.45,
				"touch_radius_m": MATCH_AI_TOUCH_RADIUS_M + 0.16,
				"kick_speed_scale": 1.01,
				"shot_bias_x": lateral_bias * 0.5,
				"carry_bias_x": lateral_bias * 1.6,
				"ball_security_bias": 0.09,
				"tackle_bias": 0.08,
				"pass_bias": 0.12,
				"pass_speed_scale": 1.0,
				"stamina_recovery_per_sec": 0.21,
				"stamina_drain_run_per_sec": 0.16,
				"stamina_drain_press_per_sec": 0.25,
			}))
		4:
			return _apply_match_player_personality(player_contract, _finalize_match_player_profile(team_id, {
				"cruise_speed_mps": 9.15,
				"sprint_bonus_mps": 2.05,
				"touch_radius_m": MATCH_AI_TOUCH_RADIUS_M + 0.22,
				"kick_speed_scale": 0.94,
				"shot_bias_x": lateral_bias * 0.75,
				"carry_bias_x": lateral_bias * 1.4,
				"ball_security_bias": 0.16,
				"tackle_bias": 0.03,
				"pass_bias": 0.06,
				"pass_speed_scale": 0.98,
				"stamina_recovery_per_sec": 0.15,
				"stamina_drain_run_per_sec": 0.25,
				"stamina_drain_press_per_sec": 0.37,
			}))
	return _apply_match_player_personality(player_contract, _finalize_match_player_profile(team_id, {
		"cruise_speed_mps": 8.8,
		"sprint_bonus_mps": 1.6,
		"touch_radius_m": MATCH_AI_TOUCH_RADIUS_M,
		"kick_speed_scale": 1.0,
		"shot_bias_x": lateral_bias * 0.5,
		"carry_bias_x": lateral_bias,
		"ball_security_bias": 0.08,
		"tackle_bias": 0.08,
		"pass_bias": 0.1,
		"pass_speed_scale": 1.0,
		"stamina_recovery_per_sec": 0.2,
		"stamina_drain_run_per_sec": 0.18,
		"stamina_drain_press_per_sec": 0.27,
	}))

func _finalize_match_player_profile(team_id: String, base_profile: Dictionary) -> Dictionary:
	var team_profile: Dictionary = _match_team_profiles.get(team_id, {})
	var build_up_scale := float(team_profile.get("build_up_scale", 1.0))
	var shot_scale := float(team_profile.get("shot_scale", 1.0))
	var press_scale := float(team_profile.get("press_scale", 1.0))
	var profile := base_profile.duplicate(true)
	profile["cruise_speed_mps"] = float(profile.get("cruise_speed_mps", 8.8)) * build_up_scale
	profile["sprint_bonus_mps"] = float(profile.get("sprint_bonus_mps", 1.6)) * press_scale
	profile["kick_speed_scale"] = float(profile.get("kick_speed_scale", 1.0)) * shot_scale
	return profile

func _apply_match_player_personality(player_contract: Dictionary, profile: Dictionary) -> Dictionary:
	var player_id := str(player_contract.get("player_id", ""))
	var role_id := str(player_contract.get("role_id", "field_player"))
	var personality_seed_source := "%d:%s:%s" % [_match_seed, _active_venue_id, player_id]
	var personality_rng := RandomNumberGenerator.new()
	personality_rng.seed = personality_seed_source.hash()
	var personalized_profile := profile.duplicate(true)
	personalized_profile["ball_security_bias"] = float(personalized_profile.get("ball_security_bias", 0.0)) + personality_rng.randf_range(-0.035, 0.045)
	personalized_profile["tackle_bias"] = float(personalized_profile.get("tackle_bias", 0.0)) + personality_rng.randf_range(-0.04, 0.04)
	personalized_profile["pass_bias"] = float(personalized_profile.get("pass_bias", 0.0)) + personality_rng.randf_range(-0.06, 0.06)
	personalized_profile["pass_speed_scale"] = float(personalized_profile.get("pass_speed_scale", 1.0)) + personality_rng.randf_range(-0.035, 0.035)
	if role_id == "goalkeeper":
		personalized_profile["keeper_claim_bias"] = float(personalized_profile.get("keeper_claim_bias", 0.0)) + personality_rng.randf_range(-0.035, 0.035)
	return personalized_profile

func _resolve_next_match_player_stamina_norm(player_state: Dictionary, player_profile: Dictionary, intent_kind: String, delta: float) -> float:
	var stamina_norm := clampf(float(player_state.get("stamina_norm", 1.0)), 0.18, 1.0)
	var recovery_rate := float(player_profile.get("stamina_recovery_per_sec", 0.18))
	var run_drain_rate := float(player_profile.get("stamina_drain_run_per_sec", 0.18))
	var press_drain_rate := float(player_profile.get("stamina_drain_press_per_sec", 0.28))
	if intent_kind == "hold_shape" or intent_kind == "goal_guard" or intent_kind == "goalkeeper_secure_ball" or intent_kind == "final_idle":
		return minf(stamina_norm + recovery_rate * maxf(delta, 0.0), 1.0)
	var drain_rate := run_drain_rate
	if intent_kind == "press_ball" or intent_kind == "goalkeeper_intercept" or intent_kind == "goalkeeper_distribute_ball" or intent_kind == "kick_ball":
		drain_rate = press_drain_rate
	return maxf(stamina_norm - drain_rate * maxf(delta, 0.0), 0.18)

func _resolve_match_player_speed_mps(player_contract: Dictionary, player_profile: Dictionary, intent_kind: String, stamina_norm: float) -> float:
	var cruise_speed_mps := float(player_profile.get("cruise_speed_mps", MATCH_FIELD_PLAYER_SPEED_MPS))
	var sprint_bonus_mps := float(player_profile.get("sprint_bonus_mps", 1.6)) * clampf((stamina_norm - 0.18) / 0.82, 0.0, 1.0)
	var role_id := str(player_contract.get("role_id", "field_player"))
	if role_id == "goalkeeper":
		cruise_speed_mps = maxf(cruise_speed_mps, MATCH_GOALKEEPER_SPEED_MPS - 1.7)
	if intent_kind == "press_ball" or intent_kind == "goalkeeper_intercept" or intent_kind == "kick_ball":
		return cruise_speed_mps + sprint_bonus_mps
	if intent_kind == "support_run":
		return cruise_speed_mps + sprint_bonus_mps * 0.82
	if intent_kind == "collapse_defense":
		return cruise_speed_mps + sprint_bonus_mps * 0.56
	return cruise_speed_mps

func _resolve_match_player_desired_local_position(player_contract: Dictionary, ball_local_position: Vector3, surface_size: Vector3, intent_kind: String) -> Vector3:
	var anchor_position: Vector3 = player_contract.get("local_anchor_position", Vector3.ZERO)
	var team_id := str(player_contract.get("team_id", "home"))
	var role_id := str(player_contract.get("role_id", "field_player"))
	var lane_index := int(player_contract.get("lane_index", 0))
	var attack_direction_z := _get_attack_direction_z(team_id)
	var team_has_live_possession := _ai_possession_team_id == team_id and _ai_possession_timer_sec > 0.0
	var half_width := surface_size.x * 0.5 - MATCH_PLAYER_FIELD_MARGIN_M
	var half_length := surface_size.z * 0.5 - MATCH_PLAYER_FIELD_MARGIN_M
	if role_id == "goalkeeper":
		if intent_kind == "goalkeeper_intercept":
			var chase_target := ball_local_position + Vector3(0.0, 0.0, -attack_direction_z * 0.75)
			return _clamp_match_local_position(chase_target, half_width, half_length)
		var defend_z := half_length if team_id == "home" else -half_length
		var desired_goalkeeper_position := Vector3(
			clampf(ball_local_position.x * 0.42, -MATCH_GOAL_WIDTH_FALLBACK_M * 0.6, MATCH_GOAL_WIDTH_FALLBACK_M * 0.6),
			0.0,
			defend_z + clampf(ball_local_position.z - defend_z, -3.6, 3.6)
		)
		return _clamp_match_local_position(desired_goalkeeper_position, half_width, half_length)
	if intent_kind == "press_ball":
		var chase_offset_z := attack_direction_z * 1.75 if team_has_live_possession else -attack_direction_z * 0.85
		var chase_target := ball_local_position + Vector3(clampf((float(lane_index) - 2.5) * 0.45, -0.75, 0.75), 0.0, chase_offset_z)
		return _clamp_match_local_position(chase_target, half_width, half_length)
	if intent_kind == "collapse_defense":
		var fallback_z := half_length - 10.0 if team_id == "home" else -half_length + 10.0
		var collapse_target := Vector3(
			clampf(ball_local_position.x * 0.72, -half_width * 0.78, half_width * 0.78),
			0.0,
			lerpf(ball_local_position.z, fallback_z, 0.58)
		)
		return _clamp_match_local_position(collapse_target, half_width, half_length)
	var support_depth_m := 13.0 if intent_kind == "support_run" else 6.0
	var support_direction_z := attack_direction_z if team_has_live_possession or _resolve_team_ball_zone(team_id, ball_local_position) == "attacking" else -attack_direction_z
	var support_target := ball_local_position + Vector3((float(lane_index) - 2.0) * 3.0, 0.0, -attack_direction_z * support_depth_m)
	support_target.z = ball_local_position.z + support_direction_z * support_depth_m
	var press_factor := 0.34
	if intent_kind == "support_run":
		press_factor = 0.62
	elif anchor_position.distance_to(ball_local_position) <= 24.0:
		press_factor = 0.52
	elif _resolve_team_ball_zone(team_id, ball_local_position) == "defensive":
		press_factor = 0.44
	var desired_position := anchor_position.lerp(support_target, press_factor)
	return _clamp_match_local_position(desired_position, half_width, half_length)

func _clamp_match_local_position(local_position: Vector3, half_width: float, half_length: float) -> Vector3:
	return Vector3(
		clampf(local_position.x, -half_width, half_width),
		0.0,
		clampf(local_position.z, -half_length, half_length)
	)

func _is_ball_on_team_defensive_half(team_id: String, ball_local_position: Vector3) -> bool:
	if team_id == "home":
		return ball_local_position.z >= 0.0
	return ball_local_position.z <= 0.0

func _get_attack_direction_z(team_id: String) -> float:
	return -1.0 if team_id == "home" else 1.0

func _resolve_team_role_plans(ball_local_position: Vector3, surface_size: Vector3) -> Dictionary:
	return {
		"home": _build_team_role_plan("home", ball_local_position, surface_size),
		"away": _build_team_role_plan("away", ball_local_position, surface_size),
	}

func _build_team_role_plan(team_id: String, ball_local_position: Vector3, surface_size: Vector3) -> Dictionary:
	var goalkeeper_id := ""
	var closest_field_id := ""
	var second_field_id := ""
	var third_field_id := ""
	var closest_field_distance_m := INF
	var second_field_distance_m := INF
	var third_field_distance_m := INF
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		if str(player_contract.get("team_id", "")) != team_id:
			continue
		var player_id := str(player_contract.get("player_id", ""))
		var role_id := str(player_contract.get("role_id", "field_player"))
		if role_id == "goalkeeper":
			goalkeeper_id = player_id
			continue
		var player_state: Dictionary = _match_player_states.get(player_id, {})
		var player_local_position: Vector3 = player_state.get("local_position", player_contract.get("local_anchor_position", Vector3.ZERO))
		var lateral_distance_m := Vector2(
			player_local_position.x - ball_local_position.x,
			player_local_position.z - ball_local_position.z
		).length()
		if lateral_distance_m < closest_field_distance_m:
			third_field_distance_m = second_field_distance_m
			third_field_id = second_field_id
			second_field_distance_m = closest_field_distance_m
			second_field_id = closest_field_id
			closest_field_distance_m = lateral_distance_m
			closest_field_id = player_id
		elif lateral_distance_m < second_field_distance_m:
			third_field_distance_m = second_field_distance_m
			third_field_id = second_field_id
			second_field_distance_m = lateral_distance_m
			second_field_id = player_id
		elif lateral_distance_m < third_field_distance_m:
			third_field_distance_m = lateral_distance_m
			third_field_id = player_id
	var team_ball_zone := _resolve_team_ball_zone(team_id, ball_local_position)
	var goalkeeper_intercept := goalkeeper_id != "" and _should_goalkeeper_chase_ball(team_id, ball_local_position, surface_size)
	var primary_press_id := closest_field_id
	var support_runner_id := second_field_id
	var collapse_defense_id := third_field_id if team_ball_zone == "defensive" else ""
	if _kickoff_protection_timer_sec > 0.0:
		var restart_taker_id := _resolve_team_restart_taker_id(team_id)
		if team_id == _kickoff_team_id:
			primary_press_id = restart_taker_id
			support_runner_id = second_field_id if second_field_id != restart_taker_id else ""
			collapse_defense_id = ""
		else:
			primary_press_id = ""
			support_runner_id = ""
			collapse_defense_id = ""
	if goalkeeper_intercept:
		primary_press_id = goalkeeper_id
		if collapse_defense_id == "":
			collapse_defense_id = second_field_id if second_field_id != "" else closest_field_id
	return {
		"goalkeeper_id": goalkeeper_id,
		"goalkeeper_intercept": goalkeeper_intercept,
		"primary_press_id": primary_press_id,
		"support_runner_id": support_runner_id,
		"collapse_defense_id": collapse_defense_id,
		"ball_zone": team_ball_zone,
		"restart_taker_id": _resolve_team_restart_taker_id(team_id),
	}

func _resolve_match_player_intent_kind(player_contract: Dictionary, team_role_plan: Dictionary) -> String:
	var player_id := str(player_contract.get("player_id", ""))
	var role_id := str(player_contract.get("role_id", "field_player"))
	if role_id == "goalkeeper":
		if str(_goalkeeper_control_state.get("player_id", "")) == player_id:
			var goalkeeper_control_phase := str(_goalkeeper_control_state.get("phase", ""))
			if goalkeeper_control_phase == "secure":
				return "goalkeeper_secure_ball"
			if goalkeeper_control_phase == "distribute":
				return "goalkeeper_distribute_ball"
		if bool(team_role_plan.get("goalkeeper_intercept", false)) and str(team_role_plan.get("goalkeeper_id", "")) == player_id:
			return "goalkeeper_intercept"
		return "goal_guard"
	if str(team_role_plan.get("primary_press_id", "")) == player_id:
		return "press_ball"
	if str(team_role_plan.get("collapse_defense_id", "")) == player_id:
		return "collapse_defense"
	if str(team_role_plan.get("support_runner_id", "")) == player_id:
		return "support_run"
	return "hold_shape"

func _should_goalkeeper_chase_ball(team_id: String, ball_local_position: Vector3, surface_size: Vector3) -> bool:
	var half_length := surface_size.z * 0.5
	var defensive_gate_z := half_length - 26.0
	var lateral_gate_x := MATCH_GOAL_WIDTH_FALLBACK_M * 1.9
	if team_id == "home":
		return ball_local_position.z >= defensive_gate_z and absf(ball_local_position.x) <= lateral_gate_x
	return ball_local_position.z <= -defensive_gate_z and absf(ball_local_position.x) <= lateral_gate_x

func _maybe_apply_ai_touch(ball_node: Node3D, mounted_venue: Node3D, ball_local_position: Vector3, ball_linear_velocity: Vector3, surface_size: Vector3, delta: float) -> void:
	if _last_ai_touch_cooldown_sec > 0.0:
		return
	if _advance_goalkeeper_ball_control(ball_node, mounted_venue, delta):
		return
	var best_candidates_by_team := {
		"home": {},
		"away": {},
	}
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		var player_id := str(player_contract.get("player_id", ""))
		var player_state: Dictionary = _match_player_states.get(player_id, {})
		var player_local_position: Vector3 = player_state.get("local_position", player_contract.get("local_anchor_position", Vector3.ZERO))
		var player_profile := _resolve_match_player_profile(player_contract)
		var lateral_distance_m := Vector2(
			player_local_position.x - ball_local_position.x,
			player_local_position.z - ball_local_position.z
		).length()
		var team_id := str(player_contract.get("team_id", ""))
		var existing_candidate: Dictionary = best_candidates_by_team.get(team_id, {})
		if existing_candidate.is_empty() or lateral_distance_m < float(existing_candidate.get("distance_m", INF)):
			best_candidates_by_team[team_id] = {
				"player_contract": player_contract.duplicate(true),
				"player_state": player_state.duplicate(true),
				"player_profile": player_profile.duplicate(true),
				"distance_m": lateral_distance_m,
				"touch_radius_m": float(player_profile.get("touch_radius_m", MATCH_AI_TOUCH_RADIUS_M)),
			}
	var selected_candidate := _resolve_best_ai_touch_candidate(best_candidates_by_team, ball_local_position)
	if selected_candidate.is_empty():
		return
	if _candidate_should_goalkeeper_secure_ball(selected_candidate, ball_local_position, ball_linear_velocity, surface_size):
		_begin_goalkeeper_ball_control(ball_node, mounted_venue, selected_candidate)
		return
	_apply_ai_touch(
		ball_node,
		mounted_venue,
		selected_candidate.get("player_contract", {}),
		selected_candidate.get("player_state", {}),
		selected_candidate.get("player_profile", {}),
		ball_local_position
	)

func _advance_goalkeeper_ball_control(ball_node: Node3D, mounted_venue: Node3D, delta: float) -> bool:
	var goalkeeper_player_id := str(_goalkeeper_control_state.get("player_id", ""))
	var goalkeeper_control_phase := str(_goalkeeper_control_state.get("phase", ""))
	if goalkeeper_player_id == "" or goalkeeper_control_phase == "":
		return false
	var player_contract := _find_match_player_contract(goalkeeper_player_id)
	if player_contract.is_empty():
		_clear_goalkeeper_control()
		_sync_ai_control_debug_state()
		return false
	var player_state: Dictionary = (_match_player_states.get(goalkeeper_player_id, _build_default_match_player_state(player_contract)) as Dictionary).duplicate(true)
	var team_id := str(player_contract.get("team_id", "home"))
	_sync_goalkeeper_controlled_ball(ball_node, mounted_venue, player_state, team_id)
	if goalkeeper_control_phase == "secure":
		var remaining_timer_sec := maxf(float(_goalkeeper_control_state.get("timer_sec", 0.0)) - maxf(delta, 0.0), 0.0)
		_goalkeeper_control_state["timer_sec"] = remaining_timer_sec
		if remaining_timer_sec <= 0.0:
			_goalkeeper_control_state["phase"] = "distribute"
			_goalkeeper_control_state["timer_sec"] = MATCH_GOALKEEPER_DISTRIBUTION_WINDUP_SEC
		_sync_ai_control_debug_state()
		return true
	if goalkeeper_control_phase == "distribute":
		var distribute_timer_sec := maxf(float(_goalkeeper_control_state.get("timer_sec", 0.0)) - maxf(delta, 0.0), 0.0)
		_goalkeeper_control_state["timer_sec"] = distribute_timer_sec
		if distribute_timer_sec > 0.0:
			_sync_ai_control_debug_state()
			return true
		var player_profile := _resolve_match_player_profile(player_contract)
		_apply_goalkeeper_distribution(ball_node, mounted_venue, player_contract, player_state, player_profile)
		_clear_goalkeeper_control()
		_sync_ai_control_debug_state()
		return true
	_clear_goalkeeper_control()
	_sync_ai_control_debug_state()
	return false

func _candidate_should_goalkeeper_secure_ball(candidate: Dictionary, ball_local_position: Vector3, ball_linear_velocity: Vector3, surface_size: Vector3) -> bool:
	if candidate.is_empty():
		return false
	var player_contract: Dictionary = candidate.get("player_contract", {})
	var player_state: Dictionary = candidate.get("player_state", {})
	var player_profile: Dictionary = candidate.get("player_profile", {})
	var team_id := str(player_contract.get("team_id", "home"))
	if str(player_contract.get("role_id", "field_player")) != "goalkeeper":
		return false
	if str(player_state.get("intent_kind", "")) != "goalkeeper_intercept":
		return false
	if ball_linear_velocity.length() > MATCH_GOALKEEPER_SECURE_BALL_SPEED_MAX_MPS:
		return false
	var goal_approach_speed_mps := ball_linear_velocity.z if team_id == "home" else -ball_linear_velocity.z
	if ball_linear_velocity.length() > 2.0 and goal_approach_speed_mps < 0.75:
		return false
	var secure_touch_radius := minf(float(candidate.get("touch_radius_m", MATCH_AI_TOUCH_RADIUS_M)), MATCH_GOALKEEPER_SECURE_TOUCH_RADIUS_M)
	if float(candidate.get("distance_m", INF)) > secure_touch_radius:
		return false
	if ball_local_position.y > 2.0:
		return false
	if not _is_ball_in_goalkeeper_secure_zone(team_id, ball_local_position, surface_size, ball_linear_velocity.length()):
		return false
	var stamina_norm := clampf(float(player_state.get("stamina_norm", 1.0)), 0.18, 1.0)
	var distance_factor := 1.0 - clampf(float(candidate.get("distance_m", INF)) / secure_touch_radius, 0.0, 1.0)
	var centrality_factor := 1.0 - clampf(absf(ball_local_position.x) / (MATCH_GOAL_WIDTH_FALLBACK_M * 1.28), 0.0, 1.0)
	var speed_factor := 1.0 - clampf(ball_linear_velocity.length() / MATCH_GOALKEEPER_SECURE_BALL_SPEED_MAX_MPS, 0.0, 1.0)
	var claim_probability := 0.22 \
		+ float(player_profile.get("keeper_claim_bias", 0.0)) \
		+ distance_factor * 0.28 \
		+ centrality_factor * 0.18 \
		+ speed_factor * 0.12 \
		+ (stamina_norm - 0.55) * 0.18
	var is_clear_live_claim := ball_linear_velocity.length() >= 4.0 \
		and goal_approach_speed_mps >= 2.4 \
		and distance_factor >= 0.42 \
		and centrality_factor >= 0.86
	if is_clear_live_claim and float(candidate.get("distance_m", INF)) <= secure_touch_radius * 0.84:
		return true
	if is_clear_live_claim:
		claim_probability = maxf(claim_probability, 0.9 + (stamina_norm - 0.55) * 0.05)
	if ball_linear_velocity.length() <= 2.0:
		claim_probability = maxf(claim_probability, 0.88)
	return _roll_match_chance(clampf(claim_probability, 0.2, 0.93))

func _is_ball_in_goalkeeper_secure_zone(team_id: String, ball_local_position: Vector3, surface_size: Vector3, ball_speed_mps: float) -> bool:
	var half_length := surface_size.z * 0.5
	var moving_attack := ball_speed_mps > 5.5
	var secure_gate_z := half_length - (14.5 if moving_attack else 21.0)
	var lateral_gate_x := MATCH_GOAL_WIDTH_FALLBACK_M * (1.08 if moving_attack else 1.28)
	if team_id == "home":
		return ball_local_position.z >= secure_gate_z and absf(ball_local_position.x) <= lateral_gate_x
	return ball_local_position.z <= -secure_gate_z and absf(ball_local_position.x) <= lateral_gate_x

func _begin_goalkeeper_ball_control(ball_node: Node3D, mounted_venue: Node3D, candidate: Dictionary) -> void:
	var player_contract: Dictionary = candidate.get("player_contract", {})
	var player_state: Dictionary = candidate.get("player_state", {})
	var player_id := str(player_contract.get("player_id", ""))
	if player_id == "":
		return
	var team_id := str(player_contract.get("team_id", "home"))
	var secured_state := player_state.duplicate(true)
	secured_state["intent_kind"] = "goalkeeper_secure_ball"
	secured_state["move_target"] = secured_state.get("local_position", player_contract.get("local_anchor_position", Vector3.ZERO))
	secured_state["animation_state"] = "work"
	secured_state["kick_requested"] = false
	secured_state["facing_direction"] = Vector3(0.0, 0.0, _get_attack_direction_z(team_id))
	_match_player_states[player_id] = secured_state
	_goalkeeper_control_state = {
		"team_id": team_id,
		"player_id": player_id,
		"phase": "secure",
		"timer_sec": MATCH_GOALKEEPER_SECURE_HOLD_SEC,
	}
	_ai_possession_team_id = team_id
	_ai_possession_player_id = player_id
	_ai_possession_timer_sec = MATCH_GOALKEEPER_SECURE_HOLD_SEC + 0.35
	_record_ai_touch(team_id, player_id, "secure_ball")
	_ai_debug_state["last_touch_player_id"] = player_id
	_ai_debug_state["last_touch_team_id"] = team_id
	_ai_debug_state["last_touch_role_id"] = "goalkeeper"
	_set_game_state("in_play", 0.0)
	_sync_goalkeeper_controlled_ball(ball_node, mounted_venue, secured_state, team_id)
	_sync_ai_control_debug_state()

func _sync_goalkeeper_controlled_ball(ball_node: Node3D, mounted_venue: Node3D, player_state: Dictionary, team_id: String) -> void:
	if ball_node == null or mounted_venue == null:
		return
	var player_local_position: Vector3 = player_state.get("local_position", Vector3.ZERO)
	var controlled_ball_world_position := mounted_venue.to_global(
		player_local_position + Vector3(0.0, MATCH_GOALKEEPER_CONTROL_BALL_HEIGHT_M, _get_attack_direction_z(team_id) * 0.26)
	)
	ball_node.global_position = controlled_ball_world_position
	if ball_node is RigidBody3D:
		var rigid_ball := ball_node as RigidBody3D
		rigid_ball.linear_velocity = Vector3.ZERO
		rigid_ball.angular_velocity = Vector3.ZERO
		rigid_ball.sleeping = false
	_last_ball_world_position = controlled_ball_world_position

func _apply_goalkeeper_distribution(ball_node: Node3D, mounted_venue: Node3D, player_contract: Dictionary, player_state: Dictionary, player_profile: Dictionary) -> void:
	if ball_node == null or mounted_venue == null or not (ball_node is RigidBody3D):
		return
	var team_id := str(player_contract.get("team_id", "home"))
	var player_id := str(player_contract.get("player_id", ""))
	var ball_local_position := mounted_venue.to_local(_get_ball_world_position(ball_node))
	var distribution_target := _resolve_goalkeeper_distribution_target(player_contract, player_profile, ball_local_position, _resolve_match_surface_size(mounted_venue))
	var distribution_direction := distribution_target - ball_local_position
	distribution_direction.y = 0.0
	if distribution_direction.length_squared() <= 0.0001:
		distribution_direction = Vector3(0.0, 0.0, _get_attack_direction_z(team_id))
	distribution_direction = distribution_direction.normalized()
	var kick_speed_scale := clampf(float(player_profile.get("kick_speed_scale", 1.0)), 0.94, 1.08)
	var rigid_ball := ball_node as RigidBody3D
	rigid_ball.linear_velocity = distribution_direction * MATCH_GOALKEEPER_DISTRIBUTION_SPEED_MPS * kick_speed_scale + Vector3.UP * MATCH_GOALKEEPER_DISTRIBUTION_LIFT_MPS
	rigid_ball.angular_velocity = Vector3.ZERO
	rigid_ball.sleeping = false
	var distributed_state := player_state.duplicate(true)
	distributed_state["intent_kind"] = "goalkeeper_distribute_ball"
	distributed_state["animation_state"] = "work"
	distributed_state["kick_requested"] = true
	distributed_state["facing_direction"] = distribution_direction
	distributed_state["stamina_norm"] = maxf(float(distributed_state.get("stamina_norm", 1.0)) - 0.03, 0.18)
	_match_player_states[player_id] = distributed_state
	_last_ai_touch_cooldown_sec = MATCH_GOALKEEPER_DISTRIBUTION_TOUCH_COOLDOWN_SEC
	_ai_possession_team_id = team_id
	_ai_possession_player_id = player_id
	_ai_possession_timer_sec = 0.42
	_record_ai_touch(team_id, player_id, "distribute_ball")
	_ai_debug_state["kick_count"] = int(_ai_debug_state.get("kick_count", 0)) + 1
	_ai_debug_state["last_touch_player_id"] = player_id
	_ai_debug_state["last_touch_team_id"] = team_id
	_ai_debug_state["last_touch_role_id"] = "goalkeeper"
	_ai_debug_state["goalkeeper_distribution_count"] = int(_ai_debug_state.get("goalkeeper_distribution_count", 0)) + 1
	_ai_debug_state["last_distribution_player_id"] = player_id
	_ai_debug_state["last_distribution_team_id"] = team_id
	_ai_debug_state["last_distribution_role_id"] = "goalkeeper"
	_set_game_state("in_play", 0.0)
	_last_ball_world_position = _get_ball_world_position(ball_node)

func _resolve_goalkeeper_distribution_target(player_contract: Dictionary, player_profile: Dictionary, ball_local_position: Vector3, surface_size: Vector3) -> Vector3:
	var team_id := str(player_contract.get("team_id", "home"))
	var half_width := surface_size.x * 0.5 - MATCH_PLAYER_FIELD_MARGIN_M
	var half_length := surface_size.z * 0.5 - MATCH_PLAYER_FIELD_MARGIN_M
	var carry_bias_x := float(player_profile.get("carry_bias_x", 0.0))
	var target_z := clampf(
		ball_local_position.z + _get_attack_direction_z(team_id) * MATCH_GOALKEEPER_DISTRIBUTION_ADVANCE_M,
		-half_length * 0.24,
		half_length * 0.24
	)
	return Vector3(
		clampf(ball_local_position.x * 0.35 + carry_bias_x * 3.8, -half_width * 0.58, half_width * 0.58),
		0.0,
		target_z
	)

func _resolve_best_ai_touch_candidate(best_candidates_by_team: Dictionary, ball_local_position: Vector3) -> Dictionary:
	var home_candidate: Dictionary = best_candidates_by_team.get("home", {})
	var away_candidate: Dictionary = best_candidates_by_team.get("away", {})
	if _kickoff_protection_timer_sec > 0.0:
		var kickoff_candidate: Dictionary = best_candidates_by_team.get(_kickoff_team_id, {})
		if _candidate_can_touch(kickoff_candidate):
			return kickoff_candidate
	if _ai_possession_team_id != "" and _ai_possession_timer_sec > 0.0:
		var possession_candidate: Dictionary = best_candidates_by_team.get(_ai_possession_team_id, {})
		var challenger_team_id := "away" if _ai_possession_team_id == "home" else "home"
		var challenger_candidate: Dictionary = best_candidates_by_team.get(challenger_team_id, {})
		if _candidate_can_touch(possession_candidate):
			if _candidate_can_touch(challenger_candidate):
				var possession_profile: Dictionary = possession_candidate.get("player_profile", {})
				var possession_state: Dictionary = possession_candidate.get("player_state", {})
				var challenger_state: Dictionary = challenger_candidate.get("player_state", {})
				var possession_stamina_norm := clampf(float(possession_state.get("stamina_norm", 1.0)), 0.18, 1.0)
				var challenger_stamina_norm := clampf(float(challenger_state.get("stamina_norm", 1.0)), 0.18, 1.0)
				var possession_lock_norm := clampf(_ai_possession_timer_sec / MATCH_AI_POSSESSION_WINDOW_SEC, 0.0, 1.0)
				var possession_carry_penalty_norm := _resolve_player_carry_streak_norm(_ai_possession_team_id, _ai_possession_player_id)
				var hold_margin_m := 1.1 \
					+ maxf(float(possession_profile.get("ball_security_bias", 0.0)), 0.0) * 1.7 \
					+ (possession_stamina_norm - challenger_stamina_norm) * 0.28 \
					+ possession_lock_norm * 0.35 \
					- possession_carry_penalty_norm * 0.22
				if float(challenger_candidate.get("distance_m", INF)) + hold_margin_m >= float(possession_candidate.get("distance_m", INF)):
					return possession_candidate
				if _candidate_should_break_possession(challenger_candidate, possession_candidate, ball_local_position):
					return challenger_candidate
			return possession_candidate
	var preferred_candidate := home_candidate
	if preferred_candidate.is_empty() or float(away_candidate.get("distance_m", INF)) < float(preferred_candidate.get("distance_m", INF)):
		preferred_candidate = away_candidate
	if _candidate_can_touch(preferred_candidate):
		return preferred_candidate
	return {}

func _candidate_can_touch(candidate: Dictionary) -> bool:
	if candidate.is_empty():
		return false
	return float(candidate.get("distance_m", INF)) <= float(candidate.get("touch_radius_m", MATCH_AI_TOUCH_RADIUS_M))

func _candidate_should_break_possession(challenger_candidate: Dictionary, possession_candidate: Dictionary, ball_local_position: Vector3) -> bool:
	if possession_candidate.is_empty() or not _candidate_can_touch(possession_candidate):
		return true
	var challenger_contract: Dictionary = challenger_candidate.get("player_contract", {})
	var challenger_state: Dictionary = challenger_candidate.get("player_state", {})
	var challenger_profile: Dictionary = challenger_candidate.get("player_profile", {})
	var possession_profile: Dictionary = possession_candidate.get("player_profile", {})
	var possession_state: Dictionary = possession_candidate.get("player_state", {})
	var challenger_role_id := str(challenger_contract.get("role_id", "field_player"))
	var challenger_intent_kind := str(challenger_state.get("intent_kind", "hold_shape"))
	var possession_goal_center := _resolve_opponent_goal_local_center(null, _ai_possession_team_id)
	var possession_is_in_shot_window := _is_ai_shot_window(_ai_possession_team_id, ball_local_position, possession_goal_center)
	if challenger_role_id == "goalkeeper" and challenger_intent_kind == "goalkeeper_intercept":
		return true
	var challenger_distance_m := float(challenger_candidate.get("distance_m", INF))
	var possession_distance_m := float(possession_candidate.get("distance_m", INF))
	if challenger_distance_m + 0.55 < possession_distance_m:
		return true
	var challenger_stamina_norm := clampf(float(challenger_state.get("stamina_norm", 1.0)), 0.18, 1.0)
	var possession_stamina_norm := clampf(float(possession_state.get("stamina_norm", 1.0)), 0.18, 1.0)
	var possession_lock_norm := clampf(_ai_possession_timer_sec / MATCH_AI_POSSESSION_WINDOW_SEC, 0.0, 1.0)
	var possession_carry_penalty_norm := _resolve_player_carry_streak_norm(_ai_possession_team_id, _ai_possession_player_id)
	var possession_advantage_m := MATCH_AI_POSSESSION_BREAK_ADVANTAGE_M \
		+ maxf(float(possession_profile.get("ball_security_bias", 0.0)), 0.0) * 1.35 \
		+ (possession_stamina_norm - challenger_stamina_norm) * 0.34 \
		+ possession_lock_norm * 0.42 \
		- possession_carry_penalty_norm * 0.26
	if challenger_distance_m + possession_advantage_m >= possession_distance_m:
		return false
	var press_bonus := 0.0
	if challenger_intent_kind == "press_ball":
		press_bonus = 0.07
	elif challenger_intent_kind == "collapse_defense":
		press_bonus = 0.05
	var zone_bonus := -0.02
	var possession_ball_zone := _resolve_team_ball_zone(_ai_possession_team_id, ball_local_position)
	if possession_ball_zone == "defensive":
		zone_bonus = 0.12
	elif possession_ball_zone == "attacking":
		zone_bonus = -0.12
	var break_probability := 0.08 \
		+ float(challenger_profile.get("tackle_bias", 0.0)) \
		- float(possession_profile.get("ball_security_bias", 0.0)) \
		+ press_bonus \
		+ zone_bonus \
		+ (possession_distance_m - challenger_distance_m) * 0.2 \
		+ (challenger_stamina_norm - possession_stamina_norm) * 0.18 \
		- possession_lock_norm * 0.12 \
		+ possession_carry_penalty_norm * 0.09
	if possession_is_in_shot_window:
		break_probability -= 0.22
	return _roll_match_chance(clampf(break_probability, 0.02, 0.42 if not possession_is_in_shot_window else 0.18))

func _apply_ai_touch(ball_node: Node3D, mounted_venue: Node3D, player_contract: Dictionary, player_state: Dictionary, player_profile: Dictionary, ball_local_position: Vector3) -> void:
	if ball_node == null or not (ball_node is RigidBody3D):
		return
	var team_id := str(player_contract.get("team_id", "home"))
	var role_id := str(player_contract.get("role_id", "field_player"))
	var intent_kind := str(player_state.get("intent_kind", "press_ball"))
	var touch_plan := _resolve_ai_touch_plan(mounted_venue, player_contract, player_state, player_profile, ball_local_position, intent_kind)
	var is_shot_attempt := bool(touch_plan.get("is_shot_attempt", false))
	var kick_direction: Vector3 = touch_plan.get("direction", Vector3.ZERO)
	var kick_speed_mps := float(touch_plan.get("speed_mps", 0.0))
	var action_kind := str(touch_plan.get("action_kind", "carry_ball"))
	if kick_direction.length_squared() <= 0.0001 or kick_speed_mps <= 0.0:
		return
	var rigid_ball := ball_node as RigidBody3D
	rigid_ball.linear_velocity = kick_direction * kick_speed_mps + Vector3.UP * MATCH_AI_TOUCH_LIFT_MPS
	rigid_ball.angular_velocity = Vector3.ZERO
	rigid_ball.sleeping = false
	_set_game_state("in_play", 0.0)
	var player_id := str(player_contract.get("player_id", ""))
	player_state["animation_state"] = "run"
	player_state["facing_direction"] = kick_direction
	player_state["intent_kind"] = "kick_ball"
	player_state["kick_requested"] = true
	player_state["stamina_norm"] = maxf(float(player_state.get("stamina_norm", 1.0)) - 0.05, 0.18)
	_match_player_states[player_id] = player_state.duplicate(true)
	var touch_cooldown_sec := MATCH_AI_SHOT_TOUCH_COOLDOWN_SEC if is_shot_attempt else 0.42
	if intent_kind == "collapse_defense":
		touch_cooldown_sec = 0.36
	elif action_kind == "pass_ball":
		touch_cooldown_sec = 0.34
	_last_ai_touch_cooldown_sec = touch_cooldown_sec
	_ai_possession_team_id = team_id
	_ai_possession_player_id = player_id
	_ai_possession_timer_sec = MATCH_AI_POSSESSION_WINDOW_SEC
	_record_ai_touch(team_id, player_id, action_kind)
	_ai_debug_state["kick_count"] = int(_ai_debug_state.get("kick_count", 0)) + 1
	if action_kind == "pass_ball":
		_ai_debug_state["pass_count"] = int(_ai_debug_state.get("pass_count", 0)) + 1
	_ai_debug_state["last_touch_player_id"] = player_id
	_ai_debug_state["last_touch_team_id"] = team_id
	_ai_debug_state["last_touch_role_id"] = role_id
	_ai_debug_state["last_touch_action_kind"] = action_kind
	_sync_ai_control_debug_state()

func _resolve_ai_touch_plan(mounted_venue: Node3D, player_contract: Dictionary, player_state: Dictionary, player_profile: Dictionary, ball_local_position: Vector3, intent_kind: String) -> Dictionary:
	var team_id := str(player_contract.get("team_id", "home"))
	var role_id := str(player_contract.get("role_id", "field_player"))
	var opponent_goal_center := _resolve_opponent_goal_local_center(mounted_venue, team_id)
	var is_shot_attempt := _is_ai_shot_window(team_id, ball_local_position, opponent_goal_center)
	if role_id != "goalkeeper":
		var carry_streak_count := _resolve_player_carry_streak(team_id, str(player_contract.get("player_id", "")))
		if not is_shot_attempt or carry_streak_count >= 3:
			var pass_plan := _maybe_resolve_ai_pass_plan(player_contract, player_state, player_profile, ball_local_position)
			if not pass_plan.is_empty():
				pass_plan["is_shot_attempt"] = false
				return pass_plan
	return {
		"action_kind": "shot_ball" if is_shot_attempt else "carry_ball",
		"direction": _resolve_ai_kick_direction(mounted_venue, player_contract, player_state, player_profile, ball_local_position, intent_kind),
		"speed_mps": _resolve_ai_kick_speed_mps(mounted_venue, player_contract, player_state, player_profile, role_id, team_id, ball_local_position, intent_kind),
		"is_shot_attempt": is_shot_attempt,
	}

func _maybe_resolve_ai_pass_plan(player_contract: Dictionary, player_state: Dictionary, player_profile: Dictionary, ball_local_position: Vector3) -> Dictionary:
	var team_id := str(player_contract.get("team_id", "home"))
	var player_id := str(player_contract.get("player_id", ""))
	if _ai_possession_team_id != team_id or _ai_possession_timer_sec <= 0.0:
		return {}
	var team_ball_zone := _resolve_team_ball_zone(team_id, ball_local_position)
	var carry_streak_count := _resolve_player_carry_streak(team_id, player_id)
	var carry_streak_norm := _resolve_player_carry_streak_norm(team_id, player_id)
	var pass_target := _resolve_best_ai_pass_target(player_contract, ball_local_position, team_ball_zone, carry_streak_count)
	if pass_target.is_empty():
		return {}
	var stamina_norm := clampf(float(player_state.get("stamina_norm", 1.0)), 0.18, 1.0)
	var pass_probability := 0.08 \
		+ float(player_profile.get("pass_bias", 0.0)) \
		+ (0.7 - stamina_norm) * 0.12 \
		+ carry_streak_norm * 0.18
	if team_ball_zone == "defensive":
		pass_probability += 0.18
	elif team_ball_zone == "neutral":
		pass_probability += 0.18
	pass_probability += clampf(float(pass_target.get("forward_progress_m", 0.0)) / 24.0, 0.0, 0.2)
	pass_probability += clampf((float(pass_target.get("openness_m", 0.0)) - 4.0) / 12.0, 0.0, 0.12)
	if float(pass_target.get("forward_progress_m", 0.0)) >= 5.0:
		pass_probability += 0.08
	if carry_streak_count >= 3:
		pass_probability += 0.08
	if not _roll_match_chance(clampf(pass_probability, 0.05, 0.7)):
		return {}
	var pass_target_position: Vector3 = pass_target.get("local_position", ball_local_position)
	var attack_direction_z := _get_attack_direction_z(team_id)
	var lead_scale := 0.18
	if team_ball_zone == "neutral":
		lead_scale = 0.22
	elif team_ball_zone == "defensive":
		lead_scale = 0.2
	var lead_distance_m := clampf(float(pass_target.get("distance_m", 0.0)) * lead_scale, 1.4, 4.2)
	var pass_direction := pass_target_position + Vector3(0.0, 0.0, attack_direction_z * lead_distance_m) - ball_local_position
	pass_direction.y = 0.0
	if pass_direction.length_squared() <= 0.0001:
		return {}
	var base_pass_speed_mps := 14.6
	if team_ball_zone == "defensive":
		base_pass_speed_mps = 15.0
	elif team_ball_zone == "neutral":
		base_pass_speed_mps = 15.5
	base_pass_speed_mps += carry_streak_norm * 0.5
	return {
		"action_kind": "pass_ball",
		"direction": pass_direction.normalized(),
		"speed_mps": base_pass_speed_mps * clampf(float(player_profile.get("pass_speed_scale", 1.0)), 0.94, 1.08),
	}

func _resolve_best_ai_pass_target(player_contract: Dictionary, ball_local_position: Vector3, team_ball_zone: String, carry_streak_count: int) -> Dictionary:
	var team_id := str(player_contract.get("team_id", "home"))
	var player_id := str(player_contract.get("player_id", ""))
	var attack_direction_z := _get_attack_direction_z(team_id)
	var best_target := {}
	var best_score := -INF
	var minimum_pass_distance_m := 7.0
	var minimum_forward_progress_m := 1.5
	if team_ball_zone == "defensive":
		minimum_forward_progress_m = 0.8
	if carry_streak_count >= 2:
		minimum_pass_distance_m = 5.8
		minimum_forward_progress_m = minf(minimum_forward_progress_m, 0.8)
	for teammate_contract_variant in _match_player_contracts:
		var teammate_contract: Dictionary = teammate_contract_variant
		if str(teammate_contract.get("team_id", "")) != team_id:
			continue
		if str(teammate_contract.get("player_id", "")) == player_id:
			continue
		if str(teammate_contract.get("role_id", "")) == "goalkeeper":
			continue
		var teammate_id := str(teammate_contract.get("player_id", ""))
		var teammate_state: Dictionary = _match_player_states.get(teammate_id, {})
		var teammate_local_position: Vector3 = teammate_state.get("local_position", teammate_contract.get("local_anchor_position", Vector3.ZERO))
		var pass_vector := teammate_local_position - ball_local_position
		var pass_distance_m := Vector2(pass_vector.x, pass_vector.z).length()
		if pass_distance_m < minimum_pass_distance_m or pass_distance_m > 30.0:
			continue
		var forward_progress_m := (teammate_local_position.z - ball_local_position.z) * attack_direction_z
		if forward_progress_m < minimum_forward_progress_m:
			continue
		var openness_m := INF
		for opponent_contract_variant in _match_player_contracts:
			var opponent_contract: Dictionary = opponent_contract_variant
			if str(opponent_contract.get("team_id", "")) == team_id:
				continue
			var opponent_id := str(opponent_contract.get("player_id", ""))
			var opponent_state: Dictionary = _match_player_states.get(opponent_id, {})
			var opponent_local_position: Vector3 = opponent_state.get("local_position", opponent_contract.get("local_anchor_position", Vector3.ZERO))
			openness_m = minf(openness_m, Vector2(
				opponent_local_position.x - teammate_local_position.x,
				opponent_local_position.z - teammate_local_position.z
			).length())
		var teammate_intent_kind := str(teammate_state.get("intent_kind", "hold_shape"))
		var target_score := forward_progress_m * 0.68 \
			+ minf(openness_m, 12.0) * 0.42 \
			- pass_distance_m * 0.14
		if teammate_intent_kind == "support_run":
			target_score += 2.2
		elif teammate_intent_kind == "hold_shape":
			target_score -= 0.6
		if target_score > best_score:
			best_score = target_score
			best_target = {
				"player_id": teammate_id,
				"local_position": teammate_local_position,
				"distance_m": pass_distance_m,
				"forward_progress_m": forward_progress_m,
				"openness_m": openness_m,
			}
	return best_target

func _resolve_ai_kick_direction(mounted_venue: Node3D, player_contract: Dictionary, player_state: Dictionary, player_profile: Dictionary, ball_local_position: Vector3, intent_kind: String) -> Vector3:
	var team_id := str(player_contract.get("team_id", "home"))
	var carry_bias_x := float(player_profile.get("carry_bias_x", 0.0))
	var stamina_norm := clampf(float(player_state.get("stamina_norm", 1.0)), 0.18, 1.0)
	if intent_kind == "goalkeeper_intercept" or intent_kind == "collapse_defense":
		var clear_direction := Vector3(
			carry_bias_x * 0.42 + signf(ball_local_position.x) * 0.18,
			0.0,
			_get_attack_direction_z(team_id)
		)
		if clear_direction.length_squared() > 0.0001:
			return clear_direction.normalized()
	var target_goal_center := _resolve_opponent_goal_local_center(mounted_venue, team_id)
	var goal_distance_m := Vector2(
		target_goal_center.x - ball_local_position.x,
		target_goal_center.z - ball_local_position.z
	).length()
	if _is_ai_shot_window(team_id, ball_local_position, target_goal_center):
		target_goal_center.x = clampf(
			target_goal_center.x + float(player_profile.get("shot_bias_x", 0.0)),
			-MATCH_GOAL_WIDTH_FALLBACK_M * 0.34,
			MATCH_GOAL_WIDTH_FALLBACK_M * 0.34
		)
	else:
		var carry_distance_m := 11.0 if goal_distance_m <= MATCH_AI_PROGRESS_DISTANCE_WINDOW_M else 16.0
		carry_distance_m *= lerpf(0.8, 1.08, clampf((stamina_norm - 0.18) / 0.82, 0.0, 1.0))
		var carry_variation_x := _match_randf_range(-0.75, 0.75) * 0.22
		var carry_target := ball_local_position + Vector3(
			carry_bias_x + carry_variation_x,
			0.0,
			_get_attack_direction_z(team_id) * carry_distance_m
		)
		var carry_direction := carry_target - ball_local_position
		if carry_direction.length_squared() > 0.0001:
			return carry_direction.normalized()
	var kick_direction := target_goal_center - ball_local_position
	kick_direction.y = 0.0
	if kick_direction.length_squared() <= 0.0001:
		kick_direction = Vector3(0.0, 0.0, _get_attack_direction_z(team_id))
	return kick_direction.normalized()

func _resolve_ai_kick_speed_mps(mounted_venue: Node3D, player_contract: Dictionary, player_state: Dictionary, player_profile: Dictionary, role_id: String, team_id: String, ball_local_position: Vector3, intent_kind: String) -> float:
	var kick_speed_scale := float(player_profile.get("kick_speed_scale", 1.0))
	var stamina_norm := clampf(float(player_state.get("stamina_norm", 1.0)), 0.18, 1.0)
	var progression_scale := lerpf(0.9, 1.08, clampf((stamina_norm - 0.18) / 0.82, 0.0, 1.0))
	var carry_streak_norm := _resolve_player_carry_streak_norm(team_id, str(player_contract.get("player_id", "")))
	if role_id == "goalkeeper" or intent_kind == "goalkeeper_intercept":
		return 12.4 * kick_speed_scale
	if intent_kind == "collapse_defense":
		return 10.8 * maxf(kick_speed_scale, 1.0)
	var opponent_goal_center := _resolve_opponent_goal_local_center(mounted_venue, team_id)
	var goal_distance_m := Vector2(
		opponent_goal_center.x - ball_local_position.x,
		opponent_goal_center.z - ball_local_position.z
	).length()
	if _is_ai_shot_window(team_id, ball_local_position, opponent_goal_center):
		return 13.9 * kick_speed_scale * progression_scale * lerpf(1.0, 0.92, carry_streak_norm)
	if goal_distance_m <= MATCH_AI_PROGRESS_DISTANCE_WINDOW_M:
		return 12.4 * kick_speed_scale * progression_scale * lerpf(1.0, 0.96, carry_streak_norm)
	return 13.6 * kick_speed_scale * progression_scale

func _is_ai_shot_window(team_id: String, ball_local_position: Vector3, target_goal_center: Vector3) -> bool:
	if _resolve_team_ball_zone(team_id, ball_local_position) != "attacking":
		return false
	var goal_distance_m := Vector2(
		target_goal_center.x - ball_local_position.x,
		target_goal_center.z - ball_local_position.z
	).length()
	return goal_distance_m <= MATCH_AI_SHOT_DISTANCE_WINDOW_M and absf(ball_local_position.x) <= MATCH_GOAL_WIDTH_FALLBACK_M * 1.22

func _clear_ai_possession() -> void:
	_ai_possession_team_id = ""
	_ai_possession_player_id = ""
	_ai_possession_timer_sec = 0.0

func _clear_ai_touch_streaks() -> void:
	_ai_touch_streak_team_id = ""
	_ai_touch_streak_player_id = ""
	_ai_touch_streak_count = 0
	_ai_carry_streak_team_id = ""
	_ai_carry_streak_player_id = ""
	_ai_carry_streak_count = 0

func _record_ai_touch(team_id: String, player_id: String, action_kind: String) -> void:
	if team_id != "" and player_id != "" and team_id == _ai_touch_streak_team_id and player_id == _ai_touch_streak_player_id:
		_ai_touch_streak_count += 1
	elif team_id != "" and player_id != "":
		_ai_touch_streak_count = 1
	else:
		_ai_touch_streak_count = 0
	_ai_touch_streak_team_id = team_id
	_ai_touch_streak_player_id = player_id
	if action_kind == "carry_ball":
		if team_id != "" and player_id != "" and team_id == _ai_carry_streak_team_id and player_id == _ai_carry_streak_player_id:
			_ai_carry_streak_count += 1
		elif team_id != "" and player_id != "":
			_ai_carry_streak_count = 1
		else:
			_ai_carry_streak_count = 0
		_ai_carry_streak_team_id = team_id
		_ai_carry_streak_player_id = player_id
		return
	_ai_carry_streak_team_id = ""
	_ai_carry_streak_player_id = ""
	_ai_carry_streak_count = 0

func _resolve_player_carry_streak(team_id: String, player_id: String) -> int:
	if team_id == "" or player_id == "":
		return 0
	if team_id != _ai_carry_streak_team_id or player_id != _ai_carry_streak_player_id:
		return 0
	return _ai_carry_streak_count

func _resolve_player_carry_streak_norm(team_id: String, player_id: String) -> float:
	return clampf(float(maxi(_resolve_player_carry_streak(team_id, player_id) - 1, 0)) / 3.0, 0.0, 1.0)

func _arm_match_restart(restart_team_id: String) -> void:
	_clear_ai_possession()
	_clear_ai_touch_streaks()
	_clear_goalkeeper_control()
	_last_ai_touch_cooldown_sec = 0.0
	_kickoff_team_id = restart_team_id if restart_team_id != "" else _kickoff_team_id
	_kickoff_protection_timer_sec = MATCH_AI_KICKOFF_PROTECTION_SEC
	_pending_restart_team_id = ""
	_reform_match_players_to_restart_shape()
	_sync_ai_control_debug_state()

func _resolve_out_of_bounds_restart_team_id() -> String:
	if _ai_possession_team_id == "home":
		return "away"
	if _ai_possession_team_id == "away":
		return "home"
	return _kickoff_team_id

func _resolve_match_opening_kickoff_team_id() -> String:
	return "home" if _match_session_serial % 2 == 1 else "away"

func _build_match_team_profiles(match_session_serial: int) -> Dictionary:
	var profile_rng := RandomNumberGenerator.new()
	profile_rng.seed = ("%d:%d:%s" % [_match_seed, match_session_serial, _active_venue_id]).hash()
	var home_profile := {
		"build_up_scale": 1.0 + profile_rng.randf_range(-0.015, 0.015),
		"shot_scale": 1.0 + profile_rng.randf_range(-0.012, 0.012),
		"press_scale": 1.0 + profile_rng.randf_range(-0.015, 0.015),
	}
	var away_profile := {
		"build_up_scale": 1.0 + profile_rng.randf_range(-0.015, 0.015),
		"shot_scale": 1.0 + profile_rng.randf_range(-0.012, 0.012),
		"press_scale": 1.0 + profile_rng.randf_range(-0.015, 0.015),
	}
	return {
		"home": home_profile,
		"away": away_profile,
	}

func _seed_match_rng() -> void:
	if _forced_match_seed > 0:
		_match_seed = _forced_match_seed
		_match_rng.seed = _match_seed
		return
	var tick_seed := Time.get_ticks_usec()
	var unix_seed := int(Time.get_unix_time_from_system() * 1000000.0)
	var seed_source := "%s:%d:%d:%d" % [_active_venue_id, _match_session_serial, tick_seed, unix_seed]
	_match_seed = seed_source.hash()
	if _match_seed == 0:
		_match_seed = 1
	_match_rng.seed = _match_seed

func _roll_match_chance(probability: float) -> bool:
	var clamped_probability := clampf(probability, 0.0, 1.0)
	if clamped_probability <= 0.0:
		return false
	if clamped_probability >= 1.0:
		return true
	return _match_rng.randf() <= clamped_probability

func _match_randf_range(min_value: float, max_value: float) -> float:
	if is_equal_approx(min_value, max_value):
		return min_value
	return _match_rng.randf_range(min_value, max_value)

func _resolve_team_restart_taker_id(team_id: String) -> String:
	var best_player_id := ""
	var best_distance_m := INF
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		if str(player_contract.get("team_id", "")) != team_id:
			continue
		if str(player_contract.get("role_id", "")) == "goalkeeper":
			continue
		var anchor_position: Vector3 = player_contract.get("local_anchor_position", Vector3.ZERO)
		var distance_m := Vector2(anchor_position.x, anchor_position.z).length()
		if distance_m < best_distance_m:
			best_distance_m = distance_m
			best_player_id = str(player_contract.get("player_id", ""))
	return best_player_id

func _sync_ai_control_debug_state() -> void:
	_ai_debug_state["control_team_id"] = _ai_possession_team_id
	_ai_debug_state["control_player_id"] = _ai_possession_player_id
	_ai_debug_state["control_time_remaining_sec"] = _ai_possession_timer_sec
	_ai_debug_state["kickoff_team_id"] = _kickoff_team_id
	_ai_debug_state["kickoff_time_remaining_sec"] = _kickoff_protection_timer_sec
	_ai_debug_state["goalkeeper_control_team_id"] = str(_goalkeeper_control_state.get("team_id", ""))
	_ai_debug_state["goalkeeper_control_player_id"] = str(_goalkeeper_control_state.get("player_id", ""))
	_ai_debug_state["goalkeeper_control_phase"] = str(_goalkeeper_control_state.get("phase", ""))
	_ai_debug_state["goalkeeper_control_time_remaining_sec"] = float(_goalkeeper_control_state.get("timer_sec", 0.0))
	_ai_debug_state["match_seed"] = _match_seed

func _clear_goalkeeper_control() -> void:
	_goalkeeper_control_state = {
		"team_id": "",
		"player_id": "",
		"phase": "",
		"timer_sec": 0.0,
	}

func _find_match_player_contract(player_id: String) -> Dictionary:
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		if str(player_contract.get("player_id", "")) == player_id:
			return player_contract.duplicate(true)
	return {}

func _resolve_opponent_goal_local_center(mounted_venue: Node3D, team_id: String) -> Vector3:
	if mounted_venue != null and mounted_venue.has_method("get_goal_contracts"):
		var goal_contracts: Dictionary = mounted_venue.get_goal_contracts()
		var target_goal_id := "goal_a" if team_id == "home" else "goal_b"
		var target_goal_contract: Dictionary = goal_contracts.get(target_goal_id, {})
		var local_center_variant: Variant = target_goal_contract.get("local_center", Vector3.ZERO)
		if local_center_variant is Vector3:
			return local_center_variant as Vector3
	var fallback_z := -MATCH_SURFACE_SIZE_FALLBACK.z * 0.5 if team_id == "home" else MATCH_SURFACE_SIZE_FALLBACK.z * 0.5
	return Vector3(0.0, 0.0, fallback_z)

func _resolve_match_surface_size(mounted_venue: Node3D) -> Vector3:
	if mounted_venue != null and mounted_venue.has_method("get_play_surface_contract"):
		var surface_contract: Dictionary = mounted_venue.get_play_surface_contract()
		var surface_size_variant: Variant = surface_contract.get("surface_size", MATCH_SURFACE_SIZE_FALLBACK)
		if surface_size_variant is Vector3:
			return surface_size_variant as Vector3
	return MATCH_SURFACE_SIZE_FALLBACK

func _resolve_team_ball_zone(team_id: String, ball_local_position: Vector3) -> String:
	if team_id == "home":
		if ball_local_position.z >= MATCH_AI_NEUTRAL_ZONE_BUFFER_M:
			return "defensive"
		if ball_local_position.z <= -MATCH_AI_NEUTRAL_ZONE_BUFFER_M:
			return "attacking"
		return "neutral"
	if ball_local_position.z <= -MATCH_AI_NEUTRAL_ZONE_BUFFER_M:
		return "defensive"
	if ball_local_position.z >= MATCH_AI_NEUTRAL_ZONE_BUFFER_M:
		return "attacking"
	return "neutral"

func _sync_match_visual_state(mounted_venue: Node3D) -> void:
	if mounted_venue == null or not mounted_venue.has_method("sync_match_state"):
		return
	mounted_venue.sync_match_state({
		"match_state": _match_state,
		"start_ring_visible": _match_state == MATCH_STATE_IDLE,
		"player_states": _match_player_states.duplicate(true),
		"winner_side": _winner_side,
	})

func _get_ball_world_position(ball_node: Node3D) -> Vector3:
	return ball_node.global_position if ball_node != null else Vector3.ZERO

func _get_ball_linear_velocity(ball_node: Node3D) -> Vector3:
	if ball_node is RigidBody3D:
		return (ball_node as RigidBody3D).linear_velocity
	return Vector3.ZERO

func _resolve_entry_world_position(entry: Dictionary) -> Vector3:
	var world_position_variant: Variant = entry.get("world_position", Vector3.ZERO)
	if world_position_variant is Vector3:
		return world_position_variant as Vector3
	return Vector3.ZERO
