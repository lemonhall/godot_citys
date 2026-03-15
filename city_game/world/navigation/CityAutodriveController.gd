extends RefCounted

const STATE_INACTIVE := "inactive"
const STATE_ARMED := "armed"
const STATE_FOLLOWING_ROUTE := "following_route"
const STATE_INTERRUPTED := "interrupted"
const STATE_ARRIVED := "arrived"
const STATE_FAILED := "failed"

const WAYPOINT_REACHED_DISTANCE_M := 10.0
const ARRIVAL_DISTANCE_M := 18.0
const ROUTE_DEVIATION_REROUTE_M := 56.0

var _state := STATE_INACTIVE
var _route_result: Dictionary = {}
var _destination_target: Dictionary = {}
var _current_polyline_index := 1
var _failure_reason := ""

func arm(route_result: Dictionary, destination_target: Dictionary = {}) -> Dictionary:
	if (route_result.get("polyline", []) as Array).size() < 2:
		return fail("invalid_route")
	_route_result = route_result.duplicate(true)
	_destination_target = destination_target.duplicate(true)
	_current_polyline_index = 1
	_failure_reason = ""
	_state = STATE_ARMED
	return get_state()

func stop(reason: String = STATE_INTERRUPTED) -> Dictionary:
	match reason:
		STATE_INTERRUPTED, STATE_ARRIVED, STATE_FAILED:
			_state = reason
		_:
			_state = STATE_INACTIVE
	return get_state()

func fail(reason: String) -> Dictionary:
	_failure_reason = reason
	_state = STATE_FAILED
	return get_state()

func accept_reroute(route_result: Dictionary) -> Dictionary:
	return arm(route_result, _destination_target)

func is_active() -> bool:
	return _state == STATE_ARMED or _state == STATE_FOLLOWING_ROUTE

func get_destination_target() -> Dictionary:
	return _destination_target.duplicate(true)

func get_route_result() -> Dictionary:
	return _route_result.duplicate(true)

func get_state() -> Dictionary:
	var polyline_size := (_route_result.get("polyline", []) as Array).size()
	return {
		"state": _state,
		"route_id": str(_route_result.get("route_id", "")),
		"polyline_point_count": polyline_size,
		"current_polyline_index": _current_polyline_index,
		"reroute_generation": int(_route_result.get("reroute_generation", 0)),
		"failure_reason": _failure_reason,
	}

func update(vehicle_state: Dictionary, manual_input_requested: bool) -> Dictionary:
	if manual_input_requested and is_active():
		_state = STATE_INTERRUPTED
		return _build_update_result({"throttle": 0.0, "steer": 0.0, "brake": true}, false)
	if not is_active():
		return _build_update_result({"throttle": 0.0, "steer": 0.0, "brake": false}, false)
	if vehicle_state.is_empty() or not bool(vehicle_state.get("driving", false)):
		return fail("not_driving")

	var polyline: Array = _route_result.get("polyline", [])
	if polyline.size() < 2:
		return fail("invalid_route")
	if _state == STATE_ARMED:
		_state = STATE_FOLLOWING_ROUTE

	var vehicle_position: Vector3 = vehicle_state.get("world_position", Vector3.ZERO)
	_align_polyline_progress(vehicle_position, polyline)
	while _current_polyline_index < polyline.size() - 1:
		var current_waypoint: Vector3 = polyline[_current_polyline_index]
		if vehicle_position.distance_to(current_waypoint) > WAYPOINT_REACHED_DISTANCE_M:
			break
		_current_polyline_index += 1

	var destination_point: Vector3 = polyline[polyline.size() - 1]
	if vehicle_position.distance_to(destination_point) <= ARRIVAL_DISTANCE_M:
		_state = STATE_ARRIVED
		return _build_update_result({"throttle": 0.0, "steer": 0.0, "brake": true}, false)

	var target_index := clampi(_current_polyline_index, 1, polyline.size() - 1)
	var target_point: Vector3 = polyline[target_index]
	var heading: Vector3 = vehicle_state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()

	var to_target := Vector3(target_point.x - vehicle_position.x, 0.0, target_point.z - vehicle_position.z)
	if to_target.length_squared() <= 0.0001:
		to_target = heading
	var desired_direction := to_target.normalized()
	var heading_2d := Vector2(heading.x, heading.z)
	var desired_2d := Vector2(desired_direction.x, desired_direction.z)
	var angle_error := atan2(heading_2d.cross(desired_2d), heading_2d.dot(desired_2d))
	var steer := clampf(-angle_error / deg_to_rad(34.0), -1.0, 1.0)
	var distance_to_target := vehicle_position.distance_to(target_point)
	var throttle := 1.0 if distance_to_target > 24.0 else 0.65
	var brake := absf(angle_error) > deg_to_rad(60.0) and distance_to_target < 20.0
	var request_reroute := _distance_to_route(vehicle_position, polyline, target_index) > ROUTE_DEVIATION_REROUTE_M
	return _build_update_result({
		"throttle": throttle,
		"steer": steer,
		"brake": brake,
	}, request_reroute)

func _distance_to_route(vehicle_position: Vector3, polyline: Array, target_index: int) -> float:
	var vehicle_point := Vector2(vehicle_position.x, vehicle_position.z)
	var min_distance := INF
	var start_index := maxi(target_index - 2, 0)
	var end_index := mini(target_index + 1, polyline.size() - 1)
	for point_index in range(start_index, end_index):
		if point_index >= polyline.size() - 1:
			break
		var a: Vector3 = polyline[point_index]
		var b: Vector3 = polyline[point_index + 1]
		var closest := Geometry2D.get_closest_point_to_segment(vehicle_point, Vector2(a.x, a.z), Vector2(b.x, b.z))
		min_distance = minf(min_distance, vehicle_point.distance_to(closest))
	return 0.0 if min_distance == INF else min_distance

func _align_polyline_progress(vehicle_position: Vector3, polyline: Array) -> void:
	if polyline.size() < 2:
		return
	var nearest_segment_index := _find_nearest_segment_index(vehicle_position, polyline)
	if nearest_segment_index < 0:
		return
	_current_polyline_index = clampi(maxi(_current_polyline_index, nearest_segment_index + 1), 1, polyline.size() - 1)

func _find_nearest_segment_index(vehicle_position: Vector3, polyline: Array) -> int:
	var vehicle_point := Vector2(vehicle_position.x, vehicle_position.z)
	var nearest_segment_index := -1
	var nearest_distance := INF
	for point_index in range(polyline.size() - 1):
		var a: Vector3 = polyline[point_index]
		var b: Vector3 = polyline[point_index + 1]
		var closest := Geometry2D.get_closest_point_to_segment(vehicle_point, Vector2(a.x, a.z), Vector2(b.x, b.z))
		var distance := vehicle_point.distance_to(closest)
		if distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_segment_index = point_index
	return nearest_segment_index

func _build_update_result(control: Dictionary, request_reroute: bool) -> Dictionary:
	var state := get_state()
	state["control"] = control.duplicate(true)
	state["request_reroute"] = request_reroute and _state == STATE_FOLLOWING_ROUTE
	return state
