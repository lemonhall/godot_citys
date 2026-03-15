extends RefCounted

var _clusters: Array[Dictionary] = []
var _clusters_by_id: Dictionary = {}
var _cluster_ids_by_edge: Dictionary = {}
var _cluster_ids_by_normalized_name: Dictionary = {}
var _world_counts: Dictionary = {}

func setup(clusters: Array, cluster_ids_by_edge: Dictionary, world_counts: Dictionary) -> void:
	_clusters.clear()
	_clusters_by_id.clear()
	_cluster_ids_by_edge = cluster_ids_by_edge.duplicate(true)
	_cluster_ids_by_normalized_name.clear()
	_world_counts = world_counts.duplicate(true)
	for cluster_variant in clusters:
		var stored := (cluster_variant as Dictionary).duplicate(true)
		var cluster_id := str(stored.get("street_cluster_id", ""))
		if cluster_id == "":
			continue
		_clusters.append(stored)
		_clusters_by_id[cluster_id] = stored
		var normalized_name := str(stored.get("normalized_name", ""))
		if normalized_name != "":
			if not _cluster_ids_by_normalized_name.has(normalized_name):
				_cluster_ids_by_normalized_name[normalized_name] = []
			(_cluster_ids_by_normalized_name[normalized_name] as Array).append(cluster_id)

func get_cluster_count() -> int:
	return _clusters.size()

func get_clusters() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for cluster_variant in _clusters:
		results.append((cluster_variant as Dictionary).duplicate(true))
	return results

func get_world_counts() -> Dictionary:
	return _world_counts.duplicate(true)

func get_cluster_by_id(cluster_id: String) -> Dictionary:
	if not _clusters_by_id.has(cluster_id):
		return {}
	return (_clusters_by_id[cluster_id] as Dictionary).duplicate(true)

func get_cluster_for_edge(edge_id: String) -> Dictionary:
	var cluster_id := str(_cluster_ids_by_edge.get(edge_id, ""))
	if cluster_id == "":
		return {}
	return get_cluster_by_id(cluster_id)

func get_edge_canonical_name(edge_id: String) -> String:
	return str(get_cluster_for_edge(edge_id).get("canonical_name", ""))

func get_cluster_ids_by_normalized_name(normalized_name: String) -> Array[String]:
	if not _cluster_ids_by_normalized_name.has(normalized_name):
		return []
	var results: Array[String] = []
	for cluster_id_variant in _cluster_ids_by_normalized_name[normalized_name]:
		results.append(str(cluster_id_variant))
	return results

func get_clusters_intersecting_rect(rect: Rect2) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for cluster_variant in _clusters:
		var cluster: Dictionary = cluster_variant
		var bounds: Rect2 = cluster.get("bounds", Rect2())
		if bounds.intersects(rect):
			results.append(cluster.duplicate(true))
	return results
