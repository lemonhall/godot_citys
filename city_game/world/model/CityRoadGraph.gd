extends RefCounted

var nodes: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var _nodes_by_id: Dictionary = {}

func add_node(node_data: Dictionary) -> void:
	var stored := node_data.duplicate(true)
	nodes.append(stored)
	_nodes_by_id[str(stored.get("district_id", ""))] = stored

func add_edge(edge_data: Dictionary) -> void:
	edges.append(edge_data.duplicate(true))

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
