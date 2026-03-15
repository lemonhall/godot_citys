extends RefCounted

func build_pins(task_runtime, include_completed: bool = false) -> Array[Dictionary]:
	var pins: Array[Dictionary] = []
	if task_runtime == null or not task_runtime.has_method("get_tasks_for_status"):
		return pins
	for snapshot_variant in task_runtime.get_tasks_for_status("available"):
		var available_pin := _build_pin(snapshot_variant)
		if not available_pin.is_empty():
			pins.append(available_pin)
	for snapshot_variant in task_runtime.get_tasks_for_status("active"):
		var active_pin := _build_pin(snapshot_variant)
		if not active_pin.is_empty():
			pins.append(active_pin)
	if include_completed:
		for snapshot_variant in task_runtime.get_tasks_for_status("completed"):
			var completed_pin := _build_pin(snapshot_variant)
			if not completed_pin.is_empty():
				pins.append(completed_pin)
	pins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := int(a.get("priority", 0))
		var b_priority := int(b.get("priority", 0))
		if a_priority == b_priority:
			return str(a.get("pin_id", "")) < str(b.get("pin_id", ""))
		return a_priority < b_priority
	)
	return pins

func _build_pin(task_variant: Variant) -> Dictionary:
	if not (task_variant is Dictionary):
		return {}
	var task: Dictionary = task_variant
	var route_target: Dictionary = task.get("route_target", {})
	if route_target.is_empty():
		return {}
	var status := str(task.get("status", "available"))
	var pin_type := "task_available"
	var priority := 96
	var visibility_scope := "full_map"
	match status:
		"active":
			pin_type = "task_active"
			priority = 98
			visibility_scope = "all"
		"completed":
			pin_type = "task_completed"
			priority = 94
			visibility_scope = "full_map"
		_:
			visibility_scope = "all" if bool(task.get("tracked", false)) else "full_map"
	return {
		"pin_id": "task_runtime:%s" % str(task.get("task_id", "")),
		"pin_type": pin_type,
		"pin_source": "task_runtime",
		"visibility_scope": visibility_scope,
		"task_id": str(task.get("task_id", "")),
		"status": status,
		"icon_id": str(task.get("icon_id", "")),
		"title": str(task.get("title", "")),
		"subtitle": str(route_target.get("display_name", "")),
		"world_position": route_target.get("world_anchor", Vector3.ZERO),
		"priority": priority,
		"is_selectable": true,
		"route_target_override": route_target.duplicate(true),
	}
