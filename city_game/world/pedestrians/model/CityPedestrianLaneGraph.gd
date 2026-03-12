extends RefCounted

const SPATIAL_CELL_SIZE_M := 512.0
const BOUNDARY_EPSILON := 0.25

var lanes: Array[Dictionary] = []
var _lanes_by_id: Dictionary = {}
var _lane_indices_by_cell: Dictionary = {}
var _lane_type_counts: Dictionary = {}

func add_lane(lane_data: Dictionary) -> void:
	var stored := lane_data.duplicate(true)
	if not stored.has("bounds"):
		stored["bounds"] = _build_bounds(stored.get("points", []))
	lanes.append(stored)
	var lane_index := lanes.size() - 1
	var lane_id := str(stored.get("lane_id", ""))
	_lanes_by_id[lane_id] = stored
	var lane_type := str(stored.get("lane_type", ""))
	_lane_type_counts[lane_type] = int(_lane_type_counts.get(lane_type, 0)) + 1
	_register_lane_in_spatial_index(lane_index, stored.get("bounds", Rect2()))

func get_lane_count() -> int:
	return lanes.size()

func get_lane_by_id(lane_id: String) -> Dictionary:
	if not _lanes_by_id.has(lane_id):
		return {}
	return (_lanes_by_id[lane_id] as Dictionary).duplicate(true)

func get_lane_type_count(lane_type: String) -> int:
	return int(_lane_type_counts.get(lane_type, 0))

func get_lanes_intersecting_rect(rect: Rect2, allowed_types: Array = []) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var candidate_indices := _collect_candidate_lane_indices(rect)
	for lane_index in candidate_indices:
		var lane_dict: Dictionary = lanes[lane_index]
		var lane_type := str(lane_dict.get("lane_type", ""))
		if not allowed_types.is_empty() and not allowed_types.has(lane_type):
			continue
		var bounds: Rect2 = lane_dict.get("bounds", Rect2())
		if not bounds.intersects(rect):
			continue
		results.append(lane_dict.duplicate(true))
	return results

func get_boundary_connectors_for_rect(rect: Rect2, allowed_types: Array = []) -> Dictionary:
	var connectors := {
		"west": [],
		"east": [],
		"north": [],
		"south": [],
	}
	var seen_keys: Dictionary = {}
	var lanes_in_rect := get_lanes_intersecting_rect(rect.grow(2.0), allowed_types)
	for lane_variant in lanes_in_rect:
		var lane: Dictionary = lane_variant
		var points: Array = lane.get("points", [])
		var lane_id := str(lane.get("lane_id", ""))
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			_try_append_boundary_connector(connectors, seen_keys, lane_id, "west", rect.position.x, true, a, b, rect)
			_try_append_boundary_connector(connectors, seen_keys, lane_id, "east", rect.end.x, true, a, b, rect)
			_try_append_boundary_connector(connectors, seen_keys, lane_id, "north", rect.position.y, false, a, b, rect)
			_try_append_boundary_connector(connectors, seen_keys, lane_id, "south", rect.end.y, false, a, b, rect)
	for side in connectors.keys():
		(connectors[side] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("offset", 0.0)) < float(b.get("offset", 0.0))
		)
	return connectors

func _try_append_boundary_connector(connectors: Dictionary, seen_keys: Dictionary, lane_id: String, side: String, boundary_value: float, vertical_boundary: bool, a: Vector3, b: Vector3, rect: Rect2) -> void:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var axis_a := a2.x if vertical_boundary else a2.y
	var axis_b := b2.x if vertical_boundary else b2.y
	if absf(axis_a - axis_b) <= 0.0001:
		if absf(axis_a - boundary_value) > BOUNDARY_EPSILON:
			return
	else:
		var min_axis := minf(axis_a, axis_b)
		var max_axis := maxf(axis_a, axis_b)
		if boundary_value < min_axis - BOUNDARY_EPSILON or boundary_value > max_axis + BOUNDARY_EPSILON:
			return
	var t := 0.0 if absf(axis_a - axis_b) <= 0.0001 else clampf((boundary_value - axis_a) / (axis_b - axis_a), 0.0, 1.0)
	var point := a2.lerp(b2, t)
	if vertical_boundary:
		if point.y < rect.position.y - BOUNDARY_EPSILON or point.y > rect.end.y + BOUNDARY_EPSILON:
			return
	else:
		if point.x < rect.position.x - BOUNDARY_EPSILON or point.x > rect.end.x + BOUNDARY_EPSILON:
			return
	var offset := point.y - rect.position.y if vertical_boundary else point.x - rect.position.x
	var dedupe_key := "%s:%s:%d" % [side, lane_id, int(round(offset * 10.0))]
	if seen_keys.has(dedupe_key):
		return
	seen_keys[dedupe_key] = true
	(connectors[side] as Array).append({
		"lane_id": lane_id,
		"offset": offset,
	})

func _build_bounds(points: Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in points:
		var world_point: Vector3 = point
		min_x = minf(min_x, world_point.x)
		min_y = minf(min_y, world_point.z)
		max_x = maxf(max_x, world_point.x)
		max_y = maxf(max_y, world_point.z)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _register_lane_in_spatial_index(lane_index: int, bounds: Rect2) -> void:
	var min_cell_x := _world_to_cell_coord(bounds.position.x)
	var max_cell_x := _world_to_cell_coord(bounds.end.x)
	var min_cell_y := _world_to_cell_coord(bounds.position.y)
	var max_cell_y := _world_to_cell_coord(bounds.end.y)
	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var cell_key := _build_spatial_cell_key(cell_x, cell_y)
			if not _lane_indices_by_cell.has(cell_key):
				_lane_indices_by_cell[cell_key] = []
			(_lane_indices_by_cell[cell_key] as Array).append(lane_index)

func _collect_candidate_lane_indices(rect: Rect2) -> Array[int]:
	var candidate_map: Dictionary = {}
	var min_cell_x := _world_to_cell_coord(rect.position.x)
	var max_cell_x := _world_to_cell_coord(rect.end.x)
	var min_cell_y := _world_to_cell_coord(rect.position.y)
	var max_cell_y := _world_to_cell_coord(rect.end.y)
	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var cell_key := _build_spatial_cell_key(cell_x, cell_y)
			if not _lane_indices_by_cell.has(cell_key):
				continue
			for lane_index in _lane_indices_by_cell[cell_key]:
				candidate_map[int(lane_index)] = true
	var candidate_indices: Array[int] = []
	for lane_index in candidate_map.keys():
		candidate_indices.append(int(lane_index))
	candidate_indices.sort()
	return candidate_indices

func _world_to_cell_coord(value: float) -> int:
	return int(floor(value / SPATIAL_CELL_SIZE_M))

func _build_spatial_cell_key(cell_x: int, cell_y: int) -> String:
	return "%d:%d" % [cell_x, cell_y]
