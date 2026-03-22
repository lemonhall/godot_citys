extends CharacterBody3D

const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")
const TennisRacketVisualRig := preload("res://city_game/world/minigames/TennisRacketVisualRig.gd")

signal primary_fire_requested
signal grenade_throw_requested
signal laser_designator_requested
signal missile_launcher_requested
signal weapon_mode_changed(weapon_mode: String)
signal aim_down_sights_changed(is_active: bool)
signal fishing_preview_toggled(is_active: bool)
signal fishing_cast_action_requested

const TRAVERSAL_MODE_GROUNDED := "grounded"
const TRAVERSAL_MODE_AIRBORNE := "airborne"
const TRAVERSAL_MODE_WALL_CLIMB := "wall_climb"
const TRAVERSAL_MODE_GROUND_SLAM := "ground_slam"
const WEAPON_MODE_RIFLE := "rifle"
const WEAPON_MODE_GRENADE := "grenade"
const WEAPON_MODE_LASER_DESIGNATOR := "laser_designator"
const WEAPON_MODE_MISSILE_LAUNCHER := "missile_launcher"
const SPORTS_CAR_MODEL_ID := "sports_car_a"
const SPORTS_CAR_SPEED_MULTIPLIER := 2.0

@export var walk_speed := 8.0
@export var sprint_speed := 18.5
@export var inspection_walk_speed := 96.0
@export var inspection_sprint_speed := 180.0
@export var jump_velocity := 7.4
@export var mouse_sensitivity := 0.003
@export var min_pitch_deg := -68.0
@export var max_pitch_deg := 35.0
@export var player_floor_snap_length := 0.9
@export var inspection_floor_snap_length := 1.8
@export var primary_fire_cooldown_sec := 0.12
@export var primary_fire_shoulder_offset := Vector3(0.46, 1.22, -0.18)
@export var primary_fire_forward_offset_m := 0.72
@export var aim_trace_distance_m := 240.0
@export var grenade_hold_offset := Vector3(0.52, 1.18, -0.62)
@export var grenade_gravity_mps2 := 24.0
@export var grenade_min_throw_distance_m := 2.0
@export var grenade_max_throw_distance_m := 83.0
@export var grenade_min_flight_time_sec := 0.26
@export var grenade_max_flight_time_sec := 2.1
@export var grenade_throw_range_curve := 1.25
@export var grenade_preview_step_sec := 0.08
@export var grenade_preview_max_steps := 30
@export var fishing_cast_gravity_mps2 := 20.0
@export var fishing_cast_min_distance_m := 4.0
@export var fishing_cast_max_distance_m := 28.0
@export var fishing_cast_min_flight_time_sec := 0.22
@export var fishing_cast_max_flight_time_sec := 1.2
@export var fishing_preview_step_sec := 0.08
@export var fishing_preview_max_steps := 24
@export var ads_camera_local_position := Vector3(0.58, 2.05, 4.2)
@export var ads_camera_fov := 42.0
@export var ads_transition_speed := 8.0
@export var ads_mouse_sensitivity_scale := 0.72
@export var wall_climb_speed := 26.0
@export var wall_climb_lateral_speed := 6.0
@export var wall_climb_adhesion_speed := 7.5
@export var wall_climb_probe_distance_m := 2.3
@export var wall_climb_attach_distance_m := 0.72
@export var wall_climb_max_surface_normal_y := 0.3
@export var wall_jump_vertical_velocity := 14.5
@export var wall_jump_push_off_speed := 20.0
@export var ground_slam_initial_speed := 34.0
@export var ground_slam_accel := 132.0
@export var ground_slam_max_speed := 92.0
@export var ground_slam_horizontal_damping := 28.0
@export var ground_slam_shockwave_duration_sec := 0.48
@export var ground_slam_shockwave_radius_m := 7.5
@export var ground_slam_camera_shake_duration_sec := 0.38
@export var ground_slam_camera_shake_amplitude_m := 0.18
@export var vehicle_impact_camera_shake_duration_sec := 0.22
@export var vehicle_impact_camera_shake_amplitude_m := 0.14
@export var vehicle_drive_forward_speed := 42.0
@export var vehicle_drive_reverse_speed := 14.0
@export var vehicle_drive_accel := 36.0
@export var vehicle_drive_brake_decel := 42.0
@export var vehicle_drive_coast_decel := 13.0
@export var vehicle_drive_turn_rate_deg := 94.0
@export var vehicle_drive_turn_rate_idle_deg := 46.0
@export var vehicle_mouse_steer_sensitivity := 0.012
@export var vehicle_mouse_steer_release_speed := 4.0
@export var vehicle_drive_camera_local_position := Vector3(0.0, 3.25, 8.4)
@export var vehicle_drive_camera_fov := 72.0
@export var vehicle_impact_speed_cap_mps := 8.5
@export var water_swim_speed := 5.6
@export var water_sprint_speed := 8.4
@export var water_ascend_speed := 6.4
@export var water_sink_speed := 2.4
@export var water_horizontal_accel := 18.0
@export var water_vertical_accel := 14.0

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var player_visual: Node3D = $Visual

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _pitch := deg_to_rad(-18.0)
var _control_enabled := true
var _movement_locked := false
var _speed_profile := "player"
var _stabilization_suspend_frames := 0
var _collision_resume_process_frames := 0
var _weapon_mode := WEAPON_MODE_RIFLE
var _primary_fire_cooldown_remaining := 0.0
var _primary_fire_active := false
var _aim_down_sights_active := false
var _grenade_hold_requested := false
var _grenade_ready_active := false
var _ads_blend := 0.0
var _default_camera_local_position := Vector3.ZERO
var _default_camera_fov := 65.0
var _camera_rig_base_position := Vector3.ZERO
var _traversal_mode := TRAVERSAL_MODE_GROUNDED
var _wall_climb_reentry_block_frames := 0
var _wall_climb_normal := Vector3.ZERO
var _wall_climb_contact_point := Vector3.ZERO
var _traversal_fx_root: Node3D = null
var _grenade_hold_visual: MeshInstance3D = null
var _grenade_preview_root: Node3D = null
var _grenade_preview_ring: MeshInstance3D = null
var _grenade_preview_dots: Array[MeshInstance3D] = []
var _grenade_preview_state := {
	"visible": false,
	"landing_point": Vector3.ZERO,
	"sample_count": 0,
}
var _active_shockwaves: Array[Dictionary] = []
var _camera_shake_remaining_sec := 0.0
var _camera_shake_total_duration_sec := 0.0
var _camera_shake_amplitude_m := 0.0
var _aim_disturbance_remaining_sec := 0.0
var _aim_disturbance_total_duration_sec := 0.0
var _aim_disturbance_amplitude_deg := 0.0
var _aim_disturbance_elapsed_sec := 0.0
var _aim_disturbance_phase_seed := 0.0
var _slam_impact_count := 0
var _last_slam_impact_speed := 0.0
var _rng := RandomNumberGenerator.new()
var _driving_vehicle := false
var _driving_vehicle_state: Dictionary = {}
var _driving_vehicle_speed_mps := 0.0
var _vehicle_drive_input_override := {
	"throttle": 0.0,
	"steer": 0.0,
	"brake": false,
}
var _vehicle_drive_input_override_active := false
var _vehicle_autodrive_input_override := {
	"throttle": 0.0,
	"steer": 0.0,
	"brake": false,
}
var _vehicle_autodrive_input_override_active := false
var _vehicle_mouse_steer := 0.0
var _water_vertical_input_override := 0.0
var _water_vertical_input_override_active := false
var _vehicle_visual_catalog: CityVehicleVisualCatalog = null
var _drive_vehicle_visual_root: Node3D = null
var _drive_vehicle_model_root: Node3D = null
var _tennis_racket_visual: Node3D = null
var _missile_launcher_visual: Node3D = null
var _fishing_mode_enabled := false
var _fishing_cast_surface_y_m := 0.0
var _fishing_preview_requested := false
var _fishing_pole_visual: Node3D = null
var _fishing_preview_root: Node3D = null
var _fishing_preview_ring: MeshInstance3D = null
var _fishing_preview_dots: Array[MeshInstance3D] = []
var _fishing_preview_state := {
	"visible": false,
	"landing_point": Vector3.ZERO,
	"sample_count": 0,
}
var _lake_water_state := {
	"in_water": false,
	"underwater": false,
	"region_id": "",
	"water_level_y_m": 0.0,
	"depth_m": 0.0,
	"floor_y_m": 0.0,
	"world_position": Vector3.ZERO,
}

func _ready() -> void:
	camera_rig.rotation.x = _pitch
	_camera_rig_base_position = camera_rig.position
	if camera != null:
		_default_camera_local_position = camera.position
		_default_camera_fov = camera.fov
	_rng.seed = 1337
	_vehicle_visual_catalog = CityVehicleVisualCatalog.new()
	_ensure_traversal_fx_root()
	_ensure_tennis_racket_visual()
	_ensure_missile_launcher_visual()
	_ensure_fishing_pole_visual()
	set_tennis_racket_visible(false)
	set_fishing_pole_equipped_visible(false)
	_update_grenade_hold_visual()
	_update_grenade_preview()
	_update_fishing_preview()
	_update_missile_launcher_visual()
	floor_snap_length = _current_floor_snap_length()
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	if _primary_fire_cooldown_remaining > 0.0:
		_primary_fire_cooldown_remaining = maxf(_primary_fire_cooldown_remaining - delta, 0.0)
	if _primary_fire_active and _control_enabled:
		request_primary_fire()
	_update_ads_camera(delta)
	_update_traversal_fx(delta)
	_update_grenade_preview()
	_update_fishing_preview()
	if _collision_resume_process_frames <= 0:
		return
	_collision_resume_process_frames -= 1
	if _collision_resume_process_frames == 0:
		_set_primary_collision_enabled(true)

func _unhandled_input(event: InputEvent) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not _control_enabled:
		return
	if _driving_vehicle:
		if event is InputEventMouseButton:
			var drive_button := event as InputEventMouseButton
			if drive_button.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var drive_motion := event as InputEventMouseMotion
			apply_vehicle_mouse_steer_delta(drive_motion.relative.x)
		elif event.is_action_pressed("ui_cancel"):
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sensitivity := mouse_sensitivity * _current_ads_mouse_sensitivity_scale()
		rotate_y(-motion.relative.x * sensitivity)
		_pitch = clamp(_pitch - motion.relative.y * sensitivity, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		camera_rig.rotation.x = _pitch
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if _fishing_mode_enabled:
			if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
				fishing_cast_action_requested.emit()
			elif button.button_index == MOUSE_BUTTON_RIGHT:
				set_fishing_cast_preview_active(button.pressed)
				fishing_preview_toggled.emit(button.pressed)
			if button.pressed and (button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT):
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			if button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT:
				return
		if button.button_index == MOUSE_BUTTON_LEFT:
			if _weapon_mode == WEAPON_MODE_RIFLE:
				set_primary_fire_active(button.pressed)
			elif _weapon_mode == WEAPON_MODE_GRENADE and button.pressed:
				request_grenade_throw()
			elif _weapon_mode == WEAPON_MODE_LASER_DESIGNATOR and button.pressed:
				request_laser_designator_fire()
			elif _weapon_mode == WEAPON_MODE_MISSILE_LAUNCHER and button.pressed:
				request_missile_launcher_fire()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			if _weapon_mode == WEAPON_MODE_GRENADE:
				set_grenade_ready_active(button.pressed)
			else:
				set_aim_down_sights_active(button.pressed)
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_CTRL:
				request_ground_slam()
			elif key_event.keycode == KEY_0:
				set_weapon_mode(WEAPON_MODE_LASER_DESIGNATOR)
			elif key_event.keycode == KEY_1:
				set_weapon_mode(WEAPON_MODE_RIFLE)
			elif key_event.keycode == KEY_2:
				set_weapon_mode(WEAPON_MODE_GRENADE)
			elif key_event.keycode == KEY_8:
				set_weapon_mode(WEAPON_MODE_MISSILE_LAUNCHER)
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	floor_snap_length = 0.0 if _is_in_lake_water() else _current_floor_snap_length()
	if _driving_vehicle:
		_process_vehicle_drive(delta)
		return
	if _wall_climb_reentry_block_frames > 0:
		_wall_climb_reentry_block_frames -= 1
	if _stabilization_suspend_frames > 0:
		_stabilization_suspend_frames -= 1
	if _is_in_lake_water():
		_process_water_traversal(delta)
		return
	if _traversal_mode == TRAVERSAL_MODE_WALL_CLIMB:
		_process_wall_climb(delta)
		return
	if _traversal_mode == TRAVERSAL_MODE_GROUND_SLAM:
		_process_ground_slam(delta)
		return
	var movement_input_enabled := _control_enabled and not _movement_locked
	if movement_input_enabled and _jump_requested():
		if request_wall_climb():
			return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif movement_input_enabled and _jump_requested():
		velocity.y = jump_velocity

	var input_dir := _read_move_input() if movement_input_enabled else Vector2.ZERO
	var move_dir := Vector3.ZERO
	if input_dir.length() > 0.0:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()

		var right := global_transform.basis.x
		right.y = 0.0
		right = right.normalized()

		move_dir = (right * input_dir.x + forward * input_dir.y).normalized()

	var speed := _current_sprint_speed() if _sprint_requested() else _current_walk_speed()
	if is_on_floor():
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	elif move_dir.length_squared() > 0.0:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed

	if velocity.y <= 0.0 and not _jump_requested():
		apply_floor_snap()
	move_and_slide()
	if _stabilization_suspend_frames <= 0 and velocity.y <= 0.0 and not _jump_requested():
		var snapped_to_ground := _stabilize_ground_contact()
		if snapped_to_ground and not is_on_floor():
			apply_floor_snap()
			velocity.y = -0.01
			move_and_slide()
	_update_default_traversal_mode()

func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		_primary_fire_active = false
		velocity.x = 0.0
		velocity.z = 0.0
		_driving_vehicle_speed_mps = 0.0
		clear_vehicle_autodrive_input()
		clear_water_vertical_input()
	_clear_transient_weapon_state()
	_update_missile_launcher_visual()

func is_control_enabled() -> bool:
	return _control_enabled

func set_movement_locked(enabled: bool) -> void:
	_movement_locked = enabled
	if enabled:
		velocity.x = 0.0
		velocity.z = 0.0

func is_movement_locked() -> bool:
	return _movement_locked

func set_weapon_mode(mode: String) -> void:
	if _driving_vehicle:
		return
	if mode != WEAPON_MODE_RIFLE and mode != WEAPON_MODE_GRENADE and mode != WEAPON_MODE_LASER_DESIGNATOR and mode != WEAPON_MODE_MISSILE_LAUNCHER:
		return
	if _weapon_mode == mode:
		_update_grenade_hold_visual()
		_update_missile_launcher_visual()
		return
	_weapon_mode = mode
	_clear_transient_weapon_state()
	_update_missile_launcher_visual()
	weapon_mode_changed.emit(_weapon_mode)

func get_weapon_mode() -> String:
	return _weapon_mode

func get_weapon_state() -> Dictionary:
	return {
		"mode": _weapon_mode,
		"grenade_hold_requested": _grenade_hold_requested,
		"grenade_ready": _grenade_ready_active,
		"aim_down_sights_active": _aim_down_sights_active,
		"driving_vehicle": _driving_vehicle,
		"fishing_mode_enabled": _fishing_mode_enabled,
	}

func set_fishing_mode_enabled(enabled: bool, cast_surface_y_m: float = 0.0) -> void:
	var next_enabled := enabled and not _driving_vehicle
	var surface_changed := not is_equal_approx(_fishing_cast_surface_y_m, cast_surface_y_m)
	if _fishing_mode_enabled == next_enabled and (not next_enabled or not surface_changed):
		_update_fishing_preview()
		return
	_fishing_mode_enabled = next_enabled
	_fishing_cast_surface_y_m = cast_surface_y_m
	if _fishing_mode_enabled:
		_clear_transient_weapon_state()
	else:
		_fishing_preview_requested = false
		_hide_fishing_preview_visual()
		_fishing_preview_state = {
			"visible": false,
			"landing_point": Vector3.ZERO,
			"sample_count": 0,
		}
	_update_missile_launcher_visual()
	_update_fishing_preview()

func is_fishing_mode_enabled() -> bool:
	return _fishing_mode_enabled

func set_fishing_pole_equipped_visible(should_show: bool) -> void:
	_ensure_fishing_pole_visual()
	if _fishing_pole_visual == null or not is_instance_valid(_fishing_pole_visual):
		return
	if _fishing_pole_visual.has_method("set_equipped_visible"):
		_fishing_pole_visual.set_equipped_visible(should_show)
	else:
		_fishing_pole_visual.visible = should_show
	if not should_show:
		_fishing_preview_requested = false
		_update_fishing_preview()

func set_fishing_cast_preview_active(active: bool) -> void:
	_fishing_preview_requested = active and _fishing_mode_enabled and _control_enabled and not _driving_vehicle
	if not _fishing_preview_requested:
		_hide_fishing_preview_visual()
		_fishing_preview_state = {
			"visible": false,
			"landing_point": Vector3.ZERO,
			"sample_count": 0,
		}
		return
	_update_fishing_preview()

func get_fishing_preview_state() -> Dictionary:
	return _fishing_preview_state.duplicate(true)

func play_fishing_cast_swing() -> void:
	_ensure_fishing_pole_visual()
	if _fishing_pole_visual == null or not is_instance_valid(_fishing_pole_visual):
		return
	if _fishing_pole_visual.has_method("play_cast_swing"):
		_fishing_pole_visual.play_cast_swing()

func get_fishing_tip_world_position() -> Vector3:
	_ensure_fishing_pole_visual()
	if _fishing_pole_visual != null and is_instance_valid(_fishing_pole_visual):
		var tip_anchor := _fishing_pole_visual.get_node_or_null("MountRoot/TipAnchor") as Marker3D
		if tip_anchor != null:
			return tip_anchor.global_position
		return _fishing_pole_visual.global_position
	return global_position + Vector3.UP * 1.2

func get_fishing_visual_state() -> Dictionary:
	_ensure_fishing_pole_visual()
	if _fishing_pole_visual != null and is_instance_valid(_fishing_pole_visual) and _fishing_pole_visual.has_method("get_visual_state"):
		return _fishing_pole_visual.get_visual_state()
	return {
		"pole_present": false,
		"equipped_visible": false,
		"swing_active": false,
		"swing_count": 0,
	}

func set_tennis_racket_visible(should_show: bool) -> void:
	_ensure_tennis_racket_visual()
	if _tennis_racket_visual != null and is_instance_valid(_tennis_racket_visual) and _tennis_racket_visual.has_method("set_equipped_visible"):
		_tennis_racket_visual.set_equipped_visible(should_show)

func play_tennis_swing(swing_style: String = "forehand") -> void:
	_ensure_tennis_racket_visual()
	if _tennis_racket_visual != null and is_instance_valid(_tennis_racket_visual):
		if _tennis_racket_visual.has_method("set_equipped_visible"):
			_tennis_racket_visual.set_equipped_visible(true)
		if _tennis_racket_visual.has_method("play_swing"):
			_tennis_racket_visual.play_swing(swing_style)

func get_tennis_visual_state() -> Dictionary:
	if _tennis_racket_visual != null and is_instance_valid(_tennis_racket_visual) and _tennis_racket_visual.has_method("get_visual_state"):
		return _tennis_racket_visual.get_visual_state()
	return {
		"racket_present": false,
		"equipped_visible": false,
		"swing_active": false,
		"swing_progress": 0.0,
		"swing_count": 0,
		"swing_sound_count": 0,
		"last_swing_style": "",
	}

func get_missile_launcher_visual_state() -> Dictionary:
	_ensure_missile_launcher_visual()
	if _missile_launcher_visual != null and is_instance_valid(_missile_launcher_visual) and _missile_launcher_visual.has_method("get_visual_state"):
		return _missile_launcher_visual.get_visual_state()
	return {
		"equipped_visible": false,
		"fire_fx_active": false,
		"fire_count": 0,
	}

func set_speed_profile(profile: String) -> void:
	if profile != "player" and profile != "inspection":
		return
	_speed_profile = profile

func get_speed_profile() -> String:
	return _speed_profile

func get_walk_speed_mps() -> float:
	return _current_walk_speed()

func get_sprint_speed_mps() -> float:
	return _current_sprint_speed()

func get_pitch_limits_degrees() -> Dictionary:
	return {
		"min": min_pitch_deg,
		"max": max_pitch_deg,
	}

func get_floor_snap_config() -> Dictionary:
	return {
		"player": player_floor_snap_length,
		"inspection": inspection_floor_snap_length,
	}

func get_mobility_tuning() -> Dictionary:
	return {
		"walk_speed": walk_speed,
		"sprint_speed": sprint_speed,
		"jump_velocity": jump_velocity,
		"water_swim_speed": water_swim_speed,
		"water_ascend_speed": water_ascend_speed,
		"wall_climb_speed": wall_climb_speed,
		"wall_jump_vertical_velocity": wall_jump_vertical_velocity,
		"wall_jump_push_off_speed": wall_jump_push_off_speed,
		"ground_slam_initial_speed": ground_slam_initial_speed,
		"ground_slam_max_speed": ground_slam_max_speed,
		"vehicle_drive_forward_speed": vehicle_drive_forward_speed,
		"vehicle_drive_reverse_speed": vehicle_drive_reverse_speed,
	}

func get_traversal_state() -> Dictionary:
	return {
		"mode": _traversal_mode,
		"vertical_speed": velocity.y,
		"wall_normal": _wall_climb_normal,
		"wall_contact_point": _wall_climb_contact_point,
	}

func get_traversal_fx_state() -> Dictionary:
	return {
		"slam_impact_count": _slam_impact_count,
		"last_slam_impact_speed": _last_slam_impact_speed,
		"shockwave_visible": _active_shockwaves.size() > 0,
		"shockwave_count": _active_shockwaves.size(),
		"camera_shake_remaining_sec": _camera_shake_remaining_sec,
		"camera_shake_total_duration_sec": _camera_shake_total_duration_sec,
		"camera_shake_amplitude_m": _camera_shake_amplitude_m,
		"aim_disturbance_remaining_sec": _aim_disturbance_remaining_sec,
		"aim_disturbance_total_duration_sec": _aim_disturbance_total_duration_sec,
		"aim_disturbance_amplitude_deg": _aim_disturbance_amplitude_deg,
	}

func is_driving_vehicle() -> bool:
	return _driving_vehicle

func get_driving_vehicle_state() -> Dictionary:
	var state := _driving_vehicle_state.duplicate(true)
	state["driving"] = _driving_vehicle
	state["speed_mps"] = _driving_vehicle_speed_mps
	var vehicle_world_position := global_position
	if _driving_vehicle:
		vehicle_world_position.y -= _estimate_standing_height()
	state["world_position"] = vehicle_world_position
	var heading := -global_transform.basis.z
	heading.y = 0.0
	state["heading"] = heading.normalized() if heading.length_squared() > 0.0001 else Vector3.FORWARD
	return state

func set_vehicle_drive_input(throttle: float, steer: float, brake: bool = false) -> void:
	_vehicle_drive_input_override_active = true
	_vehicle_drive_input_override = {
		"throttle": clampf(throttle, -1.0, 1.0),
		"steer": clampf(steer, -1.0, 1.0),
		"brake": brake,
	}

func clear_vehicle_drive_input() -> void:
	_vehicle_drive_input_override_active = false
	_vehicle_drive_input_override = {
		"throttle": 0.0,
		"steer": 0.0,
		"brake": false,
	}

func set_vehicle_autodrive_input(throttle: float, steer: float, brake: bool = false) -> void:
	_vehicle_autodrive_input_override_active = true
	_vehicle_autodrive_input_override = {
		"throttle": clampf(throttle, -1.0, 1.0),
		"steer": clampf(steer, -1.0, 1.0),
		"brake": brake,
	}

func clear_vehicle_autodrive_input() -> void:
	_vehicle_autodrive_input_override_active = false
	_vehicle_autodrive_input_override = {
		"throttle": 0.0,
		"steer": 0.0,
		"brake": false,
	}

func set_water_vertical_input(input_value: float) -> void:
	_water_vertical_input_override_active = true
	_water_vertical_input_override = clampf(input_value, -1.0, 1.0)

func clear_water_vertical_input() -> void:
	_water_vertical_input_override_active = false
	_water_vertical_input_override = 0.0

func apply_vehicle_mouse_steer_delta(relative_x: float) -> void:
	if not _driving_vehicle:
		return
	if absf(relative_x) <= 0.001:
		return
	_vehicle_mouse_steer = clampf(_vehicle_mouse_steer - relative_x * vehicle_mouse_steer_sensitivity, -1.0, 1.0)

func has_manual_vehicle_input_request() -> bool:
	if _vehicle_drive_input_override_active:
		return true
	var raw_input := _read_raw_vehicle_drive_input()
	return absf(float(raw_input.get("throttle", 0.0))) > 0.01 \
		or absf(float(raw_input.get("steer", 0.0))) > 0.01 \
		or bool(raw_input.get("brake", false))

func apply_vehicle_impact_slowdown(speed_cap_mps: float = -1.0) -> float:
	if not _driving_vehicle:
		return 0.0
	var resolved_speed_cap_mps := speed_cap_mps if speed_cap_mps >= 0.0 else vehicle_impact_speed_cap_mps
	_driving_vehicle_speed_mps = minf(_driving_vehicle_speed_mps, maxf(resolved_speed_cap_mps, 0.0))
	return _driving_vehicle_speed_mps

func enter_vehicle_drive_mode(vehicle_state: Dictionary) -> void:
	if vehicle_state.is_empty():
		return
	_driving_vehicle = true
	_driving_vehicle_state = vehicle_state.duplicate(true)
	_driving_vehicle_speed_mps = 0.0
	_clear_transient_weapon_state()
	_traversal_mode = TRAVERSAL_MODE_GROUNDED
	_wall_climb_normal = Vector3.ZERO
	_wall_climb_contact_point = Vector3.ZERO
	clear_vehicle_drive_input()
	clear_vehicle_autodrive_input()
	_clear_vehicle_mouse_steer()
	var heading: Vector3 = vehicle_state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	rotation.y = _yaw_from_drive_heading(heading.normalized())
	_pitch = deg_to_rad(-10.0)
	camera_rig.rotation.x = _pitch
	global_position = vehicle_state.get("world_position", global_position)
	global_position.y += _estimate_standing_height()
	if player_visual != null:
		player_visual.visible = false
	_update_missile_launcher_visual()
	_mount_drive_vehicle_visual(vehicle_state)
	if not _stabilize_ground_contact():
		suspend_ground_stabilization(4)

func exit_vehicle_drive_mode(exit_lateral_offset_m: float = 2.35) -> Dictionary:
	if not _driving_vehicle:
		return {}
	var exit_state := get_driving_vehicle_state()
	var heading: Vector3 = exit_state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	var lateral := Vector3(-heading.z, 0.0, heading.x)
	if lateral.length_squared() <= 0.0001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized()
	_driving_vehicle = false
	_driving_vehicle_state = {}
	_driving_vehicle_speed_mps = 0.0
	clear_vehicle_drive_input()
	clear_vehicle_autodrive_input()
	_clear_vehicle_mouse_steer()
	velocity = Vector3.ZERO
	_traversal_mode = TRAVERSAL_MODE_GROUNDED
	_wall_climb_normal = Vector3.ZERO
	_wall_climb_contact_point = Vector3.ZERO
	if player_visual != null:
		player_visual.visible = true
	_update_missile_launcher_visual()
	if _drive_vehicle_model_root != null and is_instance_valid(_drive_vehicle_model_root):
		_drive_vehicle_model_root.queue_free()
	_drive_vehicle_model_root = null
	if _drive_vehicle_visual_root != null and is_instance_valid(_drive_vehicle_visual_root):
		_drive_vehicle_visual_root.visible = false
	var exit_world_position: Vector3 = exit_state.get("world_position", global_position)
	global_position = exit_world_position + lateral * exit_lateral_offset_m + Vector3.UP * _estimate_standing_height()
	suspend_ground_stabilization(12)
	return exit_state

func set_primary_fire_active(active: bool) -> void:
	if _driving_vehicle:
		_primary_fire_active = false
		return
	_primary_fire_active = active and _control_enabled and _weapon_mode == WEAPON_MODE_RIFLE
	if _primary_fire_active:
		request_primary_fire()

func set_aim_down_sights_active(active: bool) -> void:
	var next_active := active and _control_enabled and _weapon_mode != WEAPON_MODE_GRENADE
	if _driving_vehicle:
		next_active = false
	if _aim_down_sights_active == next_active:
		return
	_aim_down_sights_active = next_active
	aim_down_sights_changed.emit(_aim_down_sights_active)

func is_aim_down_sights_active() -> bool:
	return _aim_down_sights_active

func set_grenade_ready_active(active: bool) -> void:
	if _driving_vehicle:
		_grenade_hold_requested = false
		_grenade_ready_active = false
		_update_grenade_hold_visual()
		_update_grenade_preview()
		return
	_grenade_hold_requested = active and _control_enabled and _weapon_mode == WEAPON_MODE_GRENADE
	_grenade_ready_active = _grenade_hold_requested
	_update_grenade_hold_visual()
	_update_grenade_preview()

func is_grenade_ready_active() -> bool:
	return _grenade_ready_active

func get_grenade_preview_state() -> Dictionary:
	return _grenade_preview_state.duplicate(true)

func get_fishing_cast_spawn_transform() -> Transform3D:
	var aim_basis := _resolve_aim_basis()
	return Transform3D(aim_basis, get_fishing_tip_world_position())

func get_fishing_cast_launch_velocity() -> Vector3:
	var cast_profile := _build_fishing_cast_profile()
	return cast_profile.get("launch_velocity", Vector3.ZERO)

func get_camera_fov_state() -> Dictionary:
	return {
		"default": _default_camera_fov,
		"ads": ads_camera_fov,
		"current": camera.fov if camera != null else _default_camera_fov,
		"blend": _ads_blend,
	}

func request_primary_fire() -> bool:
	if not _control_enabled:
		return false
	if _driving_vehicle:
		return false
	if _weapon_mode != WEAPON_MODE_RIFLE:
		return false
	if _primary_fire_cooldown_remaining > 0.0:
		return false
	_primary_fire_cooldown_remaining = primary_fire_cooldown_sec
	primary_fire_requested.emit()
	return true

func request_grenade_throw() -> bool:
	if not _control_enabled:
		return false
	if _driving_vehicle:
		return false
	if _weapon_mode != WEAPON_MODE_GRENADE:
		return false
	if not _grenade_ready_active:
		return false
	_grenade_ready_active = false
	_update_grenade_hold_visual()
	_update_grenade_preview()
	grenade_throw_requested.emit()
	if _grenade_hold_requested:
		call_deferred("_restore_grenade_ready_from_hold")
	return true

func request_laser_designator_fire() -> bool:
	if not _control_enabled:
		return false
	if _driving_vehicle:
		return false
	if _weapon_mode != WEAPON_MODE_LASER_DESIGNATOR:
		return false
	laser_designator_requested.emit()
	return true

func request_missile_launcher_fire() -> bool:
	if not _control_enabled:
		return false
	if _driving_vehicle:
		return false
	if _weapon_mode != WEAPON_MODE_MISSILE_LAUNCHER:
		return false
	_play_missile_launcher_fire_fx()
	missile_launcher_requested.emit()
	return true

func request_wall_climb() -> bool:
	if not _control_enabled:
		return false
	if _driving_vehicle:
		return false
	if _is_in_lake_water():
		return false
	if _wall_climb_reentry_block_frames > 0:
		return false
	var wall_hit := _find_climbable_wall()
	if wall_hit.is_empty():
		return false
	_enter_wall_climb(wall_hit)
	return true

func request_wall_jump() -> bool:
	if not _control_enabled:
		return false
	if _driving_vehicle:
		return false
	if _traversal_mode != TRAVERSAL_MODE_WALL_CLIMB:
		return false
	if _wall_climb_normal.length_squared() <= 0.0001:
		return false
	var wall_normal := _wall_climb_normal.normalized()
	var input_dir := _read_move_input() if _control_enabled else Vector2.ZERO
	var wall_tangent := Vector3(wall_normal.z, 0.0, -wall_normal.x).normalized()
	velocity = Vector3.UP * wall_jump_vertical_velocity
	velocity += wall_normal * wall_jump_push_off_speed
	velocity += wall_tangent * input_dir.x * wall_climb_lateral_speed
	global_position += wall_normal * maxf(wall_climb_attach_distance_m * 1.15, 0.85)
	_traversal_mode = TRAVERSAL_MODE_AIRBORNE
	_wall_climb_contact_point = global_position
	_wall_climb_reentry_block_frames = 10
	suspend_ground_stabilization(8)
	return true

func request_ground_slam() -> bool:
	if not _control_enabled:
		return false
	if _driving_vehicle:
		return false
	if _is_in_lake_water():
		return false
	if _traversal_mode == TRAVERSAL_MODE_GROUNDED or is_on_floor():
		return false
	if _wall_climb_normal.length_squared() > 0.0001:
		global_position += _wall_climb_normal * 0.35
	_traversal_mode = TRAVERSAL_MODE_GROUND_SLAM
	_wall_climb_normal = Vector3.ZERO
	velocity.x *= 0.25
	velocity.z *= 0.25
	velocity.y = minf(velocity.y, -ground_slam_initial_speed)
	return true

func get_projectile_spawn_transform() -> Transform3D:
	var aim_basis := _resolve_aim_basis()
	var right := global_transform.basis.x.normalized()
	var up := Vector3.UP
	var player_forward := (-global_transform.basis.z).normalized()
	var origin := global_position
	origin += right * primary_fire_shoulder_offset.x
	origin += up * primary_fire_shoulder_offset.y
	origin += player_forward * (primary_fire_forward_offset_m + primary_fire_shoulder_offset.z)
	return Transform3D(aim_basis, origin)

func get_projectile_direction() -> Vector3:
	var spawn_origin := get_projectile_spawn_transform().origin
	var aim_target := _resolve_aim_target_world_position()
	return (aim_target - spawn_origin).normalized()

func get_grenade_spawn_transform() -> Transform3D:
	var aim_basis := _resolve_aim_basis()
	var right := global_transform.basis.x.normalized()
	var up := Vector3.UP
	var player_forward := (-global_transform.basis.z).normalized()
	var origin := global_position
	origin += right * grenade_hold_offset.x
	origin += up * grenade_hold_offset.y
	origin += player_forward * absf(grenade_hold_offset.z)
	return Transform3D(aim_basis, origin)

func get_grenade_launch_velocity() -> Vector3:
	var spawn_origin := get_grenade_spawn_transform().origin
	var horizontal_direction := _get_grenade_horizontal_direction()
	var range_factor := _get_grenade_throw_range_factor()
	var target_distance_m := lerpf(grenade_min_throw_distance_m, grenade_max_throw_distance_m, range_factor)
	var target_surface_position := _resolve_grenade_surface_target(spawn_origin, horizontal_direction, target_distance_m)
	var planar_delta := Vector3(target_surface_position.x - spawn_origin.x, 0.0, target_surface_position.z - spawn_origin.z)
	var planar_distance_m := maxf(planar_delta.length(), 0.001)
	var flight_time_sec := lerpf(grenade_min_flight_time_sec, grenade_max_flight_time_sec, range_factor)
	flight_time_sec = maxf(flight_time_sec, 0.12)
	var horizontal_speed_mps := planar_distance_m / flight_time_sec
	var vertical_delta_m := target_surface_position.y - spawn_origin.y
	var vertical_speed_mps := (vertical_delta_m + 0.5 * grenade_gravity_mps2 * flight_time_sec * flight_time_sec) / flight_time_sec
	var launch_velocity := horizontal_direction * horizontal_speed_mps
	launch_velocity.y = vertical_speed_mps
	return launch_velocity

func _get_grenade_throw_range_factor() -> float:
	var pitch_radians := camera_rig.rotation.x if camera_rig != null else _pitch
	var pitch_span := deg_to_rad(max_pitch_deg) - deg_to_rad(min_pitch_deg)
	if absf(pitch_span) <= 0.0001:
		return 1.0
	var normalized := (pitch_radians - deg_to_rad(min_pitch_deg)) / pitch_span
	normalized = clampf(normalized, 0.0, 1.0)
	return pow(normalized, grenade_throw_range_curve)

func _get_grenade_horizontal_direction() -> Vector3:
	var aim_basis: Basis = camera.global_transform.basis if camera != null else global_transform.basis
	var forward := (-aim_basis.z).normalized()
	var horizontal_direction := Vector3(forward.x, 0.0, forward.z)
	if horizontal_direction.length_squared() <= 0.0001:
		horizontal_direction = Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z)
	if horizontal_direction.length_squared() <= 0.0001:
		horizontal_direction = Vector3.FORWARD
	return horizontal_direction.normalized()

func _resolve_grenade_surface_target(spawn_origin: Vector3, horizontal_direction: Vector3, target_distance_m: float) -> Vector3:
	var probe_position := spawn_origin + horizontal_direction * target_distance_m
	var fallback_position := Vector3(
		probe_position.x,
		global_position.y - _estimate_standing_height(),
		probe_position.z
	)
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return fallback_position
	var max_height_above_spawn_m := _resolve_grenade_surface_height_budget(target_distance_m)
	var excluded_rids: Array[RID] = [get_rid()]
	for _attempt in range(8):
		var query := PhysicsRayQueryParameters3D.create(
			probe_position + Vector3.UP * 48.0,
			probe_position + Vector3.DOWN * 96.0
		)
		query.collide_with_areas = false
		query.exclude = excluded_rids
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return fallback_position
		var hit_position: Vector3 = hit.get("position", fallback_position)
		if hit_position.y <= spawn_origin.y + max_height_above_spawn_m:
			return hit_position
		var collider := hit.get("collider") as CollisionObject3D
		if collider == null:
			return fallback_position
		excluded_rids.append(collider.get_rid())
	return fallback_position

func _resolve_grenade_surface_height_budget(target_distance_m: float) -> float:
	if target_distance_m <= 10.0:
		return 2.5
	if target_distance_m <= 24.0:
		return 5.0
	if target_distance_m <= 48.0:
		return 10.0
	return 18.0

func get_aim_target_world_position() -> Vector3:
	return _resolve_aim_target_world_position()

func get_aim_trace_segment() -> Dictionary:
	var aim_basis := _resolve_aim_basis()
	var origin: Vector3 = camera.global_position if camera != null else global_position + Vector3.UP * 1.4
	var forward := (-aim_basis.z).normalized()
	return {
		"origin": origin,
		"target": origin + forward * aim_trace_distance_m,
		"distance_m": aim_trace_distance_m,
	}

func _resolve_aim_target_world_position() -> Vector3:
	var trace_segment: Dictionary = get_aim_trace_segment()
	var origin: Vector3 = trace_segment.get("origin", global_position + Vector3.UP * 1.4)
	var fallback_target: Vector3 = trace_segment.get("target", origin + Vector3.FORWARD * aim_trace_distance_m)
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return fallback_target
	var query := PhysicsRayQueryParameters3D.create(origin, fallback_target)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return fallback_target
	return hit.get("position", fallback_target)

func suspend_ground_stabilization(frame_count: int) -> void:
	_stabilization_suspend_frames = maxi(_stabilization_suspend_frames, frame_count)

func trigger_camera_shake(duration_sec: float, amplitude_m: float, aim_disturbance_deg: float = 0.0) -> void:
	_camera_shake_total_duration_sec = maxf(duration_sec, 0.0)
	_camera_shake_remaining_sec = maxf(_camera_shake_remaining_sec, _camera_shake_total_duration_sec)
	_camera_shake_amplitude_m = maxf(_camera_shake_amplitude_m, amplitude_m)
	if aim_disturbance_deg <= 0.0:
		return
	if _aim_disturbance_remaining_sec <= 0.0:
		_aim_disturbance_elapsed_sec = 0.0
		_aim_disturbance_phase_seed = _rng.randf_range(0.0, TAU)
	_aim_disturbance_total_duration_sec = maxf(duration_sec, 0.0)
	_aim_disturbance_remaining_sec = maxf(_aim_disturbance_remaining_sec, _aim_disturbance_total_duration_sec)
	_aim_disturbance_amplitude_deg = maxf(_aim_disturbance_amplitude_deg, aim_disturbance_deg)

func _restore_grenade_ready_from_hold() -> void:
	if not _control_enabled:
		return
	if _weapon_mode != WEAPON_MODE_GRENADE:
		return
	if not _grenade_hold_requested:
		return
	_grenade_ready_active = true
	_update_grenade_hold_visual()
	_update_grenade_preview()

func _process_vehicle_drive(delta: float) -> void:
	if _stabilization_suspend_frames > 0:
		_stabilization_suspend_frames -= 1
	var drive_input: Dictionary = _read_vehicle_drive_input()
	var throttle := float(drive_input.get("throttle", 0.0))
	var steer := float(drive_input.get("steer", 0.0))
	var brake := bool(drive_input.get("brake", false))
	var drive_tuning := _resolve_active_vehicle_drive_tuning()
	var forward_speed := float(drive_tuning.get("forward_speed", vehicle_drive_forward_speed))
	var reverse_speed := float(drive_tuning.get("reverse_speed", vehicle_drive_reverse_speed))
	var accel := float(drive_tuning.get("accel", vehicle_drive_accel))
	var speed_ratio := clampf(absf(_driving_vehicle_speed_mps) / maxf(forward_speed, 0.001), 0.0, 1.0)
	var turn_rate_deg := lerpf(vehicle_drive_turn_rate_idle_deg, vehicle_drive_turn_rate_deg, speed_ratio)
	if absf(_driving_vehicle_speed_mps) > 0.05 or absf(throttle) > 0.0:
		var drive_direction_sign := 1.0 if _driving_vehicle_speed_mps >= 0.0 else -1.0
		rotation.y += deg_to_rad(turn_rate_deg) * steer * drive_direction_sign * delta
	if brake:
		_driving_vehicle_speed_mps = move_toward(_driving_vehicle_speed_mps, 0.0, vehicle_drive_brake_decel * delta)
	elif throttle > 0.0:
		_driving_vehicle_speed_mps = move_toward(_driving_vehicle_speed_mps, forward_speed * throttle, accel * delta)
	elif throttle < 0.0:
		if _driving_vehicle_speed_mps > 1.0:
			_driving_vehicle_speed_mps = move_toward(_driving_vehicle_speed_mps, 0.0, vehicle_drive_brake_decel * delta)
		else:
			_driving_vehicle_speed_mps = move_toward(_driving_vehicle_speed_mps, -reverse_speed * absf(throttle), accel * delta)
	else:
		_driving_vehicle_speed_mps = move_toward(_driving_vehicle_speed_mps, 0.0, vehicle_drive_coast_decel * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	velocity.x = forward.x * _driving_vehicle_speed_mps
	velocity.z = forward.z * _driving_vehicle_speed_mps
	apply_floor_snap()
	move_and_slide()
	if _stabilization_suspend_frames <= 0 and velocity.y <= 0.0:
		var snapped_to_ground := _stabilize_ground_contact()
		if snapped_to_ground and not is_on_floor():
			apply_floor_snap()
			velocity.y = -0.01
			move_and_slide()
	_decay_vehicle_mouse_steer(delta)

func _process_water_traversal(delta: float) -> void:
	_traversal_mode = TRAVERSAL_MODE_AIRBORNE
	_wall_climb_normal = Vector3.ZERO
	_wall_climb_contact_point = Vector3.ZERO
	var movement_input_enabled := _control_enabled and not _movement_locked
	var input_dir := _read_move_input() if movement_input_enabled else Vector2.ZERO
	var move_dir := Vector3.ZERO
	if input_dir.length() > 0.0:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		move_dir = (right * input_dir.x + forward * input_dir.y).normalized()
	var target_velocity := move_dir * _current_water_swim_speed()
	var horizontal_step := water_horizontal_accel * maxf(delta, 0.0)
	velocity.x = move_toward(velocity.x, target_velocity.x, horizontal_step)
	velocity.z = move_toward(velocity.z, target_velocity.z, horizontal_step)
	var vertical_input := _read_water_vertical_input() if movement_input_enabled else 0.0
	if vertical_input > 0.0 and is_on_floor():
		velocity.y = maxf(velocity.y, water_ascend_speed * 0.65)
	var target_vertical_speed := water_ascend_speed * vertical_input - water_sink_speed
	velocity.y = move_toward(velocity.y, target_vertical_speed, water_vertical_accel * maxf(delta, 0.0))
	move_and_slide()

func _read_vehicle_drive_input() -> Dictionary:
	if _vehicle_drive_input_override_active:
		return _merge_vehicle_mouse_steer(_vehicle_drive_input_override)
	if _vehicle_autodrive_input_override_active:
		return _vehicle_autodrive_input_override.duplicate(true)
	return _merge_vehicle_mouse_steer(_read_raw_vehicle_drive_input())

func _read_raw_vehicle_drive_input() -> Dictionary:
	var throttle := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		throttle -= 1.0
	var steer := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		steer += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		steer -= 1.0
	var brake := Input.is_key_pressed(KEY_SPACE) or (throttle < 0.0 and _driving_vehicle_speed_mps > 1.0)
	return {
		"throttle": clampf(throttle, -1.0, 1.0),
		"steer": clampf(steer, -1.0, 1.0),
		"brake": brake,
	}

func _mount_drive_vehicle_visual(vehicle_state: Dictionary) -> void:
	_ensure_drive_vehicle_visual_root()
	if _drive_vehicle_visual_root == null or _vehicle_visual_catalog == null:
		return
	if _drive_vehicle_model_root != null and is_instance_valid(_drive_vehicle_model_root):
		_drive_vehicle_model_root.queue_free()
	_drive_vehicle_model_root = null
	var model_id := str(vehicle_state.get("model_id", ""))
	var entry := _vehicle_visual_catalog.get_entry(model_id)
	if entry.is_empty():
		entry = _vehicle_visual_catalog.select_entry_for_state(vehicle_state)
	if entry.is_empty():
		return
	var model_root := _vehicle_visual_catalog.instantiate_scene_for_entry(entry)
	if model_root == null:
		return
	_drive_vehicle_model_root = model_root
	_drive_vehicle_model_root.name = "Model"
	_drive_vehicle_model_root.scale = Vector3.ONE * _vehicle_visual_catalog.resolve_runtime_scale(entry)
	_drive_vehicle_model_root.position = Vector3(0.0, _vehicle_visual_catalog.resolve_ground_offset_m(entry) * _vehicle_visual_catalog.resolve_runtime_scale(entry), 0.0)
	_drive_vehicle_visual_root.add_child(_drive_vehicle_model_root)
	_drive_vehicle_visual_root.visible = true

func _ensure_drive_vehicle_visual_root() -> void:
	if _drive_vehicle_visual_root != null and is_instance_valid(_drive_vehicle_visual_root):
		return
	var drive_root := Node3D.new()
	drive_root.name = "DriveVehicleVisual"
	drive_root.position = Vector3(0.0, -_estimate_standing_height(), 0.0)
	drive_root.rotation.y = PI
	add_child(drive_root)
	_drive_vehicle_visual_root = drive_root

func _yaw_from_drive_heading(heading: Vector3) -> float:
	return atan2(-heading.x, -heading.z)

func _resolve_active_vehicle_drive_tuning() -> Dictionary:
	var speed_multiplier := 1.0
	if str(_driving_vehicle_state.get("model_id", "")) == SPORTS_CAR_MODEL_ID:
		speed_multiplier = SPORTS_CAR_SPEED_MULTIPLIER
	return {
		"forward_speed": vehicle_drive_forward_speed * speed_multiplier,
		"reverse_speed": vehicle_drive_reverse_speed * speed_multiplier,
		"accel": vehicle_drive_accel * speed_multiplier,
	}

func _merge_vehicle_mouse_steer(drive_input: Dictionary) -> Dictionary:
	var merged := drive_input.duplicate(true)
	if absf(_vehicle_mouse_steer) <= 0.0001:
		return merged
	merged["steer"] = clampf(float(merged.get("steer", 0.0)) + _vehicle_mouse_steer, -1.0, 1.0)
	return merged

func _decay_vehicle_mouse_steer(delta: float) -> void:
	if absf(_vehicle_mouse_steer) <= 0.0001:
		_vehicle_mouse_steer = 0.0
		return
	_vehicle_mouse_steer = move_toward(_vehicle_mouse_steer, 0.0, vehicle_mouse_steer_release_speed * maxf(delta, 0.0))

func _clear_vehicle_mouse_steer() -> void:
	_vehicle_mouse_steer = 0.0

func _read_move_input() -> Vector2:
	var horizontal := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		horizontal += 1.0

	var vertical := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		vertical += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		vertical -= 1.0

	return Vector2(horizontal, vertical).normalized()

func _read_water_vertical_input() -> float:
	if _water_vertical_input_override_active:
		return _water_vertical_input_override
	return 1.0 if _jump_requested() else 0.0

func _jump_requested() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("ui_accept")

func _wall_jump_requested() -> bool:
	return Input.is_action_just_pressed("ui_accept")

func _sprint_requested() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)

func _current_water_swim_speed() -> float:
	return water_sprint_speed if _sprint_requested() else water_swim_speed

func _is_in_lake_water() -> bool:
	return bool(_lake_water_state.get("in_water", false))

func _current_walk_speed() -> float:
	return inspection_walk_speed if _speed_profile == "inspection" else walk_speed

func _current_sprint_speed() -> float:
	return inspection_sprint_speed if _speed_profile == "inspection" else sprint_speed

func _current_floor_snap_length() -> float:
	return inspection_floor_snap_length if _speed_profile == "inspection" else player_floor_snap_length

func _stabilize_ground_contact() -> bool:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return false
	var standing_height := _estimate_standing_height()
	var probe_length := standing_height + _current_floor_snap_length() + 0.6
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.25,
		global_position + Vector3.DOWN * probe_length
	)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_position: Vector3 = hit.get("position", global_position)
	var target_y := hit_position.y + standing_height
	if absf(global_position.y - target_y) > _current_floor_snap_length() + 0.75:
		return false
	global_position.y = target_y
	velocity.y = 0.0
	return true

func _estimate_standing_height() -> float:
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0

func teleport_to_world_position(world_position: Vector3) -> void:
	_suspend_primary_collision_for_frames(2)
	global_position = world_position
	velocity = Vector3.ZERO

func set_lake_water_state(state: Dictionary) -> void:
	var next_state := {
		"in_water": bool(state.get("in_water", false)),
		"underwater": bool(state.get("underwater", false)),
		"region_id": str(state.get("region_id", "")),
		"water_level_y_m": float(state.get("water_level_y_m", 0.0)),
		"depth_m": float(state.get("depth_m", 0.0)),
		"floor_y_m": float(state.get("floor_y_m", 0.0)),
		"world_position": state.get("world_position", global_position),
	}
	if next_state == _lake_water_state:
		return
	_lake_water_state = next_state

func get_lake_water_state() -> Dictionary:
	return _lake_water_state.duplicate(true)

func advance_toward_world_position(target_position: Vector3, step_distance: float) -> bool:
	var planar_delta := Vector3(target_position.x - global_position.x, 0.0, target_position.z - global_position.z)
	var planar_distance := planar_delta.length()
	if planar_distance <= step_distance:
		_suspend_primary_collision_for_frames(2)
		global_position = Vector3(target_position.x, target_position.y, target_position.z)
		velocity = Vector3.ZERO
		return true

	var direction := planar_delta / planar_distance
	global_position += direction * step_distance
	global_position.y = target_position.y
	velocity = Vector3.ZERO
	return false

func _suspend_primary_collision_for_frames(frame_count: int) -> void:
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		return
	_set_primary_collision_enabled(false)
	_collision_resume_process_frames = maxi(_collision_resume_process_frames, frame_count)

func _set_primary_collision_enabled(enabled: bool) -> void:
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		return
	collision_shape.disabled = not enabled

func _update_ads_camera(delta: float) -> void:
	if camera == null:
		return
	if _driving_vehicle:
		_ads_blend = 0.0
		_pitch = lerpf(_pitch, deg_to_rad(-10.0), delta * 5.0)
		camera_rig.rotation.x = _pitch
		camera.position = camera.position.lerp(vehicle_drive_camera_local_position, clampf(delta * 8.0, 0.0, 1.0))
		camera.fov = lerpf(camera.fov, vehicle_drive_camera_fov, clampf(delta * 8.0, 0.0, 1.0))
		return
	var target_blend := 1.0 if _aim_down_sights_active and _control_enabled else 0.0
	_ads_blend = move_toward(_ads_blend, target_blend, delta * ads_transition_speed)
	camera.position = _default_camera_local_position.lerp(ads_camera_local_position, _ads_blend)
	camera.fov = lerpf(_default_camera_fov, ads_camera_fov, _ads_blend)

func _current_ads_mouse_sensitivity_scale() -> float:
	return ads_mouse_sensitivity_scale if _aim_down_sights_active else 1.0

func _find_climbable_wall() -> Dictionary:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return {}
	var origin := global_position + Vector3.UP * 1.0
	var forward := (-global_transform.basis.z).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * wall_climb_probe_distance_m)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
	if absf(hit_normal.y) > wall_climb_max_surface_normal_y:
		return {}
	return hit

func _enter_wall_climb(wall_hit: Dictionary) -> void:
	_traversal_mode = TRAVERSAL_MODE_WALL_CLIMB
	_wall_climb_reentry_block_frames = 0
	_wall_climb_normal = wall_hit.get("normal", Vector3.BACK)
	_wall_climb_contact_point = wall_hit.get("position", global_position)
	velocity = Vector3.ZERO
	suspend_ground_stabilization(8)

func _process_wall_climb(_delta: float) -> void:
	if _control_enabled and Input.is_key_pressed(KEY_CTRL):
		request_ground_slam()
		return
	if _control_enabled and _wall_jump_requested():
		if request_wall_jump():
			return
	var wall_hit := _find_climbable_wall()
	if wall_hit.is_empty():
		_traversal_mode = TRAVERSAL_MODE_AIRBORNE
		return
	_wall_climb_normal = wall_hit.get("normal", _wall_climb_normal)
	_wall_climb_contact_point = wall_hit.get("position", _wall_climb_contact_point)
	var tangent := Vector3(_wall_climb_normal.z, 0.0, -_wall_climb_normal.x).normalized()
	var input_dir := _read_move_input() if _control_enabled else Vector2.ZERO
	var climb_speed := wall_climb_speed * (0.55 if input_dir.y < 0.0 else 1.0)
	velocity = Vector3.UP * climb_speed
	velocity += tangent * input_dir.x * wall_climb_lateral_speed
	velocity += -_wall_climb_normal * wall_climb_adhesion_speed
	move_and_slide()
	_maintain_wall_climb_offset()
	_traversal_mode = TRAVERSAL_MODE_WALL_CLIMB

func _maintain_wall_climb_offset() -> void:
	if _wall_climb_normal.length_squared() <= 0.0001:
		return
	var target_position := _wall_climb_contact_point + _wall_climb_normal * wall_climb_attach_distance_m
	global_position.x = target_position.x
	global_position.z = target_position.z

func _process_ground_slam(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_slam_horizontal_damping * delta)
	velocity.z = move_toward(velocity.z, 0.0, ground_slam_horizontal_damping * delta)
	velocity.y = maxf(velocity.y - ground_slam_accel * delta, -ground_slam_max_speed)
	var impact_speed := absf(velocity.y)
	move_and_slide()
	var stabilized_to_ground := false
	if not is_on_floor():
		stabilized_to_ground = _stabilize_ground_contact()
	if is_on_floor() or stabilized_to_ground:
		if stabilized_to_ground and not is_on_floor():
			apply_floor_snap()
			velocity.y = -0.01
			move_and_slide()
		_trigger_ground_slam_impact(impact_speed)
		_traversal_mode = TRAVERSAL_MODE_GROUNDED
		velocity.y = 0.0
		return
	_traversal_mode = TRAVERSAL_MODE_GROUND_SLAM

func _update_default_traversal_mode() -> void:
	if _traversal_mode == TRAVERSAL_MODE_WALL_CLIMB or _traversal_mode == TRAVERSAL_MODE_GROUND_SLAM:
		return
	_traversal_mode = TRAVERSAL_MODE_GROUNDED if is_on_floor() else TRAVERSAL_MODE_AIRBORNE

func _ensure_traversal_fx_root() -> void:
	if get_node_or_null("TraversalFx") != null:
		_traversal_fx_root = get_node_or_null("TraversalFx") as Node3D
		return
	var fx_root := Node3D.new()
	fx_root.name = "TraversalFx"
	add_child(fx_root)
	_traversal_fx_root = fx_root

func _ensure_tennis_racket_visual() -> void:
	if _tennis_racket_visual != null and is_instance_valid(_tennis_racket_visual):
		return
	var visual_parent := player_visual if player_visual != null and is_instance_valid(player_visual) else self
	_tennis_racket_visual = visual_parent.get_node_or_null("TennisRacketVisual") as Node3D
	if _tennis_racket_visual == null:
		_tennis_racket_visual = TennisRacketVisualRig.new()
		_tennis_racket_visual.name = "TennisRacketVisual"
		visual_parent.add_child(_tennis_racket_visual)
	if _tennis_racket_visual.has_method("configure_rig"):
		_tennis_racket_visual.configure_rig({
			"mount_position": Vector3(0.66, 0.38, -0.18),
			"rest_rotation_deg": Vector3(18.0, 16.0, -26.0),
			"forehand_rotation_deg": Vector3(-48.0, 28.0, -146.0),
			"backhand_rotation_deg": Vector3(-36.0, -30.0, 136.0),
			"serve_rotation_deg": Vector3(-122.0, 24.0, -168.0),
			"forehand_position_offset": Vector3(0.18, -0.07, 0.24),
			"backhand_position_offset": Vector3(-0.18, -0.04, 0.22),
			"serve_position_offset": Vector3(0.05, 0.38, 0.32),
			"normalize_visual_to_target_length": true,
			"target_length_m": 0.69,
			"swing_duration_sec": 0.28,
		})

func _ensure_missile_launcher_visual() -> void:
	if _missile_launcher_visual != null and is_instance_valid(_missile_launcher_visual):
		return
	var visual_parent := player_visual if player_visual != null and is_instance_valid(player_visual) else self
	_missile_launcher_visual = visual_parent.get_node_or_null("RpgLauncherEquippedVisual") as Node3D

func _update_missile_launcher_visual() -> void:
	_ensure_missile_launcher_visual()
	if _missile_launcher_visual == null or not is_instance_valid(_missile_launcher_visual):
		return
	var should_show := _weapon_mode == WEAPON_MODE_MISSILE_LAUNCHER and _control_enabled and not _driving_vehicle and not _fishing_mode_enabled
	if _missile_launcher_visual.has_method("set_equipped_visible"):
		_missile_launcher_visual.set_equipped_visible(should_show)
	else:
		_missile_launcher_visual.visible = should_show

func _play_missile_launcher_fire_fx() -> void:
	_ensure_missile_launcher_visual()
	if _missile_launcher_visual == null or not is_instance_valid(_missile_launcher_visual):
		return
	if _missile_launcher_visual.has_method("play_fire_fx"):
		_missile_launcher_visual.play_fire_fx()

func _ensure_grenade_hold_visual() -> void:
	if get_node_or_null("GrenadeHoldVisual") != null:
		_grenade_hold_visual = get_node_or_null("GrenadeHoldVisual") as MeshInstance3D
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GrenadeHoldVisual"
	mesh_instance.position = grenade_hold_offset
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.26
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.219608, 0.243137, 0.294118, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.34902, 0.901961, 0.654902, 1.0)
	material.emission_energy_multiplier = 0.2
	mesh_instance.material_override = material
	mesh_instance.visible = false
	add_child(mesh_instance)
	_grenade_hold_visual = mesh_instance

func _ensure_grenade_preview_visual() -> void:
	if get_node_or_null("GrenadePreview") != null:
		_grenade_preview_root = get_node_or_null("GrenadePreview") as Node3D
	if _grenade_preview_root == null:
		_grenade_preview_root = Node3D.new()
		_grenade_preview_root.name = "GrenadePreview"
		_grenade_preview_root.top_level = true
		add_child(_grenade_preview_root)
	if _grenade_preview_ring == null or not is_instance_valid(_grenade_preview_ring):
		_grenade_preview_ring = _grenade_preview_root.get_node_or_null("LandingRing") as MeshInstance3D
	if _grenade_preview_ring == null:
		_grenade_preview_ring = MeshInstance3D.new()
		_grenade_preview_ring.name = "LandingRing"
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 1.6
		ring_mesh.bottom_radius = 1.6
		ring_mesh.height = 0.08
		ring_mesh.radial_segments = 24
		_grenade_preview_ring.mesh = ring_mesh
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.albedo_color = Color(0.694118, 0.980392, 0.658824, 0.52)
		ring_material.emission_enabled = true
		ring_material.emission = Color(0.352941, 1.0, 0.568627, 1.0)
		ring_material.emission_energy_multiplier = 0.85
		_grenade_preview_ring.material_override = ring_material
		_grenade_preview_ring.visible = false
		_grenade_preview_root.add_child(_grenade_preview_ring)
	if _grenade_preview_dots.is_empty():
		for index in range(grenade_preview_max_steps):
			var dot := MeshInstance3D.new()
			dot.name = "PreviewDot%d" % index
			var dot_mesh := SphereMesh.new()
			dot_mesh.radius = 0.075
			dot_mesh.height = 0.15
			dot.mesh = dot_mesh
			var dot_material := StandardMaterial3D.new()
			dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dot_material.albedo_color = Color(0.854902, 1.0, 0.886275, 0.42)
			dot_material.emission_enabled = true
			dot_material.emission = Color(0.564706, 1.0, 0.780392, 1.0)
			dot_material.emission_energy_multiplier = 0.38
			dot.material_override = dot_material
			dot.visible = false
			_grenade_preview_root.add_child(dot)
			_grenade_preview_dots.append(dot)

func _update_grenade_hold_visual() -> void:
	var should_show := _weapon_mode == WEAPON_MODE_GRENADE and _grenade_ready_active and _control_enabled and not _fishing_mode_enabled
	if should_show and (_grenade_hold_visual == null or not is_instance_valid(_grenade_hold_visual)):
		_ensure_grenade_hold_visual()
	if _grenade_hold_visual == null or not is_instance_valid(_grenade_hold_visual):
		return
	_grenade_hold_visual.visible = should_show

func _update_grenade_preview() -> void:
	var preview_visible := _weapon_mode == WEAPON_MODE_GRENADE and _grenade_ready_active and _control_enabled and not _fishing_mode_enabled
	if not preview_visible:
		if not bool(_grenade_preview_state.get("visible", false)):
			return
		_hide_grenade_preview_visual()
		_grenade_preview_state = {
			"visible": false,
			"landing_point": Vector3.ZERO,
			"sample_count": 0,
		}
		return
	_ensure_grenade_preview_visual()
	if _grenade_preview_root == null:
		return
	var preview_state := _build_grenade_preview_state()
	var preview_points: Array = preview_state.get("points", [])
	var landing_point: Vector3 = preview_state.get("landing_point", Vector3.ZERO)
	for dot_index in range(_grenade_preview_dots.size()):
		var dot := _grenade_preview_dots[dot_index]
		if dot == null or not is_instance_valid(dot):
			continue
		if dot_index < preview_points.size():
			dot.global_position = preview_points[dot_index]
			dot.visible = true
		else:
			dot.visible = false
	if _grenade_preview_ring != null and is_instance_valid(_grenade_preview_ring):
		_grenade_preview_ring.global_position = landing_point + Vector3.UP * 0.04
		_grenade_preview_ring.visible = preview_points.size() > 0
	_grenade_preview_state = {
		"visible": preview_points.size() > 0,
		"landing_point": landing_point,
		"sample_count": preview_points.size(),
	}

func _hide_grenade_preview_visual() -> void:
	for dot in _grenade_preview_dots:
		if dot != null and is_instance_valid(dot):
			dot.visible = false
	if _grenade_preview_ring != null and is_instance_valid(_grenade_preview_ring):
		_grenade_preview_ring.visible = false

func _build_grenade_preview_state() -> Dictionary:
	var points: Array[Vector3] = []
	var current_position := get_grenade_spawn_transform().origin
	var current_velocity := get_grenade_launch_velocity()
	var landing_point := current_position
	var space_state := get_world_3d().direct_space_state if get_world_3d() != null else null
	for _step_index in range(grenade_preview_max_steps):
		var next_velocity := current_velocity + Vector3.DOWN * grenade_gravity_mps2 * grenade_preview_step_sec
		var next_position := current_position + (current_velocity + next_velocity) * 0.5 * grenade_preview_step_sec
		if space_state != null:
			var query := PhysicsRayQueryParameters3D.create(current_position, next_position)
			query.collide_with_areas = false
			query.exclude = [get_rid()]
			var hit: Dictionary = space_state.intersect_ray(query)
			if not hit.is_empty():
				landing_point = hit.get("position", next_position)
				points.append(landing_point)
				break
		landing_point = next_position
		points.append(next_position)
		current_position = next_position
		current_velocity = next_velocity
	return {
		"points": points,
		"landing_point": landing_point,
	}

func _ensure_fishing_pole_visual() -> void:
	if _fishing_pole_visual != null and is_instance_valid(_fishing_pole_visual):
		return
	var visual_parent := player_visual if player_visual != null and is_instance_valid(player_visual) else self
	var hold_anchor := visual_parent.get_node_or_null("FishingPoleHoldAnchor") as Node3D
	if hold_anchor == null:
		return
	_fishing_pole_visual = hold_anchor.get_node_or_null("FishingPoleEquippedVisual") as Node3D

func _ensure_fishing_preview_visual() -> void:
	if get_node_or_null("FishingPreview") != null:
		_fishing_preview_root = get_node_or_null("FishingPreview") as Node3D
	if _fishing_preview_root == null:
		_fishing_preview_root = Node3D.new()
		_fishing_preview_root.name = "FishingPreview"
		_fishing_preview_root.top_level = true
		add_child(_fishing_preview_root)
	if _fishing_preview_ring == null or not is_instance_valid(_fishing_preview_ring):
		_fishing_preview_ring = _fishing_preview_root.get_node_or_null("LandingRing") as MeshInstance3D
	if _fishing_preview_ring == null:
		_fishing_preview_ring = MeshInstance3D.new()
		_fishing_preview_ring.name = "LandingRing"
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 0.42
		ring_mesh.bottom_radius = 0.42
		ring_mesh.height = 0.05
		ring_mesh.radial_segments = 24
		_fishing_preview_ring.mesh = ring_mesh
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.albedo_color = Color(0.980392, 0.913725, 0.556863, 0.58)
		ring_material.emission_enabled = true
		ring_material.emission = Color(0.992157, 0.831373, 0.431373, 1.0)
		ring_material.emission_energy_multiplier = 0.88
		_fishing_preview_ring.material_override = ring_material
		_fishing_preview_ring.visible = false
		_fishing_preview_root.add_child(_fishing_preview_ring)
	if _fishing_preview_dots.is_empty():
		for index in range(fishing_preview_max_steps):
			var dot := MeshInstance3D.new()
			dot.name = "PreviewDot%d" % index
			var dot_mesh := SphereMesh.new()
			dot_mesh.radius = 0.055
			dot_mesh.height = 0.11
			dot.mesh = dot_mesh
			var dot_material := StandardMaterial3D.new()
			dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dot_material.albedo_color = Color(1.0, 0.956863, 0.768627, 0.46)
			dot_material.emission_enabled = true
			dot_material.emission = Color(1.0, 0.905882, 0.611765, 1.0)
			dot_material.emission_energy_multiplier = 0.42
			dot.material_override = dot_material
			dot.visible = false
			_fishing_preview_root.add_child(dot)
			_fishing_preview_dots.append(dot)

func _update_fishing_preview() -> void:
	var preview_visible := _fishing_preview_requested and _fishing_mode_enabled and _control_enabled and not _driving_vehicle
	if not preview_visible:
		if not bool(_fishing_preview_state.get("visible", false)):
			return
		_hide_fishing_preview_visual()
		_fishing_preview_state = {
			"visible": false,
			"landing_point": Vector3.ZERO,
			"sample_count": 0,
		}
		return
	_ensure_fishing_preview_visual()
	if _fishing_preview_root == null:
		return
	var preview_state := _build_fishing_preview_state()
	var preview_points: Array = preview_state.get("points", [])
	var landing_point: Vector3 = preview_state.get("landing_point", Vector3.ZERO)
	for dot_index in range(_fishing_preview_dots.size()):
		var dot := _fishing_preview_dots[dot_index]
		if dot == null or not is_instance_valid(dot):
			continue
		if dot_index < preview_points.size():
			dot.global_position = preview_points[dot_index]
			dot.visible = true
		else:
			dot.visible = false
	if _fishing_preview_ring != null and is_instance_valid(_fishing_preview_ring):
		_fishing_preview_ring.global_position = landing_point + Vector3.UP * 0.03
		_fishing_preview_ring.visible = preview_points.size() > 0
	_fishing_preview_state = {
		"visible": preview_points.size() > 0,
		"landing_point": landing_point,
		"sample_count": preview_points.size(),
	}

func _hide_fishing_preview_visual() -> void:
	for dot in _fishing_preview_dots:
		if dot != null and is_instance_valid(dot):
			dot.visible = false
	if _fishing_preview_ring != null and is_instance_valid(_fishing_preview_ring):
		_fishing_preview_ring.visible = false

func _build_fishing_preview_state() -> Dictionary:
	var cast_profile := _build_fishing_cast_profile()
	var points: Array[Vector3] = []
	var current_position: Vector3 = cast_profile.get("spawn_origin", get_fishing_tip_world_position())
	var current_velocity: Vector3 = cast_profile.get("launch_velocity", Vector3.ZERO)
	var landing_point: Vector3 = cast_profile.get("landing_point", current_position)
	for _step_index in range(fishing_preview_max_steps):
		var next_velocity := current_velocity + Vector3.DOWN * fishing_cast_gravity_mps2 * fishing_preview_step_sec
		var next_position := current_position + (current_velocity + next_velocity) * 0.5 * fishing_preview_step_sec
		if next_position.y <= _fishing_cast_surface_y_m:
			points.append(landing_point)
			break
		points.append(next_position)
		current_position = next_position
		current_velocity = next_velocity
	if points.is_empty():
		points.append(landing_point)
	return {
		"points": points,
		"landing_point": landing_point,
	}

func _build_fishing_cast_profile() -> Dictionary:
	var spawn_origin := get_fishing_cast_spawn_transform().origin
	var horizontal_direction := _get_grenade_horizontal_direction()
	var range_factor := _get_grenade_throw_range_factor()
	var target_distance_m := lerpf(fishing_cast_min_distance_m, fishing_cast_max_distance_m, range_factor)
	var landing_point := Vector3(
		spawn_origin.x + horizontal_direction.x * target_distance_m,
		_fishing_cast_surface_y_m,
		spawn_origin.z + horizontal_direction.z * target_distance_m
	)
	var planar_delta := Vector3(landing_point.x - spawn_origin.x, 0.0, landing_point.z - spawn_origin.z)
	var planar_distance_m := maxf(planar_delta.length(), 0.001)
	var flight_time_sec := lerpf(fishing_cast_min_flight_time_sec, fishing_cast_max_flight_time_sec, range_factor)
	flight_time_sec = maxf(flight_time_sec, 0.12)
	var horizontal_speed_mps := planar_distance_m / flight_time_sec
	var vertical_delta_m := landing_point.y - spawn_origin.y
	var vertical_speed_mps := (vertical_delta_m + 0.5 * fishing_cast_gravity_mps2 * flight_time_sec * flight_time_sec) / flight_time_sec
	var launch_velocity := horizontal_direction * horizontal_speed_mps
	launch_velocity.y = vertical_speed_mps
	return {
		"spawn_origin": spawn_origin,
		"landing_point": landing_point,
		"launch_velocity": launch_velocity,
	}

func _clear_transient_weapon_state() -> void:
	var ads_was_active := _aim_down_sights_active
	_primary_fire_active = false
	_aim_down_sights_active = false
	_grenade_hold_requested = false
	_grenade_ready_active = false
	_update_grenade_hold_visual()
	_update_grenade_preview()
	if ads_was_active:
		aim_down_sights_changed.emit(false)

func _trigger_ground_slam_impact(impact_speed: float) -> void:
	_slam_impact_count += 1
	_last_slam_impact_speed = impact_speed
	_spawn_ground_slam_shockwave()
	trigger_camera_shake(ground_slam_camera_shake_duration_sec, ground_slam_camera_shake_amplitude_m)

func _spawn_ground_slam_shockwave() -> void:
	_ensure_traversal_fx_root()
	if _traversal_fx_root == null or not is_inside_tree() or not _traversal_fx_root.is_inside_tree():
		return
	var shockwave := MeshInstance3D.new()
	shockwave.name = "SlamShockwave%d" % _slam_impact_count
	shockwave.mesh = _build_ground_slam_shockwave_mesh()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.78, 0.94, 1.0, 0.72)
	material.emission_enabled = true
	material.emission = Color(0.42, 0.86, 1.0, 1.0)
	material.emission_energy_multiplier = 1.2
	shockwave.material_override = material
	_traversal_fx_root.add_child(shockwave)
	shockwave.position = Vector3(0.0, -_estimate_standing_height() + 0.08, 0.0)
	shockwave.scale = Vector3(0.2, 1.0, 0.2)
	_active_shockwaves.append({
		"node": shockwave,
		"material": material,
		"elapsed_sec": 0.0,
		"duration_sec": ground_slam_shockwave_duration_sec,
	})

func _build_ground_slam_shockwave_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.08
	mesh.radial_segments = 24
	mesh.rings = 1
	return mesh

func _update_traversal_fx(delta: float) -> void:
	_update_active_shockwaves(delta)
	_update_aim_disturbance(delta)
	_update_camera_shake(delta)

func _update_aim_disturbance(delta: float) -> void:
	if _aim_disturbance_remaining_sec <= 0.0:
		_aim_disturbance_remaining_sec = 0.0
		_aim_disturbance_total_duration_sec = 0.0
		_aim_disturbance_amplitude_deg = 0.0
		return
	_aim_disturbance_elapsed_sec += maxf(delta, 0.0)
	_aim_disturbance_remaining_sec = maxf(_aim_disturbance_remaining_sec - delta, 0.0)

func _resolve_aim_basis() -> Basis:
	var aim_basis: Basis = camera.global_transform.basis if camera != null else global_transform.basis
	var disturbance_angles := _get_aim_disturbance_angles_rad()
	if disturbance_angles.length_squared() <= 0.0000001:
		return aim_basis
	var yaw_basis := Basis(Vector3.UP, disturbance_angles.x)
	aim_basis = yaw_basis * aim_basis
	var pitch_axis := aim_basis.x.normalized()
	if pitch_axis.length_squared() > 0.0001:
		aim_basis = Basis(pitch_axis, disturbance_angles.y) * aim_basis
	return aim_basis.orthonormalized()

func _get_aim_disturbance_angles_rad() -> Vector2:
	if _aim_disturbance_remaining_sec <= 0.0 or _aim_disturbance_amplitude_deg <= 0.0:
		return Vector2.ZERO
	var normalized_remaining := 1.0
	if _aim_disturbance_total_duration_sec > 0.0001:
		normalized_remaining = clampf(_aim_disturbance_remaining_sec / _aim_disturbance_total_duration_sec, 0.0, 1.0)
	var envelope := clampf(0.42 + normalized_remaining * 0.58, 0.0, 1.0)
	var yaw_wave := sin(_aim_disturbance_elapsed_sec * 8.6 + _aim_disturbance_phase_seed)
	var pitch_wave := cos(_aim_disturbance_elapsed_sec * 11.4 + _aim_disturbance_phase_seed * 1.37)
	return Vector2(
		deg_to_rad(yaw_wave * _aim_disturbance_amplitude_deg * envelope),
		deg_to_rad(pitch_wave * _aim_disturbance_amplitude_deg * 0.82 * envelope)
	)

func _update_active_shockwaves(delta: float) -> void:
	if _active_shockwaves.is_empty():
		return
	var remaining_shockwaves: Array[Dictionary] = []
	for shockwave_entry in _active_shockwaves:
		var entry: Dictionary = shockwave_entry
		var shockwave := entry.get("node") as MeshInstance3D
		var material := entry.get("material") as StandardMaterial3D
		if shockwave == null or not is_instance_valid(shockwave):
			continue
		var elapsed_sec := float(entry.get("elapsed_sec", 0.0)) + delta
		var duration_sec := maxf(float(entry.get("duration_sec", ground_slam_shockwave_duration_sec)), 0.001)
		var progress := clampf(elapsed_sec / duration_sec, 0.0, 1.0)
		var radius_scale := lerpf(0.2, ground_slam_shockwave_radius_m, progress)
		shockwave.scale = Vector3(radius_scale, 1.0, radius_scale)
		if material != null:
			material.albedo_color.a = lerpf(0.72, 0.0, progress)
			material.emission_energy_multiplier = lerpf(1.25, 0.0, progress)
		if progress >= 1.0:
			shockwave.queue_free()
			continue
		entry["elapsed_sec"] = elapsed_sec
		remaining_shockwaves.append(entry)
	_active_shockwaves = remaining_shockwaves

func _update_camera_shake(delta: float) -> void:
	if camera_rig == null:
		return
	if _camera_shake_remaining_sec <= 0.0:
		_camera_shake_remaining_sec = 0.0
		_camera_shake_total_duration_sec = 0.0
		_camera_shake_amplitude_m = 0.0
		camera_rig.position = _camera_rig_base_position
		return
	_camera_shake_remaining_sec = maxf(_camera_shake_remaining_sec - delta, 0.0)
	var normalized := 0.0
	if _camera_shake_total_duration_sec > 0.0:
		normalized = _camera_shake_remaining_sec / _camera_shake_total_duration_sec
	var current_amplitude := _camera_shake_amplitude_m * normalized
	var shake_offset := Vector3(
		_rng.randf_range(-current_amplitude, current_amplitude),
		_rng.randf_range(-current_amplitude, current_amplitude),
		_rng.randf_range(-current_amplitude * 0.35, current_amplitude * 0.35)
	)
	camera_rig.position = _camera_rig_base_position + shake_offset
