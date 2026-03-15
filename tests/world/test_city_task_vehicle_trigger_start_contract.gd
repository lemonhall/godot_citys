extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle task trigger start contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_task_runtime"), "Vehicle task trigger start contract requires task runtime access"):
		return
	if not T.require_true(self, world.has_method("get_task_slot_index"), "Vehicle task trigger start contract requires task slot index access"):
		return
	if not T.require_true(self, world.has_method("is_player_driving_vehicle"), "Vehicle task trigger start contract requires driving state introspection"):
		return

	var task_runtime = world.get_task_runtime()
	var task_slot_index = world.get_task_slot_index()
	var available_task: Dictionary = (task_runtime.get_tasks_for_status("available") as Array)[0]
	var task_id := str(available_task.get("task_id", ""))
	var start_slot: Dictionary = task_slot_index.get_slot_by_id(str(available_task.get("start_slot", "")))
	var start_anchor: Vector3 = start_slot.get("world_anchor", Vector3.ZERO)
	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Vehicle task trigger start contract requires PlayerController.enter_vehicle_drive_mode()"):
		return

	player.enter_vehicle_drive_mode({
		"vehicle_id": "task_trigger_test_vehicle",
		"model_id": "sports_car",
		"world_position": start_anchor + Vector3(float(start_slot.get("trigger_radius_m", 0.0)) + 8.0, 0.0, 0.0),
		"heading": Vector3.FORWARD,
		"length_m": 4.4,
		"width_m": 1.9,
		"height_m": 1.5,
	})
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame_index in range(4):
		await physics_frame
		await process_frame
	if not T.require_true(self, world.is_player_driving_vehicle(), "Vehicle task trigger start contract requires the player to be in drive mode before entering the ring"):
		return
	if not T.require_true(self, str(task_runtime.get_task_snapshot(task_id).get("status", "")) == "available", "Driving near the start slot without entering it must not start the task"):
		return

	player.teleport_to_world_position(start_anchor + Vector3.UP * _estimate_standing_height(player))
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame_index in range(8):
		await physics_frame
		await process_frame

	if not T.require_true(self, str(task_runtime.get_task_snapshot(task_id).get("status", "")) == "active", "Driving the current vehicle through the start slot must start the task"):
		return
	if not T.require_true(self, not world.get_active_route_result().is_empty(), "Vehicle task trigger start contract must sync the active objective route after start"):
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
