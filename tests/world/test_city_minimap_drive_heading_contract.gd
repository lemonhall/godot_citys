extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for minimap drive heading contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Minimap drive heading contract requires drive-mode entry support"):
		return
	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "Minimap drive heading contract requires minimap snapshot support"):
		return
	if not T.require_true(self, world.has_method("fast_travel_to_target"), "Minimap drive heading contract requires stable fast-travel setup support"):
		return

	var start_travel: Dictionary = world.fast_travel_to_target(Vector3(128.0, 0.0, 14.0))
	if not T.require_true(self, bool(start_travel.get("success", false)), "Minimap drive heading contract requires a stable drive-mode start point"):
		return

	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player, Vector3.RIGHT))
	await process_frame

	var snapshot: Dictionary = world.build_minimap_snapshot()
	var player_marker: Dictionary = snapshot.get("player_marker", {})
	var heading_rad := float(player_marker.get("heading_rad", 0.0))
	var expected_heading_rad := PI * 0.5
	var heading_error := absf(wrapf(heading_rad - expected_heading_rad, -PI, PI))
	if not T.require_true(self, heading_error <= 0.15, "Driving east/right must make the minimap marker point right instead of mirroring left"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _build_synthetic_vehicle_state(player, heading: Vector3) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:minimap_drive_heading",
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
