extends RefCounted

const CityChunkNavBuilder := preload("res://city_game/world/navigation/CityChunkNavBuilder.gd")
const CityMacroRouteGraph := preload("res://city_game/world/navigation/CityMacroRouteGraph.gd")
const CityRoutePlanner := preload("res://city_game/world/navigation/CityRoutePlanner.gd")
const CityRouteCache := preload("res://city_game/world/navigation/CityRouteCache.gd")

var _config
var _world_data: Dictionary = {}
var _macro_route_graph
var _route_planner
var _route_cache := CityRouteCache.new()
var _place_query = null

func _init(config = null, world_data: Dictionary = {}) -> void:
	if config != null:
		setup(config, world_data)

func setup(config, world_data: Dictionary = {}) -> void:
	_config = config
	_world_data = world_data
	_macro_route_graph = CityMacroRouteGraph.new(_config, _world_data)
	_route_planner = CityRoutePlanner.new(_config, _world_data)
	_place_query = _world_data.get("place_query")

func are_adjacent_chunks_connected(chunk_key_a: Vector2i, chunk_key_b: Vector2i) -> bool:
	if absi(chunk_key_a.x - chunk_key_b.x) + absi(chunk_key_a.y - chunk_key_b.y) != 1:
		return false
	var portals: Dictionary = get_boundary_portals(chunk_key_a, chunk_key_b)
	if not portals.has("from_exit") or not portals.has("to_entry"):
		return false
	return portals["from_exit"].distance_to(portals["to_entry"]) <= 0.01

func get_boundary_portals(chunk_key_a: Vector2i, chunk_key_b: Vector2i) -> Dictionary:
	var nav_a: Dictionary = CityChunkNavBuilder.build_chunk_nav(_config, chunk_key_a)
	var nav_b: Dictionary = CityChunkNavBuilder.build_chunk_nav(_config, chunk_key_b)
	var portals_a: Dictionary = nav_a["portals"]
	var portals_b: Dictionary = nav_b["portals"]

	if chunk_key_b.x == chunk_key_a.x + 1:
		return {"from_exit": portals_a["east"], "to_entry": portals_b["west"]}
	if chunk_key_b.x == chunk_key_a.x - 1:
		return {"from_exit": portals_a["west"], "to_entry": portals_b["east"]}
	if chunk_key_b.y == chunk_key_a.y + 1:
		return {"from_exit": portals_a["south"], "to_entry": portals_b["north"]}
	if chunk_key_b.y == chunk_key_a.y - 1:
		return {"from_exit": portals_a["north"], "to_entry": portals_b["south"]}
	return {}

func plan_route(start_position: Vector3, goal_position: Vector3) -> Array[Dictionary]:
	var origin_target: Dictionary = _resolve_raw_world_target(start_position)
	var destination_target: Dictionary = _resolve_raw_world_target(goal_position)
	var route_result: Dictionary = plan_route_result(origin_target, destination_target, 0)
	return route_result.get("steps", [])

func plan_route_result(origin_target: Dictionary, destination_target: Dictionary, reroute_generation: int = 0) -> Dictionary:
	if _route_planner == null or origin_target.is_empty() or destination_target.is_empty():
		return {}
	var cache_key := _route_cache.build_cache_key(
		_resolve_target_cache_id(origin_target),
		_resolve_target_cache_id(destination_target),
		_route_planner.get_graph_version(),
		reroute_generation
	)
	var cached_result: Dictionary = _route_cache.get_route(cache_key)
	if not cached_result.is_empty():
		return cached_result
	var route_result: Dictionary = _route_planner.plan_route(origin_target, destination_target, reroute_generation)
	if route_result.is_empty():
		route_result = _plan_route_with_origin_fallbacks(origin_target, destination_target, reroute_generation)
	if route_result.is_empty():
		return {}
	_route_cache.store_route(cache_key, route_result)
	return route_result

func reroute_from_world_position(current_world_position: Vector3, destination_target: Dictionary, previous_generation: int = 0) -> Dictionary:
	var origin_target := _resolve_raw_world_target(current_world_position)
	return plan_route_result(origin_target, destination_target, previous_generation + 1)

func get_route_cache_stats() -> Dictionary:
	return _route_cache.get_stats()

func get_route_graph_version() -> String:
	return "" if _route_planner == null else _route_planner.get_graph_version()

func get_route_debug_graph_stats() -> Dictionary:
	if _route_planner == null or not _route_planner.has_method("get_debug_graph_stats"):
		return {}
	return _route_planner.get_debug_graph_stats()

func debug_plan_route(origin_target: Dictionary, destination_target: Dictionary) -> Dictionary:
	if _route_planner == null or not _route_planner.has_method("debug_plan_route"):
		return {}
	return _route_planner.debug_plan_route(origin_target, destination_target)

func _resolve_raw_world_target(world_position: Vector3) -> Dictionary:
	if _place_query != null and _place_query.has_method("resolve_world_point"):
		return _place_query.resolve_world_point(world_position)
	return {
		"place_id": "",
		"world_anchor": world_position,
		"routable_anchor": world_position,
	}

func _resolve_target_cache_id(target: Dictionary) -> String:
	var place_id := str(target.get("place_id", ""))
	if place_id != "":
		return place_id
	var anchor: Vector3 = target.get("routable_anchor", target.get("world_anchor", Vector3.ZERO))
	return "raw:%d:%d:%d" % [int(round(anchor.x)), int(round(anchor.y)), int(round(anchor.z))]

func _plan_route_with_origin_fallbacks(origin_target: Dictionary, destination_target: Dictionary, reroute_generation: int) -> Dictionary:
	for origin_candidate in _build_origin_fallback_targets(origin_target):
		var route_result: Dictionary = _route_planner.plan_route(origin_candidate, destination_target, reroute_generation)
		if not route_result.is_empty():
			return route_result
	return {}

func _build_origin_fallback_targets(origin_target: Dictionary) -> Array[Dictionary]:
	if _place_query == null or not _place_query.has_method("resolve_world_point"):
		return []
	var base_world_anchor: Vector3 = origin_target.get("raw_world_anchor", origin_target.get("world_anchor", origin_target.get("routable_anchor", Vector3.ZERO)))
	var seen_cache_ids: Dictionary = {}
	var fallback_targets: Array[Dictionary] = []
	for radius in [128.0, 256.0, 384.0, 512.0]:
		for offset_variant in [
			Vector3(radius, 0.0, 0.0),
			Vector3(-radius, 0.0, 0.0),
			Vector3(0.0, 0.0, radius),
			Vector3(0.0, 0.0, -radius),
			Vector3(radius, 0.0, radius),
			Vector3(-radius, 0.0, radius),
			Vector3(radius, 0.0, -radius),
			Vector3(-radius, 0.0, -radius),
		]:
			var offset: Vector3 = offset_variant
			var candidate_target: Dictionary = _place_query.resolve_world_point(base_world_anchor + offset)
			if candidate_target.is_empty():
				continue
			var cache_id := _resolve_target_cache_id(candidate_target)
			if seen_cache_ids.has(cache_id):
				continue
			seen_cache_ids[cache_id] = true
			fallback_targets.append(candidate_target)
	return fallback_targets
