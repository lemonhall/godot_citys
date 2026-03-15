extends RefCounted

var _task_catalog = null
var _task_slot_index = null
var _task_states_by_id: Dictionary = {}
var _active_task_id := ""
var _tracked_task_id := ""

func setup(task_catalog, task_slot_index) -> void:
	_task_catalog = task_catalog
	_task_slot_index = task_slot_index
	_task_states_by_id.clear()
	_active_task_id = ""
	_tracked_task_id = ""
	if _task_catalog == null or not _task_catalog.has_method("get_task_definitions"):
		return
	for definition_variant in _task_catalog.get_task_definitions():
		var definition: Dictionary = definition_variant
		var task_id := str(definition.get("task_id", ""))
		if task_id == "":
			continue
		var status := _sanitize_status(str(definition.get("initial_status", "available")))
		_task_states_by_id[task_id] = {
			"task_id": task_id,
			"status": status,
			"current_objective_index": 0,
		}
		if status == "active" and _active_task_id == "":
			_active_task_id = task_id
	if _active_task_id != "":
		_tracked_task_id = _active_task_id

func get_active_task_id() -> String:
	return _active_task_id

func get_tracked_task_id() -> String:
	return _tracked_task_id

func get_task_state(task_id: String) -> Dictionary:
	if not _task_states_by_id.has(task_id):
		return {}
	return (_task_states_by_id[task_id] as Dictionary).duplicate(true)

func get_task_snapshot(task_id: String) -> Dictionary:
	if _task_catalog == null or not _task_catalog.has_method("get_task_definition"):
		return {}
	var definition: Dictionary = _task_catalog.get_task_definition(task_id)
	if definition.is_empty():
		return {}
	var state := get_task_state(task_id)
	var snapshot := definition.duplicate(true)
	var status := _sanitize_status(str(state.get("status", definition.get("initial_status", "available"))))
	snapshot["status"] = status
	snapshot["active"] = task_id == _active_task_id
	snapshot["tracked"] = task_id == _tracked_task_id
	snapshot["current_objective_slot"] = get_current_objective_slot(task_id)
	snapshot["route_target"] = get_route_target_for_task(task_id)
	return snapshot

func get_tasks_for_status(status: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if _task_catalog == null or not _task_catalog.has_method("get_task_ids"):
		return results
	var resolved_status := _sanitize_status(status)
	for task_id in _task_catalog.get_task_ids():
		var snapshot := get_task_snapshot(task_id)
		if str(snapshot.get("status", "")) == resolved_status:
			results.append(snapshot)
	return results

func get_tracked_task_snapshot() -> Dictionary:
	return get_task_snapshot(_tracked_task_id)

func get_active_task_snapshot() -> Dictionary:
	return get_task_snapshot(_active_task_id)

func set_tracked_task(task_id: String) -> Dictionary:
	if task_id == "":
		_tracked_task_id = ""
		return {}
	if not _task_states_by_id.has(task_id):
		return {}
	_tracked_task_id = task_id
	return get_task_snapshot(task_id)

func start_task(task_id: String) -> Dictionary:
	if not _task_states_by_id.has(task_id):
		return {}
	if _active_task_id != "" and _active_task_id != task_id:
		return {}
	var state: Dictionary = _task_states_by_id[task_id]
	if _sanitize_status(str(state.get("status", "available"))) != "available":
		return {}
	state["status"] = "active"
	state["current_objective_index"] = 0
	_task_states_by_id[task_id] = state
	_active_task_id = task_id
	_tracked_task_id = task_id
	return get_task_snapshot(task_id)

func start_task_from_slot(slot_id: String) -> Dictionary:
	if _task_slot_index == null or not _task_slot_index.has_method("get_slot_by_id"):
		return {}
	var slot: Dictionary = _task_slot_index.get_slot_by_id(slot_id)
	if str(slot.get("slot_kind", "")) != "start":
		return {}
	return start_task(str(slot.get("task_id", "")))

func get_current_objective_slot(task_id: String = "") -> Dictionary:
	var resolved_task_id := task_id if task_id != "" else _active_task_id
	if resolved_task_id == "" or _task_catalog == null or not _task_catalog.has_method("get_task_definition"):
		return {}
	var definition: Dictionary = _task_catalog.get_task_definition(resolved_task_id)
	var state := get_task_state(resolved_task_id)
	if definition.is_empty() or str(state.get("status", "")) != "active":
		return {}
	var objective_slots: Array = definition.get("objective_slots", [])
	var objective_index := int(state.get("current_objective_index", 0))
	if objective_index < 0 or objective_index >= objective_slots.size():
		return {}
	if _task_slot_index == null or not _task_slot_index.has_method("get_slot_by_id"):
		return {}
	return _task_slot_index.get_slot_by_id(str(objective_slots[objective_index]))

func complete_objective_slot(slot_id: String) -> Dictionary:
	if _active_task_id == "":
		return {}
	var current_slot := get_current_objective_slot(_active_task_id)
	if current_slot.is_empty() or str(current_slot.get("slot_id", "")) != slot_id:
		return {}
	var definition: Dictionary = _task_catalog.get_task_definition(_active_task_id)
	var state: Dictionary = _task_states_by_id[_active_task_id]
	var next_index := int(state.get("current_objective_index", 0)) + 1
	var objective_slots: Array = definition.get("objective_slots", [])
	if next_index >= objective_slots.size():
		state["status"] = "completed"
		state["current_objective_index"] = objective_slots.size()
		_task_states_by_id[_active_task_id] = state
		var completed_task_id := _active_task_id
		_active_task_id = ""
		return get_task_snapshot(completed_task_id)
	state["status"] = "active"
	state["current_objective_index"] = next_index
	_task_states_by_id[_active_task_id] = state
	return get_task_snapshot(_active_task_id)

func get_slots_for_rect(rect: Rect2, statuses: Array = [], slot_kinds: Array = []) -> Array[Dictionary]:
	if _task_slot_index == null or not _task_slot_index.has_method("get_slots_intersecting_rect"):
		return []
	var results: Array[Dictionary] = []
	for slot_variant in _task_slot_index.get_slots_intersecting_rect(rect, slot_kinds):
		var slot: Dictionary = slot_variant
		if statuses.is_empty() or statuses.has(get_task_status(str(slot.get("task_id", "")))):
			results.append(slot.duplicate(true))
	return results

func get_slots_for_chunk(chunk_key: Vector2i, statuses: Array = [], slot_kinds: Array = []) -> Array[Dictionary]:
	if _task_slot_index == null or not _task_slot_index.has_method("get_slots_for_chunk"):
		return []
	var results: Array[Dictionary] = []
	for slot_variant in _task_slot_index.get_slots_for_chunk(chunk_key, slot_kinds):
		var slot: Dictionary = slot_variant
		if statuses.is_empty() or statuses.has(get_task_status(str(slot.get("task_id", "")))):
			results.append(slot.duplicate(true))
	return results

func get_route_target_for_task(task_id: String) -> Dictionary:
	if _task_catalog == null or not _task_catalog.has_method("get_task_definition"):
		return {}
	var definition: Dictionary = _task_catalog.get_task_definition(task_id)
	if definition.is_empty() or _task_slot_index == null:
		return {}
	var status := get_task_status(task_id)
	if status == "available":
		var start_slot: Dictionary = _task_slot_index.get_slot_by_id(str(definition.get("start_slot", "")))
		return (start_slot.get("route_target_override", {}) as Dictionary).duplicate(true)
	if status == "active":
		var objective_slot: Dictionary = get_current_objective_slot(task_id)
		return (objective_slot.get("route_target_override", {}) as Dictionary).duplicate(true)
	return {}

func get_task_status(task_id: String) -> String:
	if not _task_states_by_id.has(task_id):
		return ""
	return _sanitize_status(str((_task_states_by_id[task_id] as Dictionary).get("status", "available")))

func get_state_snapshot() -> Dictionary:
	return {
		"task_count": _task_states_by_id.size(),
		"available_count": get_tasks_for_status("available").size(),
		"active_count": get_tasks_for_status("active").size(),
		"completed_count": get_tasks_for_status("completed").size(),
		"active_task_id": _active_task_id,
		"tracked_task_id": _tracked_task_id,
	}

func _sanitize_status(status: String) -> String:
	if status == "active" or status == "completed":
		return status
	return "available"
