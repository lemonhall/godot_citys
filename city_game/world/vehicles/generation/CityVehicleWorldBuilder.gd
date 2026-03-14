extends RefCounted

const CityVehicleConfig := preload("res://city_game/world/vehicles/model/CityVehicleConfig.gd")
const CityVehicleLaneGraph := preload("res://city_game/world/vehicles/model/CityVehicleLaneGraph.gd")
const CityVehicleQuery := preload("res://city_game/world/vehicles/model/CityVehicleQuery.gd")

const MIN_DRIVABLE_LANE_LENGTH_M := 12.0
const BRANCH_ALIGNMENT_EPSILON_DEG := 50.0

func build(config, district_graph, road_graph):
	var vehicle_config: CityVehicleConfig = CityVehicleConfig.new()
	var lane_graph: CityVehicleLaneGraph = _build_lane_graph(config, vehicle_config, road_graph)
	var district_profiles_by_id: Dictionary = {}

	for district_entry in district_graph.districts:
		var district_data: Dictionary = district_entry
		var profile: Dictionary = _build_profile_for_district(config, vehicle_config, district_data)
		district_profiles_by_id[profile["district_id"]] = profile.duplicate(true)

	var query: CityVehicleQuery = CityVehicleQuery.new()
	query.setup(config, vehicle_config, road_graph, lane_graph, district_profiles_by_id)
	return query

func _build_lane_graph(config, vehicle_config: CityVehicleConfig, road_graph) -> CityVehicleLaneGraph:
	var lane_graph := CityVehicleLaneGraph.new()
	for road_edge in road_graph.edges:
		_add_drivable_lanes(vehicle_config, lane_graph, road_edge)
	_add_intersection_turn_contracts(config, lane_graph, road_graph)
	return lane_graph

func _add_drivable_lanes(vehicle_config: CityVehicleConfig, lane_graph: CityVehicleLaneGraph, edge: Dictionary) -> void:
	var points: Array = edge.get("points", [])
	if points.size() < 2:
		return
	var section_semantics: Dictionary = edge.get("section_semantics", {})
	var lane_schema: Dictionary = section_semantics.get("lane_schema", {})
	if lane_schema.is_empty():
		return
	var edge_profile: Dictionary = section_semantics.get("edge_profile", {})
	var road_id := str(edge.get("road_id", edge.get("edge_id", "")))
	var road_class := str(edge.get("class", "local"))
	var template_id := str(edge.get("template_id", section_semantics.get("template_id", "local")))
	var direction_mode := str(lane_schema.get("direction_mode", "two_way"))
	var lane_width_m := float(lane_schema.get("lane_width_m", 3.2))
	var median_width_m := float(edge_profile.get("median_width_m", edge.get("median_width_m", 0.0)))
	var forward_lane_count := int(lane_schema.get("forward_lane_count", edge.get("lane_count_forward", 0)))
	var backward_lane_count := int(lane_schema.get("backward_lane_count", edge.get("lane_count_backward", 0)))
	var forward_offsets := _build_lane_offsets(forward_lane_count, 1.0, lane_width_m, median_width_m, backward_lane_count <= 0)
	var backward_offsets := _build_lane_offsets(backward_lane_count, -1.0, lane_width_m, median_width_m, forward_lane_count <= 0)

	for lane_index in range(forward_offsets.size()):
		var forward_offset_points := _build_offset_points(points, forward_offsets[lane_index])
		var forward_length := _polyline_length_3d(forward_offset_points)
		if forward_length < MIN_DRIVABLE_LANE_LENGTH_M:
			continue
		lane_graph.add_lane({
			"lane_id": "veh_lane_%s_f_%02d" % [road_id, lane_index],
			"lane_type": "driving",
			"road_id": road_id,
			"edge_id": str(edge.get("edge_id", road_id)),
			"road_class": road_class,
			"template_id": template_id,
			"direction": "forward",
			"direction_mode": direction_mode,
			"lane_index": lane_index,
			"lane_width_m": lane_width_m,
			"points": forward_offset_points,
			"path_length_m": forward_length,
			"headway_m": vehicle_config.get_min_headway_for_road_class(road_class),
			"seed": int(edge.get("seed", 0)) + lane_index * 17,
		})

	for lane_index in range(backward_offsets.size()):
		var backward_offset_points := _build_offset_points(points, backward_offsets[lane_index])
		backward_offset_points.reverse()
		var backward_length := _polyline_length_3d(backward_offset_points)
		if backward_length < MIN_DRIVABLE_LANE_LENGTH_M:
			continue
		lane_graph.add_lane({
			"lane_id": "veh_lane_%s_b_%02d" % [road_id, lane_index],
			"lane_type": "driving",
			"road_id": road_id,
			"edge_id": str(edge.get("edge_id", road_id)),
			"road_class": road_class,
			"template_id": template_id,
			"direction": "backward",
			"direction_mode": direction_mode,
			"lane_index": lane_index,
			"lane_width_m": lane_width_m,
			"points": backward_offset_points,
			"path_length_m": backward_length,
			"headway_m": vehicle_config.get_min_headway_for_road_class(road_class),
			"seed": int(edge.get("seed", 0)) + 1000 + lane_index * 17,
		})

func _build_lane_offsets(lane_count: int, side_sign: float, lane_width_m: float, median_width_m: float, center_single_direction: bool) -> Array[float]:
	var offsets: Array[float] = []
	if lane_count <= 0:
		return offsets
	if center_single_direction:
		var centered_origin := float(lane_count - 1) * 0.5
		for lane_index in range(lane_count):
			offsets.append((float(lane_index) - centered_origin) * lane_width_m)
		return offsets
	var inner_offset := median_width_m * 0.5 + lane_width_m * 0.5
	for lane_index in range(lane_count):
		offsets.append(side_sign * (inner_offset + lane_width_m * float(lane_index)))
	return offsets

func _build_offset_points(points: Array, offset_distance: float) -> Array[Vector3]:
	var offset_points: Array[Vector3] = []
	if points.size() < 2:
		return offset_points
	for point_index in range(points.size()):
		var current: Vector2 = points[point_index]
		var previous: Vector2 = points[maxi(point_index - 1, 0)]
		var following: Vector2 = points[mini(point_index + 1, points.size() - 1)]
		var tangent := following - previous
		if tangent.length_squared() <= 0.0001:
			tangent = following - current
		if tangent.length_squared() <= 0.0001:
			tangent = current - previous
		if tangent.length_squared() <= 0.0001:
			continue
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		offset_points.append(Vector3(
			current.x + normal.x * offset_distance,
			0.0,
			current.y + normal.y * offset_distance
		))
	return offset_points

func _polyline_length_3d(points: Array) -> float:
	var total := 0.0
	for point_index in range(points.size() - 1):
		total += (points[point_index + 1] as Vector3).distance_to(points[point_index] as Vector3)
	return total

func _add_intersection_turn_contracts(config, lane_graph: CityVehicleLaneGraph, road_graph) -> void:
	var intersections: Array = road_graph.get_intersections_in_rect(config.get_world_bounds())
	for intersection_variant in intersections:
		var intersection: Dictionary = intersection_variant
		var ordered_branches: Array = intersection.get("ordered_branches", [])
		var connection_semantics: Array = intersection.get("branch_connection_semantics", [])
		if ordered_branches.is_empty() or connection_semantics.is_empty():
			continue
		var position: Vector2 = intersection.get("position", Vector2.ZERO)
		var branch_lane_map: Dictionary = {}
		var branch_lanes: Array[Dictionary] = []
		for branch_variant in ordered_branches:
			var branch: Dictionary = branch_variant
			var branch_index := int(branch.get("branch_index", -1))
			var branch_lane_sets := _collect_branch_lane_sets(lane_graph, str(branch.get("edge_id", "")), position, float(branch.get("bearing_deg", 0.0)))
			branch_lane_map[str(branch_index)] = branch_lane_sets
			branch_lanes.append({
				"branch_index": branch_index,
				"edge_id": str(branch.get("edge_id", "")),
				"inbound_lane_ids": (branch_lane_sets.get("inbound_lane_ids", []) as Array).duplicate(true),
				"outbound_lane_ids": (branch_lane_sets.get("outbound_lane_ids", []) as Array).duplicate(true),
			})
		var lane_connections: Array[Dictionary] = []
		for connection_variant in connection_semantics:
			var connection: Dictionary = connection_variant
			var from_branch_index := int(connection.get("from_branch_index", -1))
			var to_branch_index := int(connection.get("to_branch_index", -1))
			var from_branch_lanes: Dictionary = branch_lane_map.get(str(from_branch_index), {})
			var to_branch_lanes: Dictionary = branch_lane_map.get(str(to_branch_index), {})
			lane_connections.append({
				"from_branch_index": from_branch_index,
				"to_branch_index": to_branch_index,
				"turn_type": str(connection.get("turn_type", "")),
				"from_lane_ids": (from_branch_lanes.get("inbound_lane_ids", []) as Array).duplicate(true),
				"to_lane_ids": (to_branch_lanes.get("outbound_lane_ids", []) as Array).duplicate(true),
			})
		lane_graph.add_intersection_turn_contract({
			"intersection_id": str(intersection.get("intersection_id", "")),
			"position": position,
			"intersection_type": str(intersection.get("intersection_type", "")),
			"ordered_branches": ordered_branches.duplicate(true),
			"branch_connection_semantics": connection_semantics.duplicate(true),
			"branch_lanes": branch_lanes,
			"lane_connections": lane_connections,
		})

func _collect_branch_lane_sets(lane_graph: CityVehicleLaneGraph, road_id: String, intersection_position: Vector2, branch_bearing_deg: float) -> Dictionary:
	var inbound_lane_ids: Array[String] = []
	var outbound_lane_ids: Array[String] = []
	for lane_id_variant in lane_graph.get_lane_ids_for_road(road_id):
		var lane_id := str(lane_id_variant)
		var lane: Dictionary = lane_graph.get_lane_by_id(lane_id)
		var nearest_info := _find_nearest_lane_info(intersection_position, lane.get("points", []))
		if nearest_info.is_empty():
			continue
		if float(nearest_info.get("distance", INF)) > maxf(float(lane.get("lane_width_m", 3.2)) * 3.0, 24.0):
			continue
		var tangent: Vector2 = nearest_info.get("tangent", Vector2.ZERO)
		if tangent.length_squared() <= 0.0001:
			continue
		var travel_bearing := _bearing_from_vector(tangent)
		if _min_bearing_delta(travel_bearing, branch_bearing_deg) <= BRANCH_ALIGNMENT_EPSILON_DEG:
			outbound_lane_ids.append(lane_id)
		elif _min_bearing_delta(travel_bearing, fposmod(branch_bearing_deg + 180.0, 360.0)) <= BRANCH_ALIGNMENT_EPSILON_DEG:
			inbound_lane_ids.append(lane_id)
	inbound_lane_ids.sort()
	outbound_lane_ids.sort()
	return {
		"inbound_lane_ids": inbound_lane_ids,
		"outbound_lane_ids": outbound_lane_ids,
	}

func _find_nearest_lane_info(position: Vector2, points: Array) -> Dictionary:
	var best_distance := INF
	var best_point := Vector2.ZERO
	var best_tangent := Vector2.ZERO
	for point_index in range(points.size() - 1):
		var a3: Vector3 = points[point_index]
		var b3: Vector3 = points[point_index + 1]
		var a := Vector2(a3.x, a3.z)
		var b := Vector2(b3.x, b3.z)
		var nearest := Geometry2D.get_closest_point_to_segment(position, a, b)
		var distance := position.distance_to(nearest)
		if distance < best_distance:
			best_distance = distance
			best_point = nearest
			best_tangent = (b - a).normalized()
	return {
		"nearest_point": best_point,
		"distance": best_distance,
		"tangent": best_tangent,
	}

func _build_profile_for_district(config, vehicle_config: CityVehicleConfig, district_data: Dictionary) -> Dictionary:
	var district_key: Vector2i = district_data.get("district_key", Vector2i.ZERO)
	var district_class := _resolve_district_class(config, district_data)
	var density_scalar := vehicle_config.get_density_for_district_class(district_class)
	return {
		"district_id": str(district_data.get("district_id", "")),
		"district_key": district_key,
		"district_class": district_class,
		"density_scalar": density_scalar,
		"density_bucket": vehicle_config.resolve_density_bucket(density_scalar),
		"profile_seed": int(district_data.get("seed", 0)),
	}

func _resolve_district_class(config, district_data: Dictionary) -> String:
	var center: Vector2 = district_data.get("center", Vector2.ZERO)
	var bounds: Rect2 = config.get_world_bounds()
	var half_size := bounds.size * 0.5
	var radial_x := absf(center.x) / maxf(half_size.x, 1.0)
	var radial_y := absf(center.y) / maxf(half_size.y, 1.0)
	var radial_factor := sqrt(radial_x * radial_x + radial_y * radial_y)
	var district_seed_value := int(district_data.get("seed", 0))
	var district_key: Vector2i = district_data.get("district_key", Vector2i.ZERO)

	if radial_factor < 0.24:
		return "core"
	if radial_factor < 0.46:
		if district_seed_value % 7 == 0:
			return "industrial"
		return "mixed"
	if radial_factor < 0.78:
		if (district_key.x + district_key.y) % 6 == 0:
			return "industrial"
		return "residential"
	return "periphery"

func _bearing_from_vector(direction: Vector2) -> float:
	var bearing := fposmod(rad_to_deg(atan2(direction.x, direction.y)), 360.0)
	if bearing >= 359.999:
		return 0.0
	return bearing

func _min_bearing_delta(a_deg: float, b_deg: float) -> float:
	var diff := fmod(absf(a_deg - b_deg), 360.0)
	if diff > 180.0:
		diff = 360.0 - diff
	return diff
