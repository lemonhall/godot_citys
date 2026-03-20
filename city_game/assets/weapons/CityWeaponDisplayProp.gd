extends Node3D

@export var source_scene: PackedScene
@export var target_length_m := 1.0
@export_range(1.0, 10.0, 0.1) var display_scale_multiplier := 1.0
@export var weapon_class := ""
@export_enum("x", "y", "z") var target_axis := "z"

var _presentation_root: Node3D = null
var _mounted_root: Node3D = null
var _content_root: Node3D = null
var _normalized_length_m := 0.0
var _presented_length_m := 0.0
var _applied_scale := 1.0

func _ready() -> void:
	_rebuild_mounted_prop()

func get_weapon_display_contract() -> Dictionary:
	return {
		"weapon_class": weapon_class,
		"source_scene_path": source_scene.resource_path if source_scene != null else "",
		"target_length_m": target_length_m,
		"display_scale_multiplier": display_scale_multiplier,
		"normalized_length_m": _normalized_length_m,
		"presented_length_m": _presented_length_m,
		"applied_scale": _applied_scale,
	}

func _rebuild_mounted_prop() -> void:
	if _presentation_root != null:
		_presentation_root.queue_free()
		_presentation_root = null
	_mounted_root = null
	_content_root = null
	_normalized_length_m = 0.0
	_presented_length_m = 0.0
	_applied_scale = 1.0
	if source_scene == null:
		return
	var instantiated_variant: Variant = source_scene.instantiate()
	if not (instantiated_variant is Node):
		return
	var applied_display_scale_multiplier := maxf(display_scale_multiplier, 1.0)
	_presentation_root = Node3D.new()
	_presentation_root.name = "PresentationRoot"
	_presentation_root.scale = Vector3.ONE * applied_display_scale_multiplier
	add_child(_presentation_root)
	_mounted_root = Node3D.new()
	_mounted_root.name = "MountedProp"
	_presentation_root.add_child(_mounted_root)
	_content_root = Node3D.new()
	_content_root.name = "ContentRoot"
	_mounted_root.add_child(_content_root)
	var mounted_content := instantiated_variant as Node
	_content_root.add_child(mounted_content)
	var source_aabb := _compute_local_aabb(_content_root, Transform3D.IDENTITY)
	if source_aabb.size == Vector3.ZERO:
		return
	_content_root.rotation = _resolve_axis_alignment_rotation(source_aabb.size, target_axis)
	var local_aabb := _compute_local_aabb(_mounted_root, Transform3D.IDENTITY)
	if local_aabb.size == Vector3.ZERO:
		return
	var longest_axis_m := maxf(local_aabb.size.x, maxf(local_aabb.size.y, local_aabb.size.z))
	if longest_axis_m <= 0.0001:
		return
	_applied_scale = target_length_m / longest_axis_m if target_length_m > 0.0001 else 1.0
	_mounted_root.scale = Vector3.ONE * _applied_scale
	var center := local_aabb.position + local_aabb.size * 0.5
	_mounted_root.position = -center * _applied_scale
	_normalized_length_m = longest_axis_m * _applied_scale
	_presented_length_m = _normalized_length_m * applied_display_scale_multiplier

func _resolve_axis_alignment_rotation(size: Vector3, desired_axis: String) -> Vector3:
	var longest_axis := "x"
	if size.y > size.x and size.y >= size.z:
		longest_axis = "y"
	elif size.z > size.x and size.z > size.y:
		longest_axis = "z"
	if longest_axis == desired_axis:
		return Vector3.ZERO
	match "%s->%s" % [longest_axis, desired_axis]:
		"x->y":
			return Vector3(0.0, 0.0, deg_to_rad(90.0))
		"x->z":
			return Vector3(0.0, deg_to_rad(90.0), 0.0)
		"y->x":
			return Vector3(0.0, 0.0, deg_to_rad(-90.0))
		"y->z":
			return Vector3(deg_to_rad(90.0), 0.0, 0.0)
		"z->x":
			return Vector3(0.0, deg_to_rad(-90.0), 0.0)
		"z->y":
			return Vector3(deg_to_rad(-90.0), 0.0, 0.0)
	return Vector3.ZERO

func _compute_local_aabb(node: Node, accumulated_transform: Transform3D) -> AABB:
	var node_transform := accumulated_transform
	if node is Node3D:
		node_transform = accumulated_transform * (node as Node3D).transform
	var has_any := false
	var merged := AABB()
	if node is VisualInstance3D:
		var visual := node as VisualInstance3D
		var visual_aabb := visual.get_aabb()
		if visual_aabb.size != Vector3.ZERO:
			merged = _transform_aabb(node_transform, visual_aabb)
			has_any = true
	for child in node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var child_aabb := _compute_local_aabb(child_node, node_transform)
		if child_aabb.size == Vector3.ZERO:
			continue
		if not has_any:
			merged = child_aabb
			has_any = true
		else:
			merged = merged.merge(child_aabb)
	return merged if has_any else AABB()

func _transform_aabb(node_transform: Transform3D, aabb: AABB) -> AABB:
	var corners := [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
		aabb.position + Vector3(0.0, aabb.size.y, 0.0),
		aabb.position + Vector3(0.0, 0.0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
		aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
		aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]
	var first_corner: Vector3 = node_transform * corners[0]
	var min_corner := first_corner
	var max_corner := first_corner
	for corner in corners:
		var transformed_corner: Vector3 = node_transform * corner
		min_corner = Vector3(
			minf(min_corner.x, transformed_corner.x),
			minf(min_corner.y, transformed_corner.y),
			minf(min_corner.z, transformed_corner.z)
		)
		max_corner = Vector3(
			maxf(max_corner.x, transformed_corner.x),
			maxf(max_corner.y, transformed_corner.y),
			maxf(max_corner.z, transformed_corner.z)
		)
	return AABB(min_corner, max_corner - min_corner)
