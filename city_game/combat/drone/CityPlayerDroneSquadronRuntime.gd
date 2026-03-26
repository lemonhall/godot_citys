extends Node3D

const CityPlayerDroneWingmanScript := preload("res://city_game/combat/drone/CityPlayerDroneWingman.gd")
const AREA_WAVE_PATTERN := [1, 2, 3]
const ORDER_KIND_SINGLE := "single"
const ORDER_KIND_AREA := "area"
const WAVE_INDEX_NONE := -1
const AREA_TARGET_OFFSETS := [
	Vector3.ZERO,
	Vector3(4.5, 0.0, 0.0),
	Vector3(-4.5, 0.0, 0.0),
	Vector3(0.0, 0.0, 4.5),
	Vector3(0.0, 0.0, -4.5),
	Vector3(7.2, 0.0, 7.2),
	Vector3(-7.2, 0.0, 7.2),
	Vector3(7.2, 0.0, -7.2),
	Vector3(-7.2, 0.0, -7.2),
]

@export var max_total_count := 10
@export var wingman_side_spacing_m := 5.8
@export var wingman_back_spacing_m := 6.4
@export var wingman_vertical_step_m := 0.18
@export var area_strike_radius_m := 12.0
@export var area_wave_interval_sec := 0.6
@export var strike_event_history_limit := 24

var _player_owner: Node3D = null
var _leader_runtime: Node3D = null
var _desired_total_count := 0
var _last_action := ""
var _last_reject_reason := ""
var _wingmen: Array[Node3D] = []
var _elapsed_sec := 0.0
var _pending_area_assignments: Array[Dictionary] = []
var _recent_strike_events: Array[Dictionary] = []
var _next_area_dispatch_time_sec := -1.0

func configure(player_owner: Node3D, leader_runtime: Node3D) -> void:
	_player_owner = player_owner
	_leader_runtime = leader_runtime
	if _leader_runtime != null and is_instance_valid(_leader_runtime) and _leader_runtime.has_method("bind_squadron_runtime"):
		_leader_runtime.bind_squadron_runtime(self)

func request_short_press() -> Dictionary:
	var leader_state := _resolve_leader_system_state()
	if _is_leader_strike_committed():
		_propagate_leader_recover_attempt()
		_last_reject_reason = "strike_committed"
		return _build_result(false)
	if leader_state == "stowed":
		if _leader_runtime == null or not is_instance_valid(_leader_runtime) or not _leader_runtime.has_method("request_deploy"):
			_last_reject_reason = "missing_leader_runtime"
			return _build_result(false)
		var deploy_result := (_leader_runtime.request_deploy() as Dictionary).duplicate(true)
		if not bool(deploy_result.get("accepted", false)):
			_last_reject_reason = str(deploy_result.get("error", "leader_deploy_rejected"))
			return _build_result(false)
		_desired_total_count = 1
		_last_action = "deploy_leader"
		_last_reject_reason = ""
		return _build_result(true)
	if _desired_total_count >= max_total_count:
		_last_reject_reason = "max_total_reached"
		return _build_result(false)
	if leader_state == "recovering":
		_last_reject_reason = "leader_recovering"
		return _build_result(false)
	_desired_total_count = clampi(_desired_total_count + 1, 0, max_total_count)
	_last_action = "add_wingman"
	_last_reject_reason = ""
	return _build_result(true)

func request_recall_all() -> Dictionary:
	var leader_state := _resolve_leader_system_state()
	if _leader_runtime != null and is_instance_valid(_leader_runtime) and _leader_runtime.has_method("request_recover") and leader_state != "stowed":
		var recover_result := (_leader_runtime.request_recover() as Dictionary).duplicate(true)
		if not bool(recover_result.get("accepted", false)):
			_last_reject_reason = str(recover_result.get("error", "leader_recover_rejected"))
			return _build_result(false)
	_desired_total_count = 0
	_last_action = "recall_all"
	_last_reject_reason = ""
	_clear_pending_area_assignments()
	_clear_wingmen()
	return _build_result(true)

func request_single_wingman_strike(target_world_position: Vector3 = Vector3.ZERO) -> Dictionary:
	if _resolve_leader_system_state() != "active":
		_last_reject_reason = "leader_inactive"
		return _build_result(false)
	if not _pending_area_assignments.is_empty():
		_last_reject_reason = "area_order_active"
		return _build_result(false)
	var available_wingman := _claim_next_available_wingman()
	if available_wingman == null:
		_last_reject_reason = _resolve_dispatch_reject_reason()
		return _build_result(false)
	var resolved_target := _resolve_dispatch_target_world_position(target_world_position)
	if resolved_target == Vector3.ZERO:
		_last_reject_reason = "missing_target"
		return _build_result(false)
	if not available_wingman.has_method("begin_strike") or not bool(available_wingman.begin_strike(resolved_target, ORDER_KIND_SINGLE, WAVE_INDEX_NONE)):
		_last_reject_reason = "wingman_rejected"
		return _build_result(false)
	_record_strike_event(available_wingman, ORDER_KIND_SINGLE, WAVE_INDEX_NONE, resolved_target)
	_last_action = "dispatch_single_wingman"
	_last_reject_reason = ""
	return _build_result(true)

func request_area_wingman_strike(target_world_position: Vector3 = Vector3.ZERO) -> Dictionary:
	if _resolve_leader_system_state() != "active":
		_last_reject_reason = "leader_inactive"
		return _build_result(false)
	if not _pending_area_assignments.is_empty():
		_last_reject_reason = "area_order_active"
		return _build_result(false)
	var available_wingmen := _collect_available_wingmen()
	if available_wingmen.is_empty():
		_last_reject_reason = _resolve_dispatch_reject_reason()
		return _build_result(false)
	var center_world_position := _resolve_dispatch_target_world_position(target_world_position)
	if center_world_position == Vector3.ZERO:
		_last_reject_reason = "missing_target"
		return _build_result(false)
	_pending_area_assignments = _build_area_assignments(center_world_position, available_wingmen.size())
	_next_area_dispatch_time_sec = _elapsed_sec
	_dispatch_due_area_wave()
	_last_action = "dispatch_area_wingmen"
	_last_reject_reason = ""
	return _build_result(true)

func get_debug_state() -> Dictionary:
	var leader_state := _resolve_leader_system_state()
	var member_world_positions: Array[Vector3] = []
	var slot_world_positions: Array[Vector3] = []
	var wingman_states: Array[Dictionary] = []
	var leader_position := _resolve_leader_world_position()
	if leader_state != "stowed":
		member_world_positions.append(leader_position)
	var striking_wingman_count := 0
	var resolved_strike_event_count := 0
	for wingman in _wingmen:
		if wingman == null or not is_instance_valid(wingman):
			continue
		member_world_positions.append(wingman.global_position)
		if wingman.has_method("get_debug_state"):
			var wingman_state := (wingman.get_debug_state() as Dictionary).duplicate(true)
			wingman_states.append(wingman_state)
			var state_name := str(wingman_state.get("state", "formation"))
			if state_name == "striking" or state_name == "exploding":
				striking_wingman_count += 1
	for strike_event: Dictionary in _recent_strike_events:
		if bool(strike_event.get("resolved", false)):
			resolved_strike_event_count += 1
	for slot_index in range(_wingmen.size()):
		slot_world_positions.append(_resolve_slot_world_position(slot_index))
	return {
		"desired_total_count": _desired_total_count,
		"active_total_count": _resolve_active_total_count(),
		"wingman_count": _wingmen.size(),
		"striking_wingman_count": striking_wingman_count,
		"available_wingman_count": _collect_available_wingmen().size(),
		"max_total_count": max_total_count,
		"leader_system_state": leader_state,
		"leader_world_position": leader_position,
		"member_world_positions": member_world_positions,
		"slot_world_positions": slot_world_positions,
		"wingman_states": wingman_states,
		"recent_strike_events": _recent_strike_events.duplicate(true),
		"resolved_strike_event_count": resolved_strike_event_count,
		"pending_area_assignment_count": _pending_area_assignments.size(),
		"last_action": _last_action,
		"last_reject_reason": _last_reject_reason,
	}

func _process(delta: float) -> void:
	_elapsed_sec += maxf(delta, 0.0)
	var leader_state := _resolve_leader_system_state()
	if leader_state == "stowed":
		_desired_total_count = 0
		_clear_pending_area_assignments()
		_clear_wingmen()
		return
	var desired_wingman_count := 0
	if leader_state != "stowed":
		desired_wingman_count = clampi(_desired_total_count - 1, 0, max_total_count - 1)
	_sync_wingman_count(desired_wingman_count)
	_dispatch_due_area_wave()
	if _wingmen.is_empty():
		return
	var leader_forward := _resolve_leader_forward()
	for wingman_index in range(_wingmen.size()):
		var wingman := _wingmen[wingman_index]
		if wingman == null or not is_instance_valid(wingman):
			continue
		if wingman.has_method("set_follow_target"):
			wingman.set_follow_target(_resolve_slot_world_position(wingman_index), leader_forward)
	_prune_spent_wingmen()

func _sync_wingman_count(target_count: int) -> void:
	while _wingmen.size() < target_count:
		var slot_index := _wingmen.size()
		var wingman: Node3D = CityPlayerDroneWingmanScript.new()
		wingman.name = "Wingman_%02d" % slot_index
		add_child(wingman)
		var initial_position: Vector3 = _resolve_slot_world_position(slot_index)
		if wingman.has_method("configure"):
			wingman.configure(slot_index, initial_position, _resolve_leader_forward())
		_wingmen.append(wingman)
	while _wingmen.size() > target_count:
		var wingman_to_remove: Node3D = _wingmen.pop_back()
		if wingman_to_remove != null and is_instance_valid(wingman_to_remove):
			wingman_to_remove.queue_free()

func _clear_wingmen() -> void:
	while not _wingmen.is_empty():
		var wingman: Node3D = _wingmen.pop_back()
		if wingman != null and is_instance_valid(wingman):
			wingman.queue_free()

func _clear_pending_area_assignments() -> void:
	_pending_area_assignments.clear()
	_next_area_dispatch_time_sec = -1.0

func _resolve_active_total_count() -> int:
	var leader_count := 1 if _resolve_leader_system_state() != "stowed" else 0
	return leader_count + _wingmen.size()

func _resolve_leader_system_state() -> String:
	if _leader_runtime == null or not is_instance_valid(_leader_runtime):
		return "stowed"
	if _leader_runtime.has_method("get_system_state"):
		return str(_leader_runtime.get_system_state())
	if _leader_runtime.has_method("get_debug_state"):
		return str((_leader_runtime.get_debug_state() as Dictionary).get("system_state", "stowed"))
	return "stowed"

func _resolve_leader_world_position() -> Vector3:
	if _leader_runtime != null and is_instance_valid(_leader_runtime) and _leader_runtime is Node3D:
		return (_leader_runtime as Node3D).global_position
	if _player_owner != null and is_instance_valid(_player_owner):
		return _player_owner.global_position
	return global_position

func _resolve_leader_forward() -> Vector3:
	if _leader_runtime != null and is_instance_valid(_leader_runtime) and _leader_runtime is Node3D:
		var forward := -(_leader_runtime as Node3D).global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.0001:
			return forward.normalized()
	if _player_owner != null and is_instance_valid(_player_owner):
		var player_forward := -_player_owner.global_transform.basis.z
		player_forward.y = 0.0
		if player_forward.length_squared() > 0.0001:
			return player_forward.normalized()
	return Vector3.FORWARD

func _resolve_slot_world_position(slot_index: int) -> Vector3:
	var leader_position := _resolve_leader_world_position()
	var forward := _resolve_leader_forward()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	var row_index := int(slot_index / 2) + 1
	var side_sign := -1.0 if slot_index % 2 == 0 else 1.0
	var side_offset := side_sign * wingman_side_spacing_m * float(row_index)
	var back_offset := wingman_back_spacing_m * float(row_index)
	var height_offset := wingman_vertical_step_m * float((slot_index % 3) - 1)
	return leader_position - forward * back_offset + right * side_offset + Vector3.UP * height_offset

func _is_leader_strike_committed() -> bool:
	if _leader_runtime == null or not is_instance_valid(_leader_runtime) or not _leader_runtime.has_method("get_debug_state"):
		return false
	return bool((_leader_runtime.get_debug_state() as Dictionary).get("strike_committed", false))

func _propagate_leader_recover_attempt() -> void:
	if _leader_runtime == null or not is_instance_valid(_leader_runtime) or not _leader_runtime.has_method("request_recover"):
		return
	_leader_runtime.request_recover()

func _collect_available_wingmen() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for wingman in _wingmen:
		if wingman == null or not is_instance_valid(wingman):
			continue
		if wingman.has_method("is_available_for_strike") and bool(wingman.is_available_for_strike()):
			result.append(wingman)
	return result

func _claim_next_available_wingman() -> Node3D:
	for wingman in _wingmen:
		if wingman == null or not is_instance_valid(wingman):
			continue
		if wingman.has_method("is_available_for_strike") and bool(wingman.is_available_for_strike()):
			return wingman
	return null

func _resolve_dispatch_reject_reason() -> String:
	return "no_wingman_available" if _wingmen.is_empty() else "wingman_busy"

func _resolve_dispatch_target_world_position(target_world_position: Vector3) -> Vector3:
	var resolved_target := target_world_position
	if resolved_target == Vector3.ZERO and _leader_runtime != null and is_instance_valid(_leader_runtime) and _leader_runtime.has_method("get_crosshair_state"):
		resolved_target = (_leader_runtime.get_crosshair_state() as Dictionary).get("world_target", Vector3.ZERO) as Vector3
	if resolved_target == Vector3.ZERO:
		resolved_target = _resolve_leader_world_position() + _resolve_leader_forward() * 120.0
	return _snap_world_position_to_surface(resolved_target)

func _build_area_assignments(center_world_position: Vector3, total_count: int) -> Array[Dictionary]:
	var assignments: Array[Dictionary] = []
	var remaining: int = maxi(total_count, 0)
	var target_index := 0
	var wave_index := 0
	var pattern_index := 0
	while remaining > 0:
		var planned_wave_size: int = mini(int(AREA_WAVE_PATTERN[pattern_index]), remaining)
		for _wave_member_index in range(planned_wave_size):
			assignments.append({
				"order_kind": ORDER_KIND_AREA,
				"wave_index": wave_index,
				"target_world_position": _resolve_area_target_world_position(center_world_position, target_index),
			})
			target_index += 1
		remaining -= planned_wave_size
		wave_index += 1
		pattern_index = (pattern_index + 1) % AREA_WAVE_PATTERN.size()
	return assignments

func _resolve_area_target_world_position(center_world_position: Vector3, target_index: int) -> Vector3:
	var offset: Vector3 = AREA_TARGET_OFFSETS[target_index] if target_index < AREA_TARGET_OFFSETS.size() else AREA_TARGET_OFFSETS[target_index % AREA_TARGET_OFFSETS.size()]
	var clamped_offset: Vector3 = offset
	if Vector2(clamped_offset.x, clamped_offset.z).length() > area_strike_radius_m:
		clamped_offset = clamped_offset.normalized() * area_strike_radius_m
	return _snap_world_position_to_surface(center_world_position + clamped_offset)

func _snap_world_position_to_surface(candidate_world_position: Vector3) -> Vector3:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return candidate_world_position
	var query := PhysicsRayQueryParameters3D.create(
		candidate_world_position + Vector3.UP * 80.0,
		candidate_world_position + Vector3.DOWN * 160.0
	)
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return candidate_world_position
	return hit.get("position", candidate_world_position)

func _dispatch_due_area_wave() -> void:
	if _pending_area_assignments.is_empty():
		return
	if _next_area_dispatch_time_sec >= 0.0 and _elapsed_sec + 0.0001 < _next_area_dispatch_time_sec:
		return
	var current_wave_index := int(_pending_area_assignments[0].get("wave_index", 0))
	while not _pending_area_assignments.is_empty():
		var next_assignment: Dictionary = _pending_area_assignments[0]
		if int(next_assignment.get("wave_index", current_wave_index)) != current_wave_index:
			break
		var wingman := _claim_next_available_wingman()
		if wingman == null:
			_last_reject_reason = _resolve_dispatch_reject_reason()
			return
		_pending_area_assignments.pop_front()
		var target_world_position := next_assignment.get("target_world_position", Vector3.ZERO) as Vector3
		if wingman.has_method("begin_strike") and bool(wingman.begin_strike(target_world_position, ORDER_KIND_AREA, current_wave_index)):
			_record_strike_event(wingman, ORDER_KIND_AREA, current_wave_index, target_world_position)
	if _pending_area_assignments.is_empty():
		_next_area_dispatch_time_sec = -1.0
		return
	_next_area_dispatch_time_sec = _elapsed_sec + area_wave_interval_sec

func _record_strike_event(wingman: Node3D, order_kind: String, wave_index: int, target_world_position: Vector3) -> void:
	var slot_index := -1
	var wingman_state: Dictionary = {}
	if wingman != null and is_instance_valid(wingman):
		wingman_state = _read_wingman_debug_state(wingman)
		if wingman.has_method("get_slot_index"):
			slot_index = int(wingman.get_slot_index())
		elif not wingman_state.is_empty():
			slot_index = int(wingman_state.get("slot_index", -1))
	_recent_strike_events.append({
		"dispatch_time_sec": _elapsed_sec,
		"order_kind": order_kind,
		"wave_index": wave_index,
		"target_world_position": target_world_position,
		"wingman_name": wingman.name if wingman != null and is_instance_valid(wingman) else "",
		"wingman_slot_index": slot_index,
		"path_seed": int(wingman_state.get("path_seed", 0)),
		"planned_lateral_offset_m": float(wingman_state.get("planned_lateral_offset_m", 0.0)),
		"planned_arc_height_m": float(wingman_state.get("planned_arc_height_m", 0.0)),
		"resolved": false,
		"impact_fx_played": false,
		"impact_fx_ring_enabled": false,
		"impact_fx_sphere_enabled": false,
		"impact_audio_trigger_count": 0,
		"impact_audio_stream_path": "",
		"impact_world_position": Vector3.ZERO,
		"min_recorded_speed_scale": 0.0,
		"max_recorded_speed_scale": 0.0,
		"max_recorded_curve_offset_m": 0.0,
		"max_recorded_vertical_offset_m": 0.0,
	})
	while _recent_strike_events.size() > strike_event_history_limit:
		_recent_strike_events.pop_front()

func _prune_spent_wingmen() -> void:
	var active_wingmen: Array[Node3D] = []
	var spent_count := 0
	for wingman in _wingmen:
		if wingman == null or not is_instance_valid(wingman):
			spent_count += 1
			continue
		if wingman.has_method("is_spent") and bool(wingman.is_spent()):
			_hydrate_resolved_strike_event(_read_wingman_debug_state(wingman))
			spent_count += 1
			wingman.queue_free()
			continue
		active_wingmen.append(wingman)
	_wingmen = active_wingmen
	if spent_count <= 0:
		return
	var leader_baseline := 0 if _resolve_leader_system_state() == "stowed" else 1
	_desired_total_count = max(leader_baseline, _desired_total_count - spent_count)

func _read_wingman_debug_state(wingman: Node3D) -> Dictionary:
	if wingman == null or not is_instance_valid(wingman) or not wingman.has_method("get_debug_state"):
		return {}
	return (wingman.get_debug_state() as Dictionary).duplicate(true)

func _hydrate_resolved_strike_event(wingman_state: Dictionary) -> void:
	if wingman_state.is_empty():
		return
	var slot_index := int(wingman_state.get("slot_index", -1))
	if slot_index < 0:
		return
	var strike_result := wingman_state.get("last_strike_result", {}) as Dictionary
	for event_index in range(_recent_strike_events.size() - 1, -1, -1):
		var strike_event := _recent_strike_events[event_index]
		if int(strike_event.get("wingman_slot_index", -1)) != slot_index:
			continue
		if bool(strike_event.get("resolved", false)):
			continue
		strike_event["resolved"] = true
		strike_event["resolved_time_sec"] = _elapsed_sec
		strike_event["path_seed"] = int(wingman_state.get("path_seed", int(strike_event.get("path_seed", 0))))
		strike_event["planned_lateral_offset_m"] = float(wingman_state.get("planned_lateral_offset_m", float(strike_event.get("planned_lateral_offset_m", 0.0))))
		strike_event["planned_arc_height_m"] = float(wingman_state.get("planned_arc_height_m", float(strike_event.get("planned_arc_height_m", 0.0))))
		strike_event["min_recorded_speed_scale"] = float(wingman_state.get("min_recorded_speed_scale", 0.0))
		strike_event["max_recorded_speed_scale"] = float(wingman_state.get("max_recorded_speed_scale", 0.0))
		strike_event["max_recorded_curve_offset_m"] = float(wingman_state.get("max_recorded_curve_offset_m", 0.0))
		strike_event["max_recorded_vertical_offset_m"] = float(wingman_state.get("max_recorded_vertical_offset_m", 0.0))
		strike_event["trigger_kind"] = str(strike_result.get("trigger_kind", ""))
		strike_event["impact_world_position"] = strike_result.get("impact_world_position", Vector3.ZERO) as Vector3
		strike_event["impact_fx_played"] = bool(strike_result.get("impact_fx_played", false))
		strike_event["impact_fx_ring_enabled"] = bool(strike_result.get("impact_fx_ring_enabled", false))
		strike_event["impact_fx_sphere_enabled"] = bool(strike_result.get("impact_fx_sphere_enabled", false))
		strike_event["impact_audio_trigger_count"] = int(strike_result.get("impact_audio_trigger_count", 0))
		strike_event["impact_audio_stream_path"] = str(strike_result.get("impact_audio_stream_path", ""))
		strike_event["last_strike_result"] = strike_result.duplicate(true)
		_recent_strike_events[event_index] = strike_event
		return

func _build_result(accepted: bool) -> Dictionary:
	var result := get_debug_state()
	result["accepted"] = accepted
	result["recognized"] = true
	if not accepted:
		result["error"] = _last_reject_reason
	return result
