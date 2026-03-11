extends Node3D

const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")

var _config
var _world_data: Dictionary = {}
var _chunk_scenes: Dictionary = {}

func setup(config, world_data: Dictionary) -> void:
	_config = config
	_world_data = world_data.duplicate(true)

func sync_streaming(active_chunk_entries: Array, player_position: Vector3) -> void:
	if _config == null:
		return

	var target_chunk_ids: Dictionary = {}
	for entry in active_chunk_entries:
		var chunk_id := str(entry.get("chunk_id", ""))
		target_chunk_ids[chunk_id] = true
		if not _chunk_scenes.has(chunk_id):
			var chunk_scene = CityChunkScene.new()
			chunk_scene.setup(_build_chunk_payload(entry))
			add_child(chunk_scene)
			_chunk_scenes[chunk_id] = chunk_scene

	for chunk_id in get_chunk_ids():
		if target_chunk_ids.has(chunk_id):
			continue
		var chunk_scene: Node3D = _chunk_scenes[chunk_id]
		chunk_scene.queue_free()
		_chunk_scenes.erase(chunk_id)

	for chunk_id in get_chunk_ids():
		var chunk_scene: Node3D = _chunk_scenes[chunk_id]
		chunk_scene.update_lod_for_distance(player_position.distance_to(chunk_scene.position))

func get_chunk_ids() -> Array[String]:
	var ids: Array[String] = []
	for chunk_id in _chunk_scenes.keys():
		ids.append(str(chunk_id))
	ids.sort()
	return ids

func get_chunk_scene_count() -> int:
	return _chunk_scenes.size()

func get_chunk_scene(chunk_id: String):
	return _chunk_scenes.get(chunk_id)

func get_renderer_stats() -> Dictionary:
	var lod_mode_counts := {
		"near": 0,
		"mid": 0,
		"far": 0,
	}
	var multimesh_instance_total := 0
	for chunk_id in get_chunk_ids():
		var chunk_scene = _chunk_scenes[chunk_id]
		var chunk_stats: Dictionary = chunk_scene.get_renderer_stats()
		var lod_mode := str(chunk_stats.get("lod_mode", ""))
		if lod_mode_counts.has(lod_mode):
			lod_mode_counts[lod_mode] += 1
		multimesh_instance_total += int(chunk_stats.get("multimesh_instance_count", 0))
	return {
		"active_rendered_chunk_count": get_chunk_scene_count(),
		"multimesh_instance_total": multimesh_instance_total,
		"lod_mode_counts": lod_mode_counts,
	}

func get_chunk_scene_stats(chunk_id: String) -> Dictionary:
	if not _chunk_scenes.has(chunk_id):
		return {}
	return (_chunk_scenes[chunk_id] as Node).get_renderer_stats()

func _build_chunk_payload(entry: Dictionary) -> Dictionary:
	var chunk_key: Vector2i = entry.get("chunk_key", Vector2i.ZERO)
	return {
		"chunk_id": str(entry.get("chunk_id", "")),
		"chunk_key": chunk_key,
		"chunk_center": _chunk_center_from_key(chunk_key),
		"chunk_size_m": float(_config.chunk_size_m),
		"chunk_seed": _config.derive_seed("render_chunk", chunk_key),
	}

func _chunk_center_from_key(chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = _config.get_world_bounds()
	var center_x := bounds.position.x + (float(chunk_key.x) + 0.5) * float(_config.chunk_size_m)
	var center_z := bounds.position.y + (float(chunk_key.y) + 0.5) * float(_config.chunk_size_m)
	return Vector3(center_x, 0.0, center_z)
