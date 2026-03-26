extends Node3D

const CityPlayerDroneWingmanScript := preload("res://city_game/combat/drone/CityPlayerDroneWingman.gd")

@export var max_total_count := 10
@export var wingman_side_spacing_m := 5.8
@export var wingman_back_spacing_m := 6.4
@export var wingman_vertical_step_m := 0.18

var _player_owner: Node3D = null
var _leader_runtime: Node3D = null
var _desired_total_count := 0
var _last_action := ""
var _last_reject_reason := ""
var _wingmen: Array[Node3D] = []

func configure(player_owner: Node3D, leader_runtime: Node3D) -> void:
	_player_owner = player_owner
	_leader_runtime = leader_runtime

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
	_clear_wingmen()
	return _build_result(true)

func get_debug_state() -> Dictionary:
	var leader_state := _resolve_leader_system_state()
	var member_world_positions: Array[Vector3] = []
	var slot_world_positions: Array[Vector3] = []
	var leader_position := _resolve_leader_world_position()
	if leader_state != "stowed":
		member_world_positions.append(leader_position)
	for wingman in _wingmen:
		if wingman == null or not is_instance_valid(wingman):
			continue
		member_world_positions.append(wingman.global_position)
	for slot_index in range(_wingmen.size()):
		slot_world_positions.append(_resolve_slot_world_position(slot_index))
	return {
		"desired_total_count": _desired_total_count,
		"active_total_count": _resolve_active_total_count(),
		"wingman_count": _wingmen.size(),
		"max_total_count": max_total_count,
		"leader_system_state": leader_state,
		"leader_world_position": leader_position,
		"member_world_positions": member_world_positions,
		"slot_world_positions": slot_world_positions,
		"last_action": _last_action,
		"last_reject_reason": _last_reject_reason,
	}

func _process(_delta: float) -> void:
	var leader_state := _resolve_leader_system_state()
	if leader_state == "stowed":
		_desired_total_count = 0
		_clear_wingmen()
		return
	var desired_wingman_count := 0
	if leader_state != "stowed":
		desired_wingman_count = clampi(_desired_total_count - 1, 0, max_total_count - 1)
	_sync_wingman_count(desired_wingman_count)
	if _wingmen.is_empty():
		return
	var leader_forward := _resolve_leader_forward()
	for wingman_index in range(_wingmen.size()):
		var wingman := _wingmen[wingman_index]
		if wingman == null or not is_instance_valid(wingman):
			continue
		if wingman.has_method("set_follow_target"):
			wingman.set_follow_target(_resolve_slot_world_position(wingman_index), leader_forward)

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

func _build_result(accepted: bool) -> Dictionary:
	var result := get_debug_state()
	result["accepted"] = accepted
	result["recognized"] = true
	if not accepted:
		result["error"] = _last_reject_reason
	return result
