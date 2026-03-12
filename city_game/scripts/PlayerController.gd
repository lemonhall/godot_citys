extends CharacterBody3D

signal primary_fire_requested

const TRAVERSAL_MODE_GROUNDED := "grounded"
const TRAVERSAL_MODE_AIRBORNE := "airborne"
const TRAVERSAL_MODE_WALL_CLIMB := "wall_climb"
const TRAVERSAL_MODE_GROUND_SLAM := "ground_slam"

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
@export var ads_camera_local_position := Vector3(0.58, 2.05, 4.2)
@export var ads_camera_fov := 42.0
@export var ads_transition_speed := 8.0
@export var ads_mouse_sensitivity_scale := 0.72
@export var wall_climb_speed := 16.5
@export var wall_climb_lateral_speed := 6.0
@export var wall_climb_adhesion_speed := 7.5
@export var wall_climb_probe_distance_m := 2.3
@export var wall_climb_attach_distance_m := 0.72
@export var wall_climb_max_surface_normal_y := 0.3
@export var ground_slam_initial_speed := 34.0
@export var ground_slam_accel := 132.0
@export var ground_slam_max_speed := 92.0
@export var ground_slam_horizontal_damping := 28.0
@export var ground_slam_shockwave_duration_sec := 0.48
@export var ground_slam_shockwave_radius_m := 7.5
@export var ground_slam_camera_shake_duration_sec := 0.38
@export var ground_slam_camera_shake_amplitude_m := 0.18

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _pitch := deg_to_rad(-18.0)
var _control_enabled := true
var _speed_profile := "player"
var _stabilization_suspend_frames := 0
var _collision_resume_process_frames := 0
var _primary_fire_cooldown_remaining := 0.0
var _primary_fire_active := false
var _aim_down_sights_active := false
var _ads_blend := 0.0
var _default_camera_local_position := Vector3.ZERO
var _default_camera_fov := 65.0
var _camera_rig_base_position := Vector3.ZERO
var _traversal_mode := TRAVERSAL_MODE_GROUNDED
var _wall_climb_normal := Vector3.ZERO
var _wall_climb_contact_point := Vector3.ZERO
var _traversal_fx_root: Node3D = null
var _active_shockwaves: Array[Dictionary] = []
var _camera_shake_remaining_sec := 0.0
var _camera_shake_amplitude_m := 0.0
var _slam_impact_count := 0
var _last_slam_impact_speed := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	camera_rig.rotation.x = _pitch
	_camera_rig_base_position = camera_rig.position
	if camera != null:
		_default_camera_local_position = camera.position
		_default_camera_fov = camera.fov
	_rng.seed = 1337
	_ensure_traversal_fx_root()
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

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sensitivity := mouse_sensitivity * _current_ads_mouse_sensitivity_scale()
		rotate_y(-motion.relative.x * sensitivity)
		_pitch = clamp(_pitch - motion.relative.y * sensitivity, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		camera_rig.rotation.x = _pitch
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			set_primary_fire_active(button.pressed)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			set_aim_down_sights_active(button.pressed)
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_CTRL:
			request_ground_slam()
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	floor_snap_length = _current_floor_snap_length()
	if _stabilization_suspend_frames > 0:
		_stabilization_suspend_frames -= 1
	if _traversal_mode == TRAVERSAL_MODE_WALL_CLIMB:
		_process_wall_climb(delta)
		return
	if _traversal_mode == TRAVERSAL_MODE_GROUND_SLAM:
		_process_ground_slam(delta)
		return
	if _control_enabled and _jump_requested():
		if request_wall_climb():
			return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif _control_enabled and _jump_requested():
		velocity.y = jump_velocity

	var input_dir := _read_move_input() if _control_enabled else Vector2.ZERO
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
		_aim_down_sights_active = false
		velocity.x = 0.0
		velocity.z = 0.0

func is_control_enabled() -> bool:
	return _control_enabled

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
		"wall_climb_speed": wall_climb_speed,
		"ground_slam_initial_speed": ground_slam_initial_speed,
		"ground_slam_max_speed": ground_slam_max_speed,
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
		"camera_shake_amplitude_m": _camera_shake_amplitude_m,
	}

func set_primary_fire_active(active: bool) -> void:
	_primary_fire_active = active and _control_enabled
	if _primary_fire_active:
		request_primary_fire()

func set_aim_down_sights_active(active: bool) -> void:
	_aim_down_sights_active = active and _control_enabled

func is_aim_down_sights_active() -> bool:
	return _aim_down_sights_active

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
	if _primary_fire_cooldown_remaining > 0.0:
		return false
	_primary_fire_cooldown_remaining = primary_fire_cooldown_sec
	primary_fire_requested.emit()
	return true

func request_wall_climb() -> bool:
	if not _control_enabled:
		return false
	var wall_hit := _find_climbable_wall()
	if wall_hit.is_empty():
		return false
	_enter_wall_climb(wall_hit)
	return true

func request_ground_slam() -> bool:
	if not _control_enabled:
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
	var aim_basis: Basis = camera.global_transform.basis if camera != null else global_transform.basis
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

func get_aim_target_world_position() -> Vector3:
	return _resolve_aim_target_world_position()

func _resolve_aim_target_world_position() -> Vector3:
	var aim_basis: Basis = camera.global_transform.basis if camera != null else global_transform.basis
	var origin := camera.global_position if camera != null else global_position + Vector3.UP * 1.4
	var forward := (-aim_basis.z).normalized()
	var fallback_target := origin + forward * aim_trace_distance_m
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

func _jump_requested() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("ui_accept")

func _sprint_requested() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)

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
	_wall_climb_normal = wall_hit.get("normal", Vector3.BACK)
	_wall_climb_contact_point = wall_hit.get("position", global_position)
	velocity = Vector3.ZERO
	suspend_ground_stabilization(8)

func _process_wall_climb(delta: float) -> void:
	if _control_enabled and Input.is_key_pressed(KEY_CTRL):
		request_ground_slam()
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

func _trigger_ground_slam_impact(impact_speed: float) -> void:
	_slam_impact_count += 1
	_last_slam_impact_speed = impact_speed
	_spawn_ground_slam_shockwave()
	_camera_shake_remaining_sec = ground_slam_camera_shake_duration_sec
	_camera_shake_amplitude_m = ground_slam_camera_shake_amplitude_m

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
	_update_camera_shake(delta)

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
		_camera_shake_amplitude_m = 0.0
		camera_rig.position = _camera_rig_base_position
		return
	_camera_shake_remaining_sec = maxf(_camera_shake_remaining_sec - delta, 0.0)
	var normalized := 0.0
	if ground_slam_camera_shake_duration_sec > 0.0:
		normalized = _camera_shake_remaining_sec / ground_slam_camera_shake_duration_sec
	var current_amplitude := _camera_shake_amplitude_m * normalized
	var shake_offset := Vector3(
		_rng.randf_range(-current_amplitude, current_amplitude),
		_rng.randf_range(-current_amplitude, current_amplitude),
		_rng.randf_range(-current_amplitude * 0.35, current_amplitude * 0.35)
	)
	camera_rig.position = _camera_rig_base_position + shake_offset
