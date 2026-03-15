extends RefCounted

var _provider = null

func _init(provider = null) -> void:
	_provider = provider

func get_cluster_count() -> int:
	var catalog = _resolve_catalog()
	return 0 if catalog == null else int(catalog.get_cluster_count())

func get_clusters() -> Array[Dictionary]:
	var catalog = _resolve_catalog()
	return [] if catalog == null else catalog.get_clusters()

func get_world_counts() -> Dictionary:
	var catalog = _resolve_catalog()
	return {} if catalog == null else catalog.get_world_counts()

func get_cluster_by_id(cluster_id: String) -> Dictionary:
	var catalog = _resolve_catalog()
	return {} if catalog == null else catalog.get_cluster_by_id(cluster_id)

func get_cluster_for_edge(edge_id: String) -> Dictionary:
	var catalog = _resolve_catalog()
	return {} if catalog == null else catalog.get_cluster_for_edge(edge_id)

func get_edge_canonical_name(edge_id: String) -> String:
	var catalog = _resolve_catalog()
	return "" if catalog == null else str(catalog.get_edge_canonical_name(edge_id))

func get_cluster_ids_by_normalized_name(normalized_name: String) -> Array[String]:
	var catalog = _resolve_catalog()
	return [] if catalog == null else catalog.get_cluster_ids_by_normalized_name(normalized_name)

func get_clusters_intersecting_rect(rect: Rect2) -> Array[Dictionary]:
	var catalog = _resolve_catalog()
	return [] if catalog == null else catalog.get_clusters_intersecting_rect(rect)

func _resolve_catalog():
	if _provider == null or not _provider.has_method("get_street_cluster_catalog"):
		return null
	return _provider.get_street_cluster_catalog()
