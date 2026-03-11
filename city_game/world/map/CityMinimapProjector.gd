extends RefCounted

const MAP_SIZE_PX := 220.0
const DEFAULT_WORLD_RADIUS_M := 1600.0

var _config
var _world_data: Dictionary = {}

func _init(config = null, world_data: Dictionary = {}) -> void:
	if config != null:
		setup(config, world_data)

func setup(config, world_data: Dictionary = {}) -> void:
	_config = config
	_world_data = world_data.duplicate(true)

func build_snapshot(center_world_position: Vector3, player_world_position: Vector3, player_heading_rad: float, route_world_positions: Array = [], world_radius_m: float = DEFAULT_WORLD_RADIUS_M) -> Dictionary:
	var snapshot := build_road_snapshot(center_world_position, world_radius_m)
	snapshot["player_marker"] = build_player_marker(center_world_position, player_world_position, player_heading_rad, world_radius_m)
	snapshot["route_overlay"] = build_route_overlay_from_world_positions(center_world_position, route_world_positions, world_radius_m)
	return snapshot

func build_road_snapshot(center_world_position: Vector3, world_radius_m: float = DEFAULT_WORLD_RADIUS_M) -> Dictionary:
	var road_graph = _world_data.get("road_graph")
	var rect := Rect2(
		Vector2(center_world_position.x - world_radius_m, center_world_position.z - world_radius_m),
		Vector2(world_radius_m * 2.0, world_radius_m * 2.0)
	)
	var road_polylines: Array = []
	if road_graph != null and road_graph.has_method("get_edges_intersecting_rect"):
		for edge in road_graph.get_edges_intersecting_rect(rect):
			var polyline: PackedVector2Array = PackedVector2Array()
			for point in (edge as Dictionary).get("points", []):
				var world_point: Vector2 = point
				polyline.append(_project_point(world_point, center_world_position, world_radius_m))
			if polyline.size() >= 2:
				road_polylines.append(polyline)
	return {
		"map_size_px": MAP_SIZE_PX,
		"world_radius_m": world_radius_m,
		"center_world": {
			"x": center_world_position.x,
			"z": center_world_position.z,
		},
		"road_polylines": road_polylines,
	}

func build_player_marker(center_world_position: Vector3, player_world_position: Vector3, player_heading_rad: float, world_radius_m: float = DEFAULT_WORLD_RADIUS_M) -> Dictionary:
	return {
		"position": _project_point(Vector2(player_world_position.x, player_world_position.z), center_world_position, world_radius_m),
		"heading_rad": player_heading_rad,
	}

func build_route_overlay(center_world_position: Vector3, start_world_position: Vector3, goal_world_position: Vector3, route: Array, world_radius_m: float = DEFAULT_WORLD_RADIUS_M) -> Dictionary:
	var route_world_positions: Array[Vector3] = [start_world_position]
	for step in route:
		route_world_positions.append((step as Dictionary).get("target_position", goal_world_position))
	return build_route_overlay_from_world_positions(center_world_position, route_world_positions, world_radius_m)

func build_route_overlay_from_world_positions(center_world_position: Vector3, route_world_positions: Array, world_radius_m: float = DEFAULT_WORLD_RADIUS_M) -> Dictionary:
	return _project_route(route_world_positions, center_world_position, world_radius_m)

func _project_route(route_world_positions: Array, center_world_position: Vector3, world_radius_m: float) -> Dictionary:
	var polyline: PackedVector2Array = PackedVector2Array()
	for world_position in route_world_positions:
		var point3: Vector3 = world_position
		polyline.append(_project_point(Vector2(point3.x, point3.z), center_world_position, world_radius_m))
	if polyline.is_empty():
		return {}
	return {
		"polyline": polyline,
		"start_marker": {"position": polyline[0]},
		"goal_marker": {"position": polyline[polyline.size() - 1]},
	}

func _project_point(world_point: Vector2, center_world_position: Vector3, world_radius_m: float) -> Vector2:
	var normalized := Vector2(
		clampf((world_point.x - center_world_position.x) / world_radius_m, -1.0, 1.0),
		clampf((world_point.y - center_world_position.z) / world_radius_m, -1.0, 1.0)
	)
	return Vector2(
		(normalized.x * 0.5 + 0.5) * MAP_SIZE_PX,
		(normalized.y * 0.5 + 0.5) * MAP_SIZE_PX
	)
