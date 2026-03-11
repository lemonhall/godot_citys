extends Node3D

const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")

const PREPARE_BUDGET_PER_TICK := 1
const MOUNT_BUDGET_PER_TICK := 1
const RETIRE_BUDGET_PER_TICK := 1
const MAX_POOLED_CHUNKS := 8

var _config
var _world_data: Dictionary = {}
var _chunk_scenes: Dictionary = {}
var _prepared_payloads: Dictionary = {}
var _pending_prepare: Dictionary = {}
var _pending_mount_ids: Array[String] = []
var _pending_retire_ids: Array[String] = []
var _scene_pool: Array[Node3D] = []
var _last_player_position := Vector3.ZERO
var _last_prepare_usec := 0
var _last_mount_usec := 0
var _last_retire_usec := 0
var _last_prepare_count := 0
var _last_mount_count := 0
var _last_retire_count := 0
var _last_queue_process_frame := -1
var _prepare_profile_sample_count := 0
var _prepare_profile_total_usec := 0
var _prepare_profile_max_usec := 0
var _prepare_profile_last_usec := 0
var _mount_setup_sample_count := 0
var _mount_setup_total_usec := 0
var _mount_setup_max_usec := 0
var _mount_setup_last_usec := 0

func setup(config, world_data: Dictionary) -> void:
	_config = config
	_world_data = world_data.duplicate(true)
	_prepared_payloads.clear()
	_pending_prepare.clear()
	_pending_mount_ids.clear()
	_pending_retire_ids.clear()
	_last_prepare_usec = 0
	_last_mount_usec = 0
	_last_retire_usec = 0
	_last_prepare_count = 0
	_last_mount_count = 0
	_last_retire_count = 0
	_last_queue_process_frame = -1
	reset_streaming_profile_stats()
	set_process(true)

func _process(_delta: float) -> void:
	_process_streaming_queues_once_per_frame()
	_update_lod_states(_last_player_position)

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	for chunk_scene in _scene_pool:
		if is_instance_valid(chunk_scene):
			chunk_scene.free()
	_scene_pool.clear()
	for chunk_scene in _chunk_scenes.values():
		if is_instance_valid(chunk_scene):
			chunk_scene.free()
	_chunk_scenes.clear()
	_prepared_payloads.clear()
	_pending_prepare.clear()
	_pending_mount_ids.clear()
	_pending_retire_ids.clear()
	_last_queue_process_frame = -1

func sync_streaming(active_chunk_entries: Array, player_position: Vector3) -> void:
	if _config == null:
		return
	_last_player_position = player_position

	var target_chunk_entries := _build_target_chunk_map(active_chunk_entries)
	var target_chunk_ids: Dictionary = {}
	for chunk_id in target_chunk_entries.keys():
		target_chunk_ids[chunk_id] = true

	var new_entries: Array[Dictionary] = []
	for entry in active_chunk_entries:
		var chunk_id := str(entry.get("chunk_id", ""))
		if _chunk_scenes.has(chunk_id) or _prepared_payloads.has(chunk_id) or _pending_prepare.has(chunk_id):
			continue
		new_entries.append(entry)
	new_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _distance_to_entry(player_position, a) < _distance_to_entry(player_position, b)
	)
	for entry in new_entries:
		_pending_prepare[str(entry.get("chunk_id", ""))] = entry.duplicate(true)

	for chunk_id in get_chunk_ids():
		if target_chunk_ids.has(chunk_id):
			continue
		_queue_retire(chunk_id)

	for chunk_id in _prepared_payloads.keys():
		if target_chunk_ids.has(chunk_id):
			continue
		_prepared_payloads.erase(chunk_id)

	for chunk_id in _pending_prepare.keys():
		if target_chunk_ids.has(chunk_id):
			continue
		_pending_prepare.erase(chunk_id)

	for pending_index in range(_pending_mount_ids.size() - 1, -1, -1):
		var pending_chunk_id := _pending_mount_ids[pending_index]
		if target_chunk_ids.has(pending_chunk_id):
			continue
		_pending_mount_ids.remove_at(pending_index)

	_process_streaming_queues_once_per_frame()
	_update_lod_states(player_position)

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

func get_streaming_budget_stats() -> Dictionary:
	return {
		"prepare_budget_per_tick": PREPARE_BUDGET_PER_TICK,
		"mount_budget_per_tick": MOUNT_BUDGET_PER_TICK,
		"retire_budget_per_tick": RETIRE_BUDGET_PER_TICK,
		"pending_prepare_count": _pending_prepare.size(),
		"pending_mount_count": _pending_mount_ids.size(),
		"pending_retire_count": _pending_retire_ids.size(),
		"last_prepare_count": _last_prepare_count,
		"last_mount_count": _last_mount_count,
		"last_retire_count": _last_retire_count,
		"last_prepare_usec": _last_prepare_usec,
		"last_mount_usec": _last_mount_usec,
		"last_retire_usec": _last_retire_usec,
	}

func get_streaming_profile_stats() -> Dictionary:
	return {
		"prepare_profile_sample_count": _prepare_profile_sample_count,
		"prepare_profile_total_usec": _prepare_profile_total_usec,
		"prepare_profile_avg_usec": _average_usec(_prepare_profile_total_usec, _prepare_profile_sample_count),
		"prepare_profile_max_usec": _prepare_profile_max_usec,
		"prepare_profile_last_usec": _prepare_profile_last_usec,
		"mount_setup_sample_count": _mount_setup_sample_count,
		"mount_setup_total_usec": _mount_setup_total_usec,
		"mount_setup_avg_usec": _average_usec(_mount_setup_total_usec, _mount_setup_sample_count),
		"mount_setup_max_usec": _mount_setup_max_usec,
		"mount_setup_last_usec": _mount_setup_last_usec,
	}

func reset_streaming_profile_stats() -> void:
	_prepare_profile_sample_count = 0
	_prepare_profile_total_usec = 0
	_prepare_profile_max_usec = 0
	_prepare_profile_last_usec = 0
	_mount_setup_sample_count = 0
	_mount_setup_total_usec = 0
	_mount_setup_max_usec = 0
	_mount_setup_last_usec = 0

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
	var stats := {
		"active_rendered_chunk_count": get_chunk_scene_count(),
		"multimesh_instance_total": multimesh_instance_total,
		"lod_mode_counts": lod_mode_counts,
	}
	stats.merge(get_streaming_budget_stats(), true)
	stats.merge(get_streaming_profile_stats(), true)
	return stats

func get_chunk_scene_stats(chunk_id: String) -> Dictionary:
	if not _chunk_scenes.has(chunk_id):
		return {}
	return (_chunk_scenes[chunk_id] as Node).get_renderer_stats()

func _build_target_chunk_map(active_chunk_entries: Array) -> Dictionary:
	var map := {}
	for entry in active_chunk_entries:
		map[str(entry.get("chunk_id", ""))] = entry.duplicate(true)
	return map

func _queue_retire(chunk_id: String) -> void:
	if not _chunk_scenes.has(chunk_id):
		return
	if _pending_retire_ids.has(chunk_id):
		return
	_pending_retire_ids.append(chunk_id)

func _process_streaming_queues() -> void:
	if _should_use_warm_start_pipeline():
		_process_prepare_budget()
		_process_mount_budget()
		_process_retire_budget()
		return
	_process_retire_budget()
	_process_mount_budget()
	_process_prepare_budget()

func _process_streaming_queues_once_per_frame() -> void:
	var process_frame := Engine.get_process_frames()
	if _last_queue_process_frame == process_frame:
		return
	_last_queue_process_frame = process_frame
	_process_streaming_queues()

func _process_prepare_budget() -> void:
	var prepare_ids: Array[String] = []
	for chunk_id in _pending_prepare.keys():
		prepare_ids.append(str(chunk_id))
	prepare_ids.sort_custom(func(a: String, b: String) -> bool:
		return _distance_to_entry(_last_player_position, _pending_prepare[a]) < _distance_to_entry(_last_player_position, _pending_prepare[b])
	)

	var started_usec := Time.get_ticks_usec()
	var prepared_count := 0
	for chunk_id in prepare_ids:
		if prepared_count >= PREPARE_BUDGET_PER_TICK:
			break
		var entry: Dictionary = _pending_prepare[chunk_id]
		var payload := _build_chunk_payload(entry)
		var profile_started_usec := Time.get_ticks_usec()
		payload["prepared_profile"] = CityChunkProfileBuilder.build_profile(payload)
		_record_prepare_profile_sample(Time.get_ticks_usec() - profile_started_usec)
		_prepared_payloads[chunk_id] = payload
		if not _pending_mount_ids.has(chunk_id):
			_pending_mount_ids.append(chunk_id)
		_pending_prepare.erase(chunk_id)
		prepared_count += 1
	_last_prepare_count = prepared_count
	_last_prepare_usec = _duration_or_zero(started_usec, prepared_count)

func _process_mount_budget() -> void:
	var started_usec := Time.get_ticks_usec()
	var mounted_count := 0
	while not _pending_mount_ids.is_empty() and mounted_count < MOUNT_BUDGET_PER_TICK:
		var chunk_id: String = str(_pending_mount_ids.pop_front())
		if _chunk_scenes.has(chunk_id):
			continue
		if not _prepared_payloads.has(chunk_id):
			continue
		var payload: Dictionary = _prepared_payloads[chunk_id]
		var chunk_scene := _take_pooled_scene()
		var setup_started_usec := Time.get_ticks_usec()
		chunk_scene.setup(payload)
		_record_mount_setup_sample(Time.get_ticks_usec() - setup_started_usec)
		chunk_scene.visible = true
		add_child(chunk_scene)
		_chunk_scenes[chunk_id] = chunk_scene
		_prepared_payloads.erase(chunk_id)
		mounted_count += 1
	_last_mount_count = mounted_count
	_last_mount_usec = _duration_or_zero(started_usec, mounted_count)

func _process_retire_budget() -> void:
	var started_usec := Time.get_ticks_usec()
	var retired_count := 0
	while not _pending_retire_ids.is_empty() and retired_count < RETIRE_BUDGET_PER_TICK:
		var chunk_id: String = str(_pending_retire_ids.pop_front())
		if not _chunk_scenes.has(chunk_id):
			continue
		var chunk_scene: Node3D = _chunk_scenes[chunk_id]
		_chunk_scenes.erase(chunk_id)
		remove_child(chunk_scene)
		chunk_scene.visible = false
		if _scene_pool.size() < MAX_POOLED_CHUNKS:
			_scene_pool.append(chunk_scene)
		else:
			chunk_scene.queue_free()
		retired_count += 1
	_last_retire_count = retired_count
	_last_retire_usec = _duration_or_zero(started_usec, retired_count)

func _take_pooled_scene() -> Node3D:
	if _scene_pool.is_empty():
		return CityChunkScene.new()
	return _scene_pool.pop_back()

func _update_lod_states(player_position: Vector3) -> void:
	for chunk_id in get_chunk_ids():
		var chunk_scene: Node3D = _chunk_scenes[chunk_id]
		chunk_scene.update_lod_for_distance(player_position.distance_to(chunk_scene.position))

func _distance_to_entry(player_position: Vector3, entry: Dictionary) -> float:
	var chunk_key: Vector2i = entry.get("chunk_key", Vector2i.ZERO)
	var chunk_center := _chunk_center_from_key(chunk_key)
	return player_position.distance_to(chunk_center)

func _build_chunk_payload(entry: Dictionary) -> Dictionary:
	var chunk_key: Vector2i = entry.get("chunk_key", Vector2i.ZERO)
	return {
		"chunk_id": str(entry.get("chunk_id", "")),
		"chunk_key": chunk_key,
		"chunk_center": _chunk_center_from_key(chunk_key),
		"chunk_size_m": float(_config.chunk_size_m),
		"chunk_seed": _config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(_config.base_seed),
		"road_graph": _world_data.get("road_graph"),
	}

func _chunk_center_from_key(chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = _config.get_world_bounds()
	var center_x := bounds.position.x + (float(chunk_key.x) + 0.5) * float(_config.chunk_size_m)
	var center_z := bounds.position.y + (float(chunk_key.y) + 0.5) * float(_config.chunk_size_m)
	return Vector3(center_x, 0.0, center_z)

func _duration_or_zero(started_usec: int, item_count: int) -> int:
	if item_count <= 0:
		return 0
	return maxi(int(Time.get_ticks_usec() - started_usec), 1)

func _record_prepare_profile_sample(duration_usec: int) -> void:
	_prepare_profile_sample_count += 1
	_prepare_profile_total_usec += duration_usec
	_prepare_profile_max_usec = maxi(_prepare_profile_max_usec, duration_usec)
	_prepare_profile_last_usec = duration_usec

func _record_mount_setup_sample(duration_usec: int) -> void:
	_mount_setup_sample_count += 1
	_mount_setup_total_usec += duration_usec
	_mount_setup_max_usec = maxi(_mount_setup_max_usec, duration_usec)
	_mount_setup_last_usec = duration_usec

func _average_usec(total_usec: int, sample_count: int) -> int:
	if sample_count <= 0:
		return 0
	return int(round(float(total_usec) / float(sample_count)))

func _should_use_warm_start_pipeline() -> bool:
	return _chunk_scenes.is_empty() and _prepared_payloads.is_empty()
