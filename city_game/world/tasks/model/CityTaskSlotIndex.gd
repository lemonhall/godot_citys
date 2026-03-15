extends RefCounted

const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")

var _config = null
var _slots_by_id: Dictionary = {}
var _slot_ids_by_task_id: Dictionary = {}
var _slot_ids_by_chunk_id: Dictionary = {}
var _sorted_slot_ids: Array[String] = []

func setup(config, slots: Array) -> void:
	_config = config
	_slots_by_id.clear()
	_slot_ids_by_task_id.clear()
	_slot_ids_by_chunk_id.clear()
	_sorted_slot_ids.clear()
	if _config == null:
		return
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var stored := _sanitize_slot(slot_variant as Dictionary)
		var slot_id := str(stored.get("slot_id", ""))
		var task_id := str(stored.get("task_id", ""))
		if slot_id == "" or task_id == "":
			continue
		_slots_by_id[slot_id] = stored
		_sorted_slot_ids.append(slot_id)
		if not _slot_ids_by_task_id.has(task_id):
			_slot_ids_by_task_id[task_id] = []
		(_slot_ids_by_task_id[task_id] as Array).append(slot_id)
		var chunk_id := str(stored.get("chunk_id", ""))
		if not _slot_ids_by_chunk_id.has(chunk_id):
			_slot_ids_by_chunk_id[chunk_id] = []
		(_slot_ids_by_chunk_id[chunk_id] as Array).append(slot_id)
	_sorted_slot_ids.sort()

func get_slot_count() -> int:
	return _sorted_slot_ids.size()

func get_slots() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for slot_id in _sorted_slot_ids:
		results.append((_slots_by_id[slot_id] as Dictionary).duplicate(true))
	return results

func get_slot_by_id(slot_id: String) -> Dictionary:
	if not _slots_by_id.has(slot_id):
		return {}
	return (_slots_by_id[slot_id] as Dictionary).duplicate(true)

func get_slots_for_task(task_id: String, slot_kinds: Array = []) -> Array[Dictionary]:
	if not _slot_ids_by_task_id.has(task_id):
		return []
	var results: Array[Dictionary] = []
	for slot_id_variant in _slot_ids_by_task_id[task_id]:
		var slot_id := str(slot_id_variant)
		if not _slots_by_id.has(slot_id):
			continue
		var slot: Dictionary = _slots_by_id[slot_id]
		if _matches_slot_kind(slot, slot_kinds):
			results.append(slot.duplicate(true))
	return results

func get_slots_for_chunk(chunk_key: Vector2i, slot_kinds: Array = []) -> Array[Dictionary]:
	if _config == null:
		return []
	var chunk_id: String = _config.format_chunk_id(chunk_key)
	if not _slot_ids_by_chunk_id.has(chunk_id):
		return []
	var results: Array[Dictionary] = []
	for slot_id_variant in _slot_ids_by_chunk_id[chunk_id]:
		var slot_id := str(slot_id_variant)
		if not _slots_by_id.has(slot_id):
			continue
		var slot: Dictionary = _slots_by_id[slot_id]
		if _matches_slot_kind(slot, slot_kinds):
			results.append(slot.duplicate(true))
	return results

func get_slots_intersecting_rect(rect: Rect2, slot_kinds: Array = []) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if _config == null or rect.size.x < 0.0 or rect.size.y < 0.0:
		return results
	var seen: Dictionary = {}
	for chunk_key in _get_chunk_keys_for_rect(rect):
		for slot_variant in get_slots_for_chunk(chunk_key, slot_kinds):
			var slot: Dictionary = slot_variant
			var slot_id := str(slot.get("slot_id", ""))
			if slot_id == "" or seen.has(slot_id):
				continue
			if not _slot_intersects_rect(slot, rect):
				continue
			seen[slot_id] = true
			results.append(slot.duplicate(true))
	return results

func get_nearby_slots(world_position: Vector3, radius_m: float, slot_kinds: Array = []) -> Array[Dictionary]:
	var query_radius := maxf(radius_m, 0.0)
	var rect := Rect2(
		Vector2(world_position.x - query_radius, world_position.z - query_radius),
		Vector2.ONE * query_radius * 2.0
	)
	var results: Array[Dictionary] = []
	for slot_variant in get_slots_intersecting_rect(rect, slot_kinds):
		var slot: Dictionary = slot_variant
		var anchor: Vector3 = slot.get("world_anchor", Vector3.ZERO)
		if Vector2(anchor.x - world_position.x, anchor.z - world_position.z).length() <= query_radius + float(slot.get("trigger_radius_m", 0.0)):
			results.append(slot.duplicate(true))
	return results

func _sanitize_slot(slot_data: Dictionary) -> Dictionary:
	var world_anchor: Vector3 = slot_data.get("world_anchor", Vector3.ZERO)
	var chunk_key := CityChunkKey.world_to_chunk_key(_config, world_anchor)
	return {
		"slot_id": str(slot_data.get("slot_id", "")),
		"task_id": str(slot_data.get("task_id", "")),
		"slot_kind": str(slot_data.get("slot_kind", "start")),
		"world_anchor": world_anchor,
		"trigger_radius_m": maxf(float(slot_data.get("trigger_radius_m", 0.0)), 1.5),
		"marker_theme": str(slot_data.get("marker_theme", "")),
		"route_target_override": (slot_data.get("route_target_override", {}) as Dictionary).duplicate(true),
		"display_name": str(slot_data.get("display_name", "")),
		"district_id": str(slot_data.get("district_id", "")),
		"chunk_key": chunk_key,
		"chunk_id": _config.format_chunk_id(chunk_key),
	}

func _matches_slot_kind(slot: Dictionary, slot_kinds: Array) -> bool:
	return slot_kinds.is_empty() or slot_kinds.has(str(slot.get("slot_kind", "")))

func _slot_intersects_rect(slot: Dictionary, rect: Rect2) -> bool:
	var anchor: Vector3 = slot.get("world_anchor", Vector3.ZERO)
	var radius_m := maxf(float(slot.get("trigger_radius_m", 0.0)), 1.5)
	var slot_rect := Rect2(
		Vector2(anchor.x - radius_m, anchor.z - radius_m),
		Vector2.ONE * radius_m * 2.0
	)
	return rect.intersects(slot_rect)

func _get_chunk_keys_for_rect(rect: Rect2) -> Array[Vector2i]:
	if _config == null:
		return []
	var min_key := CityChunkKey.world_to_chunk_key(_config, Vector3(rect.position.x, 0.0, rect.position.y))
	var max_key := CityChunkKey.world_to_chunk_key(_config, Vector3(rect.end.x, 0.0, rect.end.y))
	var results: Array[Vector2i] = []
	for chunk_x in range(mini(min_key.x, max_key.x), maxi(min_key.x, max_key.x) + 1):
		for chunk_y in range(mini(min_key.y, max_key.y), maxi(min_key.y, max_key.y) + 1):
			results.append(Vector2i(chunk_x, chunk_y))
	return results
