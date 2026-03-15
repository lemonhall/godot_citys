extends RefCounted

func build(task_runtime) -> Dictionary:
	if task_runtime == null or not task_runtime.has_method("get_tasks_for_status"):
		return {}
	var active_items := _build_items(task_runtime.get_tasks_for_status("active"))
	var available_items := _build_items(task_runtime.get_tasks_for_status("available"))
	var completed_items := _build_items(task_runtime.get_tasks_for_status("completed"))
	var tracked_task_id := ""
	if task_runtime.has_method("get_tracked_task_id"):
		tracked_task_id = str(task_runtime.get_tracked_task_id())
	var current_task := {}
	if tracked_task_id != "" and task_runtime.has_method("get_task_snapshot"):
		current_task = _build_item(task_runtime.get_task_snapshot(tracked_task_id))
	elif not active_items.is_empty():
		current_task = active_items[0].duplicate(true)
	return {
		"visible": true,
		"tracked_task_id": tracked_task_id,
		"group_order": ["current_task", "active", "available", "completed"],
		"current_task": current_task,
		"groups": {
			"active": active_items,
			"available": available_items,
			"completed": completed_items,
		},
		"counts": {
			"active": active_items.size(),
			"available": available_items.size(),
			"completed": completed_items.size(),
		},
	}

func _build_items(tasks: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for task_variant in tasks:
		results.append(_build_item(task_variant))
	return results

func _build_item(task_variant: Variant) -> Dictionary:
	if not (task_variant is Dictionary):
		return {}
	var task: Dictionary = task_variant
	var route_target: Dictionary = task.get("route_target", {})
	var status := str(task.get("status", "available"))
	var target_label := str(route_target.get("display_name", ""))
	var objective_text := ""
	match status:
		"active":
			objective_text = "Objective: %s" % target_label
		"available":
			objective_text = "Start: %s" % target_label
		"completed":
			objective_text = "Completed"
	return {
		"task_id": str(task.get("task_id", "")),
		"title": str(task.get("title", "")),
		"summary": str(task.get("summary", "")),
		"status": status,
		"icon_id": str(task.get("icon_id", "")),
		"tracked": bool(task.get("tracked", false)),
		"active": bool(task.get("active", false)),
		"target_label": target_label,
		"objective_text": objective_text,
		"has_route_target": not route_target.is_empty(),
	}
