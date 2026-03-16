extends RefCounted

const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")

var _config = null
var _world_data: Dictionary = {}

func setup(config, world_data: Dictionary) -> void:
	_config = config
	_world_data = world_data.duplicate(false)

func resolve_hit(hit: Dictionary, chunk_renderer: Node = null) -> Dictionary:
	if hit.is_empty():
		return {}
	var collider := hit.get("collider") as Node
	if collider != null and collider.has_meta("city_inspection_payload"):
		var payload: Dictionary = collider.get_meta("city_inspection_payload", {})
		if not payload.is_empty():
			return _build_building_result(payload, hit)
	return _build_chunk_result(hit.get("position", Vector3.ZERO), chunk_renderer)

func _build_building_result(payload: Dictionary, hit: Dictionary) -> Dictionary:
	var result := payload.duplicate(true)
	result["inspection_kind"] = "building"
	result["world_position"] = hit.get("position", result.get("world_position", Vector3.ZERO))
	var display_name := str(result.get("display_name", ""))
	var building_id := str(result.get("building_id", ""))
	result["message_text"] = display_name
	result["clipboard_text"] = _build_building_clipboard_text(display_name, building_id, result)
	return result

func _build_chunk_result(world_position: Vector3, chunk_renderer: Node = null) -> Dictionary:
	var chunk_key := Vector2i.ZERO
	var chunk_id := ""
	if _config != null and _config.has_method("format_chunk_id"):
		chunk_key = CityChunkKey.world_to_chunk_key(_config, world_position)
		chunk_id = str(_config.format_chunk_id(chunk_key))
	var chunk_stats: Dictionary = {}
	if chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene_stats") and chunk_id != "":
		chunk_stats = chunk_renderer.get_chunk_scene_stats(chunk_id)
	var lod_mode := str(chunk_stats.get("lod_mode", ""))
	var building_count := int(chunk_stats.get("road_segment_count", 0))
	return {
		"inspection_kind": "chunk",
		"display_name": chunk_id,
		"chunk_id": chunk_id,
		"chunk_key": chunk_key,
		"place_id": "",
		"world_position": world_position,
		"chunk_stats": chunk_stats.duplicate(true),
		"message_text": _build_chunk_message(chunk_id, chunk_key, lod_mode, building_count),
		"clipboard_text": _build_chunk_message(chunk_id, chunk_key, lod_mode, building_count),
	}

func _build_chunk_message(chunk_id: String, chunk_key: Vector2i, lod_mode: String, road_segment_count: int) -> String:
	var message := "Chunk %s (%d,%d)" % [chunk_id, chunk_key.x, chunk_key.y]
	if lod_mode != "":
		message += " | lod=%s" % lod_mode
	if road_segment_count > 0:
		message += " | roads=%d" % road_segment_count
	return message

func _build_building_clipboard_text(display_name: String, building_id: String, result: Dictionary) -> String:
	var parts := PackedStringArray()
	if display_name != "":
		parts.append(display_name)
	if building_id != "":
		parts.append("id=%s" % building_id)
	var place_id := str(result.get("place_id", ""))
	if place_id != "":
		parts.append("place_id=%s" % place_id)
	var chunk_id := str(result.get("chunk_id", ""))
	if chunk_id != "":
		parts.append("chunk_id=%s" % chunk_id)
	return " | ".join(parts)
