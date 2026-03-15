extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for task map tab contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "Task map tab contract requires full map control"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "Task map tab contract requires map screen state introspection"):
		return
	if not T.require_true(self, world.has_method("get_task_runtime"), "Task map tab contract requires task runtime access"):
		return
	if not T.require_true(self, world.has_method("select_task_for_tracking"), "Task map tab contract requires select_task_for_tracking()"):
		return
	if not T.require_true(self, world.has_method("get_tracked_task_id"), "Task map tab contract requires tracked task introspection"):
		return

	world.set_full_map_open(true)
	await process_frame

	var map_state: Dictionary = world.get_map_screen_state()
	var task_panel: Dictionary = map_state.get("task_panel", {})
	if not T.require_true(self, bool(task_panel.get("visible", false)), "Opening the full map must surface a formal Tasks panel state"):
		return
	var group_order: Array = task_panel.get("group_order", [])
	for group_name in ["current_task", "active", "available", "completed"]:
		if not T.require_true(self, group_order.has(group_name), "Tasks panel must publish the %s group in its formal state" % group_name):
			return
	var groups: Dictionary = task_panel.get("groups", {})
	if not T.require_true(self, (groups.get("available", []) as Array).size() >= 3, "Tasks panel must source available tasks from the runtime instead of a hardcoded empty list"):
		return

	var task_runtime = world.get_task_runtime()
	var available_tasks: Array = task_runtime.get_tasks_for_status("available")
	var first_task_id := str((available_tasks[0] as Dictionary).get("task_id", ""))
	var selected: Dictionary = world.select_task_for_tracking(first_task_id)
	if not T.require_true(self, str(selected.get("task_id", "")) == first_task_id, "Selecting a task from the panel contract must return the tracked task snapshot"):
		return
	if not T.require_true(self, str(world.get_tracked_task_id()) == first_task_id, "Task panel selection must update the tracked task id"):
		return
	if not T.require_true(self, not world.get_active_route_result().is_empty(), "Task panel selection must sync a formal route target for available tasks"):
		return

	map_state = world.get_map_screen_state()
	task_panel = map_state.get("task_panel", {})
	var current_task: Dictionary = task_panel.get("current_task", {})
	if not T.require_true(self, str(current_task.get("task_id", "")) == first_task_id, "Tasks panel current_task must follow the tracked task selection"):
		return
	if not T.require_true(self, str((map_state.get("last_selection_contract", {}) as Dictionary).get("selection_mode", "")) == "task_panel", "Task panel selection must use a formal task_panel selection contract instead of a hidden map-only state"):
		return
	if not T.require_true(self, (map_state.get("pin_types", []) as Array).has("task_available"), "Full map must render projected available task pins through the shared pin registry"):
		return

	world.queue_free()
	T.pass_and_quit(self)
