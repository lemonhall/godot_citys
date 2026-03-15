extends RefCounted

const CityRouteContract := preload("res://city_game/world/navigation/CityRouteContract.gd")

const TURN_PENALTY_BY_TYPE := {
	"straight": 0.0,
	"slight_left": 6.0,
	"slight_right": 6.0,
	"left": 12.0,
	"right": 12.0,
	"u_turn": 24.0,
	"depart": 0.0,
	"arrive": 0.0,
}

var _config = null
var _road_graph = null
var _vehicle_query = null
var _lane_graph = null
var _nodes_by_id: Dictionary = {}
var _lane_id_to_node_id: Dictionary = {}
var _successors_by_node: Dictionary = {}
var _graph_version := ""

func _init(config = null, world_data: Dictionary = {}) -> void:
	if config != null:
		setup(config, world_data)

func setup(config, world_data: Dictionary = {}) -> void:
	_config = config
	_road_graph = world_data.get("road_graph")
	_vehicle_query = world_data.get("vehicle_query")
	_lane_graph = _vehicle_query.get_lane_graph() if _vehicle_query != null and _vehicle_query.has_method("get_lane_graph") else null
	_build_driving_graph_view()

func get_graph_version() -> String:
	return _graph_version

func get_debug_graph_stats() -> Dictionary:
	var successor_edge_count := 0
	for successor_list_variant in _successors_by_node.values():
		successor_edge_count += (successor_list_variant as Array).size()
	return {
		"node_count": _nodes_by_id.size(),
		"successor_origin_count": _successors_by_node.size(),
		"successor_edge_count": successor_edge_count,
		"graph_version": _graph_version,
	}

func debug_plan_route(origin_target: Dictionary, destination_target: Dictionary) -> Dictionary:
	var origin_anchor: Vector3 = origin_target.get("routable_anchor", origin_target.get("world_anchor", Vector3.ZERO))
	var destination_anchor: Vector3 = destination_target.get("routable_anchor", destination_target.get("world_anchor", Vector3.ZERO))
	var origin_candidates := _collect_route_candidates(origin_anchor)
	var destination_candidates := _collect_route_candidates(destination_anchor)
	var solution := _search_best_solution(origin_candidates, destination_candidates) if not origin_candidates.is_empty() and not destination_candidates.is_empty() else {}
	return {
		"origin_anchor": origin_anchor,
		"destination_anchor": destination_anchor,
		"origin_candidate_count": origin_candidates.size(),
		"destination_candidate_count": destination_candidates.size(),
		"origin_node_ids": _collect_candidate_node_ids(origin_candidates),
		"destination_node_ids": _collect_candidate_node_ids(destination_candidates),
		"solution_found": not solution.is_empty(),
	}

func plan_route(origin_target: Dictionary, destination_target: Dictionary, reroute_generation: int = 0) -> Dictionary:
	if _lane_graph == null:
		return {}
	var origin_anchor: Vector3 = origin_target.get("routable_anchor", origin_target.get("world_anchor", Vector3.ZERO))
	var destination_anchor: Vector3 = destination_target.get("routable_anchor", destination_target.get("world_anchor", Vector3.ZERO))
	var origin_candidates := _collect_route_candidates(origin_anchor)
	var destination_candidates := _collect_route_candidates(destination_anchor)
	if origin_candidates.is_empty() or destination_candidates.is_empty():
		return {}
	var solution := _search_best_solution(origin_candidates, destination_candidates)
	if solution.is_empty():
		return {}
	return _build_route_result(origin_target, destination_target, solution, reroute_generation)

func _build_driving_graph_view() -> void:
	_nodes_by_id.clear()
	_lane_id_to_node_id.clear()
	_successors_by_node.clear()
	if _lane_graph == null:
		_graph_version = ""
		return
	var lanes: Array = _lane_graph.get_lanes() if _lane_graph.has_method("get_lanes") else []
	lanes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("lane_id", "")) < str(b.get("lane_id", ""))
	)
	for lane_variant in lanes:
		var lane: Dictionary = lane_variant
		if str(lane.get("lane_type", "")) != "driving":
			continue
		var lane_id := str(lane.get("lane_id", ""))
		var node_id := _build_node_id(lane)
		if node_id == "":
			continue
		_lane_id_to_node_id[lane_id] = node_id
		if not _nodes_by_id.has(node_id):
			_nodes_by_id[node_id] = _build_node_data(node_id, lane)
	var intersection_contracts: Array = _lane_graph.get_intersection_turn_contracts() if _lane_graph.has_method("get_intersection_turn_contracts") else []
	for contract_variant in intersection_contracts:
		var contract: Dictionary = contract_variant
		var intersection_id := str(contract.get("intersection_id", ""))
		var position_2d: Vector2 = contract.get("position", Vector2.ZERO)
		var world_anchor := Vector3(position_2d.x, 0.0, position_2d.y)
		var seen_keys: Dictionary = {}
		for connection_variant in contract.get("lane_connections", []):
			var connection: Dictionary = connection_variant
			var turn_type := str(connection.get("turn_type", "straight"))
			for from_lane_id_variant in connection.get("from_lane_ids", []):
				var from_lane_id := str(from_lane_id_variant)
				var from_node_id := str(_lane_id_to_node_id.get(from_lane_id, ""))
				if from_node_id == "":
					continue
				for to_lane_id_variant in connection.get("to_lane_ids", []):
					var to_lane_id := str(to_lane_id_variant)
					var to_node_id := str(_lane_id_to_node_id.get(to_lane_id, ""))
					if to_node_id == "":
						continue
					var edge_key := "%s|%s|%s" % [from_node_id, to_node_id, intersection_id]
					if seen_keys.has(edge_key):
						continue
					seen_keys[edge_key] = true
					if not _successors_by_node.has(from_node_id):
						_successors_by_node[from_node_id] = []
					(_successors_by_node[from_node_id] as Array).append({
						"to_node_id": to_node_id,
						"turn_type": turn_type,
						"intersection_id": intersection_id,
						"world_anchor": world_anchor,
						"turn_penalty_m": float(TURN_PENALTY_BY_TYPE.get(turn_type, 8.0)),
					})
	_graph_version = "lane_nodes:%d|turn_contracts:%d" % [_nodes_by_id.size(), intersection_contracts.size()]

func _build_node_id(lane: Dictionary) -> String:
	var road_id := str(lane.get("road_id", ""))
	var direction := str(lane.get("direction", ""))
	if road_id == "" or direction == "":
		return ""
	return "%s:%s" % [road_id, direction]

func _build_node_data(node_id: String, lane: Dictionary) -> Dictionary:
	var edge_id := str(lane.get("edge_id", lane.get("road_id", "")))
	var edge: Dictionary = _road_graph.get_edge_by_id(edge_id) if _road_graph != null and _road_graph.has_method("get_edge_by_id") else {}
	var road_name := str(edge.get("canonical_road_name", edge.get("display_name", edge_id)))
	var points: Array = lane.get("points", [])
	return {
		"node_id": node_id,
		"road_id": str(lane.get("road_id", "")),
		"edge_id": edge_id,
		"direction": str(lane.get("direction", "")),
		"road_name": road_name,
		"representative_lane_id": str(lane.get("lane_id", "")),
		"points": points.duplicate(true),
		"length_m": _polyline_length(points),
		"start_point": points[0] if not points.is_empty() else Vector3.ZERO,
		"end_point": points[points.size() - 1] if not points.is_empty() else Vector3.ZERO,
	}

func _collect_route_candidates(anchor: Vector3, max_count: int = 12) -> Array[Dictionary]:
	var candidates_by_node: Dictionary = {}
	for radius in [192.0, 384.0, 768.0, 1536.0, 3072.0, 6144.0]:
		var rect := Rect2(
			Vector2(anchor.x - radius, anchor.z - radius),
			Vector2(radius * 2.0, radius * 2.0)
		)
		var lanes: Array = _lane_graph.get_lanes_intersecting_rect(rect, ["driving"])
		lanes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("lane_id", "")) < str(b.get("lane_id", ""))
		)
		for lane_variant in lanes:
			var lane: Dictionary = lane_variant
			var candidate := _build_lane_candidate(anchor, lane)
			if candidate.is_empty():
				continue
			var node_id := str(candidate.get("node_id", ""))
			if not candidates_by_node.has(node_id) or float(candidate.get("distance_to_anchor", INF)) < float((candidates_by_node[node_id] as Dictionary).get("distance_to_anchor", INF)):
				candidates_by_node[node_id] = candidate
		if candidates_by_node.size() >= max_count:
			break
	var candidates: Array[Dictionary] = []
	for candidate_variant in candidates_by_node.values():
		candidates.append((candidate_variant as Dictionary).duplicate(true))
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_distance := float(a.get("distance_to_anchor", INF))
		var b_distance := float(b.get("distance_to_anchor", INF))
		if is_equal_approx(a_distance, b_distance):
			return str(a.get("node_id", "")) < str(b.get("node_id", ""))
		return a_distance < b_distance
	)
	if candidates.size() > max_count:
		candidates.resize(max_count)
	return candidates

func _build_lane_candidate(anchor: Vector3, lane: Dictionary) -> Dictionary:
	var lane_id := str(lane.get("lane_id", ""))
	var node_id := str(_lane_id_to_node_id.get(lane_id, ""))
	if lane_id == "" or node_id == "":
		return {}
	var sample := _sample_closest_point_on_polyline(anchor, lane.get("points", []))
	if sample.is_empty():
		return {}
	var node: Dictionary = _nodes_by_id.get(node_id, {})
	return {
		"lane_id": lane_id,
		"node_id": node_id,
		"lane_points": lane.get("points", []).duplicate(true),
		"lane_length_m": _polyline_length(lane.get("points", [])),
		"distance_to_anchor": float(sample.get("distance_to_anchor", INF)),
		"distance_along_m": float(sample.get("distance_along_m", 0.0)),
		"snapped_point": sample.get("world_point", anchor),
		"road_name": str(node.get("road_name", "")),
	}

func _search_best_solution(origin_candidates: Array, destination_candidates: Array) -> Dictionary:
	var destination_by_node: Dictionary = {}
	for candidate_variant in destination_candidates:
		var candidate: Dictionary = candidate_variant
		var node_id := str(candidate.get("node_id", ""))
		if node_id == "":
			continue
		if not destination_by_node.has(node_id) or float(candidate.get("distance_to_anchor", INF)) < float((destination_by_node[node_id] as Dictionary).get("distance_to_anchor", INF)):
			destination_by_node[node_id] = candidate.duplicate(true)

	var frontier: Array[Dictionary] = []
	var best_cost_by_state: Dictionary = {}
	var parent_by_state: Dictionary = {}
	var state_data_by_id: Dictionary = {}
	for origin_variant in origin_candidates:
		var origin: Dictionary = origin_variant
		var state_id := _build_start_state_id(str(origin.get("node_id", "")), str(origin.get("lane_id", "")), float(origin.get("distance_along_m", 0.0)))
		var heuristic := _estimate_heuristic(str(origin.get("node_id", "")), destination_candidates)
		frontier.append({
			"state_id": state_id,
			"node_id": str(origin.get("node_id", "")),
			"entry_offset_m": float(origin.get("distance_along_m", 0.0)),
			"g_cost": 0.0,
			"f_cost": heuristic,
		})
		best_cost_by_state[state_id] = 0.0
		state_data_by_id[state_id] = {
			"node_id": str(origin.get("node_id", "")),
			"entry_offset_m": float(origin.get("distance_along_m", 0.0)),
			"candidate": origin.duplicate(true),
		}

	while not frontier.is_empty():
		var current := _pop_lowest_cost_frontier(frontier)
		var current_state_id := str(current.get("state_id", ""))
		var current_cost := float(current.get("g_cost", INF))
		if current_cost > float(best_cost_by_state.get(current_state_id, INF)) + 0.001:
			continue
		var current_node_id := str(current.get("node_id", ""))
		if destination_by_node.has(current_node_id):
			var destination_candidate: Dictionary = destination_by_node[current_node_id]
			var travel_to_destination := float(destination_candidate.get("distance_along_m", 0.0)) - float(current.get("entry_offset_m", 0.0))
			if travel_to_destination >= -0.5:
				return {
					"goal_state_id": current_state_id,
					"destination_candidate": destination_candidate.duplicate(true),
					"state_data_by_id": state_data_by_id,
					"parent_by_state": parent_by_state,
					"distance_m": current_cost + maxf(travel_to_destination, 0.0),
				}
		var current_node: Dictionary = _nodes_by_id.get(current_node_id, {})
		var traversal_cost := maxf(float(current_node.get("length_m", 0.0)) - float(current.get("entry_offset_m", 0.0)), 0.0)
		for successor_variant in _successors_by_node.get(current_node_id, []):
			var successor: Dictionary = successor_variant
			var next_node_id := str(successor.get("to_node_id", ""))
			if next_node_id == "":
				continue
			var next_state_id := _build_zero_offset_state_id(next_node_id)
			var new_cost := current_cost + traversal_cost + float(successor.get("turn_penalty_m", 0.0))
			if new_cost + 0.001 >= float(best_cost_by_state.get(next_state_id, INF)):
				continue
			best_cost_by_state[next_state_id] = new_cost
			parent_by_state[next_state_id] = {
				"previous_state_id": current_state_id,
				"transition": successor.duplicate(true),
			}
			state_data_by_id[next_state_id] = {
				"node_id": next_node_id,
				"entry_offset_m": 0.0,
			}
			frontier.append({
				"state_id": next_state_id,
				"node_id": next_node_id,
				"entry_offset_m": 0.0,
				"g_cost": new_cost,
				"f_cost": new_cost + _estimate_heuristic(next_node_id, destination_candidates),
			})
	return {}

func _build_route_result(origin_target: Dictionary, destination_target: Dictionary, solution: Dictionary, reroute_generation: int) -> Dictionary:
	var state_data_by_id: Dictionary = solution.get("state_data_by_id", {})
	var parent_by_state: Dictionary = solution.get("parent_by_state", {})
	var goal_state_id := str(solution.get("goal_state_id", ""))
	var destination_candidate: Dictionary = solution.get("destination_candidate", {})
	var state_ids: Array[String] = []
	var transitions_reversed: Array[Dictionary] = []
	var cursor := goal_state_id
	while cursor != "":
		state_ids.append(cursor)
		if not parent_by_state.has(cursor):
			break
		var parent_entry: Dictionary = parent_by_state[cursor]
		transitions_reversed.append((parent_entry.get("transition", {}) as Dictionary).duplicate(true))
		cursor = str(parent_entry.get("previous_state_id", ""))
	state_ids.reverse()
	transitions_reversed.reverse()
	if state_ids.is_empty():
		return {}
	var start_state: Dictionary = state_data_by_id.get(state_ids[0], {})
	var start_candidate: Dictionary = start_state.get("candidate", {})
	var node_sequence: Array[String] = []
	for state_id in state_ids:
		node_sequence.append(str((state_data_by_id.get(state_id, {}) as Dictionary).get("node_id", "")))
	var segment_entries := _build_route_segments(node_sequence, start_candidate, destination_candidate)
	var polyline: Array[Vector3] = segment_entries.get("polyline", [])
	var segments: Array = segment_entries.get("segments", [])
	if polyline.is_empty():
		return {}
	var steps: Array[Dictionary] = []
	for segment_variant in segments:
		var segment: Dictionary = segment_variant
		steps.append(CityRouteContract.build_step(_config, segment.get("target_position", Vector3.ZERO), {
			"road_name": str(segment.get("road_name", "")),
			"lane_node_id": str(segment.get("lane_node_id", "")),
			"distance_m": float(segment.get("distance_m", 0.0)),
		}))
	var maneuvers := _build_maneuvers(segments, transitions_reversed, polyline)
	var origin_target_id := _resolve_target_id(origin_target)
	var destination_target_id := _resolve_target_id(destination_target)
	var total_distance_m := _polyline_length(polyline)
	return {
		"route_id": "%s->%s@%d" % [origin_target_id, destination_target_id, reroute_generation],
		"origin_target_id": origin_target_id,
		"destination_target_id": destination_target_id,
		"snapped_origin": start_candidate.get("snapped_point", polyline[0]),
		"snapped_destination": destination_candidate.get("snapped_point", polyline[polyline.size() - 1]),
		"polyline": polyline.duplicate(true),
		"steps": steps,
		"maneuvers": maneuvers,
		"distance_m": total_distance_m,
		"estimated_time_s": total_distance_m / 18.0,
		"reroute_generation": reroute_generation,
		"source_version": CityRouteContract.SOURCE_VERSION,
		"graph_version": _graph_version,
		"graph_source": "vehicle_lane_graph_view",
	}

func _build_route_segments(node_sequence: Array[String], start_candidate: Dictionary, destination_candidate: Dictionary) -> Dictionary:
	var polyline: Array[Vector3] = []
	var segments: Array[Dictionary] = []
	if node_sequence.size() == 1:
		var direct_points := _sample_polyline_between(
			start_candidate.get("lane_points", []),
			float(start_candidate.get("distance_along_m", 0.0)),
			float(destination_candidate.get("distance_along_m", 0.0))
		)
		_append_polyline_segment(polyline, direct_points)
		segments.append(_build_segment_entry(
			str(start_candidate.get("node_id", "")),
			str(start_candidate.get("road_name", "")),
			polyline[polyline.size() - 1] if not polyline.is_empty() else destination_candidate.get("snapped_point", Vector3.ZERO),
			_polyline_length(direct_points)
		))
		return {
			"polyline": polyline,
			"segments": segments,
		}

	var start_points := _sample_polyline_between(
		start_candidate.get("lane_points", []),
		float(start_candidate.get("distance_along_m", 0.0)),
		float(start_candidate.get("lane_length_m", 0.0))
	)
	_append_polyline_segment(polyline, start_points)
	segments.append(_build_segment_entry(
		str(start_candidate.get("node_id", "")),
		str(start_candidate.get("road_name", "")),
		polyline[polyline.size() - 1],
		_polyline_length(start_points)
	))

	for node_index in range(1, node_sequence.size() - 1):
		var node_id := node_sequence[node_index]
		var node: Dictionary = _nodes_by_id.get(node_id, {})
		var node_points: Array = node.get("points", []).duplicate(true)
		_append_polyline_segment(polyline, node_points)
		segments.append(_build_segment_entry(
			node_id,
			str(node.get("road_name", "")),
			polyline[polyline.size() - 1],
			_polyline_length(node_points)
		))

	var destination_points := _sample_polyline_between(
		destination_candidate.get("lane_points", []),
		0.0,
		float(destination_candidate.get("distance_along_m", 0.0))
	)
	_append_polyline_segment(polyline, destination_points)
	segments.append(_build_segment_entry(
		str(destination_candidate.get("node_id", "")),
		str(destination_candidate.get("road_name", "")),
		polyline[polyline.size() - 1],
		_polyline_length(destination_points)
	))
	return {
		"polyline": polyline,
		"segments": segments,
	}

func _build_segment_entry(node_id: String, road_name: String, target_position: Vector3, distance_m: float) -> Dictionary:
	return {
		"lane_node_id": node_id,
		"road_name": road_name,
		"target_position": target_position,
		"distance_m": distance_m,
	}

func _build_maneuvers(segments: Array, transitions: Array, polyline: Array) -> Array[Dictionary]:
	if segments.is_empty():
		return []
	var maneuvers: Array[Dictionary] = []
	var first_segment: Dictionary = segments[0]
	maneuvers.append(CityRouteContract.build_maneuver(
		"depart",
		float(first_segment.get("distance_m", 0.0)),
		str(first_segment.get("road_name", "")),
		str(first_segment.get("road_name", "")),
		polyline[0],
		"Start on %s" % str(first_segment.get("road_name", "the route"))
	))
	for transition_index in range(transitions.size()):
		var transition: Dictionary = transitions[transition_index]
		var from_segment: Dictionary = segments[transition_index]
		var to_segment: Dictionary = segments[transition_index + 1]
		var turn_type := str(transition.get("turn_type", "straight"))
		var road_name_to := str(to_segment.get("road_name", ""))
		maneuvers.append(CityRouteContract.build_maneuver(
			turn_type,
			float(to_segment.get("distance_m", 0.0)),
			str(from_segment.get("road_name", "")),
			road_name_to,
			transition.get("world_anchor", Vector3.ZERO),
			_format_turn_instruction(turn_type, road_name_to)
		))
	var last_segment: Dictionary = segments[segments.size() - 1]
	maneuvers.append(CityRouteContract.build_maneuver(
		"arrive",
		0.0,
		str(last_segment.get("road_name", "")),
		str(last_segment.get("road_name", "")),
		polyline[polyline.size() - 1],
		"Arrive at destination"
	))
	return maneuvers

func _sample_closest_point_on_polyline(anchor: Vector3, points: Array) -> Dictionary:
	if points.size() < 2:
		return {}
	var best_distance := INF
	var best_world_point := anchor
	var best_distance_along := 0.0
	var traversed := 0.0
	for point_index in range(points.size() - 1):
		var a := points[point_index] as Vector3
		var b := points[point_index + 1] as Vector3
		var segment := b - a
		var segment_length := segment.length()
		if segment_length <= 0.001:
			continue
		var t := clampf((anchor - a).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
		var closest := a + segment * t
		var distance_to_anchor := anchor.distance_to(closest)
		if distance_to_anchor < best_distance:
			best_distance = distance_to_anchor
			best_world_point = closest
			best_distance_along = traversed + segment_length * t
		traversed += segment_length
	return {
		"world_point": best_world_point,
		"distance_to_anchor": best_distance,
		"distance_along_m": best_distance_along,
	}

func _sample_polyline_between(points: Array, start_distance_m: float, end_distance_m: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if points.size() < 2:
		return result
	var clamped_start := maxf(start_distance_m, 0.0)
	var total_length := _polyline_length(points)
	var clamped_end := clampf(end_distance_m, clamped_start, total_length)
	result.append(_sample_point_along_polyline(points, clamped_start))
	var traversed := 0.0
	for point_index in range(points.size() - 1):
		var a := points[point_index] as Vector3
		var b := points[point_index + 1] as Vector3
		var segment_length := a.distance_to(b)
		var segment_start := traversed
		var segment_end := traversed + segment_length
		traversed = segment_end
		if segment_end <= clamped_start + 0.001:
			continue
		if segment_start >= clamped_end - 0.001:
			break
		if segment_end < clamped_end - 0.001:
			result.append(b)
	result.append(_sample_point_along_polyline(points, clamped_end))
	return _dedupe_polyline_points(result)

func _sample_point_along_polyline(points: Array, distance_m: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	if points.size() == 1:
		return points[0]
	var traversed := 0.0
	for point_index in range(points.size() - 1):
		var a := points[point_index] as Vector3
		var b := points[point_index + 1] as Vector3
		var segment_length := a.distance_to(b)
		if traversed + segment_length >= distance_m:
			var t := 0.0 if segment_length <= 0.001 else (distance_m - traversed) / segment_length
			return a.lerp(b, clampf(t, 0.0, 1.0))
		traversed += segment_length
	return points[points.size() - 1]

func _append_polyline_segment(target: Array[Vector3], segment: Array) -> void:
	for point_variant in segment:
		var point: Vector3 = point_variant
		if target.is_empty() or target[target.size() - 1].distance_to(point) > 0.05:
			target.append(point)

func _dedupe_polyline_points(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point in points:
		if result.is_empty() or result[result.size() - 1].distance_to(point) > 0.05:
			result.append(point)
	return result

func _polyline_length(points: Array) -> float:
	if points.size() < 2:
		return 0.0
	var total := 0.0
	for point_index in range(points.size() - 1):
		total += (points[point_index + 1] as Vector3).distance_to(points[point_index] as Vector3)
	return total

func _estimate_heuristic(node_id: String, destination_candidates: Array) -> float:
	if not _nodes_by_id.has(node_id):
		return 0.0
	var node: Dictionary = _nodes_by_id[node_id]
	var node_end: Vector3 = node.get("end_point", Vector3.ZERO)
	var best_distance := INF
	for candidate_variant in destination_candidates:
		var candidate: Dictionary = candidate_variant
		best_distance = minf(best_distance, node_end.distance_to(candidate.get("snapped_point", Vector3.ZERO)))
	return 0.0 if best_distance == INF else best_distance

func _pop_lowest_cost_frontier(frontier: Array[Dictionary]) -> Dictionary:
	var best_index := 0
	var best_score := float((frontier[0] as Dictionary).get("f_cost", INF))
	for index in range(1, frontier.size()):
		var candidate_score := float((frontier[index] as Dictionary).get("f_cost", INF))
		if candidate_score < best_score:
			best_score = candidate_score
			best_index = index
	var best_entry: Dictionary = frontier[best_index]
	frontier.remove_at(best_index)
	return best_entry

func _build_start_state_id(node_id: String, lane_id: String, entry_offset_m: float) -> String:
	return "%s|%s|%d" % [node_id, lane_id, int(round(entry_offset_m * 10.0))]

func _build_zero_offset_state_id(node_id: String) -> String:
	return "%s|full" % node_id

func _resolve_target_id(target: Dictionary) -> String:
	var place_id := str(target.get("place_id", ""))
	if place_id != "":
		return place_id
	var anchor: Vector3 = target.get("routable_anchor", target.get("world_anchor", Vector3.ZERO))
	return "raw:%d:%d:%d" % [int(round(anchor.x)), int(round(anchor.y)), int(round(anchor.z))]

func _format_turn_instruction(turn_type: String, road_name_to: String) -> String:
	match turn_type:
		"left", "slight_left":
			return "Turn left onto %s" % road_name_to
		"right", "slight_right":
			return "Turn right onto %s" % road_name_to
		"u_turn":
			return "Make a U-turn toward %s" % road_name_to
		"straight":
			return "Continue on %s" % road_name_to
	return "Continue toward %s" % road_name_to

func _collect_candidate_node_ids(candidates: Array) -> Array[String]:
	var node_ids: Array[String] = []
	for candidate_variant in candidates:
		node_ids.append(str((candidate_variant as Dictionary).get("node_id", "")))
	return node_ids
