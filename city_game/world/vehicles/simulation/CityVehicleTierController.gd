extends RefCounted

const CityVehicleBudget := preload("res://city_game/world/vehicles/streaming/CityVehicleBudget.gd")
const CityVehicleStreamer := preload("res://city_game/world/vehicles/streaming/CityVehicleStreamer.gd")
const CityVehicleState := preload("res://city_game/world/vehicles/simulation/CityVehicleState.gd")

const ASSIGNMENT_REBUILD_INTERVAL_SEC := 0.18
const PLAYER_ASSIGNMENT_REBUILD_DISTANCE_M := 96.0

var _config = null
var _budget := CityVehicleBudget.new()
var _vehicle_streamer := CityVehicleStreamer.new()
var _budget_contract: Dictionary = {}
var _global_snapshot: Dictionary = {}
var _chunk_render_snapshots: Dictionary = {}
var _tier0_state_refs: Array[CityVehicleState] = []
var _tier1_state_refs: Array[CityVehicleState] = []
var _tier2_state_refs: Array[CityVehicleState] = []
var _tier3_state_refs: Array[CityVehicleState] = []
var _last_assignment_chunk_ids: Array[String] = []
var _last_assignment_player_position := Vector3.ZERO
var _assignment_rebuild_elapsed_sec := 0.0
var _has_assignment_cache := false
var _last_profile_stats := {
	"traffic_spawn_usec": 0,
	"traffic_update_usec": 0,
	"traffic_active_state_count": 0,
	"traffic_step_usec": 0,
	"traffic_rank_usec": 0,
	"traffic_snapshot_rebuild_usec": 0,
	"traffic_tier1_count": 0,
	"traffic_tier2_count": 0,
	"traffic_tier3_count": 0,
}

func setup(config, world_data: Dictionary) -> void:
	_config = config
	_budget = CityVehicleBudget.new()
	_budget.setup(config)
	_budget_contract = _budget.get_contract()
	_vehicle_streamer = CityVehicleStreamer.new()
	_vehicle_streamer.setup(_config, world_data, _budget_contract)
	_global_snapshot.clear()
	_chunk_render_snapshots.clear()
	_tier0_state_refs.clear()
	_tier1_state_refs.clear()
	_tier2_state_refs.clear()
	_tier3_state_refs.clear()
	_last_assignment_chunk_ids.clear()
	_last_assignment_player_position = Vector3.ZERO
	_assignment_rebuild_elapsed_sec = 0.0
	_has_assignment_cache = false
	_last_profile_stats = {
		"traffic_spawn_usec": 0,
		"traffic_update_usec": 0,
		"traffic_active_state_count": 0,
		"traffic_step_usec": 0,
		"traffic_rank_usec": 0,
		"traffic_snapshot_rebuild_usec": 0,
		"traffic_tier1_count": 0,
		"traffic_tier2_count": 0,
		"traffic_tier3_count": 0,
	}

func get_budget_contract() -> Dictionary:
	return _budget_contract.duplicate(true)

func prewarm_chunk_entries(chunk_entries: Array) -> void:
	_vehicle_streamer.prewarm_chunk_entries(chunk_entries)

func update_active_chunks(active_chunk_entries: Array, player_position: Vector3, delta: float = 0.0) -> Dictionary:
	var update_started_usec := Time.get_ticks_usec()
	var spawn_started_usec := Time.get_ticks_usec()
	_vehicle_streamer.sync_active_chunks(active_chunk_entries)
	var traffic_spawn_usec := Time.get_ticks_usec() - spawn_started_usec
	var active_states: Array = _vehicle_streamer.get_active_states()

	var step_started_usec := Time.get_ticks_usec()
	if delta > 0.0:
		for state_variant in active_states:
			var state: CityVehicleState = state_variant
			state.step(delta)
	var traffic_step_usec := _duration_or_zero(step_started_usec, active_states.size()) if delta > 0.0 else 0

	var active_chunk_ids: Array[String] = []
	for entry_variant in active_chunk_entries:
		active_chunk_ids.append(str((entry_variant as Dictionary).get("chunk_id", "")))
	active_chunk_ids.sort()
	_assignment_rebuild_elapsed_sec += maxf(delta, 0.0)
	if not _should_rebuild_assignments(active_chunk_ids, player_position):
		var reuse_result := _rebuild_chunk_snapshots_from_cached_assignments(active_chunk_ids)
		var runtime_snapshot: Dictionary = _vehicle_streamer.get_runtime_summary()
		_update_runtime_snapshot(
			active_chunk_ids.size(),
			active_states.size(),
			int(reuse_result.get("tier0_count", 0)),
			int(reuse_result.get("tier1_count", 0)),
			int(reuse_result.get("tier2_count", 0)),
			int(reuse_result.get("tier3_count", 0)),
			runtime_snapshot,
			traffic_spawn_usec,
			traffic_step_usec,
			0,
			int(reuse_result.get("traffic_snapshot_rebuild_usec", 0)),
			update_started_usec
		)
		return get_global_summary()
	var ranking_started_usec := Time.get_ticks_usec()
	var distance_ranked_states: Array[CityVehicleState] = []
	for state_variant in active_states:
		distance_ranked_states.append(state_variant)
	distance_ranked_states.sort_custom(func(a: CityVehicleState, b: CityVehicleState) -> bool:
		return player_position.distance_squared_to(a.world_position) < player_position.distance_squared_to(b.world_position)
	)
	var traffic_rank_usec := _duration_or_zero(ranking_started_usec, distance_ranked_states.size())
	var tier1_budget := int(_budget_contract.get("tier1_budget", 4))
	var tier2_budget := int(_budget_contract.get("tier2_budget", 2))
	var tier3_budget := int(_budget_contract.get("tier3_budget", 1))
	var nearfield_budget := int(_budget_contract.get("nearfield_budget", tier2_budget))
	var tier2_radius_sq := pow(float(_budget_contract.get("tier2_radius_m", 120.0)), 2.0)
	var tier3_radius_sq := pow(float(_budget_contract.get("tier3_radius_m", 36.0)), 2.0)

	var snapshot_rebuild_started_usec := Time.get_ticks_usec()
	var next_chunk_render_snapshots: Dictionary = {}
	_tier0_state_refs.clear()
	_tier1_state_refs.clear()
	_tier2_state_refs.clear()
	_tier3_state_refs.clear()
	var tier0_count := 0
	var tier1_count := 0
	var tier2_count := 0
	var tier3_count := 0
	for chunk_id in active_chunk_ids:
		next_chunk_render_snapshots[chunk_id] = _make_empty_chunk_render_snapshot(chunk_id)

	for state_variant in distance_ranked_states:
		var state: CityVehicleState = state_variant
		var chunk_id := state.chunk_id
		if not next_chunk_render_snapshots.has(chunk_id):
			next_chunk_render_snapshots[chunk_id] = _make_empty_chunk_render_snapshot(chunk_id)
		var chunk_snapshot: Dictionary = next_chunk_render_snapshots[chunk_id]
		var distance_sq := player_position.distance_squared_to(state.world_position)
		var nearfield_count := tier2_count + tier3_count
		if distance_sq <= tier3_radius_sq and tier3_count < tier3_budget:
			state.set_tier(CityVehicleState.TIER_3)
			_vehicle_streamer.ground_state(state)
			_tier3_state_refs.append(state)
			var tier3_states: Array = chunk_snapshot.get("tier3_states", [])
			tier3_states.append(state.to_render_snapshot())
			chunk_snapshot["tier3_states"] = tier3_states
			tier3_count += 1
			chunk_snapshot["tier3_count"] = int(chunk_snapshot.get("tier3_count", 0)) + 1
		elif distance_sq <= tier2_radius_sq and nearfield_count < nearfield_budget and tier2_count < tier2_budget:
			state.set_tier(CityVehicleState.TIER_2)
			_vehicle_streamer.ground_state(state)
			_tier2_state_refs.append(state)
			var tier2_states: Array = chunk_snapshot.get("tier2_states", [])
			tier2_states.append(state.to_render_snapshot())
			chunk_snapshot["tier2_states"] = tier2_states
			tier2_count += 1
			chunk_snapshot["tier2_count"] = int(chunk_snapshot.get("tier2_count", 0)) + 1
		elif tier1_count < tier1_budget:
			state.set_tier(CityVehicleState.TIER_1)
			_vehicle_streamer.ground_state(state)
			_tier1_state_refs.append(state)
			var tier1_states: Array = chunk_snapshot.get("tier1_states", [])
			tier1_states.append(state.to_render_snapshot())
			chunk_snapshot["tier1_states"] = tier1_states
			tier1_count += 1
			chunk_snapshot["tier1_count"] = int(chunk_snapshot.get("tier1_count", 0)) + 1
		else:
			state.set_tier(CityVehicleState.TIER_0)
			_tier0_state_refs.append(state)
			tier0_count += 1
			chunk_snapshot["tier0_count"] = int(chunk_snapshot.get("tier0_count", 0)) + 1
		next_chunk_render_snapshots[chunk_id] = chunk_snapshot

	for chunk_id_variant in next_chunk_render_snapshots.keys():
		var chunk_id := str(chunk_id_variant)
		var next_snapshot: Dictionary = next_chunk_render_snapshots[chunk_id]
		var previous_snapshot: Dictionary = _chunk_render_snapshots.get(chunk_id, {})
		next_snapshot["dirty"] = not _chunk_snapshot_matches(previous_snapshot, next_snapshot)
		next_snapshot["farfield_render_dirty"] = false
		next_chunk_render_snapshots[chunk_id] = next_snapshot
	_chunk_render_snapshots = next_chunk_render_snapshots
	var traffic_snapshot_rebuild_usec := _duration_or_zero(snapshot_rebuild_started_usec, next_chunk_render_snapshots.size())

	var runtime_snapshot: Dictionary = _vehicle_streamer.get_runtime_summary()
	_update_runtime_snapshot(
		active_chunk_ids.size(),
		active_states.size(),
		tier0_count,
		tier1_count,
		tier2_count,
		tier3_count,
		runtime_snapshot,
		traffic_spawn_usec,
		traffic_step_usec,
		traffic_rank_usec,
		traffic_snapshot_rebuild_usec,
		update_started_usec
	)
	_last_assignment_chunk_ids = active_chunk_ids.duplicate()
	_last_assignment_player_position = player_position
	_assignment_rebuild_elapsed_sec = 0.0
	_has_assignment_cache = true
	return get_global_summary()

func get_global_summary() -> Dictionary:
	return {
		"preset": str(_global_snapshot.get("preset", "lite")),
		"active_chunk_count": int(_global_snapshot.get("active_chunk_count", 0)),
		"active_page_count": int(_global_snapshot.get("active_page_count", 0)),
		"active_state_count": int(_global_snapshot.get("active_state_count", 0)),
		"tier0_count": int(_global_snapshot.get("tier0_count", 0)),
		"tier1_count": int(_global_snapshot.get("tier1_count", 0)),
		"tier2_count": int(_global_snapshot.get("tier2_count", 0)),
		"tier3_count": int(_global_snapshot.get("tier3_count", 0)),
		"tier1_budget": int(_global_snapshot.get("tier1_budget", 0)),
		"tier2_budget": int(_global_snapshot.get("tier2_budget", 0)),
		"tier3_budget": int(_global_snapshot.get("tier3_budget", 0)),
		"nearfield_budget": int(_global_snapshot.get("nearfield_budget", 0)),
		"tier2_radius_m": float(_global_snapshot.get("tier2_radius_m", 0.0)),
		"tier3_radius_m": float(_global_snapshot.get("tier3_radius_m", 0.0)),
		"page_cache_hit_count": int(_global_snapshot.get("page_cache_hit_count", 0)),
		"page_cache_miss_count": int(_global_snapshot.get("page_cache_miss_count", 0)),
		"duplicate_page_load_count": int(_global_snapshot.get("duplicate_page_load_count", 0)),
		"profile_stats": (_global_snapshot.get("profile_stats", {}) as Dictionary).duplicate(true),
	}

func get_chunk_snapshot(chunk_id: String) -> Dictionary:
	if not _chunk_render_snapshots.has(chunk_id):
		return _make_empty_chunk_render_snapshot(chunk_id)
	return (_chunk_render_snapshots[chunk_id] as Dictionary).duplicate(true)

func get_chunk_snapshot_ref(chunk_id: String) -> Dictionary:
	if not _chunk_render_snapshots.has(chunk_id):
		return _make_empty_chunk_render_snapshot(chunk_id)
	return _chunk_render_snapshots[chunk_id]

func get_state_snapshot(vehicle_id: String) -> Dictionary:
	return _vehicle_streamer.get_state_snapshot(vehicle_id)

func get_runtime_snapshot() -> Dictionary:
	var runtime_snapshot: Dictionary = _vehicle_streamer.get_runtime_snapshot()
	runtime_snapshot["tier0_count"] = int(_global_snapshot.get("tier0_count", 0))
	runtime_snapshot["tier1_count"] = int(_global_snapshot.get("tier1_count", 0))
	runtime_snapshot["tier2_count"] = int(_global_snapshot.get("tier2_count", 0))
	runtime_snapshot["tier3_count"] = int(_global_snapshot.get("tier3_count", 0))
	runtime_snapshot["tier1_states"] = _build_full_state_snapshots(_tier1_state_refs)
	runtime_snapshot["tier2_states"] = _build_full_state_snapshots(_tier2_state_refs)
	runtime_snapshot["tier3_states"] = _build_full_state_snapshots(_tier3_state_refs)
	runtime_snapshot["nearfield_budget"] = int(_budget_contract.get("nearfield_budget", 3))
	runtime_snapshot["tier3_budget"] = int(_budget_contract.get("tier3_budget", 1))
	runtime_snapshot["budget_contract"] = _budget_contract.duplicate(true)
	runtime_snapshot["profile_stats"] = _last_profile_stats.duplicate(true)
	return runtime_snapshot

func resolve_projectile_hit(start_position: Vector3, end_position: Vector3, _damage: float = 1.0, _velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	var best_state: CityVehicleState = null
	var best_distance_sq := INF
	var best_hit_position := end_position
	for state in _get_interactive_nearfield_states():
		var vehicle_center := state.world_position + Vector3.UP * maxf(state.height_m * 0.5, 0.75)
		var closest := _closest_point_on_segment(vehicle_center, start_position, end_position)
		var hit_radius_m := maxf(maxf(state.length_m, state.width_m) * 0.35, 1.2)
		var distance_sq := vehicle_center.distance_squared_to(closest)
		if distance_sq > hit_radius_m * hit_radius_m:
			continue
		if distance_sq >= best_distance_sq:
			continue
		best_state = state
		best_distance_sq = distance_sq
		best_hit_position = closest
	if best_state == null:
		return {}
	best_state.request_stop("projectile")
	_mark_state_chunk_dirty(best_state)
	return {
		"vehicle_id": best_state.vehicle_id,
		"chunk_id": best_state.chunk_id,
		"hit_position": best_hit_position,
		"interaction_state": best_state.get_interaction_state(),
	}

func resolve_explosion_impact(world_position: Vector3, radius_m: float) -> Dictionary:
	var stopped_ids: Array[String] = []
	for state in _get_interactive_nearfield_states():
		var stop_radius_m := radius_m + maxf(maxf(state.length_m, state.width_m) * 0.4, 1.0)
		if state.world_position.distance_to(world_position) > stop_radius_m:
			continue
		if state.get_interaction_state() != CityVehicleState.INTERACTION_STOPPED:
			stopped_ids.append(state.vehicle_id)
		state.request_stop("explosion")
		_mark_state_chunk_dirty(state)
	return {
		"stopped_count": stopped_ids.size(),
		"stopped_vehicle_ids": stopped_ids.duplicate(),
	}

func find_hijackable_vehicle_candidate(player_position: Vector3, max_distance_m: float = 6.5) -> Dictionary:
	var best_state: CityVehicleState = null
	var best_distance_m := max_distance_m
	for state in _get_interactive_nearfield_states():
		if not state.is_hijackable():
			continue
		var distance_m := player_position.distance_to(state.world_position)
		if distance_m > best_distance_m:
			continue
		best_state = state
		best_distance_m = distance_m
	if best_state == null:
		return {}
	var snapshot := best_state.to_snapshot()
	snapshot["distance_m"] = best_distance_m
	return snapshot

func claim_vehicle(vehicle_id: String) -> Dictionary:
	var state: CityVehicleState = _vehicle_streamer.get_state(vehicle_id)
	if state == null or not state.is_hijackable():
		return {}
	var snapshot := state.to_snapshot()
	state.claim_for_player()
	_vehicle_streamer.invalidate_active_state_cache()
	_drop_state_from_cached_assignments(vehicle_id)
	snapshot["success"] = true
	return snapshot

func get_runtime_summary() -> Dictionary:
	var runtime_snapshot: Dictionary = _vehicle_streamer.get_runtime_summary()
	return {
		"active_page_count": int(runtime_snapshot.get("active_page_count", 0)),
		"cached_page_count": int(runtime_snapshot.get("cached_page_count", 0)),
		"resident_state_count": int(runtime_snapshot.get("resident_state_count", 0)),
		"page_cache_hit_count": int(runtime_snapshot.get("page_cache_hit_count", 0)),
		"page_cache_miss_count": int(runtime_snapshot.get("page_cache_miss_count", 0)),
		"page_generation_count": int(runtime_snapshot.get("page_generation_count", 0)),
		"duplicate_page_load_count": int(runtime_snapshot.get("duplicate_page_load_count", 0)),
		"page_eviction_count": int(runtime_snapshot.get("page_eviction_count", 0)),
		"tier0_count": int(_global_snapshot.get("tier0_count", 0)),
		"tier1_count": int(_global_snapshot.get("tier1_count", 0)),
		"tier2_count": int(_global_snapshot.get("tier2_count", 0)),
		"tier3_count": int(_global_snapshot.get("tier3_count", 0)),
		"nearfield_budget": int(_budget_contract.get("nearfield_budget", 3)),
		"tier3_budget": int(_budget_contract.get("tier3_budget", 1)),
	}

func _build_full_state_snapshots(states: Array[CityVehicleState]) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for state in states:
		snapshots.append(state.to_snapshot())
	return snapshots

func _make_empty_chunk_render_snapshot(chunk_id: String) -> Dictionary:
	return {
		"chunk_id": chunk_id,
		"dirty": false,
		"farfield_render_dirty": false,
		"tier0_count": 0,
		"tier1_count": 0,
		"tier2_count": 0,
		"tier3_count": 0,
		"tier1_states": [],
		"tier2_states": [],
		"tier3_states": [],
	}

func _should_rebuild_assignments(active_chunk_ids: Array[String], player_position: Vector3) -> bool:
	if not _has_assignment_cache:
		return true
	if not _string_arrays_equal(_last_assignment_chunk_ids, active_chunk_ids):
		return true
	if player_position.distance_to(_last_assignment_player_position) > PLAYER_ASSIGNMENT_REBUILD_DISTANCE_M:
		return true
	return _assignment_rebuild_elapsed_sec >= ASSIGNMENT_REBUILD_INTERVAL_SEC

func _rebuild_chunk_snapshots_from_cached_assignments(active_chunk_ids: Array[String]) -> Dictionary:
	var snapshot_started_usec := Time.get_ticks_usec()
	var next_chunk_render_snapshots: Dictionary = {}
	var tier0_count := 0
	var tier1_count := 0
	var tier2_count := 0
	var tier3_count := 0
	for chunk_id in active_chunk_ids:
		next_chunk_render_snapshots[chunk_id] = _make_empty_chunk_render_snapshot(chunk_id)
	for state in _tier0_state_refs:
		if state == null or not next_chunk_render_snapshots.has(state.chunk_id):
			continue
		var chunk_snapshot: Dictionary = next_chunk_render_snapshots[state.chunk_id]
		chunk_snapshot["tier0_count"] = int(chunk_snapshot.get("tier0_count", 0)) + 1
		next_chunk_render_snapshots[state.chunk_id] = chunk_snapshot
		tier0_count += 1
	for state in _tier1_state_refs:
		if state == null or not next_chunk_render_snapshots.has(state.chunk_id):
			continue
		_vehicle_streamer.ground_state(state)
		var chunk_snapshot: Dictionary = next_chunk_render_snapshots[state.chunk_id]
		var tier1_states: Array = chunk_snapshot.get("tier1_states", [])
		tier1_states.append(state.to_render_snapshot())
		chunk_snapshot["tier1_states"] = tier1_states
		chunk_snapshot["tier1_count"] = int(chunk_snapshot.get("tier1_count", 0)) + 1
		next_chunk_render_snapshots[state.chunk_id] = chunk_snapshot
		tier1_count += 1
	for state in _tier2_state_refs:
		if state == null or not next_chunk_render_snapshots.has(state.chunk_id):
			continue
		_vehicle_streamer.ground_state(state)
		var chunk_snapshot: Dictionary = next_chunk_render_snapshots[state.chunk_id]
		var tier2_states: Array = chunk_snapshot.get("tier2_states", [])
		tier2_states.append(state.to_render_snapshot())
		chunk_snapshot["tier2_states"] = tier2_states
		chunk_snapshot["tier2_count"] = int(chunk_snapshot.get("tier2_count", 0)) + 1
		next_chunk_render_snapshots[state.chunk_id] = chunk_snapshot
		tier2_count += 1
	for state in _tier3_state_refs:
		if state == null or not next_chunk_render_snapshots.has(state.chunk_id):
			continue
		_vehicle_streamer.ground_state(state)
		var chunk_snapshot: Dictionary = next_chunk_render_snapshots[state.chunk_id]
		var tier3_states: Array = chunk_snapshot.get("tier3_states", [])
		tier3_states.append(state.to_render_snapshot())
		chunk_snapshot["tier3_states"] = tier3_states
		chunk_snapshot["tier3_count"] = int(chunk_snapshot.get("tier3_count", 0)) + 1
		next_chunk_render_snapshots[state.chunk_id] = chunk_snapshot
		tier3_count += 1
	for chunk_id_variant in next_chunk_render_snapshots.keys():
		var chunk_id := str(chunk_id_variant)
		var next_snapshot: Dictionary = next_chunk_render_snapshots[chunk_id]
		var previous_snapshot: Dictionary = _chunk_render_snapshots.get(chunk_id, {})
		next_snapshot["dirty"] = not _chunk_snapshot_matches(previous_snapshot, next_snapshot)
		next_snapshot["farfield_render_dirty"] = false
		next_chunk_render_snapshots[chunk_id] = next_snapshot
	_chunk_render_snapshots = next_chunk_render_snapshots
	return {
		"tier0_count": tier0_count,
		"tier1_count": tier1_count,
		"tier2_count": tier2_count,
		"tier3_count": tier3_count,
		"traffic_snapshot_rebuild_usec": _duration_or_zero(snapshot_started_usec, next_chunk_render_snapshots.size()),
	}

func _chunk_snapshot_matches(previous_snapshot: Dictionary, next_snapshot: Dictionary) -> bool:
	if previous_snapshot.is_empty():
		return false
	for key in ["tier0_count", "tier1_count", "tier2_count", "tier3_count"]:
		if int(previous_snapshot.get(key, -1)) != int(next_snapshot.get(key, -2)):
			return false
	for key in ["tier1_states", "tier2_states", "tier3_states"]:
		if not _state_snapshot_arrays_match(previous_snapshot.get(key, []), next_snapshot.get(key, [])):
			return false
	return true

func _string_arrays_equal(lhs: Array[String], rhs: Array[String]) -> bool:
	if lhs.size() != rhs.size():
		return false
	for item_index in range(lhs.size()):
		if lhs[item_index] != rhs[item_index]:
			return false
	return true

func _state_snapshot_arrays_match(previous_states: Array, next_states: Array) -> bool:
	if previous_states.size() != next_states.size():
		return false
	for state_index in range(previous_states.size()):
		var previous_state: Dictionary = previous_states[state_index]
		var next_state: Dictionary = next_states[state_index]
		if str(previous_state.get("vehicle_id", "")) != str(next_state.get("vehicle_id", "")):
			return false
		if not (previous_state.get("world_position", Vector3.ZERO) as Vector3).is_equal_approx(next_state.get("world_position", Vector3.ZERO)):
			return false
		if not (previous_state.get("heading", Vector3.FORWARD) as Vector3).is_equal_approx(next_state.get("heading", Vector3.FORWARD)):
			return false
	return true

func _update_runtime_snapshot(
	active_chunk_count: int,
	active_state_count: int,
	tier0_count: int,
	tier1_count: int,
	tier2_count: int,
	tier3_count: int,
	runtime_snapshot: Dictionary,
	traffic_spawn_usec: int,
	traffic_step_usec: int,
	traffic_rank_usec: int,
	traffic_snapshot_rebuild_usec: int,
	update_started_usec: int
) -> void:
	_global_snapshot = {
		"preset": str(_budget_contract.get("preset", "lite")),
		"active_chunk_count": active_chunk_count,
		"active_page_count": int(runtime_snapshot.get("active_page_count", 0)),
		"active_state_count": active_state_count,
		"tier0_count": tier0_count,
		"tier1_count": tier1_count,
		"tier2_count": tier2_count,
		"tier3_count": tier3_count,
		"tier1_budget": int(_budget_contract.get("tier1_budget", 4)),
		"tier2_budget": int(_budget_contract.get("tier2_budget", 2)),
		"tier3_budget": int(_budget_contract.get("tier3_budget", 1)),
		"nearfield_budget": int(_budget_contract.get("nearfield_budget", 3)),
		"tier2_radius_m": float(_budget_contract.get("tier2_radius_m", 120.0)),
		"tier3_radius_m": float(_budget_contract.get("tier3_radius_m", 36.0)),
		"page_cache_hit_count": int(runtime_snapshot.get("page_cache_hit_count", 0)),
		"page_cache_miss_count": int(runtime_snapshot.get("page_cache_miss_count", 0)),
		"duplicate_page_load_count": int(runtime_snapshot.get("duplicate_page_load_count", 0)),
	}
	_last_profile_stats = {
		"traffic_spawn_usec": traffic_spawn_usec,
		"traffic_update_usec": Time.get_ticks_usec() - update_started_usec,
		"traffic_active_state_count": active_state_count,
		"traffic_step_usec": traffic_step_usec,
		"traffic_rank_usec": traffic_rank_usec,
		"traffic_snapshot_rebuild_usec": traffic_snapshot_rebuild_usec,
		"traffic_tier1_count": tier1_count,
		"traffic_tier2_count": tier2_count,
		"traffic_tier3_count": tier3_count,
	}
	_global_snapshot["profile_stats"] = _last_profile_stats.duplicate(true)

func _duration_or_zero(started_usec: int, item_count: int) -> int:
	if item_count <= 0:
		return 0
	return maxi(int(Time.get_ticks_usec() - started_usec), 1)

func _get_interactive_nearfield_states() -> Array[CityVehicleState]:
	var states: Array[CityVehicleState] = []
	for state in _tier3_state_refs:
		if state != null and state.is_runtime_active():
			states.append(state)
	for state in _tier2_state_refs:
		if state != null and state.is_runtime_active():
			states.append(state)
	return states

func _closest_point_on_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> Vector3:
	var segment := segment_end - segment_start
	var length_sq := segment.length_squared()
	if length_sq <= 0.0001:
		return segment_start
	var t := clampf((point - segment_start).dot(segment) / length_sq, 0.0, 1.0)
	return segment_start + segment * t

func _mark_state_chunk_dirty(state: CityVehicleState) -> void:
	if state == null:
		return
	if not _chunk_render_snapshots.has(state.chunk_id):
		return
	var chunk_snapshot: Dictionary = _chunk_render_snapshots[state.chunk_id]
	chunk_snapshot["dirty"] = true
	_chunk_render_snapshots[state.chunk_id] = chunk_snapshot

func _drop_state_from_cached_assignments(vehicle_id: String) -> void:
	_tier0_state_refs = _filter_out_vehicle(_tier0_state_refs, vehicle_id)
	_tier1_state_refs = _filter_out_vehicle(_tier1_state_refs, vehicle_id)
	_tier2_state_refs = _filter_out_vehicle(_tier2_state_refs, vehicle_id)
	_tier3_state_refs = _filter_out_vehicle(_tier3_state_refs, vehicle_id)
	for chunk_id_variant in _chunk_render_snapshots.keys():
		var chunk_id := str(chunk_id_variant)
		var chunk_snapshot: Dictionary = _chunk_render_snapshots[chunk_id]
		chunk_snapshot["tier1_states"] = _filter_snapshot_states(chunk_snapshot.get("tier1_states", []), vehicle_id)
		chunk_snapshot["tier2_states"] = _filter_snapshot_states(chunk_snapshot.get("tier2_states", []), vehicle_id)
		chunk_snapshot["tier3_states"] = _filter_snapshot_states(chunk_snapshot.get("tier3_states", []), vehicle_id)
		chunk_snapshot["tier1_count"] = (chunk_snapshot.get("tier1_states", []) as Array).size()
		chunk_snapshot["tier2_count"] = (chunk_snapshot.get("tier2_states", []) as Array).size()
		chunk_snapshot["tier3_count"] = (chunk_snapshot.get("tier3_states", []) as Array).size()
		chunk_snapshot["dirty"] = true
		_chunk_render_snapshots[chunk_id] = chunk_snapshot
	_has_assignment_cache = false

func _filter_out_vehicle(states: Array[CityVehicleState], vehicle_id: String) -> Array[CityVehicleState]:
	var filtered: Array[CityVehicleState] = []
	for state in states:
		if state == null or state.vehicle_id == vehicle_id:
			continue
		filtered.append(state)
	return filtered

func _filter_snapshot_states(states: Array, vehicle_id: String) -> Array:
	var filtered: Array = []
	for state_variant in states:
		var state: Dictionary = state_variant
		if str(state.get("vehicle_id", "")) == vehicle_id:
			continue
		filtered.append(state)
	return filtered
