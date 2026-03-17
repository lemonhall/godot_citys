extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LANDMARK_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_landmark.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LANDMARK_SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Music road playback toggle contract requires the authored landmark scene"):
		return

	var landmark := (scene as PackedScene).instantiate()
	root.add_child(landmark)
	await process_frame

	if not T.require_true(self, landmark.has_method("set_note_playback_enabled"), "Music road playback toggle contract requires set_note_playback_enabled() on the landmark"):
		return
	if not T.require_true(self, landmark.has_method("debug_apply_music_road_vehicle_state"), "Music road playback toggle contract requires debug_apply_music_road_vehicle_state() on the landmark"):
		return
	if not T.require_true(self, landmark.has_method("get_music_road_runtime_state"), "Music road playback toggle contract requires runtime state introspection"):
		return

	landmark.set_note_playback_enabled(false)
	landmark.debug_apply_music_road_vehicle_state({
		"driving": true,
		"world_position": Vector3(0.0, 0.0, 2.0),
	}, 0.0)
	landmark.debug_apply_music_road_vehicle_state({
		"driving": true,
		"world_position": Vector3(0.0, 0.0, 20.0),
	}, 1.0)

	var runtime_state: Dictionary = landmark.get_music_road_runtime_state()
	var note_player_state: Dictionary = runtime_state.get("note_player", {})
	if not T.require_true(self, note_player_state.get("playback_enabled", true) == false, "Music road playback toggle contract must report playback_enabled = false after muting"):
		return
	if not T.require_true(self, int(note_player_state.get("triggered_note_count", 0)) > 0, "Music road playback toggle contract must keep forwarding note events while playback is muted"):
		return
	if not T.require_true(self, int(note_player_state.get("played_note_count", 0)) == 0, "Music road playback toggle contract must suppress audible plays while muted"):
		return
	if not T.require_true(self, int(note_player_state.get("suppressed_note_count", 0)) > 0, "Music road playback toggle contract must account for muted note events in telemetry"):
		return

	landmark.queue_free()
	T.pass_and_quit(self)
