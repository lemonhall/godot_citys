extends RefCounted

var _task_runtime = null
var _contact_slot_ids_by_carrier: Dictionary = {}
var _blocked_start_slot_ids_by_carrier: Dictionary = {}

func setup(task_runtime) -> void:
	_task_runtime = task_runtime
	_contact_slot_ids_by_carrier.clear()
	_blocked_start_slot_ids_by_carrier.clear()

func update(player_world_position: Vector3, vehicle_state: Dictionary = {}, nearby_radius_m: float = 320.0) -> Dictionary:
	var result := {
		"started_task": {},
		"completed_task": {},
		"carrier": "",
	}
	if _task_runtime == null:
		return result
	var carriers := [
		{
			"carrier": "player",
			"position": player_world_position,
		},
	]
	if bool(vehicle_state.get("driving", false)):
		carriers.append({
			"carrier": "vehicle",
			"position": vehicle_state.get("world_position", player_world_position),
		})
	for carrier_variant in carriers:
		var carrier: Dictionary = carrier_variant
		var carrier_id := str(carrier.get("carrier", "player"))
		var position: Vector3 = carrier.get("position", player_world_position)
		var previous_contacts: Dictionary = _contact_slot_ids_by_carrier.get(carrier_id, {})
		var blocked_start_slots: Dictionary = (_blocked_start_slot_ids_by_carrier.get(carrier_id, {}) as Dictionary).duplicate(true)
		var current_contacts: Dictionary = {}
		for slot_variant in _query_available_start_slots(position, nearby_radius_m):
			var slot: Dictionary = slot_variant
			var slot_id := str(slot.get("slot_id", ""))
			if not _is_position_inside_slot(position, slot):
				continue
			current_contacts[slot_id] = true
			if blocked_start_slots.has(slot_id):
				continue
			if not previous_contacts.has(slot_id) and (result.get("started_task", {}) as Dictionary).is_empty():
				var started: Dictionary = _task_runtime.start_task_from_slot(slot_id)
				if not started.is_empty():
					result["started_task"] = started
					result["started_slot"] = slot.duplicate(true)
					result["carrier"] = carrier_id
					blocked_start_slots[slot_id] = true
		var objective_slot: Dictionary = _task_runtime.get_current_objective_slot()
		if not objective_slot.is_empty():
			var objective_slot_id := str(objective_slot.get("slot_id", ""))
			if _is_position_inside_slot(position, objective_slot):
				current_contacts[objective_slot_id] = true
				if not previous_contacts.has(objective_slot_id) and (result.get("completed_task", {}) as Dictionary).is_empty():
					var completed: Dictionary = _task_runtime.complete_objective_slot(objective_slot_id)
					if not completed.is_empty():
						result["completed_task"] = completed
						result["completed_slot"] = objective_slot.duplicate(true)
						result["carrier"] = carrier_id
		_refresh_blocked_start_slots_for_carrier(blocked_start_slots, position)
		_blocked_start_slot_ids_by_carrier[carrier_id] = blocked_start_slots
		_contact_slot_ids_by_carrier[carrier_id] = current_contacts
	return result

func _query_available_start_slots(world_position: Vector3, nearby_radius_m: float) -> Array:
	if _task_runtime == null or not _task_runtime.has_method("get_slots_for_rect"):
		return []
	var rect := Rect2(
		Vector2(world_position.x - nearby_radius_m, world_position.z - nearby_radius_m),
		Vector2.ONE * nearby_radius_m * 2.0
	)
	return _task_runtime.get_slots_for_rect(rect, ["available"], ["start"])

func _is_position_inside_slot(world_position: Vector3, slot: Dictionary) -> bool:
	var anchor: Vector3 = slot.get("world_anchor", Vector3.ZERO)
	var trigger_radius_m := float(slot.get("trigger_radius_m", 0.0))
	return Vector2(world_position.x - anchor.x, world_position.z - anchor.z).length() <= trigger_radius_m

func _refresh_blocked_start_slots_for_carrier(blocked_start_slots: Dictionary, position: Vector3) -> void:
	if blocked_start_slots.is_empty() or _task_runtime == null or not _task_runtime.has_method("get_slot_by_id"):
		return
	var unblock_slot_ids: Array[String] = []
	for slot_id_variant in blocked_start_slots.keys():
		var slot_id := str(slot_id_variant)
		var slot: Dictionary = _task_runtime.get_slot_by_id(slot_id)
		if slot.is_empty() or not _is_position_inside_slot(position, slot):
			unblock_slot_ids.append(slot_id)
	for slot_id in unblock_slot_ids:
		blocked_start_slots.erase(slot_id)
