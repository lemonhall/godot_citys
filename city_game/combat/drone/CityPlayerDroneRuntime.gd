extends CharacterBody3D

const FlightControllerScript := preload("res://city_game/combat/drone/CityPlayerDroneFlightController.gd")
const SCENE_PATH := "res://city_game/combat/drone/CityDroneGunship.tscn"
const RUNTIME_SCRIPT_PATH := "res://city_game/combat/drone/CityPlayerDroneRuntime.gd"

const SYSTEM_STATE_STOWED := "stowed"
const SYSTEM_STATE_DEPLOYING := "deploying"
const SYSTEM_STATE_ACTIVE := "active"
const SYSTEM_STATE_RECOVERING := "recovering"
const VIEW_MODE_THIRD_PERSON := "third_person"
const VIEW_MODE_FPV_ADS := "fpv_ads"
const STRIKE_STATE_IDLE := "idle"
const STRIKE_STATE_LOCKED := "locked"
const STRIKE_STATE_STRIKING := "striking"
const STRIKE_STATE_EXPLODING := "exploding"
const STRIKE_STATE_SIGNAL_LOSS := "signal_loss"

@export var deploy_duration_sec := 2.0
@export var recover_duration_sec := 2.0
@export var retrieval_side_offset_m := 1.35
@export var retrieval_forward_offset_m := 0.85
@export var retrieval_height_m := 0.95
@export var hover_forward_offset_m := 3.4
@export var hover_height_m := 5.8
@export var presentation_scale := 3.0
@export var mouse_yaw_sensitivity := 0.0024
@export var max_mouse_yaw_step_deg := 10.0
@export var fpv_mouse_yaw_sensitivity := 0.0028
@export var fpv_mouse_pitch_sensitivity := 0.0022
@export var fpv_pitch_limit_deg := 72.0
@export var fpv_ads_fov_deg := 50.0
@export var strike_speed_mps := 210.0
@export var strike_impact_radius_m := 2.8
@export var strike_explosion_radius_m := 16.0
@export var strike_explosion_damage := 26.0
@export var strike_explosion_effect_duration_sec := 0.68
@export var strike_signal_loss_duration_sec := 2.4
@export var strike_no_signal_visible_duration_sec := 1.0
@export var strike_no_signal_blink_hz := 5.5
@export var strike_camera_shake_duration_sec := 0.52
@export var strike_camera_shake_amplitude_m := 0.48

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_root: Node3D = $ModelRoot
@onready var rotor_blur_root: Node3D = $RotorBlurRoot
@onready var camera_rig: Node3D = $CameraRig
@onready var third_person_pose: Marker3D = $CameraRig/ThirdPersonPose
@onready var fpv_pivot: Node3D = $CameraRig/FpvPivot
@onready var fpv_pose: Marker3D = $CameraRig/FpvPivot/FpvPose
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var fpv_overlay: CanvasLayer = $FpvOverlay
@onready var fpv_overlay_rect: ColorRect = $FpvOverlay/InfraredRect
@onready var no_signal_label: Label = $FpvOverlay/NoSignalLabel
@onready var death_fx_root: Node3D = $DeathFxRoot
@onready var death_explosion_ring: MeshInstance3D = $DeathFxRoot/ExplosionRing
@onready var death_explosion_sphere: MeshInstance3D = $DeathFxRoot/ExplosionSphere
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
var _pending_mouse_yaw_delta_rad := 0.0
var _view_mode := VIEW_MODE_THIRD_PERSON
var _strike_state := STRIKE_STATE_IDLE
var _fpv_pitch_rad := 0.0
var _fpv_yaw_rad := 0.0
var _locked_target_world_position := Vector3.ZERO
var _strike_explosion_elapsed_sec := 0.0
var _strike_signal_loss_elapsed_sec := 0.0
var _strike_explosion_world_position := Vector3.ZERO
var _last_strike_result: Dictionary = {}

func _ready() -> void:
	_apply_presentation_scale()
	_sync_presentation_from_visual_root()
	_reset_death_fx()
	_set_drone_visible(false)
	_sync_camera_pose()
	_sync_fpv_overlay_state()
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
	_sync_camera_pose()
	_sync_fpv_overlay_state()

func bind_player_owner(player_owner: Node3D) -> void:
	_player_owner = player_owner
	_player_camera = _resolve_player_camera()
	_apply_camera_ownership()

func _unhandled_input(event: InputEvent) -> void:
	if _system_state != SYSTEM_STATE_ACTIVE:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if button.pressed and button.button_index == MOUSE_BUTTON_RIGHT and _strike_state == STRIKE_STATE_IDLE:
			_set_view_mode(VIEW_MODE_THIRD_PERSON if _view_mode == VIEW_MODE_FPV_ADS else VIEW_MODE_FPV_ADS)
			get_viewport().set_input_as_handled()
			return
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT and _view_mode == VIEW_MODE_FPV_ADS and _strike_state == STRIKE_STATE_IDLE:
			_begin_suicide_strike_lock()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseMotion):
		return
	if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if _view_mode == VIEW_MODE_FPV_ADS and _strike_state == STRIKE_STATE_IDLE:
		_fpv_yaw_rad = wrapf(_fpv_yaw_rad - motion.relative.x * fpv_mouse_yaw_sensitivity, -PI, PI)
		var max_pitch_rad := deg_to_rad(maxf(fpv_pitch_limit_deg, 0.0))
		_fpv_pitch_rad = clampf(_fpv_pitch_rad - motion.relative.y * fpv_mouse_pitch_sensitivity, -max_pitch_rad, max_pitch_rad)
		get_viewport().set_input_as_handled()
		return
	_pending_mouse_yaw_delta_rad += -motion.relative.x * mouse_yaw_sensitivity
	get_viewport().set_input_as_handled()

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
			if _strike_state != STRIKE_STATE_IDLE:
				_last_reject_reason = "strike_committed"
				return {
					"accepted": false,
					"recognized": true,
					"error": _last_reject_reason,
					"state": _system_state,
				}
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

func get_crosshair_state() -> Dictionary:
	var viewport_size := _resolve_viewport_size()
	var fpv_visible := _is_fpv_active()
	var world_target := _locked_target_world_position if _locked_target_world_position != Vector3.ZERO else _resolve_crosshair_world_target()
	return {
		"visible": fpv_visible and _strike_state == STRIKE_STATE_IDLE,
		"screen_position": viewport_size * 0.5,
		"viewport_size": viewport_size,
		"world_target": world_target,
		"aim_down_sights_active": fpv_visible,
	}

func get_debug_state() -> Dictionary:
	var fpv_visible := _is_fpv_active()
	var crosshair_target := _locked_target_world_position if _locked_target_world_position != Vector3.ZERO else _resolve_crosshair_world_target()
	var strike_target_distance_m := global_position.distance_to(_locked_target_world_position) if _locked_target_world_position != Vector3.ZERO else 0.0
	var signal_loss_active := _strike_state == STRIKE_STATE_SIGNAL_LOSS
	var signal_loss_progress := 0.0
	if strike_signal_loss_duration_sec > 0.0:
		signal_loss_progress = clampf(_strike_signal_loss_elapsed_sec / strike_signal_loss_duration_sec, 0.0, 1.0)
	return {
		"system_state": _system_state,
		"camera_owner": _resolve_camera_owner(),
		"input_owner": _resolve_input_owner(),
		"transition_progress": _resolve_transition_progress(),
		"player_locked": _is_player_locked(),
		"drone_visible": visible,
		"drone_world_position": global_position,
		"body_yaw_deg": rad_to_deg(rotation.y),
		"planar_velocity_mps": _planar_velocity_mps,
		"vertical_velocity_mps": _vertical_velocity_mps,
		"presentation_scale": presentation_scale,
		"view_mode": _view_mode,
		"strike_state": _strike_state,
		"manual_flight_input_enabled": _system_state == SYSTEM_STATE_ACTIVE and _strike_state == STRIKE_STATE_IDLE,
		"fpv_filter_enabled": fpv_visible,
		"fpv_crosshair_visible": fpv_visible and _strike_state == STRIKE_STATE_IDLE,
		"signal_loss_active": signal_loss_active,
		"signal_loss_progress": signal_loss_progress,
		"signal_loss_remaining_sec": maxf(strike_signal_loss_duration_sec - _strike_signal_loss_elapsed_sec, 0.0) if signal_loss_active else 0.0,
		"overlay_mode": _resolve_overlay_mode(),
		"no_signal_visible": no_signal_label != null and no_signal_label.visible,
		"fpv_fov_deg": camera.fov if camera != null else 0.0,
		"fpv_pitch_deg": rad_to_deg(_fpv_pitch_rad),
		"fpv_yaw_deg": rad_to_deg(_fpv_yaw_rad),
		"fpv_crosshair_world_target": crosshair_target,
		"locked_target_world_position": _locked_target_world_position,
		"strike_target_valid": _locked_target_world_position != Vector3.ZERO,
		"strike_target_distance_m": strike_target_distance_m,
		"strike_explosion_world_position": _strike_explosion_world_position,
		"last_strike_result": _last_strike_result.duplicate(true),
		"strike_committed": _strike_state != STRIKE_STATE_IDLE,
		"visual_pitch_deg": rad_to_deg(visual_root.rotation.x) if visual_root != null else 0.0,
		"visual_roll_deg": rad_to_deg(visual_root.rotation.z) if visual_root != null else 0.0,
		"rotor_blur_pitch_deg": rad_to_deg(rotor_blur_root.rotation.x) if rotor_blur_root != null else 0.0,
		"rotor_blur_roll_deg": rad_to_deg(rotor_blur_root.rotation.z) if rotor_blur_root != null else 0.0,
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
	_reset_aircraft_attitude(_resolve_player_yaw())
	_set_view_mode(VIEW_MODE_THIRD_PERSON)
	_strike_state = STRIKE_STATE_IDLE
	_fpv_pitch_rad = 0.0
	_fpv_yaw_rad = 0.0
	_locked_target_world_position = Vector3.ZERO
	_strike_explosion_elapsed_sec = 0.0
	_strike_signal_loss_elapsed_sec = 0.0
	_strike_explosion_world_position = Vector3.ZERO
	_last_strike_result.clear()
	_pending_mouse_yaw_delta_rad = 0.0
	velocity = Vector3.ZERO
	_planar_velocity_mps = 0.0
	_vertical_velocity_mps = 0.0
	_reset_death_fx()
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
	_set_view_mode(VIEW_MODE_THIRD_PERSON)
	_strike_state = STRIKE_STATE_IDLE
	_locked_target_world_position = Vector3.ZERO
	_strike_explosion_elapsed_sec = 0.0
	_strike_signal_loss_elapsed_sec = 0.0
	_strike_explosion_world_position = Vector3.ZERO
	_pending_mouse_yaw_delta_rad = 0.0
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
	match _strike_state:
		STRIKE_STATE_IDLE:
			_apply_pending_mouse_yaw()
			var flight_state: Dictionary = _flight_controller.step(self, camera, visual_root, delta)
			_sync_presentation_from_visual_root()
			_planar_velocity_mps = float(flight_state.get("planar_speed_mps", 0.0))
			_vertical_velocity_mps = float(flight_state.get("vertical_speed_mps", 0.0))
		STRIKE_STATE_LOCKED:
			_begin_suicide_strike_run()
			_step_suicide_strike(delta)
		STRIKE_STATE_STRIKING:
			_step_suicide_strike(delta)
		STRIKE_STATE_EXPLODING:
			_step_strike_explosion(delta)
		STRIKE_STATE_SIGNAL_LOSS:
			_step_signal_loss_closeout(delta)

func _step_recover(delta: float) -> void:
	_transition_elapsed_sec = minf(_transition_elapsed_sec + maxf(delta, 0.0), recover_duration_sec)
	var progress := _smoothstep(_resolve_transition_progress())
	var next_position := _transition_start_position.lerp(_transition_target_position, progress)
	_update_transition_velocity(next_position, delta)
	global_position = next_position
	if progress >= 1.0 - 0.0001:
		_system_state = SYSTEM_STATE_STOWED
		_set_view_mode(VIEW_MODE_THIRD_PERSON)
		_strike_state = STRIKE_STATE_IDLE
		_locked_target_world_position = Vector3.ZERO
		_strike_explosion_elapsed_sec = 0.0
		_strike_signal_loss_elapsed_sec = 0.0
		_strike_explosion_world_position = Vector3.ZERO
		_pending_mouse_yaw_delta_rad = 0.0
		velocity = Vector3.ZERO
		_planar_velocity_mps = 0.0
		_vertical_velocity_mps = 0.0
		_reset_death_fx()
		_set_drone_visible(false)
		_set_player_lock(false)
		_apply_camera_ownership()

func _set_drone_visible(should_be_visible: bool) -> void:
	visible = should_be_visible
	if visual_root != null:
		visual_root.visible = should_be_visible
	if rotor_blur_root != null:
		rotor_blur_root.visible = should_be_visible
	if fpv_overlay != null:
		fpv_overlay.visible = should_be_visible and _is_fpv_active()
	if fpv_overlay_rect != null:
		fpv_overlay_rect.visible = should_be_visible and _is_fpv_active()
	if no_signal_label != null:
		no_signal_label.visible = false
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
			if _strike_state != STRIKE_STATE_IDLE:
				return "none"
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

func _set_view_mode(next_view_mode: String) -> void:
	_view_mode = next_view_mode if next_view_mode == VIEW_MODE_FPV_ADS else VIEW_MODE_THIRD_PERSON
	if _view_mode == VIEW_MODE_THIRD_PERSON:
		_fpv_pitch_rad = 0.0
		_fpv_yaw_rad = 0.0
	_sync_camera_pose()
	_sync_fpv_overlay_state()

func _resolve_viewport_size() -> Vector2:
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	if get_viewport() != null:
		var visible_rect := get_viewport().get_visible_rect()
		if visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0:
			viewport_size = visible_rect.size
	return viewport_size

func _build_query_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	if self is CollisionObject3D:
		exclusions.append(get_rid())
	if _player_owner is CollisionObject3D:
		exclusions.append((_player_owner as CollisionObject3D).get_rid())
	return exclusions

func _resolve_crosshair_world_target() -> Vector3:
	if camera == null or get_world_3d() == null or get_world_3d().direct_space_state == null:
		return global_position + (-global_transform.basis.z).normalized() * 600.0
	var viewport_size := _resolve_viewport_size()
	var screen_center := viewport_size * 0.5
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_direction := camera.project_ray_normal(screen_center)
	var ray_end := ray_origin + ray_direction * 800.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.exclude = _build_query_exclusions()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.get("position", ray_end)
	return ray_end

func _is_fpv_active() -> bool:
	return _system_state == SYSTEM_STATE_ACTIVE and _view_mode == VIEW_MODE_FPV_ADS

func _sync_camera_pose() -> void:
	if camera == null:
		return
	if _is_fpv_active():
		if fpv_pivot != null:
			fpv_pivot.rotation = Vector3(_fpv_pitch_rad, _fpv_yaw_rad, 0.0)
		if fpv_pose != null:
			camera.global_transform = fpv_pose.global_transform
		camera.fov = fpv_ads_fov_deg
		return
	if third_person_pose != null:
		camera.global_transform = third_person_pose.global_transform
	camera.fov = 68.0

func _sync_fpv_overlay_state() -> void:
	var overlay_visible := visible and _is_fpv_active()
	if fpv_overlay != null:
		fpv_overlay.visible = overlay_visible
	if fpv_overlay_rect != null:
		fpv_overlay_rect.visible = overlay_visible
		var overlay_material := fpv_overlay_rect.material as ShaderMaterial
		if overlay_material != null:
			overlay_material.set_shader_parameter("overlay_mode", 1.0 if _strike_state == STRIKE_STATE_SIGNAL_LOSS else 0.0)
			overlay_material.set_shader_parameter("signal_loss_strength", 1.0 if _strike_state == STRIKE_STATE_SIGNAL_LOSS else 0.0)
	if no_signal_label != null:
		no_signal_label.visible = overlay_visible and _should_show_no_signal_label()
		if no_signal_label.visible:
			var blink_phase := sin(_strike_signal_loss_elapsed_sec * TAU * maxf(strike_no_signal_blink_hz, 0.1))
			no_signal_label.modulate = Color(0.345098, 1.0, 0.521569, 0.78 + maxf(blink_phase, 0.0) * 0.22)

func _apply_pending_mouse_yaw() -> void:
	if absf(_pending_mouse_yaw_delta_rad) <= 0.000001:
		return
	var max_step_rad := deg_to_rad(max_mouse_yaw_step_deg)
	var yaw_step := clampf(_pending_mouse_yaw_delta_rad, -max_step_rad, max_step_rad)
	rotation.y += yaw_step
	_pending_mouse_yaw_delta_rad = 0.0

func _apply_presentation_scale() -> void:
	var scaled_nodes: Array[Node3D] = [visual_root, rotor_blur_root, death_fx_root]
	for presentation_node in scaled_nodes:
		if presentation_node == null:
			continue
		presentation_node.scale = Vector3.ONE * presentation_scale

func _sync_presentation_from_visual_root() -> void:
	if visual_root == null or rotor_blur_root == null:
		return
	rotor_blur_root.rotation.x = visual_root.rotation.x
	rotor_blur_root.rotation.z = visual_root.rotation.z

func _begin_suicide_strike_lock() -> void:
	if not _is_fpv_active() or camera == null:
		return
	_last_reject_reason = ""
	_locked_target_world_position = _resolve_crosshair_world_target()
	if _locked_target_world_position == Vector3.ZERO:
		_locked_target_world_position = global_position + (-camera.global_transform.basis.z).normalized() * 120.0
	var camera_forward := -camera.global_transform.basis.z
	if camera_forward.length_squared() <= 0.0001:
		camera_forward = (_locked_target_world_position - global_position).normalized()
	_orient_body_toward_direction(camera_forward)
	_fpv_pitch_rad = 0.0
	_fpv_yaw_rad = 0.0
	_pending_mouse_yaw_delta_rad = 0.0
	velocity = Vector3.ZERO
	_planar_velocity_mps = 0.0
	_vertical_velocity_mps = 0.0
	_strike_explosion_elapsed_sec = 0.0
	_strike_signal_loss_elapsed_sec = 0.0
	_strike_explosion_world_position = Vector3.ZERO
	_last_strike_result.clear()
	_strike_state = STRIKE_STATE_LOCKED
	if visual_root != null:
		visual_root.rotation = Vector3.ZERO
	if rotor_blur_root != null:
		rotor_blur_root.rotation = Vector3.ZERO

func _begin_suicide_strike_run() -> void:
	if _strike_state != STRIKE_STATE_LOCKED:
		return
	_strike_state = STRIKE_STATE_STRIKING

func _step_suicide_strike(delta: float) -> void:
	if _locked_target_world_position == Vector3.ZERO:
		_explode_drone("missing_target", global_position)
		return
	var previous_position := global_position
	var to_target := _locked_target_world_position - previous_position
	var distance_to_target := to_target.length()
	if distance_to_target <= strike_impact_radius_m:
		_explode_drone("target_reached", _locked_target_world_position)
		return
	var direction := to_target / maxf(distance_to_target, 0.001)
	_orient_body_toward_direction(direction)
	var travel_distance := minf(strike_speed_mps * maxf(delta, 0.0), distance_to_target)
	var next_position := previous_position + direction * travel_distance
	if get_world_3d() != null and get_world_3d().direct_space_state != null:
		var query := PhysicsRayQueryParameters3D.create(previous_position, next_position)
		query.collide_with_areas = false
		query.exclude = _build_query_exclusions()
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_explode_drone("impact", hit.get("position", next_position))
			return
	global_position = next_position
	velocity = direction * strike_speed_mps
	_planar_velocity_mps = Vector2(velocity.x, velocity.z).length()
	_vertical_velocity_mps = velocity.y
	if travel_distance >= distance_to_target - 0.0001:
		_explode_drone("target_reached", _locked_target_world_position)

func _explode_drone(trigger_kind: String, explosion_world_position: Vector3) -> void:
	if _strike_state == STRIKE_STATE_EXPLODING:
		return
	global_position = explosion_world_position
	velocity = Vector3.ZERO
	_planar_velocity_mps = 0.0
	_vertical_velocity_mps = 0.0
	_strike_state = STRIKE_STATE_EXPLODING
	_strike_explosion_elapsed_sec = 0.0
	_strike_explosion_world_position = explosion_world_position
	_last_strike_result = _apply_drone_explosion_damage(explosion_world_position)
	_last_strike_result["trigger_kind"] = trigger_kind
	_last_strike_result["locked_target_world_position"] = _locked_target_world_position
	_last_strike_result["explosion_world_position"] = explosion_world_position
	_last_strike_result["signal_loss_duration_sec"] = strike_signal_loss_duration_sec
	_trigger_strike_camera_shake(explosion_world_position)
	if collision_shape != null:
		collision_shape.disabled = true
	if rotor_audio != null:
		rotor_audio.stop()
	if visual_root != null:
		visual_root.visible = false
	if rotor_blur_root != null:
		rotor_blur_root.visible = false
	_reset_death_fx()
	if death_fx_root != null:
		death_fx_root.visible = true
	if death_explosion_ring != null:
		death_explosion_ring.visible = true
		death_explosion_ring.scale = Vector3(0.36, 1.0, 0.36)
	if death_explosion_sphere != null:
		death_explosion_sphere.visible = true
		death_explosion_sphere.scale = Vector3.ONE * 0.42

func _step_strike_explosion(delta: float) -> void:
	global_position = _strike_explosion_world_position
	velocity = Vector3.ZERO
	_planar_velocity_mps = 0.0
	_vertical_velocity_mps = 0.0
	_strike_explosion_elapsed_sec += maxf(delta, 0.0)
	var duration_sec := maxf(strike_explosion_effect_duration_sec, 0.001)
	var progress := clampf(_strike_explosion_elapsed_sec / duration_sec, 0.0, 1.0)
	if death_explosion_ring != null:
		var ring_scale := lerpf(0.36, strike_explosion_radius_m * 0.62, progress)
		death_explosion_ring.scale = Vector3(ring_scale, 1.0, ring_scale)
		var ring_material := death_explosion_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.albedo_color.a = lerpf(0.74, 0.0, progress)
			ring_material.emission_energy_multiplier = lerpf(2.0, 0.0, progress)
	if death_explosion_sphere != null:
		var sphere_scale := lerpf(0.42, strike_explosion_radius_m * 0.24, progress)
		death_explosion_sphere.scale = Vector3.ONE * sphere_scale
		var sphere_material := death_explosion_sphere.material_override as StandardMaterial3D
		if sphere_material != null:
			sphere_material.albedo_color.a = lerpf(0.44, 0.0, progress)
			sphere_material.emission_energy_multiplier = lerpf(2.4, 0.0, progress)
	if progress >= 1.0:
		_enter_signal_loss_closeout()

func _enter_signal_loss_closeout() -> void:
	_strike_state = STRIKE_STATE_SIGNAL_LOSS
	_strike_signal_loss_elapsed_sec = 0.0
	_reset_death_fx()

func _step_signal_loss_closeout(delta: float) -> void:
	global_position = _strike_explosion_world_position
	velocity = Vector3.ZERO
	_planar_velocity_mps = 0.0
	_vertical_velocity_mps = 0.0
	_strike_signal_loss_elapsed_sec += maxf(delta, 0.0)
	if _strike_signal_loss_elapsed_sec >= maxf(strike_signal_loss_duration_sec, 0.001):
		_complete_strike_closeout()

func _complete_strike_closeout() -> void:
	_system_state = SYSTEM_STATE_STOWED
	_set_view_mode(VIEW_MODE_THIRD_PERSON)
	_strike_state = STRIKE_STATE_IDLE
	_locked_target_world_position = Vector3.ZERO
	_strike_explosion_elapsed_sec = 0.0
	_strike_signal_loss_elapsed_sec = 0.0
	_pending_mouse_yaw_delta_rad = 0.0
	velocity = Vector3.ZERO
	_planar_velocity_mps = 0.0
	_vertical_velocity_mps = 0.0
	_reset_death_fx()
	_set_drone_visible(false)
	_set_player_lock(false)
	_apply_camera_ownership()

func _apply_drone_explosion_damage(explosion_world_position: Vector3) -> Dictionary:
	var enemy_hit_count := 0
	var building_hit_count := 0
	if get_tree() != null:
		for enemy_node in get_tree().get_nodes_in_group("city_enemy"):
			var enemy := enemy_node as Node3D
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.global_position.distance_to(explosion_world_position) > strike_explosion_radius_m:
				continue
			if enemy.has_method("apply_projectile_hit"):
				var impulse_direction := enemy.global_position - explosion_world_position
				if impulse_direction.length_squared() <= 0.0001:
					impulse_direction = Vector3.UP
				enemy.apply_projectile_hit(strike_explosion_damage, explosion_world_position, impulse_direction.normalized() * 24.0)
				enemy_hit_count += 1
		for building_node in get_tree().get_nodes_in_group("city_destructible_building"):
			if building_node == null or not is_instance_valid(building_node):
				continue
			if not building_node.has_method("apply_explosion_damage"):
				continue
			var building_result = building_node.apply_explosion_damage(explosion_world_position, strike_explosion_damage, strike_explosion_radius_m)
			if bool((building_result as Dictionary).get("accepted", false)):
				building_hit_count += 1
	var pedestrian_result: Dictionary = {}
	var vehicle_result: Dictionary = {}
	var world_runtime := _resolve_world_runtime()
	if world_runtime != null:
		if world_runtime.has_method("resolve_pedestrian_explosion"):
			pedestrian_result = world_runtime.resolve_pedestrian_explosion(explosion_world_position, maxf(strike_explosion_radius_m * 0.42, 5.0), strike_explosion_radius_m)
		if world_runtime.has_method("resolve_vehicle_explosion"):
			vehicle_result = world_runtime.resolve_vehicle_explosion(explosion_world_position, strike_explosion_radius_m)
	return {
		"enemy_hit_count": enemy_hit_count,
		"building_hit_count": building_hit_count,
		"pedestrian_result": pedestrian_result.duplicate(true),
		"vehicle_result": vehicle_result.duplicate(true),
	}

func _trigger_strike_camera_shake(explosion_world_position: Vector3) -> void:
	if _player_owner == null or not is_instance_valid(_player_owner):
		return
	if not _player_owner.has_method("trigger_camera_shake"):
		return
	var distance_to_player := _player_owner.global_position.distance_to(explosion_world_position)
	var falloff := clampf(1.0 - distance_to_player / 48.0, 0.35, 1.0)
	_player_owner.trigger_camera_shake(strike_camera_shake_duration_sec, strike_camera_shake_amplitude_m * falloff)

func _resolve_world_runtime() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("resolve_pedestrian_explosion") or current.has_method("resolve_vehicle_explosion"):
			return current
		current = current.get_parent()
	return null

func _resolve_overlay_mode() -> String:
	return "signal_loss" if _strike_state == STRIKE_STATE_SIGNAL_LOSS else "infrared"

func _should_show_no_signal_label() -> bool:
	if _strike_state != STRIKE_STATE_SIGNAL_LOSS:
		return false
	if _strike_signal_loss_elapsed_sec > maxf(strike_no_signal_visible_duration_sec, 0.0):
		return false
	var blink_step := int(floor(_strike_signal_loss_elapsed_sec * maxf(strike_no_signal_blink_hz, 0.1)))
	return blink_step % 2 == 0

func _orient_body_toward_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.0001:
		return
	var up_axis := Vector3.UP if absf(direction.normalized().dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	look_at(global_position + direction.normalized(), up_axis)

func _reset_aircraft_attitude(yaw_rad: float) -> void:
	global_rotation = Vector3.ZERO
	global_rotation.y = yaw_rad
	if visual_root != null:
		visual_root.rotation = Vector3.ZERO
	if rotor_blur_root != null:
		rotor_blur_root.rotation = Vector3.ZERO
	if fpv_pivot != null:
		fpv_pivot.rotation = Vector3.ZERO

func _reset_death_fx() -> void:
	if death_fx_root != null:
		death_fx_root.visible = false
	if death_explosion_ring != null:
		death_explosion_ring.visible = false
		death_explosion_ring.scale = Vector3(0.36, 1.0, 0.36)
		var ring_material := death_explosion_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.albedo_color.a = 0.74
			ring_material.emission_energy_multiplier = 2.0
	if death_explosion_sphere != null:
		death_explosion_sphere.visible = false
		death_explosion_sphere.scale = Vector3.ONE * 0.42
		var sphere_material := death_explosion_sphere.material_override as StandardMaterial3D
		if sphere_material != null:
			sphere_material.albedo_color.a = 0.44
			sphere_material.emission_energy_multiplier = 2.4
