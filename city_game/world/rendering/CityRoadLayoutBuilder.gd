extends RefCounted

const CityRoadTemplateCatalog := preload("res://city_game/world/rendering/CityRoadTemplateCatalog.gd")
const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

const QUERY_MARGIN_M := 56.0
const LOCAL_CELL_SIZE_M := 320.0
const LOCAL_CELL_MARGIN_M := 96.0

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
	var shared_graph_segment_count := 0
	var local_fallback_segment_count := 0
	var road_graph = chunk_data.get("road_graph")
	if road_graph != null and road_graph.has_method("get_edges_intersecting_rect"):
		for edge in road_graph.get_edges_intersecting_rect(expanded_rect):
			var segment := _make_segment_from_world_polyline(
				str(edge.get("class", "arterial")),
				edge.get("points", []),
				chunk_center,
				world_seed,
				int(edge.get("seed", world_seed))
			)
			if segment.is_empty():
				continue
			if not _polyline_intersects_chunk(segment.get("points", []), half_size):
				continue
			segments.append(segment)
			shared_graph_segment_count += 1

	var connectors := {
		"north": [],
		"south": [],
		"east": [],
		"west": [],
	}
	var curved_segment_count := 0
	var non_axis_road_segment_count := 0
	var bridge_count := 0
	var template_counts := {
		"expressway_elevated": 0,
		"arterial": 0,
		"local": 0,
		"service": 0,
	}
	var min_bridge_clearance := INF
	var max_bridge_deck_thickness := 0.0

	for segment in segments:
		var points: Array = segment.get("points", [])
		_accumulate_connectors(connectors, points, half_size)
		if _is_curved(points):
			curved_segment_count += 1
		if _is_non_axis(points):
			non_axis_road_segment_count += 1
		var template_id := str(segment.get("template_id", "local"))
		if template_counts.has(template_id):
			template_counts[template_id] += 1
		if bool(segment.get("bridge", false)):
			bridge_count += 1
			min_bridge_clearance = minf(min_bridge_clearance, float(segment.get("bridge_clearance_m", 0.0)))
			max_bridge_deck_thickness = maxf(max_bridge_deck_thickness, float(segment.get("deck_thickness_m", 0.0)))

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
		"road_mesh_mode": "terrain_overlay_bridges",
		"road_template_counts": template_counts,
		"bridge_min_clearance_m": 0.0 if min_bridge_clearance == INF else min_bridge_clearance,
		"bridge_deck_thickness_m": max_bridge_deck_thickness,
		"shared_graph_segment_count": shared_graph_segment_count,
		"local_fallback_segment_count": local_fallback_segment_count,
		"signature": _build_signature(connectors, curved_segment_count, segments.size(), non_axis_road_segment_count, bridge_count, template_counts),
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

			var east_west := _build_local_axis_points(
				portals["west"],
				portals["east"],
				hub,
				_cell_seed(world_seed, "local_axis_we", cell_key)
			)
			var east_west_segment := _make_segment_from_world_polyline("local", east_west, chunk_center, world_seed, _cell_seed(world_seed, "local_segment_we", cell_key))
			if not east_west_segment.is_empty() and _polyline_intersects_chunk(east_west_segment.get("points", []), half_size):
				segments.append(east_west_segment)

			var north_south := _build_local_axis_points(
				portals["north"],
				portals["south"],
				hub,
				_cell_seed(world_seed, "local_axis_ns", cell_key)
			)
			var north_south_segment := _make_segment_from_world_polyline("local", north_south, chunk_center, world_seed, _cell_seed(world_seed, "local_segment_ns", cell_key))
			if not north_south_segment.is_empty() and _polyline_intersects_chunk(north_south_segment.get("points", []), half_size):
				segments.append(north_south_segment)

			if _should_add_service_link(cell_key, world_seed):
				var service_points := _build_local_service_points(portals, hub, cell_key, world_seed)
				var service_segment := _make_segment_from_world_polyline("service", service_points, chunk_center, world_seed, _cell_seed(world_seed, "local_segment_service", cell_key))
				if not service_segment.is_empty() and _polyline_intersects_chunk(service_segment.get("points", []), half_size):
					segments.append(service_segment)
	return segments

static func _make_segment_from_world_polyline(road_class: String, points_2d: Array, chunk_center: Vector3, world_seed: int, segment_seed: int) -> Dictionary:
	if points_2d.size() < 2:
		return {}
	var template_id := CityRoadTemplateCatalog.get_template_id_for_class(road_class)
	var template := CityRoadTemplateCatalog.get_template(template_id)
	var local_points := _world_polyline_to_local_points(points_2d, chunk_center, world_seed)
	if local_points.size() < 2:
		return {}
	var max_grade := float(template.get("max_grade", 0.08))
	local_points = _smooth_ground_profile(local_points, max_grade)
	var bridge := template_id == "expressway_elevated" or _should_raise_bridge(road_class, points_2d, segment_seed)
	var bridge_clearance := 0.0
	var bridge_range := Vector2.ZERO
	var deck_thickness := float(template.get("deck_thickness_m", 0.4))
	if bridge:
		bridge_clearance = _resolve_bridge_clearance(template_id, segment_seed)
		var bridge_profile := _build_bridge_profile(
			local_points,
			points_2d,
			world_seed,
			bridge_clearance,
			max_grade,
			float(template.get("width_m", 11.0)),
			template_id
		)
		if bridge_profile.is_empty():
			bridge = false
			bridge_clearance = 0.0
		else:
			bridge_range = bridge_profile.get("bridge_range", Vector2.ZERO)
			local_points = bridge_profile.get("points", local_points)
			deck_thickness = maxf(deck_thickness, 1.0)
	return {
		"class": road_class,
		"template_id": template_id,
		"lane_count_total": int(template.get("lane_count_total", 2)),
		"width": float(template.get("width_m", 11.0)),
		"median_width_m": float(template.get("median_width_m", 0.0)),
		"shoulder_width_m": float(template.get("shoulder_width_m", 0.0)),
		"deck_thickness_m": deck_thickness,
		"points": local_points,
		"bridge": bridge,
		"bridge_clearance_m": bridge_clearance,
		"bridge_range": bridge_range,
}

static func _get_local_grid_origin(world_seed: int) -> Vector2:
	return Vector2(
		64.0 + float((world_seed >> 3) % 79),
		-96.0 + float((world_seed >> 5) % 87)
	)

static func _build_local_cell_hub(cell_key: Vector2i, cell_min: Vector2, world_seed: int) -> Vector2:
	var hub_seed := _cell_seed(world_seed, "local_hub", cell_key)
	var center := cell_min + Vector2.ONE * LOCAL_CELL_SIZE_M * 0.5
	var jitter_x := sin(float(hub_seed % 4096) * 0.011) * 58.0
	var jitter_y := cos(float((hub_seed >> 2) % 4096) * 0.013) * 54.0
	return center + Vector2(jitter_x, jitter_y)

static func _build_local_cell_portal(cell_key: Vector2i, cell_min: Vector2, side: String, world_seed: int) -> Vector2:
	var cell_max := cell_min + Vector2.ONE * LOCAL_CELL_SIZE_M
	var offset_ratio := _cell_boundary_ratio(world_seed, cell_key, side)
	match side:
		"west":
			return Vector2(cell_min.x, lerpf(cell_min.y + LOCAL_CELL_SIZE_M * 0.18, cell_max.y - LOCAL_CELL_SIZE_M * 0.18, offset_ratio))
		"east":
			return Vector2(cell_max.x, lerpf(cell_min.y + LOCAL_CELL_SIZE_M * 0.18, cell_max.y - LOCAL_CELL_SIZE_M * 0.18, offset_ratio))
		"north":
			return Vector2(lerpf(cell_min.x + LOCAL_CELL_SIZE_M * 0.18, cell_max.x - LOCAL_CELL_SIZE_M * 0.18, offset_ratio), cell_min.y)
		"south":
			return Vector2(lerpf(cell_min.x + LOCAL_CELL_SIZE_M * 0.18, cell_max.x - LOCAL_CELL_SIZE_M * 0.18, offset_ratio), cell_max.y)
	return cell_min + Vector2.ONE * LOCAL_CELL_SIZE_M * 0.5

static func _cell_boundary_ratio(world_seed: int, cell_key: Vector2i, side: String) -> float:
	var seed_scope := "local_boundary_v" if side == "west" or side == "east" else "local_boundary_h"
	var boundary_key := cell_key
	if side == "east":
		boundary_key.x += 1
	elif side == "south":
		boundary_key.y += 1
	var boundary_seed := _cell_seed(world_seed, seed_scope, boundary_key)
	return 0.5 + sin(float(boundary_seed % 8192) * 0.009) * 0.23

static func _build_local_axis_points(start_portal: Vector2, end_portal: Vector2, hub: Vector2, axis_seed: int) -> Array[Vector2]:
	var direction := (end_portal - start_portal).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var lateral_sway := sin(float(axis_seed % 4096) * 0.012) * 46.0
	var anchor := start_portal.lerp(end_portal, 0.5).lerp(hub, 0.56) + normal * lateral_sway
	return [
		start_portal,
		start_portal.lerp(anchor, 0.36),
		anchor,
		end_portal.lerp(anchor, 0.36),
		end_portal,
	]

static func _build_local_service_points(portals: Dictionary, hub: Vector2, cell_key: Vector2i, world_seed: int) -> Array[Vector2]:
	var service_seed := _cell_seed(world_seed, "local_service", cell_key)
	var side_pairs := [
		["west", "north"],
		["north", "east"],
		["east", "south"],
		["south", "west"],
	]
	var pair: Array = side_pairs[int(posmod(service_seed, side_pairs.size()))]
	var start_portal: Vector2 = portals.get(pair[0], hub)
	var end_portal: Vector2 = portals.get(pair[1], hub)
	var direction := (end_portal - start_portal).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var shoulder := 22.0 + float(service_seed % 11)
	return [
		start_portal,
		start_portal.lerp(hub, 0.44) + normal * shoulder,
		hub + normal * shoulder * 0.35,
		end_portal.lerp(hub, 0.44) + normal * shoulder,
		end_portal,
	]

static func _should_add_service_link(cell_key: Vector2i, world_seed: int) -> bool:
	return posmod(_cell_seed(world_seed, "local_service_enable", cell_key), 3) == 0

static func _cell_seed(world_seed: int, scope: String, cell_key: Vector2i) -> int:
	var hash_seed := int((world_seed * 33 + cell_key.x * 92837111 + cell_key.y * 689287499) & 0x7fffffff)
	for byte_value in scope.to_utf8_buffer():
		hash_seed = int((hash_seed * 31 + int(byte_value) + 19) & 0x7fffffff)
	return hash_seed

static func _should_raise_bridge(road_class: String, points_2d: Array, bridge_seed: int) -> bool:
	if road_class != "arterial" and road_class != "secondary":
		return false
	if points_2d.size() < 2:
		return false
	var midpoint := _polyline_midpoint_2d(points_2d)
	var center_bias := absf(midpoint.x) <= 2600.0 and absf(midpoint.y) <= 2600.0
	var marker := posmod(int(round(midpoint.x / 320.0)) * 13 + int(round(midpoint.y / 320.0)) * 17 + bridge_seed, 17)
	return center_bias and marker <= 3

static func _resolve_bridge_clearance(template_id: String, clearance_seed: int) -> float:
	if template_id == "expressway_elevated":
		return 6.5 + float(posmod(clearance_seed, 4))
	return 5.0 + float(posmod(clearance_seed, 3))

static func _polyline_midpoint_2d(points: Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var total_length := 0.0
	for point_index in range(points.size() - 1):
		total_length += (points[point_index] as Vector2).distance_to(points[point_index + 1] as Vector2)
	var target_length := total_length * 0.5
	var traversed := 0.0
	for point_index in range(points.size() - 1):
		var a: Vector2 = points[point_index]
		var b: Vector2 = points[point_index + 1]
		var segment_length := a.distance_to(b)
		if traversed + segment_length >= target_length and segment_length > 0.001:
			return a.lerp(b, (target_length - traversed) / segment_length)
		traversed += segment_length
	return points[-1]

static func _world_polyline_to_local_points(points_2d: Array, chunk_center: Vector3, world_seed: int) -> Array[Vector3]:
	var local_points: Array[Vector3] = []
	for point in points_2d:
		var world_point: Vector2 = point
		local_points.append(Vector3(
			world_point.x - chunk_center.x,
			CityTerrainSampler.sample_height(world_point.x, world_point.y, world_seed),
			world_point.y - chunk_center.z
		))
	return local_points

static func _smooth_ground_profile(local_points: Array, max_grade: float) -> Array[Vector3]:
	if local_points.size() <= 2:
		return local_points.duplicate()
	var smoothed: Array[Vector3] = []
	for point in local_points:
		smoothed.append(point)
	for _iteration in range(2):
		for point_index in range(1, smoothed.size() - 1):
			var prev_point: Vector3 = smoothed[point_index - 1]
			var current_point: Vector3 = smoothed[point_index]
			var next_point: Vector3 = smoothed[point_index + 1]
			var blended_y := (prev_point.y + current_point.y * 2.0 + next_point.y) * 0.25
			smoothed[point_index] = Vector3(current_point.x, lerpf(current_point.y, blended_y, 0.72), current_point.z)
	_enforce_max_grade(smoothed, max_grade)
	return smoothed

static func _enforce_max_grade(points: Array[Vector3], max_grade: float) -> void:
	for point_index in range(1, points.size()):
		var prev_point: Vector3 = points[point_index - 1]
		var current_point: Vector3 = points[point_index]
		var horizontal_distance := maxf(Vector2(prev_point.x, prev_point.z).distance_to(Vector2(current_point.x, current_point.z)), 1.0)
		var max_delta := horizontal_distance * max_grade
		var clamped_y := clampf(current_point.y, prev_point.y - max_delta, prev_point.y + max_delta)
		points[point_index] = Vector3(current_point.x, clamped_y, current_point.z)
	for point_index in range(points.size() - 2, -1, -1):
		var next_point: Vector3 = points[point_index + 1]
		var current_point: Vector3 = points[point_index]
		var horizontal_distance := maxf(Vector2(next_point.x, next_point.z).distance_to(Vector2(current_point.x, current_point.z)), 1.0)
		var max_delta := horizontal_distance * max_grade
		var clamped_y := clampf(current_point.y, next_point.y - max_delta, next_point.y + max_delta)
		points[point_index] = Vector3(current_point.x, clamped_y, current_point.z)

static func _build_bridge_profile(local_points: Array, points_2d: Array, world_seed: int, bridge_clearance: float, max_grade: float, road_width: float, template_id: String) -> Dictionary:
	var total_length := _measure_horizontal_polyline_length(local_points)
	if total_length <= 1.0 or max_grade <= 0.001:
		return {}
	var deck_level := _resolve_bridge_deck_level(points_2d, local_points, world_seed, bridge_clearance)
	var start_delta := maxf(deck_level - float((local_points[0] as Vector3).y), 0.0)
	var end_delta := maxf(deck_level - float((local_points[-1] as Vector3).y), 0.0)
	var minimum_flat_length := _resolve_bridge_min_flat_length(road_width, template_id)
	var required_ramp_in := _resolve_bridge_transition_length(start_delta, max_grade, road_width, template_id)
	var required_ramp_out := _resolve_bridge_transition_length(end_delta, max_grade, road_width, template_id)
	var required_total := required_ramp_in + minimum_flat_length + required_ramp_out
	if total_length < required_total:
		return {}

	var slack := total_length - required_total
	var flat_length := minimum_flat_length + slack * 0.2
	var transition_slack := maxf(total_length - flat_length - required_ramp_in - required_ramp_out, 0.0)
	var ramp_in_length := required_ramp_in + transition_slack * 0.5
	var ramp_out_length := required_ramp_out + transition_slack * 0.5
	var flat_start_distance := ramp_in_length
	var flat_end_distance := total_length - ramp_out_length
	if flat_end_distance <= flat_start_distance:
		return {}

	var raised_points: Array[Vector3] = []
	var traversed_distance := 0.0
	for point_index in range(local_points.size()):
		var point: Vector3 = local_points[point_index]
		if point_index > 0:
			var previous_point: Vector3 = local_points[point_index - 1]
			traversed_distance += Vector2(previous_point.x, previous_point.z).distance_to(Vector2(point.x, point.z))
		var ramp := _bridge_ramp_factor_by_distance(traversed_distance, flat_start_distance, flat_end_distance, total_length)
		raised_points.append(Vector3(point.x, lerpf(point.y, deck_level, ramp), point.z))
	_enforce_max_grade(raised_points, max_grade)
	if _measure_max_grade(raised_points) > max_grade + 0.01:
		return {}
	return {
		"points": raised_points,
		"bridge_range": Vector2(flat_start_distance / total_length, flat_end_distance / total_length),
	}

static func _resolve_bridge_deck_level(points_2d: Array, local_points: Array, world_seed: int, bridge_clearance: float) -> float:
	var max_ground := -INF
	for ratio in [0.22, 0.35, 0.5, 0.65, 0.78]:
		var sample_point := _sample_polyline_2d(points_2d, float(ratio))
		max_ground = maxf(max_ground, CityTerrainSampler.sample_height(sample_point.x, sample_point.y, world_seed))
	var endpoint_height := maxf((local_points[0] as Vector3).y, (local_points[-1] as Vector3).y)
	return maxf(max_ground + bridge_clearance, endpoint_height + bridge_clearance * 0.72)

static func _resolve_bridge_transition_length(height_delta: float, max_grade: float, road_width: float, template_id: String) -> float:
	var physical_length := height_delta / maxf(max_grade, 0.001)
	var minimum_length := maxf(road_width * (2.0 if template_id == "expressway_elevated" else 1.5), 44.0 if template_id == "expressway_elevated" else 28.0)
	return maxf(physical_length, minimum_length)

static func _resolve_bridge_min_flat_length(road_width: float, template_id: String) -> float:
	return maxf(road_width * (1.6 if template_id == "expressway_elevated" else 1.2), 64.0 if template_id == "expressway_elevated" else 36.0)

static func _bridge_ramp_factor_by_distance(distance_m: float, flat_start_distance: float, flat_end_distance: float, total_length: float) -> float:
	if distance_m <= 0.0 or distance_m >= total_length:
		return 0.0
	if distance_m < flat_start_distance:
		return _smoothstep(0.0, flat_start_distance, distance_m)
	if distance_m > flat_end_distance:
		return 1.0 - _smoothstep(flat_end_distance, total_length, distance_m)
	return 1.0

static func _measure_horizontal_polyline_length(points: Array) -> float:
	var total_length := 0.0
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		total_length += Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	return total_length

static func _measure_max_grade(points: Array) -> float:
	var max_grade := 0.0
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var horizontal_distance := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		if horizontal_distance <= 0.001:
			continue
		max_grade = maxf(max_grade, absf(b.y - a.y) / horizontal_distance)
	return max_grade

static func _sample_polyline_2d(points: Array, ratio: float) -> Vector2:
	var total_length := 0.0
	for point_index in range(points.size() - 1):
		total_length += (points[point_index] as Vector2).distance_to(points[point_index + 1] as Vector2)
	if total_length <= 0.001:
		return points[0]
	var target_length := total_length * clampf(ratio, 0.0, 1.0)
	var traversed := 0.0
	for point_index in range(points.size() - 1):
		var a: Vector2 = points[point_index]
		var b: Vector2 = points[point_index + 1]
		var segment_length := a.distance_to(b)
		if traversed + segment_length >= target_length and segment_length > 0.001:
			return a.lerp(b, (target_length - traversed) / segment_length)
		traversed += segment_length
	return points[-1]

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

static func _build_signature(connectors: Dictionary, curved_segment_count: int, segment_count: int, non_axis_count: int, bridge_count: int, template_counts: Dictionary) -> String:
	var parts := PackedStringArray([
		"segments=%d" % segment_count,
		"curved=%d" % curved_segment_count,
		"non_axis=%d" % non_axis_count,
		"bridges=%d" % bridge_count,
		"templates=%s/%s/%s/%s" % [
			int(template_counts.get("expressway_elevated", 0)),
			int(template_counts.get("arterial", 0)),
			int(template_counts.get("local", 0)),
			int(template_counts.get("service", 0)),
		],
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

static func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 0.0
	var t := clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
