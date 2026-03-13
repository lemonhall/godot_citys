extends RefCounted

const CityPedestrianBudget := preload("res://city_game/world/pedestrians/streaming/CityPedestrianBudget.gd")
const CityPedestrianStreamer := preload("res://city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd")
const CityPedestrianState := preload("res://city_game/world/pedestrians/simulation/CityPedestrianState.gd")
const CityPedestrianReactionModel := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd")

const TIER1_UPDATE_INTERVAL_SEC := 0.12
const TIER0_UPDATE_INTERVAL_SEC := 0.35
const ASSIGNMENT_REBUILD_INTERVAL_SEC := 0.12
const PLAYER_CONTEXT_TELEPORT_DISTANCE_M := 32.0
const PLAYER_ASSIGNMENT_REBUILD_DISTANCE_M := 0.01
const PLAYER_ASSIGNMENT_REBUILD_SPEED_DELTA_MPS := 0.1

var _config = null
var _budget := CityPedestrianBudget.new()
var _pedestrian_streamer := CityPedestrianStreamer.new()
var _reaction_model := CityPedestrianReactionModel.new()
var _budget_contract: Dictionary = {}
var _global_snapshot: Dictionary = {}
var _chunk_render_snapshots: Dictionary = {}
var _last_assignment_chunk_ids: Array[String] = []
var _last_assignment_player_position := Vector3.ZERO
var _last_assignment_player_velocity := Vector3.ZERO
var _last_assignment_player_context: Dictionary = {}
var _assignment_rebuild_elapsed_sec := 0.0
var _has_assignment_cache := false
var _force_assignment_rebuild := true
var _tier1_state_refs: Array[CityPedestrianState] = []
var _tier2_state_refs: Array[CityPedestrianState] = []
var _tier3_state_refs: Array[CityPedestrianState] = []
var _last_player_position := Vector3.ZERO
var _last_player_velocity := Vector3.ZERO
var _last_player_context: Dictionary = {}
var _has_player_context := false
var _last_profile_stats := {
	"crowd_spawn_usec": 0,
	"crowd_update_usec": 0,
	"crowd_active_state_count": 0,
	"crowd_step_usec": 0,
	"crowd_reaction_usec": 0,
	"crowd_rank_usec": 0,
	"crowd_snapshot_rebuild_usec": 0,
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
	_chunk_render_snapshots.clear()
	_last_assignment_chunk_ids.clear()
	_last_assignment_player_position = Vector3.ZERO
	_last_assignment_player_velocity = Vector3.ZERO
	_last_assignment_player_context.clear()
	_assignment_rebuild_elapsed_sec = 0.0
	_has_assignment_cache = false
	_force_assignment_rebuild = true
	_tier1_state_refs.clear()
	_tier2_state_refs.clear()
	_tier3_state_refs.clear()
	_last_player_position = Vector3.ZERO
	_last_player_velocity = Vector3.ZERO
	_last_player_context.clear()
	_has_player_context = false
	_last_profile_stats = {
		"crowd_spawn_usec": 0,
		"crowd_update_usec": 0,
		"crowd_active_state_count": 0,
		"crowd_step_usec": 0,
		"crowd_reaction_usec": 0,
		"crowd_rank_usec": 0,
		"crowd_snapshot_rebuild_usec": 0,
	}

func get_budget_contract() -> Dictionary:
	return _budget_contract.duplicate(true)

func set_player_context(player_position: Vector3, player_velocity: Vector3 = Vector3.ZERO, context: Dictionary = {}) -> void:
	_reaction_model.set_player_context(player_position, player_velocity, context)
	_last_player_position = player_position
	_last_player_velocity = player_velocity
	_last_player_context = context.duplicate(true)
	_has_player_context = true

func notify_projectile_event(origin: Vector3, direction: Vector3, range_m: float = 36.0) -> void:
	_reaction_model.notify_projectile_event(origin, direction, range_m)
	_mark_assignment_rebuild_required()

func notify_explosion_event(world_position: Vector3, radius_m: float) -> void:
	_reaction_model.notify_explosion_event(world_position, radius_m)
	_mark_assignment_rebuild_required()

func resolve_projectile_hit(start_position: Vector3, end_position: Vector3, damage: float = 1.0, velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	var best_hit := {}
	for state_variant in _get_projectile_hit_candidates():
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
	var death_event := _build_death_event_for_state(hit_state, best_hit.get("hit_position", end_position))
	_reaction_model.notify_casualty_event(
		best_hit.get("hit_position", end_position),
		float(_budget_contract.get("casualty_witness_radius_m", 18.0))
	)
	_mark_assignment_rebuild_required()
	return {
		"pedestrian_id": hit_state.pedestrian_id,
		"chunk_id": hit_state.chunk_id,
		"life_state": hit_state.life_state,
		"damage": damage,
		"hit_position": best_hit.get("hit_position", end_position),
		"hit_distance_m": float(best_hit.get("hit_distance_m", start_position.distance_to(end_position))),
		"velocity": velocity,
		"death_events": [death_event],
	}

func _get_projectile_hit_candidates() -> Array[CityPedestrianState]:
	var candidates: Array[CityPedestrianState] = []
	var seen_ids: Dictionary = {}
	for state in _tier3_state_refs:
		if _append_projectile_hit_candidate(candidates, seen_ids, state):
			continue
	for state in _tier2_state_refs:
		if _append_projectile_hit_candidate(candidates, seen_ids, state):
			continue
	for state in _tier1_state_refs:
		if _append_projectile_hit_candidate(candidates, seen_ids, state):
			continue
	if not candidates.is_empty():
		return candidates
	for state_variant in _pedestrian_streamer.get_active_states():
		var state: CityPedestrianState = state_variant
		_append_projectile_hit_candidate(candidates, seen_ids, state)
	return candidates

func _append_projectile_hit_candidate(candidates: Array[CityPedestrianState], seen_ids: Dictionary, state: CityPedestrianState) -> bool:
	if state == null:
		return false
	if seen_ids.has(state.pedestrian_id):
		return false
	seen_ids[state.pedestrian_id] = true
	candidates.append(state)
	return true

func resolve_explosion_impact(world_position: Vector3, lethal_radius_m: float, threat_radius_m: float = -1.0) -> Dictionary:
	var resolved_threat_radius_m := threat_radius_m if threat_radius_m >= 0.0 else lethal_radius_m
	var killed_ids: Array[String] = []
	var death_events: Array[Dictionary] = []
	for state_variant in _pedestrian_streamer.get_active_states():
		var state: CityPedestrianState = state_variant
		if not state.is_alive():
			continue
		var distance_m := state.world_position.distance_to(world_position)
		if distance_m <= lethal_radius_m:
			state.mark_dead("explosion", world_position)
			killed_ids.append(state.pedestrian_id)
			death_events.append(_build_death_event_for_state(state, world_position))
	_reaction_model.notify_explosion_event(world_position, lethal_radius_m, resolved_threat_radius_m)
	_reaction_model.notify_casualty_event(
		world_position,
		float(_budget_contract.get("explosion_witness_radius_m", 20.0))
	)
	if not death_events.is_empty():
		_mark_assignment_rebuild_required()
	return {
		"killed_count": killed_ids.size(),
		"killed_ids": killed_ids,
		"lethal_radius_m": lethal_radius_m,
		"threat_radius_m": resolved_threat_radius_m,
		"death_events": death_events,
	}

func update_active_chunks(active_chunk_entries: Array, player_position: Vector3, delta: float = 0.0) -> Dictionary:
	var update_started_usec := Time.get_ticks_usec()
	var inferred_player_velocity := Vector3.ZERO
	if _has_player_context and player_position == _last_player_position:
		inferred_player_velocity = _last_player_velocity
	elif _has_player_context and delta > 0.0:
		var player_travel_distance_m := player_position.distance_to(_last_player_position)
		if player_travel_distance_m <= PLAYER_CONTEXT_TELEPORT_DISTANCE_M:
			inferred_player_velocity = (player_position - _last_player_position) / delta
	set_player_context(player_position, inferred_player_velocity, _last_player_context)

	var active_chunk_ids: Array[String] = []
	for entry_variant in active_chunk_entries:
		active_chunk_ids.append(str((entry_variant as Dictionary).get("chunk_id", "")))
	var spawn_started_usec := Time.get_ticks_usec()
	var streaming_snapshot: Dictionary = _pedestrian_streamer.sync_active_chunks(active_chunk_entries)
	var crowd_spawn_usec := Time.get_ticks_usec() - spawn_started_usec
	var active_states: Array = _pedestrian_streamer.get_active_states()

	var crowd_step_usec := 0
	if delta > 0.0:
		var step_started_usec := Time.get_ticks_usec()
		for state_variant in active_states:
			var state: CityPedestrianState = state_variant
			state.queue_step(delta)
			var step_delta := _resolve_step_delta_for_state(state)
			if step_delta <= 0.0:
				continue
			state.step(step_delta)
			_pedestrian_streamer.ground_state(state)
		crowd_step_usec = _duration_or_zero(step_started_usec, active_states.size())

	_assignment_rebuild_elapsed_sec += maxf(delta, 0.0)
	if not _should_rebuild_assignments(active_chunk_ids, player_position, inferred_player_velocity):
		var reused_runtime_snapshot: Dictionary = _pedestrian_streamer.get_runtime_snapshot()
		_update_runtime_snapshot(
			active_chunk_ids.size(),
			active_states.size(),
			int(_global_snapshot.get("tier0_count", 0)),
			int(_global_snapshot.get("tier1_count", 0)),
			int(_global_snapshot.get("tier2_count", 0)),
			int(_global_snapshot.get("tier3_count", 0)),
			reused_runtime_snapshot,
			crowd_spawn_usec,
			crowd_step_usec,
			0,
			0,
			0,
			update_started_usec
		)
		return get_global_summary()

	var reaction_started_usec := Time.get_ticks_usec()
	var reactive_candidates := _reaction_model.update_reactions(active_states, _budget_contract, delta)
	var crowd_reaction_usec := _duration_or_zero(reaction_started_usec, active_states.size())
	var rank_started_usec := Time.get_ticks_usec()
	var reactive_rankings := _rank_reactive_candidates(reactive_candidates)
	var tier3_ids: Dictionary = _select_tier3_ids(reactive_rankings)
	var distance_ranked_states := _build_distance_ranked_states(active_states, player_position)
	var crowd_rank_usec := _duration_or_zero(rank_started_usec, active_states.size())

	var tier1_budget := int(_budget_contract.get("tier1_budget", 768))
	var tier2_budget := int(_budget_contract.get("tier2_budget", 96))
	var tier3_budget := int(_budget_contract.get("tier3_budget", 24))
	var nearfield_budget := int(_budget_contract.get("nearfield_budget", tier2_budget))
	var tier2_radius_m := float(_budget_contract.get("tier2_radius_m", 110.0))
	var tier2_radius_sq := tier2_radius_m * tier2_radius_m

	var tier0_count := 0
	var tier1_count := 0
	var tier2_count := 0
	var tier3_count := 0
	var remaining_tier2_budget: int = maxi(nearfield_budget - tier3_ids.size(), 0)
	remaining_tier2_budget = mini(remaining_tier2_budget, tier2_budget)
	var snapshot_rebuild_started_usec := Time.get_ticks_usec()
	var next_chunk_render_snapshots: Dictionary = {}
	_tier1_state_refs.clear()
	_tier2_state_refs.clear()
	_tier3_state_refs.clear()
	for chunk_id in active_chunk_ids:
		var chunk_snapshot: Dictionary = _chunk_render_snapshots.get(chunk_id, _make_empty_chunk_render_snapshot(chunk_id))
		_reset_chunk_render_snapshot(chunk_snapshot, chunk_id)
		next_chunk_render_snapshots[chunk_id] = chunk_snapshot

	for state_variant in distance_ranked_states:
		var state: CityPedestrianState = state_variant
		if state == null:
			continue
		var pedestrian_id := state.pedestrian_id
		if not next_chunk_render_snapshots.has(state.chunk_id):
			var dynamic_chunk_snapshot: Dictionary = _chunk_render_snapshots.get(state.chunk_id, _make_empty_chunk_render_snapshot(state.chunk_id))
			_reset_chunk_render_snapshot(dynamic_chunk_snapshot, state.chunk_id)
			next_chunk_render_snapshots[state.chunk_id] = dynamic_chunk_snapshot
		var chunk_snapshot: Dictionary = next_chunk_render_snapshots[state.chunk_id]
		var distance_sq := player_position.distance_squared_to(state.world_position)
		if tier3_ids.has(pedestrian_id):
			state.set_tier(CityPedestrianState.TIER_3)
			_tier3_state_refs.append(state)
			var chunk_tier3_states: Array = chunk_snapshot.get("tier3_states", [])
			chunk_tier3_states.append(state)
			chunk_snapshot["tier3_states"] = chunk_tier3_states
			tier3_count += 1
			chunk_snapshot["tier3_count"] = int(chunk_snapshot.get("tier3_count", 0)) + 1
			_chunk_render_snapshots[state.chunk_id] = chunk_snapshot
			continue
		if distance_sq <= tier2_radius_sq and tier2_count < remaining_tier2_budget:
			state.set_tier(CityPedestrianState.TIER_2)
			_tier2_state_refs.append(state)
			var chunk_tier2_states: Array = chunk_snapshot.get("tier2_states", [])
			chunk_tier2_states.append(state)
			chunk_snapshot["tier2_states"] = chunk_tier2_states
			tier2_count += 1
			chunk_snapshot["tier2_count"] = int(chunk_snapshot.get("tier2_count", 0)) + 1
		elif tier1_count < tier1_budget:
			state.set_tier(CityPedestrianState.TIER_1)
			_tier1_state_refs.append(state)
			var chunk_tier1_states: Array = chunk_snapshot.get("tier1_states", [])
			chunk_tier1_states.append(state)
			chunk_snapshot["tier1_states"] = chunk_tier1_states
			tier1_count += 1
			chunk_snapshot["tier1_count"] = int(chunk_snapshot.get("tier1_count", 0)) + 1
		else:
			state.set_tier(CityPedestrianState.TIER_0)
			tier0_count += 1
			chunk_snapshot["tier0_count"] = int(chunk_snapshot.get("tier0_count", 0)) + 1
		next_chunk_render_snapshots[state.chunk_id] = chunk_snapshot
	_chunk_render_snapshots = next_chunk_render_snapshots
	var crowd_snapshot_rebuild_usec := _duration_or_zero(snapshot_rebuild_started_usec, active_states.size())

	var runtime_snapshot: Dictionary = _pedestrian_streamer.get_runtime_snapshot()
	_update_runtime_snapshot(
		active_chunk_ids.size(),
		active_states.size(),
		tier0_count,
		tier1_count,
		tier2_count,
		tier3_count,
		runtime_snapshot,
		crowd_spawn_usec,
		crowd_step_usec,
		crowd_reaction_usec,
		crowd_rank_usec,
		crowd_snapshot_rebuild_usec,
		update_started_usec
	)
	_last_assignment_chunk_ids = active_chunk_ids.duplicate()
	_last_assignment_player_position = player_position
	_last_assignment_player_velocity = inferred_player_velocity
	_last_assignment_player_context = _last_player_context.duplicate(true)
	_assignment_rebuild_elapsed_sec = 0.0
	_has_assignment_cache = true
	_force_assignment_rebuild = false
	return get_global_summary()

func get_global_snapshot() -> Dictionary:
	var snapshot: Dictionary = _global_snapshot.duplicate(true)
	snapshot["tier1_states"] = _build_full_state_snapshots(_tier1_state_refs)
	snapshot["tier2_states"] = _build_full_state_snapshots(_tier2_state_refs)
	snapshot["tier3_states"] = _build_full_state_snapshots(_tier3_state_refs)
	return snapshot

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
	if not _chunk_render_snapshots.has(chunk_id):
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
	return (_chunk_render_snapshots[chunk_id] as Dictionary).duplicate(true)

func get_chunk_snapshot_ref(chunk_id: String) -> Dictionary:
	if not _chunk_render_snapshots.has(chunk_id):
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
	return _chunk_render_snapshots[chunk_id]

func get_state_snapshot(pedestrian_id: String) -> Dictionary:
	return _pedestrian_streamer.get_state_snapshot(pedestrian_id)

func get_runtime_snapshot() -> Dictionary:
	var runtime_snapshot: Dictionary = _pedestrian_streamer.get_runtime_snapshot()
	runtime_snapshot["tier0_count"] = int(_global_snapshot.get("tier0_count", 0))
	runtime_snapshot["tier1_count"] = int(_global_snapshot.get("tier1_count", 0))
	runtime_snapshot["tier2_count"] = int(_global_snapshot.get("tier2_count", 0))
	runtime_snapshot["tier3_count"] = int(_global_snapshot.get("tier3_count", 0))
	runtime_snapshot["tier1_states"] = _build_full_state_snapshots(_tier1_state_refs)
	runtime_snapshot["tier2_states"] = _build_full_state_snapshots(_tier2_state_refs)
	runtime_snapshot["tier3_states"] = _build_full_state_snapshots(_tier3_state_refs)
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

func _build_distance_ranked_states(active_states: Array, player_position: Vector3) -> Array:
	var ranked_states: Array = active_states.duplicate()
	ranked_states.sort_custom(func(a, b) -> bool:
		return player_position.distance_squared_to(a.world_position) < player_position.distance_squared_to(b.world_position)
	)
	return ranked_states

func _duration_or_zero(started_usec: int, item_count: int) -> int:
	if item_count <= 0:
		return 0
	return maxi(int(Time.get_ticks_usec() - started_usec), 1)

func _mark_assignment_rebuild_required() -> void:
	_force_assignment_rebuild = true

func _should_rebuild_assignments(active_chunk_ids: Array[String], player_position: Vector3, player_velocity: Vector3) -> bool:
	if not _has_assignment_cache:
		return true
	if _force_assignment_rebuild:
		return true
	if _reaction_model.get_event_count() > 0:
		return true
	if not _string_arrays_equal(_last_assignment_chunk_ids, active_chunk_ids):
		return true
	if player_position.distance_to(_last_assignment_player_position) > PLAYER_ASSIGNMENT_REBUILD_DISTANCE_M:
		return true
	if player_velocity.distance_to(_last_assignment_player_velocity) > PLAYER_ASSIGNMENT_REBUILD_SPEED_DELTA_MPS:
		return true
	if _last_player_context != _last_assignment_player_context:
		return true
	return _assignment_rebuild_elapsed_sec >= ASSIGNMENT_REBUILD_INTERVAL_SEC

func _string_arrays_equal(lhs: Array[String], rhs: Array[String]) -> bool:
	if lhs.size() != rhs.size():
		return false
	for item_index in range(lhs.size()):
		if lhs[item_index] != rhs[item_index]:
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
	crowd_spawn_usec: int,
	crowd_step_usec: int,
	crowd_reaction_usec: int,
	crowd_rank_usec: int,
	crowd_snapshot_rebuild_usec: int,
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
		"tier1_budget": int(_budget_contract.get("tier1_budget", 768)),
		"tier2_budget": int(_budget_contract.get("tier2_budget", 96)),
		"tier3_budget": int(_budget_contract.get("tier3_budget", 24)),
		"nearfield_budget": int(_budget_contract.get("nearfield_budget", int(_budget_contract.get("tier2_budget", 96)))),
		"tier2_radius_m": float(_budget_contract.get("tier2_radius_m", 110.0)),
		"tier3_radius_m": float(_budget_contract.get("tier3_radius_m", 30.0)),
		"page_cache_hit_count": int(runtime_snapshot.get("page_cache_hit_count", 0)),
		"page_cache_miss_count": int(runtime_snapshot.get("page_cache_miss_count", 0)),
		"duplicate_page_load_count": int(runtime_snapshot.get("duplicate_page_load_count", 0)),
		"reactive_event_count": _reaction_model.get_event_count(),
	}
	_last_profile_stats = {
		"crowd_spawn_usec": crowd_spawn_usec,
		"crowd_update_usec": Time.get_ticks_usec() - update_started_usec,
		"crowd_active_state_count": active_state_count,
		"crowd_step_usec": crowd_step_usec,
		"crowd_reaction_usec": crowd_reaction_usec,
		"crowd_rank_usec": crowd_rank_usec,
		"crowd_snapshot_rebuild_usec": crowd_snapshot_rebuild_usec,
	}
	_global_snapshot["profile_stats"] = _last_profile_stats.duplicate(true)

func _build_full_state_snapshots(states: Array[CityPedestrianState]) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for state in states:
		if state == null:
			continue
		snapshots.append(state.to_snapshot())
	return snapshots

func _make_empty_chunk_render_snapshot(chunk_id: String) -> Dictionary:
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

func _reset_chunk_render_snapshot(snapshot: Dictionary, chunk_id: String) -> void:
	snapshot["chunk_id"] = chunk_id
	snapshot["tier0_count"] = 0
	snapshot["tier1_count"] = 0
	snapshot["tier2_count"] = 0
	snapshot["tier3_count"] = 0
	snapshot["tier1_states"] = []
	snapshot["tier2_states"] = []
	snapshot["tier3_states"] = []

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

func _build_death_event_for_state(state: CityPedestrianState, source_position: Vector3) -> Dictionary:
	return {
		"pedestrian_id": state.pedestrian_id,
		"chunk_id": state.chunk_id,
		"world_position": state.world_position,
		"heading": state.heading,
		"height_m": state.height_m,
		"radius_m": state.radius_m,
		"seed": state.seed_value,
		"archetype_id": state.archetype_id,
		"archetype_signature": state.archetype_signature,
		"source_position": source_position,
		"death_cause": state.death_cause,
	}
