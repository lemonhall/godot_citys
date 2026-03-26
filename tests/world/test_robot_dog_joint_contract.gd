extends SceneTree

const T := preload("res://tests/_test_util.gd")

const ROBOT_DOG_SCENE_PATH := "res://city_game/world/creatures/quadrupeds/CityRobotDog.tscn"
const EXPECTED_JOINT_NAMES := [
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
	if not T.require_true(self, ResourceLoader.exists(ROBOT_DOG_SCENE_PATH, "PackedScene"), "Robot dog joint contract requires CityRobotDog.tscn"):
		return
	var scene := load(ROBOT_DOG_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Robot dog joint contract must load CityRobotDog as PackedScene"):
		return

	var robot_dog := scene.instantiate() as Node3D
	root.add_child(robot_dog)
	await process_frame
	await process_frame

	for required_method in [
		"get_pose_debug_state",
		"get_joint_constraint_contract",
		"set_crouch_requested",
		"toggle_crouch_requested",
		"tick_robot_dog",
		"reset_robot_dog_pose",
	]:
		if not T.require_true(self, robot_dog.has_method(required_method), "Robot dog joint contract requires %s()" % required_method):
			return

	var joint_constraints := robot_dog.get_joint_constraint_contract() as Dictionary
	if not T.require_true(self, joint_constraints.size() == EXPECTED_JOINT_NAMES.size(), "Robot dog joint contract must expose 8 explicit joint constraints"):
		return
	for joint_name in EXPECTED_JOINT_NAMES:
		var joint_contract: Dictionary = joint_constraints.get(joint_name, {})
		if not T.require_true(self, not joint_contract.is_empty(), "Robot dog joint contract must expose %s" % joint_name):
			return
		if not T.require_true(self, str(joint_contract.get("axis_name", "")) == "z", "Robot dog joint contract must freeze %s to local Z axis" % joint_name):
			return
		if not T.require_true(self, (joint_contract.get("axis", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(0.0, 0.0, 1.0)), "Robot dog joint contract must expose Vector3(0, 0, 1) for %s axis" % joint_name):
			return
		var min_deg := float(joint_contract.get("min_deg", 999.0))
		var max_deg := float(joint_contract.get("max_deg", -999.0))
		if joint_name.ends_with("_hip"):
			if not T.require_true(self, is_equal_approx(min_deg, -60.0) and is_equal_approx(max_deg, 5.0), "Robot dog hip joints must freeze to [-60, 5] deg"):
				return
		else:
			if not T.require_true(self, is_equal_approx(min_deg, -80.0) and is_equal_approx(max_deg, 80.0), "Robot dog knee joints must freeze to [-80, 80] deg"):
				return

	var pose_state := robot_dog.get_pose_debug_state() as Dictionary
	if not T.require_true(self, str(pose_state.get("species_id", "")) == "robot_dog", "Robot dog joint contract must preserve species_id"):
		return
	if not T.require_true(self, str(pose_state.get("pose_state", "")) == "standing", "Robot dog joint contract must boot in standing pose"):
		return
	if not T.require_true(self, not bool(pose_state.get("crouch_requested", true)), "Robot dog joint contract must boot with crouch_requested=false"):
		return
	if not T.require_true(self, is_zero_approx(float(pose_state.get("crouch_alpha", 1.0))), "Robot dog joint contract must boot with crouch_alpha=0"):
		return
	if not T.require_true(self, is_zero_approx(float(pose_state.get("body_height_offset_m", 1.0))), "Robot dog joint contract must boot with zero body height offset"):
		return
	var legs: Array = pose_state.get("legs", [])
	if not T.require_true(self, legs.size() == 4, "Robot dog joint contract must expose 4 leg debug states"):
		return
	for leg_variant in legs:
		if not (leg_variant is Dictionary):
			T.fail_and_quit(self, "Robot dog joint contract legs[] entries must be Dictionary")
			return
		var leg_state: Dictionary = leg_variant as Dictionary
		for required_leg_key in [
			"leg_id",
			"hip_joint_name",
			"knee_joint_name",
			"hip_angle_deg",
			"knee_angle_deg",
			"body_to_thigh_angle_deg",
			"crouch_target_hip_angle_deg",
			"is_crouched",
		]:
			if not T.require_true(self, leg_state.has(required_leg_key), "Robot dog leg debug state must include %s" % required_leg_key):
				return

	robot_dog.queue_free()
	await process_frame
	T.pass_and_quit(self)
