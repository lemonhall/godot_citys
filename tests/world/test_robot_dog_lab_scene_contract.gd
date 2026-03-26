extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/RobotDogLab.tscn"
const ROBOT_DOG_SCENE_PATH := "res://city_game/world/creatures/quadrupeds/CityRobotDog.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Robot dog lab contract requires a dedicated RobotDogLab.tscn scene"):
		return
	if not T.require_true(self, ResourceLoader.exists(ROBOT_DOG_SCENE_PATH, "PackedScene"), "Robot dog lab contract requires the formal CityRobotDog.tscn scene resource"):
		return

	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Robot dog lab contract must load the lab scene as PackedScene"):
		return

	var lab_scene_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(LAB_SCENE_PATH))
	for authored_node_name in [
		"GroundBody",
		"FixtureRoot",
		"RampBody",
		"StepBody",
		"ChannelBody",
	]:
		if not T.require_true(self, lab_scene_text.find('[node name="%s"' % authored_node_name) >= 0, "Robot dog lab scene-first contract requires %s to be authored directly in RobotDogLab.tscn" % authored_node_name):
			return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"get_robot_dog",
		"get_robot_dog_debug_state",
		"reset_lab_state",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Robot dog lab scene must expose %s()" % required_method):
			return

	for required_node_path in [
		"GroundBody",
		"GroundBody/CollisionShape3D",
		"GroundBody/GroundMesh",
		"FixtureRoot",
		"FixtureRoot/RampBody",
		"FixtureRoot/StepBody",
		"FixtureRoot/ChannelBody",
		"Player",
		"Player/CameraRig/Camera3D",
		"Hud",
		"RobotDogRoot",
	]:
		if not T.require_true(self, lab.get_node_or_null(required_node_path) != null, "Robot dog lab scene must author %s in the scene-first hierarchy" % required_node_path):
			return

	var robot_dog := lab.get_robot_dog() as Node3D
	if not T.require_true(self, robot_dog != null, "Robot dog lab scene must mount a formal robot dog root"):
		return
	if not T.require_true(self, robot_dog.scene_file_path == ROBOT_DOG_SCENE_PATH, "Robot dog lab must mount the formal CityRobotDog.tscn instead of directly mounting the glb"):
		return

	var robot_dog_state := lab.get_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(robot_dog_state.get("species_id", "")) == "robot_dog", "Robot dog lab must boot with robot_dog as the formal species_id"):
		return
	if not T.require_true(self, int(robot_dog_state.get("joint_anchor_count", 0)) == 8, "Robot dog lab must preserve the 8 joint anchor contract"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
