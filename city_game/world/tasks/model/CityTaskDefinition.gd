extends RefCounted

const VALID_STATUSES := {
	"available": true,
	"active": true,
	"completed": true,
}

var _data: Dictionary = {}

func setup(definition_data: Dictionary) -> void:
	var task_id := str(definition_data.get("task_id", ""))
	if task_id == "":
		_data.clear()
		return
	var objective_slots: Array[String] = []
	for slot_id_variant in definition_data.get("objective_slots", []):
		var slot_id := str(slot_id_variant)
		if slot_id != "":
			objective_slots.append(slot_id)
	_data = {
		"task_id": task_id,
		"title": str(definition_data.get("title", task_id)),
		"summary": str(definition_data.get("summary", "")),
		"icon_id": str(definition_data.get("icon_id", "task")),
		"initial_status": _sanitize_status(str(definition_data.get("initial_status", "available"))),
		"start_slot": str(definition_data.get("start_slot", "")),
		"objective_slots": objective_slots,
		"auto_track_on_start": bool(definition_data.get("auto_track_on_start", true)),
		"completion_mode": "event" if str(definition_data.get("completion_mode", "")) == "event" else "slot",
		"completion_event_id": str(definition_data.get("completion_event_id", "")),
		"repeatable": bool(definition_data.get("repeatable", false)),
		"reset_to_available_after_closeout": bool(definition_data.get("reset_to_available_after_closeout", false)),
	}

func is_valid() -> bool:
	return not _data.is_empty()

func to_dict() -> Dictionary:
	return _data.duplicate(true)

func get_task_id() -> String:
	return str(_data.get("task_id", ""))

func get_initial_status() -> String:
	return str(_data.get("initial_status", "available"))

func get_start_slot_id() -> String:
	return str(_data.get("start_slot", ""))

func get_objective_slot_ids() -> Array[String]:
	var results: Array[String] = []
	for slot_id_variant in _data.get("objective_slots", []):
		results.append(str(slot_id_variant))
	return results

func _sanitize_status(status: String) -> String:
	return status if VALID_STATUSES.has(status) else "available"
