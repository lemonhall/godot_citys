extends RefCounted

var _provider = null

func _init(provider = null) -> void:
	_provider = provider

func get_debug_sample_queries() -> Dictionary:
	var place_query = _resolve_place_query()
	return {} if place_query == null else place_query.get_debug_sample_queries()

func resolve_query(query: String) -> Dictionary:
	var place_query = _resolve_place_query()
	return {} if place_query == null else place_query.resolve_query(query)

func resolve_world_point(world_position: Vector3) -> Dictionary:
	var place_query = _resolve_place_query()
	return {} if place_query == null else place_query.resolve_world_point(world_position)

func _resolve_place_query():
	if _provider == null or not _provider.has_method("get_place_query"):
		return null
	return _provider.get_place_query()
