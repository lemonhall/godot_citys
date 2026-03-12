extends CharacterBody3D

signal projectile_fire_requested(origin: Vector3, direction: Vector3)

const BEHAVIOR_APPROACH := "approach"
const BEHAVIOR_ORBIT := "orbit"
const ROLE_ID_ASSAULT := "assault"
const HEALTH_BAR_FILL_DEPTH_OFFSET_M := -0.028
const HEALTH_BAR_WORLD_OFFSET := Vector3(0.0, 2.85, 0.0)

@export var chase_speed_mps := 10.5
@export var orbit_speed_mps := 8.0
@export var dodge_distance_m := 7.5
@export var dodge_cooldown_sec := 0.9
@export var dodge_prediction_sec := 0.45
@export var dodge_trigger_radius_m := 1.8
@export var floor_snap_length_m := 1.4
@export var max_health := 3.0
@export var corpse_cleanup_delay_sec := 15.0
@export var corpse_body_rest_height_m := 0.58
@export var corpse_body_roll_deg := 90.0
@export var orbit_radius_m := 9.5
@export var orbit_activation_radius_m := 13.5
@export var orbit_break_radius_m := 16.5
@export var obstacle_probe_distance_m := 4.0
@export var ranged_fire_min_distance_m := 9.0
@export var ranged_fire_max_distance_m := 30.0
@export var burst_cooldown_sec := 1.6
@export var burst_interval_sec := 0.11
@export var burst_shot_count := 3
@export var camouflage_duration_sec := 0.42
@export var camouflage_min_alpha := 0.18
@export var camouflage_flicker_hz := 18.0
@export var pressure_dash_activation_radius_m := 9999.0
@export var pressure_dash_min_distance_m := 6.4
@export var pressure_dash_forward_m := 4.4
@export var pressure_dash_lateral_m := 5.9
@export var pressure_dash_interval_sec := 0.5
@export var pressure_dash_energy_max := 6.0
@export var pressure_dash_energy_cost := 1.0
@export var pressure_dash_energy_recharge_per_sec := 0.18
@export var pressure_zigzag_move_bias := 0.8
@export var pressure_chase_speed_mps := 16.0

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _target: Node3D = null
var _health := 0.0
var _dodge_cooldown_remaining := 0.0
var _dodge_count := 0
var _last_dodge_offset := Vector3.ZERO
var _behavior_mode := BEHAVIOR_APPROACH
var _orbit_direction_sign := 1.0
var _burst_cooldown_remaining := 0.0
var _burst_interval_remaining := 0.0
var _burst_shots_remaining := 0
var _camouflage_remaining_sec := 0.0
var _camouflage_alpha := 1.0
var _body: MeshInstance3D = null
var _body_material: StandardMaterial3D = null
var _body_standing_position := Vector3.ZERO
var _body_standing_rotation := Vector3.ZERO
var _health_bar_root: Node3D = null
var _health_bar_fill_anchor: Node3D = null
var _health_bar_fill_material: StandardMaterial3D = null
var _pressure_energy := 0.0
var _pressure_dash_interval_remaining := 0.0
var _pressure_dash_count := 0
var _pressure_last_dash_offset := Vector3.ZERO
var _pressure_zigzag_sign := 1
var _pressure_sign_history: Array[int] = []
var _combat_active := true

func _ready() -> void:
	add_to_group("city_enemy")
	_health = max_health
	_combat_active = true
	_pressure_energy = pressure_dash_energy_max
	_ensure_collision()
	_ensure_visual()
	_ensure_health_bar()
	floor_snap_length = floor_snap_length_m
	_update_health_feedback()
	_update_health_bar_transform()
	_update_visual_state()

func configure(target: Node3D) -> void:
	_target = target

func get_dodge_count() -> int:
	return _dodge_count

func get_last_dodge_offset() -> Vector3:
	return _last_dodge_offset

func get_role_id() -> String:
	return ROLE_ID_ASSAULT

func get_behavior_mode() -> String:
	return _behavior_mode

func get_standing_height() -> float:
	return _estimate_standing_height()

func get_camouflage_state() -> Dictionary:
	return {
		"active": _camouflage_remaining_sec > 0.0,
		"alpha": _camouflage_alpha,
		"time_remaining_sec": _camouflage_remaining_sec,
	}

func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(_health / maxf(max_health, 0.001), 0.0, 1.0)

func get_health_state() -> Dictionary:
	return {
		"current": maxf(_health, 0.0),
		"max": maxf(max_health, 0.0),
		"ratio": get_health_ratio(),
		"alive": _health > 0.0,
		"combat_active": _combat_active,
		"state": "combat" if _combat_active else "corpse",
		"visible": _health_bar_root != null and _health_bar_root.visible,
	}

func is_combat_active() -> bool:
	return _combat_active

func set_corpse_cleanup_delay_sec(duration_sec: float) -> void:
	corpse_cleanup_delay_sec = maxf(duration_sec, 0.0)

func get_pressure_state() -> Dictionary:
	return {
		"energy": _pressure_energy,
		"energy_max": pressure_dash_energy_max,
		"energy_ratio": _get_pressure_energy_ratio(),
		"dash_count": _pressure_dash_count,
		"last_dash_offset": _pressure_last_dash_offset,
		"next_sign": _pressure_zigzag_sign,
		"sign_history": _pressure_sign_history.duplicate(),
		"can_dash": _can_execute_pressure_dash(),
	}

func apply_projectile_hit(projectile_damage: float, _hit_position: Vector3, _impulse: Vector3) -> void:
	if not _combat_active:
		return
	_health = maxf(_health - projectile_damage, 0.0)
	_update_health_feedback()
	if _health <= 0.0:
		_enter_corpse_state()

func _physics_process(delta: float) -> void:
	floor_snap_length = floor_snap_length_m
	if _dodge_cooldown_remaining > 0.0:
		_dodge_cooldown_remaining = maxf(_dodge_cooldown_remaining - delta, 0.0)
	if _burst_cooldown_remaining > 0.0:
		_burst_cooldown_remaining = maxf(_burst_cooldown_remaining - delta, 0.0)
	if _burst_interval_remaining > 0.0:
		_burst_interval_remaining = maxf(_burst_interval_remaining - delta, 0.0)
	if _pressure_dash_interval_remaining > 0.0:
		_pressure_dash_interval_remaining = maxf(_pressure_dash_interval_remaining - delta, 0.0)
	if _camouflage_remaining_sec > 0.0:
		_camouflage_remaining_sec = maxf(_camouflage_remaining_sec - delta, 0.0)
	_recharge_pressure_energy(delta)
	_evaluate_incoming_projectiles()
	_update_behavior_mode()
	_try_execute_pressure_dash()
	_update_ranged_fire()
	_update_visual_state()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var move_direction := _compute_move_direction()
	var move_speed := orbit_speed_mps if _behavior_mode == BEHAVIOR_ORBIT else _resolve_pressure_move_speed()
	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed
	if velocity.y <= 0.0:
		apply_floor_snap()
	move_and_slide()
	if velocity.y <= 0.0:
		_stabilize_ground_contact()
	_face_target()
	_update_health_bar_transform()

func _update_behavior_mode() -> void:
	if _target == null or not is_instance_valid(_target):
		_behavior_mode = BEHAVIOR_APPROACH
		return
	var planar_delta := _target.global_position - global_position
	planar_delta.y = 0.0
	var distance_to_target := planar_delta.length()
	var preserve_pressure := _should_preserve_pressure_mode(distance_to_target)
	if _behavior_mode == BEHAVIOR_ORBIT:
		if distance_to_target >= orbit_break_radius_m or preserve_pressure:
			_behavior_mode = BEHAVIOR_APPROACH
	else:
		if distance_to_target <= orbit_activation_radius_m and not preserve_pressure:
			_behavior_mode = BEHAVIOR_ORBIT

func _compute_move_direction() -> Vector3:
	if _target == null or not is_instance_valid(_target):
		return Vector3.ZERO
	var planar_delta := _target.global_position - global_position
	planar_delta.y = 0.0
	var distance_to_target := planar_delta.length()
	if distance_to_target <= 0.001:
		return Vector3.ZERO
	var to_target := planar_delta / distance_to_target
	if _behavior_mode == BEHAVIOR_ORBIT:
		var tangent := Vector3(-to_target.z, 0.0, to_target.x) * _orbit_direction_sign
		var radial_correction := clampf((distance_to_target - orbit_radius_m) / maxf(orbit_radius_m, 0.001), -0.85, 0.85)
		var orbit_direction := (tangent * 1.35 + to_target * radial_correction).normalized()
		return _avoid_obstacles(orbit_direction)
	if _is_pressure_window(distance_to_target):
		var zigzag_tangent := Vector3(-to_target.z, 0.0, to_target.x) * float(_pressure_zigzag_sign)
		var pressure_direction := (to_target * 1.18 + zigzag_tangent * pressure_zigzag_move_bias).normalized()
		return _avoid_obstacles(pressure_direction)
	return _avoid_obstacles(to_target)

func _evaluate_incoming_projectiles() -> void:
	if _dodge_cooldown_remaining > 0.0 or get_tree() == null:
		return
	for projectile in get_tree().get_nodes_in_group("city_projectile"):
		if projectile == null or not is_instance_valid(projectile):
			continue
		if not projectile.has_method("get_velocity"):
			continue
		if consider_incoming_projectile(projectile.global_position, projectile.get_velocity()):
			return

func consider_incoming_projectile(projectile_position: Vector3, projectile_velocity: Vector3) -> bool:
	var planar_velocity := Vector3(projectile_velocity.x, 0.0, projectile_velocity.z)
	var planar_speed_sq := planar_velocity.length_squared()
	if planar_speed_sq <= 0.0001:
		return false
	var planar_relative := Vector3(global_position.x - projectile_position.x, 0.0, global_position.z - projectile_position.z)
	if planar_velocity.dot(planar_relative) <= 0.0:
		return false
	var time_to_closest := clampf(planar_relative.dot(planar_velocity) / planar_speed_sq, 0.0, dodge_prediction_sec)
	if time_to_closest <= 0.0:
		return false
	var closest_point := projectile_position + projectile_velocity * time_to_closest
	var miss_distance := Vector2(global_position.x - closest_point.x, global_position.z - closest_point.z).length()
	if miss_distance > dodge_trigger_radius_m:
		return false
	return _execute_dodge(planar_velocity.normalized())

func _execute_dodge(projectile_direction: Vector3) -> bool:
	var lateral := Vector3(-projectile_direction.z, 0.0, projectile_direction.x).normalized()
	if lateral.length_squared() <= 0.0001:
		return false
	var current_position := global_position
	var best_position := current_position
	var best_score: float = INF
	for direction_sign in [-1.0, 1.0]:
		var candidate: Vector3 = current_position + lateral * dodge_distance_m * direction_sign
		candidate = _resolve_surface_position(candidate)
		var score: float = candidate.distance_to(_target.global_position) if _target != null and is_instance_valid(_target) else 0.0
		if score < best_score:
			best_score = score
			best_position = candidate
	if best_position.distance_to(current_position) <= 0.5:
		return false
	global_position = best_position
	velocity = Vector3.ZERO
	_last_dodge_offset = best_position - current_position
	_dodge_count += 1
	_dodge_cooldown_remaining = dodge_cooldown_sec
	_behavior_mode = BEHAVIOR_ORBIT
	_activate_camouflage()
	return true

func _try_execute_pressure_dash() -> bool:
	if not _can_execute_pressure_dash():
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	var planar_delta := _target.global_position - global_position
	planar_delta.y = 0.0
	var distance_to_target := planar_delta.length()
	if not _is_pressure_window(distance_to_target):
		return false
	if distance_to_target <= 0.001:
		return false
	if not _has_line_of_sight_to_target():
		return false
	return _execute_pressure_dash(planar_delta / distance_to_target, distance_to_target)

func _execute_pressure_dash(to_target: Vector3, distance_to_target: float) -> bool:
	var tangent := Vector3(-to_target.z, 0.0, to_target.x).normalized()
	if tangent.length_squared() <= 0.0001:
		return false
	var current_position := global_position
	var candidate_signs := [_pressure_zigzag_sign, -_pressure_zigzag_sign]
	var best_position := current_position
	var best_sign := _pressure_zigzag_sign
	for sign_value in candidate_signs:
		var forward_step := minf(pressure_dash_forward_m, maxf(distance_to_target - pressure_dash_min_distance_m, 1.85))
		var candidate := current_position + to_target * forward_step + tangent * pressure_dash_lateral_m * float(sign_value)
		candidate = _resolve_surface_position(candidate)
		var candidate_delta := _target.global_position - candidate
		candidate_delta.y = 0.0
		var candidate_distance := candidate_delta.length()
		if candidate_distance < pressure_dash_min_distance_m - 0.35:
			continue
		best_position = candidate
		best_sign = sign_value
		break
	if best_position.distance_to(current_position) <= 1.0:
		return false
	global_position = best_position
	velocity = Vector3.ZERO
	_pressure_last_dash_offset = best_position - current_position
	_pressure_dash_count += 1
	_pressure_energy = maxf(_pressure_energy - pressure_dash_energy_cost, 0.0)
	_pressure_dash_interval_remaining = pressure_dash_interval_sec
	_record_pressure_sign(best_sign)
	_pressure_zigzag_sign = -best_sign
	_activate_camouflage()
	return true

func _update_ranged_fire() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if _burst_shots_remaining > 0:
		if _burst_interval_remaining > 0.0:
			return
		_emit_burst_projectile()
		_burst_shots_remaining -= 1
		_burst_interval_remaining = burst_interval_sec
		if _burst_shots_remaining <= 0:
			_burst_cooldown_remaining = burst_cooldown_sec
		return
	if _burst_cooldown_remaining > 0.0:
		return
	var planar_delta := _target.global_position - global_position
	planar_delta.y = 0.0
	var distance_to_target := planar_delta.length()
	if distance_to_target < ranged_fire_min_distance_m or distance_to_target > ranged_fire_max_distance_m:
		return
	if not _has_line_of_sight_to_target():
		return
	_burst_shots_remaining = burst_shot_count
	_burst_interval_remaining = 0.0
	_emit_burst_projectile()
	_burst_shots_remaining -= 1
	if _burst_shots_remaining <= 0:
		_burst_cooldown_remaining = burst_cooldown_sec

func _emit_burst_projectile() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var muzzle_origin := global_position + Vector3.UP * 1.45
	var aim_target := _target.global_position + Vector3.UP * 1.1
	var direction := (aim_target - muzzle_origin).normalized()
	if direction.length_squared() <= 0.0001:
		return
	projectile_fire_requested.emit(muzzle_origin, direction)

func _avoid_obstacles(move_direction: Vector3) -> Vector3:
	if move_direction.length_squared() <= 0.0001:
		return Vector3.ZERO
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return move_direction
	var from := global_position + Vector3.UP * 1.0
	var to := from + move_direction.normalized() * obstacle_probe_distance_m
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	if _target is CollisionObject3D:
		query.exclude.append((_target as CollisionObject3D).get_rid())
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return move_direction
	if _behavior_mode == BEHAVIOR_ORBIT:
		_orbit_direction_sign *= -1.0
		var to_target := (_target.global_position - global_position).normalized()
		var tangent := Vector3(-to_target.z, 0.0, to_target.x) * _orbit_direction_sign
		return tangent.normalized()
	return (move_direction + Vector3(-move_direction.z, 0.0, move_direction.x) * _orbit_direction_sign * 0.75).normalized()

func _has_line_of_sight_to_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return true
	var from := global_position + Vector3.UP * 1.45
	var to := _target.global_position + Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	if _target is CollisionObject3D:
		query.exclude.append((_target as CollisionObject3D).get_rid())
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _resolve_surface_position(candidate: Vector3) -> Vector3:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return candidate
	var query := PhysicsRayQueryParameters3D.create(
		candidate + Vector3.UP * 12.0,
		candidate + Vector3.DOWN * 24.0
	)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return candidate
	var resolved := candidate
	var hit_position: Vector3 = hit.get("position", candidate)
	resolved.y = hit_position.y + _estimate_standing_height()
	return resolved

func _stabilize_ground_contact() -> void:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return
	var standing_height := _estimate_standing_height()
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.3,
		global_position + Vector3.DOWN * (standing_height + floor_snap_length_m + 1.0)
	)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var hit_position: Vector3 = hit.get("position", global_position)
	global_position.y = hit_position.y + standing_height
	velocity.y = 0.0

func _face_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var look_target := _target.global_position
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP, true)

func _activate_camouflage() -> void:
	_camouflage_remaining_sec = maxf(_camouflage_remaining_sec, camouflage_duration_sec)
	_update_visual_state()

func _update_visual_state() -> void:
	if _body_material == null:
		return
	if _camouflage_remaining_sec > 0.0:
		var phase := (camouflage_duration_sec - _camouflage_remaining_sec) * camouflage_flicker_hz * TAU
		var flicker := 0.5 + 0.5 * sin(phase)
		_camouflage_alpha = lerpf(camouflage_min_alpha, 0.42, flicker)
		_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_body_material.albedo_color = Color(0.62, 0.88, 1.0, _camouflage_alpha)
		_body_material.emission_enabled = true
		_body_material.emission = Color(0.33, 0.92, 1.0, 1.0)
		_body_material.emission_energy_multiplier = 1.3 + (1.0 - _camouflage_alpha) * 1.1
		return
	_camouflage_alpha = 1.0
	_body_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_body_material.albedo_color = Color(0.141176, 0.156863, 0.203922, 1.0)
	_body_material.emission_enabled = true
	_body_material.emission = Color(1.0, 0.227451, 0.227451, 1.0)
	_body_material.emission_energy_multiplier = 0.55

func _estimate_standing_height() -> float:
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	return 1.0

func _ensure_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 1.5
	collision_shape.shape = capsule
	add_child(collision_shape)

func _ensure_visual() -> void:
	if get_node_or_null("Body") != null:
		_body = get_node_or_null("Body") as MeshInstance3D
		if _body != null:
			_body_material = _body.material_override as StandardMaterial3D
			_body_standing_position = _body.position
			_body_standing_rotation = _body.rotation
		return
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.position = Vector3(0.0, 1.15, 0.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.05, 2.3, 0.75)
	body.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.141176, 0.156863, 0.203922, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.227451, 0.227451, 1.0)
	material.emission_energy_multiplier = 0.55
	body.material_override = material
	add_child(body)
	_body = body
	_body_material = material
	_body_standing_position = _body.position
	_body_standing_rotation = _body.rotation

func _ensure_health_bar() -> void:
	if get_node_or_null("HealthBar") != null:
		_health_bar_root = get_node_or_null("HealthBar") as Node3D
		var existing_back := _health_bar_root.get_node_or_null("Back") as MeshInstance3D if _health_bar_root != null else null
		var existing_fill_anchor := _health_bar_root.get_node_or_null("FillAnchor") as Node3D if _health_bar_root != null else null
		_health_bar_fill_anchor = existing_fill_anchor
		if _health_bar_root != null:
			_health_bar_root.top_level = true
		if existing_back != null:
			existing_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var existing_back_material := existing_back.material_override as StandardMaterial3D
			if existing_back_material != null:
				existing_back_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		if existing_fill_anchor != null:
			var existing_fill := existing_fill_anchor.get_node_or_null("Fill") as MeshInstance3D
			if existing_fill != null:
				existing_fill.position.z = HEALTH_BAR_FILL_DEPTH_OFFSET_M
				existing_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_health_bar_fill_material = existing_fill.material_override as StandardMaterial3D
				if _health_bar_fill_material != null:
					_health_bar_fill_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		return

	var health_bar_root := Node3D.new()
	health_bar_root.name = "HealthBar"
	health_bar_root.top_level = true

	var back := MeshInstance3D.new()
	back.name = "Back"
	back.mesh = _build_health_bar_mesh(1.28, 0.11, 0.045)
	var back_material := StandardMaterial3D.new()
	back_material.albedo_color = Color(0.08, 0.09, 0.11, 0.88)
	back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back.material_override = back_material
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	health_bar_root.add_child(back)

	var fill_anchor := Node3D.new()
	fill_anchor.name = "FillAnchor"
	fill_anchor.position = Vector3(-0.6, 0.0, 0.0)

	var fill := MeshInstance3D.new()
	fill.name = "Fill"
	fill.position = Vector3(0.54, 0.0, HEALTH_BAR_FILL_DEPTH_OFFSET_M)
	fill.mesh = _build_health_bar_mesh(1.08, 0.06, 0.032)
	var fill_material := StandardMaterial3D.new()
	fill_material.albedo_color = Color(0.941176, 0.235294, 0.235294, 1.0)
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.material_override = fill_material
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill_anchor.add_child(fill)
	health_bar_root.add_child(fill_anchor)
	add_child(health_bar_root)

	_health_bar_root = health_bar_root
	_health_bar_fill_anchor = fill_anchor
	_health_bar_fill_material = fill_material
	_update_health_bar_transform()

func _update_health_feedback() -> void:
	if _health_bar_root == null or _health_bar_fill_anchor == null:
		return
	var health_ratio := get_health_ratio()
	_health_bar_root.visible = _health > 0.0
	_health_bar_fill_anchor.scale.x = maxf(health_ratio, 0.001)
	if _health_bar_fill_material != null:
		_health_bar_fill_material.albedo_color = Color(
			lerpf(0.941176, 0.239216, 1.0 - health_ratio),
			lerpf(0.235294, 0.803922, health_ratio),
			lerpf(0.235294, 0.309804, health_ratio),
			1.0
		)

func _build_health_bar_mesh(width: float, height: float, depth: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, depth)
	return mesh

func _enter_corpse_state() -> void:
	if not _combat_active:
		return
	_combat_active = false
	_health = 0.0
	remove_from_group("city_enemy")
	velocity = Vector3.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	_camouflage_remaining_sec = 0.0
	_update_health_feedback()
	_apply_corpse_pose()
	_update_corpse_visual_state()
	_schedule_corpse_cleanup()

func _apply_corpse_pose() -> void:
	if _body == null or not is_instance_valid(_body):
		return
	_body.position = Vector3(_body_standing_position.x, corpse_body_rest_height_m, _body_standing_position.z)
	_body.rotation = Vector3(
		_body_standing_rotation.x,
		_body_standing_rotation.y,
		deg_to_rad(corpse_body_roll_deg)
	)

func _update_corpse_visual_state() -> void:
	if _body_material == null:
		return
	_body_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_body_material.albedo_color = Color(0.298039, 0.180392, 0.180392, 1.0)
	_body_material.emission_enabled = true
	_body_material.emission = Color(0.470588, 0.109804, 0.109804, 1.0)
	_body_material.emission_energy_multiplier = 0.18

func _schedule_corpse_cleanup() -> void:
	if get_tree() == null:
		queue_free()
		return
	if corpse_cleanup_delay_sec <= 0.0:
		queue_free()
		return
	var cleanup_timer := get_tree().create_timer(corpse_cleanup_delay_sec)
	cleanup_timer.timeout.connect(queue_free, CONNECT_ONE_SHOT)

func _update_health_bar_transform() -> void:
	if _health_bar_root == null or not is_instance_valid(_health_bar_root):
		return
	var bar_position := global_position + HEALTH_BAR_WORLD_OFFSET
	_health_bar_root.global_position = bar_position
	var active_camera := get_viewport().get_camera_3d() if get_viewport() != null else null
	if active_camera == null or not is_instance_valid(active_camera):
		return
	var look_target := active_camera.global_position
	look_target.y = bar_position.y
	var planar_delta := look_target - bar_position
	planar_delta.y = 0.0
	if planar_delta.length_squared() <= 0.0001:
		return
	_health_bar_root.look_at(look_target, Vector3.UP, true)
	_health_bar_root.rotate_y(PI)

func _recharge_pressure_energy(delta: float) -> void:
	if pressure_dash_energy_max <= 0.0:
		_pressure_energy = 0.0
		return
	_pressure_energy = minf(pressure_dash_energy_max, _pressure_energy + pressure_dash_energy_recharge_per_sec * delta)

func _is_pressure_window(distance_to_target: float) -> bool:
	return distance_to_target >= pressure_dash_min_distance_m and distance_to_target <= pressure_dash_activation_radius_m

func _can_execute_pressure_dash() -> bool:
	if _pressure_dash_interval_remaining > 0.0:
		return false
	return _pressure_energy >= pressure_dash_energy_cost and pressure_dash_energy_cost > 0.0

func _get_pressure_energy_ratio() -> float:
	if pressure_dash_energy_max <= 0.0:
		return 0.0
	return clampf(_pressure_energy / pressure_dash_energy_max, 0.0, 1.0)

func _record_pressure_sign(sign_value: int) -> void:
	_pressure_sign_history.append(sign_value)
	if _pressure_sign_history.size() > 6:
		_pressure_sign_history.pop_front()

func _should_preserve_pressure_mode(distance_to_target: float) -> bool:
	return _pressure_energy >= pressure_dash_energy_cost and distance_to_target > orbit_activation_radius_m

func _resolve_pressure_move_speed() -> float:
	if _target == null or not is_instance_valid(_target):
		return chase_speed_mps
	var planar_delta := _target.global_position - global_position
	planar_delta.y = 0.0
	var distance_to_target := planar_delta.length()
	if _is_pressure_window(distance_to_target):
		return pressure_chase_speed_mps
	return chase_speed_mps
