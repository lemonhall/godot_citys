extends RefCounted

var nodes: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var _nodes_by_id: Dictionary = {}
var _growth_stats: Dictionary = {}
var _intersections: Array[Dictionary] = []

func add_node(node_data: Dictionary) -> void:
	var stored := node_data.duplicate(true)
	nodes.append(stored)
	_nodes_by_id[str(stored.get("district_id", ""))] = stored

func add_edge(edge_data: Dictionary) -> void:
	var stored := edge_data.duplicate(true)
	if not stored.has("bounds"):
		stored["bounds"] = _build_bounds(stored.get("points", []))
	edges.append(stored)

func get_node_count() -> int:
	return nodes.size()

func get_edge_count() -> int:
	return edges.size()

func get_node_by_id(district_id: String) -> Dictionary:
	if not _nodes_by_id.has(district_id):
		return {}
	return (_nodes_by_id[district_id] as Dictionary).duplicate(true)

func get_edges_intersecting_rect(rect: Rect2, allowed_classes: Array = []) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for edge in edges:
		var edge_dict: Dictionary = edge
		var road_class := str(edge_dict.get("class", ""))
		if not allowed_classes.is_empty() and not allowed_classes.has(road_class):
			continue
		var bounds: Rect2 = edge_dict.get("bounds", Rect2())
		if not bounds.intersects(rect):
			continue
		results.append(edge_dict.duplicate(true))
	return results

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
