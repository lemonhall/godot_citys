extends RefCounted

const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")
const CityChunkLifecycle := preload("res://city_game/world/streaming/CityChunkLifecycle.gd")

var _config
var _world_data: Dictionary = {}
var _current_chunk_key := Vector2i(-1, -1)
var _current_chunk_id := ""
var _active_chunks: Dictionary = {}
var _transition_log: Array[Dictionary] = []
var _sequence := 0
var _last_prepare_usec := 0
var _last_mount_usec := 0
var _last_retire_usec := 0

func _init(config = null, world_data: Dictionary = {}) -> void:
	if config != null:
		setup(config, world_data)

func setup(config, world_data: Dictionary = {}) -> void:
	_config = config
	_world_data = world_data.duplicate(true)
	_current_chunk_key = Vector2i(-1, -1)
	_current_chunk_id = ""
	_active_chunks.clear()
	_transition_log.clear()
	_sequence = 0
	_last_prepare_usec = 0
	_last_mount_usec = 0
	_last_retire_usec = 0

func update_for_world_position(world_position: Vector3) -> Array[Dictionary]:
	if _config == null:
		return []

	var next_chunk_key: Vector2i = CityChunkKey.world_to_chunk_key(_config, world_position)
	var target_keys: Array[Vector2i] = CityChunkKey.get_window_keys(_config, next_chunk_key, 2)
	var target_chunk_map: Dictionary = {}
	for chunk_key in target_keys:
		target_chunk_map[_config.format_chunk_id(chunk_key)] = chunk_key

	var events: Array[Dictionary] = []
	var pending_mount_ids: Array[String] = []

	var prepare_started_usec := Time.get_ticks_usec()
	for chunk_id in _get_sorted_target_ids(target_chunk_map):
		if _active_chunks.has(chunk_id):
			continue
		var chunk_key: Vector2i = target_chunk_map[chunk_id]
		_active_chunks[chunk_id] = {
			"chunk_id": chunk_id,
			"chunk_key": chunk_key,
			"state": CityChunkLifecycle.EVENT_PREPARE,
		}
		events.append(_append_event(CityChunkLifecycle.EVENT_PREPARE, chunk_id, chunk_key))
		pending_mount_ids.append(chunk_id)
	_last_prepare_usec = _duration_or_zero(prepare_started_usec, pending_mount_ids.size())

	var mount_started_usec := Time.get_ticks_usec()
	for chunk_id in pending_mount_ids:
		var entry: Dictionary = _active_chunks[chunk_id]
		entry["state"] = CityChunkLifecycle.EVENT_MOUNT
		_active_chunks[chunk_id] = entry
		events.append(_append_event(CityChunkLifecycle.EVENT_MOUNT, chunk_id, entry["chunk_key"]))
	_last_mount_usec = _duration_or_zero(mount_started_usec, pending_mount_ids.size())

	var retire_started_usec := Time.get_ticks_usec()
	var retire_count := 0
	for chunk_id in get_active_chunk_ids():
		if target_chunk_map.has(chunk_id):
			continue
		var entry: Dictionary = _active_chunks[chunk_id]
		events.append(_append_event(CityChunkLifecycle.EVENT_RETIRE, chunk_id, entry["chunk_key"]))
		_active_chunks.erase(chunk_id)
		retire_count += 1
	_last_retire_usec = _duration_or_zero(retire_started_usec, retire_count)

	_current_chunk_key = next_chunk_key
	_current_chunk_id = _config.format_chunk_id(next_chunk_key)
	return events

func get_current_chunk_id() -> String:
	return _current_chunk_id

func get_current_chunk_key() -> Vector2i:
	return _current_chunk_key

func get_active_chunk_ids() -> Array[String]:
	var ids: Array[String] = []
	for chunk_id in _active_chunks.keys():
		ids.append(str(chunk_id))
	ids.sort()
	return ids

func get_active_chunk_count() -> int:
	return _active_chunks.size()

func get_transition_log() -> Array[Dictionary]:
	return _transition_log.duplicate(true)

func clear_transition_log() -> void:
	_transition_log.clear()
	_sequence = 0

func get_streaming_snapshot() -> Dictionary:
	return {
		"current_chunk_id": _current_chunk_id,
		"current_chunk_key": _current_chunk_key,
		"active_chunk_count": get_active_chunk_count(),
		"active_chunk_ids": get_active_chunk_ids(),
		"last_prepare_usec": _last_prepare_usec,
		"last_mount_usec": _last_mount_usec,
		"last_retire_usec": _last_retire_usec,
	}

func _append_event(event_type: String, chunk_id: String, chunk_key: Vector2i) -> Dictionary:
	_sequence += 1
	var event := CityChunkLifecycle.make_event(_sequence, event_type, chunk_id, chunk_key)
	_transition_log.append(event)
	return event

func _duration_or_zero(started_usec: int, item_count: int) -> int:
	if item_count <= 0:
		return 0
	return maxi(int(Time.get_ticks_usec() - started_usec), 1)

func _get_sorted_target_ids(target_chunk_map: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for chunk_id in target_chunk_map.keys():
		ids.append(str(chunk_id))
	ids.sort()
	return ids
