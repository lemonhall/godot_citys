extends RefCounted

const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

const LANE_SAMPLE_STEP_M := 24.0
const SECONDARY_SPACING_M := 160.0
const QUERY_MARGIN_M := 56.0

static func build_chunk_roads(chunk_data: Dictionary) -> Dictionary:
	var chunk_center: Vector3 = chunk_data.get("chunk_center", Vector3.ZERO)
	var chunk_size_m := float(chunk_data.get("chunk_size_m", 256.0))
	var world_seed := int(chunk_data.get("world_seed", chunk_data.get("chunk_seed", 0)))
	var half_size := chunk_size_m * 0.5
	var rect := Rect2(
		Vector2(chunk_center.x - half_size, chunk_center.z - half_size),
		Vector2(chunk_size_m, chunk_size_m)
	)
	var expanded_rect := rect.grow(QUERY_MARGIN_M)

	var segments: Array[Dictionary] = []
	var road_graph = chunk_data.get("road_graph")
	if road_graph != null and road_graph.has_method("get_edges_intersecting_rect"):
		for edge in road_graph.get_edges_intersecting_rect(expanded_rect, ["arterial"]):
			var points_2d: Array = edge.get("points", [])
			if points_2d.size() < 2:
				continue
			segments.append({
				"class": str(edge.get("class", "arterial")),
				"width": float(edge.get("width_m", 20.0)),
				"points": _vector2_polyline_to_local_points(points_2d, chunk_center, world_seed),
			})

	segments.append_array(_build_secondary_family(chunk_center, chunk_size_m, world_seed, true))
	segments.append_array(_build_secondary_family(chunk_center, chunk_size_m, world_seed, false))

	var connectors := {
		"north": [],
		"south": [],
		"east": [],
		"west": [],
	}
	var curved_segment_count := 0
	for segment in segments:
		var points: Array = segment.get("points", [])
		_accumulate_connectors(connectors, points, half_size)
		if _is_curved(points):
			curved_segment_count += 1

	for side in connectors.keys():
		var values: Array = connectors[side]
		values.sort()
		connectors[side] = values

	return {
		"segments": segments,
		"connectors": connectors,
		"curved_segment_count": curved_segment_count,
		"signature": _build_signature(connectors, curved_segment_count, segments.size()),
	}

static func _build_secondary_family(chunk_center: Vector3, chunk_size_m: float, world_seed: int, vertical: bool) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var half_size := chunk_size_m * 0.5
	var min_primary := (chunk_center.x if vertical else chunk_center.z) - half_size - QUERY_MARGIN_M
	var max_primary := (chunk_center.x if vertical else chunk_center.z) + half_size + QUERY_MARGIN_M
	var lane_min := int(floor(min_primary / SECONDARY_SPACING_M)) - 1
	var lane_max := int(ceil(max_primary / SECONDARY_SPACING_M)) + 1

	for lane_index in range(lane_min, lane_max + 1):
		var width := 12.0 if abs(lane_index) % 4 == 0 else 9.0
		var points: Array[Vector3] = []
		var min_secondary := (chunk_center.z if vertical else chunk_center.x) - half_size - QUERY_MARGIN_M
		var max_secondary := (chunk_center.z if vertical else chunk_center.x) + half_size + QUERY_MARGIN_M
		var sample_cursor := min_secondary
		while sample_cursor <= max_secondary + 0.01:
			var point := _sample_lane_point(lane_index, sample_cursor, vertical, world_seed)
			points.append(Vector3(point.x - chunk_center.x, point.y, point.z - chunk_center.z))
			sample_cursor += LANE_SAMPLE_STEP_M
		if _polyline_intersects_chunk(points, half_size):
			segments.append({
				"class": "secondary",
				"width": width,
				"points": points,
			})
	return segments

static func _sample_lane_point(lane_index: int, along: float, vertical: bool, world_seed: int) -> Vector3:
	var lane_base := float(lane_index) * SECONDARY_SPACING_M + _lane_offset(lane_index, world_seed, vertical)
	var curve := _lane_curve(along, lane_index, world_seed, vertical)
	var world_x := lane_base + curve if vertical else along
	var world_z := along if vertical else lane_base + curve
	return CityTerrainSampler.sample_world_point(world_x, world_z, world_seed)

static func _lane_offset(lane_index: int, world_seed: int, vertical: bool) -> float:
	var scope_bias := 0.37 if vertical else 0.59
	return sin(float(lane_index) * 0.73 + float(world_seed & 255) * 0.01 + scope_bias) * 18.0

static func _lane_curve(along: float, lane_index: int, world_seed: int, vertical: bool) -> float:
	var primary_scale := 460.0 + float((world_seed >> 4) % 120)
	var secondary_scale := 780.0 + float((world_seed >> 6) % 180)
	var scope_bias := 0.21 if vertical else 0.49
	return sin(along / primary_scale + float(lane_index) * 0.42 + scope_bias) * 24.0 + cos(along / secondary_scale + float(lane_index) * 0.11 + scope_bias) * 10.0

static func _vector2_polyline_to_local_points(points_2d: Array, chunk_center: Vector3, world_seed: int) -> Array[Vector3]:
	var local_points: Array[Vector3] = []
	for point in points_2d:
		var world_point: Vector2 = point
		local_points.append(Vector3(
			world_point.x - chunk_center.x,
			CityTerrainSampler.sample_height(world_point.x, world_point.y, world_seed),
			world_point.y - chunk_center.z
		))
	return local_points

static func _polyline_intersects_chunk(points: Array, half_size: float) -> bool:
	for point in points:
		var local_point: Vector3 = point
		if absf(local_point.x) <= half_size + QUERY_MARGIN_M and absf(local_point.z) <= half_size + QUERY_MARGIN_M:
			return true
	return false

static func _accumulate_connectors(connectors: Dictionary, points: Array, half_size: float) -> void:
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		_append_crossing(connectors["west"], _intersect_vertical_boundary(a, b, -half_size))
		_append_crossing(connectors["east"], _intersect_vertical_boundary(a, b, half_size))
		_append_crossing(connectors["north"], _intersect_horizontal_boundary(a, b, -half_size))
		_append_crossing(connectors["south"], _intersect_horizontal_boundary(a, b, half_size))

static func _intersect_vertical_boundary(a: Vector3, b: Vector3, boundary_x: float) -> Variant:
	if (a.x - boundary_x) * (b.x - boundary_x) > 0.0 or is_equal_approx(a.x, b.x):
		return null
	var t := (boundary_x - a.x) / (b.x - a.x)
	if t < 0.0 or t > 1.0:
		return null
	return snappedf(lerpf(a.z, b.z, t), 0.01)

static func _intersect_horizontal_boundary(a: Vector3, b: Vector3, boundary_z: float) -> Variant:
	if (a.z - boundary_z) * (b.z - boundary_z) > 0.0 or is_equal_approx(a.z, b.z):
		return null
	var t := (boundary_z - a.z) / (b.z - a.z)
	if t < 0.0 or t > 1.0:
		return null
	return snappedf(lerpf(a.x, b.x, t), 0.01)

static func _append_crossing(values: Array, crossing: Variant) -> void:
	if crossing == null:
		return
	var connector := float(crossing)
	for existing in values:
		if absf(float(existing) - connector) <= 0.05:
			return
	values.append(connector)

static func _is_curved(points: Array) -> bool:
	if points.size() < 3:
		return false
	var start: Vector3 = points[0]
	var finish: Vector3 = points[-1]
	var baseline := Vector2(finish.x - start.x, finish.z - start.z)
	if baseline.length() <= 0.01:
		return false
	var baseline_dir := baseline.normalized()
	var max_offset := 0.0
	for point_index in range(1, points.size() - 1):
		var point: Vector3 = points[point_index]
		var relative := Vector2(point.x - start.x, point.z - start.z)
		var projection := baseline_dir * relative.dot(baseline_dir)
		max_offset = maxf(max_offset, (relative - projection).length())
	return max_offset >= 0.5

static func _build_signature(connectors: Dictionary, curved_segment_count: int, segment_count: int) -> String:
	var parts := PackedStringArray([
		"segments=%d" % segment_count,
		"curved=%d" % curved_segment_count,
	])
	for side in ["north", "south", "east", "west"]:
		var values: Array = connectors.get(side, [])
		parts.append("%s:%s" % [side, ",".join(_to_string_array(values))])
	return "|".join(parts)

static func _to_string_array(values: Array) -> PackedStringArray:
	var strings := PackedStringArray()
	for value in values:
		strings.append("%.2f" % float(value))
	return strings
