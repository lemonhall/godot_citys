extends RefCounted

var _provider = null

func _init(provider = null) -> void:
	_provider = provider

func get_cache_contract() -> Dictionary:
	var place_index = _resolve_place_index()
	return {} if place_index == null else place_index.get_cache_contract()

func get_debug_sample_queries() -> Dictionary:
	var place_index = _resolve_place_index()
	return {} if place_index == null else place_index.get_debug_sample_queries()

func get_entry_count() -> int:
	var place_index = _resolve_place_index()
	return 0 if place_index == null else int(place_index.get_entry_count())

func get_entries() -> Array[Dictionary]:
	var place_index = _resolve_place_index()
	return [] if place_index == null else place_index.get_entries()

func get_entry_by_id(place_id: String) -> Dictionary:
	var place_index = _resolve_place_index()
	return {} if place_index == null else place_index.get_entry_by_id(place_id)

func get_entries_for_type(place_type: String) -> Array[Dictionary]:
	var place_index = _resolve_place_index()
	return [] if place_index == null else place_index.get_entries_for_type(place_type)

func get_entries_intersecting_rect(rect: Rect2, allowed_types: Array = []) -> Array[Dictionary]:
	var place_index = _resolve_place_index()
	return [] if place_index == null else place_index.get_entries_intersecting_rect(rect, allowed_types)

func find_best_match(query: String, allowed_types: Array = []) -> Dictionary:
	var place_index = _resolve_place_index()
	return {} if place_index == null else place_index.find_best_match(query, allowed_types)

func _resolve_place_index():
	if _provider == null or not _provider.has_method("get_place_index"):
		return null
	return _provider.get_place_index()
