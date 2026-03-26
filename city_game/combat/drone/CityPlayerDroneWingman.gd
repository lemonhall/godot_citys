extends Node3D

const DRONE_MODEL_SCENE := preload("res://city_game/assets/environment/source/aircraft/drone_a.glb")

@export var presentation_scale := 3.0
@export var follow_response := 6.5
@export var yaw_response := 6.5
@export var bob_amplitude_m := 0.14
@export var bob_frequency_hz := 0.9

var _slot_index := 0
var _target_world_position := Vector3.ZERO
var _look_direction := Vector3.FORWARD
var _elapsed_sec := 0.0
var _visual_root: Node3D = null

func _ready() -> void:
	_ensure_visual_root()

func configure(slot_index: int, initial_world_position: Vector3, look_direction: Vector3) -> void:
	_slot_index = slot_index
	global_position = initial_world_position
	_target_world_position = initial_world_position
	_look_direction = look_direction.normalized() if look_direction.length_squared() > 0.0001 else Vector3.FORWARD
	_apply_immediate_orientation()

func set_follow_target(target_world_position: Vector3, look_direction: Vector3) -> void:
	_target_world_position = target_world_position
	if look_direction.length_squared() > 0.0001:
		_look_direction = look_direction.normalized()

func get_debug_state() -> Dictionary:
	return {
		"slot_index": _slot_index,
		"world_position": global_position,
		"target_world_position": _target_world_position,
	}

func _process(delta: float) -> void:
	_elapsed_sec += maxf(delta, 0.0)
	var bob_offset := Vector3.UP * sin(_elapsed_sec * TAU * bob_frequency_hz + float(_slot_index) * 0.6) * bob_amplitude_m
	var desired_world_position := _target_world_position + bob_offset
	var blend := clampf(follow_response * maxf(delta, 0.0), 0.0, 1.0)
	if global_position.distance_to(desired_world_position) >= 24.0:
		global_position = desired_world_position
	else:
		global_position = global_position.lerp(desired_world_position, blend)
	var desired_yaw_rad := atan2(-_look_direction.x, -_look_direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw_rad, clampf(yaw_response * maxf(delta, 0.0), 0.0, 1.0))

func _ensure_visual_root() -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		return
	_visual_root = Node3D.new()
	_visual_root.name = "ModelRoot"
	add_child(_visual_root)
	if DRONE_MODEL_SCENE != null:
		var drone_model := DRONE_MODEL_SCENE.instantiate() as Node3D
		if drone_model != null:
			_visual_root.add_child(drone_model)
	_visual_root.scale = Vector3.ONE * presentation_scale

func _apply_immediate_orientation() -> void:
	var desired_yaw_rad := atan2(-_look_direction.x, -_look_direction.z)
	rotation.y = desired_yaw_rad
