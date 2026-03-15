extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player vehicle mouse-steer contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Vehicle mouse-steer contract requires drive-mode entry support"):
		return
	if not T.require_true(self, player.has_method("set_vehicle_drive_input"), "Vehicle mouse-steer contract requires manual drive input support"):
		return
	if not T.require_true(self, player.has_method("clear_vehicle_drive_input"), "Vehicle mouse-steer contract requires manual drive input cleanup support"):
		return
	if not T.require_true(self, player.has_method("get_driving_vehicle_state"), "Vehicle mouse-steer contract requires driving-state introspection"):
		return
	if not T.require_true(self, player.has_method("apply_vehicle_mouse_steer_delta"), "PlayerController must expose apply_vehicle_mouse_steer_delta() so driving mouse steering can be validated headlessly"):
		return
	if not T.require_true(self, world.has_method("fast_travel_to_target"), "Vehicle mouse-steer contract requires stable drive start placement"):
		return

	var start_travel: Dictionary = world.fast_travel_to_target(Vector3(128.0, 0.0, 14.0))
	if not T.require_true(self, bool(start_travel.get("success", false)), "Vehicle mouse-steer contract requires a stable surface-aligned drive start"):
		return

	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))
	await process_frame

	player.set_vehicle_drive_input(1.0, 0.0, false)
	player.apply_vehicle_mouse_steer_delta(120.0)
	for _frame_index in range(10):
		await physics_frame
		await process_frame
	player.clear_vehicle_drive_input()

	var heading: Vector3 = (player.get_driving_vehicle_state() as Dictionary).get("heading", Vector3.ZERO)
	if not T.require_true(self, heading.x >= 0.08, "Moving the mouse to the right while driving forward must yaw the vehicle to the right instead of ignoring mouse steering"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:player_vehicle_mouse_steer",
		"model_id": "car_b",
		"heading": Vector3.FORWARD,
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
