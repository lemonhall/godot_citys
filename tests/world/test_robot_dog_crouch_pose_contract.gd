extends SceneTree

const T := preload("res://tests/_test_util.gd")

const ROBOT_DOG_SCENE_PATH := "res://city_game/world/creatures/quadrupeds/CityRobotDog.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(ROBOT_DOG_SCENE_PATH, "PackedScene"), "Robot dog crouch pose contract requires CityRobotDog.tscn"):
		return
	var scene := load(ROBOT_DOG_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Robot dog crouch pose contract must load CityRobotDog as PackedScene"):
		return

	var robot_dog := scene.instantiate() as Node3D
	root.add_child(robot_dog)
	await process_frame
	await process_frame

	for required_method in [
		"get_pose_debug_state",
		"set_crouch_requested",
		"tick_robot_dog",
		"reset_robot_dog_pose",
	]:
		if not T.require_true(self, robot_dog.has_method(required_method), "Robot dog crouch pose contract requires %s()" % required_method):
			return

	robot_dog.set_crouch_requested(true)
	for _step in range(24):
		robot_dog.tick_robot_dog(0.1)
		await process_frame

	var crouched_state := robot_dog.get_pose_debug_state() as Dictionary
	if not T.require_true(self, str(crouched_state.get("pose_state", "")) == "crouched", "Robot dog crouch pose contract must settle into crouched pose"):
		return
	if not T.require_true(self, float(crouched_state.get("crouch_alpha", 0.0)) >= 0.99, "Robot dog crouch pose contract must drive crouch_alpha to 1"):
		return
	if not T.require_true(self, float(crouched_state.get("body_height_offset_m", 0.0)) > 0.10, "Robot dog crouch pose contract must lower the body by more than 0.10m"):
		return
	var crouched_legs: Array = crouched_state.get("legs", [])
	if not T.require_true(self, crouched_legs.size() == 4, "Robot dog crouch pose contract must preserve 4 leg states while crouched"):
		return
	var average_body_to_thigh_angle := _average_body_to_thigh_angle(crouched_legs)
	if not T.require_true(self, average_body_to_thigh_angle <= 10.0, "Robot dog crouch pose contract must bring the thighs close to body-parallel"):
		return
	if not T.require_true(self, _max_abs_joint_angle(crouched_legs, "knee_angle_deg") >= 3.0, "Robot dog crouch pose contract must still articulate the calf pivots by a visible amount instead of leaving them untouched"):
		return

	robot_dog.set_crouch_requested(false)
	for _step in range(24):
		robot_dog.tick_robot_dog(0.1)
		await process_frame

	var standing_state := robot_dog.get_pose_debug_state() as Dictionary
	if not T.require_true(self, str(standing_state.get("pose_state", "")) == "standing", "Robot dog crouch pose contract must return to standing pose"):
		return
	if not T.require_true(self, float(standing_state.get("crouch_alpha", 1.0)) <= 0.01, "Robot dog crouch pose contract must restore crouch_alpha to zero"):
		return
	if not T.require_true(self, float(standing_state.get("body_height_offset_m", 1.0)) <= 0.01, "Robot dog crouch pose contract must restore body height offset to near zero"):
		return

	robot_dog.reset_robot_dog_pose()
	var reset_state := robot_dog.get_pose_debug_state() as Dictionary
	if not T.require_true(self, str(reset_state.get("pose_state", "")) == "standing", "Robot dog crouch pose contract reset must restore standing pose"):
		return
	if not T.require_true(self, not bool(reset_state.get("crouch_requested", true)), "Robot dog crouch pose contract reset must clear crouch_requested"):
		return

	robot_dog.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _average_body_to_thigh_angle(legs: Array) -> float:
	if legs.is_empty():
		return 999.0
	var total := 0.0
	for leg_variant in legs:
		var leg_state := leg_variant as Dictionary
		total += absf(float(leg_state.get("body_to_thigh_angle_deg", 999.0)))
	return total / float(legs.size())

func _max_abs_joint_angle(legs: Array, key: String) -> float:
	var maximum := 0.0
	for leg_variant in legs:
		var leg_state := leg_variant as Dictionary
		maximum = maxf(maximum, absf(float(leg_state.get(key, 0.0))))
	return maximum
