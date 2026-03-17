extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LANDMARK_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_landmark.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LANDMARK_SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Music road runtime-state compact contract requires the authored landmark scene"):
		return

	var landmark := (scene as PackedScene).instantiate()
	root.add_child(landmark)
	await process_frame

	if not T.require_true(self, landmark.has_method("debug_apply_music_road_vehicle_state"), "Music road runtime-state compact contract requires debug_apply_music_road_vehicle_state() on the landmark"):
		return
	if not T.require_true(self, landmark.has_method("get_music_road_runtime_state"), "Music road runtime-state compact contract requires runtime state introspection"):
		return

	landmark.debug_apply_music_road_vehicle_state({
		"driving": true,
		"world_position": Vector3(0.0, 0.0, 2.0),
	}, 0.0)
	landmark.debug_apply_music_road_vehicle_state({
		"driving": true,
		"world_position": Vector3(0.0, 0.0, 20.0),
	}, 1.0)

	var runtime_state: Dictionary = landmark.get_music_road_runtime_state()
	if not T.require_true(self, int(runtime_state.get("triggered_note_count", 0)) > 0, "Music road runtime-state compact contract must still expose triggered_note_count summary after notes fire"):
		return
	if not T.require_true(self, not runtime_state.has("triggered_note_events"), "Music road runtime-state compact contract must not deep-copy triggered_note_events into the per-frame landmark state payload"):
		return
	if not T.require_true(self, (runtime_state.get("note_player", {}) as Dictionary).has("played_note_count"), "Music road runtime-state compact contract must keep note player telemetry in the compact payload"):
		return

	root.remove_child(landmark)
	landmark.queue_free()
	await process_frame
	T.pass_and_quit(self)
