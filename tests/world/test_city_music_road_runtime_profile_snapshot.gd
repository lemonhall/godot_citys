extends SceneTree

const T := preload("res://tests/_test_util.gd")

const MANIFEST_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/landmark_manifest.json"
const LANDMARK_ID := "landmark:v23:music_road:chunk_136_136"
const PROFILE_STEPS := 180

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for music road runtime profile snapshot")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "Music road runtime profile snapshot requires get_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "Music road runtime profile snapshot requires reset_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("set_performance_diagnostics_enabled"), "Music road runtime profile snapshot requires set_performance_diagnostics_enabled()"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Music road runtime profile snapshot requires get_chunk_renderer()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Music road runtime profile snapshot requires player teleport support"):
		return

	var manifest := _load_manifest()
	if manifest.is_empty():
		T.fail_and_quit(self, "Music road runtime profile snapshot requires decodable manifest")
		return
	var world_position := _decode_vector3(manifest.get("world_position", null))
	player.teleport_to_world_position(world_position + Vector3(0.0, 3.0, -4.0))
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")
	world.set_performance_diagnostics_enabled(true)
	world.reset_performance_profile()

	for _step in range(PROFILE_STEPS):
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame

	var profile: Dictionary = world.get_performance_profile()
	var chunk_renderer = world.get_chunk_renderer()
	var landmark_state := {}
	if chunk_renderer != null and chunk_renderer.has_method("find_scene_landmark_node"):
		var landmark: Variant = chunk_renderer.find_scene_landmark_node(LANDMARK_ID)
		if landmark != null and landmark.has_method("get_music_road_debug_state"):
			landmark_state = landmark.get_music_road_debug_state()

	print("MUSIC_ROAD_PROFILE ", JSON.stringify({
		"frame_step_avg_usec": int(profile.get("frame_step_avg_usec", 0)),
		"update_streaming_avg_usec": int(profile.get("update_streaming_avg_usec", 0)),
		"renderer_sync_avg_usec": int(profile.get("update_streaming_renderer_sync_avg_usec", 0)),
		"renderer_sync_queue_avg_usec": int(profile.get("update_streaming_renderer_sync_queue_avg_usec", 0)),
		"renderer_sync_crowd_avg_usec": int(profile.get("update_streaming_renderer_sync_crowd_avg_usec", 0)),
		"renderer_sync_traffic_avg_usec": int(profile.get("update_streaming_renderer_sync_traffic_avg_usec", 0)),
		"crowd_active_state_count": int(profile.get("crowd_active_state_count", 0)),
		"traffic_active_state_count": int(profile.get("traffic_active_state_count", 0)),
		"veh_tier0_count": int(profile.get("veh_tier0_count", 0)),
		"veh_tier1_count": int(profile.get("veh_tier1_count", 0)),
		"veh_tier2_count": int(profile.get("veh_tier2_count", 0)),
		"veh_tier3_count": int(profile.get("veh_tier3_count", 0)),
		"music_road_debug_state": landmark_state,
	}))

	world.set_performance_diagnostics_enabled(false)
	world.queue_free()
	T.pass_and_quit(self)

func _load_manifest() -> Dictionary:
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
