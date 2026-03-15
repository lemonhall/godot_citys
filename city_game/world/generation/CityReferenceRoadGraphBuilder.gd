extends RefCounted

const CityRoadGraph := preload("res://city_game/world/model/CityRoadGraph.gd")
const CityRoadTemplateCatalog := preload("res://city_game/world/rendering/CityRoadTemplateCatalog.gd")

const SEGMENT_COUNT_LIMIT := 3800
const HIGHWAY_LENGTH_M := 560.0
const ARTERIAL_LENGTH_M := 320.0
const LOCAL_LENGTH_M := 210.0
const SNAP_DISTANCE_M := 72.0
const MIN_INTERSECTION_DEVIATION_DEG := 24.0
const HIGHWAY_BRANCH_PROBABILITY := 0.18
const ARTERIAL_BRANCH_PROBABILITY := 0.38
const LOCAL_BRANCH_PROBABILITY := 0.18
const POPULATION_CENTER_MARGIN_M := 2200.0
const MAIN_CENTER_RADIUS_M := 24500.0
const SATELLITE_CENTER_RADIUS_M := 15000.0
const CORRIDOR_WIDTH_M := 5200.0
const CORRIDOR_SPINE_STEP_SCALE := 0.94
const METRO_SPRAWL_RADIUS_X_M := 33800.0
const METRO_SPRAWL_RADIUS_Y_M := 31200.0
const METRO_SPRAWL_RADIAL_SCALE := 2.56

var _config
var _rng := RandomNumberGenerator.new()
var _growth_stats := {
	"seed_count": 0,
	"non_axis_edge_count": 0,
	"snap_event_count": 0,
	"split_event_count": 0,
}
var _candidate_order := 0
var _population_centers: Array[Dictionary] = []
var _corridors: Array[Dictionary] = []

func build_graph(config) -> CityRoadGraph:
	var road_graph := CityRoadGraph.new()
	build_overlay(config, road_graph)
	return road_graph

func build_overlay(config, road_graph) -> void:
	_config = config
	_rng.seed = int(config.base_seed) ^ 0x5B8D9F1B
	_population_centers = _build_population_centers()
	_corridors = _build_corridors(_population_centers)
	_growth_stats = {
		"seed_count": 0,
		"non_axis_edge_count": 0,
		"snap_event_count": 0,
		"split_event_count": 0,
		"population_center_count": _population_centers.size(),
		"satellite_center_count": maxi(_population_centers.size() - 1, 0),
		"corridor_count": _corridors.size(),
		"population_centers": _population_centers.duplicate(true),
		"corridors": _corridors.duplicate(true),
	}
	_candidate_order = 0

	var accepted: Array[Dictionary] = []
	var pending: Array[Dictionary] = _build_seed_segments()
	_growth_stats["seed_count"] = pending.size()

	while not pending.is_empty() and accepted.size() < SEGMENT_COUNT_LIMIT:
		pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.get("t", 0)) == int(b.get("t", 0)):
				return int(a.get("order", 0)) < int(b.get("order", 0))
			return int(a.get("t", 0)) < int(b.get("t", 0))
		)
		var candidate: Dictionary = pending.pop_front()
		if not _segment_within_world(candidate):
			continue
		var constrained := _apply_local_constraints(candidate, accepted)
		if constrained.is_empty():
			continue
		accepted.append(constrained)
		if _is_non_axis(constrained):
			_growth_stats["non_axis_edge_count"] = int(_growth_stats.get("non_axis_edge_count", 0)) + 1
		for child in _spawn_children(constrained):
			if _segment_within_world(child):
				pending.append(child)

	for index in range(accepted.size()):
		road_graph.add_edge(_segment_to_edge(accepted[index], index))
	road_graph.set_growth_stats(_growth_stats)
	road_graph.set_intersections(_build_intersections(accepted))
	rebuild_runtime_intersections(config, road_graph)

func rebuild_runtime_intersections(config, road_graph) -> void:
	var base_intersections: Array = road_graph.get_intersections_in_rect(config.get_world_bounds())
	road_graph.set_runtime_intersections(_merge_intersection_arrays(base_intersections, _build_endpoint_intersections(road_graph.edges)))

func _merge_intersection_arrays(existing_intersections: Array, incoming_intersections: Array) -> Array[Dictionary]:
	var merged: Dictionary = {}
	for intersection_variant in existing_intersections:
		_merge_intersection_into_map(merged, intersection_variant)
	for intersection_variant in incoming_intersections:
		_merge_intersection_into_map(merged, intersection_variant)
	var intersections: Array[Dictionary] = []
	for key in merged.keys():
		intersections.append((merged[key] as Dictionary).duplicate(true))
	intersections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("intersection_id", "")) < str(b.get("intersection_id", ""))
	)
	return intersections

func _build_seed_segments() -> Array[Dictionary]:
	var seeds: Array[Dictionary] = []
	var seed_keys: Dictionary = {}
	for corridor_variant in _corridors:
		var corridor: Dictionary = corridor_variant
		_append_corridor_spine_seeds(seeds, seed_keys, corridor)

	for center_index in range(_population_centers.size()):
		var center: Dictionary = _population_centers[center_index]
		var center_position: Vector2 = center.get("position", Vector2.ZERO)
		var rotation_deg := _resolve_center_rotation_deg(center_index)
		var center_kind := str(center.get("kind", "satellite"))
		for offset_deg in [0.0, 90.0, 180.0, 270.0]:
			var road_class := "arterial" if center_kind == "main" else "local"
			var segment_length := ARTERIAL_LENGTH_M if center_kind == "main" else LOCAL_LENGTH_M
			_append_seed_candidate(
				seeds,
				seed_keys,
				_make_candidate(center_position, fposmod(rotation_deg + offset_deg, 360.0), segment_length, road_class, false, 2 + center_index)
			)
	return seeds

func _append_corridor_spine_seeds(seeds: Array[Dictionary], seed_keys: Dictionary, corridor: Dictionary) -> void:
	var start: Vector2 = corridor.get("start", Vector2.ZERO)
	var finish: Vector2 = corridor.get("end", Vector2.ZERO)
	var road_class := str(corridor.get("road_class", "arterial"))
	var trunk_highway := road_class == "expressway_elevated"
	var segment_length_m := _segment_length_for_class(road_class)
	var direction := finish - start
	var total_length := direction.length()
	if total_length <= 1.0 or segment_length_m <= 1.0:
		return
	var direction_normalized := direction / total_length
	var step_length := maxf(segment_length_m * CORRIDOR_SPINE_STEP_SCALE, 96.0)
	var step_count := maxi(int(ceil(total_length / step_length)), 1)
	var previous_point := start
	for step_index in range(step_count):
		var traveled := minf(total_length, float(step_index + 1) * step_length)
		var next_point := start + direction_normalized * traveled
		_append_seed_candidate(
			seeds,
			seed_keys,
			_make_candidate_between_points(previous_point, next_point, road_class, trunk_highway, step_index)
		)
		previous_point = next_point
	if previous_point.distance_to(finish) > 1.0:
		_append_seed_candidate(
			seeds,
			seed_keys,
			_make_candidate_between_points(previous_point, finish, road_class, trunk_highway, step_count)
		)

func _make_candidate(start: Vector2, direction_deg: float, length_m: float, road_class: String, highway: bool, t: int) -> Dictionary:
	_candidate_order += 1
	var angle := deg_to_rad(direction_deg)
	var end := start + Vector2(sin(angle), cos(angle)) * length_m
	return {
		"start": start,
		"end": end,
		"direction_deg": direction_deg,
		"road_class": road_class,
		"highway": highway,
		"t": t,
		"order": _candidate_order,
		"severed": false,
		"seed": _rng.randi(),
	}

func _make_candidate_between_points(start: Vector2, finish: Vector2, road_class: String, highway: bool, t: int) -> Dictionary:
	var direction := finish - start
	if direction.length_squared() <= 0.0001:
		return {}
	_candidate_order += 1
	return {
		"start": start,
		"end": finish,
		"direction_deg": _bearing_from_vector(direction.normalized()),
		"road_class": road_class,
		"highway": highway,
		"t": t,
		"order": _candidate_order,
		"severed": false,
		"seed": _rng.randi(),
	}

func _segment_within_world(segment: Dictionary) -> bool:
	var bounds: Rect2 = _config.get_world_bounds()
	return bounds.has_point(segment.get("start", Vector2.ZERO)) and bounds.has_point(segment.get("end", Vector2.ZERO))

func _apply_local_constraints(candidate: Dictionary, accepted: Array[Dictionary]) -> Dictionary:
	var start: Vector2 = candidate.get("start", Vector2.ZERO)
	var end: Vector2 = candidate.get("end", Vector2.ZERO)
	var best_intersection := Vector2.ZERO
	var has_intersection := false
	var best_intersection_distance := INF
	var snap_target := Vector2.ZERO
	var has_snap := false
	var best_snap_distance := INF

	for other in accepted:
		var other_start: Vector2 = other.get("start", Vector2.ZERO)
		var other_end: Vector2 = other.get("end", Vector2.ZERO)
		if start.distance_to(other_start) > 1200.0 and start.distance_to(other_end) > 1200.0:
			continue

		var angle_delta := _min_degree_difference(float(candidate.get("direction_deg", 0.0)), float(other.get("direction_deg", 0.0)))
		var intersection = _segment_intersection(start, end, other_start, other_end)
		if intersection != null:
			var point: Vector2 = intersection
			if angle_delta < MIN_INTERSECTION_DEVIATION_DEG:
				return {}
			var distance_to_start := start.distance_to(point)
			if distance_to_start < best_intersection_distance:
				best_intersection_distance = distance_to_start
				best_intersection = point
				has_intersection = true

		for endpoint in [other_start, other_end]:
			var endpoint_distance := end.distance_to(endpoint)
			if endpoint_distance <= SNAP_DISTANCE_M and endpoint_distance < best_snap_distance:
				best_snap_distance = endpoint_distance
				snap_target = endpoint
				has_snap = true

		var projected := Geometry2D.get_closest_point_to_segment(end, other_start, other_end)
		var projected_distance := end.distance_to(projected)
		if projected_distance <= SNAP_DISTANCE_M and not projected.is_equal_approx(other_start) and not projected.is_equal_approx(other_end):
			if angle_delta < MIN_INTERSECTION_DEVIATION_DEG:
				return {}
			if projected_distance < best_intersection_distance:
				best_intersection_distance = projected_distance
				best_intersection = projected
				has_intersection = true

	if has_intersection:
		var clipped := candidate.duplicate(true)
		clipped["end"] = best_intersection
		clipped["severed"] = true
		_growth_stats["split_event_count"] = int(_growth_stats.get("split_event_count", 0)) + 1
		return clipped
	if has_snap:
		var snapped_candidate := candidate.duplicate(true)
		snapped_candidate["end"] = snap_target
		snapped_candidate["severed"] = true
		_growth_stats["snap_event_count"] = int(_growth_stats.get("snap_event_count", 0)) + 1
		return snapped_candidate
	return candidate

func _spawn_children(segment: Dictionary) -> Array[Dictionary]:
	if bool(segment.get("severed", false)):
		return []
	var children: Array[Dictionary] = []
	var start: Vector2 = segment.get("end", Vector2.ZERO)
	var direction_deg := float(segment.get("direction_deg", 0.0))
	var road_class := str(segment.get("road_class", "local"))
	var straight_direction := direction_deg + _rand_range(-10.0, 10.0)

	match road_class:
		"expressway_elevated":
			children.append(_make_candidate(start, straight_direction, HIGHWAY_LENGTH_M, "expressway_elevated", true, int(segment.get("t", 0)) + 1))
			if _sample_population(start) > 0.42:
				if _rng.randf() < HIGHWAY_BRANCH_PROBABILITY:
					children.append(_make_candidate(start, direction_deg - 90.0 + _rand_range(-7.0, 7.0), ARTERIAL_LENGTH_M, "arterial", false, int(segment.get("t", 0)) + 6))
				if _rng.randf() < HIGHWAY_BRANCH_PROBABILITY:
					children.append(_make_candidate(start, direction_deg + 90.0 + _rand_range(-7.0, 7.0), ARTERIAL_LENGTH_M, "arterial", false, int(segment.get("t", 0)) + 6))
		"arterial":
			if _sample_population(start) > 0.28:
				children.append(_make_candidate(start, straight_direction, ARTERIAL_LENGTH_M, "arterial", false, int(segment.get("t", 0)) + 1))
			if _rng.randf() < ARTERIAL_BRANCH_PROBABILITY:
				children.append(_make_candidate(start, direction_deg - 90.0 + _rand_range(-14.0, 14.0), LOCAL_LENGTH_M, "local", false, int(segment.get("t", 0)) + 1))
			if _rng.randf() < ARTERIAL_BRANCH_PROBABILITY:
				children.append(_make_candidate(start, direction_deg + 90.0 + _rand_range(-14.0, 14.0), LOCAL_LENGTH_M, "local", false, int(segment.get("t", 0)) + 1))
		_:
			if _sample_population(start) > 0.16:
				children.append(_make_candidate(start, direction_deg + _rand_range(-18.0, 18.0), LOCAL_LENGTH_M, "local", false, int(segment.get("t", 0)) + 1))
			if _rng.randf() < LOCAL_BRANCH_PROBABILITY:
				children.append(_make_candidate(start, direction_deg - 90.0 + _rand_range(-20.0, 20.0), LOCAL_LENGTH_M * 0.88, "local", false, int(segment.get("t", 0)) + 1))
	return children

func _sample_population(position: Vector2) -> float:
	var center_bias := 0.0
	for center_variant in _population_centers:
		center_bias += _sample_population_center(position, center_variant)
	var corridor_bias := 0.0
	for corridor_variant in _corridors:
		corridor_bias = maxf(corridor_bias, _sample_corridor_density(position, corridor_variant))
	var metro_sprawl := _sample_main_metro_sprawl(position)
	var wave_a := 0.5 + 0.5 * sin(position.x / 4600.0 + float(_config.base_seed % 97) * 0.01)
	var wave_b := 0.5 + 0.5 * cos(position.y / 5200.0 + float(_config.base_seed % 131) * 0.01)
	var diagonal := 0.5 + 0.5 * sin((position.x + position.y) / 6800.0)
	var noise_bias := (wave_a * 0.44 + wave_b * 0.33 + diagonal * 0.23) * 0.14
	return clampf(center_bias * 0.78 + corridor_bias * 0.34 + metro_sprawl * 0.42 + noise_bias * 0.8, 0.0, 1.0)

func _segment_to_edge(segment: Dictionary, index: int) -> Dictionary:
	var start: Vector2 = segment.get("start", Vector2.ZERO)
	var end: Vector2 = segment.get("end", Vector2.ZERO)
	var direction := (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var jitter_scale := 0.0
	if not bool(segment.get("highway", false)):
		jitter_scale = (sin(float(int(segment.get("seed", 0)) % 4096) * 0.011) * 0.5 + 0.5) * 42.0
	var midpoint := start.lerp(end, 0.5) + normal * jitter_scale
	var road_class := str(segment.get("road_class", "local"))
	var template := CityRoadTemplateCatalog.get_template_for_class(road_class)
	var section_semantics: Dictionary = template.get("section_semantics", {})
	return {
		"edge_id": "ref_road_%05d" % index,
		"road_id": "ref_road_%05d" % index,
		"from": "",
		"to": "",
		"class": road_class,
		"template_id": str(template.get("template_id", "local")),
		"display_name": "Reference %05d" % index,
		"seed": int(segment.get("seed", 0)),
		"width_m": float(template.get("width_m", 11.0)),
		"lane_count_total": int(template.get("lane_count_total", 2)),
		"lane_count_forward": int(template.get("lane_count_forward", 0)),
		"lane_count_backward": int(template.get("lane_count_backward", 0)),
		"lane_count_shared": int(template.get("lane_count_shared", 0)),
		"median_width_m": float(template.get("median_width_m", 0.0)),
		"shoulder_width_m": float(template.get("shoulder_width_m", 0.0)),
		"section_semantics": section_semantics.duplicate(true),
		"points": [start, midpoint, end],
	}

func _build_intersections(accepted: Array[Dictionary]) -> Array[Dictionary]:
	var candidate_points: Dictionary = {}
	for segment in accepted:
		_register_candidate_point(candidate_points, segment.get("start", Vector2.ZERO))
		_register_candidate_point(candidate_points, segment.get("end", Vector2.ZERO))

	for index_a in range(accepted.size()):
		for index_b in range(index_a + 1, accepted.size()):
			var a := accepted[index_a]
			var b := accepted[index_b]
			var intersection = _segment_intersection(a.get("start", Vector2.ZERO), a.get("end", Vector2.ZERO), b.get("start", Vector2.ZERO), b.get("end", Vector2.ZERO))
			if intersection == null:
				continue
			_register_candidate_point(candidate_points, intersection)

	var intersections: Array[Dictionary] = []
	for key in candidate_points.keys():
		var position: Vector2 = candidate_points[key]
		var ordered_branches := _collect_ordered_branches(position, accepted)
		if ordered_branches.size() < 3:
			continue
		intersections.append(_make_intersection_contract(position, ordered_branches, "overlay"))
	return intersections

func _add_node_degree(node_degree: Dictionary, position: Vector2, increment: int) -> void:
	var key := "%d:%d" % [int(round(position.x / 4.0)), int(round(position.y / 4.0))]
	if not node_degree.has(key):
		node_degree[key] = {
			"position": position,
			"degree": 0,
		}
	var entry: Dictionary = node_degree[key]
	entry["degree"] = int(entry.get("degree", 0)) + increment
	node_degree[key] = entry

func _register_candidate_point(candidate_points: Dictionary, position: Vector2) -> void:
	var key := "%d:%d" % [int(round(position.x / 4.0)), int(round(position.y / 4.0))]
	if not candidate_points.has(key):
		candidate_points[key] = position

func _collect_ordered_branches(position: Vector2, accepted: Array[Dictionary]) -> Array[Dictionary]:
	var branch_map: Dictionary = {}
	for segment_index in range(accepted.size()):
		var segment: Dictionary = accepted[segment_index]
		var start: Vector2 = segment.get("start", Vector2.ZERO)
		var end: Vector2 = segment.get("end", Vector2.ZERO)
		var edge_id := "ref_road_%05d" % segment_index
		var road_class := str(segment.get("road_class", "local"))
		var template_id := CityRoadTemplateCatalog.get_template_id_for_class(road_class)
		var start_distance := position.distance_to(start)
		var end_distance := position.distance_to(end)
		var segment_distance := position.distance_to(Geometry2D.get_closest_point_to_segment(position, start, end))

		if start_distance <= 1.5 and end_distance > 1.5:
			_add_branch(branch_map, position, end, edge_id, road_class, template_id, "toward_end")
			continue
		if end_distance <= 1.5 and start_distance > 1.5:
			_add_branch(branch_map, position, start, edge_id, road_class, template_id, "toward_start")
			continue
		if segment_distance <= 1.5 and start_distance > 1.5 and end_distance > 1.5:
			_add_branch(branch_map, position, start, edge_id, road_class, template_id, "through_start")
			_add_branch(branch_map, position, end, edge_id, road_class, template_id, "through_end")
	return _ordered_branches_from_map(branch_map)

func _build_endpoint_intersections(road_edges: Array[Dictionary]) -> Array[Dictionary]:
	var endpoint_nodes: Dictionary = {}
	for edge_variant in road_edges:
		var edge: Dictionary = edge_variant
		var points: Array = edge.get("points", [])
		if points.size() < 2:
			continue
		var road_class := str(edge.get("class", "local"))
		var edge_id := str(edge.get("edge_id", edge.get("road_id", "")))
		var template_id := str(edge.get("template_id", CityRoadTemplateCatalog.get_template_id_for_class(road_class)))
		var start: Vector2 = points[0]
		var end: Vector2 = points[points.size() - 1]
		_register_endpoint_branch(
			endpoint_nodes,
			start,
			_resolve_edge_endpoint_target(points, true),
			edge_id,
			road_class,
			template_id,
			"edge_start"
		)
		_register_endpoint_branch(
			endpoint_nodes,
			end,
			_resolve_edge_endpoint_target(points, false),
			edge_id,
			road_class,
			template_id,
			"edge_end"
		)
	var intersections: Array[Dictionary] = []
	for key in endpoint_nodes.keys():
		var entry: Dictionary = endpoint_nodes[key]
		var position: Vector2 = entry.get("position", Vector2.ZERO)
		var ordered_branches := _ordered_branches_from_map(entry.get("branch_map", {}))
		if ordered_branches.size() < 3:
			continue
		intersections.append(_make_intersection_contract(position, ordered_branches, "endpoint"))
	return intersections

func _register_endpoint_branch(endpoint_nodes: Dictionary, position: Vector2, target: Vector2, edge_id: String, road_class: String, template_id: String, branch_role: String) -> void:
	var key := _intersection_position_key(position)
	if not endpoint_nodes.has(key):
		endpoint_nodes[key] = {
			"position": position,
			"branch_map": {},
		}
	var entry: Dictionary = endpoint_nodes[key]
	var branch_map: Dictionary = entry.get("branch_map", {})
	_add_branch(branch_map, position, target, edge_id, road_class, template_id, branch_role)
	entry["branch_map"] = branch_map
	endpoint_nodes[key] = entry

func _resolve_edge_endpoint_target(points: Array, from_start: bool) -> Vector2:
	if from_start:
		var origin: Vector2 = points[0]
		for point_index in range(1, points.size()):
			var candidate: Vector2 = points[point_index]
			if origin.distance_to(candidate) > 1.5:
				return candidate
		return points[points.size() - 1]
	var origin: Vector2 = points[points.size() - 1]
	for reverse_offset in range(1, points.size()):
		var reverse_index := points.size() - 1 - reverse_offset
		var candidate: Vector2 = points[reverse_index]
		if origin.distance_to(candidate) > 1.5:
			return candidate
	return points[0]

func _ordered_branches_from_map(branch_map: Dictionary) -> Array[Dictionary]:
	var ordered_candidates: Array[Dictionary] = []
	for branch_key in branch_map.keys():
		ordered_candidates.append((branch_map[branch_key] as Dictionary).duplicate(true))
	ordered_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_bearing := float(a.get("bearing_deg", 0.0))
		var b_bearing := float(b.get("bearing_deg", 0.0))
		if absf(a_bearing - b_bearing) <= 0.001:
			var a_edge := str(a.get("edge_id", ""))
			var b_edge := str(b.get("edge_id", ""))
			if a_edge == b_edge:
				return str(a.get("branch_role", "")) < str(b.get("branch_role", ""))
			return a_edge < b_edge
		return a_bearing < b_bearing
	)
	var ordered_branches: Array[Dictionary] = []
	for branch_index in range(ordered_candidates.size()):
		var candidate: Dictionary = ordered_candidates[branch_index]
		ordered_branches.append({
			"branch_index": branch_index,
			"edge_id": str(candidate.get("edge_id", "")),
			"road_class": str(candidate.get("road_class", "")),
			"template_id": str(candidate.get("template_id", "")),
			"bearing_deg": float(candidate.get("bearing_deg", 0.0)),
		})
	return ordered_branches

func _make_intersection_contract(position: Vector2, ordered_branches: Array[Dictionary], topology_source: String = "overlay") -> Dictionary:
	return {
		"intersection_id": "int_%d_%d" % [int(round(position.x)), int(round(position.y))],
		"position": position,
		"degree": ordered_branches.size(),
		"topology_source": topology_source,
		"pedestrian_crossing_candidate": topology_source != "endpoint",
		"intersection_type": _classify_intersection_type(ordered_branches),
		"ordered_branches": ordered_branches,
		"branch_connection_semantics": _build_branch_connection_semantics(ordered_branches),
	}

func _merge_intersection_into_map(intersection_map: Dictionary, intersection: Dictionary) -> void:
	var key := _intersection_position_key(intersection.get("position", Vector2.ZERO))
	if not intersection_map.has(key):
		intersection_map[key] = intersection.duplicate(true)
		return
	intersection_map[key] = _merge_intersection_contracts(intersection_map[key], intersection)

func _merge_intersection_contracts(existing_variant: Variant, incoming_variant: Variant) -> Dictionary:
	var existing: Dictionary = existing_variant
	var incoming: Dictionary = incoming_variant
	var branch_map: Dictionary = {}
	for branch_variant in existing.get("ordered_branches", []):
		_merge_branch_candidate(branch_map, branch_variant)
	for branch_variant in incoming.get("ordered_branches", []):
		_merge_branch_candidate(branch_map, branch_variant)
	var existing_source := str(existing.get("topology_source", "overlay"))
	var incoming_source := str(incoming.get("topology_source", "overlay"))
	var merged_source := existing_source if existing_source == incoming_source else "merged"
	var merged := _make_intersection_contract(existing.get("position", Vector2.ZERO), _ordered_branches_from_map(branch_map), merged_source)
	merged["pedestrian_crossing_candidate"] = bool(existing.get("pedestrian_crossing_candidate", true)) or bool(incoming.get("pedestrian_crossing_candidate", true))
	return merged

func _intersection_position_key(position: Vector2) -> String:
	return "%d:%d" % [int(round(position.x / 4.0)), int(round(position.y / 4.0))]

func _add_branch(branch_map: Dictionary, position: Vector2, target: Vector2, edge_id: String, road_class: String, template_id: String, branch_role: String) -> void:
	var direction := target - position
	if direction.length_squared() <= 0.0001:
		return
	var bearing_deg := _bearing_from_vector(direction.normalized())
	var candidate := {
		"branch_index": -1,
		"edge_id": edge_id,
		"road_class": road_class,
		"template_id": template_id,
		"branch_role": branch_role,
		"bearing_deg": bearing_deg,
		"branch_length_m": direction.length(),
	}
	_merge_branch_candidate(branch_map, candidate)

func _merge_branch_candidate(branch_map: Dictionary, branch_variant: Variant) -> void:
	var candidate: Dictionary = branch_variant
	var bearing_deg := float(candidate.get("bearing_deg", 0.0))
	var branch_key := str(int(posmod(int(round(bearing_deg * 4.0)), 1440)))
	if not branch_map.has(branch_key):
		branch_map[branch_key] = candidate.duplicate(true)
		return
	var existing: Dictionary = branch_map[branch_key]
	if _branch_priority(candidate) > _branch_priority(existing):
		branch_map[branch_key] = candidate.duplicate(true)

func _branch_priority(branch: Dictionary) -> float:
	var road_class := str(branch.get("road_class", "local"))
	var class_priority := 1.0
	match road_class:
		"expressway_elevated":
			class_priority = 4.0
		"arterial":
			class_priority = 3.0
		"service":
			class_priority = 0.5
	return float(branch.get("branch_length_m", 0.0)) + class_priority * 100000.0

func _classify_intersection_type(ordered_branches: Array[Dictionary]) -> String:
	var degree := ordered_branches.size()
	if degree == 3:
		var gap_max := 0.0
		for branch_index in range(ordered_branches.size()):
			var current_bearing := float((ordered_branches[branch_index] as Dictionary).get("bearing_deg", 0.0))
			var next_bearing := float((ordered_branches[(branch_index + 1) % ordered_branches.size()] as Dictionary).get("bearing_deg", 0.0))
			var gap := fposmod(next_bearing - current_bearing, 360.0)
			if branch_index == ordered_branches.size() - 1:
				gap = fposmod(next_bearing + 360.0 - current_bearing, 360.0)
			gap_max = maxf(gap_max, gap)
		return "tee" if gap_max >= 150.0 else "fork"
	if degree == 4:
		return "cross"
	return "multi_way"

func _build_branch_connection_semantics(ordered_branches: Array[Dictionary]) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	for from_index in range(ordered_branches.size()):
		var from_branch: Dictionary = ordered_branches[from_index]
		var inbound_bearing := fposmod(float(from_branch.get("bearing_deg", 0.0)) + 180.0, 360.0)
		for to_index in range(ordered_branches.size()):
			var to_branch: Dictionary = ordered_branches[to_index]
			var to_bearing := float(to_branch.get("bearing_deg", 0.0))
			var turn_delta := fposmod(to_bearing - inbound_bearing, 360.0)
			connections.append({
				"from_branch_index": from_index,
				"to_branch_index": to_index,
				"turn_type": _classify_turn_type(from_index, to_index, turn_delta),
			})
	return connections

func _classify_turn_type(from_branch_index: int, to_branch_index: int, turn_delta: float) -> String:
	if from_branch_index == to_branch_index:
		return "u_turn"
	if turn_delta <= 30.0 or turn_delta >= 330.0:
		return "straight"
	if turn_delta < 180.0:
		return "right_turn"
	return "left_turn"

func _bearing_from_vector(direction: Vector2) -> float:
	var bearing := fposmod(rad_to_deg(atan2(direction.x, direction.y)), 360.0)
	if bearing >= 359.999:
		return 0.0
	return bearing

func _segment_intersection(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2) -> Variant:
	var r := a1 - a0
	var s := b1 - b0
	var denominator := _cross_2d(r, s)
	if absf(denominator) <= 0.0001:
		return null
	var diff := b0 - a0
	var u := _cross_2d(diff, r) / denominator
	var t := _cross_2d(diff, s) / denominator
	if t <= 0.001 or t >= 0.999 or u <= 0.001 or u >= 0.999:
		return null
	return a0 + r * t

func _cross_2d(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x

func _min_degree_difference(a_deg: float, b_deg: float) -> float:
	var diff := fmod(absf(a_deg - b_deg), 360.0)
	if diff > 180.0:
		diff = 360.0 - diff
	return diff

func _width_for_class(road_class: String) -> float:
	return float(CityRoadTemplateCatalog.get_width_for_class(road_class))

func _is_non_axis(segment: Dictionary) -> bool:
	var start: Vector2 = segment.get("start", Vector2.ZERO)
	var end: Vector2 = segment.get("end", Vector2.ZERO)
	var delta := end - start
	if delta.length() <= 0.1:
		return false
	var angle := absf(rad_to_deg(atan2(delta.y, delta.x)))
	angle = fmod(angle, 180.0)
	if angle > 90.0:
		angle = 180.0 - angle
	return angle >= 12.0 and angle <= 78.0

func _rand_range(min_value: float, max_value: float) -> float:
	return lerpf(min_value, max_value, _rng.randf())

func _append_seed_candidate(seeds: Array[Dictionary], seed_keys: Dictionary, candidate: Dictionary) -> void:
	var start: Vector2 = candidate.get("start", Vector2.ZERO)
	var direction_deg := int(round(float(candidate.get("direction_deg", 0.0))))
	var road_class := str(candidate.get("road_class", "local"))
	var key := "%d:%d:%d:%s" % [int(round(start.x / 8.0)), int(round(start.y / 8.0)), posmod(direction_deg, 360), road_class]
	if seed_keys.has(key):
		return
	seed_keys[key] = true
	seeds.append(candidate)

func _build_population_centers() -> Array[Dictionary]:
	var centers: Array[Dictionary] = []
	var main_center_position := Vector2(
		lerpf(-1200.0, 1200.0, _seeded_unit("main_center_x")),
		lerpf(-1100.0, 1100.0, _seeded_unit("main_center_y"))
	)
	centers.append({
		"center_id": "main_core",
		"kind": "main",
		"position": _clamp_center_to_world(main_center_position),
		"radius_m": MAIN_CENTER_RADIUS_M,
		"weight": 1.0,
	})

	var satellite_base_angles := [224.0, 318.0, 44.0, 118.0]
	var satellite_base_distances := [14200.0, 16800.0, 15800.0, 17600.0]
	var satellite_base_weights := [0.78, 0.72, 0.76, 0.7]
	for satellite_index in range(satellite_base_angles.size()):
		var angle_deg: float = float(satellite_base_angles[satellite_index]) + lerpf(-12.0, 12.0, _seeded_unit("satellite_angle_%d" % satellite_index))
		var distance_m: float = float(satellite_base_distances[satellite_index]) + lerpf(-1400.0, 1400.0, _seeded_unit("satellite_distance_%d" % satellite_index))
		var direction := Vector2(sin(deg_to_rad(angle_deg)), cos(deg_to_rad(angle_deg)))
		var satellite_position := _clamp_center_to_world(main_center_position + direction * distance_m)
		centers.append({
			"center_id": "satellite_%d" % satellite_index,
			"kind": "satellite",
			"position": satellite_position,
			"radius_m": SATELLITE_CENTER_RADIUS_M + lerpf(-700.0, 1200.0, _seeded_unit("satellite_radius_%d" % satellite_index)),
			"weight": satellite_base_weights[satellite_index],
			"angle_deg": fposmod(angle_deg, 360.0),
		})
	return centers

func _build_corridors(population_centers: Array[Dictionary]) -> Array[Dictionary]:
	var corridors: Array[Dictionary] = []
	if population_centers.size() <= 1:
		return corridors
	var main_center: Dictionary = population_centers[0]
	var main_position: Vector2 = main_center.get("position", Vector2.ZERO)
	for center_index in range(1, population_centers.size()):
		var satellite_center: Dictionary = population_centers[center_index]
		var satellite_position: Vector2 = satellite_center.get("position", Vector2.ZERO)
		corridors.append({
			"corridor_id": "trunk_corridor_%d" % center_index,
			"corridor_kind": "main_satellite",
			"start": main_position,
			"end": satellite_position,
			"width_m": CORRIDOR_WIDTH_M + center_index * 180.0,
			"weight": 0.86 if center_index <= 2 else 0.74,
			"road_class": "expressway_elevated",
		})
	var satellites: Array[Dictionary] = []
	for center_index in range(1, population_centers.size()):
		satellites.append((population_centers[center_index] as Dictionary).duplicate(true))
	satellites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("angle_deg", 0.0)) < float(b.get("angle_deg", 0.0))
	)
	if satellites.size() >= 3:
		for satellite_index in range(0, satellites.size(), 2):
			var current_satellite: Dictionary = satellites[satellite_index]
			var next_satellite: Dictionary = satellites[(satellite_index + 1) % satellites.size()]
			corridors.append({
				"corridor_id": "ring_corridor_%d" % satellite_index,
				"corridor_kind": "satellite_ring",
				"start": current_satellite.get("position", Vector2.ZERO),
				"end": next_satellite.get("position", Vector2.ZERO),
				"width_m": CORRIDOR_WIDTH_M * 0.72,
				"weight": 0.6,
				"road_class": "arterial",
			})
	return corridors

func _sample_main_metro_sprawl(position: Vector2) -> float:
	if _population_centers.is_empty():
		return 0.0
	var main_center: Dictionary = _population_centers[0]
	var main_position: Vector2 = main_center.get("position", Vector2.ZERO)
	var delta := position - main_position
	var rect_ratio := maxf(
		absf(delta.x) / METRO_SPRAWL_RADIUS_X_M,
		absf(delta.y) / METRO_SPRAWL_RADIUS_Y_M
	)
	var rect_density := clampf(1.0 - rect_ratio, 0.0, 1.0)
	rect_density = _smoothstep01(rect_density)
	var radial_ratio := delta.length() / maxf(MAIN_CENTER_RADIUS_M * METRO_SPRAWL_RADIAL_SCALE, 1.0)
	var radial_density := exp(-radial_ratio * radial_ratio * 0.72)
	var warp_a := 0.5 + 0.5 * sin(delta.x / 6100.0 + delta.y / 8400.0 + float(_config.base_seed % 53) * 0.01)
	var warp_b := 0.5 + 0.5 * cos(delta.y / 5600.0 - delta.x / 7900.0 + float(_config.base_seed % 71) * 0.01)
	var warp := 0.82 + (warp_a * 0.55 + warp_b * 0.45) * 0.18
	return clampf(maxf(rect_density * warp, radial_density * 0.86), 0.0, 1.0)

func _segment_length_for_class(road_class: String) -> float:
	match road_class:
		"expressway_elevated":
			return HIGHWAY_LENGTH_M
		"arterial":
			return ARTERIAL_LENGTH_M
	return LOCAL_LENGTH_M

func _resolve_center_rotation_deg(center_index: int) -> float:
	return lerpf(-22.0, 22.0, _seeded_unit("center_rotation_%d" % center_index)) + center_index * 11.0

func _sample_population_center(position: Vector2, center: Dictionary) -> float:
	var center_position: Vector2 = center.get("position", Vector2.ZERO)
	var radius_m := maxf(float(center.get("radius_m", SATELLITE_CENTER_RADIUS_M)), 1.0)
	var weight := float(center.get("weight", 0.5))
	var distance_ratio := position.distance_to(center_position) / radius_m
	var base_density := exp(-distance_ratio * distance_ratio * 1.45)
	var harmonic := 0.9 + 0.1 * sin((position.x - center_position.x) / (radius_m * 0.48) + (position.y - center_position.y) / (radius_m * 0.63))
	return base_density * harmonic * weight

func _sample_corridor_density(position: Vector2, corridor: Dictionary) -> float:
	var start: Vector2 = corridor.get("start", Vector2.ZERO)
	var finish: Vector2 = corridor.get("end", Vector2.ZERO)
	var closest := Geometry2D.get_closest_point_to_segment(position, start, finish)
	var width_m := maxf(float(corridor.get("width_m", CORRIDOR_WIDTH_M)), 1.0)
	var distance_ratio := position.distance_to(closest) / width_m
	var corridor_density := exp(-distance_ratio * distance_ratio * 2.2)
	var segment_length := maxf(start.distance_to(finish), 1.0)
	var taper := clampf(1.0 - minf(position.distance_to(start), position.distance_to(finish)) / (segment_length * 1.15), 0.35, 1.0)
	return corridor_density * taper * float(corridor.get("weight", 0.7))

func _smoothstep01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _seeded_unit(scope_name: String) -> float:
	return float(int(_config.derive_seed(scope_name)) % 10000) / 9999.0

func _clamp_center_to_world(position: Vector2) -> Vector2:
	var bounds: Rect2 = _config.get_world_bounds()
	return Vector2(
		clampf(position.x, bounds.position.x + POPULATION_CENTER_MARGIN_M, bounds.end.x - POPULATION_CENTER_MARGIN_M),
		clampf(position.y, bounds.position.y + POPULATION_CENTER_MARGIN_M, bounds.end.y - POPULATION_CENTER_MARGIN_M)
	)
