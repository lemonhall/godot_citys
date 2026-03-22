extends Node3D

@export var cast_duration_sec := 0.34
@export var cast_position_offset := Vector3(0.12, -0.08, 0.34)
@export var cast_rotation_offset_deg := Vector3(-42.0, 12.0, -64.0)

@onready var _mount_root := $MountRoot as Node3D
@onready var _pole_root := $MountRoot/Pole as Node3D
@onready var _tip_anchor := $MountRoot/TipAnchor as Marker3D

var _authored_mount_position := Vector3.ZERO
var _authored_mount_rotation_deg := Vector3.ZERO
var _swing_remaining_sec := 0.0
var _swing_count := 0

func _ready() -> void:
	if _mount_root != null:
		_authored_mount_position = _mount_root.position
		_authored_mount_rotation_deg = _mount_root.rotation_degrees
	_apply_pose(0.0)

func _process(delta: float) -> void:
	if _swing_remaining_sec <= 0.0:
		return
	_swing_remaining_sec = maxf(_swing_remaining_sec - maxf(delta, 0.0), 0.0)
	var progress := 1.0 - (_swing_remaining_sec / maxf(cast_duration_sec, 0.05))
	_apply_pose(progress)

func set_equipped_visible(should_show: bool) -> void:
	visible = should_show
	if not should_show:
		_swing_remaining_sec = 0.0
		_apply_pose(0.0)

func play_cast_swing() -> void:
	visible = true
	_swing_remaining_sec = maxf(cast_duration_sec, 0.05)
	_swing_count += 1
	_apply_pose(0.0)

func get_visual_state() -> Dictionary:
	return {
		"pole_present": _pole_root != null and is_instance_valid(_pole_root),
		"equipped_visible": visible,
		"swing_active": _swing_remaining_sec > 0.0,
		"swing_count": _swing_count,
		"tip_world_position": Vector3.ZERO if _tip_anchor == null else _tip_anchor.global_position,
		"mount_position": Vector3.ZERO if _mount_root == null else _mount_root.position,
		"mount_rotation_degrees": Vector3.ZERO if _mount_root == null else _mount_root.rotation_degrees,
	}

func _apply_pose(progress: float) -> void:
	if _mount_root == null:
		return
	var envelope := sin(clampf(progress, 0.0, 1.0) * PI)
	_mount_root.position = _authored_mount_position + cast_position_offset * envelope
	_mount_root.rotation_degrees = _authored_mount_rotation_deg + cast_rotation_offset_deg * envelope
