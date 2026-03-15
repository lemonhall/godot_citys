extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var projection_script := load("res://city_game/world/tasks/presentation/CityTaskPinProjection.gd")
	if config_script == null or generator_script == null or projection_script == null:
		T.fail_and_quit(self, "Task pin projection test requires CityWorldConfig, CityWorldGenerator, and CityTaskPinProjection")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)
	var task_runtime = world_data.get("task_runtime")
	var projection = projection_script.new()
	var projected_pins: Array = projection.build_pins(task_runtime)
	if not T.require_true(self, projected_pins.size() >= 3, "Task pin projection must emit formal available task pins for the full map"):
		return
	var first_available := _find_pin_for_status(projected_pins, "available")
	if not T.require_true(self, not first_available.is_empty(), "Task pin projection must emit an available task pin status"):
		return
	for required_key in ["pin_id", "pin_type", "task_id", "status", "icon_id", "title", "world_position", "priority", "route_target_override", "visibility_scope"]:
		if not T.require_true(self, first_available.has(required_key), "Projected task pin must expose %s" % required_key):
			return
	if not T.require_true(self, str(first_available.get("pin_type", "")) == "task_available", "Available task pins must publish the task_available visual contract"):
		return
	if not T.require_true(self, str(first_available.get("visibility_scope", "")) == "full_map", "Untracked available task pins must stay full_map only instead of polluting the idle minimap"):
		return

	var available_tasks: Array = task_runtime.get_tasks_for_status("available")
	var first_task_id := str((available_tasks[0] as Dictionary).get("task_id", ""))
	task_runtime.set_tracked_task(first_task_id)
	projected_pins = projection.build_pins(task_runtime)
	var tracked_available := _find_pin_by_task(projected_pins, first_task_id)
	if not T.require_true(self, str(tracked_available.get("visibility_scope", "")) == "all", "Tracked available task pins must become visible to the minimap without opening a second pin system"):
		return

	task_runtime.start_task(first_task_id)
	projected_pins = projection.build_pins(task_runtime)
	var active_pin := _find_pin_for_status(projected_pins, "active")
	if not T.require_true(self, not active_pin.is_empty(), "Starting a task must project an active task pin"):
		return
	if not T.require_true(self, str(active_pin.get("pin_type", "")) == "task_active", "Active task pins must publish the task_active visual contract"):
		return
	if not T.require_true(self, str(active_pin.get("visibility_scope", "")) == "all", "Active task pins must stay visible to both full map and minimap consumers"):
		return

	T.pass_and_quit(self)

func _find_pin_for_status(pins: Array, status: String) -> Dictionary:
	for pin_variant in pins:
		var pin: Dictionary = pin_variant
		if str(pin.get("status", "")) == status:
			return pin
	return {}

func _find_pin_by_task(pins: Array, task_id: String) -> Dictionary:
	for pin_variant in pins:
		var pin: Dictionary = pin_variant
		if str(pin.get("task_id", "")) == task_id:
			return pin
	return {}
