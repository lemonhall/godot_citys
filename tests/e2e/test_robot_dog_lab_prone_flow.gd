extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/RobotDogLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Robot dog lab prone flow requires RobotDogLab.tscn"):
		return
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Robot dog lab prone flow must load RobotDogLab as PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"get_robot_dog",
		"get_robot_dog_debug_state",
		"step_robot_dog",
		"reset_lab_state",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Robot dog lab prone flow requires %s()" % required_method):
			return

	var robot_dog := lab.get_robot_dog() as Node
	if not T.require_true(self, robot_dog != null, "Robot dog lab prone flow requires a mounted robot dog root"):
		return

	var press_p := InputEventKey.new()
	press_p.pressed = true
	press_p.keycode = KEY_P
	lab._unhandled_input(press_p)
	lab.step_robot_dog(0.1, 24)

	var crouched_state := lab.get_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(crouched_state.get("pose_state", "")) == "crouched", "Robot dog lab prone flow must enter crouched pose after pressing P"):
		return
	if not T.require_true(self, float(crouched_state.get("body_height_offset_m", 0.0)) > 0.10, "Robot dog lab prone flow must expose the lowered body state through the lab debug API"):
		return

	lab._unhandled_input(press_p)
	lab.step_robot_dog(0.1, 24)
	var standing_state := lab.get_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(standing_state.get("pose_state", "")) == "standing", "Robot dog lab prone flow must return to standing pose after pressing P again"):
		return

	var press_f5 := InputEventKey.new()
	press_f5.pressed = true
	press_f5.keycode = KEY_F5
	lab._unhandled_input(press_f5)

	var reset_state := lab.get_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(reset_state.get("pose_state", "")) == "standing", "Robot dog lab prone flow reset must restore standing pose"):
		return
	if not T.require_true(self, not bool(reset_state.get("crouch_requested", true)), "Robot dog lab prone flow reset must clear crouch_requested"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
