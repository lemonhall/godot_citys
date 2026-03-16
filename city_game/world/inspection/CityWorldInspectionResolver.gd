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
	return _build_ground_probe_result(
		hit.get("position", Vector3.ZERO),
		hit.get("normal", Vector3.UP),
		chunk_renderer
	)

func _build_building_result(payload: Dictionary, hit: Dictionary) -> Dictionary:
	var result := payload.duplicate(true)
	result["inspection_kind"] = "building"
	result["world_position"] = hit.get("position", result.get("world_position", Vector3.ZERO))
	var display_name := str(result.get("display_name", ""))
	var building_id := str(result.get("building_id", ""))
	result["message_text"] = display_name
	result["clipboard_text"] = _build_building_clipboard_text(display_name, building_id, result)
	return result

func _build_ground_probe_result(world_position: Vector3, surface_normal: Vector3, chunk_renderer: Node = null) -> Dictionary:
	var chunk_key := Vector2i.ZERO
	var chunk_id := ""
	if _config != null and _config.has_method("format_chunk_id"):
		chunk_key = CityChunkKey.world_to_chunk_key(_config, world_position)
		chunk_id = str(_config.format_chunk_id(chunk_key))
	var chunk_center := _resolve_chunk_center(chunk_key)
	var chunk_local_position := world_position - chunk_center
	var surface_y_m := world_position.y
	var chunk_stats: Dictionary = {}
	if chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene_stats") and chunk_id != "":
		chunk_stats = chunk_renderer.get_chunk_scene_stats(chunk_id)
	var lod_mode := str(chunk_stats.get("lod_mode", ""))
	var road_segment_count := int(chunk_stats.get("road_segment_count", 0))
	var message_text := _build_ground_probe_message(chunk_id, chunk_key, lod_mode, road_segment_count, chunk_local_position, surface_y_m)
	return {
		"inspection_kind": "ground_probe",
		"display_name": chunk_id,
		"chunk_id": chunk_id,
		"chunk_key": chunk_key,
		"place_id": "",
		"world_position": world_position,
		"surface_y_m": surface_y_m,
		"chunk_local_position": chunk_local_position,
		"surface_normal": surface_normal,
		"chunk_stats": chunk_stats.duplicate(true),
		"message_text": message_text,
		"clipboard_text": _build_ground_probe_clipboard_text(chunk_id, chunk_key, world_position, surface_y_m, chunk_local_position, surface_normal, lod_mode, road_segment_count),
	}

func _build_chunk_message(chunk_id: String, chunk_key: Vector2i, lod_mode: String, road_segment_count: int) -> String:
	var message := "Chunk %s (%d,%d)" % [chunk_id, chunk_key.x, chunk_key.y]
	if lod_mode != "":
		message += " | lod=%s" % lod_mode
	if road_segment_count > 0:
		message += " | roads=%d" % road_segment_count
	return message

func _build_ground_probe_message(chunk_id: String, chunk_key: Vector2i, lod_mode: String, road_segment_count: int, chunk_local_position: Vector3, surface_y_m: float) -> String:
	var message := _build_chunk_message(chunk_id, chunk_key, lod_mode, road_segment_count)
	message += " | y=%.2f" % surface_y_m
	message += " | local=%s" % _format_vector3(chunk_local_position)
	return message

func _build_ground_probe_clipboard_text(chunk_id: String, chunk_key: Vector2i, world_position: Vector3, surface_y_m: float, chunk_local_position: Vector3, surface_normal: Vector3, lod_mode: String, road_segment_count: int) -> String:
	var parts := PackedStringArray()
	parts.append(_build_chunk_message(chunk_id, chunk_key, lod_mode, road_segment_count))
	parts.append("y=%.2f" % surface_y_m)
	parts.append("world=%s" % _format_vector3(world_position))
	parts.append("local=%s" % _format_vector3(chunk_local_position))
	parts.append("normal=%s" % _format_vector3(surface_normal))
	return " | ".join(parts)

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

func _resolve_chunk_center(chunk_key: Vector2i) -> Vector3:
	if _config == null or not _config.has_method("get_world_bounds"):
		return Vector3.ZERO
	var bounds: Rect2 = _config.get_world_bounds()
	var chunk_size_m := float(_config.chunk_size_m)
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * chunk_size_m,
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * chunk_size_m
	)

func _format_vector3(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
