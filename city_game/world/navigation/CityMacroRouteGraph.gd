extends RefCounted

const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")
const CityChunkNavBuilder := preload("res://city_game/world/navigation/CityChunkNavBuilder.gd")

var _config
var _world_data: Dictionary = {}

func _init(config = null, world_data: Dictionary = {}) -> void:
	if config != null:
		setup(config, world_data)

func setup(config, world_data: Dictionary = {}) -> void:
	_config = config
	_world_data = world_data.duplicate(true)

func build_chunk_route(start_chunk_key: Vector2i, goal_chunk_key: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = [start_chunk_key]
	var current := start_chunk_key

	while current.x != goal_chunk_key.x:
		if current.x < goal_chunk_key.x:
			current = Vector2i(current.x + 1, current.y)
		else:
			current = Vector2i(current.x - 1, current.y)
		route.append(current)

	while current.y != goal_chunk_key.y:
		if current.y < goal_chunk_key.y:
			current = Vector2i(current.x, current.y + 1)
		else:
			current = Vector2i(current.x, current.y - 1)
		route.append(current)

	return route

func build_route_between_positions(start_position: Vector3, goal_position: Vector3) -> Array[Dictionary]:
	var start_chunk_key: Vector2i = CityChunkKey.world_to_chunk_key(_config, start_position)
	var goal_chunk_key: Vector2i = CityChunkKey.world_to_chunk_key(_config, goal_position)
	var chunk_route: Array[Vector2i] = build_chunk_route(start_chunk_key, goal_chunk_key)
	var route: Array[Dictionary] = []

	for index in range(1, chunk_route.size()):
		var chunk_key: Vector2i = chunk_route[index]
		var nav_chunk: Dictionary = CityChunkNavBuilder.build_chunk_nav(_config, chunk_key)
		var target_position: Vector3 = nav_chunk["center"]
		if index == chunk_route.size() - 1:
			target_position = goal_position
		route.append({
			"chunk_id": nav_chunk["chunk_id"],
			"chunk_key": chunk_key,
			"target_position": target_position,
		})

	if route.is_empty():
		route.append({
			"chunk_id": _config.format_chunk_id(goal_chunk_key),
			"chunk_key": goal_chunk_key,
			"target_position": goal_position,
		})
	return route
