extends SceneTree

const T := preload("res://tests/_test_util.gd")

const FORMAL_DRONE_PATH := "res://city_game/assets/environment/source/aircraft/drone_a.glb"
const FORMAL_AIRCRAFT_README_PATH := "res://city_game/assets/environment/source/aircraft/README.md"
const ROOT_DRONE_PATH := "res://Drone.glb"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, FileAccess.file_exists(FORMAL_DRONE_PATH), "Drone asset intake contract requires drone_a.glb to live under the formal aircraft source directory"):
		return
	if not T.require_true(self, FileAccess.file_exists(FORMAL_AIRCRAFT_README_PATH), "Drone asset intake contract requires the aircraft source README to stay present"):
		return
	if not T.require_true(self, ResourceLoader.exists(FORMAL_DRONE_PATH, "PackedScene"), "Drone asset intake contract requires the formal drone glb to load as PackedScene"):
		return
	if not T.require_true(self, not FileAccess.file_exists(ROOT_DRONE_PATH), "Drone asset intake contract must not leave Drone.glb scattered in the repository root"):
		return

	var readme_text := FileAccess.get_file_as_string(FORMAL_AIRCRAFT_README_PATH)
	if not T.require_true(self, readme_text.find("drone_a.glb") >= 0, "Drone asset intake contract requires the aircraft README to mention drone_a.glb"):
		return

	var scene_resource := load(FORMAL_DRONE_PATH)
	if not T.require_true(self, scene_resource != null and scene_resource is PackedScene, "Drone asset intake contract requires the formal drone glb to resolve as PackedScene when loaded"):
		return
	var drone_root := (scene_resource as PackedScene).instantiate()
	if not T.require_true(self, drone_root is Node3D, "Drone asset intake contract requires the imported drone root to instantiate as Node3D"):
		return
	root.add_child(drone_root)
	await process_frame

	var visual_count := 0
	for child in drone_root.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null:
			continue
		visual_count += 1
	if not T.require_true(self, visual_count > 0, "Drone asset intake contract requires the formal drone asset to expose visible geometry after import"):
		return

	drone_root.queue_free()
	await process_frame
	T.pass_and_quit(self)
