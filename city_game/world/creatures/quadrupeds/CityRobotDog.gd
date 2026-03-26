extends Node3D

const SPECIES_ID := "robot_dog"
const JOINT_ANCHOR_NAMES := [
	"lf_hip",
	"lf_knee",
	"rf_hip",
	"rf_knee",
	"lr_hip",
	"lr_knee",
	"rr_hip",
	"rr_knee",
]

@onready var body_pivot: Node3D = $BodyPivot
@onready var model_root: Node3D = $BodyPivot/Model
@onready var joint_anchor_root: Node3D = $JointAnchors

var _initial_root_transform := Transform3D.IDENTITY
var _initial_body_pivot_transform := Transform3D.IDENTITY
var _initial_joint_anchor_local_transforms: Dictionary = {}

func _ready() -> void:
	_capture_initial_pose()

func get_joint_anchor_names() -> Array:
	var names: Array = []
	for joint_anchor_name in JOINT_ANCHOR_NAMES:
		names.append(joint_anchor_name)
	return names

func get_joint_anchor_state() -> Dictionary:
	var joint_anchor_state := {}
	for joint_anchor_name in JOINT_ANCHOR_NAMES:
		var joint_anchor := _get_joint_anchor_node(joint_anchor_name)
		if joint_anchor == null:
			continue
		joint_anchor_state[joint_anchor_name] = {
			"local_position": joint_anchor.position,
			"global_position": joint_anchor.global_position,
			"node_path": str(joint_anchor.get_path()),
		}
	return joint_anchor_state

func get_debug_state() -> Dictionary:
	return {
		"species_id": SPECIES_ID,
		"model_scene_path": model_root.scene_file_path if model_root != null else "",
		"joint_anchor_count": get_joint_anchor_names().size(),
		"joint_anchor_names": get_joint_anchor_names(),
		"joint_anchor_state": get_joint_anchor_state().duplicate(true),
	}

func reset_robot_dog_pose() -> void:
	transform = _initial_root_transform
	if body_pivot != null:
		body_pivot.transform = _initial_body_pivot_transform
	for joint_anchor_name in JOINT_ANCHOR_NAMES:
		var joint_anchor := _get_joint_anchor_node(joint_anchor_name)
		if joint_anchor == null:
			continue
		if not _initial_joint_anchor_local_transforms.has(joint_anchor_name):
			continue
		joint_anchor.transform = _initial_joint_anchor_local_transforms[joint_anchor_name]

func _capture_initial_pose() -> void:
	_initial_root_transform = transform
	if body_pivot != null:
		_initial_body_pivot_transform = body_pivot.transform
	_initial_joint_anchor_local_transforms.clear()
	for joint_anchor_name in JOINT_ANCHOR_NAMES:
		var joint_anchor := _get_joint_anchor_node(joint_anchor_name)
		if joint_anchor == null:
			continue
		_initial_joint_anchor_local_transforms[joint_anchor_name] = joint_anchor.transform

func _get_joint_anchor_node(joint_anchor_name: String) -> Marker3D:
	if joint_anchor_root == null:
		return null
	return joint_anchor_root.get_node_or_null(joint_anchor_name) as Marker3D
