extends Node3D

const DEFAULT_SWIM_ANIMATION := "Armature|Swim"

@export var swim_animation_name := DEFAULT_SWIM_ANIMATION
@export var swim_radius_m := 0.9
@export var swim_depth_bob_m := 0.12
@export var swim_speed_scale := 1.0
@export var normalize_model_to_actor_origin := true

@onready var _motion_root := $MotionRoot as Node3D
@onready var _model_root := $MotionRoot/Model as Node3D

var _animation_player: AnimationPlayer = null
var _current_swim_animation := ""
var _school_id := ""
var _phase_offset_sec := 0.0
var _elapsed_sec := 0.0
var _authored_motion_position := Vector3.ZERO
var _authored_motion_rotation := Vector3.ZERO
var _normalization_offset := Vector3.ZERO

func _ready() -> void:
	_animation_player = _find_animation_player(_model_root)
	if _motion_root != null:
		_authored_motion_position = _motion_root.position
		_authored_motion_rotation = _motion_root.rotation
	if normalize_model_to_actor_origin:
		_center_model_to_actor_origin()
	_play_swim_loop()
	_apply_swim_pose(0.0)

func _process(delta: float) -> void:
	_elapsed_sec += maxf(delta, 0.0)
	_apply_swim_pose(_elapsed_sec)

func configure_school_visual(school_summary: Dictionary) -> void:
	_school_id = str(school_summary.get("school_id", "")).strip_edges()
	if _school_id != "":
		name = _school_id
	var school_radius_m := maxf(float(school_summary.get("swim_radius_m", swim_radius_m)), 0.4)
	swim_radius_m = clampf(school_radius_m * 0.12, 0.55, 1.35)
	swim_depth_bob_m = clampf(swim_radius_m * 0.18, 0.08, 0.22)
	swim_speed_scale = _resolve_school_speed_scale(_school_id)
	_phase_offset_sec = _resolve_school_phase_offset(_school_id)
	_elapsed_sec = 0.0
	if is_inside_tree():
		_apply_swim_pose(0.0)

func get_debug_state() -> Dictionary:
	return {
		"school_id": _school_id,
		"swim_animation_name": _current_swim_animation,
		"current_animation": "" if _animation_player == null else str(_animation_player.current_animation),
		"is_playing": false if _animation_player == null else _animation_player.is_playing(),
		"swim_radius_m": swim_radius_m,
		"swim_depth_bob_m": swim_depth_bob_m,
		"swim_speed_scale": swim_speed_scale,
		"normalization_offset": _normalization_offset,
		"motion_offset": _motion_root.position - _authored_motion_position if _motion_root != null else Vector3.ZERO,
		"model_scene_path": "" if _model_root == null else str(_model_root.scene_file_path),
	}

func get_current_animation_name() -> String:
	return "" if _animation_player == null else str(_animation_player.current_animation)

func _play_swim_loop() -> void:
	if _animation_player == null:
		return
	_current_swim_animation = _resolve_swim_animation_name()
	if _current_swim_animation == "":
		_animation_player.stop()
		return
	_animation_player.play(_current_swim_animation)

func _apply_swim_pose(elapsed_sec: float) -> void:
	if _motion_root == null:
		return
	var swim_time := elapsed_sec * maxf(swim_speed_scale, 0.05) + _phase_offset_sec
	var lateral_offset := Vector3(
		cos(swim_time * 0.9) * swim_radius_m,
		sin(swim_time * 1.7) * swim_depth_bob_m,
		sin(swim_time) * swim_radius_m * 0.56
	)
	_motion_root.position = _authored_motion_position + lateral_offset
	var tangent := Vector3(
		-sin(swim_time * 0.9) * swim_radius_m * 0.9,
		cos(swim_time * 1.7) * swim_depth_bob_m * 1.7,
		cos(swim_time) * swim_radius_m * 0.56
	)
	tangent.y = 0.0
	if tangent.length_squared() > 0.0001:
		_motion_root.rotation = Vector3(
			_authored_motion_rotation.x,
			atan2(-tangent.x, -tangent.z),
			_authored_motion_rotation.z
		)

func _resolve_swim_animation_name() -> String:
	if _animation_player == null:
		return ""
	if _animation_player.has_animation(swim_animation_name):
		return swim_animation_name
	for animation_name_variant in _animation_player.get_animation_list():
		var animation_name := str(animation_name_variant)
		if animation_name.to_lower().contains("swim"):
			return animation_name
	return ""

func _center_model_to_actor_origin() -> void:
	if _model_root == null:
		return
	var visual_bounds := _collect_visual_bounds(_model_root)
	if visual_bounds.is_empty():
		return
	var center: Vector3 = visual_bounds.get("center", Vector3.ZERO)
	_normalization_offset = -center
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
		"min": min_corner,
		"max": max_corner,
		"center": (min_corner + max_corner) * 0.5,
	}

func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	if root_node == null:
		return null
	for child in root_node.get_children():
		var match_player := _find_animation_player(child)
		if match_player != null:
			return match_player
	return null

func _resolve_school_speed_scale(school_id: String) -> float:
	if school_id == "":
		return 1.0
	var accumulator := 0
	for char_index in school_id.length():
		accumulator += school_id.unicode_at(char_index)
	return 0.82 + float(accumulator % 31) / 100.0

func _resolve_school_phase_offset(school_id: String) -> float:
	if school_id == "":
		return 0.0
	var accumulator := 0
	for char_index in school_id.length():
		accumulator += school_id.unicode_at(char_index) * (char_index + 1)
	return float(accumulator % 628) / 100.0

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
