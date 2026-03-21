extends SceneTree

const T := preload("res://tests/_test_util.gd")

const FORMAL_HELICOPTER_PATH := "res://city_game/assets/environment/source/aircraft/helicopter_a.glb"
const FORMAL_HELICOPTER_README_PATH := "res://city_game/assets/environment/source/aircraft/README.md"
const ROOT_HELICOPTER_PATH := "res://Helicopter.glb"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, FileAccess.file_exists(FORMAL_HELICOPTER_PATH), "Helicopter asset intake contract requires helicopter_a.glb to live under the formal aircraft source directory"):
		return
	if not T.require_true(self, FileAccess.file_exists(FORMAL_HELICOPTER_README_PATH), "Helicopter asset intake contract requires a local README that explains the aircraft source asset directory"):
		return
	if not T.require_true(self, ResourceLoader.exists(FORMAL_HELICOPTER_PATH, "PackedScene"), "Helicopter asset intake contract requires the formal helicopter glb to load as PackedScene"):
		return
	if not T.require_true(self, not FileAccess.file_exists(ROOT_HELICOPTER_PATH), "Helicopter asset intake contract must not leave Helicopter.glb scattered in the repository root"):
		return

	var scene_resource := load(FORMAL_HELICOPTER_PATH)
	if not T.require_true(self, scene_resource != null and scene_resource is PackedScene, "Helicopter asset intake contract requires the formal helicopter glb to resolve as PackedScene when loaded"):
		return
	var helicopter_root := (scene_resource as PackedScene).instantiate()
	if not T.require_true(self, helicopter_root is Node3D, "Helicopter asset intake contract requires the imported helicopter root to instantiate as Node3D"):
		return
	root.add_child(helicopter_root)
	await process_frame

	var visual_count := 0
	for child in helicopter_root.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null:
			continue
		visual_count += 1
	if not T.require_true(self, visual_count > 0, "Helicopter asset intake contract requires the formal helicopter asset to expose visible geometry after import"):
		return

	helicopter_root.queue_free()
	await process_frame
	T.pass_and_quit(self)
