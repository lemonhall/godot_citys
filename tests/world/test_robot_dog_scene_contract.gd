extends SceneTree

const T := preload("res://tests/_test_util.gd")

const ROBOT_DOG_ASSET_PATH := "res://city_game/assets/environment/source/creatures/robot_dog_02/robot_dog_02.glb"
const ROBOT_DOG_SCENE_PATH := "res://city_game/world/creatures/quadrupeds/CityRobotDog.tscn"
const EXPECTED_JOINT_ANCHOR_NAMES := [
	"lf_hip",
	"lf_knee",
	"rf_hip",
	"rf_knee",
	"lr_hip",
	"lr_knee",
	"rr_hip",
	"rr_knee",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(ROBOT_DOG_ASSET_PATH, "PackedScene"), "Robot dog scene contract requires the formal robot dog glb under the creature asset directory"):
		return
	if not T.require_true(self, ResourceLoader.exists(ROBOT_DOG_SCENE_PATH, "PackedScene"), "Robot dog scene contract requires a dedicated CityRobotDog.tscn scene"):
		return

	var scene := load(ROBOT_DOG_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Robot dog scene contract must load the formal creature scene as PackedScene"):
		return

	var robot_dog := scene.instantiate() as Node3D
	root.add_child(robot_dog)
	await process_frame
	await process_frame

	for required_method in [
		"get_debug_state",
		"get_joint_anchor_state",
		"get_joint_anchor_names",
		"reset_robot_dog_pose",
	]:
		if not T.require_true(self, robot_dog.has_method(required_method), "Formal robot dog scene must expose %s()" % required_method):
			return

	for required_node_path in [
		"BodyPivot",
		"BodyPivot/Model",
		"JointAnchors",
	]:
		if not T.require_true(self, robot_dog.get_node_or_null(required_node_path) != null, "Formal robot dog scene must author %s in the scene-first hierarchy" % required_node_path):
			return

	var model_root := robot_dog.get_node_or_null("BodyPivot/Model") as Node3D
	if not T.require_true(self, model_root != null, "Formal robot dog scene must mount the curated glb under BodyPivot/Model"):
		return
	if not T.require_true(self, str(model_root.scene_file_path) == ROBOT_DOG_ASSET_PATH, "Formal robot dog scene must source the curated robot dog glb from the creature asset directory"):
		return

	var joint_anchor_names := robot_dog.get_joint_anchor_names() as Array
	if not T.require_true(self, joint_anchor_names.size() == EXPECTED_JOINT_ANCHOR_NAMES.size(), "Formal robot dog scene must expose exactly 8 authored joint anchors"):
		return
	for joint_anchor_name in EXPECTED_JOINT_ANCHOR_NAMES:
		if not T.require_true(self, joint_anchor_names.has(joint_anchor_name), "Formal robot dog scene must expose authored joint anchor %s" % joint_anchor_name):
			return
		if not T.require_true(self, robot_dog.get_node_or_null("JointAnchors/%s" % joint_anchor_name) is Marker3D, "Formal robot dog scene must author JointAnchors/%s as Marker3D" % joint_anchor_name):
			return

	var debug_state := robot_dog.get_debug_state() as Dictionary
	if not T.require_true(self, str(debug_state.get("species_id", "")) == "robot_dog", "Formal robot dog scene must freeze species_id to robot_dog"):
		return
	if not T.require_true(self, int(debug_state.get("joint_anchor_count", 0)) == 8, "Formal robot dog scene must report 8 joint anchors in debug state"):
		return

	robot_dog.queue_free()
	await process_frame
	T.pass_and_quit(self)
