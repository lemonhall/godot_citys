extends Node3D

@export var equipped_visible := false
@export var cast_duration_sec := 0.34
@export var cast_position_offset := Vector3(0.12, -0.08, 0.34)
@export var cast_rotation_offset_deg := Vector3(-42.0, 12.0, -64.0)
@export var line_target_pitch_weight := 0.0
@export var line_target_yaw_weight := 0.0

@onready var _line_hold_pose_anchor := $LineHoldPoseAnchor as Node3D
@onready var _mount_root := $MountRoot as Node3D
@onready var _pole_root := $MountRoot/Pole as Node3D
@onready var _line_origin_anchor := $MountRoot/LineOriginAnchor as Marker3D
@onready var _tip_anchor := $MountRoot/TipAnchor as Marker3D

var _authored_mount_position := Vector3.ZERO
var _authored_mount_rotation_deg := Vector3.ZERO
var _swing_remaining_sec := 0.0
var _swing_count := 0
var _line_pose_active := false
var _line_target_world_position := Vector3.ZERO

func _ready() -> void:
	if _mount_root != null:
		_authored_mount_position = _mount_root.position
		_authored_mount_rotation_deg = _mount_root.rotation_degrees
	visible = equipped_visible
	_apply_pose(0.0)

func _process(delta: float) -> void:
	if _swing_remaining_sec > 0.0:
		_swing_remaining_sec = maxf(_swing_remaining_sec - maxf(delta, 0.0), 0.0)
		var progress := 1.0 - (_swing_remaining_sec / maxf(cast_duration_sec, 0.05))
		_apply_pose(progress)
		return
	_apply_pose(0.0)

func set_equipped_visible(should_show: bool) -> void:
	equipped_visible = should_show
	visible = should_show
	if not should_show:
		_swing_remaining_sec = 0.0
		_line_pose_active = false
		_line_target_world_position = Vector3.ZERO
		_apply_pose(0.0)

func play_cast_swing() -> void:
	equipped_visible = true
	visible = true
	_swing_remaining_sec = maxf(cast_duration_sec, 0.05)
	_swing_count += 1
	_apply_pose(0.0)

func set_line_pose_active(active: bool, target_world_position: Vector3 = Vector3.ZERO) -> void:
	_line_pose_active = active
	_line_target_world_position = target_world_position if active else Vector3.ZERO
	if _swing_remaining_sec <= 0.0:
		_apply_pose(0.0)

func get_visual_state() -> Dictionary:
	var carry_pose := _resolve_carry_pose()
	var cast_endpoint_pose := _resolve_cast_endpoint_pose()
	return {
		"pole_present": _pole_root != null and is_instance_valid(_pole_root),
		"equipped_visible": visible,
		"swing_active": _swing_remaining_sec > 0.0,
		"swing_count": _swing_count,
		"line_pose_active": _line_pose_active,
		"pose_name": _resolve_pose_name(),
		"tip_world_position": get_line_origin_world_position(),
		"mount_position": Vector3.ZERO if _mount_root == null else _mount_root.position,
		"mount_world_position": Vector3.ZERO if _mount_root == null else _mount_root.global_position,
		"mount_rotation_degrees": Vector3.ZERO if _mount_root == null else _mount_root.rotation_degrees,
		"carry_mount_position": carry_pose.get("position", Vector3.ZERO),
		"carry_mount_rotation_degrees": carry_pose.get("rotation_degrees", Vector3.ZERO),
		"cast_endpoint_mount_position": cast_endpoint_pose.get("position", Vector3.ZERO),
		"cast_endpoint_mount_rotation_degrees": cast_endpoint_pose.get("rotation_degrees", Vector3.ZERO),
	}

func get_line_origin_world_position() -> Vector3:
	if _line_origin_anchor != null and is_instance_valid(_line_origin_anchor):
		return _line_origin_anchor.global_position
	if _tip_anchor != null and is_instance_valid(_tip_anchor):
		return _tip_anchor.global_position
	return Vector3.ZERO

func _apply_pose(progress: float) -> void:
	if _mount_root == null:
		return
	if _swing_remaining_sec > 0.0:
		var carry_pose := _resolve_carry_pose()
		var cast_endpoint_pose := _resolve_cast_endpoint_pose()
		var t := _ease_cast_progress(progress)
		var carry_position: Vector3 = carry_pose.get("position", _authored_mount_position)
		var carry_rotation_deg: Vector3 = carry_pose.get("rotation_degrees", _authored_mount_rotation_deg)
		var cast_endpoint_position: Vector3 = cast_endpoint_pose.get("position", _authored_mount_position)
		var cast_endpoint_rotation_deg: Vector3 = cast_endpoint_pose.get("rotation_degrees", _authored_mount_rotation_deg)
		_mount_root.position = carry_position.lerp(cast_endpoint_position, t)
		_mount_root.rotation_degrees = carry_rotation_deg.lerp(cast_endpoint_rotation_deg, t)
		return
	var rest_pose := _resolve_rest_pose()
	_mount_root.position = rest_pose.get("position", _authored_mount_position)
	_mount_root.rotation_degrees = rest_pose.get("rotation_degrees", _authored_mount_rotation_deg)

func _resolve_carry_pose() -> Dictionary:
	return {
		"position": _authored_mount_position,
		"rotation_degrees": _authored_mount_rotation_deg,
	}

func _resolve_cast_endpoint_pose() -> Dictionary:
	var position := _authored_mount_position + cast_position_offset
	var rotation_deg := _authored_mount_rotation_deg + cast_rotation_offset_deg
	var target_adjustment := _resolve_line_target_adjustment_deg()
	rotation_deg.x += target_adjustment.x
	rotation_deg.y += target_adjustment.y
	return {
		"position": position,
		"rotation_degrees": rotation_deg,
	}

func _resolve_rest_pose() -> Dictionary:
	return _resolve_cast_endpoint_pose() if _line_pose_active else _resolve_carry_pose()

func _ease_cast_progress(progress: float) -> float:
	var clamped := clampf(progress, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)

func _resolve_line_target_adjustment_deg() -> Vector2:
	if not _line_pose_active or _line_target_world_position == Vector3.ZERO or _mount_root == null or not is_inside_tree():
		return Vector2.ZERO
	var local_target := _mount_root.to_local(_line_target_world_position)
	var planar_distance := Vector2(local_target.x, local_target.z).length()
	if planar_distance <= 0.0001:
		return Vector2.ZERO
	var pitch_deg := rad_to_deg(atan2(local_target.y, planar_distance)) * line_target_pitch_weight
	var yaw_deg := rad_to_deg(atan2(-local_target.x, -local_target.z)) * line_target_yaw_weight
	return Vector2(clampf(pitch_deg, -5.0, 5.0), clampf(yaw_deg, -6.0, 6.0))

func _resolve_pose_name() -> String:
	if _swing_remaining_sec > 0.0:
		return "cast_swing"
	if _line_pose_active:
		return "line_hold"
	return "carry"
