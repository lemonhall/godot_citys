extends RefCounted

const ACTIVE_VENUE_SCAN_RADIUS_M := 768.0
const BALL_RADIUS_FALLBACK_M := 0.0675
const BALL_CONTACT_EPSILON_M := 0.05
const BOUNCE_COOLDOWN_SEC := 0.10
const AI_RETURN_DELAY_SEC := 0.18
const AI_SERVE_DELAY_SEC := 0.48
const LIVE_OUT_MARGIN_M := 6.0
const POINT_RESULT_LINGER_SEC := 0.65
const GAME_BREAK_LINGER_SEC := 1.0
const MATCH_GAMES_TO_WIN := 4
const PLAY_SURFACE_COLLISION_LAYER_VALUE := 1 << 8
const DEFAULT_GRAVITY_MPS2 := 9.8
const SERVE_DESIRED_SPEED_MPS := 46.0
const PLAYER_RETURN_DESIRED_SPEED_MPS := 40.0
const AI_RETURN_DESIRED_SPEED_MPS := 38.0
const MIN_SHOT_TRAVEL_TIME_SEC := 1.2
const MAX_SHOT_TRAVEL_TIME_SEC := 2.8
const SERVE_READY_BALL_HEIGHT_M := 1.08
const PLAYER_AUTO_FOOTWORK_SPEED_MPS := 34.0
const PLAYER_STRIKE_RADIUS_M := 3.8
const PLAYER_STRIKE_HEIGHT_MIN_M := 0.25
const PLAYER_STRIKE_HEIGHT_MAX_M := 4.2
const PLAYER_RECEIVE_MARKER_RADIUS_M := 4.2
const PLAYER_POST_BOUNCE_READY_WINDOW_SEC := 0.72
const PLAYER_STRIKE_SLOT_BLEND := 0.12
const PLAYER_STRIKE_SLOT_MIN_AHEAD_M := 0.45
const MATCH_STATE_IDLE := "idle"
const MATCH_STATE_PRE_SERVE := "pre_serve"
const MATCH_STATE_SERVE_IN_FLIGHT := "serve_in_flight"
const MATCH_STATE_RALLY := "rally"
const MATCH_STATE_POINT_RESULT := "point_result"
const MATCH_STATE_GAME_BREAK := "game_break"
const MATCH_STATE_FINAL := "final"
const AUTO_FOOTWORK_STATE_IDLE := "idle"
const AUTO_FOOTWORK_STATE_TRACKING := "tracking"
const AUTO_FOOTWORK_STATE_SET := "set"
const STRIKE_WINDOW_STATE_IDLE := "idle"
const STRIKE_WINDOW_STATE_TRACKING := "tracking"
const STRIKE_WINDOW_STATE_READY := "ready"
const STRIKE_WINDOW_STATE_RECOVER := "recover"
const FEEDBACK_EVENT_SERVE_READY := "serve_ready"
const FEEDBACK_EVENT_READY := "ready"
const FEEDBACK_EVENT_POINT_RESULT := "point_result"
const FEEDBACK_EVENT_GAME_BREAK := "game_break"
const FEEDBACK_EVENT_FINAL := "final"

var _entries_by_venue_id: Dictionary = {}
var _active_venue_id := ""
var _bound_ball_prop_id := ""
var _ball_bound := false
var _ambient_simulation_frozen := false
var _ball_radius_m := BALL_RADIUS_FALLBACK_M
var _match_state := MATCH_STATE_IDLE
var _state_timer_sec := 0.0
var _home_games := 0
var _away_games := 0
var _home_points := 0
var _away_points := 0
var _server_side := "home"
var _serve_attempt_index := 0
var _expected_service_box_id := "service_box_deuce_away"
var _winner_side := ""
var _point_winner_side := ""
var _point_end_reason := ""
var _last_hitter_side := ""
var _target_side := ""
var _target_bounce_count := 0
var _bounce_cooldown_sec := 0.0
var _ai_return_armed := false
var _ai_return_timer_sec := 0.0
var _previous_ball_world_position := Vector3.ZERO
var _previous_ball_linear_velocity := Vector3.ZERO
var _scoreboard_state: Dictionary = {}
var _match_hud_state: Dictionary = {}
var _opponent_state: Dictionary = {}
var _latest_player_world_position := Vector3.ZERO
var _planned_target_world_position := Vector3.ZERO
var _planned_target_side := ""
var _landing_marker_visible := false
var _landing_marker_world_position := Vector3.ZERO
var _incoming_strike_world_position := Vector3.ZERO
var _auto_footwork_assist_state := AUTO_FOOTWORK_STATE_IDLE
var _strike_window_state := STRIKE_WINDOW_STATE_IDLE
var _strike_quality_feedback := ""
var _home_receive_grace_sec := 0.0
var _ai_return_pattern_index := 0
var _player_swing_token := 0
var _player_swing_style := ""
var _opponent_swing_token := 0
var _opponent_swing_style := ""
var _feedback_event_token := 0
var _feedback_event_kind := ""
var _feedback_event_text := ""
var _feedback_event_tone := "neutral"
var _rally_shot_count := 0
var _debug_forced_ai_pressure_error_kind := ""
var _debug_last_bounce_probe: Dictionary = {}
var _debug_last_bounce_event: Dictionary = {}
var _debug_last_live_out_world_position := Vector3.ZERO

func configure(entries: Dictionary) -> void:
	_entries_by_venue_id.clear()
	var sorted_ids: Array[String] = []
	for venue_id_variant in entries.keys():
		var venue_id := str(venue_id_variant).strip_edges()
		if venue_id == "":
			continue
		var entry: Dictionary = (entries.get(venue_id, {}) as Dictionary).duplicate(true)
		if str(entry.get("game_kind", "")) != "tennis_court":
			continue
		_entries_by_venue_id[venue_id] = entry
		sorted_ids.append(venue_id)
	sorted_ids.sort()
	if _active_venue_id == "" or not _entries_by_venue_id.has(_active_venue_id):
		_active_venue_id = sorted_ids[0] if not sorted_ids.is_empty() else ""
	_reset_runtime_state()
	_refresh_visual_snapshots()

func update(chunk_renderer: Node, player_node: Node3D, delta: float) -> Dictionary:
	var entry := _resolve_active_entry()
	if entry.is_empty():
		_set_player_racket_visible(player_node, false)
		_handle_unavailable_runtime()
		return get_state()
	if not _is_player_near_active_venue(entry, player_node):
		_set_player_racket_visible(player_node, false)
		_handle_unavailable_runtime(str(entry.get("primary_ball_prop_id", "")))
		return get_state()
	var mounted_venue := _resolve_mounted_venue(chunk_renderer, entry)
	var ball_node := _resolve_bound_ball(chunk_renderer, entry)
	_update_ball_radius(entry)
	_latest_player_world_position = player_node.global_position if player_node != null and is_instance_valid(player_node) else Vector3.ZERO
	_update_ambient_freeze(player_node, mounted_venue)
	if mounted_venue == null or ball_node == null:
		_set_player_racket_visible(player_node, _match_state != MATCH_STATE_IDLE)
		_clear_receive_hint_state()
		_refresh_visual_snapshots(mounted_venue)
		return get_state()
	_ensure_play_surface_collision_isolation(ball_node, mounted_venue)
	var player_world_position := player_node.global_position if player_node != null else Vector3.ZERO
	var in_release_bounds := mounted_venue.has_method("is_world_point_in_release_bounds") and bool(mounted_venue.is_world_point_in_release_bounds(player_world_position))
	if not in_release_bounds and _has_dirty_match_session():
		_perform_full_match_reset(ball_node, mounted_venue)
		_set_player_racket_visible(player_node, false)
		_refresh_visual_snapshots(mounted_venue)
		return get_state()
	if _match_state == MATCH_STATE_IDLE and _can_player_start_match(player_world_position, mounted_venue):
		_start_match(ball_node, mounted_venue)
	_set_player_racket_visible(player_node, _match_state != MATCH_STATE_IDLE)
	_update_timers(delta)
	_advance_match_state(ball_node, mounted_venue, delta)
	_update_player_receive_assist(player_node, mounted_venue, ball_node, delta)
	_refresh_visual_snapshots(mounted_venue)
	_previous_ball_world_position = _get_ball_world_position(ball_node)
	_previous_ball_linear_velocity = _get_ball_linear_velocity(ball_node)
	return get_state()

func get_state() -> Dictionary:
	return {
		"active_venue_id": _active_venue_id,
		"venue_entry_count": _entries_by_venue_id.size(),
		"primary_ball_prop_id": _bound_ball_prop_id,
		"ball_bound": _ball_bound,
		"ambient_simulation_frozen": _ambient_simulation_frozen,
		"match_state": _match_state,
		"home_games": _home_games,
		"away_games": _away_games,
		"home_point_label": _point_count_to_label(_home_points),
		"away_point_label": _point_count_to_label(_away_points),
		"server_side": _server_side,
		"serve_attempt_index": _serve_attempt_index,
		"expected_service_box_id": _expected_service_box_id,
		"winner_side": _winner_side,
		"point_winner_side": _point_winner_side,
		"point_end_reason": _point_end_reason,
		"rally_shot_count": _rally_shot_count,
		"last_hitter_side": _last_hitter_side,
		"target_side": _target_side,
		"ball_bounce_count_home": _target_bounce_count if _target_side == "home" else 0,
		"ball_bounce_count_away": _target_bounce_count if _target_side == "away" else 0,
		"planned_target_world_position": _planned_target_world_position,
		"planned_target_side": _planned_target_side,
		"debug_last_bounce_probe": _debug_last_bounce_probe.duplicate(true),
		"debug_last_bounce_event": _debug_last_bounce_event.duplicate(true),
		"debug_last_live_out_world_position": _debug_last_live_out_world_position,
		"landing_marker_visible": _landing_marker_visible,
		"landing_marker_world_position": _landing_marker_world_position,
		"auto_footwork_assist_state": _auto_footwork_assist_state,
		"strike_window_state": _strike_window_state,
		"strike_quality_feedback": _strike_quality_feedback,
		"state_text": _build_match_state_text(),
		"coach_text": _build_match_coach_text(),
		"coach_tone": _build_match_coach_tone(),
		"feedback_event_token": _feedback_event_token,
		"feedback_event_kind": _feedback_event_kind,
		"feedback_event_text": _feedback_event_text,
		"feedback_event_tone": _feedback_event_tone,
		"player_swing_token": _player_swing_token,
		"player_swing_style": _player_swing_style,
		"match_hud_state": _match_hud_state.duplicate(true),
		"scoreboard_state": _scoreboard_state.duplicate(true),
		"opponent_state": _opponent_state.duplicate(true),
	}

func get_match_hud_state() -> Dictionary:
	return _match_hud_state.duplicate(true)

func is_ambient_simulation_frozen() -> bool:
	return _ambient_simulation_frozen

func handle_primary_interaction(chunk_renderer: Node, player_node: Node3D, prop_id: String = "", interaction_contract: Dictionary = {}) -> Dictionary:
	var normalized_prop_id := str(prop_id).strip_edges()
	if normalized_prop_id == "":
		normalized_prop_id = str(interaction_contract.get("prop_id", "")).strip_edges()
	if normalized_prop_id == "":
		return {
			"handled": false,
			"success": false,
			"error": "missing_prop_id",
		}
	var entry := _resolve_active_entry()
	var expected_prop_id := str(entry.get("primary_ball_prop_id", "")).strip_edges()
	if expected_prop_id == "" or normalized_prop_id != expected_prop_id:
		return {
			"handled": false,
			"success": false,
			"error": "prop_mismatch",
		}
	var mounted_venue := _resolve_mounted_venue(chunk_renderer, entry)
	var ball_node := _resolve_bound_ball(chunk_renderer, entry)
	_update_ball_radius(entry)
	if mounted_venue == null or ball_node == null:
		return _build_handled_interaction_result(false, "missing_runtime_nodes", normalized_prop_id)
	if player_node == null or not is_instance_valid(player_node):
		return _build_handled_interaction_result(false, "missing_player", normalized_prop_id)
	match _match_state:
		MATCH_STATE_PRE_SERVE:
			if _server_side == "home":
				return _handle_player_serve(ball_node, mounted_venue, player_node, normalized_prop_id)
			return _build_handled_interaction_result(false, "away_server_turn", normalized_prop_id)
		MATCH_STATE_RALLY:
			if _target_side == "home":
				return _handle_player_return(ball_node, mounted_venue, player_node, normalized_prop_id)
			return _build_handled_interaction_result(false, "ball_targeting_away_side", normalized_prop_id)
		_:
			return _build_handled_interaction_result(false, "no_live_tennis_interaction", normalized_prop_id)

func debug_award_point(winner_side: String, reason: String = "debug_point") -> Dictionary:
	var resolved_winner_side := _normalize_side(winner_side)
	if resolved_winner_side == "":
		return {
			"success": false,
			"error": "invalid_winner_side",
		}
	if _match_state == MATCH_STATE_IDLE:
		return {
			"success": false,
			"error": "match_inactive",
		}
	_apply_point_winner(resolved_winner_side, reason)
	_refresh_visual_snapshots()
	return {
		"success": true,
		"winner_side": resolved_winner_side,
		"match_state": _match_state,
	}

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
	_previous_ball_world_position = world_position
	_previous_ball_linear_velocity = linear_velocity
	return {
		"success": true,
		"ball_world_position": world_position,
	}

func debug_force_reset_ball(chunk_renderer: Node) -> Dictionary:
	var entry := _resolve_active_entry()
	if entry.is_empty():
		return {"success": false, "error": "missing_entry"}
	var mounted_venue := _resolve_mounted_venue(chunk_renderer, entry)
	var ball_node := _resolve_bound_ball(chunk_renderer, entry)
	if mounted_venue == null or ball_node == null:
		return {"success": false, "error": "missing_runtime_nodes"}
	_reset_ball_to_server_anchor(ball_node, mounted_venue)
	_refresh_visual_snapshots(mounted_venue)
	return {"success": true}

func debug_set_ai_pressure_error_kind(error_kind: String) -> Dictionary:
	var normalized_error_kind := error_kind.strip_edges().to_lower()
	if normalized_error_kind == "default":
		normalized_error_kind = ""
	_debug_forced_ai_pressure_error_kind = normalized_error_kind
	return {
		"success": true,
		"debug_forced_ai_pressure_error_kind": _debug_forced_ai_pressure_error_kind,
	}

func notify_manual_ball_interaction(prop_id: String = "", _player_node: Node3D = null) -> Dictionary:
	var normalized_prop_id := str(prop_id).strip_edges()
	if normalized_prop_id == "" or normalized_prop_id != _bound_ball_prop_id:
		return {
			"success": false,
			"error": "prop_mismatch",
		}
	return _build_handled_interaction_result(false, "use_tennis_shot_planner", normalized_prop_id)

func _handle_unavailable_runtime(bound_ball_prop_id: String = "") -> void:
	_ball_bound = false
	_bound_ball_prop_id = bound_ball_prop_id
	_ambient_simulation_frozen = false
	if _has_dirty_match_session():
		_reset_runtime_state()
	_refresh_visual_snapshots()

func _reset_runtime_state() -> void:
	_home_games = 0
	_away_games = 0
	_home_points = 0
	_away_points = 0
	_server_side = "home"
	_serve_attempt_index = 0
	_expected_service_box_id = "service_box_deuce_away"
	_winner_side = ""
	_point_winner_side = ""
	_point_end_reason = ""
	_last_hitter_side = ""
	_target_side = ""
	_target_bounce_count = 0
	_match_state = MATCH_STATE_IDLE
	_state_timer_sec = 0.0
	_bounce_cooldown_sec = 0.0
	_ai_return_armed = false
	_ai_return_timer_sec = 0.0
	_previous_ball_world_position = Vector3.ZERO
	_previous_ball_linear_velocity = Vector3.ZERO
	_planned_target_world_position = Vector3.ZERO
	_planned_target_side = ""
	_rally_shot_count = 0
	_clear_receive_hint_state()
	_strike_window_state = STRIKE_WINDOW_STATE_IDLE
	_strike_quality_feedback = ""
	_player_swing_token = 0
	_player_swing_style = ""
	_opponent_swing_token = 0
	_opponent_swing_style = ""
	_feedback_event_kind = ""
	_feedback_event_text = ""
	_feedback_event_tone = "neutral"
	_opponent_state = _build_default_opponent_state()
	_debug_last_bounce_probe.clear()
	_debug_last_bounce_event.clear()
	_debug_last_live_out_world_position = Vector3.ZERO
	_refresh_visual_snapshots()

func _start_match(ball_node: Node3D, mounted_venue: Node3D) -> void:
	_home_games = 0
	_away_games = 0
	_home_points = 0
	_away_points = 0
	_server_side = "home"
	_winner_side = ""
	_point_winner_side = ""
	_point_end_reason = ""
	_prepare_next_point(ball_node, mounted_venue, true)

func _prepare_next_point(ball_node: Node3D, mounted_venue: Node3D, reset_scores: bool = false) -> void:
	if reset_scores:
		_home_points = 0
		_away_points = 0
	_serve_attempt_index = 0
	_expected_service_box_id = _resolve_expected_service_box_id()
	_point_winner_side = ""
	_point_end_reason = ""
	_last_hitter_side = ""
	_target_side = ""
	_target_bounce_count = 0
	_state_timer_sec = AI_SERVE_DELAY_SEC if _server_side == "away" else 0.0
	_match_state = MATCH_STATE_PRE_SERVE
	_ai_return_armed = false
	_ai_return_timer_sec = 0.0
	_planned_target_world_position = Vector3.ZERO
	_planned_target_side = ""
	_rally_shot_count = 0
	_clear_receive_hint_state()
	_strike_window_state = STRIKE_WINDOW_STATE_IDLE
	_strike_quality_feedback = ""
	_debug_last_bounce_probe.clear()
	_debug_last_bounce_event.clear()
	_debug_last_live_out_world_position = Vector3.ZERO
	_reset_ball_to_server_anchor(ball_node, mounted_venue)
	if _server_side == "home":
		_emit_feedback_event(FEEDBACK_EVENT_SERVE_READY, "按 E 发球", "action")
	else:
		_emit_feedback_event(FEEDBACK_EVENT_SERVE_READY, "对手准备发球", "warning")

func _advance_match_state(ball_node: Node3D, mounted_venue: Node3D, delta: float) -> void:
	match _match_state:
		MATCH_STATE_PRE_SERVE:
			_snap_ball_to_server_anchor_if_idle(ball_node, mounted_venue)
			if _server_side == "away" and _state_timer_sec <= 0.0:
				_execute_ai_serve(ball_node, mounted_venue)
		MATCH_STATE_SERVE_IN_FLIGHT, MATCH_STATE_RALLY:
			_advance_live_ball(ball_node, mounted_venue, delta)
		MATCH_STATE_POINT_RESULT, MATCH_STATE_GAME_BREAK:
			if _state_timer_sec <= 0.0:
				if _winner_side != "" and _is_match_complete():
					_match_state = MATCH_STATE_FINAL
					_reset_ball_to_server_anchor(ball_node, mounted_venue)
					_freeze_ball(ball_node)
					return
				_prepare_next_point(ball_node, mounted_venue)
		MATCH_STATE_FINAL:
			_freeze_ball(ball_node)
		_:
			pass

func _advance_live_ball(ball_node: Node3D, mounted_venue: Node3D, _delta: float) -> void:
	if _ai_return_armed and _ai_return_timer_sec <= 0.0:
		_execute_ai_return(ball_node, mounted_venue)
	var ball_world_position := _get_ball_world_position(ball_node)
	var ball_linear_velocity := _get_ball_linear_velocity(ball_node)
	if _detect_net_fault(mounted_venue, ball_world_position):
		_apply_point_winner(_resolve_other_side(_last_hitter_side), "net")
		_freeze_ball(ball_node)
		return
	var bounce_event := _detect_bounce_event(mounted_venue, ball_world_position, ball_linear_velocity)
	if not bounce_event.is_empty():
		var bounce_side := str(bounce_event.get("bounce_side", ""))
		var bounce_world_position := bounce_event.get("contact_world_position", ball_world_position) as Vector3
		if _match_state == MATCH_STATE_SERVE_IN_FLIGHT:
			_handle_serve_bounce(ball_node, mounted_venue, bounce_world_position, bounce_side)
		else:
			_handle_rally_bounce(ball_node, mounted_venue, bounce_world_position, bounce_side)
		if _match_state == MATCH_STATE_POINT_RESULT or _match_state == MATCH_STATE_GAME_BREAK or _match_state == MATCH_STATE_FINAL:
			_freeze_ball(ball_node)
			return
	if _ball_is_out_of_live_bounds(mounted_venue, ball_world_position):
		_apply_point_winner(_resolve_other_side(_last_hitter_side), "out")
		_freeze_ball(ball_node)

func _handle_serve_bounce(ball_node: Node3D, mounted_venue: Node3D, ball_world_position: Vector3, bounce_side: String) -> void:
	var receiver_side := _resolve_other_side(_server_side)
	var service_box_id := ""
	if mounted_venue.has_method("get_service_box_id_for_world_point"):
		service_box_id = str(mounted_venue.get_service_box_id_for_world_point(ball_world_position))
	var in_play_bounds := mounted_venue.has_method("is_world_point_in_play_bounds") and bool(mounted_venue.is_world_point_in_play_bounds(ball_world_position))
	if bounce_side != receiver_side or service_box_id != _expected_service_box_id or not in_play_bounds:
		if _serve_attempt_index == 0:
			_serve_attempt_index = 1
			_point_end_reason = "fault"
			_match_state = MATCH_STATE_PRE_SERVE
			_planned_target_world_position = Vector3.ZERO
			_planned_target_side = ""
			_reset_ball_to_server_anchor(ball_node, mounted_venue)
			return
		_apply_point_winner(receiver_side, "double_fault")
		return
	_match_state = MATCH_STATE_RALLY
	_point_end_reason = ""
	_target_side = receiver_side
	_target_bounce_count = 1
	_strike_quality_feedback = "serve_in"
	if receiver_side == "away":
		_arm_ai_return()
	else:
		_configure_receive_hint_for_home_return(mounted_venue, ball_world_position)
		_strike_window_state = STRIKE_WINDOW_STATE_TRACKING

func _handle_rally_bounce(_ball_node: Node3D, mounted_venue: Node3D, ball_world_position: Vector3, bounce_side: String) -> void:
	var in_play_bounds := mounted_venue.has_method("is_world_point_in_play_bounds") and bool(mounted_venue.is_world_point_in_play_bounds(ball_world_position))
	if not in_play_bounds:
		_apply_point_winner(_resolve_other_side(_last_hitter_side), "out")
		return
	if _target_side == "":
		_target_side = _resolve_other_side(_last_hitter_side)
	if bounce_side != _target_side:
		_apply_point_winner(_target_side, "wrong_side_bounce")
		return
	_target_bounce_count += 1
	if _target_bounce_count >= 2:
		if _target_side == "home":
			_strike_window_state = STRIKE_WINDOW_STATE_IDLE
			_strike_quality_feedback = "late"
		_apply_point_winner(_resolve_other_side(_target_side), "double_bounce")
		return
	if _target_side == "home":
		_landing_marker_visible = false
		_home_receive_grace_sec = PLAYER_POST_BOUNCE_READY_WINDOW_SEC
	if _target_side == "away":
		_arm_ai_return()

func _apply_point_winner(winner_side: String, reason: String) -> void:
	var resolved_winner_side := _normalize_side(winner_side)
	if resolved_winner_side == "":
		return
	_point_winner_side = resolved_winner_side
	_point_end_reason = reason
	if resolved_winner_side == "home":
		_home_points += 1
	else:
		_away_points += 1
	_ai_return_armed = false
	_ai_return_timer_sec = 0.0
	_target_side = ""
	_target_bounce_count = 0
	_last_hitter_side = ""
	_clear_receive_hint_state()
	if _is_game_won():
		_finalize_game(resolved_winner_side)
		return
	_match_state = MATCH_STATE_POINT_RESULT
	_state_timer_sec = POINT_RESULT_LINGER_SEC
	_emit_feedback_event(
		FEEDBACK_EVENT_POINT_RESULT,
		_build_point_result_summary_text(resolved_winner_side, reason),
		"success" if resolved_winner_side == "home" else "warning"
	)

func _finalize_game(game_winner_side: String) -> void:
	if game_winner_side == "home":
		_home_games += 1
	else:
		_away_games += 1
	_home_points = 0
	_away_points = 0
	_clear_receive_hint_state()
	if _is_match_complete():
		_winner_side = game_winner_side
		_match_state = MATCH_STATE_FINAL
		_state_timer_sec = 0.0
		_emit_feedback_event(
			FEEDBACK_EVENT_FINAL,
			"你赢下整场比赛" if game_winner_side == "home" else "对手赢下整场比赛",
			"success" if game_winner_side == "home" else "warning"
		)
		return
	_server_side = _resolve_other_side(_server_side)
	_match_state = MATCH_STATE_GAME_BREAK
	_state_timer_sec = GAME_BREAK_LINGER_SEC
	_emit_feedback_event(
		FEEDBACK_EVENT_GAME_BREAK,
		"你赢下一局，准备下一分" if game_winner_side == "home" else "对手赢下一局，准备下一分",
		"success" if game_winner_side == "home" else "warning"
	)

func _perform_full_match_reset(ball_node: Node3D, mounted_venue: Node3D) -> void:
	_reset_runtime_state()
	if ball_node != null and mounted_venue != null:
		_reset_ball_to_server_anchor(ball_node, mounted_venue)

func _update_timers(delta: float) -> void:
	var clamped_delta := maxf(delta, 0.0)
	_state_timer_sec = maxf(_state_timer_sec - clamped_delta, 0.0)
	_bounce_cooldown_sec = maxf(_bounce_cooldown_sec - clamped_delta, 0.0)
	_home_receive_grace_sec = maxf(_home_receive_grace_sec - clamped_delta, 0.0)
	if _ai_return_armed:
		_ai_return_timer_sec = maxf(_ai_return_timer_sec - clamped_delta, 0.0)

func _update_ball_radius(entry: Dictionary) -> void:
	_ball_radius_m = clampf(float(entry.get("target_diameter_m", BALL_RADIUS_FALLBACK_M * 2.0)) * 0.5, 0.03, 0.18)

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

func _update_player_receive_assist(player_node: Node3D, mounted_venue: Node3D, ball_node: Node3D, delta: float) -> void:
	if player_node == null or not is_instance_valid(player_node) or mounted_venue == null or ball_node == null:
		return
	var has_receive_slot := _incoming_strike_world_position != Vector3.ZERO
	if _match_state != MATCH_STATE_RALLY or _target_side != "home" or not has_receive_slot:
		if not has_receive_slot and (_strike_window_state == STRIKE_WINDOW_STATE_TRACKING or _strike_window_state == STRIKE_WINDOW_STATE_RECOVER):
			_strike_window_state = STRIKE_WINDOW_STATE_IDLE
		if not has_receive_slot:
			_auto_footwork_assist_state = AUTO_FOOTWORK_STATE_IDLE
		return
	var player_slot_distance := Vector2(
		player_node.global_position.x - _incoming_strike_world_position.x,
		player_node.global_position.z - _incoming_strike_world_position.z
	).length()
	_auto_footwork_assist_state = AUTO_FOOTWORK_STATE_SET if player_slot_distance <= PLAYER_RECEIVE_MARKER_RADIUS_M * 0.6 else AUTO_FOOTWORK_STATE_TRACKING
	var previous_strike_window_state := _strike_window_state
	var strike_eval := _evaluate_player_strike_window(ball_node, player_node, mounted_venue)
	if bool(strike_eval.get("can_strike", false)):
		_strike_window_state = STRIKE_WINDOW_STATE_READY
		_strike_quality_feedback = str(strike_eval.get("feedback", "good"))
		if previous_strike_window_state != STRIKE_WINDOW_STATE_READY:
			_emit_feedback_event(FEEDBACK_EVENT_READY, "READY，按 E 回球", "success")
	elif _strike_window_state != STRIKE_WINDOW_STATE_RECOVER:
		_strike_window_state = STRIKE_WINDOW_STATE_TRACKING
		_strike_quality_feedback = str(strike_eval.get("feedback", "tracking"))

func _refresh_visual_snapshots(mounted_venue: Node3D = null) -> void:
	_scoreboard_state = {
		"home_games": _home_games,
		"away_games": _away_games,
		"home_point_label": _point_count_to_label(_home_points),
		"away_point_label": _point_count_to_label(_away_points),
		"server_side": _server_side,
		"match_state": _match_state,
		"winner_side": _winner_side,
		"point_end_reason": _point_end_reason,
	}
	_match_hud_state = {
		"visible": _match_state != MATCH_STATE_IDLE,
		"match_state": _match_state,
		"home_games": _home_games,
		"away_games": _away_games,
		"home_point_label": _point_count_to_label(_home_points),
		"away_point_label": _point_count_to_label(_away_points),
		"server_side": _server_side,
		"winner_side": _winner_side,
		"point_end_reason": _point_end_reason,
		"landing_marker_visible": _landing_marker_visible,
		"landing_marker_world_position": _landing_marker_world_position,
		"auto_footwork_assist_state": _auto_footwork_assist_state,
		"strike_window_state": _strike_window_state,
		"strike_quality_feedback": _strike_quality_feedback,
		"expected_service_box_id": _expected_service_box_id,
		"state_text": _build_match_state_text(),
		"coach_text": _build_match_coach_text(),
		"coach_tone": _build_match_coach_tone(),
		"feedback_event_token": _feedback_event_token,
		"feedback_event_kind": _feedback_event_kind,
		"feedback_event_text": _feedback_event_text,
		"feedback_event_tone": _feedback_event_tone,
	}
	_opponent_state = _build_opponent_state(mounted_venue)
	if mounted_venue == null:
		return
	if mounted_venue.has_method("set_scoreboard_state"):
		mounted_venue.set_scoreboard_state(_scoreboard_state.duplicate(true))
	if mounted_venue.has_method("sync_match_state"):
		mounted_venue.sync_match_state({
			"match_state": _match_state,
			"start_ring_visible": _match_state == MATCH_STATE_IDLE,
			"scoreboard_state": _scoreboard_state.duplicate(true),
			"opponent_state": _opponent_state.duplicate(true),
			"winner_side": _winner_side,
			"receive_hint_state": {
				"landing_marker_visible": _landing_marker_visible,
				"landing_marker_world_position": _landing_marker_world_position,
				"marker_radius_m": PLAYER_RECEIVE_MARKER_RADIUS_M,
				"auto_footwork_assist_state": _auto_footwork_assist_state,
				"strike_window_state": _strike_window_state,
				"strike_quality_feedback": _strike_quality_feedback,
			},
		})

func _build_opponent_state(mounted_venue: Node3D = null) -> Dictionary:
	var opponent_local_position := Vector3(0.0, 0.0, -9.0)
	var animation_state := "idle"
	if mounted_venue != null and mounted_venue.has_method("get_tennis_court_contract"):
		var court_contract: Dictionary = mounted_venue.get_tennis_court_contract()
		var anchor_key := "away_deuce_receiver_anchor" if _expected_service_box_id == "service_box_deuce_away" else "away_ad_receiver_anchor"
		if _match_state == MATCH_STATE_PRE_SERVE or _match_state == MATCH_STATE_SERVE_IN_FLIGHT:
			opponent_local_position = _extract_local_anchor(court_contract.get(anchor_key, {}), Vector3(0.0, 0.0, -9.4))
		elif _match_state == MATCH_STATE_RALLY and _target_side == "away":
			var target_local_position := mounted_venue.to_local(_planned_target_world_position) if _planned_target_world_position != Vector3.ZERO else mounted_venue.to_local(_previous_ball_world_position)
			var court_bounds: Dictionary = court_contract.get("court_bounds", {})
			var half_width := float(court_bounds.get("half_width_m", 4.115))
			var half_length := float(court_bounds.get("half_length_m", 11.885))
			var service_line_distance_m := float(court_contract.get("service_line_distance_m", 6.40))
			opponent_local_position = Vector3(
				clampf(target_local_position.x, -half_width * 0.44, half_width * 0.44),
				0.0,
				clampf(target_local_position.z + 6.0, -half_length + 8.0, -service_line_distance_m - 4.0)
			)
			animation_state = "run"
		else:
			opponent_local_position = _extract_local_anchor(court_contract.get("away_baseline_anchor", {}), Vector3(0.0, 0.0, -9.2))
	var facing_direction := Vector3(0.0, 0.0, 1.0)
	if _match_state == MATCH_STATE_RALLY and _target_side == "away":
		facing_direction = Vector3(0.0, 0.0, 1.0)
	return {
		"local_position": opponent_local_position,
		"facing_direction": facing_direction,
		"animation_state": animation_state,
		"racket_visible": true,
		"swing_token": _opponent_swing_token,
		"swing_style": _opponent_swing_style,
	}

func _resolve_default_venue_id() -> String:
	var sorted_ids: Array[String] = []
	for venue_id_variant in _entries_by_venue_id.keys():
		sorted_ids.append(str(venue_id_variant))
	sorted_ids.sort()
	return sorted_ids[0] if not sorted_ids.is_empty() else ""

func _resolve_active_entry() -> Dictionary:
	if _active_venue_id == "":
		_active_venue_id = _resolve_default_venue_id()
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

func _is_player_near_active_venue(entry: Dictionary, player_node: Node3D) -> bool:
	if player_node == null or not is_instance_valid(player_node):
		return false
	return player_node.global_position.distance_squared_to(_resolve_entry_world_position(entry)) <= ACTIVE_VENUE_SCAN_RADIUS_M * ACTIVE_VENUE_SCAN_RADIUS_M

func _can_player_start_match(player_world_position: Vector3, mounted_venue: Node3D) -> bool:
	return mounted_venue != null \
		and mounted_venue.has_method("is_world_point_in_match_start_ring") \
		and bool(mounted_venue.is_world_point_in_match_start_ring(player_world_position))

func _ensure_play_surface_collision_isolation(ball_node: Node3D, _mounted_venue: Node3D) -> void:
	if ball_node == null or not (ball_node is CollisionObject3D):
		return
	var collision_object := ball_node as CollisionObject3D
	if collision_object.collision_layer != PLAY_SURFACE_COLLISION_LAYER_VALUE:
		collision_object.collision_layer = PLAY_SURFACE_COLLISION_LAYER_VALUE
	if collision_object.collision_mask != PLAY_SURFACE_COLLISION_LAYER_VALUE:
		collision_object.collision_mask = PLAY_SURFACE_COLLISION_LAYER_VALUE

func _reset_ball_to_server_anchor(ball_node: Node3D, mounted_venue: Node3D) -> void:
	if ball_node == null or mounted_venue == null:
		return
	var server_anchor := _resolve_current_server_anchor(mounted_venue)
	var ball_rest_world_position := _resolve_ball_rest_world_position(server_anchor, mounted_venue)
	if ball_node is Node3D:
		(ball_node as Node3D).global_position = ball_rest_world_position
	_freeze_ball(ball_node)
	_previous_ball_world_position = ball_rest_world_position
	_previous_ball_linear_velocity = Vector3.ZERO

func _snap_ball_to_server_anchor_if_idle(ball_node: Node3D, mounted_venue: Node3D) -> void:
	if ball_node == null or mounted_venue == null:
		return
	var server_anchor := _resolve_current_server_anchor(mounted_venue)
	var ball_rest_world_position := _resolve_ball_rest_world_position(server_anchor, mounted_venue)
	var ball_position := _get_ball_world_position(ball_node)
	if ball_position.distance_squared_to(ball_rest_world_position) > 0.004:
		if ball_node is Node3D:
			(ball_node as Node3D).global_position = ball_rest_world_position
	_freeze_ball(ball_node)
	_previous_ball_world_position = ball_rest_world_position
	_previous_ball_linear_velocity = Vector3.ZERO

func _freeze_ball(ball_node: Node3D) -> void:
	if not (ball_node is RigidBody3D):
		return
	var rigid_ball := ball_node as RigidBody3D
	rigid_ball.linear_velocity = Vector3.ZERO
	rigid_ball.angular_velocity = Vector3.ZERO
	rigid_ball.sleeping = true

func _resolve_current_server_anchor(mounted_venue: Node3D) -> Vector3:
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue != null and mounted_venue.has_method("get_tennis_court_contract") else {}
	var serve_from_deuce := ((_home_points + _away_points) % 2) == 0
	if _server_side == "home":
		var key := "home_deuce_server_anchor" if serve_from_deuce else "home_ad_server_anchor"
		return _extract_world_anchor(court_contract.get(key, {}))
	var away_key := "away_deuce_server_anchor" if serve_from_deuce else "away_ad_server_anchor"
	return _extract_world_anchor(court_contract.get(away_key, {}))

func _resolve_expected_service_box_id() -> String:
	var serve_from_deuce := ((_home_points + _away_points) % 2) == 0
	if _server_side == "home":
		return "service_box_deuce_away" if serve_from_deuce else "service_box_ad_away"
	return "service_box_deuce_home" if serve_from_deuce else "service_box_ad_home"

func _detect_bounce_event(mounted_venue: Node3D, ball_world_position: Vector3, ball_linear_velocity: Vector3) -> Dictionary:
	if mounted_venue == null or _bounce_cooldown_sec > 0.0:
		return {}
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var surface_top_y := float(court_contract.get("surface_top_y", ball_world_position.y))
	var threshold_y := surface_top_y + _ball_radius_m + BALL_CONTACT_EPSILON_M
	if _previous_ball_world_position == Vector3.ZERO:
		return {}
	var direct_cross := _previous_ball_world_position.y > threshold_y and ball_world_position.y <= threshold_y and ball_linear_velocity.y <= 0.25
	var rebound_near_surface := _previous_ball_linear_velocity.y < -0.6 \
		and ball_linear_velocity.y >= -0.05 \
		and minf(_previous_ball_world_position.y, ball_world_position.y) <= threshold_y + maxf(_ball_radius_m * 1.8, 0.36)
	_debug_last_bounce_probe = {
		"previous_ball_world_position": _previous_ball_world_position,
		"ball_world_position": ball_world_position,
		"previous_ball_linear_velocity": _previous_ball_linear_velocity,
		"ball_linear_velocity": ball_linear_velocity,
		"threshold_y": threshold_y,
		"direct_cross": direct_cross,
		"rebound_near_surface": rebound_near_surface,
		"target_bounce_count": _target_bounce_count,
		"planned_target_world_position": _planned_target_world_position,
		"planned_target_side": _planned_target_side,
	}
	if not direct_cross and not rebound_near_surface:
		return {}
	_bounce_cooldown_sec = BOUNCE_COOLDOWN_SEC
	var contact_world_position := _resolve_bounce_contact_world_position(mounted_venue, ball_world_position, direct_cross)
	var local_position := mounted_venue.to_local(contact_world_position)
	_debug_last_bounce_event = {
		"bounce_side": "home" if local_position.z >= 0.0 else "away",
		"contact_world_position": contact_world_position,
	}
	return {
		"bounce_side": "home" if local_position.z >= 0.0 else "away",
		"contact_world_position": contact_world_position,
	}

func _resolve_bounce_contact_world_position(mounted_venue: Node3D, ball_world_position: Vector3, direct_cross: bool) -> Vector3:
	if _target_bounce_count == 0 and _planned_target_world_position != Vector3.ZERO:
		var planned_contact_world_position := _planned_target_world_position
		planned_contact_world_position.y = _resolve_surface_top_y(mounted_venue, planned_contact_world_position.y) + _ball_radius_m
		return planned_contact_world_position
	var contact_world_position := _previous_ball_world_position.lerp(ball_world_position, 0.5)
	if direct_cross and absf(ball_world_position.y - _previous_ball_world_position.y) > 0.0001:
		var surface_top_y := _resolve_surface_top_y(mounted_venue, ball_world_position.y)
		var contact_plane_y := surface_top_y + _ball_radius_m
		var travel_fraction := clampf((contact_plane_y - _previous_ball_world_position.y) / (ball_world_position.y - _previous_ball_world_position.y), 0.0, 1.0)
		contact_world_position = _previous_ball_world_position.lerp(ball_world_position, travel_fraction)
	contact_world_position.y = _resolve_surface_top_y(mounted_venue, contact_world_position.y) + _ball_radius_m
	return contact_world_position

func _detect_net_fault(mounted_venue: Node3D, ball_world_position: Vector3) -> bool:
	if mounted_venue == null or _last_hitter_side == "":
		return false
	if _previous_ball_world_position == Vector3.ZERO:
		return false
	var previous_local := mounted_venue.to_local(_previous_ball_world_position)
	var current_local := mounted_venue.to_local(ball_world_position)
	if signf(previous_local.z) == signf(current_local.z) and absf(current_local.z) > 0.18:
		return false
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var crossing_y := current_local.y
	if absf(current_local.z - previous_local.z) > 0.0001:
		var t := clampf((-previous_local.z) / (current_local.z - previous_local.z), 0.0, 1.0)
		crossing_y = lerpf(previous_local.y, current_local.y, t)
	if absf(current_local.x) > float(court_contract.get("singles_width_m", 8.23)) * 0.5 + 0.4 and absf(previous_local.x) > float(court_contract.get("singles_width_m", 8.23)) * 0.5 + 0.4:
		return false
	return crossing_y <= float(court_contract.get("net_center_height_m", 0.914)) + _ball_radius_m - 0.02

func _ball_is_out_of_live_bounds(mounted_venue: Node3D, ball_world_position: Vector3) -> bool:
	if mounted_venue == null or _last_hitter_side == "":
		return false
	var local_position := mounted_venue.to_local(ball_world_position)
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var court_bounds: Dictionary = court_contract.get("court_bounds", {})
	var release_buffer_m := float(court_contract.get("release_buffer_m", LIVE_OUT_MARGIN_M + 18.0))
	var half_width := float(court_bounds.get("half_width_m", 4.115)) + release_buffer_m + LIVE_OUT_MARGIN_M
	var half_length := float(court_bounds.get("half_length_m", 11.885)) + release_buffer_m + LIVE_OUT_MARGIN_M
	if absf(local_position.x) <= half_width and absf(local_position.z) <= half_length:
		return false
	var surface_top_y := float(court_contract.get("surface_top_y", ball_world_position.y))
	_debug_last_live_out_world_position = ball_world_position
	return ball_world_position.y <= surface_top_y + 1.2

func _arm_ai_return() -> void:
	_ai_return_armed = true
	_ai_return_timer_sec = AI_RETURN_DELAY_SEC

func _execute_ai_serve(ball_node: Node3D, mounted_venue: Node3D) -> void:
	if ball_node == null or mounted_venue == null or _match_state != MATCH_STATE_PRE_SERVE or _server_side != "away":
		return
	var target_world_position := _resolve_service_target_world_position(mounted_venue, _expected_service_box_id)
	var launch_source := _resolve_serve_launch_source(mounted_venue)
	if not _launch_ball_to_target(ball_node, mounted_venue, launch_source, target_world_position, SERVE_DESIRED_SPEED_MPS):
		return
	_match_state = MATCH_STATE_SERVE_IN_FLIGHT
	_last_hitter_side = "away"
	_target_side = "home"
	_target_bounce_count = 0
	_ai_return_armed = false
	_ai_return_timer_sec = 0.0
	_register_opponent_swing("serve")
	_register_planned_target("home", target_world_position)
	_clear_receive_hint_state()
	_rally_shot_count = 1
	_strike_window_state = STRIKE_WINDOW_STATE_IDLE
	_strike_quality_feedback = "read_away_serve"
	_previous_ball_world_position = launch_source
	_previous_ball_linear_velocity = _get_ball_linear_velocity(ball_node)

func _execute_ai_return(ball_node: Node3D, mounted_venue: Node3D) -> void:
	_ai_return_armed = false
	if ball_node == null or mounted_venue == null or _match_state != MATCH_STATE_RALLY or _target_side != "away":
		return
	var ai_return_plan := _build_ai_return_plan(mounted_venue)
	var target_world_position := ai_return_plan.get("target_world_position", Vector3.ZERO) as Vector3
	var pressure_error_kind := str(ai_return_plan.get("pressure_error_kind", ""))
	var launch_source := _get_ball_world_position(ball_node)
	if not _launch_ball_to_target(ball_node, mounted_venue, launch_source, target_world_position, AI_RETURN_DESIRED_SPEED_MPS):
		return
	_last_hitter_side = "away"
	_target_side = "home"
	_target_bounce_count = 0
	_rally_shot_count += 1
	_register_opponent_swing(_resolve_opponent_swing_style(mounted_venue, target_world_position))
	_register_planned_target("home", target_world_position)
	if pressure_error_kind == "out":
		_clear_receive_hint_state()
		_strike_window_state = STRIKE_WINDOW_STATE_IDLE
		_strike_quality_feedback = "opponent_pressure_miss"
	else:
		_configure_receive_hint_for_home_return(mounted_venue, target_world_position)
		_strike_window_state = STRIKE_WINDOW_STATE_TRACKING
	_previous_ball_world_position = launch_source
	_previous_ball_linear_velocity = _get_ball_linear_velocity(ball_node)
	_ai_return_pattern_index += 1

func _handle_player_serve(ball_node: Node3D, mounted_venue: Node3D, player_node: Node3D, prop_id: String) -> Dictionary:
	_play_player_swing(player_node, "serve")
	var target_world_position := _resolve_service_target_world_position(mounted_venue, _expected_service_box_id)
	var launch_source := _resolve_serve_launch_source(mounted_venue)
	if not _launch_ball_to_target(ball_node, mounted_venue, launch_source, target_world_position, SERVE_DESIRED_SPEED_MPS):
		return _build_handled_interaction_result(false, "serve_launch_failed", prop_id)
	_match_state = MATCH_STATE_SERVE_IN_FLIGHT
	_last_hitter_side = _server_side
	_target_side = _resolve_other_side(_server_side)
	_target_bounce_count = 0
	_ai_return_armed = false
	_ai_return_timer_sec = 0.0
	_register_planned_target(_target_side, target_world_position)
	_clear_receive_hint_state()
	_rally_shot_count = 1
	_strike_window_state = STRIKE_WINDOW_STATE_IDLE
	_strike_quality_feedback = "control_serve"
	return _build_handled_interaction_result(true, "", prop_id, {
		"planned_target_world_position": target_world_position,
		"planned_target_side": _planned_target_side,
	})

func _handle_player_return(ball_node: Node3D, mounted_venue: Node3D, player_node: Node3D, prop_id: String) -> Dictionary:
	_play_player_swing(player_node, _resolve_player_swing_style(ball_node, player_node))
	var strike_eval := _evaluate_player_strike_window(ball_node, player_node, mounted_venue)
	if not bool(strike_eval.get("can_strike", false)):
		_strike_window_state = str(strike_eval.get("window_state", STRIKE_WINDOW_STATE_TRACKING))
		_strike_quality_feedback = str(strike_eval.get("feedback", "late"))
		return _build_handled_interaction_result(false, "strike_window_closed", prop_id, {
			"strike_window_state": _strike_window_state,
			"strike_quality_feedback": _strike_quality_feedback,
		})
	var target_world_position := _resolve_player_return_target_world_position(mounted_venue)
	var launch_source := _incoming_strike_world_position if _target_side == "home" and _target_bounce_count >= 1 and _home_receive_grace_sec > 0.0 and _incoming_strike_world_position != Vector3.ZERO else _get_ball_world_position(ball_node)
	if not _launch_ball_to_target(ball_node, mounted_venue, launch_source, target_world_position, PLAYER_RETURN_DESIRED_SPEED_MPS):
		return _build_handled_interaction_result(false, "return_launch_failed", prop_id)
	_last_hitter_side = "home"
	_target_side = "away"
	_target_bounce_count = 0
	_ai_return_armed = false
	_ai_return_timer_sec = 0.0
	_register_planned_target("away", target_world_position)
	_clear_receive_hint_state()
	_rally_shot_count += 1
	_strike_window_state = STRIKE_WINDOW_STATE_RECOVER
	_strike_quality_feedback = str(strike_eval.get("feedback", "good"))
	_previous_ball_world_position = launch_source
	_previous_ball_linear_velocity = _get_ball_linear_velocity(ball_node)
	return _build_handled_interaction_result(true, "", prop_id, {
		"planned_target_world_position": target_world_position,
		"planned_target_side": _planned_target_side,
		"strike_quality_feedback": _strike_quality_feedback,
	})

func _resolve_service_target_world_position(mounted_venue: Node3D, service_box_id: String) -> Vector3:
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue != null and mounted_venue.has_method("get_tennis_court_contract") else {}
	var service_boxes: Dictionary = court_contract.get("service_boxes", {})
	var service_box: Dictionary = service_boxes.get(service_box_id, {})
	var local_target := Vector3.ZERO
	if service_box.has("local_center"):
		local_target = service_box.get("local_center", Vector3.ZERO) as Vector3
	var shot_bias := _read_shot_bias_vector()
	var rect: Dictionary = service_box.get("rect", {})
	var rect_position := rect.get("position", Vector2.ZERO) as Vector2
	var rect_size := rect.get("size", Vector2.ZERO) as Vector2
	var margin_x := minf(rect_size.x * 0.18, 5.0)
	var margin_z := minf(rect_size.y * 0.18, 8.0)
	var x_min := rect_position.x + margin_x
	var x_max := rect_position.x + rect_size.x - margin_x
	var z_min := rect_position.y + margin_z
	var z_max := rect_position.y + rect_size.y - margin_z
	if absf(shot_bias.x) > 0.05:
		local_target.x = clampf(lerpf(local_target.x, x_max if shot_bias.x >= 0.0 else x_min, absf(shot_bias.x)), x_min, x_max)
	if absf(shot_bias.y) > 0.05:
		local_target.z = clampf(lerpf(local_target.z, z_max if shot_bias.y >= 0.0 else z_min, absf(shot_bias.y) * 0.55), z_min, z_max)
	return _to_world_bounce_target(mounted_venue, local_target)

func _resolve_player_return_target_world_position(mounted_venue: Node3D) -> Vector3:
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var court_bounds: Dictionary = court_contract.get("court_bounds", {})
	var half_width := float(court_bounds.get("half_width_m", 4.115))
	var half_length := float(court_bounds.get("half_length_m", 11.885))
	var service_line_distance_m := float(court_contract.get("service_line_distance_m", 6.40))
	var opponent_local := _extract_local_anchor(court_contract.get("away_baseline_anchor", {}), Vector3(0.0, 0.0, -half_length + 6.0))
	var shot_bias := _read_shot_bias_vector()
	var target_local := Vector3.ZERO
	target_local.x = half_width * 0.18 if opponent_local.x <= 0.0 else -half_width * 0.18
	if absf(shot_bias.x) > 0.05:
		target_local.x = clampf(shot_bias.x * half_width * 0.34, -half_width * 0.34, half_width * 0.34)
	var target_depth := clampf(absf(opponent_local.z) - 16.0, service_line_distance_m + 10.0, half_length - 18.0)
	target_local.z = -target_depth
	if absf(shot_bias.y) > 0.05:
		target_local.z = -clampf(target_depth + shot_bias.y * 5.0, service_line_distance_m + 9.0, half_length - 16.0)
	return _to_world_bounce_target(mounted_venue, target_local)

func _resolve_ai_return_target_world_position(mounted_venue: Node3D) -> Vector3:
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var court_bounds: Dictionary = court_contract.get("court_bounds", {})
	var half_width := float(court_bounds.get("half_width_m", 4.115))
	var half_length := float(court_bounds.get("half_length_m", 11.885))
	var service_line_distance_m := float(court_contract.get("service_line_distance_m", 6.40))
	var player_local := mounted_venue.to_local(_latest_player_world_position)
	var target_local := Vector3.ZERO
	if player_local.x < -half_width * 0.12:
		target_local.x = half_width * 0.24
	elif player_local.x > half_width * 0.12:
		target_local.x = -half_width * 0.24
	else:
		target_local.x = -half_width * 0.22 if (_ai_return_pattern_index % 2) == 0 else half_width * 0.22
	var target_depth := clampf(player_local.z - 5.5, service_line_distance_m + 6.0, half_length - 8.0)
	target_local.z = maxf(target_depth, half_length * 0.42)
	return _to_world_bounce_target(mounted_venue, target_local)

func _build_ai_return_plan(mounted_venue: Node3D) -> Dictionary:
	var safe_target_world_position := _resolve_ai_return_target_world_position(mounted_venue)
	var pressure_error_kind := _resolve_ai_pressure_error_kind()
	if pressure_error_kind != "out":
		return {
			"target_world_position": safe_target_world_position,
			"pressure_error_kind": "",
		}
	return {
		"target_world_position": _resolve_ai_pressure_out_target_world_position(mounted_venue, safe_target_world_position),
		"pressure_error_kind": pressure_error_kind,
	}

func _resolve_ai_pressure_error_kind() -> String:
	if _debug_forced_ai_pressure_error_kind == "disabled" or _debug_forced_ai_pressure_error_kind == "off" or _debug_forced_ai_pressure_error_kind == "none":
		return ""
	if _debug_forced_ai_pressure_error_kind != "":
		return _debug_forced_ai_pressure_error_kind
	if _rally_shot_count < 5:
		return ""
	return "out" if (_ai_return_pattern_index % 3) == 2 else ""

func _resolve_ai_pressure_out_target_world_position(mounted_venue: Node3D, safe_target_world_position: Vector3) -> Vector3:
	if mounted_venue == null:
		return safe_target_world_position
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var court_bounds: Dictionary = court_contract.get("court_bounds", {})
	var half_width := float(court_bounds.get("half_width_m", 4.115))
	var half_length := float(court_bounds.get("half_length_m", 11.885))
	var service_line_distance_m := float(court_contract.get("service_line_distance_m", 6.40))
	var safe_target_local := mounted_venue.to_local(safe_target_world_position)
	var error_target_local := safe_target_local
	if (_ai_return_pattern_index % 2) == 0:
		var sideline_sign := signf(error_target_local.x)
		if is_zero_approx(sideline_sign):
			sideline_sign = -1.0 if (int(_ai_return_pattern_index / 2) % 2) == 0 else 1.0
		error_target_local.x = sideline_sign * (half_width + 8.0)
		error_target_local.z = clampf(maxf(error_target_local.z, service_line_distance_m + 4.0), service_line_distance_m + 4.0, half_length - 6.0)
	else:
		error_target_local.x = clampf(error_target_local.x, -half_width * 0.24, half_width * 0.24)
		error_target_local.z = half_length + 8.0
	return _to_world_bounce_target(mounted_venue, error_target_local)

func _register_planned_target(target_side: String, target_world_position: Vector3) -> void:
	_planned_target_side = _normalize_side(target_side)
	_planned_target_world_position = target_world_position

func _set_player_racket_visible(player_node: Node3D, is_visible: bool) -> void:
	if player_node != null and is_instance_valid(player_node) and player_node.has_method("set_tennis_racket_visible"):
		player_node.set_tennis_racket_visible(is_visible)

func _play_player_swing(player_node: Node3D, swing_style: String) -> void:
	_player_swing_token += 1
	_player_swing_style = swing_style
	if player_node != null and is_instance_valid(player_node) and player_node.has_method("play_tennis_swing"):
		player_node.play_tennis_swing(swing_style)

func _register_opponent_swing(swing_style: String) -> void:
	_opponent_swing_token += 1
	_opponent_swing_style = swing_style

func _resolve_player_swing_style(ball_node: Node3D, player_node: Node3D) -> String:
	if ball_node == null or player_node == null:
		return "forehand"
	var local_delta := player_node.to_local(_get_ball_world_position(ball_node))
	if local_delta.x <= -0.7:
		return "backhand"
	if local_delta.x >= 0.7:
		return "forehand"
	return "backhand" if (_player_swing_token % 2) == 0 else "forehand"

func _resolve_opponent_swing_style(mounted_venue: Node3D, target_world_position: Vector3) -> String:
	if mounted_venue == null:
		return "backhand" if (_opponent_swing_token % 2) == 0 else "forehand"
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var default_anchor := _extract_local_anchor(court_contract.get("away_baseline_anchor", {}), Vector3.ZERO)
	var opponent_local_position := default_anchor
	var opponent_local_variant: Variant = _opponent_state.get("local_position", default_anchor)
	if opponent_local_variant is Vector3:
		opponent_local_position = opponent_local_variant as Vector3
	var target_local := mounted_venue.to_local(target_world_position)
	var lateral_delta := target_local.x - opponent_local_position.x
	if lateral_delta >= 1.6:
		return "backhand"
	if lateral_delta <= -1.6:
		return "forehand"
	return "backhand" if (_opponent_swing_token % 2) == 0 else "forehand"

func _emit_feedback_event(kind: String, text: String, tone: String = "neutral") -> void:
	var resolved_kind := kind.strip_edges()
	var resolved_text := text.strip_edges()
	if resolved_kind == "" or resolved_text == "":
		return
	_feedback_event_token += 1
	_feedback_event_kind = resolved_kind
	_feedback_event_text = resolved_text
	_feedback_event_tone = tone.strip_edges() if tone.strip_edges() != "" else "neutral"

func _build_match_state_text() -> String:
	match _match_state:
		MATCH_STATE_PRE_SERVE:
			return "准备发球"
		MATCH_STATE_SERVE_IN_FLIGHT:
			return "发球进行中"
		MATCH_STATE_RALLY:
			return "多拍回合"
		MATCH_STATE_POINT_RESULT:
			return _build_point_result_summary_text()
		MATCH_STATE_GAME_BREAK:
			return "局间准备"
		MATCH_STATE_FINAL:
			return "你赢了" if _winner_side == "home" else "你输了"
		_:
			return "等待开赛"

func _describe_point_end_reason(reason: String) -> String:
	match reason:
		"double_fault":
			return "双误"
		"fault":
			return "发球失误"
		"net":
			return "下网"
		"out":
			return "出界"
		"double_bounce":
			return "二次落地"
		"wrong_side_bounce":
			return "落点错区"
		"debug_point":
			return "测试得分"
		_:
			return "得分"

func _build_point_result_summary_text(winner_side: String = "", reason: String = "") -> String:
	var resolved_winner_side := _normalize_side(winner_side if winner_side != "" else _point_winner_side)
	var resolved_reason := reason if reason != "" else _point_end_reason
	var winner_text := "你" if resolved_winner_side == "home" else "对手"
	var loser_text := "对手" if resolved_winner_side == "home" else "你"
	match resolved_reason:
		"out":
			return "%s出界，%s得分" % [loser_text, winner_text]
		"net":
			return "%s下网，%s得分" % [loser_text, winner_text]
		"double_fault":
			return "%s双误，%s得分" % [loser_text, winner_text]
		"double_bounce":
			return "%s二次落地，%s得分" % [loser_text, winner_text]
		"wrong_side_bounce":
			return "%s落点错区，%s得分" % [loser_text, winner_text]
		"debug_point":
			return "%s测试得分" % winner_text
		_:
			return "%s得分" % winner_text

func _build_match_coach_text() -> String:
	match _match_state:
		MATCH_STATE_IDLE:
			return "走进启动环开始比赛"
		MATCH_STATE_PRE_SERVE:
			return "按 E 发球 | WASD 微调落点" if _server_side == "home" else "对手发球中，准备接球"
		MATCH_STATE_SERVE_IN_FLIGHT:
			return "发球已出手，准备下一拍"
		MATCH_STATE_RALLY:
			if _target_side == "home":
				match _strike_window_state:
					STRIKE_WINDOW_STATE_READY:
						return "进入蓝圈后按 E 回球"
					STRIKE_WINDOW_STATE_RECOVER:
						return "回位，准备下一拍"
					_:
						return "跟住蓝圈，等 READY 再按 E"
			if _target_side == "away":
				return "回球已过网，观察对手落点"
			return "保持站位，准备来球"
		MATCH_STATE_POINT_RESULT:
			return "本分结束：%s" % _build_point_result_summary_text()
		MATCH_STATE_GAME_BREAK:
			return "换发球，准备下一局"
		MATCH_STATE_FINAL:
			return "比赛结束，离开场地可重置"
		_:
			return ""

func _build_match_coach_tone() -> String:
	if _match_state == MATCH_STATE_FINAL:
		return "success" if _winner_side == "home" else "warning"
	if _match_state == MATCH_STATE_POINT_RESULT or _match_state == MATCH_STATE_GAME_BREAK:
		return "warning"
	if _match_state == MATCH_STATE_RALLY and _target_side == "home" and _strike_window_state == STRIKE_WINDOW_STATE_READY:
		return "success"
	if _match_state == MATCH_STATE_PRE_SERVE or (_match_state == MATCH_STATE_RALLY and _target_side == "home"):
		return "action"
	return "neutral"

func _configure_receive_hint_for_home_return(mounted_venue: Node3D, landing_world_position: Vector3) -> void:
	_landing_marker_visible = true
	var player_local := mounted_venue.to_local(_latest_player_world_position)
	var landing_local := mounted_venue.to_local(landing_world_position)
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var court_bounds: Dictionary = court_contract.get("court_bounds", {})
	var half_width := float(court_bounds.get("half_width_m", 4.115))
	var half_length := float(court_bounds.get("half_length_m", 11.885))
	var strike_local := landing_local
	strike_local.x = clampf(lerpf(landing_local.x, player_local.x, PLAYER_STRIKE_SLOT_BLEND * 0.25), -half_width * 0.46, half_width * 0.46)
	strike_local.z = clampf(landing_local.z + PLAYER_STRIKE_SLOT_MIN_AHEAD_M, 0.0, half_length - 3.2)
	_incoming_strike_world_position = _to_world_bounce_target(mounted_venue, strike_local)
	_landing_marker_world_position = _incoming_strike_world_position
	_auto_footwork_assist_state = AUTO_FOOTWORK_STATE_TRACKING

func _clear_receive_hint_state() -> void:
	_landing_marker_visible = false
	_landing_marker_world_position = Vector3.ZERO
	_incoming_strike_world_position = Vector3.ZERO
	_auto_footwork_assist_state = AUTO_FOOTWORK_STATE_IDLE
	_home_receive_grace_sec = 0.0
	if _strike_window_state == STRIKE_WINDOW_STATE_TRACKING or _strike_window_state == STRIKE_WINDOW_STATE_RECOVER:
		_strike_window_state = STRIKE_WINDOW_STATE_IDLE

func _evaluate_player_strike_window(ball_node: Node3D, player_node: Node3D, mounted_venue: Node3D) -> Dictionary:
	if ball_node == null or player_node == null or mounted_venue == null:
		return {
			"can_strike": false,
			"window_state": STRIKE_WINDOW_STATE_IDLE,
			"feedback": "late",
		}
	var ball_world_position := _get_ball_world_position(ball_node)
	var planar_distance_to_player := Vector2(
		ball_world_position.x - player_node.global_position.x,
		ball_world_position.z - player_node.global_position.z
	).length()
	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
	var surface_top_y := float(court_contract.get("surface_top_y", ball_world_position.y))
	var relative_height := ball_world_position.y - surface_top_y
	var planar_distance_to_slot := Vector2(
		ball_world_position.x - _incoming_strike_world_position.x,
		ball_world_position.z - _incoming_strike_world_position.z
	).length()
	var ball_local_position := mounted_venue.to_local(ball_world_position)
	var slot_local_position := mounted_venue.to_local(_incoming_strike_world_position)
	var in_post_bounce_receive_window := _target_side == "home" \
		and _target_bounce_count >= 1 \
		and _home_receive_grace_sec > 0.0 \
		and player_node.global_position.distance_to(_incoming_strike_world_position) <= PLAYER_RECEIVE_MARKER_RADIUS_M
	if in_post_bounce_receive_window:
		return {
			"can_strike": true,
			"window_state": STRIKE_WINDOW_STATE_READY,
			"feedback": "pickup",
		}
	var can_strike := planar_distance_to_player <= PLAYER_STRIKE_RADIUS_M \
		and planar_distance_to_slot <= PLAYER_STRIKE_RADIUS_M * 1.1 \
		and relative_height >= PLAYER_STRIKE_HEIGHT_MIN_M \
		and relative_height <= PLAYER_STRIKE_HEIGHT_MAX_M
	if can_strike:
		var feedback := "perfect" if planar_distance_to_slot <= 1.1 else ("good" if planar_distance_to_slot <= 2.2 else "stretch")
		return {
			"can_strike": true,
			"window_state": STRIKE_WINDOW_STATE_READY,
			"feedback": feedback,
		}
	if ball_local_position.z < slot_local_position.z + 0.6:
		return {
			"can_strike": false,
			"window_state": STRIKE_WINDOW_STATE_TRACKING,
			"feedback": "early",
		}
	return {
		"can_strike": false,
		"window_state": STRIKE_WINDOW_STATE_TRACKING,
		"feedback": "late",
	}

func _launch_ball_to_target(ball_node: Node3D, mounted_venue: Node3D, source_world_position: Vector3, target_world_position: Vector3, desired_speed_mps: float) -> bool:
	if not (ball_node is RigidBody3D) or mounted_venue == null:
		return false
	var rigid_ball := ball_node as RigidBody3D
	var horizontal_distance := Vector2(target_world_position.x - source_world_position.x, target_world_position.z - source_world_position.z).length()
	var travel_time_sec := clampf(horizontal_distance / maxf(desired_speed_mps, 1.0), MIN_SHOT_TRAVEL_TIME_SEC, MAX_SHOT_TRAVEL_TIME_SEC)
	var velocity := _solve_ballistic_velocity(source_world_position, target_world_position, travel_time_sec)
	if _shot_crosses_net(mounted_venue, source_world_position, target_world_position):
		var court_contract: Dictionary = mounted_venue.get_tennis_court_contract() if mounted_venue.has_method("get_tennis_court_contract") else {}
		var net_clearance_height := float(court_contract.get("net_center_height_m", 0.914)) + _ball_radius_m + 0.45
		var crossing_height := _estimate_net_crossing_height(mounted_venue, source_world_position, target_world_position, velocity, travel_time_sec)
		while crossing_height < net_clearance_height and travel_time_sec < MAX_SHOT_TRAVEL_TIME_SEC:
			travel_time_sec = minf(travel_time_sec + 0.14, MAX_SHOT_TRAVEL_TIME_SEC)
			velocity = _solve_ballistic_velocity(source_world_position, target_world_position, travel_time_sec)
			crossing_height = _estimate_net_crossing_height(mounted_venue, source_world_position, target_world_position, velocity, travel_time_sec)
	if ball_node is Node3D:
		(ball_node as Node3D).global_position = source_world_position
	rigid_ball.sleeping = false
	rigid_ball.linear_damp = 0.0
	rigid_ball.angular_damp = 0.0
	rigid_ball.linear_velocity = velocity
	rigid_ball.angular_velocity = Vector3.ZERO
	_previous_ball_world_position = source_world_position
	_previous_ball_linear_velocity = velocity
	return true

func _solve_ballistic_velocity(source_world_position: Vector3, target_world_position: Vector3, travel_time_sec: float) -> Vector3:
	var resolved_time := maxf(travel_time_sec, 0.05)
	var delta := target_world_position - source_world_position
	var gravity_mps2 := _resolve_gravity_mps2()
	return Vector3(
		delta.x / resolved_time,
		(delta.y + 0.5 * gravity_mps2 * resolved_time * resolved_time) / resolved_time,
		delta.z / resolved_time
	)

func _estimate_net_crossing_height(mounted_venue: Node3D, source_world_position: Vector3, target_world_position: Vector3, launch_velocity: Vector3, travel_time_sec: float) -> float:
	var source_local := mounted_venue.to_local(source_world_position)
	var target_local := mounted_venue.to_local(target_world_position)
	if is_zero_approx(target_local.z - source_local.z):
		return source_local.y
	var fraction := clampf((-source_local.z) / (target_local.z - source_local.z), 0.0, 1.0)
	var time_to_cross := travel_time_sec * fraction
	return source_local.y + launch_velocity.y * time_to_cross - 0.5 * _resolve_gravity_mps2() * time_to_cross * time_to_cross

func _shot_crosses_net(mounted_venue: Node3D, source_world_position: Vector3, target_world_position: Vector3) -> bool:
	if mounted_venue == null:
		return false
	var source_local := mounted_venue.to_local(source_world_position)
	var target_local := mounted_venue.to_local(target_world_position)
	return signf(source_local.z) != signf(target_local.z)

func _resolve_ball_rest_world_position(server_anchor: Vector3, mounted_venue: Node3D) -> Vector3:
	var surface_top_y := _resolve_surface_top_y(mounted_venue, server_anchor.y)
	return Vector3(server_anchor.x, surface_top_y + SERVE_READY_BALL_HEIGHT_M, server_anchor.z)

func _resolve_serve_launch_source(mounted_venue: Node3D) -> Vector3:
	var server_anchor := _resolve_current_server_anchor(mounted_venue)
	return _resolve_ball_rest_world_position(server_anchor, mounted_venue)

func _resolve_surface_top_y(mounted_venue: Node3D, fallback_value: float) -> float:
	if mounted_venue != null and mounted_venue.has_method("get_tennis_court_contract"):
		var court_contract: Dictionary = mounted_venue.get_tennis_court_contract()
		return float(court_contract.get("surface_top_y", fallback_value))
	return fallback_value

func _to_world_bounce_target(mounted_venue: Node3D, local_target: Vector3) -> Vector3:
	var world_target := mounted_venue.to_global(local_target)
	world_target.y = _resolve_surface_top_y(mounted_venue, world_target.y) + _ball_radius_m
	return world_target

func _build_handled_interaction_result(success: bool, error: String, prop_id: String, extras: Dictionary = {}) -> Dictionary:
	var result := {
		"handled": true,
		"success": success,
		"error": error,
		"prop_id": prop_id,
		"interaction_kind": "swing",
	}
	for key_variant in extras.keys():
		result[key_variant] = extras.get(key_variant)
	return result

func _read_shot_bias_vector() -> Vector2:
	var bias := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		bias.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		bias.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		bias.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		bias.y -= 1.0
	return bias.normalized() if bias.length_squared() > 0.0001 else Vector2.ZERO

func _resolve_gravity_mps2() -> float:
	var gravity_setting: Variant = ProjectSettings.get_setting("physics/3d/default_gravity", DEFAULT_GRAVITY_MPS2)
	return float(gravity_setting)

func _point_count_to_label(point_count: int) -> String:
	match point_count:
		0:
			return "0"
		1:
			return "15"
		2:
			return "30"
		_:
			return "40"

func _is_game_won() -> bool:
	return _home_points >= 4 or _away_points >= 4

func _is_match_complete() -> bool:
	return _home_games >= MATCH_GAMES_TO_WIN or _away_games >= MATCH_GAMES_TO_WIN

func _has_dirty_match_session() -> bool:
	return _match_state != MATCH_STATE_IDLE \
		or _home_games > 0 \
		or _away_games > 0 \
		or _home_points > 0 \
		or _away_points > 0 \
		or _winner_side != ""

func _resolve_other_side(side: String) -> String:
	return "away" if side == "home" else "home"

func _normalize_side(side: String) -> String:
	var normalized_side := str(side).strip_edges().to_lower()
	if normalized_side == "home" or normalized_side == "away":
		return normalized_side
	return ""

func _resolve_entry_world_position(entry: Dictionary) -> Vector3:
	var world_position_variant: Variant = entry.get("world_position", Vector3.ZERO)
	if world_position_variant is Vector3:
		return world_position_variant as Vector3
	return Vector3.ZERO

func _extract_world_anchor(anchor_variant: Variant, fallback_value: Vector3 = Vector3.ZERO) -> Vector3:
	if anchor_variant is Dictionary:
		var anchor: Dictionary = anchor_variant
		var world_position_variant: Variant = anchor.get("world_position", fallback_value)
		if world_position_variant is Vector3:
			return world_position_variant as Vector3
	if anchor_variant is Vector3:
		return anchor_variant as Vector3
	return fallback_value

func _extract_local_anchor(anchor_variant: Variant, fallback_value: Vector3 = Vector3.ZERO) -> Vector3:
	if anchor_variant is Dictionary:
		var anchor: Dictionary = anchor_variant
		var local_position_variant: Variant = anchor.get("local_position", fallback_value)
		if local_position_variant is Vector3:
			return local_position_variant as Vector3
	if anchor_variant is Vector3:
		return anchor_variant as Vector3
	return fallback_value

func _build_default_opponent_state() -> Dictionary:
	return {
		"local_position": Vector3(0.0, 0.0, -9.2),
		"facing_direction": Vector3(0.0, 0.0, 1.0),
		"animation_state": "idle",
		"racket_visible": true,
		"swing_token": 0,
		"swing_style": "",
	}

func _get_ball_world_position(ball_node: Node3D) -> Vector3:
	return ball_node.global_position if ball_node != null else Vector3.ZERO

func _get_ball_linear_velocity(ball_node: Node3D) -> Vector3:
	if ball_node is RigidBody3D:
		return (ball_node as RigidBody3D).linear_velocity
	return Vector3.ZERO
