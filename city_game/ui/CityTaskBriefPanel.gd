extends PanelContainer

signal task_selected(task_id: String)

var _panel_state: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_state()

func set_panel_state(panel_state: Dictionary) -> void:
	_panel_state = panel_state.duplicate(true)
	_apply_state()

func get_panel_state() -> Dictionary:
	return _panel_state.duplicate(true)

func select_task(task_id: String) -> void:
	if task_id == "":
		return
	task_selected.emit(task_id)

func _apply_state() -> void:
	var heading := get_node_or_null("Margin/VBox/Heading") as Label
	var meta := get_node_or_null("Margin/VBox/Meta") as Label
	var content := get_node_or_null("Margin/VBox/Content") as Label
	if heading != null:
		heading.text = "Tasks"
	if meta != null:
		var counts: Dictionary = _panel_state.get("counts", {})
		meta.text = "Active %d  Available %d  Completed %d" % [
			int(counts.get("active", 0)),
			int(counts.get("available", 0)),
			int(counts.get("completed", 0)),
		]
	if content != null:
		content.text = _build_content_text()

func _build_content_text() -> String:
	var lines := PackedStringArray()
	var current_task: Dictionary = _panel_state.get("current_task", {})
	if current_task.is_empty():
		lines.append("Tracked: none")
	else:
		lines.append("Tracked: %s" % str(current_task.get("title", "")))
		lines.append(str(current_task.get("objective_text", "")))
		lines.append(str(current_task.get("summary", "")))
	var groups: Dictionary = _panel_state.get("groups", {})
	for group_name in ["active", "available", "completed"]:
		var items: Array = groups.get(group_name, [])
		if items.is_empty():
			continue
		lines.append("")
		lines.append(group_name.capitalize())
		for item_variant in items:
			var item: Dictionary = item_variant
			var prefix := ">" if bool(item.get("tracked", false)) else "-"
			lines.append("%s %s" % [prefix, str(item.get("title", ""))])
	return "\n".join(lines)
