extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for task tab selection flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "Task tab flow requires full map control"):
		return
	if not T.require_true(self, world.has_method("get_task_runtime"), "Task tab flow requires task runtime access"):
		return
	if not T.require_true(self, world.has_method("select_task_for_tracking"), "Task tab flow requires select_task_for_tracking()"):
		return
	if not T.require_true(self, world.has_method("get_last_map_selection_contract"), "Task tab flow requires last selection contract introspection"):
		return

	var task_runtime = world.get_task_runtime()
	var available_tasks: Array = task_runtime.get_tasks_for_status("available")
	if not T.require_true(self, available_tasks.size() >= 1, "Task tab flow requires at least one available task"):
		return
	var first_task_id := str((available_tasks[0] as Dictionary).get("task_id", ""))

	world.set_full_map_open(true)
	await process_frame
	var selected: Dictionary = world.select_task_for_tracking(first_task_id)
	if not T.require_true(self, str(selected.get("task_id", "")) == first_task_id, "Task tab flow must return the selected task snapshot"):
		return

	var route_result: Dictionary = world.get_active_route_result()
	if not T.require_true(self, str(route_result.get("route_id", "")) != "", "Task tab flow must keep a formal route active after task selection"):
		return
	if not T.require_true(self, str(route_result.get("route_style_id", "")) == "task_available", "Tracking an available task must switch the route onto the green task route style instead of the destination style"):
		return
	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var route_overlay: Dictionary = minimap_snapshot.get("route_overlay", {})
	if not T.require_true(self, str(route_overlay.get("route_style_id", "")) == "task_available", "Tracked available task must project a green task route into the minimap overlay"):
		return
	var pin_overlay: Dictionary = minimap_snapshot.get("pin_overlay", {})
	if not T.require_true(self, (pin_overlay.get("pin_types", []) as Array).has("task_available"), "Tracked available task must project into the minimap overlay through the shared pin registry"):
		return
	var selection_contract: Dictionary = world.get_last_map_selection_contract()
	if not T.require_true(self, str(selection_contract.get("selection_mode", "")) == "task_panel", "Task tab flow must keep a formal task_panel selection contract"):
		return
	if not T.require_true(self, str(selection_contract.get("task_id", "")) == first_task_id, "Task tab flow selection contract must keep the selected task id"):
		return

	world.set_full_map_open(false)
	await process_frame
	if not T.require_true(self, str(world.get_active_route_result().get("route_id", "")) == str(route_result.get("route_id", "")), "Closing the full map must not discard the task-tracking route"):
		return

	world.queue_free()
	T.pass_and_quit(self)
