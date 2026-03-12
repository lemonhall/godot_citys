extends CharacterBody3D

signal projectile_fire_requested(origin: Vector3, direction: Vector3)

const BEHAVIOR_APPROACH := "approach"
const BEHAVIOR_ORBIT := "orbit"
const ROLE_ID_ASSAULT := "assault"

@export var chase_speed_mps := 10.5
@export var orbit_speed_mps := 8.0
@export var dodge_distance_m := 7.5
@export var dodge_cooldown_sec := 0.9
@export var dodge_prediction_sec := 0.45
@export var dodge_trigger_radius_m := 1.8
@export var floor_snap_length_m := 1.4
@export var max_health := 3.0
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

func _ready() -> void:
	add_to_group("city_enemy")
	_health = max_health
	_ensure_collision()
	_ensure_visual()
	floor_snap_length = floor_snap_length_m
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

func apply_projectile_hit(projectile_damage: float, _hit_position: Vector3, _impulse: Vector3) -> void:
	_health -= projectile_damage
	if _health <= 0.0:
		queue_free()

func _physics_process(delta: float) -> void:
	floor_snap_length = floor_snap_length_m
	if _dodge_cooldown_remaining > 0.0:
		_dodge_cooldown_remaining = maxf(_dodge_cooldown_remaining - delta, 0.0)
	if _burst_cooldown_remaining > 0.0:
		_burst_cooldown_remaining = maxf(_burst_cooldown_remaining - delta, 0.0)
	if _burst_interval_remaining > 0.0:
		_burst_interval_remaining = maxf(_burst_interval_remaining - delta, 0.0)
	if _camouflage_remaining_sec > 0.0:
		_camouflage_remaining_sec = maxf(_camouflage_remaining_sec - delta, 0.0)
	_evaluate_incoming_projectiles()
	_update_behavior_mode()
	_update_ranged_fire()
	_update_visual_state()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var move_direction := _compute_move_direction()
	var move_speed := orbit_speed_mps if _behavior_mode == BEHAVIOR_ORBIT else chase_speed_mps
	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed
	if velocity.y <= 0.0:
		apply_floor_snap()
	move_and_slide()
	if velocity.y <= 0.0:
		_stabilize_ground_contact()
	_face_target()

func _update_behavior_mode() -> void:
	if _target == null or not is_instance_valid(_target):
		_behavior_mode = BEHAVIOR_APPROACH
		return
	var planar_delta := _target.global_position - global_position
	planar_delta.y = 0.0
	var distance_to_target := planar_delta.length()
	if _behavior_mode == BEHAVIOR_ORBIT:
		if distance_to_target >= orbit_break_radius_m:
			_behavior_mode = BEHAVIOR_APPROACH
	else:
		if distance_to_target <= orbit_activation_radius_m:
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
	for sign in [-1.0, 1.0]:
		var candidate: Vector3 = current_position + lateral * dodge_distance_m * sign
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
	_camouflage_remaining_sec = camouflage_duration_sec
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
