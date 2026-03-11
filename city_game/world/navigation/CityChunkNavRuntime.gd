extends RefCounted

const CityChunkNavBuilder := preload("res://city_game/world/navigation/CityChunkNavBuilder.gd")
const CityMacroRouteGraph := preload("res://city_game/world/navigation/CityMacroRouteGraph.gd")

var _config
var _world_data: Dictionary = {}
var _macro_route_graph

func _init(config = null, world_data: Dictionary = {}) -> void:
	if config != null:
		setup(config, world_data)

func setup(config, world_data: Dictionary = {}) -> void:
	_config = config
	_world_data = world_data.duplicate(true)
	_macro_route_graph = CityMacroRouteGraph.new(_config, _world_data)

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
	return _macro_route_graph.build_route_between_positions(start_position, goal_position)
