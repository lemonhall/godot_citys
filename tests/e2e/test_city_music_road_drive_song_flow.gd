extends SceneTree

const T := preload("res://tests/_test_util.gd")

const MANIFEST_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/landmark_manifest.json"
const MUSIC_ROAD_LANDMARK_ID := "landmark:v23:music_road:chunk_136_136"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for music road drive-song flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var manifest := _load_music_road_manifest()
	if manifest.is_empty():
		T.fail_and_quit(self, "Music road drive-song flow requires a decodable landmark manifest")
		return
	var music_road_world_position: Vector3 = _decode_vector3(manifest.get("world_position", null))
	var forward_direction := _resolve_forward_direction(float(manifest.get("yaw_rad", 0.0)))
	if not T.require_true(self, world.has_method("get_music_road_runtime_state"), "Music road drive-song flow requires runtime state introspection"):
		return
	if not T.require_true(self, world.has_method("debug_step_music_road_runtime"), "Music road drive-song flow requires explicit runtime stepping for deterministic playback verification"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Music road drive-song flow requires drive-mode entry support"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "Music road drive-song flow requires teleport support for synthetic drive playback"):
		return

	player.teleport_to_world_position(music_road_world_position + Vector3.UP * 3.0 - forward_direction * 2.0)
	await process_frame
	var standing_height := _estimate_standing_height(player)
	player.enter_vehicle_drive_mode({
		"vehicle_id": "veh:test:music_road_drive_flow",
		"model_id": "sports_car_a",
		"heading": forward_direction,
		"world_position": music_road_world_position - forward_direction * 2.0,
		"length_m": 4.4,
		"width_m": 1.9,
		"height_m": 1.6,
		"speed_mps": 0.0,
	})
	world.update_streaming_for_position(player.global_position, 0.0)
	world.debug_step_music_road_runtime(0.0)

	var runtime_state: Dictionary = world.get_music_road_runtime_state()
	var road_length_m := float(runtime_state.get("road_length_m", 0.0))
	var target_speed_mps := float(runtime_state.get("target_speed_mps", 0.0))
	if not T.require_true(self, road_length_m > 0.0 and target_speed_mps > 0.0, "Music road drive-song flow requires runtime state to expose road length and target speed"):
		return

	var step_sec := 0.1
	var distance_m := -2.0
	var end_distance_m := road_length_m + 8.0
	while distance_m < end_distance_m:
		distance_m += target_speed_mps * step_sec
		var playback_position := music_road_world_position + forward_direction * distance_m + Vector3.UP * standing_height
		player.teleport_to_world_position(playback_position)
		world.update_streaming_for_position(player.global_position, step_sec)
		world.debug_step_music_road_runtime(step_sec)

	runtime_state = world.get_music_road_runtime_state()
	var last_completed_run: Dictionary = runtime_state.get("last_completed_run", {})
	if not T.require_true(self, not last_completed_run.is_empty(), "Music road drive-song flow must record a completed run after the vehicle finishes the authored road"):
		return
	if not T.require_true(self, bool(last_completed_run.get("song_success", false)), "Music road drive-song flow must mark the target-speed forward traversal as song_success"):
		return
	if not T.require_true(self, int(last_completed_run.get("triggered_note_count", 0)) >= 900, "Music road drive-song flow must trigger the full jue_bie_shu strip count"):
		return
	if not T.require_true(self, str(last_completed_run.get("song_id", "")) == "jue_bie_shu", "Music road drive-song flow must preserve the formal jue_bie_shu song_id through runtime completion"):
		return
	var landmarks_state: Dictionary = runtime_state.get("landmarks", {})
	var music_road_state: Dictionary = landmarks_state.get(MUSIC_ROAD_LANDMARK_ID, {})
	var note_player_state: Dictionary = music_road_state.get("note_player", {})
	if not T.require_true(self, int(note_player_state.get("played_note_count", 0)) > 0, "Music road drive-song flow must drive the landmark note player instead of only mutating run-state counters"):
		return
	var bank_status := str(note_player_state.get("bank_status", ""))
	if not T.require_true(self, bank_status == "ready" or bank_status == "fallback_synth", "Music road drive-song flow must resolve either the authored sample bank or the fallback synth path"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _estimate_standing_height(player) -> float:
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0

func _load_music_road_manifest() -> Dictionary:
	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not (manifest_variant is Dictionary):
		return {}
	return (manifest_variant as Dictionary).duplicate(true)

func _decode_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var payload: Dictionary = value
	return Vector3(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("z", 0.0))
	)

func _resolve_forward_direction(yaw_rad: float) -> Vector3:
	var forward := Vector3.BACK.rotated(Vector3.UP, yaw_rad)
	forward.y = 0.0
	return forward.normalized()
