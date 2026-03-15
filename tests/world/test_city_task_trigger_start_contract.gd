extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for task trigger start contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_task_runtime"), "Task trigger start contract requires task runtime access"):
		return
	if not T.require_true(self, world.has_method("get_task_slot_index"), "Task trigger start contract requires task slot index access"):
		return
	if not T.require_true(self, world.has_method("get_tracked_task_id"), "Task trigger start contract requires tracked task introspection"):
		return
	if not T.require_true(self, world.has_method("get_task_world_marker_state"), "Task trigger start contract requires task world marker introspection"):
		return

	var task_runtime = world.get_task_runtime()
	var task_slot_index = world.get_task_slot_index()
	var available_task: Dictionary = (task_runtime.get_tasks_for_status("available") as Array)[0]
	var task_id := str(available_task.get("task_id", ""))
	var start_slot: Dictionary = task_slot_index.get_slot_by_id(str(available_task.get("start_slot", "")))
	var start_anchor: Vector3 = start_slot.get("world_anchor", Vector3.ZERO)
	var player := world.get_node_or_null("Player")
	var standing_height := _estimate_standing_height(player)

	player.teleport_to_world_position(start_anchor + Vector3(float(start_slot.get("trigger_radius_m", 0.0)) + 6.0, standing_height, 0.0))
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame_index in range(4):
		await physics_frame
		await process_frame
	if not T.require_true(self, str(task_runtime.get_task_snapshot(task_id).get("status", "")) == "available", "Standing outside the trigger radius must not auto-start the task"):
		return

	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame_index in range(8):
		await physics_frame
		await process_frame

	if not T.require_true(self, str(task_runtime.get_task_snapshot(task_id).get("status", "")) == "active", "Walking into the start slot must start the task"):
		return
	if not T.require_true(self, str(world.get_tracked_task_id()) == task_id, "On-foot task start must sync the tracked task id"):
		return
	if not T.require_true(self, not world.get_active_route_result().is_empty(), "On-foot task start must switch the navigation route onto the active objective"):
		return
	if not T.require_true(self, (world.get_task_world_marker_state().get("themes", []) as Array).has("task_active_objective"), "On-foot task start must replace the start ring with an active objective ring"):
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
