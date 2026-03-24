extends Node3D

const SOURCE_ASSET_PATH := "res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb"

const LOWER_BASE_NODE_NAME := "m777_lower_base"
const UPPER_CARRIAGE_NODE_NAME := "m777_upper_carriage"
const GUN_ASSEMBLY_NODE_NAME := "m777_gun_assembly"

@export var initial_yaw_deg := 0.0
@export var initial_pitch_deg := 0.0
@export_range(-180.0, 180.0, 0.1) var pitch_zero_offset_deg := 14.7
@export_range(-180.0, 180.0, 0.1) var min_pitch_deg := 0.0
@export_range(-180.0, 180.0, 0.1) var max_pitch_deg := 71.0

@onready var _model_root := $ModelRoot as Node3D
@onready var _lower_base_mount := $ModelRoot/LowerBaseMount as Node3D
@onready var _yaw_pivot := $ModelRoot/YawPivot as Node3D
@onready var _pitch_pivot := $ModelRoot/YawPivot/PitchPivot as Node3D
@onready var _source_asset := $ModelRoot/SourceAsset as Node3D
@onready var _yaw_anchor := $Anchors/YawPivotAnchor as Marker3D
@onready var _pitch_anchor := $Anchors/PitchPivotAnchor as Marker3D

var _yaw_deg := 0.0
var _pitch_deg := 0.0
var _mounted_segment_count := 0

func _ready() -> void:
	_mount_segments()
	set_axis_angles_degrees(initial_yaw_deg, initial_pitch_deg)

func get_visual_root() -> Node3D:
	return _model_root

func set_yaw_degrees(value: float) -> void:
	_yaw_deg = value
	_apply_axis_angles()

func set_pitch_degrees(value: float) -> void:
	_pitch_deg = _clamp_pitch_degrees(value)
	_apply_axis_angles()

func set_axis_angles_degrees(yaw_deg: float, pitch_deg: float) -> void:
	_yaw_deg = yaw_deg
	_pitch_deg = _clamp_pitch_degrees(pitch_deg)
	_apply_axis_angles()

func get_yaw_degrees() -> float:
	return _yaw_deg

func get_pitch_degrees() -> float:
	return _pitch_deg

func get_anchor_state() -> Dictionary:
	return {
		"yaw_anchor_local_position": _yaw_anchor.position if _yaw_anchor != null else Vector3.ZERO,
		"pitch_anchor_local_position": _pitch_anchor.position if _pitch_anchor != null else Vector3.ZERO,
		"yaw_pivot_local_position": _yaw_pivot.position if _yaw_pivot != null else Vector3.ZERO,
		"pitch_pivot_local_position": _pitch_pivot.position if _pitch_pivot != null else Vector3.ZERO,
	}

func get_debug_state() -> Dictionary:
	return {
		"source_asset_path": SOURCE_ASSET_PATH,
		"yaw_deg": _yaw_deg,
		"pitch_deg": _pitch_deg,
		"applied_pitch_pivot_deg": pitch_zero_offset_deg - _pitch_deg,
		"pitch_zero_offset_deg": pitch_zero_offset_deg,
		"pitch_limits_deg": {
			"min": min_pitch_deg,
			"max": max_pitch_deg,
		},
		"mounted_segment_count": _mounted_segment_count,
		"lower_base_present": get_node_or_null("ModelRoot/LowerBaseMount/%s" % LOWER_BASE_NODE_NAME) != null,
		"upper_carriage_present": get_node_or_null("ModelRoot/YawPivot/%s" % UPPER_CARRIAGE_NODE_NAME) != null,
		"gun_assembly_present": get_node_or_null("ModelRoot/YawPivot/PitchPivot/%s" % GUN_ASSEMBLY_NODE_NAME) != null,
		"anchor_state": get_anchor_state(),
	}

func _mount_segments() -> void:
	_sync_pivots_from_anchors()
	if _yaw_pivot != null:
		_yaw_pivot.rotation = Vector3.ZERO
	if _pitch_pivot != null:
		_pitch_pivot.rotation = Vector3.ZERO
	_mounted_segment_count = 0
	if _reparent_segment(LOWER_BASE_NODE_NAME, _lower_base_mount):
		_mounted_segment_count += 1
	if _reparent_segment(UPPER_CARRIAGE_NODE_NAME, _yaw_pivot):
		_mounted_segment_count += 1
	if _reparent_segment(GUN_ASSEMBLY_NODE_NAME, _pitch_pivot):
		_mounted_segment_count += 1

func _sync_pivots_from_anchors() -> void:
	if _yaw_pivot != null and _yaw_anchor != null:
		_yaw_pivot.position = _yaw_anchor.position
	if _pitch_pivot != null and _yaw_anchor != null and _pitch_anchor != null:
		_pitch_pivot.position = _pitch_anchor.position - _yaw_anchor.position

func _reparent_segment(segment_name: String, target_parent: Node3D) -> bool:
	if target_parent == null:
		return false
	var segment := find_child(segment_name, true, false) as Node3D
	if segment == null:
		return false
	if segment.get_parent() != target_parent:
		segment.reparent(target_parent, true)
	return true

func _apply_axis_angles() -> void:
	if _yaw_pivot != null:
		_yaw_pivot.rotation.y = deg_to_rad(_yaw_deg)
	if _pitch_pivot != null:
		_pitch_pivot.rotation.x = deg_to_rad(pitch_zero_offset_deg - _pitch_deg)

func _clamp_pitch_degrees(value: float) -> float:
	return clampf(value, min_pitch_deg, max_pitch_deg)
