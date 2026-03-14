extends RefCounted

const CityVehicleState := preload("res://city_game/world/vehicles/simulation/CityVehicleState.gd")
const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")

var _config = null
var _world_data: Dictionary = {}
var _vehicle_query = null
var _lane_graph = null
var _world_seed := 0
var _budget_contract: Dictionary = {}
var _visual_catalog: CityVehicleVisualCatalog = null
var _pages_by_chunk_id: Dictionary = {}
var _states_by_id: Dictionary = {}
var _page_build_counts: Dictionary = {}
var _tick := 0
var _page_cache_hit_count := 0
var _page_cache_miss_count := 0
var _page_generation_count := 0
var _duplicate_page_load_count := 0
var _page_eviction_count := 0
var _ground_contexts_by_chunk_id: Dictionary = {}
var _active_state_refs: Array[CityVehicleState] = []
var _active_state_refs_dirty := true
var _last_active_chunk_ids: Array[String] = []

func setup(config, world_data: Dictionary, budget_contract: Dictionary) -> void:
	_config = config
	_world_data = world_data.duplicate(false)
	_vehicle_query = world_data.get("vehicle_query")
	_lane_graph = _vehicle_query.get_lane_graph() if _vehicle_query != null and _vehicle_query.has_method("get_lane_graph") else null
	_world_seed = int(config.base_seed) if config != null else 0
	_budget_contract = budget_contract.duplicate(true)
	_visual_catalog = CityVehicleVisualCatalog.new()
	_pages_by_chunk_id.clear()
	_states_by_id.clear()
	_page_build_counts.clear()
	_tick = 0
	_page_cache_hit_count = 0
	_page_cache_miss_count = 0
	_page_generation_count = 0
	_duplicate_page_load_count = 0
	_page_eviction_count = 0
	_ground_contexts_by_chunk_id.clear()
	_active_state_refs.clear()
	_active_state_refs_dirty = true
	_last_active_chunk_ids.clear()

func sync_active_chunks(active_chunk_entries: Array) -> Dictionary:
	_tick += 1
	var active_chunk_ids: Array[String] = []
	for entry_variant in active_chunk_entries:
		var entry: Dictionary = entry_variant
		var chunk_id := str(entry.get("chunk_id", ""))
		active_chunk_ids.append(chunk_id)
	active_chunk_ids.sort()
	if _can_reuse_active_pages(active_chunk_ids):
		_refresh_active_page_ticks(active_chunk_ids)
		return {
			"active_chunk_ids": active_chunk_ids,
			"active_page_count": active_chunk_ids.size(),
			"cached_page_count": _pages_by_chunk_id.size(),
		}

	var active_chunk_id_set: Dictionary = {}
	var last_active_chunk_id_set: Dictionary = {}
	var active_state_refs_changed := false
	for chunk_id in _last_active_chunk_ids:
		last_active_chunk_id_set[chunk_id] = true
	for entry_variant in active_chunk_entries:
		var entry: Dictionary = entry_variant
		var chunk_key: Vector2i = entry.get("chunk_key", Vector2i.ZERO)
		var chunk_id := str(entry.get("chunk_id", ""))
		active_chunk_id_set[chunk_id] = true
		if last_active_chunk_id_set.has(chunk_id) and _pages_by_chunk_id.has(chunk_id):
			var resident_page: Dictionary = _pages_by_chunk_id[chunk_id]
			resident_page["active"] = true
			resident_page["last_active_tick"] = _tick
			_pages_by_chunk_id[chunk_id] = resident_page
			continue
		var page_existed := _pages_by_chunk_id.has(chunk_id)
		var page := _ensure_page(chunk_key, chunk_id)
		if not bool(page.get("active", false)) and int(page.get("visit_count", 0)) > 0:
			_page_cache_hit_count += 1
		if not page_existed or not bool(page.get("active", false)):
			active_state_refs_changed = true
		page["active"] = true
		page["last_active_tick"] = _tick
		page["visit_count"] = int(page.get("visit_count", 0)) + 1
		_pages_by_chunk_id[chunk_id] = page

	for chunk_id in _last_active_chunk_ids:
		if active_chunk_id_set.has(chunk_id):
			continue
		if not _pages_by_chunk_id.has(chunk_id):
			continue
		var page: Dictionary = _pages_by_chunk_id[chunk_id]
		if bool(page.get("active", false)):
			active_state_refs_changed = true
		page["active"] = false
		_pages_by_chunk_id[chunk_id] = page

	var page_evictions_before := _page_eviction_count
	_prune_inactive_pages()
	if _page_eviction_count != page_evictions_before:
		active_state_refs_changed = true
	if active_state_refs_changed:
		_rebuild_active_state_refs()
	_prune_ground_contexts()
	_last_active_chunk_ids = active_chunk_ids.duplicate()
	return {
		"active_chunk_ids": active_chunk_ids,
		"active_page_count": _count_active_pages(),
		"cached_page_count": _pages_by_chunk_id.size(),
	}

func get_active_states() -> Array:
	if _active_state_refs_dirty:
		_rebuild_active_state_refs()
	return _active_state_refs

func get_state(vehicle_id: String) -> CityVehicleState:
	return _states_by_id.get(vehicle_id)

func get_state_snapshot(vehicle_id: String) -> Dictionary:
	var state: CityVehicleState = get_state(vehicle_id)
	if state == null:
		return {}
	return state.to_snapshot()

func ground_state(state: CityVehicleState) -> void:
	var ground_context: Dictionary = _resolve_ground_context_for_state(state)
	if ground_context.is_empty():
		return
	var chunk_payload: Dictionary = ground_context.get("chunk_payload", {})
	var profile: Dictionary = ground_context.get("profile", {})
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := Vector2(state.world_position.x - chunk_center.x, state.world_position.z - chunk_center.z)
	state.apply_ground_height(CityChunkGroundSampler.sample_drive_height(local_point, chunk_payload, profile, state.road_id))

func get_runtime_snapshot() -> Dictionary:
	return _build_runtime_snapshot(true)

func get_runtime_summary() -> Dictionary:
	return _build_runtime_snapshot(false)

func _build_runtime_snapshot(include_page_build_counts: bool) -> Dictionary:
	var snapshot := {
		"active_page_count": _count_active_pages(),
		"cached_page_count": _pages_by_chunk_id.size(),
		"resident_state_count": _states_by_id.size(),
		"page_cache_hit_count": _page_cache_hit_count,
		"page_cache_miss_count": _page_cache_miss_count,
		"page_generation_count": _page_generation_count,
		"duplicate_page_load_count": _duplicate_page_load_count,
		"page_eviction_count": _page_eviction_count,
	}
	if include_page_build_counts:
		snapshot["page_build_counts"] = _page_build_counts.duplicate(true)
	return snapshot

func prewarm_chunk_entries(chunk_entries: Array) -> void:
	for entry_variant in chunk_entries:
		var entry: Dictionary = entry_variant
		var chunk_id := str(entry.get("chunk_id", ""))
		if chunk_id == "" or _pages_by_chunk_id.has(chunk_id):
			continue
		_ensure_page(entry.get("chunk_key", Vector2i.ZERO), chunk_id)

func invalidate_active_state_cache() -> void:
	_active_state_refs_dirty = true

func _ensure_page(chunk_key: Vector2i, chunk_id: String) -> Dictionary:
	if _pages_by_chunk_id.has(chunk_id):
		return _pages_by_chunk_id[chunk_id]

	var chunk_query: Dictionary = _vehicle_query.get_vehicle_query_for_chunk(chunk_key)
	var page_id := str(chunk_query.get("lane_page_id", "veh_page_%s" % chunk_id))
	_page_cache_miss_count += 1
	_page_generation_count += 1
	_page_build_counts[page_id] = int(_page_build_counts.get(page_id, 0)) + 1
	if int(_page_build_counts.get(page_id, 0)) > 1:
		_duplicate_page_load_count += 1

	var state_ids: Array[String] = []
	for spawn_slot_variant in chunk_query.get("spawn_slots", []):
		var spawn_slot: Dictionary = spawn_slot_variant
		var state: CityVehicleState = _build_state(chunk_id, page_id, spawn_slot)
		_states_by_id[state.vehicle_id] = state
		state_ids.append(state.vehicle_id)

	var page := {
		"chunk_id": chunk_id,
		"chunk_key": chunk_key,
		"page_id": page_id,
		"state_ids": state_ids,
		"active": false,
		"visit_count": 0,
		"last_active_tick": -1,
	}
	_pages_by_chunk_id[chunk_id] = page
	return page

func _build_state(chunk_id: String, page_id: String, spawn_slot: Dictionary) -> CityVehicleState:
	var descriptor := _visual_catalog.build_descriptor(spawn_slot)
	var lane: Dictionary = _lane_graph.get_lane_by_id(str(spawn_slot.get("lane_ref_id", ""))) if _lane_graph != null else {}
	var state := CityVehicleState.new()
	state.setup({
		"vehicle_id": "veh:%s" % str(spawn_slot.get("spawn_slot_id", "")),
		"chunk_id": chunk_id,
		"page_id": page_id,
		"spawn_slot_id": str(spawn_slot.get("spawn_slot_id", "")),
		"road_id": str(spawn_slot.get("road_id", "")),
		"lane_ref_id": str(spawn_slot.get("lane_ref_id", "")),
		"route_signature": "%s|%s|%s" % [
			str(spawn_slot.get("lane_ref_id", "")),
			str(spawn_slot.get("road_class", "")),
			str(spawn_slot.get("direction", "")),
		],
		"model_id": str(descriptor.get("model_id", "car_b")),
		"model_signature": str(descriptor.get("model_signature", "car_b:sedan")),
		"traffic_role": str(descriptor.get("traffic_role", "civilian")),
		"vehicle_class": str(descriptor.get("vehicle_class", "sedan")),
		"seed": int(spawn_slot.get("seed", 0)),
		"length_m": float(descriptor.get("length_m", 4.4)),
		"width_m": float(descriptor.get("width_m", 1.9)),
		"height_m": float(descriptor.get("height_m", 1.5)),
		"speed_mps": _resolve_speed_mps(str(spawn_slot.get("road_class", ""))),
		"world_position": spawn_slot.get("world_position", Vector3.ZERO),
		"lane_points": lane.get("points", []),
		"lane_length_m": float(lane.get("path_length_m", 0.0)),
		"distance_along_lane_m": float(spawn_slot.get("distance_along_lane_m", 0.0)),
	})
	return state

func _resolve_speed_mps(road_class: String) -> float:
	match road_class:
		"expressway_elevated":
			return 18.0
		"arterial":
			return 15.0
		"secondary":
			return 12.5
		"collector":
			return 10.5
		"service":
			return 8.0
		_:
			return 9.0

func _prune_inactive_pages() -> void:
	var page_cache_capacity := int(_budget_contract.get("page_cache_capacity", 160))
	if _pages_by_chunk_id.size() <= page_cache_capacity:
		return
	var inactive_chunk_ids: Array[String] = []
	for chunk_id_variant in _pages_by_chunk_id.keys():
		var chunk_id := str(chunk_id_variant)
		var page: Dictionary = _pages_by_chunk_id[chunk_id]
		if bool(page.get("active", false)):
			continue
		inactive_chunk_ids.append(chunk_id)
	inactive_chunk_ids.sort_custom(func(a: String, b: String) -> bool:
		return int((_pages_by_chunk_id[a] as Dictionary).get("last_active_tick", -1)) < int((_pages_by_chunk_id[b] as Dictionary).get("last_active_tick", -1))
	)
	while _pages_by_chunk_id.size() > page_cache_capacity and not inactive_chunk_ids.is_empty():
		_evict_page(inactive_chunk_ids.pop_front())

func _evict_page(chunk_id: String) -> void:
	if not _pages_by_chunk_id.has(chunk_id):
		return
	var page: Dictionary = _pages_by_chunk_id[chunk_id]
	for vehicle_id_variant in page.get("state_ids", []):
		_states_by_id.erase(str(vehicle_id_variant))
	_pages_by_chunk_id.erase(chunk_id)
	_ground_contexts_by_chunk_id.erase(chunk_id)
	_page_eviction_count += 1

func _rebuild_active_state_refs() -> void:
	_active_state_refs.clear()
	for chunk_id_variant in _pages_by_chunk_id.keys():
		var page: Dictionary = _pages_by_chunk_id[chunk_id_variant]
		if not bool(page.get("active", false)):
			continue
		for vehicle_id_variant in page.get("state_ids", []):
			var vehicle_id := str(vehicle_id_variant)
			var state: CityVehicleState = _states_by_id.get(vehicle_id)
			if state != null and state.is_runtime_active():
				_active_state_refs.append(state)
	_active_state_refs_dirty = false

func _count_active_pages() -> int:
	var count := 0
	for page in _pages_by_chunk_id.values():
		if bool((page as Dictionary).get("active", false)):
			count += 1
	return count

func _resolve_ground_context_for_state(state: CityVehicleState) -> Dictionary:
	var chunk_key := CityChunkKey.world_to_chunk_key(_config, state.world_position)
	var chunk_id: String = str(_config.format_chunk_id(chunk_key))
	if _ground_contexts_by_chunk_id.has(chunk_id):
		return _ground_contexts_by_chunk_id[chunk_id]
	var chunk_payload := _build_chunk_payload(chunk_key)
	var road_layout: Dictionary = CityRoadLayoutBuilder.build_chunk_roads(chunk_payload)
	var profile := {
		"road_segments": road_layout.get("segments", []),
	}
	var context := {
		"chunk_id": chunk_id,
		"chunk_key": chunk_key,
		"chunk_payload": chunk_payload,
		"profile": profile,
	}
	_ground_contexts_by_chunk_id[chunk_id] = context
	return context

func _build_chunk_payload(chunk_key: Vector2i) -> Dictionary:
	var bounds: Rect2 = _config.get_world_bounds()
	return {
		"chunk_id": _config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": Vector3(
			bounds.position.x + (float(chunk_key.x) + 0.5) * float(_config.chunk_size_m),
			0.0,
			bounds.position.y + (float(chunk_key.y) + 0.5) * float(_config.chunk_size_m)
		),
		"chunk_size_m": float(_config.chunk_size_m),
		"chunk_seed": _config.derive_seed("render_chunk", chunk_key),
		"world_seed": _world_seed,
		"road_graph": _world_data.get("road_graph"),
	}

func _prune_ground_contexts() -> void:
	for chunk_id_variant in _ground_contexts_by_chunk_id.keys():
		var chunk_id := str(chunk_id_variant)
		if _pages_by_chunk_id.has(chunk_id):
			continue
		_ground_contexts_by_chunk_id.erase(chunk_id)

func _can_reuse_active_pages(active_chunk_ids: Array[String]) -> bool:
	if not _string_arrays_equal(_last_active_chunk_ids, active_chunk_ids):
		return false
	var page_cache_capacity := int(_budget_contract.get("page_cache_capacity", 160))
	if _pages_by_chunk_id.size() > page_cache_capacity:
		return false
	for chunk_id in active_chunk_ids:
		if not _pages_by_chunk_id.has(chunk_id):
			return false
		var page: Dictionary = _pages_by_chunk_id[chunk_id]
		if not bool(page.get("active", false)):
			return false
	return true

func _refresh_active_page_ticks(active_chunk_ids: Array[String]) -> void:
	for chunk_id in active_chunk_ids:
		var page: Dictionary = _pages_by_chunk_id.get(chunk_id, {})
		if page.is_empty():
			continue
		page["last_active_tick"] = _tick
		_pages_by_chunk_id[chunk_id] = page

func _string_arrays_equal(lhs: Array[String], rhs: Array[String]) -> bool:
	if lhs.size() != rhs.size():
		return false
	for item_index in range(lhs.size()):
		if lhs[item_index] != rhs[item_index]:
			return false
	return true
