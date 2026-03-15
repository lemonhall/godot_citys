extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var view_model_script := load("res://city_game/world/tasks/presentation/CityTaskBriefViewModel.gd")
	if config_script == null or generator_script == null or view_model_script == null:
		T.fail_and_quit(self, "Task brief view model test requires CityWorldConfig, CityWorldGenerator, and CityTaskBriefViewModel")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)
	var task_runtime = world_data.get("task_runtime")
	var view_model = view_model_script.new()

	var panel_state: Dictionary = view_model.build(task_runtime)
	var groups: Dictionary = panel_state.get("groups", {})
	if not T.require_true(self, (groups.get("available", []) as Array).size() >= 3, "Task brief view model must expose available tasks from the runtime"):
		return
	if not T.require_true(self, (groups.get("active", []) as Array).is_empty(), "Task brief view model must start with an empty active group"):
		return
	if not T.require_true(self, (groups.get("completed", []) as Array).is_empty(), "Task brief view model must start with an empty completed group"):
		return
	if not T.require_true(self, (panel_state.get("current_task", {}) as Dictionary).is_empty(), "Task brief view model must not invent a current task before selection"):
		return

	var first_task_id := str(((groups.get("available", []) as Array)[0] as Dictionary).get("task_id", ""))
	task_runtime.set_tracked_task(first_task_id)
	panel_state = view_model.build(task_runtime)
	var current_task: Dictionary = panel_state.get("current_task", {})
	if not T.require_true(self, str(current_task.get("task_id", "")) == first_task_id, "Task brief view model current_task must follow the tracked task"):
		return
	if not T.require_true(self, str(current_task.get("objective_text", "")) != "", "Task brief view model must expose formal objective text instead of a raw runtime dump"):
		return

	task_runtime.start_task(first_task_id)
	panel_state = view_model.build(task_runtime)
	current_task = panel_state.get("current_task", {})
	groups = panel_state.get("groups", {})
	if not T.require_true(self, str(current_task.get("status", "")) == "active", "Starting a task must move the current_task view model into active state"):
		return
	if not T.require_true(self, _array_has_task(groups.get("active", []), first_task_id), "Task brief view model active group must include the started task"):
		return

	var objective_slot: Dictionary = task_runtime.get_current_objective_slot(first_task_id)
	task_runtime.complete_objective_slot(str(objective_slot.get("slot_id", "")))
	panel_state = view_model.build(task_runtime)
	groups = panel_state.get("groups", {})
	if not T.require_true(self, _array_has_task(groups.get("completed", []), first_task_id), "Task brief view model completed group must include the finished task"):
		return

	T.pass_and_quit(self)

func _array_has_task(tasks: Variant, task_id: String) -> bool:
	if not (tasks is Array):
		return false
	for task_variant in tasks:
		var task: Dictionary = task_variant
		if str(task.get("task_id", "")) == task_id:
			return true
	return false
