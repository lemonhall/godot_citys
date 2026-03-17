extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LANDMARK_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_landmark.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LANDMARK_SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Music road visual toggle contract requires the authored landmark scene"):
		return

	var landmark := (scene as PackedScene).instantiate()
	root.add_child(landmark)
	await process_frame

	if not T.require_true(self, landmark.has_method("set_key_visuals_enabled"), "Music road visual toggle contract requires set_key_visuals_enabled() on the landmark"):
		return
	if not T.require_true(self, landmark.has_method("get_music_road_debug_state"), "Music road visual toggle contract requires debug-state introspection"):
		return

	var initial_debug_state: Dictionary = landmark.get_music_road_debug_state()
	if not T.require_true(self, initial_debug_state.get("key_visuals_enabled", false) == true, "Music road visual toggle contract must start with key visuals enabled"):
		return
	if not T.require_true(self, int(initial_debug_state.get("visible_key_instance_count", 0)) > 0, "Music road visual toggle contract must build visible key instances by default"):
		return

	landmark.set_key_visuals_enabled(false)
	var muted_debug_state: Dictionary = landmark.get_music_road_debug_state()
	if not T.require_true(self, muted_debug_state.get("key_visuals_enabled", true) == false, "Music road visual toggle contract must report key visuals disabled after toggling off"):
		return
	if not T.require_true(self, int(muted_debug_state.get("visible_key_instance_count", -1)) == 0, "Music road visual toggle contract must hide visible key instances after toggling off"):
		return

	landmark.set_key_visuals_enabled(true)
	var restored_debug_state: Dictionary = landmark.get_music_road_debug_state()
	if not T.require_true(self, restored_debug_state.get("key_visuals_enabled", false) == true, "Music road visual toggle contract must re-enable key visuals after toggling on"):
		return
	if not T.require_true(self, int(restored_debug_state.get("visible_key_instance_count", 0)) > 0, "Music road visual toggle contract must restore visible key instances after toggling on"):
		return

	landmark.free()
	T.pass_and_quit(self)
