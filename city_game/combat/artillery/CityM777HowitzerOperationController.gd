extends RefCounted

const HOWITZER_PROMPT_TEXT := "按 E 操作炮"
const HOWITZER_CONTROL_HINT_TEXT := "按 E 退出操炮  J/L 方位  I/K 高低  Space 击发  R 复位"
const HOWITZER_IDLE_HINT_TEXT := "WASD 移动  鼠标观察  R 复位"
const HOWITZER_NEARBY_HINT_TEXT := "WASD 移动  鼠标观察  E 操炮  R 复位"
const HOWITZER_OPERATION_ID := "m777_howitzer"

var yaw_speed_deg_per_sec := 28.0
var pitch_speed_deg_per_sec := 18.0
var interaction_radius_m := 7.0
var operation_release_radius_m := 20.0

var _howitzer: Node3D = null
var _player: Node3D = null
var _operation_active := false
var _last_interaction_distance_m := INF

func configure(howitzer: Node3D, player: Node3D, config: Dictionary = {}) -> void:
	_howitzer = howitzer
	_player = player
	yaw_speed_deg_per_sec = float(config.get("yaw_speed_deg_per_sec", yaw_speed_deg_per_sec))
	pitch_speed_deg_per_sec = float(config.get("pitch_speed_deg_per_sec", pitch_speed_deg_per_sec))
	interaction_radius_m = maxf(float(config.get("interaction_radius_m", interaction_radius_m)), 0.1)
	operation_release_radius_m = maxf(float(config.get("operation_release_radius_m", operation_release_radius_m)), interaction_radius_m)
	refresh_context()
	_sync_howitzer_operator_lanyard_target()

func update(delta: float, prompt_blocked: bool = false) -> void:
	refresh_context()
	_sync_howitzer_operator_lanyard_target()
	if prompt_blocked or not _operation_active:
		return
	var yaw_input := 0.0
	if Input.is_key_pressed(KEY_J):
		yaw_input -= 1.0
	if Input.is_key_pressed(KEY_L):
		yaw_input += 1.0
	var pitch_input := 0.0
	if Input.is_key_pressed(KEY_I):
		pitch_input += 1.0
	if Input.is_key_pressed(KEY_K):
		pitch_input -= 1.0
	if absf(yaw_input) > 0.001:
		adjust_yaw_degrees(yaw_input * yaw_speed_deg_per_sec * maxf(delta, 0.0))
	if absf(pitch_input) > 0.001:
		adjust_pitch_degrees(pitch_input * pitch_speed_deg_per_sec * maxf(delta, 0.0))

func refresh_context() -> void:
	_last_interaction_distance_m = _resolve_howitzer_distance_m()
	var resolved_release_radius_m := maxf(operation_release_radius_m, interaction_radius_m)
	if _operation_active and _last_interaction_distance_m > resolved_release_radius_m:
		_set_operation_active(false)

func request_primary_interaction() -> Dictionary:
	refresh_context()
	if _operation_active:
		_set_operation_active(false)
		return {
			"success": true,
			"handled": true,
			"action": "exit_operation",
		}
	if _last_interaction_distance_m > interaction_radius_m:
		return {
			"success": false,
			"handled": false,
			"error": "out_of_range",
			"distance_m": _last_interaction_distance_m,
		}
	_set_operation_active(true)
	return {
		"success": true,
		"handled": true,
		"action": "enter_operation",
	}

func request_fire() -> Dictionary:
	refresh_context()
	if not _operation_active:
		return {
			"accepted": false,
			"handled": false,
			"error": "operation_inactive",
		}
	if _player != null and _player.has_method("consume_jump_input_once"):
		_player.consume_jump_input_once()
	if _howitzer == null or not is_instance_valid(_howitzer) or not _howitzer.has_method("request_fire"):
		return {
			"accepted": false,
			"handled": true,
			"error": "fire_api_unavailable",
		}
	var result := (_howitzer.request_fire() as Dictionary).duplicate(true)
	result["handled"] = true
	return result

func adjust_yaw_degrees(delta_deg: float) -> void:
	if _howitzer == null or not is_instance_valid(_howitzer):
		return
	if not _howitzer.has_method("set_yaw_degrees") or not _howitzer.has_method("get_yaw_degrees"):
		return
	_howitzer.set_yaw_degrees(float(_howitzer.get_yaw_degrees()) + delta_deg)

func adjust_pitch_degrees(delta_deg: float) -> void:
	if _howitzer == null or not is_instance_valid(_howitzer):
		return
	if not _howitzer.has_method("set_pitch_degrees") or not _howitzer.has_method("get_pitch_degrees"):
		return
	_howitzer.set_pitch_degrees(float(_howitzer.get_pitch_degrees()) + delta_deg)

func reset_operation() -> void:
	_set_operation_active(false)

func get_operation_state() -> Dictionary:
	var resolved_release_radius_m := maxf(operation_release_radius_m, interaction_radius_m)
	return {
		"active": _operation_active,
		"within_interaction_range": _last_interaction_distance_m <= interaction_radius_m,
		"within_operation_release_range": _last_interaction_distance_m <= resolved_release_radius_m,
		"distance_m": 0.0 if not is_finite(_last_interaction_distance_m) else snappedf(_last_interaction_distance_m, 0.01),
		"interaction_radius_m": interaction_radius_m,
		"operation_release_radius_m": resolved_release_radius_m,
	}

func get_interaction_prompt_state(prompt_blocked: bool = false) -> Dictionary:
	if prompt_blocked:
		return _build_hidden_interaction_prompt_state()
	if _operation_active:
		return {
			"visible": true,
			"owner_kind": "artillery",
			"prop_id": HOWITZER_OPERATION_ID,
			"display_name": "M777 Howitzer",
			"interaction_kind": "operate_artillery",
			"prompt_text": _build_operation_prompt_text(),
			"distance_m": snappedf(_last_interaction_distance_m, 0.01),
		}
	if _last_interaction_distance_m > interaction_radius_m:
		return _build_hidden_interaction_prompt_state()
	return {
		"visible": true,
		"owner_kind": "artillery",
		"prop_id": HOWITZER_OPERATION_ID,
		"display_name": "M777 Howitzer",
		"interaction_kind": "operate_artillery",
		"prompt_text": HOWITZER_PROMPT_TEXT,
		"distance_m": snappedf(_last_interaction_distance_m, 0.01),
	}

func get_artillery_solution_state(prompt_blocked: bool = false) -> Dictionary:
	if prompt_blocked or not _operation_active:
		return _build_hidden_artillery_solution_state()
	if _howitzer == null or not is_instance_valid(_howitzer) or not _howitzer.has_method("get_firing_solution_snapshot"):
		return _build_hidden_artillery_solution_state()
	var firing_solution := (_howitzer.get_firing_solution_snapshot() as Dictionary).duplicate(true)
	if firing_solution.is_empty():
		return _build_hidden_artillery_solution_state()
	return {
		"visible": true,
		"title": "射击诸元",
		"yaw_label_text": "方位",
		"pitch_label_text": "高低",
		"yaw_bearing_deg": float(firing_solution.get("world_bearing_deg", 0.0)),
		"pitch_deg": float(firing_solution.get("pitch_deg", 0.0)),
		"pitch_min_deg": float(firing_solution.get("pitch_min_deg", 0.0)),
		"pitch_max_deg": float(firing_solution.get("pitch_max_deg", 71.0)),
	}

func get_status_text(prompt_blocked: bool = false) -> String:
	if prompt_blocked:
		return ""
	if _operation_active:
		return _build_operation_prompt_text()
	if _last_interaction_distance_m <= interaction_radius_m:
		return HOWITZER_NEARBY_HINT_TEXT
	return HOWITZER_IDLE_HINT_TEXT

func _build_hidden_interaction_prompt_state() -> Dictionary:
	return {
		"visible": false,
		"owner_kind": "artillery",
		"prop_id": HOWITZER_OPERATION_ID,
		"display_name": "M777 Howitzer",
		"interaction_kind": "operate_artillery",
		"prompt_text": "",
		"distance_m": 0.0,
	}

func _build_hidden_artillery_solution_state() -> Dictionary:
	return {
		"visible": false,
		"title": "射击诸元",
		"yaw_label_text": "方位",
		"pitch_label_text": "高低",
		"yaw_bearing_deg": 0.0,
		"pitch_deg": 0.0,
		"pitch_min_deg": 0.0,
		"pitch_max_deg": 71.0,
	}

func _build_operation_prompt_text() -> String:
	return "%s\n%s" % [
		HOWITZER_CONTROL_HINT_TEXT,
		_build_fire_readiness_text(),
	]

func _build_fire_readiness_text() -> String:
	var fire_state := _resolve_howitzer_fire_state()
	if fire_state.is_empty():
		return "击发接口未就绪"
	if bool(fire_state.get("can_fire", false)):
		return "可击发"
	return "装填中 %.1fs..." % maxf(float(fire_state.get("cooldown_sec", 0.0)), 0.0)

func _resolve_howitzer_fire_state() -> Dictionary:
	if _howitzer != null and is_instance_valid(_howitzer) and _howitzer.has_method("get_fire_state"):
		return (_howitzer.get_fire_state() as Dictionary).duplicate(true)
	return {}

func _resolve_howitzer_distance_m() -> float:
	if _player == null or not is_instance_valid(_player) or _howitzer == null or not is_instance_valid(_howitzer):
		return INF
	var anchor_world_position := _resolve_interaction_anchor_world_position()
	var player_position := _player.global_position
	return Vector2(player_position.x - anchor_world_position.x, player_position.z - anchor_world_position.z).length()

func _resolve_interaction_anchor_world_position() -> Vector3:
	if _howitzer != null and is_instance_valid(_howitzer):
		var yaw_anchor := _howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
		if yaw_anchor != null:
			return yaw_anchor.global_position
		return _howitzer.global_position
	return Vector3.ZERO

func _set_operation_active(active: bool) -> void:
	_operation_active = active
	_sync_howitzer_operator_lanyard_target()

func _sync_howitzer_operator_lanyard_target() -> void:
	if _howitzer == null or not is_instance_valid(_howitzer):
		return
	if _operation_active:
		if _howitzer.has_method("set_operator_lanyard_target_world_position"):
			_howitzer.set_operator_lanyard_target_world_position(_resolve_player_lanyard_target_world_position())
		return
	if _howitzer.has_method("clear_operator_lanyard_target_world_position"):
		_howitzer.clear_operator_lanyard_target_world_position()

func _resolve_player_lanyard_target_world_position() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		return Vector3.ZERO
	if _player.has_method("get_bite_feedback_world_position"):
		return _player.get_bite_feedback_world_position()
	return _player.global_position + Vector3.UP * 1.05
