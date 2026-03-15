extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Task route destination marker guard requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_task_runtime"), "Task route destination marker guard requires task runtime access"):
		return
	if not T.require_true(self, world.has_method("select_task_for_tracking"), "Task route destination marker guard requires task tracking access"):
		return
	if not T.require_true(self, world.has_method("get_task_world_marker_state"), "Task route destination marker guard requires task world marker state"):
		return
	if not T.require_true(self, world.has_method("get_destination_world_marker_state"), "Task route destination marker guard requires destination world marker state"):
		return

	var task_runtime = world.get_task_runtime()
	var available_tasks: Array = task_runtime.get_tasks_for_status("available")
	if not T.require_true(self, not available_tasks.is_empty(), "Task route destination marker guard requires at least one available task"):
		return

	var first_task: Dictionary = available_tasks[0]
	task_runtime.start_task(str(first_task.get("task_id", "")))
	world.select_task_for_tracking(str(first_task.get("task_id", "")))
	for _frame_index in range(6):
		await physics_frame
		await process_frame

	var task_marker_state: Dictionary = world.get_task_world_marker_state()
	var destination_marker_state: Dictionary = world.get_destination_world_marker_state()
	if not T.require_true(self, (task_marker_state.get("themes", []) as Array).has("task_active_objective"), "Active task route must still show the blue objective marker"):
		return
	if not T.require_true(self, not bool(destination_marker_state.get("visible", true)), "Active task route must keep the generic destination world marker hidden to avoid duplicate world markers"):
		return

	world.queue_free()
	T.pass_and_quit(self)
