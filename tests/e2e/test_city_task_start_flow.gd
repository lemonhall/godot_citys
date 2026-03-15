extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for task start flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_task_runtime"), "Task start flow requires task runtime access"):
		return
	if not T.require_true(self, world.has_method("get_task_slot_index"), "Task start flow requires task slot index access"):
		return
	if not T.require_true(self, world.has_method("select_task_for_tracking"), "Task start flow requires select_task_for_tracking()"):
		return
	if not T.require_true(self, world.has_method("get_task_world_marker_state"), "Task start flow requires task world marker introspection"):
		return

	var task_runtime = world.get_task_runtime()
	var task_slot_index = world.get_task_slot_index()
	var available_task: Dictionary = (task_runtime.get_tasks_for_status("available") as Array)[0]
	var task_id := str(available_task.get("task_id", ""))
	var start_slot: Dictionary = task_slot_index.get_slot_by_id(str(available_task.get("start_slot", "")))
	var player := world.get_node_or_null("Player")
	var standing_height := _estimate_standing_height(player)

	var selected: Dictionary = world.select_task_for_tracking(task_id)
	if not T.require_true(self, str(selected.get("task_id", "")) == task_id, "Task start flow must allow tracking the task before entering the start ring"):
		return
	if not T.require_true(self, not world.get_active_route_result().is_empty(), "Tracking the available task must route the player toward the start slot before mission start"):
		return
	if not T.require_true(self, str(world.get_active_route_result().get("route_style_id", "")) == "task_available", "Tracking the available task must use the green task route style before mission start"):
		return

	player.teleport_to_world_position(start_slot.get("world_anchor", Vector3.ZERO) + Vector3.UP * standing_height)
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame_index in range(8):
		await physics_frame
		await process_frame
	if not T.require_true(self, str(task_runtime.get_task_snapshot(task_id).get("status", "")) == "active", "Entering the start ring must activate the task in the end-to-end flow"):
		return

	var objective_slot: Dictionary = task_runtime.get_current_objective_slot(task_id)
	if not T.require_true(self, not objective_slot.is_empty(), "Task start flow must expose a formal active objective slot after start"):
		return
	if not T.require_true(self, (world.get_task_world_marker_state().get("themes", []) as Array).has("task_active_objective"), "Task start flow must render an active objective ring after the start trigger fires"):
		return
	if not T.require_true(self, str(world.get_active_route_result().get("route_style_id", "")) == "task_active", "Active task objectives must switch the route onto the blue task route style after mission start"):
		return
	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var route_overlay: Dictionary = minimap_snapshot.get("route_overlay", {})
	if not T.require_true(self, str(route_overlay.get("route_style_id", "")) == "task_active", "Active task objective routes must project the blue task style into the minimap overlay"):
		return

	player.teleport_to_world_position(objective_slot.get("world_anchor", Vector3.ZERO) + Vector3.UP * standing_height)
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame_index in range(8):
		await physics_frame
		await process_frame

	if not T.require_true(self, str(task_runtime.get_task_snapshot(task_id).get("status", "")) == "completed", "Entering the objective ring must complete the sample task end to end"):
		return
	if not T.require_true(self, world.get_active_route_result().is_empty(), "Completing the single-objective sample task must clear the active route"):
		return
	if not T.require_true(self, not (world.get_task_world_marker_state().get("themes", []) as Array).has("task_active_objective"), "Completing the active objective must clear the blue objective ring"):
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
