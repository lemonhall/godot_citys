extends Node3D

const CityCompassStripScript := preload("res://city_game/ui/CityCompassStrip.gd")
const CityWorldOrientationScript := preload("res://city_game/world/navigation/CityWorldOrientation.gd")

@export var yaw_speed_deg_per_sec := 28.0
@export var pitch_speed_deg_per_sec := 18.0
@export var neutral_yaw_deg := 0.0
@export var neutral_pitch_deg := 0.0

@onready var _howitzer := $ArtilleryRoot/Howitzer as Node3D
@onready var _player := $Player as CharacterBody3D
@onready var _player_camera_rig := $Player/CameraRig as Node3D
@onready var _player_camera := $Player/CameraRig/Camera3D as Camera3D
@onready var _overview_camera_rig := $LabCameraRig as Node3D
@onready var _overview_camera := $LabCameraRig/Camera3D as Camera3D
@onready var _status_label := $Hud/Root/Panel/VBox/Status as Label
@onready var _debug_text := $Hud/Root/Panel/VBox/DebugText as Label
@onready var _hud_root := $Hud/Root as Control

var _initial_player_position := Vector3.ZERO
var _initial_player_rotation := Vector3.ZERO
var _initial_player_camera_rig_rotation := Vector3.ZERO
var _world_orientation = CityWorldOrientationScript.new()
var _compass_state: Dictionary = {}

func _ready() -> void:
	_ensure_compass_view()
	_capture_initial_player_state()
	reset_lab_state()
	_focus_overview_camera()
	_refresh_hud()

func _process(delta: float) -> void:
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
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
		"anchor_state": _howitzer.get_anchor_state() if _howitzer != null and _howitzer.has_method("get_anchor_state") else {},
		"compass": get_compass_state(),
	}

func get_orientation_contract() -> Dictionary:
	return _world_orientation.get_orientation_contract() if _world_orientation != null else {}

func get_compass_state() -> Dictionary:
	return _compass_state.duplicate(true)

func reset_lab_state() -> void:
	if _howitzer != null and _howitzer.has_method("set_axis_angles_degrees"):
		_howitzer.set_axis_angles_degrees(neutral_yaw_deg, neutral_pitch_deg)
	_restore_player_state()
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
	if _status_label == null or _debug_text == null:
		return
	_compass_state = _build_player_compass_state()
	var compass_view := _hud_root.get_node_or_null("Compass")
	if compass_view != null and compass_view.has_method("set_state"):
		compass_view.set_state(_compass_state)
	var lab_state := get_lab_state()
	_status_label.text = "WASD move  Mouse look  J/L yaw  I/K pitch  R reset"
	_debug_text.text = "yaw=%.2f deg\npitch=%.2f deg\nbearing=%s %s\nplayer=%s" % [
		float(lab_state.get("yaw_deg", 0.0)),
		float(lab_state.get("pitch_deg", 0.0)),
		str(_compass_state.get("bearing_text", "000°")),
		str(_compass_state.get("cardinal_text", "N")),
		_player.global_position if _player != null else Vector3.ZERO,
	]

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
