extends RefCounted

const DEFAULT_RELEASE_BUFFER_M := 24.0
const GOAL_RESULT_LINGER_SEC := 0.18
const OUT_OF_BOUNDS_LINGER_SEC := 0.12
const RESETTING_LINGER_SEC := 0.08
const IN_PLAY_SPEED_THRESHOLD_MPS := 0.35
const IN_PLAY_DISTANCE_THRESHOLD_M := 0.45
const DEFAULT_BALL_CENTER_OFFSET := Vector3(0.0, 0.6, 0.0)
const ACTIVE_VENUE_SCAN_RADIUS_M := 768.0

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
var _scoreboard_state := {
	"home_score": 0,
	"away_score": 0,
	"game_state": "idle",
	"game_state_label": "READY",
	"last_scored_side": "",
}

func configure(entries: Dictionary) -> void:
	_entries_by_venue_id = entries.duplicate(true)
	_kickoff_ball_offset = DEFAULT_BALL_CENTER_OFFSET
	_has_kickoff_ball_offset = false
	_kickoff_surface_sync_ball_instance_id = 0
	_kickoff_surface_synced = false
	if _active_venue_id == "" or not _entries_by_venue_id.has(_active_venue_id):
		_active_venue_id = _resolve_default_venue_id()

func update(chunk_renderer: Node, player_node: Node3D, delta: float) -> Dictionary:
	var entry := _resolve_active_entry()
	if entry.is_empty():
		_ball_bound = false
		_bound_ball_prop_id = ""
		_ambient_simulation_frozen = false
		_kickoff_surface_sync_ball_instance_id = 0
		_kickoff_surface_synced = false
		_refresh_scoreboard_state()
		return get_state()
	if not _is_player_near_active_venue(entry, player_node):
		_ball_bound = false
		_bound_ball_prop_id = str(entry.get("primary_ball_prop_id", "")).strip_edges()
		_ambient_simulation_frozen = false
		_kickoff_surface_sync_ball_instance_id = 0
		_kickoff_surface_synced = false
		_refresh_scoreboard_state()
		return get_state()
	var mounted_venue := _resolve_mounted_venue(chunk_renderer, entry)
	var ball_node := _resolve_bound_ball(chunk_renderer, entry)
	var kickoff_anchor := _resolve_kickoff_anchor(entry, mounted_venue)
	_ensure_play_surface_collision_isolation(ball_node, mounted_venue)
	_refresh_kickoff_surface_sync_tracking(ball_node)
	_capture_kickoff_ball_offset(ball_node, kickoff_anchor)
	_update_ambient_freeze(player_node, mounted_venue)
	if mounted_venue == null or ball_node == null:
		_refresh_scoreboard_state()
		return get_state()
	_maybe_sync_ball_to_kickoff_surface(ball_node, kickoff_anchor)

	var ball_world_position := _get_ball_world_position(ball_node)
	var ball_linear_velocity := _get_ball_linear_velocity(ball_node)
	match _game_state:
		"goal_scored":
			_state_timer_sec = maxf(_state_timer_sec - maxf(delta, 0.0), 0.0)
			if _state_timer_sec <= 0.0:
				_perform_ball_reset(ball_node, kickoff_anchor)
				_set_game_state("resetting", RESETTING_LINGER_SEC)
		"out_of_bounds":
			_state_timer_sec = maxf(_state_timer_sec - maxf(delta, 0.0), 0.0)
			if _state_timer_sec <= 0.0:
				_perform_ball_reset(ball_node, kickoff_anchor)
				_set_game_state("resetting", RESETTING_LINGER_SEC)
		"resetting":
			_state_timer_sec = maxf(_state_timer_sec - maxf(delta, 0.0), 0.0)
			if _state_timer_sec <= 0.0:
				_set_game_state("idle", 0.0)
		_:
			var goal_event := _resolve_goal_event(mounted_venue, ball_world_position, ball_linear_velocity)
			if not goal_event.is_empty():
				_apply_goal_event(goal_event)
			elif _is_ball_out_of_bounds(mounted_venue, ball_world_position):
				_last_result_state = "out_of_bounds"
				_set_game_state("out_of_bounds", OUT_OF_BOUNDS_LINGER_SEC)
			elif _game_state == "idle" and _is_ball_in_play(ball_world_position, ball_linear_velocity, kickoff_anchor):
				_set_game_state("in_play", 0.0)
			elif _game_state == "in_play" and ball_linear_velocity.length() <= 0.01 and ball_world_position.distance_to(kickoff_anchor + _kickoff_ball_offset) <= 0.12:
				_set_game_state("idle", 0.0)

	_last_ball_world_position = ball_world_position
	_refresh_scoreboard_state()
	_sync_scoreboard_display(mounted_venue)
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
	}

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
	_last_ball_world_position = world_position
	if _game_state == "idle" and (linear_velocity.length() > 0.0 or world_position.distance_to(_resolve_kickoff_anchor(entry, _resolve_mounted_venue(chunk_renderer, entry)) + _kickoff_ball_offset) > 0.05):
		_set_game_state("in_play", 0.0)
	_refresh_scoreboard_state()
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
	_perform_ball_reset(ball_node, _resolve_kickoff_anchor(entry, _resolve_mounted_venue(chunk_renderer, entry)))
	_set_game_state("idle", 0.0)
	_refresh_scoreboard_state()
	return {"success": true}

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
		var kickoff_anchor_variant: Variant = surface_contract.get("kickoff_anchor", Vector3.ZERO)
		if kickoff_anchor_variant is Vector3:
			return kickoff_anchor_variant as Vector3
	var kickoff_anchor_variant: Variant = entry.get("world_position", Vector3.ZERO)
	if kickoff_anchor_variant is Vector3:
		return kickoff_anchor_variant as Vector3
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

func _resolve_goal_event(mounted_venue: Node3D, ball_world_position: Vector3, ball_linear_velocity: Vector3) -> Dictionary:
	if mounted_venue == null or not mounted_venue.has_method("evaluate_goal_hit"):
		return {}
	var goal_event: Dictionary = mounted_venue.evaluate_goal_hit(ball_world_position, ball_linear_velocity)
	return goal_event.duplicate(true)

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
	elif scoring_side == "away":
		_away_score += 1
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
		"game_state_label": _build_game_state_label(),
		"last_scored_side": _last_scored_side,
	}

func _sync_scoreboard_display(mounted_venue: Node3D) -> void:
	if mounted_venue == null or not mounted_venue.has_method("set_scoreboard_state"):
		return
	mounted_venue.set_scoreboard_state(_scoreboard_state.duplicate(true))

func _build_game_state_label() -> String:
	match _game_state:
		"in_play":
			return "IN PLAY"
		"goal_scored":
			if _last_scored_side == "home":
				return "GOAL HOME"
			if _last_scored_side == "away":
				return "GOAL AWAY"
			return "GOAL"
		"out_of_bounds":
			return "OUT"
		"resetting":
			return "RESET"
		_:
			return "READY"

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
