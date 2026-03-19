extends Node3D

const GROUP_NAME := "city_interactable_prop"
const PROP_ID := "prop:v27:fountain_lobster:chunk_129_142"
const DISPLAY_NAME := "龙虾"
const INTERACTION_KIND := "wave"
const PROMPT_TEXT := "按 E 让龙虾挥手"
const INTERACTION_RADIUS_M := 5

@onready var _model_root := $Model as Node3D

var _animation_player: AnimationPlayer = null
var _wave_animation_name := ""
var _wave_play_count := 0
var _ground_offset_y := 0.0
var _contract := {
	"prop_id": PROP_ID,
	"display_name": DISPLAY_NAME,
	"feature_kind": "scene_interactive_prop",
	"interaction_kind": INTERACTION_KIND,
	"interaction_radius_m": INTERACTION_RADIUS_M,
	"prompt_text": PROMPT_TEXT,
}

func _ready() -> void:
	_animation_player = _find_animation_player()
	_wave_animation_name = _resolve_wave_animation_name()
	_ground_model_to_origin()
	if _animation_player != null:
		_animation_player.stop()
	if not is_in_group(GROUP_NAME):
		add_to_group(GROUP_NAME)

func get_interaction_contract() -> Dictionary:
	return _contract.duplicate(true)

func apply_player_interaction(_player_node: Node3D, interaction_contract: Dictionary = {}) -> Dictionary:
	if _animation_player == null:
		return _build_interaction_result(false, "missing_animation_player", interaction_contract)
	if _wave_animation_name == "":
		return _build_interaction_result(false, "missing_wave_animation", interaction_contract)
	_animation_player.stop()
	_animation_player.play(_wave_animation_name)
	_wave_play_count += 1
	return _build_interaction_result(true, "", interaction_contract)

func get_debug_state() -> Dictionary:
	var visual_bounds := _collect_visual_bounds(self)
	return {
		"prop_id": PROP_ID,
		"wave_animation_name": _wave_animation_name,
		"current_animation": "" if _animation_player == null else str(_animation_player.current_animation),
		"is_playing": false if _animation_player == null else _animation_player.is_playing(),
		"wave_play_count": _wave_play_count,
		"ground_offset_y": _ground_offset_y,
		"bottom_y": float(visual_bounds.get("bottom_y", 0.0)),
	}

func _find_animation_player() -> AnimationPlayer:
	if _model_root == null:
		return null
	for child in _model_root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := child as AnimationPlayer
		if animation_player != null:
			return animation_player
	return null

func _resolve_wave_animation_name() -> String:
	if _animation_player == null:
		return ""
	for animation_name in _animation_player.get_animation_list():
		if str(animation_name) == INTERACTION_KIND:
			return INTERACTION_KIND
	if _animation_player.has_animation(INTERACTION_KIND):
		return INTERACTION_KIND
	return ""

func _ground_model_to_origin() -> void:
	if _model_root == null:
		return
	var visual_bounds := _collect_visual_bounds(self)
	if visual_bounds.is_empty():
		return
	var bottom_y := float(visual_bounds.get("bottom_y", 0.0))
	var model_position := _model_root.position
	model_position.y -= bottom_y
	_model_root.position = model_position
	_ground_offset_y = -bottom_y

func _collect_visual_bounds(root_node: Node3D) -> Dictionary:
	if root_node == null:
		return {}
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
		"bottom_y": min_corner.y,
		"top_y": max_corner.y,
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

func _build_interaction_result(success: bool, error: String, interaction_contract: Dictionary) -> Dictionary:
	var prop_id := str(interaction_contract.get("prop_id", PROP_ID))
	if prop_id == "":
		prop_id = PROP_ID
	return {
		"success": success,
		"error": error,
		"prop_id": prop_id,
		"interaction_kind": INTERACTION_KIND,
	}
