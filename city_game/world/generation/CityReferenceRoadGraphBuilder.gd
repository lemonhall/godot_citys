extends RefCounted

const CityRoadTemplateCatalog := preload("res://city_game/world/rendering/CityRoadTemplateCatalog.gd")

const SEGMENT_COUNT_LIMIT := 2600
const HIGHWAY_LENGTH_M := 420.0
const ARTERIAL_LENGTH_M := 260.0
const LOCAL_LENGTH_M := 170.0
const SNAP_DISTANCE_M := 56.0
const MIN_INTERSECTION_DEVIATION_DEG := 24.0
const HIGHWAY_BRANCH_PROBABILITY := 0.18
const ARTERIAL_BRANCH_PROBABILITY := 0.32
const LOCAL_BRANCH_PROBABILITY := 0.16

var _config
var _rng := RandomNumberGenerator.new()
var _growth_stats := {
	"seed_count": 0,
	"non_axis_edge_count": 0,
	"snap_event_count": 0,
	"split_event_count": 0,
}
var _candidate_order := 0

func build_overlay(config, road_graph) -> void:
	_config = config
	_rng.seed = int(config.base_seed) ^ 0x5B8D9F1B
	_growth_stats = {
		"seed_count": 0,
		"non_axis_edge_count": 0,
		"snap_event_count": 0,
		"split_event_count": 0,
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

func _build_seed_segments() -> Array[Dictionary]:
	var seeds: Array[Dictionary] = []
	var center := Vector2.ZERO
	for direction_deg in [0.0, 90.0, 180.0, 270.0]:
		seeds.append(_make_candidate(center, direction_deg, HIGHWAY_LENGTH_M, "expressway_elevated", true, 0))
	return seeds

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
	var radius_ratio := clampf(position.length() / 22000.0, 0.0, 1.0)
	var center_bias := 1.0 - radius_ratio
	var wave_a := 0.5 + 0.5 * sin(position.x / 4600.0 + float(_config.base_seed % 97) * 0.01)
	var wave_b := 0.5 + 0.5 * cos(position.y / 5200.0 + float(_config.base_seed % 131) * 0.01)
	var diagonal := 0.5 + 0.5 * sin((position.x + position.y) / 6800.0)
	return clampf(center_bias * 0.56 + wave_a * 0.18 + wave_b * 0.16 + diagonal * 0.10, 0.0, 1.0)

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
	var node_degree: Dictionary = {}
	for segment in accepted:
		_add_node_degree(node_degree, segment.get("start", Vector2.ZERO), 1)
		_add_node_degree(node_degree, segment.get("end", Vector2.ZERO), 1)

	for index_a in range(accepted.size()):
		for index_b in range(index_a + 1, accepted.size()):
			var a := accepted[index_a]
			var b := accepted[index_b]
			var intersection = _segment_intersection(a.get("start", Vector2.ZERO), a.get("end", Vector2.ZERO), b.get("start", Vector2.ZERO), b.get("end", Vector2.ZERO))
			if intersection == null:
				continue
			_add_node_degree(node_degree, intersection, 2)

	var intersections: Array[Dictionary] = []
	for key in node_degree.keys():
		var entry: Dictionary = node_degree[key]
		if int(entry.get("degree", 0)) < 3:
			continue
		intersections.append(entry.duplicate(true))
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
