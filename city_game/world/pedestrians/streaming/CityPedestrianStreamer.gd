extends RefCounted

const CityPedestrianArchetypeCatalog := preload("res://city_game/world/pedestrians/rendering/CityPedestrianArchetypeCatalog.gd")
const CityPedestrianState := preload("res://city_game/world/pedestrians/simulation/CityPedestrianState.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")

var _config = null
var _world_data: Dictionary = {}
var _pedestrian_query = null
var _lane_graph = null
var _road_graph = null
var _world_seed := 0
var _budget_contract: Dictionary = {}
var _archetype_catalog := CityPedestrianArchetypeCatalog.new()
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

func setup(config, world_data: Dictionary, budget_contract: Dictionary) -> void:
	_config = config
	_world_data = world_data.duplicate(false)
	_pedestrian_query = world_data.get("pedestrian_query")
	_lane_graph = _pedestrian_query.get_lane_graph() if _pedestrian_query != null and _pedestrian_query.has_method("get_lane_graph") else null
	_road_graph = world_data.get("road_graph")
	_world_seed = int(config.base_seed) if config != null else 0
	_budget_contract = budget_contract.duplicate(true)
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

func sync_active_chunks(active_chunk_entries: Array) -> Dictionary:
	_tick += 1
	var active_chunk_ids: Array[String] = []
	for entry_variant in active_chunk_entries:
		var entry: Dictionary = entry_variant
		var chunk_key: Vector2i = entry.get("chunk_key", Vector2i.ZERO)
		var chunk_id := str(entry.get("chunk_id", ""))
		active_chunk_ids.append(chunk_id)
		var page := _ensure_page(chunk_key, chunk_id)
		if not bool(page.get("active", false)) and int(page.get("visit_count", 0)) > 0:
			_page_cache_hit_count += 1
		page["active"] = true
		page["last_active_tick"] = _tick
		page["visit_count"] = int(page.get("visit_count", 0)) + 1
		_pages_by_chunk_id[chunk_id] = page

	for chunk_id_variant in _pages_by_chunk_id.keys():
		var chunk_id := str(chunk_id_variant)
		if active_chunk_ids.has(chunk_id):
			continue
		var page: Dictionary = _pages_by_chunk_id[chunk_id]
		page["active"] = false
		_pages_by_chunk_id[chunk_id] = page

	_prune_inactive_pages()
	_prune_ground_contexts()
	return {
		"active_chunk_ids": active_chunk_ids,
		"active_page_count": _count_active_pages(),
		"cached_page_count": _pages_by_chunk_id.size(),
	}

func get_active_states() -> Array:
	var active_states: Array = []
	for chunk_id_variant in _pages_by_chunk_id.keys():
		var page: Dictionary = _pages_by_chunk_id[chunk_id_variant]
		if not bool(page.get("active", false)):
			continue
		for pedestrian_id_variant in page.get("state_ids", []):
			var pedestrian_id := str(pedestrian_id_variant)
			var state: CityPedestrianState = _states_by_id.get(pedestrian_id)
			if state != null and state.is_alive():
				active_states.append(state)
	return active_states

func get_state(pedestrian_id: String) -> CityPedestrianState:
	return _states_by_id.get(pedestrian_id)

func get_state_snapshot(pedestrian_id: String) -> Dictionary:
	var state: CityPedestrianState = get_state(pedestrian_id)
	if state == null:
		return {}
	return state.to_snapshot()

func get_states_for_chunk(chunk_id: String) -> Array:
	if not _pages_by_chunk_id.has(chunk_id):
		return []
	var page: Dictionary = _pages_by_chunk_id[chunk_id]
	var states: Array = []
	for pedestrian_id_variant in page.get("state_ids", []):
		var pedestrian_id := str(pedestrian_id_variant)
		var state: CityPedestrianState = _states_by_id.get(pedestrian_id)
		if state != null:
			states.append(state)
	return states

func ground_state(state: CityPedestrianState) -> void:
	var ground_context: Dictionary = _resolve_ground_context_for_state(state)
	if ground_context.is_empty():
		return
	var chunk_payload: Dictionary = ground_context.get("chunk_payload", {})
	var profile: Dictionary = ground_context.get("profile", {})
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := Vector2(state.world_position.x - chunk_center.x, state.world_position.z - chunk_center.z)
	state.apply_ground_height(CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile))

func get_runtime_snapshot() -> Dictionary:
	return {
		"active_page_count": _count_active_pages(),
		"cached_page_count": _pages_by_chunk_id.size(),
		"resident_state_count": _states_by_id.size(),
		"page_cache_hit_count": _page_cache_hit_count,
		"page_cache_miss_count": _page_cache_miss_count,
		"page_generation_count": _page_generation_count,
		"duplicate_page_load_count": _duplicate_page_load_count,
		"page_eviction_count": _page_eviction_count,
		"page_build_counts": _page_build_counts.duplicate(true),
	}

func _ensure_page(chunk_key: Vector2i, chunk_id: String) -> Dictionary:
	if _pages_by_chunk_id.has(chunk_id):
		return (_pages_by_chunk_id[chunk_id] as Dictionary).duplicate(true)

	var chunk_query: Dictionary = _pedestrian_query.get_pedestrian_query_for_chunk(chunk_key)
	var page_id := str(chunk_query.get("lane_page_id", "ped_page_%s" % chunk_id))
	_page_cache_miss_count += 1
	_page_generation_count += 1
	_page_build_counts[page_id] = int(_page_build_counts.get(page_id, 0)) + 1
	if int(_page_build_counts.get(page_id, 0)) > 1:
		_duplicate_page_load_count += 1

	var state_ids: Array[String] = []
	for spawn_slot_variant in chunk_query.get("spawn_slots", []):
		var spawn_slot: Dictionary = spawn_slot_variant
		var state: CityPedestrianState = _build_state(chunk_id, page_id, spawn_slot)
		_states_by_id[state.pedestrian_id] = state
		state_ids.append(state.pedestrian_id)

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
	return page.duplicate(true)

func _build_state(chunk_id: String, page_id: String, spawn_slot: Dictionary) -> CityPedestrianState:
	var descriptor: Dictionary = _archetype_catalog.build_descriptor(spawn_slot)
	var lane: Dictionary = _lane_graph.get_lane_by_id(str(spawn_slot.get("lane_ref_id", ""))) if _lane_graph != null else {}
	var state := CityPedestrianState.new()
	var lane_points: Array = lane.get("points", [])
	state.setup({
		"pedestrian_id": "ped:%s" % str(spawn_slot.get("spawn_slot_id", "")),
		"chunk_id": chunk_id,
		"page_id": page_id,
		"spawn_slot_id": str(spawn_slot.get("spawn_slot_id", "")),
		"road_id": str(spawn_slot.get("road_id", "")),
		"lane_ref_id": str(spawn_slot.get("lane_ref_id", "")),
		"route_signature": "%s|%s|%s" % [
			str(spawn_slot.get("lane_ref_id", "")),
			str(spawn_slot.get("side", "")),
			str(spawn_slot.get("road_class", "")),
		],
		"archetype_id": str(descriptor.get("archetype_id", "resident")),
		"archetype_signature": str(descriptor.get("archetype_signature", "resident:v0")),
		"seed": int(spawn_slot.get("seed", 0)),
		"height_m": float(descriptor.get("height_m", 1.75)),
		"radius_m": float(descriptor.get("radius_m", 0.28)),
		"speed_mps": float(descriptor.get("speed_mps", 1.25)),
		"stride_phase": float(descriptor.get("stride_phase", 0.0)),
		"route_progress": fposmod(float(posmod(int(spawn_slot.get("seed", 0)), 997)) / 997.0, 1.0),
		"world_position": spawn_slot.get("world_position", Vector3.ZERO),
		"lane_points": lane_points,
		"lane_length_m": float(lane.get("path_length_m", 0.0)),
		"tint": descriptor.get("tint", Color(0.7, 0.74, 0.78, 1.0)),
	})
	ground_state(state)
	return state

func _prune_inactive_pages() -> void:
	var page_cache_capacity := int(_budget_contract.get("page_cache_capacity", 96))
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
	for pedestrian_id_variant in page.get("state_ids", []):
		_states_by_id.erase(str(pedestrian_id_variant))
	_pages_by_chunk_id.erase(chunk_id)
	_ground_contexts_by_chunk_id.erase(chunk_id)
	_page_eviction_count += 1

func _count_active_pages() -> int:
	var count := 0
	for page in _pages_by_chunk_id.values():
		if bool((page as Dictionary).get("active", false)):
			count += 1
	return count

func _resolve_ground_context_for_state(state: CityPedestrianState) -> Dictionary:
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
