extends RefCounted

const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

const QUERY_MARGIN_M := 56.0
const LOCAL_CELL_SIZE_M := 320.0
const LOCAL_CELL_MARGIN_M := 96.0
const LOCAL_ROAD_WIDTH_M := 8.0
const LOCAL_ARC_WIDTH_M := 6.5

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
		for edge in road_graph.get_edges_intersecting_rect(expanded_rect):
			var points_2d: Array = edge.get("points", [])
			if points_2d.size() < 2:
				continue
			var local_points := _vector2_polyline_to_local_points(points_2d, chunk_center, world_seed)
			if not _polyline_intersects_chunk(local_points, half_size):
				continue
			segments.append(_make_segment(
				str(edge.get("class", "arterial")),
				float(edge.get("width_m", 20.0)),
				local_points,
				chunk_center,
				world_seed
			))

	segments.append_array(_build_local_cell_roads(expanded_rect.grow(LOCAL_CELL_MARGIN_M), chunk_center, half_size, world_seed))

	var connectors := {
		"north": [],
		"south": [],
		"east": [],
		"west": [],
	}
	var curved_segment_count := 0
	var non_axis_road_segment_count := 0
	var bridge_count := 0
	for segment in segments:
		var points: Array = segment.get("points", [])
		_accumulate_connectors(connectors, points, half_size)
		if _is_curved(points):
			curved_segment_count += 1
		if _is_non_axis(points):
			non_axis_road_segment_count += 1
		if bool(segment.get("bridge", false)):
			bridge_count += 1

	for side in connectors.keys():
		var values: Array = connectors[side]
		values.sort()
		connectors[side] = values

	return {
		"segments": segments,
		"connectors": connectors,
		"curved_segment_count": curved_segment_count,
		"non_axis_road_segment_count": non_axis_road_segment_count,
		"bridge_count": bridge_count,
		"road_mesh_mode": "ribbon",
		"signature": _build_signature(connectors, curved_segment_count, segments.size(), non_axis_road_segment_count, bridge_count),
	}

static func _build_local_cell_roads(expanded_rect: Rect2, chunk_center: Vector3, half_size: float, world_seed: int) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var origin := _get_local_grid_origin(world_seed)
	var min_cell_x := int(floor((expanded_rect.position.x - origin.x) / LOCAL_CELL_SIZE_M)) - 1
	var max_cell_x := int(ceil((expanded_rect.end.x - origin.x) / LOCAL_CELL_SIZE_M)) + 1
	var min_cell_y := int(floor((expanded_rect.position.y - origin.y) / LOCAL_CELL_SIZE_M)) - 1
	var max_cell_y := int(ceil((expanded_rect.end.y - origin.y) / LOCAL_CELL_SIZE_M)) + 1

	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var cell_key := Vector2i(cell_x, cell_y)
			var cell_min := origin + Vector2(float(cell_x) * LOCAL_CELL_SIZE_M, float(cell_y) * LOCAL_CELL_SIZE_M)
			var hub := _build_local_cell_hub(cell_key, cell_min, world_seed)
			var portals := {
				"west": _build_local_cell_portal(cell_key, cell_min, "west", world_seed),
				"east": _build_local_cell_portal(cell_key, cell_min, "east", world_seed),
				"north": _build_local_cell_portal(cell_key, cell_min, "north", world_seed),
				"south": _build_local_cell_portal(cell_key, cell_min, "south", world_seed),
			}
			for side in portals.keys():
				var spoke_points_2d := _build_local_spoke_points(portals[side], hub, side, _cell_seed(world_seed, "local_spoke_%s" % side, cell_key))
				var local_points := _vector2_polyline_to_local_points(spoke_points_2d, chunk_center, world_seed)
				if _polyline_intersects_chunk(local_points, half_size):
					segments.append(_make_segment("local", LOCAL_ROAD_WIDTH_M, local_points, chunk_center, world_seed))

			var arc_points_2d := _build_local_arc_points(portals, hub, cell_key, world_seed)
			var arc_points := _vector2_polyline_to_local_points(arc_points_2d, chunk_center, world_seed)
			if _polyline_intersects_chunk(arc_points, half_size):
				segments.append(_make_segment("local", LOCAL_ARC_WIDTH_M, arc_points, chunk_center, world_seed))
	return segments

static func _make_segment(road_class: String, width: float, local_points: Array[Vector3], chunk_center: Vector3, world_seed: int) -> Dictionary:
	var segment := {
		"class": road_class,
		"width": width,
		"points": local_points,
		"bridge": false,
		"bridge_height_m": 0.0,
	}
	if _should_raise_bridge(road_class, local_points, chunk_center, world_seed):
		var bridge_height := 6.0 if road_class == "arterial" else 4.5
		segment["bridge"] = true
		segment["bridge_height_m"] = bridge_height
		segment["points"] = _apply_bridge_profile(local_points, bridge_height)
	return segment

static func _get_local_grid_origin(world_seed: int) -> Vector2:
	return Vector2(
		64.0 + float((world_seed >> 3) % 79),
		-96.0 + float((world_seed >> 5) % 87)
	)

static func _build_local_cell_hub(cell_key: Vector2i, cell_min: Vector2, world_seed: int) -> Vector2:
	var hub_seed := _cell_seed(world_seed, "local_hub", cell_key)
	var center := cell_min + Vector2.ONE * LOCAL_CELL_SIZE_M * 0.5
	var jitter_x := sin(float(hub_seed % 4096) * 0.013) * 68.0
	var jitter_y := cos(float((hub_seed >> 2) % 4096) * 0.015) * 64.0
	return center + Vector2(jitter_x, jitter_y)

static func _build_local_cell_portal(cell_key: Vector2i, cell_min: Vector2, side: String, world_seed: int) -> Vector2:
	var cell_max := cell_min + Vector2.ONE * LOCAL_CELL_SIZE_M
	var offset_ratio := _cell_boundary_ratio(world_seed, cell_key, side)
	match side:
		"west":
			return Vector2(cell_min.x, lerpf(cell_min.y + LOCAL_CELL_SIZE_M * 0.16, cell_max.y - LOCAL_CELL_SIZE_M * 0.16, offset_ratio))
		"east":
			return Vector2(cell_max.x, lerpf(cell_min.y + LOCAL_CELL_SIZE_M * 0.16, cell_max.y - LOCAL_CELL_SIZE_M * 0.16, offset_ratio))
		"north":
			return Vector2(lerpf(cell_min.x + LOCAL_CELL_SIZE_M * 0.16, cell_max.x - LOCAL_CELL_SIZE_M * 0.16, offset_ratio), cell_min.y)
		"south":
			return Vector2(lerpf(cell_min.x + LOCAL_CELL_SIZE_M * 0.16, cell_max.x - LOCAL_CELL_SIZE_M * 0.16, offset_ratio), cell_max.y)
	return cell_min + Vector2.ONE * LOCAL_CELL_SIZE_M * 0.5

static func _cell_boundary_ratio(world_seed: int, cell_key: Vector2i, side: String) -> float:
	var seed_scope := "local_boundary_v" if side == "west" or side == "east" else "local_boundary_h"
	var boundary_key := cell_key
	if side == "east":
		boundary_key.x += 1
	elif side == "south":
		boundary_key.y += 1
	var seed := _cell_seed(world_seed, seed_scope, boundary_key)
	return 0.5 + sin(float(seed % 8192) * 0.009) * 0.26

static func _build_local_spoke_points(portal: Vector2, hub: Vector2, side: String, seed: int) -> Array[Vector2]:
	var inward := Vector2.ZERO
	var lateral := Vector2.ZERO
	match side:
		"west":
			inward = Vector2.RIGHT
			lateral = Vector2.UP
		"east":
			inward = Vector2.LEFT
			lateral = Vector2.UP
		"north":
			inward = Vector2.DOWN
			lateral = Vector2.RIGHT
		"south":
			inward = Vector2.UP
			lateral = Vector2.RIGHT
	var shoulder := 36.0 + float(seed % 24)
	var bend := sin(float(seed % 4096) * 0.01) * 42.0
	return [
		portal,
		portal + inward * shoulder + lateral * bend * 0.22,
		portal.lerp(hub, 0.58) + lateral * bend,
		hub,
	]

static func _build_local_arc_points(portals: Dictionary, hub: Vector2, cell_key: Vector2i, world_seed: int) -> Array[Vector2]:
	var arc_seed := _cell_seed(world_seed, "local_arc", cell_key)
	var side_pairs := [
		["west", "north"],
		["north", "east"],
		["east", "south"],
		["south", "west"],
	]
	var pair: Array = side_pairs[int(posmod(arc_seed, side_pairs.size()))]
	var start_portal: Vector2 = portals.get(pair[0], hub)
	var end_portal: Vector2 = portals.get(pair[1], hub)
	var drift := Vector2(
		sin(float(arc_seed % 4096) * 0.007) * 44.0,
		cos(float((arc_seed >> 3) % 4096) * 0.011) * 44.0
	)
	return [
		start_portal,
		start_portal.lerp(hub, 0.42) + drift,
		hub + drift * 0.35,
		end_portal.lerp(hub, 0.42) + drift,
		end_portal,
	]

static func _cell_seed(world_seed: int, scope: String, cell_key: Vector2i) -> int:
	var seed := int((world_seed * 33 + cell_key.x * 92837111 + cell_key.y * 689287499) & 0x7fffffff)
	for byte_value in scope.to_utf8_buffer():
		seed = int((seed * 31 + int(byte_value) + 19) & 0x7fffffff)
	return seed

static func _should_raise_bridge(road_class: String, local_points: Array[Vector3], chunk_center: Vector3, world_seed: int) -> bool:
	if road_class != "arterial" and road_class != "collector":
		return false
	if local_points.size() < 2:
		return false
	var midpoint := _polyline_midpoint(local_points)
	var world_mid := Vector2(chunk_center.x + midpoint.x, chunk_center.z + midpoint.z)
	var grid_x := int(round(world_mid.x / 320.0))
	var grid_y := int(round(world_mid.y / 320.0))
	var marker := posmod(grid_x * 17 + grid_y * 13 + int(world_seed) + (11 if road_class == "arterial" else 5), 11)
	return marker == 0 or (absf(world_mid.x) <= 1400.0 and absf(world_mid.y) <= 1400.0 and marker <= 1)

static func _polyline_midpoint(points: Array[Vector3]) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var total_length := 0.0
	for point_index in range(points.size() - 1):
		total_length += points[point_index].distance_to(points[point_index + 1])
	var target_length := total_length * 0.5
	var traversed := 0.0
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var segment_length := a.distance_to(b)
		if traversed + segment_length >= target_length and segment_length > 0.001:
			var t := (target_length - traversed) / segment_length
			return a.lerp(b, t)
		traversed += segment_length
	return points[-1]

static func _apply_bridge_profile(local_points: Array[Vector3], bridge_height: float) -> Array[Vector3]:
	var raised_points: Array[Vector3] = []
	if local_points.size() <= 2:
		return local_points.duplicate()
	for point_index in range(local_points.size()):
		var point: Vector3 = local_points[point_index]
		var t := float(point_index) / float(local_points.size() - 1)
		var lift := sin(t * PI)
		lift *= lift * bridge_height
		raised_points.append(Vector3(point.x, point.y + lift, point.z))
	return raised_points

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
		_append_crossing(connectors["west"], _intersect_vertical_boundary(a, b, -half_size, half_size))
		_append_crossing(connectors["east"], _intersect_vertical_boundary(a, b, half_size, half_size))
		_append_crossing(connectors["north"], _intersect_horizontal_boundary(a, b, -half_size, half_size))
		_append_crossing(connectors["south"], _intersect_horizontal_boundary(a, b, half_size, half_size))

static func _intersect_vertical_boundary(a: Vector3, b: Vector3, boundary_x: float, half_size: float) -> Variant:
	if (a.x - boundary_x) * (b.x - boundary_x) > 0.0 or is_equal_approx(a.x, b.x):
		return null
	var t := (boundary_x - a.x) / (b.x - a.x)
	if t < 0.0 or t > 1.0:
		return null
	var crossing_z := lerpf(a.z, b.z, t)
	if absf(crossing_z) > half_size + 0.05:
		return null
	return snappedf(crossing_z, 0.01)

static func _intersect_horizontal_boundary(a: Vector3, b: Vector3, boundary_z: float, half_size: float) -> Variant:
	if (a.z - boundary_z) * (b.z - boundary_z) > 0.0 or is_equal_approx(a.z, b.z):
		return null
	var t := (boundary_z - a.z) / (b.z - a.z)
	if t < 0.0 or t > 1.0:
		return null
	var crossing_x := lerpf(a.x, b.x, t)
	if absf(crossing_x) > half_size + 0.05:
		return null
	return snappedf(crossing_x, 0.01)

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

static func _is_non_axis(points: Array) -> bool:
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var delta := Vector2(b.x - a.x, b.z - a.z)
		if delta.length() <= 0.1:
			continue
		var angle := absf(rad_to_deg(atan2(delta.y, delta.x)))
		angle = fmod(angle, 180.0)
		if angle > 90.0:
			angle = 180.0 - angle
		if angle >= 12.0 and angle <= 78.0:
			return true
	return false

static func _build_signature(connectors: Dictionary, curved_segment_count: int, segment_count: int, non_axis_count: int, bridge_count: int) -> String:
	var parts := PackedStringArray([
		"segments=%d" % segment_count,
		"curved=%d" % curved_segment_count,
		"non_axis=%d" % non_axis_count,
		"bridges=%d" % bridge_count,
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
