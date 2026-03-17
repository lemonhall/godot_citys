extends SceneTree

const MUSIC_ROAD_WORLD_POSITION := Vector3(0.0, 9.0, 64.0)
const LANDMARK_ID := "landmark:v23:music_road:chunk_136_136"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player = world.get_node_or_null("Player")
	var renderer = world.get_chunk_renderer()
	player.teleport_to_world_position(MUSIC_ROAD_WORLD_POSITION + Vector3(0.0, 3.0, -2.0))
	await process_frame
	var standing_height := 1.0
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape != null and collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		standing_height = capsule.radius + capsule.height * 0.5
	player.enter_vehicle_drive_mode({
		"vehicle_id": "veh:test:debug",
		"model_id": "sports_car_a",
		"heading": Vector3(0.0, 0.0, 1.0),
		"world_position": Vector3(MUSIC_ROAD_WORLD_POSITION.x, MUSIC_ROAD_WORLD_POSITION.y, MUSIC_ROAD_WORLD_POSITION.z - 2.0),
		"length_m": 4.4,
		"width_m": 1.9,
		"height_m": 1.6,
		"speed_mps": 0.0,
	})
	world.update_streaming_for_position(player.global_position, 0.0)
	await process_frame
	var runtime_state: Dictionary = world.get_music_road_runtime_state()
	var step_sec := 0.1
	var z := MUSIC_ROAD_WORLD_POSITION.z - 2.0
	var end_z := MUSIC_ROAD_WORLD_POSITION.z + float(runtime_state.get("road_length_m", 0.0)) + 8.0
	var i := 0
	while z < end_z:
		z += float(runtime_state.get("target_speed_mps", 0.0)) * step_sec
		player.teleport_to_world_position(Vector3(MUSIC_ROAD_WORLD_POSITION.x, MUSIC_ROAD_WORLD_POSITION.y + standing_height, z))
		world.update_streaming_for_position(player.global_position, step_sec)
		await physics_frame
		await process_frame
		i += 1
		if i in [1,100,400,800]:
			var landmark = renderer.find_scene_landmark_node(LANDMARK_ID) as Node3D
			var drive_state: Dictionary = player.get_driving_vehicle_state()
			var drive_pos := drive_state.get("world_position", Vector3.ZERO) as Vector3
			var local_pos := landmark.to_local(drive_pos) if landmark != null else Vector3.ZERO
			var landmark_state: Dictionary = landmark.get_music_road_runtime_state() if landmark != null else {}
			print("tick=", i, " drive=", drive_pos, " landmark_global=", landmark.global_position if landmark != null else Vector3.ZERO, " local=", local_pos, " trig=", landmark_state.get("triggered_note_count"), " prev=", landmark_state.get("triggered_note_events", []))
	quit(0)
