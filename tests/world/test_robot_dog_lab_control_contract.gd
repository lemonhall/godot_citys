extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/RobotDogLab.tscn"
const RUNTIME_SCRIPT_PATH := "res://city_game/world/creatures/quadrupeds/CityRobotDogControlRuntime.gd"
const ROBOT_DOG_SCENE_PATH := "res://city_game/world/creatures/quadrupeds/CityRobotDog.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Robot dog lab control contract requires RobotDogLab.tscn"):
		return
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Robot dog lab control contract must load RobotDogLab as PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"get_robot_dog",
		"get_robot_dog_runtime",
		"get_robot_dog_debug_state",
		"reset_lab_state",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Robot dog lab control contract requires %s()" % required_method):
			return

	var runtime := lab.get_robot_dog_runtime() as Node3D
	if not T.require_true(self, runtime != null, "Robot dog lab control contract requires a mounted robot dog control runtime"):
		return
	var runtime_script := runtime.get_script() as Script
	if not T.require_true(self, runtime_script != null and str(runtime_script.resource_path) == RUNTIME_SCRIPT_PATH, "Robot dog lab must mount the formal CityRobotDogControlRuntime.gd instead of directly mounting the visual dog scene as root runtime"):
		return

	var visual_robot_dog := lab.get_robot_dog() as Node3D
	if not T.require_true(self, visual_robot_dog != null and visual_robot_dog.scene_file_path == ROBOT_DOG_SCENE_PATH, "Robot dog lab get_robot_dog() must still resolve the formal CityRobotDog.tscn visual scene inside the control runtime"):
		return

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("is_control_enabled"), "Robot dog lab control contract requires the lab PlayerController node"):
		return
	var player_camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var runtime_camera := runtime.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, player_camera != null and runtime_camera != null, "Robot dog lab control contract requires both player and robot dog cameras"):
		return

	var initial_state := lab.get_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(initial_state.get("system_state", "")) == "active", "Robot dog lab must boot directly into the active robot dog control state for locomotion iteration"):
		return
	if not T.require_true(self, str(initial_state.get("control_owner", "")) == "robot_dog", "Robot dog lab must boot with control_owner=robot_dog instead of leaving control on the player"):
		return
	if not T.require_true(self, runtime_camera.current and not player_camera.current, "Robot dog lab must boot with the robot dog third-person camera current"):
		return
	if not T.require_true(self, not bool(player.is_control_enabled()) and bool(player.is_movement_locked()), "Robot dog lab must freeze the player body while the dog owns control"):
		return

	_press_lab_key(lab, KEY_P)
	await _settle_frames(64)
	var prone_state := lab.get_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(prone_state.get("locomotion_state", "")) == "prone", "Robot dog lab must still allow P to enter prone through the formal control runtime"):
		return
	if not T.require_true(self, str(prone_state.get("pose_state", "")) == "crouched", "Robot dog lab prone command must still drive the formal v60 crouch pose runtime"):
		return

	_press_lab_key(lab, KEY_F5)
	await _settle_frames(8)
	var reset_state := lab.get_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(reset_state.get("system_state", "")) == "active", "Robot dog lab reset must restore the formal active control runtime instead of dropping back to a private scene state"):
		return
	if not T.require_true(self, str(reset_state.get("locomotion_state", "")) == "idle", "Robot dog lab reset must restore idle locomotion instead of leaving the dog stuck prone"):
		return
	if not T.require_true(self, runtime_camera.current and not player_camera.current, "Robot dog lab reset must keep the robot dog third-person camera active for continued iteration"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _press_lab_key(lab: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	lab._unhandled_input(event)

func _settle_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
