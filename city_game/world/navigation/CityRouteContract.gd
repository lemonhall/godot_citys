extends RefCounted

const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")

const SOURCE_VERSION := "v12-route-contract-1"

static func build_step(config, target_position: Vector3, step_data: Dictionary = {}) -> Dictionary:
	var chunk_key: Vector2i = CityChunkKey.world_to_chunk_key(config, target_position)
	return {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"target_position": target_position,
		"road_name": str(step_data.get("road_name", "")),
		"lane_node_id": str(step_data.get("lane_node_id", "")),
		"distance_m": float(step_data.get("distance_m", 0.0)),
	}

static func build_maneuver(turn_type: String, distance_to_next_m: float, road_name_from: String, road_name_to: String, world_anchor: Vector3, instruction_short: String) -> Dictionary:
	return {
		"turn_type": turn_type,
		"distance_to_next_m": distance_to_next_m,
		"road_name_from": road_name_from,
		"road_name_to": road_name_to,
		"world_anchor": world_anchor,
		"instruction_short": instruction_short,
	}
