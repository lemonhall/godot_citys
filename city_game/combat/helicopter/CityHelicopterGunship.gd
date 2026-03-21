extends AnimatableBody3D

const MODEL_SCENE_PATH := "res://city_game/assets/environment/source/aircraft/helicopter_a.glb"

@export var max_health := 160.0

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

func _ready() -> void:
	_health = maxf(max_health, 1.0)
	_destroyed = false
	add_to_group("city_enemy")
	add_to_group("city_helicopter_gunship")

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
	}

func apply_projectile_hit(projectile_damage: float, hit_position: Vector3, _impulse: Vector3) -> void:
	if _destroyed:
		return
	_last_hit_world_position = hit_position
	_health = maxf(_health - maxf(projectile_damage, 0.0), 0.0)
	if _health <= 0.0:
		_destroyed = true
		_completion_count += 1

func get_gun_muzzle_world_position() -> Vector3:
	return _gun_muzzle.global_position

func get_missile_muzzle_world_positions() -> Array:
	return [
		_missile_muzzle_left.global_position,
		_missile_muzzle_right.global_position,
	]
