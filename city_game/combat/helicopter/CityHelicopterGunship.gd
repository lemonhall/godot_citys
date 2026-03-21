extends CharacterBody3D

const MODEL_SCENE_PATH := "res://city_game/assets/environment/source/aircraft/helicopter_a.glb"

signal missile_fire_requested(origin: Vector3, direction: Vector3)
signal destroyed

@export var max_health := 160.0
@export var hover_height_m := 26.0
@export var orbit_radius_m := 18.0
@export var orbit_angular_speed_deg := 42.0
@export var orbit_follow_speed_mps := 28.0
@export var missile_fire_interval_sec := 0.85
@export var target_aim_height_m := 1.1
@export var engage_delay_sec := 0.15

@onready var _model_root := $ModelRoot as Node3D
@onready var _body_center := $Anchors/BodyCenter as Marker3D
@onready var _gun_muzzle := $Anchors/GunMuzzle as Marker3D
@onready var _missile_muzzle_left := $Anchors/MissileMuzzleLeft as Marker3D
@onready var _missile_muzzle_right := $Anchors/MissileMuzzleRight as Marker3D
@onready var _damage_smoke_anchor := $Anchors/DamageSmokeAnchor as Marker3D
@onready var _rotor_hub := $Anchors/RotorHub as Marker3D

var _health := 0.0
var _destroyed := false
var _last_hit_world_position := Vector3.ZERO
var _completion_count := 0
var _target: Node3D = null
var _resolved_hover_height_m := 0.0
var _resolved_orbit_radius_m := 0.0
var _orbit_angle_rad := 0.0
var _missile_fire_cooldown_sec := 0.0
var _missile_fire_index := 0
var _engage_delay_remaining_sec := 0.0

func _ready() -> void:
	_health = maxf(max_health, 1.0)
	_destroyed = false
	_resolved_hover_height_m = hover_height_m
	_resolved_orbit_radius_m = orbit_radius_m
	_missile_fire_cooldown_sec = missile_fire_interval_sec * 0.45
	_engage_delay_remaining_sec = 0.0
	add_to_group("city_enemy")
	add_to_group("city_helicopter_gunship")

func configure_combat(target_node: Node3D, orbit_reference_world_position: Vector3 = Vector3.ZERO) -> void:
	_target = target_node
	var target_position := target_node.global_position if target_node != null and is_instance_valid(target_node) else Vector3.ZERO
	var reference_position := global_position
	if reference_position.length_squared() <= 0.0001 and orbit_reference_world_position.length_squared() > 0.0001:
		reference_position = orbit_reference_world_position
	var planar_offset := Vector2(reference_position.x - target_position.x, reference_position.z - target_position.z)
	if planar_offset.length() > 0.5:
		_resolved_orbit_radius_m = maxf(planar_offset.length(), 8.0)
		_orbit_angle_rad = atan2(planar_offset.y, planar_offset.x)
	else:
		_resolved_orbit_radius_m = maxf(orbit_radius_m, 8.0)
		_orbit_angle_rad = 0.0
	_resolved_hover_height_m = maxf(reference_position.y - target_position.y, hover_height_m)
	_engage_delay_remaining_sec = maxf(engage_delay_sec, 0.0)
	_missile_fire_cooldown_sec = minf(_missile_fire_cooldown_sec, missile_fire_interval_sec * 0.45)

func get_visual_root() -> Node3D:
	return _model_root

func get_health_state() -> Dictionary:
	return {
		"current": _health,
		"max": maxf(max_health, 0.0),
		"ratio": clampf(_health / maxf(max_health, 0.001), 0.0, 1.0),
		"alive": not _destroyed,
		"destroyed": _destroyed,
		"last_hit_world_position": _last_hit_world_position,
		"completion_count": _completion_count,
	}

func get_combat_state() -> Dictionary:
	return {
		"target_present": _target != null and is_instance_valid(_target),
		"hover_height_m": _resolved_hover_height_m,
		"orbit_radius_m": _resolved_orbit_radius_m,
		"orbit_angle_rad": _orbit_angle_rad,
		"missile_fire_cooldown_sec": _missile_fire_cooldown_sec,
		"missile_fire_index": _missile_fire_index,
		"destroyed": _destroyed,
		"speed_mps": velocity.length(),
	}

func get_debug_state() -> Dictionary:
	return {
		"model_scene_path": MODEL_SCENE_PATH,
		"anchor_names": [
			_body_center.name,
			_gun_muzzle.name,
			_missile_muzzle_left.name,
			_missile_muzzle_right.name,
			_damage_smoke_anchor.name,
			_rotor_hub.name,
		],
		"health_state": get_health_state(),
		"combat_state": get_combat_state(),
	}

func apply_projectile_hit(projectile_damage: float, hit_position: Vector3, _impulse: Vector3) -> void:
	if _destroyed:
		return
	_last_hit_world_position = hit_position
	_health = maxf(_health - maxf(projectile_damage, 0.0), 0.0)
	if _health <= 0.0:
		_enter_destroyed_state()

func get_gun_muzzle_world_position() -> Vector3:
	return _gun_muzzle.global_position

func get_missile_muzzle_world_positions() -> Array:
	return [
		_missile_muzzle_left.global_position,
		_missile_muzzle_right.global_position,
	]

func _physics_process(delta: float) -> void:
	if _destroyed:
		velocity = Vector3.ZERO
		return
	if _engage_delay_remaining_sec > 0.0:
		_engage_delay_remaining_sec = maxf(_engage_delay_remaining_sec - delta, 0.0)
		velocity = Vector3.ZERO
		_face_target()
		return
	_update_orbit(delta)
	_update_attack(delta)

func _update_orbit(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		velocity = Vector3.ZERO
		return
	_orbit_angle_rad = wrapf(_orbit_angle_rad + deg_to_rad(orbit_angular_speed_deg) * delta, -PI, PI)
	var target_position := _target.global_position
	var desired_position := target_position + Vector3(
		cos(_orbit_angle_rad) * _resolved_orbit_radius_m,
		_resolved_hover_height_m,
		sin(_orbit_angle_rad) * _resolved_orbit_radius_m
	)
	var previous_position := global_position
	global_position = global_position.move_toward(desired_position, orbit_follow_speed_mps * maxf(delta, 0.0))
	velocity = (global_position - previous_position) / maxf(delta, 0.0001)
	_face_target()

func _update_attack(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_missile_fire_cooldown_sec = maxf(_missile_fire_cooldown_sec - delta, 0.0)
	if _missile_fire_cooldown_sec > 0.0:
		return
	var missile_muzzles := get_missile_muzzle_world_positions()
	if missile_muzzles.is_empty():
		return
	var muzzle_index := _missile_fire_index % missile_muzzles.size()
	var origin := missile_muzzles[muzzle_index] as Vector3
	var aim_target := _target.global_position + Vector3.UP * target_aim_height_m
	var direction := (aim_target - origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = -global_transform.basis.z
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	_missile_fire_index += 1
	_missile_fire_cooldown_sec = missile_fire_interval_sec
	missile_fire_requested.emit(origin, direction)

func _face_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var look_target := _target.global_position
	look_target.y = global_position.y
	if global_position.distance_to(look_target) <= 0.001:
		return
	look_at(look_target, Vector3.UP, true)

func _enter_destroyed_state() -> void:
	if _destroyed:
		return
	_destroyed = true
	_completion_count += 1
	remove_from_group("city_enemy")
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	destroyed.emit()
