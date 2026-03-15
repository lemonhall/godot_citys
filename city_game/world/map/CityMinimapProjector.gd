extends RefCounted

const MAP_SIZE_PX := 220.0
const DEFAULT_WORLD_RADIUS_M := 1600.0

var _config
var _world_data: Dictionary = {}
var _pedestrian_query = null

func _init(config = null, world_data: Dictionary = {}) -> void:
	if config != null:
		setup(config, world_data)

func setup(config, world_data: Dictionary = {}) -> void:
	_config = config
	_world_data = world_data.duplicate(true)
	_pedestrian_query = _world_data.get("pedestrian_query")

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

func build_pedestrian_debug_layer(center_world_position: Vector3, world_radius_m: float = DEFAULT_WORLD_RADIUS_M, visible: bool = false) -> Dictionary:
	var hidden_layer := {
		"visible": false,
		"sidewalk_lane_count": 0,
		"crossing_lane_count": 0,
		"spawn_marker_count": 0,
		"sidewalk_polylines": [],
		"crossing_polylines": [],
		"spawn_markers": [],
		"chunk_samples": [],
	}
	if not visible or _pedestrian_query == null or not _pedestrian_query.has_method("get_lane_graph"):
		return hidden_layer

	var lane_graph = _pedestrian_query.get_lane_graph()
	if lane_graph == null or not lane_graph.has_method("get_lanes_intersecting_rect"):
		return hidden_layer

	var rect := Rect2(
		Vector2(center_world_position.x - world_radius_m, center_world_position.z - world_radius_m),
		Vector2(world_radius_m * 2.0, world_radius_m * 2.0)
	)
	var sidewalk_polylines: Array = []
	var crossing_polylines: Array = []
	var sidewalk_lane_count := 0
	var crossing_lane_count := 0
	for lane_variant in lane_graph.get_lanes_intersecting_rect(rect, ["sidewalk", "crossing"]):
		var lane: Dictionary = lane_variant
		var lane_type := str(lane.get("lane_type", ""))
		var projected_polyline := PackedVector2Array()
		for point_variant in lane.get("points", []):
			var point: Vector3 = point_variant
			projected_polyline.append(_project_point(Vector2(point.x, point.z), center_world_position, world_radius_m))
		if projected_polyline.size() < 2:
			continue
		if lane_type == "crossing":
			crossing_polylines.append(projected_polyline)
			crossing_lane_count += 1
		else:
			sidewalk_polylines.append(projected_polyline)
			sidewalk_lane_count += 1

	var spawn_markers: Array = []
	var chunk_samples: Array = []
	for chunk_key in _collect_visible_chunk_keys(rect):
		var chunk_query: Dictionary = _pedestrian_query.get_pedestrian_query_for_chunk(chunk_key)
		chunk_samples.append({
			"chunk_id": str(chunk_query.get("chunk_id", "")),
			"density_scalar": float(chunk_query.get("density_scalar", 0.0)),
			"density_bucket": str(chunk_query.get("density_bucket", "")),
			"spawn_capacity": int(chunk_query.get("spawn_capacity", 0)),
		})
		for spawn_slot_variant in chunk_query.get("spawn_slots", []):
			var spawn_slot: Dictionary = spawn_slot_variant
			var world_position: Vector3 = spawn_slot.get("world_position", Vector3.ZERO)
			if not rect.has_point(Vector2(world_position.x, world_position.z)):
				continue
			spawn_markers.append({
				"position": _project_point(Vector2(world_position.x, world_position.z), center_world_position, world_radius_m),
				"chunk_id": str(chunk_query.get("chunk_id", "")),
				"spawn_slot_id": str(spawn_slot.get("spawn_slot_id", "")),
			})

	return {
		"visible": true,
		"sidewalk_lane_count": sidewalk_lane_count,
		"crossing_lane_count": crossing_lane_count,
		"spawn_marker_count": spawn_markers.size(),
		"sidewalk_polylines": sidewalk_polylines,
		"crossing_polylines": crossing_polylines,
		"spawn_markers": spawn_markers,
		"chunk_samples": chunk_samples,
	}

func build_player_marker(center_world_position: Vector3, player_world_position: Vector3, player_heading_rad: float, world_radius_m: float = DEFAULT_WORLD_RADIUS_M) -> Dictionary:
	return {
		"position": _project_point(Vector2(player_world_position.x, player_world_position.z), center_world_position, world_radius_m),
		"heading_rad": player_heading_rad,
	}

func build_pin_overlay(center_world_position: Vector3, pins: Array, world_radius_m: float = DEFAULT_WORLD_RADIUS_M) -> Dictionary:
	var visible_rect := Rect2(
		Vector2(center_world_position.x - world_radius_m, center_world_position.z - world_radius_m),
		Vector2(world_radius_m * 2.0, world_radius_m * 2.0)
	)
	var markers: Array[Dictionary] = []
	var pin_types: Array[String] = []
	var pin_type_seen: Dictionary = {}
	for pin_variant in pins:
		var pin: Dictionary = pin_variant
		var world_position: Vector3 = pin.get("world_position", Vector3.ZERO)
		if not visible_rect.has_point(Vector2(world_position.x, world_position.z)):
			continue
		var pin_type := str(pin.get("pin_type", ""))
		if pin_type != "" and not pin_type_seen.has(pin_type):
			pin_type_seen[pin_type] = true
			pin_types.append(pin_type)
		markers.append({
			"pin_id": str(pin.get("pin_id", "")),
			"pin_type": pin_type,
			"title": str(pin.get("title", "")),
			"subtitle": str(pin.get("subtitle", "")),
			"priority": int(pin.get("priority", 0)),
			"icon_id": str(pin.get("icon_id", "")),
			"position": _project_point(Vector2(world_position.x, world_position.z), center_world_position, world_radius_m),
		})
	return {
		"markers": markers,
		"pin_count": markers.size(),
		"pin_types": pin_types,
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

func _collect_visible_chunk_keys(rect: Rect2) -> Array:
	var keys: Array = []
	if _config == null:
		return keys
	var chunk_size := float(_config.chunk_size_m)
	var bounds: Rect2 = _config.get_world_bounds()
	var chunk_grid: Vector2i = _config.get_chunk_grid_size()
	var min_chunk_x := maxi(int(floor((rect.position.x - bounds.position.x) / chunk_size)), 0)
	var max_chunk_x := mini(int(floor((rect.end.x - bounds.position.x) / chunk_size)), chunk_grid.x - 1)
	var min_chunk_y := maxi(int(floor((rect.position.y - bounds.position.y) / chunk_size)), 0)
	var max_chunk_y := mini(int(floor((rect.end.y - bounds.position.y) / chunk_size)), chunk_grid.y - 1)
	for chunk_x in range(min_chunk_x, max_chunk_x + 1):
		for chunk_y in range(min_chunk_y, max_chunk_y + 1):
			keys.append(Vector2i(chunk_x, chunk_y))
	return keys
