extends RefCounted

const CityPedestrianLaneGraph := preload("res://city_game/world/pedestrians/model/CityPedestrianLaneGraph.gd")

const SIDEWALK_BUFFER_M := 5.0
const CROSSING_BUFFER_M := 1.0
const MIN_SIDEWALK_LENGTH_M := 14.0

func build(config, road_graph) -> CityPedestrianLaneGraph:
	var lane_graph := CityPedestrianLaneGraph.new()
	for road_edge in road_graph.edges:
		var edge: Dictionary = road_edge
		if str(edge.get("class", "")) == "expressway_elevated":
			continue
		_add_sidewalk_lanes(lane_graph, edge)
	_add_crossing_lanes(config, lane_graph, road_graph)
	_add_midblock_crossings(lane_graph, road_graph)
	return lane_graph

func _add_sidewalk_lanes(lane_graph: CityPedestrianLaneGraph, edge: Dictionary) -> void:
	var road_id := str(edge.get("road_id", edge.get("edge_id", "")))
	var road_class := str(edge.get("class", "local"))
	var width_m := float(edge.get("width_m", 11.0))
	var road_clearance := width_m * 0.5 + SIDEWALK_BUFFER_M
	var points: Array = edge.get("points", [])
	for side_sign in [1.0, -1.0]:
		var side := "left" if side_sign > 0.0 else "right"
		var offset_points := _build_offset_points(points, road_clearance * side_sign)
		var lane_length := _polyline_length_3d(offset_points)
		if lane_length < MIN_SIDEWALK_LENGTH_M:
			continue
		lane_graph.add_lane({
			"lane_id": "ped_lane_%s_%s" % [road_id, side],
			"lane_type": "sidewalk",
			"road_id": road_id,
			"road_class": road_class,
			"side": side,
			"road_clearance_m": road_clearance,
			"points": offset_points,
			"path_length_m": lane_length,
			"seed": int(edge.get("seed", 0)),
		})

func _add_crossing_lanes(config, lane_graph: CityPedestrianLaneGraph, road_graph) -> void:
	var intersections: Array = road_graph.get_intersections_in_rect(config.get_world_bounds())
	var dedupe: Dictionary = {}
	for intersection_variant in intersections:
		var intersection: Dictionary = intersection_variant
		var position: Vector2 = intersection.get("position", Vector2.ZERO)
		var nearby_edges: Array = road_graph.get_edges_intersecting_rect(Rect2(position - Vector2.ONE * 48.0, Vector2.ONE * 96.0))
		for edge_variant in nearby_edges:
			var edge: Dictionary = edge_variant
			var road_class := str(edge.get("class", "local"))
			if road_class == "expressway_elevated":
				continue
			var nearest_info := _find_nearest_segment_info(position, edge.get("points", []))
			if nearest_info.is_empty():
				continue
			var nearest_point: Vector2 = nearest_info.get("nearest_point", position)
			if position.distance_to(nearest_point) > maxf(float(edge.get("width_m", 11.0)), 18.0):
				continue
			var tangent: Vector2 = nearest_info.get("tangent", Vector2.ZERO)
			if tangent.length_squared() <= 0.0001:
				continue
			var normal := Vector2(-tangent.y, tangent.x).normalized()
			var road_clearance := float(edge.get("width_m", 11.0)) * 0.5 + CROSSING_BUFFER_M
			var crossing_key := "%s:%d:%d" % [
				str(edge.get("road_id", edge.get("edge_id", ""))),
				int(round(position.x / 4.0)),
				int(round(position.y / 4.0)),
			]
			if dedupe.has(crossing_key):
				continue
			dedupe[crossing_key] = true
			var crossing_points := [
				Vector3(position.x + normal.x * road_clearance, 0.0, position.y + normal.y * road_clearance),
				Vector3(position.x - normal.x * road_clearance, 0.0, position.y - normal.y * road_clearance),
			]
			lane_graph.add_lane({
				"lane_id": "ped_crossing_%s_%d_%d" % [
					str(edge.get("road_id", edge.get("edge_id", ""))),
					int(round(position.x)),
					int(round(position.y)),
				],
				"lane_type": "crossing",
				"road_id": str(edge.get("road_id", edge.get("edge_id", ""))),
				"road_class": road_class,
				"side": "crossing",
				"road_clearance_m": road_clearance,
				"points": crossing_points,
				"path_length_m": _polyline_length_3d(crossing_points),
				"seed": int(edge.get("seed", 0)),
			})

func _add_midblock_crossings(lane_graph: CityPedestrianLaneGraph, road_graph) -> void:
	var dedupe: Dictionary = {}
	for road_edge in road_graph.edges:
		var edge: Dictionary = road_edge
		var road_class := str(edge.get("class", "local"))
		if road_class == "expressway_elevated":
			continue
		var points: Array = edge.get("points", [])
		if points.size() < 2:
			continue
		var midpoint_index := int(floor(float(points.size() - 1) * 0.5))
		var a: Vector2 = points[midpoint_index]
		var b: Vector2 = points[mini(midpoint_index + 1, points.size() - 1)]
		var tangent := (b - a).normalized()
		if tangent.length_squared() <= 0.0001:
			continue
		var center := a.lerp(b, 0.5)
		var dedupe_key := "%s:%d:%d" % [
			str(edge.get("road_id", edge.get("edge_id", ""))),
			int(round(center.x / 4.0)),
			int(round(center.y / 4.0)),
		]
		if dedupe.has(dedupe_key):
			continue
		dedupe[dedupe_key] = true
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		var road_clearance := float(edge.get("width_m", 11.0)) * 0.5 + CROSSING_BUFFER_M
		var crossing_points := [
			Vector3(center.x + normal.x * road_clearance, 0.0, center.y + normal.y * road_clearance),
			Vector3(center.x - normal.x * road_clearance, 0.0, center.y - normal.y * road_clearance),
		]
		lane_graph.add_lane({
			"lane_id": "ped_midblock_%s_%d_%d" % [
				str(edge.get("road_id", edge.get("edge_id", ""))),
				int(round(center.x)),
				int(round(center.y)),
			],
			"lane_type": "crossing",
			"road_id": str(edge.get("road_id", edge.get("edge_id", ""))),
			"road_class": road_class,
			"side": "crossing",
			"road_clearance_m": road_clearance,
			"points": crossing_points,
			"path_length_m": _polyline_length_3d(crossing_points),
			"seed": int(edge.get("seed", 0)),
		})

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

func _find_nearest_segment_info(position: Vector2, points: Array) -> Dictionary:
	var best_distance := INF
	var best_point := Vector2.ZERO
	var best_tangent := Vector2.ZERO
	for point_index in range(points.size() - 1):
		var a: Vector2 = points[point_index]
		var b: Vector2 = points[point_index + 1]
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
