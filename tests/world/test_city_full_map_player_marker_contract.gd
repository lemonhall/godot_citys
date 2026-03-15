extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for full-map player marker contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Full-map player marker contract requires drive-mode entry support"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "Full-map player marker contract requires full-map render state introspection"):
		return
	if not T.require_true(self, world.has_method("set_full_map_open"), "Full-map player marker contract requires full-map open control"):
		return
	if not T.require_true(self, world.has_method("fast_travel_to_target"), "Full-map player marker contract requires stable fast-travel setup support"):
		return

	var start_travel: Dictionary = world.fast_travel_to_target(Vector3(128.0, 0.0, 14.0))
	if not T.require_true(self, bool(start_travel.get("success", false)), "Full-map player marker contract requires a stable drive-mode start point"):
		return

	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player, Vector3.RIGHT))
	await process_frame

	world.set_full_map_open(true)
	await process_frame

	var map_state: Dictionary = world.get_map_screen_state()
	var player_marker: Dictionary = map_state.get("player_marker", {})
	if not T.require_true(self, not player_marker.is_empty(), "Opening the full map must expose a player marker render state instead of omitting the player triangle"):
		return
	if not T.require_true(self, player_marker.has("position"), "Full-map player marker must expose a projected 2D position"):
		return

	var marker_position: Vector2 = player_marker.get("position", Vector2(-1.0, -1.0))
	var map_size: Vector2 = map_state.get("size", Vector2.ZERO)
	if not T.require_true(self, map_size.x > 0.0 and map_size.y > 0.0, "Full-map player marker contract requires a valid full-map viewport size"):
		return
	if not T.require_true(self, marker_position.x >= 0.0 and marker_position.x <= map_size.x and marker_position.y >= 0.0 and marker_position.y <= map_size.y, "Full-map player marker must land inside the visible map viewport"):
		return

	var heading_rad := float(player_marker.get("heading_rad", 0.0))
	var expected_heading_rad := PI * 0.5
	var heading_error := absf(wrapf(heading_rad - expected_heading_rad, -PI, PI))
	if not T.require_true(self, heading_error <= 0.15, "Driving east/right must make the full-map player triangle point right instead of drifting or mirroring"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _build_synthetic_vehicle_state(player, heading: Vector3) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:full_map_player_marker",
		"model_id": "car_b",
		"heading": heading,
		"world_position": player.global_position - Vector3.UP * standing_height,
		"length_m": 4.4,
		"width_m": 1.9,
		"height_m": 1.6,
		"speed_mps": 0.0,
	}

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
