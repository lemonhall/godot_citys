extends CharacterBody3D

const FlightControllerScript := preload("res://city_game/combat/drone/CityPlayerDroneFlightController.gd")
const SCENE_PATH := "res://city_game/combat/drone/CityDroneGunship.tscn"
const RUNTIME_SCRIPT_PATH := "res://city_game/combat/drone/CityPlayerDroneRuntime.gd"

const SYSTEM_STATE_STOWED := "stowed"
const SYSTEM_STATE_DEPLOYING := "deploying"
const SYSTEM_STATE_ACTIVE := "active"
const SYSTEM_STATE_RECOVERING := "recovering"

@export var deploy_duration_sec := 2.0
@export var recover_duration_sec := 2.0
@export var retrieval_side_offset_m := 1.35
@export var retrieval_forward_offset_m := 0.85
@export var retrieval_height_m := 0.95
@export var hover_forward_offset_m := 3.4
@export var hover_height_m := 5.8

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_root: Node3D = $ModelRoot
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var rotor_audio: AudioStreamPlayer3D = $RotorAudio

var _flight_controller = FlightControllerScript.new()
var _player_owner: Node3D = null
var _player_camera: Camera3D = null
var _system_state := SYSTEM_STATE_STOWED
var _transition_elapsed_sec := 0.0
var _transition_start_position := Vector3.ZERO
var _transition_target_position := Vector3.ZERO
var _planar_velocity_mps := 0.0
var _vertical_velocity_mps := 0.0
var _last_reject_reason := ""
var _locked_player_position := Vector3.ZERO

func _ready() -> void:
	_set_drone_visible(false)
	if camera != null:
		camera.current = false

func _physics_process(delta: float) -> void:
	_maintain_player_lock_position()
	match _system_state:
		SYSTEM_STATE_DEPLOYING:
			_step_deploy(delta)
		SYSTEM_STATE_ACTIVE:
			_step_active(delta)
		SYSTEM_STATE_RECOVERING:
			_step_recover(delta)
		_:
			velocity = Vector3.ZERO
			_planar_velocity_mps = 0.0
			_vertical_velocity_mps = 0.0

func bind_player_owner(player_owner: Node3D) -> void:
	_player_owner = player_owner
	_player_camera = _resolve_player_camera()
	_apply_camera_ownership()

func request_toggle() -> Dictionary:
	match _system_state:
		SYSTEM_STATE_STOWED:
			if _player_owner == null or not is_instance_valid(_player_owner):
				_last_reject_reason = "missing_player_owner"
				return {
					"accepted": false,
					"recognized": true,
					"error": _last_reject_reason,
				}
			_begin_deploy()
			return {
				"accepted": true,
				"recognized": true,
				"state": _system_state,
			}
		SYSTEM_STATE_ACTIVE:
			_begin_recover()
			return {
				"accepted": true,
				"recognized": true,
				"state": _system_state,
			}
		SYSTEM_STATE_DEPLOYING, SYSTEM_STATE_RECOVERING:
			_last_reject_reason = "transition_busy"
			return {
				"accepted": false,
				"recognized": true,
				"error": _last_reject_reason,
				"state": _system_state,
			}
		_:
			return {
				"accepted": false,
				"recognized": false,
			}

func get_visual_root() -> Node3D:
	return visual_root

func should_drive_world_streaming() -> bool:
	return _system_state == SYSTEM_STATE_ACTIVE or _system_state == SYSTEM_STATE_RECOVERING

func get_focus_world_position() -> Vector3:
	return global_position

func get_focus_heading_rad() -> float:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return rotation.y
	forward = forward.normalized()
	return atan2(forward.x, -forward.z)

func get_portability_contract() -> Dictionary:
	return {
		"scene_path": SCENE_PATH,
		"runtime_script_path": RUNTIME_SCRIPT_PATH,
		"world_anchor": {
			"kind": "external_player_anchor",
		},
		"player_lock": {
			"kind": "player_controller_lock_api",
		},
		"camera_owner": {
			"kind": "external_camera_switch",
		},
		"input_source": {
			"kind": "input_singleton",
		},
		"activation_gate": {
			"kind": "external_toggle_gate",
		},
		"debug_passthrough": {
			"method": "get_debug_state",
		},
	}

func get_debug_state() -> Dictionary:
	return {
		"system_state": _system_state,
		"camera_owner": _resolve_camera_owner(),
		"input_owner": _resolve_input_owner(),
		"transition_progress": _resolve_transition_progress(),
		"player_locked": _is_player_locked(),
		"drone_visible": visible,
		"drone_world_position": global_position,
		"planar_velocity_mps": _planar_velocity_mps,
		"vertical_velocity_mps": _vertical_velocity_mps,
		"visual_pitch_deg": rad_to_deg(visual_root.rotation.x) if visual_root != null else 0.0,
		"visual_roll_deg": rad_to_deg(visual_root.rotation.z) if visual_root != null else 0.0,
		"last_reject_reason": _last_reject_reason,
		"scene_path": SCENE_PATH,
		"runtime_script_path": RUNTIME_SCRIPT_PATH,
	}

func _begin_deploy() -> void:
	_last_reject_reason = ""
	_player_camera = _resolve_player_camera()
	_transition_elapsed_sec = 0.0
	_transition_start_position = _resolve_retrieval_anchor()
	_transition_target_position = _resolve_hover_anchor()
	_locked_player_position = _player_owner.global_position
	global_position = _transition_start_position
	global_rotation.y = _resolve_player_yaw()
	velocity = Vector3.ZERO
	_planar_velocity_mps = 0.0
	_vertical_velocity_mps = 0.0
	_set_player_lock(true)
	_set_drone_visible(true)
	_system_state = SYSTEM_STATE_DEPLOYING
	_apply_camera_ownership()

func _begin_recover() -> void:
	_last_reject_reason = ""
	_transition_elapsed_sec = 0.0
	_transition_start_position = global_position
	_transition_target_position = _resolve_retrieval_anchor()
	_locked_player_position = _player_owner.global_position
	velocity = Vector3.ZERO
	_planar_velocity_mps = 0.0
	_vertical_velocity_mps = 0.0
	_set_player_lock(true)
	_system_state = SYSTEM_STATE_RECOVERING
	_apply_camera_ownership()

func _step_deploy(delta: float) -> void:
	_transition_elapsed_sec = minf(_transition_elapsed_sec + maxf(delta, 0.0), deploy_duration_sec)
	var progress := _smoothstep(_resolve_transition_progress())
	var next_position := _transition_start_position.lerp(_transition_target_position, progress)
	_update_transition_velocity(next_position, delta)
	global_position = next_position
	if progress >= 1.0 - 0.0001:
		_system_state = SYSTEM_STATE_ACTIVE
		velocity = Vector3.ZERO
		_planar_velocity_mps = 0.0
		_vertical_velocity_mps = 0.0
		_apply_camera_ownership()

func _step_active(delta: float) -> void:
	_set_player_lock(true)
	_apply_camera_ownership()
	var flight_state: Dictionary = _flight_controller.step(self, camera, visual_root, delta)
	_planar_velocity_mps = float(flight_state.get("planar_speed_mps", 0.0))
	_vertical_velocity_mps = float(flight_state.get("vertical_speed_mps", 0.0))

func _step_recover(delta: float) -> void:
	_transition_elapsed_sec = minf(_transition_elapsed_sec + maxf(delta, 0.0), recover_duration_sec)
	var progress := _smoothstep(_resolve_transition_progress())
	var next_position := _transition_start_position.lerp(_transition_target_position, progress)
	_update_transition_velocity(next_position, delta)
	global_position = next_position
	if progress >= 1.0 - 0.0001:
		_system_state = SYSTEM_STATE_STOWED
		velocity = Vector3.ZERO
		_planar_velocity_mps = 0.0
		_vertical_velocity_mps = 0.0
		_set_drone_visible(false)
		_set_player_lock(false)
		_apply_camera_ownership()

func _set_drone_visible(should_be_visible: bool) -> void:
	visible = should_be_visible
	if collision_shape != null:
		collision_shape.disabled = not should_be_visible
	if camera != null and not should_be_visible:
		camera.current = false
	if rotor_audio != null:
		if should_be_visible and rotor_audio.stream != null:
			if not rotor_audio.playing:
				rotor_audio.play()
		else:
			rotor_audio.stop()

func _set_player_lock(locked: bool) -> void:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return
	if locked:
		_locked_player_position = _player_owner.global_position
	if _player_owner.has_method("set_control_enabled"):
		_player_owner.set_control_enabled(not locked)
	if _player_owner.has_method("set_movement_locked"):
		_player_owner.set_movement_locked(locked)

func _apply_camera_ownership() -> void:
	_player_camera = _resolve_player_camera()
	if camera == null:
		return
	match _system_state:
		SYSTEM_STATE_ACTIVE, SYSTEM_STATE_RECOVERING:
			camera.current = true
			if _player_camera != null:
				_player_camera.current = false
		_:
			camera.current = false
			if _player_camera != null:
				_player_camera.current = true

func _resolve_player_camera() -> Camera3D:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return null
	return _player_owner.get_node_or_null("CameraRig/Camera3D") as Camera3D

func _resolve_retrieval_anchor() -> Vector3:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return global_position
	var forward := -_player_owner.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := _player_owner.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	return _player_owner.global_position + right * retrieval_side_offset_m + forward * retrieval_forward_offset_m + Vector3.UP * retrieval_height_m

func _resolve_hover_anchor() -> Vector3:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return global_position + Vector3.UP * hover_height_m
	var forward := -_player_owner.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	return _player_owner.global_position + forward * hover_forward_offset_m + Vector3.UP * hover_height_m

func _resolve_player_yaw() -> float:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return rotation.y
	var forward := -_player_owner.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return rotation.y
	forward = forward.normalized()
	return atan2(-forward.x, -forward.z)

func _resolve_camera_owner() -> String:
	match _system_state:
		SYSTEM_STATE_ACTIVE, SYSTEM_STATE_RECOVERING:
			return "drone"
		_:
			return "player"

func _resolve_input_owner() -> String:
	match _system_state:
		SYSTEM_STATE_ACTIVE:
			return "drone"
		SYSTEM_STATE_DEPLOYING, SYSTEM_STATE_RECOVERING:
			return "none"
		_:
			return "player"

func _resolve_transition_progress() -> float:
	match _system_state:
		SYSTEM_STATE_DEPLOYING:
			return clampf(_transition_elapsed_sec / maxf(deploy_duration_sec, 0.001), 0.0, 1.0)
		SYSTEM_STATE_RECOVERING:
			return clampf(_transition_elapsed_sec / maxf(recover_duration_sec, 0.001), 0.0, 1.0)
		SYSTEM_STATE_ACTIVE:
			return 1.0
		_:
			return 0.0

func _is_player_locked() -> bool:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return _system_state != SYSTEM_STATE_STOWED
	if _player_owner.has_method("is_movement_locked"):
		return bool(_player_owner.is_movement_locked())
	return _system_state != SYSTEM_STATE_STOWED

func _update_transition_velocity(next_position: Vector3, delta: float) -> void:
	if delta <= 0.0:
		_planar_velocity_mps = 0.0
		_vertical_velocity_mps = 0.0
		return
	var step_velocity := (next_position - global_position) / delta
	_planar_velocity_mps = Vector2(step_velocity.x, step_velocity.z).length()
	_vertical_velocity_mps = step_velocity.y

func _maintain_player_lock_position() -> void:
	if _system_state == SYSTEM_STATE_STOWED:
		return
	if _player_owner == null or not is_instance_valid(_player_owner):
		return
	if _player_owner.has_method("teleport_to_world_position"):
		_player_owner.teleport_to_world_position(_locked_player_position)
	else:
		_player_owner.global_position = _locked_player_position

func _smoothstep(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)
