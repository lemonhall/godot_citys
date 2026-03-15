extends RefCounted

var _entries: Dictionary = {}
var _hit_count := 0
var _miss_count := 0

func build_cache_key(origin_target_id: String, destination_target_id: String, graph_version: String, reroute_generation: int) -> String:
	return "%s|%s|%s|%d" % [origin_target_id, destination_target_id, graph_version, reroute_generation]

func get_route(cache_key: String) -> Dictionary:
	if not _entries.has(cache_key):
		_miss_count += 1
		return {}
	_hit_count += 1
	return (_entries[cache_key] as Dictionary).duplicate(true)

func store_route(cache_key: String, route_result: Dictionary) -> void:
	_entries[cache_key] = route_result.duplicate(true)

func clear() -> void:
	_entries.clear()
	_hit_count = 0
	_miss_count = 0

func get_stats() -> Dictionary:
	return {
		"entry_count": _entries.size(),
		"hit_count": _hit_count,
		"miss_count": _miss_count,
	}
