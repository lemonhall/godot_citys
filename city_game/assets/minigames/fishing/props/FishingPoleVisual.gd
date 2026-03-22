extends Node3D

@export var normalize_model_to_mount_origin := true

@onready var _mount_root := $MountRoot as Node3D
@onready var _model_root := $MountRoot/Model as Node3D

var _authored_mount_position := Vector3.ZERO
var _authored_mount_rotation := Vector3.ZERO
var _normalization_offset := Vector3.ZERO
var _visual_bounds: Dictionary = {}

func _ready() -> void:
	if _mount_root != null:
		_authored_mount_position = _mount_root.position
		_authored_mount_rotation = _mount_root.rotation
	if normalize_model_to_mount_origin:
		_normalize_model_root()

func get_debug_state() -> Dictionary:
	var visual_count := int(_visual_bounds.get("visual_count", 0))
	return {
		"visual_count": visual_count,
		"bounds_min": _visual_bounds.get("min", Vector3.ZERO),
		"bounds_max": _visual_bounds.get("max", Vector3.ZERO),
		"bounds_size": _visual_bounds.get("size", Vector3.ZERO),
		"normalization_offset": _normalization_offset,
		"mount_position": Vector3.ZERO if _mount_root == null else _mount_root.position,
		"mount_rotation": Vector3.ZERO if _mount_root == null else _mount_root.rotation,
		"authored_mount_position": _authored_mount_position,
		"authored_mount_rotation": _authored_mount_rotation,
		"model_scene_path": "" if _model_root == null else str(_model_root.scene_file_path),
	}

func _normalize_model_root() -> void:
	if _model_root == null:
		return
	_visual_bounds = _collect_visual_bounds(_model_root)
	if _visual_bounds.is_empty():
		return
	var min_corner: Vector3 = _visual_bounds.get("min", Vector3.ZERO)
	var center: Vector3 = _visual_bounds.get("center", Vector3.ZERO)
	_normalization_offset = Vector3(-center.x, -min_corner.y, -center.z)
	_model_root.position += _normalization_offset

func _collect_visual_bounds(root_node: Node3D) -> Dictionary:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	var visual_count := 0
	var root_inverse := root_node.global_transform.affine_inverse()
	for child in root_node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.visible:
			continue
		var local_transform := root_inverse * visual.global_transform
		var aabb := visual.get_aabb()
		for corner in _aabb_corners(aabb):
			var local_corner := local_transform * corner
			min_corner.x = minf(min_corner.x, local_corner.x)
			min_corner.y = minf(min_corner.y, local_corner.y)
			min_corner.z = minf(min_corner.z, local_corner.z)
			max_corner.x = maxf(max_corner.x, local_corner.x)
			max_corner.y = maxf(max_corner.y, local_corner.y)
			max_corner.z = maxf(max_corner.z, local_corner.z)
		visual_count += 1
	if visual_count <= 0:
		return {}
	return {
		"visual_count": visual_count,
		"min": min_corner,
		"max": max_corner,
		"center": (min_corner + max_corner) * 0.5,
		"size": max_corner - min_corner,
	}

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var base := aabb.position
	var size := aabb.size
	return [
		base,
		base + Vector3(size.x, 0.0, 0.0),
		base + Vector3(0.0, size.y, 0.0),
		base + Vector3(0.0, 0.0, size.z),
		base + Vector3(size.x, size.y, 0.0),
		base + Vector3(size.x, 0.0, size.z),
		base + Vector3(0.0, size.y, size.z),
		base + size,
	]
