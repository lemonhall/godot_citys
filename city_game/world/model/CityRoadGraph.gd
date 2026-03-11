extends RefCounted

var nodes: Array[Dictionary] = []
var edges: Array[Dictionary] = []

func add_node(node_data: Dictionary) -> void:
	nodes.append(node_data)

func add_edge(edge_data: Dictionary) -> void:
	edges.append(edge_data)

func get_node_count() -> int:
	return nodes.size()

func get_edge_count() -> int:
	return edges.size()

