extends Node3D

const CityCompassStripScript := preload("res://city_game/ui/CityCompassStrip.gd")
const CityWorldOrientationScript := preload("res://city_game/world/navigation/CityWorldOrientation.gd")
const HOWITZER_PROMPT_TEXT := "按 E 操作炮"
const HOWITZER_CONTROL_HINT_TEXT := "按 E 退出操炮  J/L 方位  I/K 高低  Space 击发  R 复位"
const HOWITZER_IDLE_HINT_TEXT := "WASD 移动  鼠标观察  R 复位"
const HOWITZER_NEARBY_HINT_TEXT := "WASD 移动  鼠标观察  E 操炮  R 复位"
const HOWITZER_OPERATION_ID := "m777_howitzer"

@export var yaw_speed_deg_per_sec := 28.0
@export var pitch_speed_deg_per_sec := 18.0
@export var neutral_yaw_deg := 0.0
@export var neutral_pitch_deg := 0.0
@export var interaction_radius_m := 7.0
@export var operation_release_radius_m := 20.0

@onready var _howitzer := $ArtilleryRoot/Howitzer as Node3D
@onready var _player := $Player as CharacterBody3D
@onready var _player_camera_rig := $Player/CameraRig as Node3D
@onready var _player_camera := $Player/CameraRig/Camera3D as Camera3D
@onready var _overview_camera_rig := $LabCameraRig as Node3D
@onready var _overview_camera := $LabCameraRig/Camera3D as Camera3D
@onready var _hud := $Hud as CanvasLayer
@onready var _status_label := $Hud/Root/Panel/VBox/Status as Label
@onready var _debug_text := $Hud/Root/Panel/VBox/DebugText as Label
@onready var _hud_root := $Hud/Root as Control

var _initial_player_position := Vector3.ZERO
var _initial_player_rotation := Vector3.ZERO
var _initial_player_camera_rig_rotation := Vector3.ZERO
var _world_orientation = CityWorldOrientationScript.new()
var _compass_state: Dictionary = {}
var _interaction_prompt_state: Dictionary = _build_hidden_interaction_prompt_state()
var _operation_active := false
var _last_interaction_distance_m := INF

func _ready() -> void:
	_ensure_compass_view()
	_capture_initial_player_state()
	reset_lab_state()
	_focus_overview_camera()
	_refresh_hud()

func _process(delta: float) -> void:
	_refresh_operation_context()
	_sync_howitzer_operator_lanyard_target()
	if _operation_active:
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
			adjust_yaw_degrees(yaw_input * yaw_speed_deg_per_sec * delta)
		if absf(pitch_input) > 0.001:
			adjust_pitch_degrees(pitch_input * pitch_speed_deg_per_sec * delta)
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_E:
		var interaction_result := request_primary_interaction()
		if bool(interaction_result.get("handled", false)):
			get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_SPACE:
		var fire_result := request_fire()
		if bool(fire_result.get("handled", false)):
			get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_R:
		reset_lab_state()
		get_viewport().set_input_as_handled()

func get_howitzer() -> Node3D:
	return _howitzer

func get_lab_state() -> Dictionary:
	var yaw_deg := 0.0
	var pitch_deg := 0.0
	if _howitzer != null and _howitzer.has_method("get_yaw_degrees"):
		yaw_deg = _howitzer.get_yaw_degrees()
	if _howitzer != null and _howitzer.has_method("get_pitch_degrees"):
		pitch_deg = _howitzer.get_pitch_degrees()
	return {
		"yaw_deg": yaw_deg,
		"pitch_deg": pitch_deg,
		"fire_state": _resolve_howitzer_fire_state(),
		"anchor_state": _howitzer.get_anchor_state() if _howitzer != null and _howitzer.has_method("get_anchor_state") else {},
		"compass": get_compass_state(),
		"operation_state": get_operation_state(),
		"interaction_prompt_state": get_interaction_prompt_state(),
		"hud_status_text": _build_status_text(),
	}

func get_orientation_contract() -> Dictionary:
	return _world_orientation.get_orientation_contract() if _world_orientation != null else {}

func get_compass_state() -> Dictionary:
	return _compass_state.duplicate(true)

func get_interaction_prompt_state() -> Dictionary:
	if _hud != null and _hud.has_method("get_interaction_prompt_state"):
		return _hud.get_interaction_prompt_state()
	return _interaction_prompt_state.duplicate(true)

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

func reset_lab_state() -> void:
	_set_operation_active(false)
	if _howitzer != null and _howitzer.has_method("set_axis_angles_degrees"):
		_howitzer.set_axis_angles_degrees(neutral_yaw_deg, neutral_pitch_deg)
	_restore_player_state()
	_refresh_operation_context()
	_sync_howitzer_operator_lanyard_target()
	_refresh_hud()

func adjust_yaw_degrees(delta_deg: float) -> void:
	if _howitzer == null or not _howitzer.has_method("set_yaw_degrees") or not _howitzer.has_method("get_yaw_degrees"):
		return
	_howitzer.set_yaw_degrees(_howitzer.get_yaw_degrees() + delta_deg)
	_refresh_hud()

func adjust_pitch_degrees(delta_deg: float) -> void:
	if _howitzer == null or not _howitzer.has_method("set_pitch_degrees") or not _howitzer.has_method("get_pitch_degrees"):
		return
	_howitzer.set_pitch_degrees(_howitzer.get_pitch_degrees() + delta_deg)
	_refresh_hud()

func request_primary_interaction() -> Dictionary:
	_refresh_operation_context()
	if _operation_active:
		_set_operation_active(false)
		_refresh_hud()
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
	_refresh_hud()
	return {
		"success": true,
		"handled": true,
		"action": "enter_operation",
	}

func request_fire() -> Dictionary:
	_refresh_operation_context()
	if not _operation_active:
		return {
			"accepted": false,
			"handled": false,
			"error": "operation_inactive",
		}
	if _howitzer == null or not _howitzer.has_method("request_fire"):
		return {
			"accepted": false,
			"handled": true,
			"error": "fire_api_unavailable",
		}
	if _player != null and _player.has_method("consume_jump_input_once"):
		_player.consume_jump_input_once()
	var result := _howitzer.request_fire() as Dictionary
	var response := result.duplicate(true)
	response["handled"] = true
	_refresh_hud()
	return response

func _capture_initial_player_state() -> void:
	if _player == null:
		return
	_initial_player_position = _player.global_position
	_initial_player_rotation = _player.rotation
	if _player_camera_rig != null:
		_initial_player_camera_rig_rotation = _player_camera_rig.rotation

func _restore_player_state() -> void:
	if _player == null:
		return
	if _player.has_method("teleport_to_world_position"):
		_player.teleport_to_world_position(_initial_player_position)
	else:
		_player.global_position = _initial_player_position
	_player.rotation = _initial_player_rotation
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO
	if _player_camera_rig != null:
		_player_camera_rig.rotation = _initial_player_camera_rig_rotation
	if _player.has_method("set_control_enabled"):
		_player.set_control_enabled(true)

func _focus_overview_camera() -> void:
	if _overview_camera_rig == null or _overview_camera == null:
		return
	var view_target := Vector3.ZERO
	if _howitzer != null:
		var pitch_anchor := _howitzer.get_node_or_null("Anchors/PitchPivotAnchor") as Node3D
		if pitch_anchor != null:
			view_target = pitch_anchor.global_position
		else:
			view_target = _howitzer.global_position
	_overview_camera_rig.look_at(view_target, Vector3.UP, true)
	_overview_camera.look_at(view_target, Vector3.UP, true)

func _refresh_hud() -> void:
	_compass_state = _build_player_compass_state()
	if _hud != null and _hud.has_method("set_navigation_state"):
		_hud.set_navigation_state({
			"compass": _compass_state,
		})
	else:
		var compass_view := _hud_root.get_node_or_null("Compass")
		if compass_view != null and compass_view.has_method("set_state"):
			compass_view.set_state(_compass_state)
	_sync_interaction_prompt_ui()
	var lab_state := get_lab_state()
	var fire_state := _resolve_howitzer_fire_state()
	var status_text := _build_status_text()
	var debug_text := "yaw=%.2f deg\npitch=%.2f deg\nbearing=%s %s\noperate=%s  distance=%.2f m  enter=%.2f m  release=%.2f m\nfire_ready=%s  cooldown=%.2f s  shots=%d\nplayer=%s" % [
		float(lab_state.get("yaw_deg", 0.0)),
		float(lab_state.get("pitch_deg", 0.0)),
		str(_compass_state.get("bearing_text", "000°")),
		str(_compass_state.get("cardinal_text", "N")),
		str(bool(get_operation_state().get("active", false))),
		float(get_operation_state().get("distance_m", 0.0)),
		interaction_radius_m,
		float(get_operation_state().get("operation_release_radius_m", operation_release_radius_m)),
		str(bool(fire_state.get("can_fire", false))),
		float(fire_state.get("cooldown_sec", 0.0)),
		int(fire_state.get("fire_count", 0)),
		_player.global_position if _player != null else Vector3.ZERO,
	]
	if _hud != null and _hud.has_method("set_status"):
		_hud.set_status(status_text)
	elif _status_label != null:
		_status_label.text = status_text
	if _hud != null and _hud.has_method("set_debug_text"):
		_hud.set_debug_text(debug_text)
	elif _debug_text != null:
		_debug_text.text = debug_text

func _build_player_compass_state() -> Dictionary:
	if _player == null or _world_orientation == null:
		return {"visible": false}
	var forward := -_player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	return _world_orientation.build_compass_state_from_world_vector(forward, true)

func _ensure_compass_view() -> void:
	if _hud_root == null:
		return
	if _hud_root.get_node_or_null("Compass") != null:
		return
	var compass := Control.new()
	compass.name = "Compass"
	compass.set_script(CityCompassStripScript)
	compass.anchor_left = 0.5
	compass.anchor_top = 0.0
	compass.anchor_right = 0.5
	compass.anchor_bottom = 0.0
	compass.offset_left = -220.0
	compass.offset_top = 18.0
	compass.offset_right = 220.0
	compass.offset_bottom = 82.0
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.visible = false
	_hud_root.add_child(compass)

func _refresh_operation_context() -> void:
	_last_interaction_distance_m = _resolve_howitzer_distance_m()
	var resolved_release_radius_m := maxf(operation_release_radius_m, interaction_radius_m)
	if _operation_active and _last_interaction_distance_m > resolved_release_radius_m:
		_set_operation_active(false)

func _resolve_howitzer_distance_m() -> float:
	if _player == null or _howitzer == null:
		return INF
	var anchor_world_position := _resolve_interaction_anchor_world_position()
	var player_position := _player.global_position
	return Vector2(player_position.x - anchor_world_position.x, player_position.z - anchor_world_position.z).length()

func _resolve_interaction_anchor_world_position() -> Vector3:
	if _howitzer != null:
		var yaw_anchor := _howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
		if yaw_anchor != null:
			return yaw_anchor.global_position
		return _howitzer.global_position
	return Vector3.ZERO

func _set_operation_active(active: bool) -> void:
	_operation_active = active
	_sync_howitzer_operator_lanyard_target()

func _sync_howitzer_operator_lanyard_target() -> void:
	if _howitzer == null:
		return
	if _operation_active:
		if _howitzer.has_method("set_operator_lanyard_target_world_position"):
			_howitzer.set_operator_lanyard_target_world_position(_resolve_player_lanyard_target_world_position())
		return
	if _howitzer.has_method("clear_operator_lanyard_target_world_position"):
		_howitzer.clear_operator_lanyard_target_world_position()

func _resolve_player_lanyard_target_world_position() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	if _player.has_method("get_bite_feedback_world_position"):
		return _player.get_bite_feedback_world_position()
	return _player.global_position + Vector3.UP * 1.05

func _sync_interaction_prompt_ui() -> void:
	_interaction_prompt_state = _build_interaction_prompt_state()
	if _hud != null and _hud.has_method("set_interaction_prompt_state"):
		_hud.set_interaction_prompt_state(_interaction_prompt_state)

func _build_interaction_prompt_state() -> Dictionary:
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

func _build_status_text() -> String:
	if _operation_active:
		return _build_operation_prompt_text()
	if _last_interaction_distance_m <= interaction_radius_m:
		return HOWITZER_NEARBY_HINT_TEXT
	return HOWITZER_IDLE_HINT_TEXT

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
	if _howitzer != null and _howitzer.has_method("get_fire_state"):
		return (_howitzer.get_fire_state() as Dictionary).duplicate(true)
	return {}
