extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	if config_script == null or generator_script == null:
		T.fail_and_quit(self, "Task runtime state machine test requires CityWorldConfig and CityWorldGenerator")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)
	var task_runtime = world_data.get("task_runtime")
	if not T.require_true(self, task_runtime != null, "World generation must expose task_runtime for v14 M1 state machine validation"):
		return

	for required_method in [
		"get_tasks_for_status",
		"get_active_task_id",
		"get_task_snapshot",
		"set_tracked_task",
		"start_task",
		"start_task_from_slot",
		"get_current_objective_slot",
		"complete_objective_slot",
		"get_slots_for_rect",
	]:
		if not T.require_true(self, task_runtime.has_method(required_method), "task_runtime must expose %s()" % required_method):
			return

	var available_tasks: Array = task_runtime.get_tasks_for_status("available")
	if not T.require_true(self, available_tasks.size() >= 2, "Task runtime needs at least two available tasks to validate active-task uniqueness"):
		return
	if not T.require_true(self, (task_runtime.get_tasks_for_status("active") as Array).is_empty(), "Task runtime must start with zero active tasks"):
		return
	if not T.require_true(self, (task_runtime.get_tasks_for_status("completed") as Array).is_empty(), "Task runtime must start with zero completed tasks"):
		return

	var first_task_id := str((available_tasks[0] as Dictionary).get("task_id", ""))
	var second_task_id := str((available_tasks[1] as Dictionary).get("task_id", ""))
	if not T.require_true(self, first_task_id != "" and second_task_id != "", "Available task snapshots must expose non-empty task ids"):
		return

	var tracked_snapshot: Dictionary = task_runtime.set_tracked_task(first_task_id)
	if not T.require_true(self, str(tracked_snapshot.get("task_id", "")) == first_task_id, "Setting tracked task must return the matching task snapshot"):
		return
	if not T.require_true(self, str(task_runtime.get_tracked_task_id()) == first_task_id, "Task runtime must keep tracked_task_id stable after explicit selection"):
		return
	if not T.require_true(self, not (tracked_snapshot.get("route_target", {}) as Dictionary).is_empty(), "Available tracked task must expose a formal route_target toward its start slot"):
		return

	var started: Dictionary = task_runtime.start_task(first_task_id)
	if not T.require_true(self, str(started.get("status", "")) == "active", "start_task() must move the task into active state"):
		return
	if not T.require_true(self, str(task_runtime.get_active_task_id()) == first_task_id, "Task runtime must expose exactly one active task id after start"):
		return

	var blocked_second_start: Dictionary = task_runtime.start_task(second_task_id)
	if not T.require_true(self, blocked_second_start.is_empty(), "Task runtime must reject starting a second task while one is already active"):
		return
	if not T.require_true(self, str(task_runtime.get_active_task_id()) == first_task_id, "Rejected second start must not replace the active task"):
		return

	var objective_slot: Dictionary = task_runtime.get_current_objective_slot(first_task_id)
	if not T.require_true(self, not objective_slot.is_empty(), "Active task must expose a current objective slot"):
		return
	var objective_anchor: Vector3 = objective_slot.get("world_anchor", Vector3.ZERO)
	var objective_rect := Rect2(Vector2(objective_anchor.x - 2.0, objective_anchor.z - 2.0), Vector2.ONE * 4.0)
	var active_objective_slots: Array = task_runtime.get_slots_for_rect(objective_rect, ["active"], ["objective"])
	if not T.require_true(self, _array_has_slot(active_objective_slots, str(objective_slot.get("slot_id", ""))), "Active objective slots must be queryable by rect without scanning unrelated task states"):
		return

	var completed: Dictionary = task_runtime.complete_objective_slot(str(objective_slot.get("slot_id", "")))
	if not T.require_true(self, str(completed.get("status", "")) == "completed", "Completing the current objective slot must complete the v14 sample task"):
		return
	if not T.require_true(self, str(task_runtime.get_active_task_id()) == "", "Completing the current objective must clear active_task_id when no further objective remains"):
		return
	if not T.require_true(self, _array_has_task(task_runtime.get_tasks_for_status("completed"), first_task_id), "Completed task list must include the finished task"):
		return
	if not T.require_true(self, (completed.get("route_target", {}) as Dictionary).is_empty(), "Completed tasks must stop exposing an active route_target"):
		return

	T.pass_and_quit(self)

func _array_has_slot(slots: Array, slot_id: String) -> bool:
	for slot_variant in slots:
		var slot: Dictionary = slot_variant
		if str(slot.get("slot_id", "")) == slot_id:
			return true
	return false

func _array_has_task(tasks: Array, task_id: String) -> bool:
	for task_variant in tasks:
		var task: Dictionary = task_variant
		if str(task.get("task_id", "")) == task_id:
			return true
	return false
