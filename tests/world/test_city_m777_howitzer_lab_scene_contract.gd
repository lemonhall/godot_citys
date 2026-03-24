extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/M777HowitzerLab.tscn"
const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const PLAYER_SCRIPT_PATH := "res://city_game/scripts/PlayerController.gd"
const WRAPPED_YAW_SAMPLE_DEG := 523.11
const WRAPPED_YAW_EXPECTED_DEG := 163.11

const REQUIRED_NODE_PATHS := [
	"GroundBody",
	"GroundBody/CollisionShape3D",
	"GroundBody/GroundMesh",
	"ArtilleryRoot",
	"ArtilleryRoot/Howitzer",
	"Player",
	"Player/CollisionShape3D",
	"Player/Visual",
	"Player/CameraRig",
	"Player/CameraRig/Camera3D",
	"LabCameraRig",
	"LabCameraRig/Camera3D",
	"Hud",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "M777 howitzer lab contract requires a dedicated lab scene instead of piggybacking on preview harness"):
		return
	if not T.require_true(self, ResourceLoader.exists(HOWITZER_SCENE_PATH, "PackedScene"), "M777 howitzer lab contract requires the formal howitzer scene to stay loadable"):
		return

	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 howitzer lab contract must load the lab scene as PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	if not T.require_true(self, lab != null, "M777 howitzer lab contract must instantiate as Node3D"):
		return

	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"get_howitzer",
		"get_lab_state",
		"reset_lab_state",
		"adjust_yaw_degrees",
		"adjust_pitch_degrees",
	]:
		if not T.require_true(self, lab.has_method(required_method), "M777 howitzer lab scene must expose %s()" % required_method):
			return

	for node_path in REQUIRED_NODE_PATHS:
		if not T.require_true(self, lab.get_node_or_null(node_path) != null, "M777 howitzer lab scene must author %s in the scene hierarchy" % node_path):
			return

	var player := lab.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null, "M777 howitzer lab contract must include a formal Player node so the lab is explorable instead of only exposing a static camera"):
		return
	if not T.require_true(self, player.get_script() != null and player.get_script().resource_path == PLAYER_SCRIPT_PATH, "M777 howitzer lab player must reuse PlayerController.gd instead of inventing a lab-only movement stack"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "M777 howitzer lab player must preserve teleport_to_world_position() from PlayerController for future focused tests and lab utilities"):
		return
	var player_camera := lab.get_node_or_null("Player/CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, player_camera != null and player_camera.current, "M777 howitzer lab must boot through the player camera instead of leaving the lab on an unfocused static view"):
		return

	var howitzer := lab.get_howitzer() as Node3D
	if not T.require_true(self, howitzer != null, "M777 howitzer lab contract must expose the mounted howitzer scene through get_howitzer()"):
		return
	if not T.require_true(self, howitzer.scene_file_path == HOWITZER_SCENE_PATH, "M777 howitzer lab must mount the formal howitzer wrapper scene instead of directly mounting the GLB"):
		return

	var initial_state := lab.get_lab_state() as Dictionary
	if not T.require_true(self, initial_state.get("yaw_deg", null) is float, "M777 howitzer lab state must expose yaw_deg as float"):
		return
	if not T.require_true(self, initial_state.get("pitch_deg", null) is float, "M777 howitzer lab state must expose pitch_deg as float"):
		return

	lab.adjust_yaw_degrees(12.0)
	lab.adjust_pitch_degrees(5.0)
	await process_frame

	var adjusted_state := lab.get_lab_state() as Dictionary
	if not T.require_true(self, absf(float(adjusted_state.get("yaw_deg", 0.0)) - 12.0) <= 0.01, "M777 howitzer lab must route yaw adjustments into the mounted howitzer runtime state"):
		return
	if not T.require_true(self, absf(float(adjusted_state.get("pitch_deg", 0.0)) - 5.0) <= 0.01, "M777 howitzer lab must expose calibrated positive elevation after applying pitch adjustments instead of leaking the model's internal offset angle"):
		return

	lab.reset_lab_state()
	lab.adjust_yaw_degrees(WRAPPED_YAW_SAMPLE_DEG)
	await process_frame
	var wrapped_yaw_state := lab.get_lab_state() as Dictionary
	if not T.require_true(self, absf(float(wrapped_yaw_state.get("yaw_deg", 0.0)) - WRAPPED_YAW_EXPECTED_DEG) <= 0.01, "M777 howitzer lab must wrap yaw back into the 0-360 degree circle instead of exposing multi-turn accumulated yaw"):
		return

	lab.adjust_pitch_degrees(-100.0)
	await process_frame

	var clamped_low_state := lab.get_lab_state() as Dictionary
	if not T.require_true(self, absf(float(clamped_low_state.get("pitch_deg", 999.0))) <= 0.01, "M777 howitzer lab must clamp calibrated pitch at 0 degrees instead of allowing negative depression"):
		return

	lab.adjust_pitch_degrees(120.0)
	await process_frame

	var clamped_high_state := lab.get_lab_state() as Dictionary
	if not T.require_true(self, absf(float(clamped_high_state.get("pitch_deg", 0.0)) - 71.0) <= 0.01, "M777 howitzer lab must clamp calibrated pitch at the 71 degree upper elevation limit"):
		return

	lab.reset_lab_state()
	await process_frame

	var reset_state := lab.get_lab_state() as Dictionary
	if not T.require_true(self, absf(float(reset_state.get("yaw_deg", 999.0))) <= 0.01, "M777 howitzer lab reset must restore yaw to the default neutral state"):
		return
	if not T.require_true(self, absf(float(reset_state.get("pitch_deg", 999.0))) <= 0.01, "M777 howitzer lab reset must restore pitch to the default neutral state"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
