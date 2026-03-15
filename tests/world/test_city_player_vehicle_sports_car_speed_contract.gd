extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for sports-car speed contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Sports-car speed contract requires drive-mode entry support"):
		return
	if not T.require_true(self, player.has_method("exit_vehicle_drive_mode"), "Sports-car speed contract requires drive-mode exit support"):
		return
	if not T.require_true(self, player.has_method("set_vehicle_drive_input"), "Sports-car speed contract requires manual drive input support"):
		return
	if not T.require_true(self, player.has_method("clear_vehicle_drive_input"), "Sports-car speed contract requires manual drive input cleanup support"):
		return
	if not T.require_true(self, player.has_method("get_driving_vehicle_state"), "Sports-car speed contract requires driving-state introspection"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "Sports-car speed contract requires teleport setup support"):
		return
	if not T.require_true(self, world.has_method("fast_travel_to_target"), "Sports-car speed contract requires stable drive start placement"):
		return

	var start_travel: Dictionary = world.fast_travel_to_target(Vector3(128.0, 0.0, 14.0))
	if not T.require_true(self, bool(start_travel.get("success", false)), "Sports-car speed contract requires a stable surface-aligned drive start"):
		return

	var baseline_position: Vector3 = player.global_position
	var sedan_metrics: Dictionary = await _measure_drive_metrics(player, baseline_position, "car_b")
	if not T.require_true(self, sedan_metrics.get("speed_mps", 0.0) > 0.0, "Sports-car speed contract requires a moving default sedan baseline"):
		return

	player.teleport_to_world_position(baseline_position)
	await process_frame
	var sports_metrics: Dictionary = await _measure_drive_metrics(player, baseline_position, "sports_car_a")
	if not T.require_true(self, sports_metrics.get("speed_mps", 0.0) >= sedan_metrics.get("speed_mps", 0.0) * 1.9, "Hijacked sports_car_a must accelerate to roughly double the default sedan speed"):
		return
	if not T.require_true(self, sports_metrics.get("distance_m", 0.0) >= sedan_metrics.get("distance_m", 0.0) * 1.8, "Hijacked sports_car_a must cover far more ground than the default sedan over the same drive window"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _measure_drive_metrics(player, start_position: Vector3, model_id: String) -> Dictionary:
	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player, model_id))
	await process_frame
	player.set_vehicle_drive_input(1.0, 0.0, false)
	for _frame_index in range(60):
		await physics_frame
		await process_frame
	player.clear_vehicle_drive_input()
	var driving_state: Dictionary = player.get_driving_vehicle_state()
	var distance_m := start_position.distance_to(player.global_position)
	player.exit_vehicle_drive_mode()
	await process_frame
	return {
		"speed_mps": float(driving_state.get("speed_mps", 0.0)),
		"distance_m": distance_m,
	}

func _build_synthetic_vehicle_state(player, model_id: String) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:%s" % model_id,
		"model_id": model_id,
		"heading": Vector3.FORWARD,
		"world_position": player.global_position - Vector3.UP * standing_height,
		"length_m": 4.6,
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
