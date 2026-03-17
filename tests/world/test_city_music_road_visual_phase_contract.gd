extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LANDMARK_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_landmark.tscn"
const TARGET_STRIP_ID := "strip_0000"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LANDMARK_SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Music road visual phase contract requires the authored landmark scene"):
		return

	var landmark := (scene as PackedScene).instantiate()
	root.add_child(landmark)
	await process_frame

	if not T.require_true(self, landmark.has_method("debug_apply_music_road_vehicle_state"), "Music road visual phase contract requires debug_apply_music_road_vehicle_state() on the landmark"):
		return
	if not T.require_true(self, landmark.has_method("get_music_road_strip_phase"), "Music road visual phase contract requires get_music_road_strip_phase() on the landmark"):
		return

	landmark.debug_apply_music_road_vehicle_state({
		"driving": true,
		"world_position": Vector3(0.0, 0.0, 2.0),
	}, 0.0)
	var idle_phase: Dictionary = landmark.get_music_road_strip_phase(TARGET_STRIP_ID)
	if not T.require_true(self, str(idle_phase.get("phase", "")) == "idle", "Music road strip must stay idle before the player enters the approach glow window"):
		return

	landmark.debug_apply_music_road_vehicle_state({
		"driving": true,
		"world_position": Vector3(0.0, 0.0, 4.0),
	}, 1.0)
	var approach_phase: Dictionary = landmark.get_music_road_strip_phase(TARGET_STRIP_ID)
	if not T.require_true(self, str(approach_phase.get("phase", "")) == "approach", "Music road strip must expose approach phase before the vehicle reaches the key"):
		return
	if not T.require_true(self, float(approach_phase.get("phase_strength", 0.0)) > 0.0, "Music road approach phase must expose a positive shader-friendly strength"):
		return

	landmark.debug_apply_music_road_vehicle_state({
		"driving": true,
		"world_position": Vector3(0.0, 0.0, 20.0),
	}, 2.0)
	var active_phase: Dictionary = landmark.get_music_road_strip_phase(TARGET_STRIP_ID)
	if not T.require_true(self, str(active_phase.get("phase", "")) == "active", "Music road strip must enter active phase exactly when the vehicle crosses the key"):
		return

	landmark.debug_apply_music_road_vehicle_state({
		"driving": true,
		"world_position": Vector3(0.0, 0.0, 26.0),
	}, 2.45)
	var decay_phase: Dictionary = landmark.get_music_road_strip_phase(TARGET_STRIP_ID)
	if not T.require_true(self, str(decay_phase.get("phase", "")) == "decay", "Music road strip must decay after the hit flash window elapses"):
		return

	landmark.debug_apply_music_road_vehicle_state({
		"driving": false,
		"world_position": Vector3(0.0, 0.0, 60.0),
	}, 4.5)
	var returned_idle_phase: Dictionary = landmark.get_music_road_strip_phase(TARGET_STRIP_ID)
	if not T.require_true(self, str(returned_idle_phase.get("phase", "")) == "idle", "Music road strip must return to idle after release decay completes"):
		return

	landmark.queue_free()
	T.pass_and_quit(self)
