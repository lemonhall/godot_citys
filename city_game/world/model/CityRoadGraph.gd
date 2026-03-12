extends RefCounted

const SPATIAL_CELL_SIZE_M := 512.0

var nodes: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var _nodes_by_id: Dictionary = {}
var _edges_by_id: Dictionary = {}
var _growth_stats: Dictionary = {}
var _intersections: Array[Dictionary] = []
var _edge_indices_by_cell: Dictionary = {}
var _query_stats := {
	"last_candidate_count": 0,
	"last_result_count": 0,
	"query_count": 0,
}

func add_node(node_data: Dictionary) -> void:
	var stored := node_data.duplicate(true)
	nodes.append(stored)
	_nodes_by_id[str(stored.get("district_id", ""))] = stored

func add_edge(edge_data: Dictionary) -> void:
	var stored := edge_data.duplicate(true)
	if not stored.has("bounds"):
		stored["bounds"] = _build_bounds(stored.get("points", []))
	edges.append(stored)
	var road_id := str(stored.get("road_id", stored.get("edge_id", "")))
	if road_id != "":
		_edges_by_id[road_id] = stored
	var edge_id := str(stored.get("edge_id", ""))
	if edge_id != "":
		_edges_by_id[edge_id] = stored
	_register_edge_in_spatial_index(edges.size() - 1, stored.get("bounds", Rect2()))

func to_cache_payload() -> Dictionary:
	return {
		"nodes": nodes.duplicate(true),
		"edges": edges.duplicate(true),
		"growth_stats": _growth_stats.duplicate(true),
		"intersections": _intersections.duplicate(true),
	}

func load_from_cache_payload(payload: Dictionary) -> void:
	nodes.clear()
	edges.clear()
	_nodes_by_id.clear()
	_edges_by_id.clear()
	_growth_stats.clear()
	_intersections.clear()
	_edge_indices_by_cell.clear()
	reset_query_stats()

	for node in payload.get("nodes", []):
		add_node(node)
	for edge in payload.get("edges", []):
		add_edge(edge)
	set_growth_stats(payload.get("growth_stats", {}))
	set_intersections(payload.get("intersections", []))

func get_node_count() -> int:
	return nodes.size()

func get_edge_count() -> int:
	return edges.size()

func get_node_by_id(district_id: String) -> Dictionary:
	if not _nodes_by_id.has(district_id):
		return {}
	return (_nodes_by_id[district_id] as Dictionary).duplicate(true)

func get_edge_by_id(edge_id: String) -> Dictionary:
	if not _edges_by_id.has(edge_id):
		return {}
	return (_edges_by_id[edge_id] as Dictionary).duplicate(true)

func get_edges_intersecting_rect(rect: Rect2, allowed_classes: Array = []) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var candidate_indices := _collect_candidate_edge_indices(rect)
	for edge_index in candidate_indices:
		var edge_dict: Dictionary = edges[edge_index]
		var road_class := str(edge_dict.get("class", ""))
		if not allowed_classes.is_empty() and not allowed_classes.has(road_class):
			continue
		var bounds: Rect2 = edge_dict.get("bounds", Rect2())
		if not bounds.intersects(rect):
			continue
		results.append(edge_dict.duplicate(true))
	_query_stats["query_count"] = int(_query_stats.get("query_count", 0)) + 1
	_query_stats["last_candidate_count"] = candidate_indices.size()
	_query_stats["last_result_count"] = results.size()
	return results

func get_query_stats() -> Dictionary:
	return _query_stats.duplicate(true)

func reset_query_stats() -> void:
	_query_stats = {
		"last_candidate_count": 0,
		"last_result_count": 0,
		"query_count": 0,
	}

func set_growth_stats(stats: Dictionary) -> void:
	_growth_stats = stats.duplicate(true)

func get_growth_stats() -> Dictionary:
	return _growth_stats.duplicate(true)

func set_intersections(intersections: Array) -> void:
	_intersections.clear()
	for intersection in intersections:
		_intersections.append((intersection as Dictionary).duplicate(true))

func get_intersections_in_rect(rect: Rect2) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for intersection in _intersections:
		var entry: Dictionary = intersection
		var position: Vector2 = entry.get("position", Vector2.ZERO)
		if rect.has_point(position):
			results.append(entry.duplicate(true))
	return results

func _build_bounds(points: Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in points:
		var world_point: Vector2 = point
		min_x = minf(min_x, world_point.x)
		min_y = minf(min_y, world_point.y)
		max_x = maxf(max_x, world_point.x)
		max_y = maxf(max_y, world_point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _register_edge_in_spatial_index(edge_index: int, bounds: Rect2) -> void:
	var min_cell_x := _world_to_cell_coord(bounds.position.x)
	var max_cell_x := _world_to_cell_coord(bounds.end.x)
	var min_cell_y := _world_to_cell_coord(bounds.position.y)
	var max_cell_y := _world_to_cell_coord(bounds.end.y)
	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var cell_key := _build_spatial_cell_key(cell_x, cell_y)
			if not _edge_indices_by_cell.has(cell_key):
				_edge_indices_by_cell[cell_key] = []
			(_edge_indices_by_cell[cell_key] as Array).append(edge_index)

func _collect_candidate_edge_indices(rect: Rect2) -> Array[int]:
	var candidate_map: Dictionary = {}
	var min_cell_x := _world_to_cell_coord(rect.position.x)
	var max_cell_x := _world_to_cell_coord(rect.end.x)
	var min_cell_y := _world_to_cell_coord(rect.position.y)
	var max_cell_y := _world_to_cell_coord(rect.end.y)
	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var cell_key := _build_spatial_cell_key(cell_x, cell_y)
			if not _edge_indices_by_cell.has(cell_key):
				continue
			for edge_index in _edge_indices_by_cell[cell_key]:
				candidate_map[int(edge_index)] = true
	var candidate_indices: Array[int] = []
	for edge_index in candidate_map.keys():
		candidate_indices.append(int(edge_index))
	candidate_indices.sort()
	return candidate_indices

func _world_to_cell_coord(value: float) -> int:
	return int(floor(value / SPATIAL_CELL_SIZE_M))

func _build_spatial_cell_key(cell_x: int, cell_y: int) -> String:
	return "%d:%d" % [cell_x, cell_y]
