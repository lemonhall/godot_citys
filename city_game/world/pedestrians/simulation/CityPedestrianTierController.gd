extends RefCounted

const CityPedestrianBudget := preload("res://city_game/world/pedestrians/streaming/CityPedestrianBudget.gd")
const CityPedestrianStreamer := preload("res://city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd")
const CityPedestrianState := preload("res://city_game/world/pedestrians/simulation/CityPedestrianState.gd")
const CityPedestrianReactionModel := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd")

const TIER1_UPDATE_INTERVAL_SEC := 0.12
const TIER0_UPDATE_INTERVAL_SEC := 0.35

var _config = null
var _budget := CityPedestrianBudget.new()
var _pedestrian_streamer := CityPedestrianStreamer.new()
var _reaction_model := CityPedestrianReactionModel.new()
var _budget_contract: Dictionary = {}
var _global_snapshot: Dictionary = {}
var _chunk_snapshots: Dictionary = {}
var _last_player_position := Vector3.ZERO
var _last_player_velocity := Vector3.ZERO
var _has_player_context := false
var _last_profile_stats := {
	"crowd_spawn_usec": 0,
	"crowd_update_usec": 0,
}

func setup(config, world_data: Dictionary) -> void:
	_config = config
	_budget = CityPedestrianBudget.new()
	_budget.setup(config)
	_budget_contract = _budget.get_contract()
	_pedestrian_streamer = CityPedestrianStreamer.new()
	_pedestrian_streamer.setup(_config, world_data, _budget_contract)
	_reaction_model = CityPedestrianReactionModel.new()
	_global_snapshot.clear()
	_chunk_snapshots.clear()
	_last_player_position = Vector3.ZERO
	_last_player_velocity = Vector3.ZERO
	_has_player_context = false
	_last_profile_stats = {
		"crowd_spawn_usec": 0,
		"crowd_update_usec": 0,
	}

func get_budget_contract() -> Dictionary:
	return _budget_contract.duplicate(true)

func set_player_context(player_position: Vector3, player_velocity: Vector3 = Vector3.ZERO) -> void:
	_reaction_model.set_player_context(player_position, player_velocity)
	_last_player_position = player_position
	_last_player_velocity = player_velocity
	_has_player_context = true

func notify_projectile_event(origin: Vector3, direction: Vector3, range_m: float = 36.0) -> void:
	_reaction_model.notify_projectile_event(origin, direction, range_m)

func notify_explosion_event(world_position: Vector3, radius_m: float) -> void:
	_reaction_model.notify_explosion_event(world_position, radius_m)

func resolve_projectile_hit(start_position: Vector3, end_position: Vector3, damage: float = 1.0, velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	var best_hit := {}
	for state_variant in _pedestrian_streamer.get_active_states():
		var state: CityPedestrianState = state_variant
		if not state.is_alive():
			continue
		var hit: Dictionary = _projectile_hit_for_state(state, start_position, end_position)
		if hit.is_empty():
			continue
		if best_hit.is_empty() or float(hit.get("travel_t", 1.0)) < float(best_hit.get("travel_t", 1.0)):
			best_hit = hit
	if best_hit.is_empty():
		return {}
	var hit_state: CityPedestrianState = best_hit.get("state")
	hit_state.mark_dead("projectile", best_hit.get("hit_position", end_position))
	return {
		"pedestrian_id": hit_state.pedestrian_id,
		"life_state": hit_state.life_state,
		"damage": damage,
		"hit_position": best_hit.get("hit_position", end_position),
		"hit_distance_m": float(best_hit.get("hit_distance_m", start_position.distance_to(end_position))),
		"velocity": velocity,
	}

func resolve_explosion_impact(world_position: Vector3, lethal_radius_m: float, threat_radius_m: float = -1.0) -> Dictionary:
	var resolved_threat_radius_m := threat_radius_m if threat_radius_m >= 0.0 else lethal_radius_m
	var killed_ids: Array[String] = []
	for state_variant in _pedestrian_streamer.get_active_states():
		var state: CityPedestrianState = state_variant
		if not state.is_alive():
			continue
		var distance_m := state.world_position.distance_to(world_position)
		if distance_m <= lethal_radius_m:
			state.mark_dead("explosion", world_position)
			killed_ids.append(state.pedestrian_id)
	_reaction_model.notify_explosion_event(world_position, lethal_radius_m, resolved_threat_radius_m)
	return {
		"killed_count": killed_ids.size(),
		"killed_ids": killed_ids,
		"lethal_radius_m": lethal_radius_m,
		"threat_radius_m": resolved_threat_radius_m,
	}

func update_active_chunks(active_chunk_entries: Array, player_position: Vector3, delta: float = 0.0) -> Dictionary:
	var update_started_usec := Time.get_ticks_usec()
	var inferred_player_velocity := Vector3.ZERO
	if _has_player_context and player_position == _last_player_position:
		inferred_player_velocity = _last_player_velocity
	elif _has_player_context and delta > 0.0:
		inferred_player_velocity = (player_position - _last_player_position) / delta
	set_player_context(player_position, inferred_player_velocity)

	var active_chunk_ids: Array[String] = []
	for entry_variant in active_chunk_entries:
		active_chunk_ids.append(str((entry_variant as Dictionary).get("chunk_id", "")))
	var spawn_started_usec := Time.get_ticks_usec()
	var streaming_snapshot: Dictionary = _pedestrian_streamer.sync_active_chunks(active_chunk_entries)
	var crowd_spawn_usec := Time.get_ticks_usec() - spawn_started_usec
	var active_states: Array = _pedestrian_streamer.get_active_states()

	if delta > 0.0:
		for state_variant in active_states:
			var state: CityPedestrianState = state_variant
			state.queue_step(delta)
			var step_delta := _resolve_step_delta_for_state(state)
			if step_delta <= 0.0:
				continue
			state.step(step_delta)
			_pedestrian_streamer.ground_state(state)

	var reactive_candidates := _reaction_model.update_reactions(active_states, _budget_contract, delta)
	var reactive_rankings := _rank_reactive_candidates(reactive_candidates)
	var tier3_ids: Dictionary = _select_tier3_ids(reactive_rankings)
	var distance_rankings := _build_distance_rankings(active_states, player_position)

	var tier1_budget := int(_budget_contract.get("tier1_budget", 768))
	var tier2_budget := int(_budget_contract.get("tier2_budget", 96))
	var tier3_budget := int(_budget_contract.get("tier3_budget", 24))
	var nearfield_budget := int(_budget_contract.get("nearfield_budget", tier2_budget))
	var tier2_radius_m := float(_budget_contract.get("tier2_radius_m", 110.0))

	var tier1_states: Array[Dictionary] = []
	var tier2_states: Array[Dictionary] = []
	var tier3_states: Array[Dictionary] = []
	var tier0_count := 0
	var tier1_count := 0
	var tier2_count := 0
	var tier3_count := 0
	var remaining_tier2_budget: int = maxi(nearfield_budget - tier3_ids.size(), 0)
	remaining_tier2_budget = mini(remaining_tier2_budget, tier2_budget)
	_chunk_snapshots.clear()
	for chunk_id in active_chunk_ids:
		_chunk_snapshots[chunk_id] = {
			"chunk_id": chunk_id,
			"tier0_count": 0,
			"tier1_count": 0,
			"tier2_count": 0,
			"tier3_count": 0,
			"tier1_states": [],
			"tier2_states": [],
			"tier3_states": [],
		}

	for ranking_variant in distance_rankings:
		var ranking: Dictionary = ranking_variant
		var pedestrian_id := str(ranking.get("pedestrian_id", ""))
		var state: CityPedestrianState = _pedestrian_streamer.get_state(pedestrian_id)
		if state == null:
			continue
		if not _chunk_snapshots.has(state.chunk_id):
			_chunk_snapshots[state.chunk_id] = {
				"chunk_id": state.chunk_id,
				"tier0_count": 0,
				"tier1_count": 0,
				"tier2_count": 0,
				"tier3_count": 0,
				"tier1_states": [],
				"tier2_states": [],
				"tier3_states": [],
			}
		var chunk_snapshot: Dictionary = _chunk_snapshots[state.chunk_id]
		var distance_m := float(ranking.get("distance_m", 0.0))
		if tier3_ids.has(pedestrian_id):
			state.set_tier(CityPedestrianState.TIER_3)
			var tier3_snapshot := state.to_snapshot()
			tier3_states.append(tier3_snapshot)
			var chunk_tier3_states: Array = chunk_snapshot.get("tier3_states", [])
			chunk_tier3_states.append(tier3_snapshot)
			chunk_snapshot["tier3_states"] = chunk_tier3_states
			tier3_count += 1
			chunk_snapshot["tier3_count"] = int(chunk_snapshot.get("tier3_count", 0)) + 1
			_chunk_snapshots[state.chunk_id] = chunk_snapshot
			continue
		if state.is_reactive():
			state.clear_reaction()
		if distance_m <= tier2_radius_m and tier2_count < remaining_tier2_budget:
			state.set_tier(CityPedestrianState.TIER_2)
			var tier2_snapshot := state.to_snapshot()
			tier2_states.append(tier2_snapshot)
			var chunk_tier2_states: Array = chunk_snapshot.get("tier2_states", [])
			chunk_tier2_states.append(tier2_snapshot)
			chunk_snapshot["tier2_states"] = chunk_tier2_states
			tier2_count += 1
			chunk_snapshot["tier2_count"] = int(chunk_snapshot.get("tier2_count", 0)) + 1
		elif tier1_count < tier1_budget:
			state.set_tier(CityPedestrianState.TIER_1)
			var tier1_snapshot := state.to_snapshot()
			tier1_states.append(tier1_snapshot)
			var chunk_tier1_states: Array = chunk_snapshot.get("tier1_states", [])
			chunk_tier1_states.append(tier1_snapshot)
			chunk_snapshot["tier1_states"] = chunk_tier1_states
			tier1_count += 1
			chunk_snapshot["tier1_count"] = int(chunk_snapshot.get("tier1_count", 0)) + 1
		else:
			state.set_tier(CityPedestrianState.TIER_0)
			tier0_count += 1
			chunk_snapshot["tier0_count"] = int(chunk_snapshot.get("tier0_count", 0)) + 1
		_chunk_snapshots[state.chunk_id] = chunk_snapshot

	var runtime_snapshot: Dictionary = _pedestrian_streamer.get_runtime_snapshot()
	_global_snapshot = {
		"preset": str(_budget_contract.get("preset", "lite")),
		"active_chunk_count": active_chunk_ids.size(),
		"active_page_count": int(streaming_snapshot.get("active_page_count", 0)),
		"active_state_count": active_states.size(),
		"tier0_count": tier0_count,
		"tier1_count": tier1_count,
		"tier2_count": tier2_count,
		"tier3_count": tier3_count,
		"tier1_budget": tier1_budget,
		"tier2_budget": tier2_budget,
		"tier3_budget": tier3_budget,
		"nearfield_budget": nearfield_budget,
		"tier2_radius_m": tier2_radius_m,
		"tier3_radius_m": float(_budget_contract.get("tier3_radius_m", 30.0)),
		"tier1_states": tier1_states,
		"tier2_states": tier2_states,
		"tier3_states": tier3_states,
		"page_cache_hit_count": int(runtime_snapshot.get("page_cache_hit_count", 0)),
		"page_cache_miss_count": int(runtime_snapshot.get("page_cache_miss_count", 0)),
		"duplicate_page_load_count": int(runtime_snapshot.get("duplicate_page_load_count", 0)),
		"reactive_event_count": _reaction_model.get_event_count(),
	}
	_last_profile_stats = {
		"crowd_spawn_usec": crowd_spawn_usec,
		"crowd_update_usec": Time.get_ticks_usec() - update_started_usec,
	}
	_global_snapshot["profile_stats"] = _last_profile_stats.duplicate(true)
	return get_global_summary()

func get_global_snapshot() -> Dictionary:
	return _global_snapshot.duplicate(true)

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
		"reactive_event_count": int(_global_snapshot.get("reactive_event_count", 0)),
		"profile_stats": (_global_snapshot.get("profile_stats", {}) as Dictionary).duplicate(true),
	}

func get_chunk_snapshot(chunk_id: String) -> Dictionary:
	if not _chunk_snapshots.has(chunk_id):
		return {
			"chunk_id": chunk_id,
			"tier0_count": 0,
			"tier1_count": 0,
			"tier2_count": 0,
			"tier3_count": 0,
			"tier1_states": [],
			"tier2_states": [],
			"tier3_states": [],
		}
	return (_chunk_snapshots[chunk_id] as Dictionary).duplicate(true)

func get_chunk_snapshot_ref(chunk_id: String) -> Dictionary:
	if not _chunk_snapshots.has(chunk_id):
		return {
			"chunk_id": chunk_id,
			"tier0_count": 0,
			"tier1_count": 0,
			"tier2_count": 0,
			"tier3_count": 0,
			"tier1_states": [],
			"tier2_states": [],
			"tier3_states": [],
		}
	return _chunk_snapshots[chunk_id]

func get_state_snapshot(pedestrian_id: String) -> Dictionary:
	return _pedestrian_streamer.get_state_snapshot(pedestrian_id)

func get_runtime_snapshot() -> Dictionary:
	var runtime_snapshot: Dictionary = _pedestrian_streamer.get_runtime_snapshot()
	runtime_snapshot["tier0_count"] = int(_global_snapshot.get("tier0_count", 0))
	runtime_snapshot["tier1_count"] = int(_global_snapshot.get("tier1_count", 0))
	runtime_snapshot["tier2_count"] = int(_global_snapshot.get("tier2_count", 0))
	runtime_snapshot["tier3_count"] = int(_global_snapshot.get("tier3_count", 0))
	runtime_snapshot["tier1_states"] = (_global_snapshot.get("tier1_states", []) as Array).duplicate(true)
	runtime_snapshot["tier2_states"] = (_global_snapshot.get("tier2_states", []) as Array).duplicate(true)
	runtime_snapshot["tier3_states"] = (_global_snapshot.get("tier3_states", []) as Array).duplicate(true)
	runtime_snapshot["nearfield_budget"] = int(_budget_contract.get("nearfield_budget", 96))
	runtime_snapshot["tier3_budget"] = int(_budget_contract.get("tier3_budget", 24))
	runtime_snapshot["reactive_event_count"] = _reaction_model.get_event_count()
	runtime_snapshot["profile_stats"] = _last_profile_stats.duplicate(true)
	return runtime_snapshot

func get_runtime_summary() -> Dictionary:
	var runtime_snapshot: Dictionary = _pedestrian_streamer.get_runtime_snapshot()
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
		"nearfield_budget": int(_budget_contract.get("nearfield_budget", 96)),
		"tier3_budget": int(_budget_contract.get("tier3_budget", 24)),
		"reactive_event_count": _reaction_model.get_event_count(),
		"profile_stats": _last_profile_stats.duplicate(true),
	}

func _build_distance_rankings(active_states: Array, player_position: Vector3) -> Array[Dictionary]:
	var rankings: Array[Dictionary] = []
	for state_variant in active_states:
		var state: CityPedestrianState = state_variant
		rankings.append({
			"pedestrian_id": state.pedestrian_id,
			"distance_m": player_position.distance_to(state.world_position),
		})
	rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance_m", 0.0)) < float(b.get("distance_m", 0.0))
	)
	return rankings

func _rank_reactive_candidates(reactive_candidates: Array) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for candidate_variant in reactive_candidates:
		ranked.append((candidate_variant as Dictionary).duplicate(true))
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("reaction_priority", 0)) == int(b.get("reaction_priority", 0)):
			return float(a.get("distance_m", 0.0)) < float(b.get("distance_m", 0.0))
		return int(a.get("reaction_priority", 0)) > int(b.get("reaction_priority", 0))
	)
	return ranked

func _select_tier3_ids(reactive_candidates: Array) -> Dictionary:
	var tier3_ids: Dictionary = {}
	var tier3_budget := int(_budget_contract.get("tier3_budget", 24))
	var tier3_radius_m := float(_budget_contract.get("tier3_radius_m", 30.0))
	for candidate_variant in reactive_candidates:
		var candidate: Dictionary = candidate_variant
		if tier3_ids.size() >= tier3_budget:
			break
		if float(candidate.get("distance_m", 0.0)) > tier3_radius_m:
			continue
		tier3_ids[str(candidate.get("pedestrian_id", ""))] = true
	return tier3_ids

func _resolve_step_delta_for_state(state: CityPedestrianState) -> float:
	match state.tier:
		CityPedestrianState.TIER_3, CityPedestrianState.TIER_2:
			return state.flush_queued_step()
		CityPedestrianState.TIER_1:
			return state.consume_queued_step(TIER1_UPDATE_INTERVAL_SEC)
		_:
			return state.consume_queued_step(TIER0_UPDATE_INTERVAL_SEC)

func _projectile_hit_for_state(state: CityPedestrianState, start_position: Vector3, end_position: Vector3) -> Dictionary:
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return {}
	var pedestrian_center := state.world_position + Vector3.UP * maxf(state.height_m * 0.5, 0.6)
	var t := clampf((pedestrian_center - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := start_position + segment * t
	var horizontal_distance_m := Vector2(pedestrian_center.x - closest_point.x, pedestrian_center.z - closest_point.z).length()
	var vertical_clearance_m := absf(pedestrian_center.y - closest_point.y)
	if horizontal_distance_m > maxf(state.radius_m + 0.22, 0.45):
		return {}
	if vertical_clearance_m > maxf(state.height_m * 0.65, 1.15):
		return {}
	return {
		"state": state,
		"travel_t": t,
		"hit_position": closest_point,
		"hit_distance_m": start_position.distance_to(closest_point),
	}
