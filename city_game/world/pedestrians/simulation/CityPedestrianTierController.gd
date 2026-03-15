extends RefCounted

const CityPedestrianBudget := preload("res://city_game/world/pedestrians/streaming/CityPedestrianBudget.gd")
const CityPedestrianStreamer := preload("res://city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd")
const CityPedestrianState := preload("res://city_game/world/pedestrians/simulation/CityPedestrianState.gd")
const CityPedestrianReactionModel := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd")
const CityPedestrianLayeredScheduler := preload("res://city_game/world/pedestrians/simulation/CityPedestrianLayeredScheduler.gd")

const TIER1_UPDATE_INTERVAL_SEC := 0.12
const TIER1_STEP_BUCKET_COUNT := 8
const TIER0_UPDATE_INTERVAL_SEC := 0.5
const TIER0_STEP_BUCKET_COUNT := 8
const ASSIGNMENT_REBUILD_INTERVAL_SEC := 0.18
const PLAYER_CONTEXT_TELEPORT_DISTANCE_M := 32.0
const PLAYER_ASSIGNMENT_REBUILD_DISTANCE_M := 32.0
const PLAYER_ASSIGNMENT_REBUILD_SPEED_DELTA_MPS := 0.1
const FARFIELD_ASSIGNMENT_REBUILD_DISTANCE_M := 96.0
const LAYERED_ASSIGNMENT_REBUILD_DISTANCE_M := 96.0
const VEHICLE_IMPACT_FLEE_SPEED_MULTIPLIER := 4.0

var _config = null
var _budget := CityPedestrianBudget.new()
var _pedestrian_streamer := CityPedestrianStreamer.new()
var _reaction_model := CityPedestrianReactionModel.new()
var _layered_scheduler := CityPedestrianLayeredScheduler.new()
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
var _tier1_step_bucket_accumulator_sec := 0.0
var _tier1_step_bucket_interval_sec := TIER1_UPDATE_INTERVAL_SEC
var _tier1_step_bucket_count := 1
var _tier1_step_bucket_cursor := 0
var _tier1_step_buckets: Array = []
var _tier0_step_accumulator_sec := 0.0
var _tier0_step_bucket_interval_sec := TIER0_UPDATE_INTERVAL_SEC
var _tier0_step_bucket_count := 1
var _tier0_step_bucket_cursor := 0
var _tier0_step_buckets: Array = []
var _pending_farfield_render_dirty_chunk_ids: Dictionary = {}
var _farfield_state_refs: Array[CityPedestrianState] = []
var _midfield_state_refs: Array[CityPedestrianState] = []
var _nearfield_state_refs: Array[CityPedestrianState] = []
var _tier0_state_refs: Array[CityPedestrianState] = []
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
	"crowd_farfield_count": 0,
	"crowd_midfield_count": 0,
	"crowd_nearfield_count": 0,
	"crowd_farfield_step_usec": 0,
	"crowd_midfield_step_usec": 0,
	"crowd_nearfield_step_usec": 0,
	"crowd_assignment_rebuild_usec": 0,
	"crowd_assignment_candidate_count": 0,
	"crowd_threat_broadcast_usec": 0,
	"crowd_threat_candidate_count": 0,
}

func setup(config, world_data: Dictionary) -> void:
	_config = config
	_budget = CityPedestrianBudget.new()
	_budget.setup(config)
	_budget_contract = _budget.get_contract()
	_pedestrian_streamer = CityPedestrianStreamer.new()
	_pedestrian_streamer.setup(_config, world_data, _budget_contract)
	_reaction_model = CityPedestrianReactionModel.new()
	_layered_scheduler = CityPedestrianLayeredScheduler.new()
	_global_snapshot.clear()
	_chunk_render_snapshots.clear()
	_last_assignment_chunk_ids.clear()
	_last_assignment_player_position = Vector3.ZERO
	_last_assignment_player_velocity = Vector3.ZERO
	_last_assignment_player_context.clear()
	_assignment_rebuild_elapsed_sec = 0.0
	_has_assignment_cache = false
	_force_assignment_rebuild = true
	_tier1_step_bucket_accumulator_sec = 0.0
	_tier1_step_bucket_interval_sec = TIER1_UPDATE_INTERVAL_SEC
	_tier1_step_bucket_count = 1
	_tier1_step_bucket_cursor = 0
	_tier1_step_buckets.clear()
	_tier0_step_accumulator_sec = 0.0
	_tier0_step_bucket_interval_sec = TIER0_UPDATE_INTERVAL_SEC
	_tier0_step_bucket_count = 1
	_tier0_step_bucket_cursor = 0
	_tier0_step_buckets.clear()
	_pending_farfield_render_dirty_chunk_ids.clear()
	_farfield_state_refs.clear()
	_midfield_state_refs.clear()
	_nearfield_state_refs.clear()
	_tier0_state_refs.clear()
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
		"crowd_farfield_count": 0,
		"crowd_midfield_count": 0,
		"crowd_nearfield_count": 0,
		"crowd_farfield_step_usec": 0,
		"crowd_midfield_step_usec": 0,
		"crowd_nearfield_step_usec": 0,
		"crowd_assignment_rebuild_usec": 0,
		"crowd_assignment_candidate_count": 0,
		"crowd_threat_broadcast_usec": 0,
		"crowd_threat_candidate_count": 0,
	}

func get_budget_contract() -> Dictionary:
	return _budget_contract.duplicate(true)

func prewarm_chunk_entries(chunk_entries: Array) -> void:
	_pedestrian_streamer.prewarm_chunk_entries(chunk_entries)

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
	_pedestrian_streamer.invalidate_active_state_cache()
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
	if not killed_ids.is_empty():
		_pedestrian_streamer.invalidate_active_state_cache()
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

func resolve_vehicle_impact(vehicle_state: Dictionary) -> Dictionary:
	if vehicle_state.is_empty():
		return {}
	var impact_speed_mps := float(vehicle_state.get("speed_mps", 0.0))
	if impact_speed_mps < float(_budget_contract.get("vehicle_impact_speed_threshold_mps", 6.0)):
		return {}
	var forward: Vector3 = vehicle_state.get("heading", Vector3.FORWARD)
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var lateral := Vector3(-forward.z, 0.0, forward.x).normalized()
	var vehicle_position: Vector3 = vehicle_state.get("world_position", Vector3.ZERO)
	var hit_radius_m := float(_budget_contract.get("vehicle_impact_hit_radius_m", 1.4))
	var front_reach_m := float(_budget_contract.get("vehicle_impact_front_reach_m", 4.6))
	var best_hit := {}
	for state in _get_vehicle_impact_candidates():
		if not state.is_alive():
			continue
		var hit := _vehicle_impact_hit_for_state(state, vehicle_position, forward, lateral, hit_radius_m, front_reach_m)
		if hit.is_empty():
			continue
		if best_hit.is_empty() or float(hit.get("forward_distance_m", INF)) < float(best_hit.get("forward_distance_m", INF)):
			best_hit = hit
	if best_hit.is_empty():
		return {}
	var hit_state: CityPedestrianState = best_hit.get("state")
	var impact_position: Vector3 = best_hit.get("impact_position", hit_state.world_position)
	hit_state.mark_dead("vehicle_impact", vehicle_position)
	_pedestrian_streamer.invalidate_active_state_cache()
	var death_event := _build_death_event_for_state(hit_state, vehicle_position)
	var launch_distance_m := clampf(
		impact_speed_mps * 0.35,
		float(_budget_contract.get("vehicle_impact_launch_distance_min_m", 3.5)),
		float(_budget_contract.get("vehicle_impact_launch_distance_max_m", 7.0))
	)
	var landing_position := hit_state.world_position + forward * launch_distance_m
	death_event["impact_source"] = "player_vehicle"
	death_event["impact_vehicle_id"] = str(vehicle_state.get("vehicle_id", ""))
	death_event["impact_heading"] = forward
	death_event["impact_speed_mps"] = impact_speed_mps
	death_event["launch_origin"] = hit_state.world_position
	death_event["landing_position"] = landing_position
	death_event["launch_distance_m"] = launch_distance_m
	death_event["launch_duration_sec"] = float(_budget_contract.get("vehicle_impact_launch_duration_sec", 0.42))
	var panic_summary := _apply_vehicle_impact_panic(impact_position, hit_state.pedestrian_id)
	_mark_assignment_rebuild_required()
	return {
		"pedestrian_id": hit_state.pedestrian_id,
		"chunk_id": hit_state.chunk_id,
		"life_state": hit_state.life_state,
		"impact_position": impact_position,
		"impact_speed_mps": impact_speed_mps,
		"death_events": [death_event],
		"panic_radius_m": float(_budget_contract.get("vehicle_impact_panic_radius_m", 16.0)),
		"panic_response_ratio": float(_budget_contract.get("vehicle_impact_panic_response_ratio", 0.6)),
		"panic_candidate_count": int(panic_summary.get("candidate_count", 0)),
		"panic_responder_count": int(panic_summary.get("responder_count", 0)),
		"panic_candidate_ids": panic_summary.get("candidate_ids", []).duplicate(),
		"panic_responder_ids": panic_summary.get("responder_ids", []).duplicate(),
		"calm_witness_id": str(panic_summary.get("calm_witness_id", "")),
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
	active_chunk_ids.sort()
	var spawn_started_usec := Time.get_ticks_usec()
	_pedestrian_streamer.sync_active_chunks(active_chunk_entries)
	var crowd_spawn_usec := Time.get_ticks_usec() - spawn_started_usec
	if _reaction_model.advance_time(delta):
		_mark_assignment_rebuild_required()
	var active_states: Array = _pedestrian_streamer.get_active_states()

	var step_profile := _empty_step_profile()
	if delta > 0.0:
		step_profile = _step_active_states(active_states, delta)

	_assignment_rebuild_elapsed_sec += maxf(delta, 0.0)
	if not _should_rebuild_assignments(active_chunk_ids, player_position, inferred_player_velocity):
		var reused_runtime_snapshot: Dictionary = _pedestrian_streamer.get_runtime_summary()
		_update_runtime_snapshot(
			active_chunk_ids.size(),
			active_states.size(),
			int(_global_snapshot.get("tier0_count", 0)),
			int(_global_snapshot.get("tier1_count", 0)),
			int(_global_snapshot.get("tier2_count", 0)),
			int(_global_snapshot.get("tier3_count", 0)),
			reused_runtime_snapshot,
			crowd_spawn_usec,
			step_profile,
			0,
			0,
			0,
			_build_layer_profile_counts(
				_farfield_state_refs.size(),
				_midfield_state_refs.size(),
				_nearfield_state_refs.size(),
				_midfield_state_refs.size() + _nearfield_state_refs.size(),
				_midfield_state_refs.size() + _nearfield_state_refs.size()
			),
			update_started_usec
		)
		return get_global_summary()

	var threat_regions: Array = _reaction_model.get_active_threat_regions(_budget_contract)
	var layer_context: Dictionary = _layered_scheduler.build_context(active_states, player_position, _budget_contract, threat_regions, _last_player_context)
	var assignment_candidate_states: Array = layer_context.get("assignment_candidate_states", [])
	var midfield_states: Array = layer_context.get("midfield_states", [])
	var threat_candidate_states: Array = layer_context.get("threat_candidate_states", [])
	var farfield_states: Array = layer_context.get("farfield_states", [])
	_clear_transient_proximity_reactions(midfield_states)
	_clear_transient_proximity_reactions(farfield_states)
	var crowd_threat_broadcast_usec := 0
	var reactive_candidates: Array = []
	if not threat_candidate_states.is_empty():
		var reaction_started_usec := Time.get_ticks_usec()
		reactive_candidates = _reaction_model.update_reactions(threat_candidate_states, _budget_contract, delta)
		crowd_threat_broadcast_usec = _duration_or_zero(reaction_started_usec, threat_candidate_states.size())
	var assignment_started_usec := Time.get_ticks_usec()
	var reactive_rankings := _rank_reactive_candidates(reactive_candidates)
	var tier3_ids: Dictionary = _select_tier3_ids(reactive_rankings)
	var distance_ranked_states := _build_distance_ranked_states(assignment_candidate_states, player_position)
	var crowd_assignment_rebuild_usec := _elapsed_usec_or_one(assignment_started_usec)

	var tier1_budget := int(_budget_contract.get("tier1_budget", 768))
	var tier2_budget := int(_budget_contract.get("tier2_budget", 96))
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
	var dirty_chunk_ids := _capture_dirty_chunk_ids()
	var farfield_render_dirty_chunk_ids := _capture_farfield_render_dirty_chunk_ids()
	var assignment_candidate_ids: Dictionary = {}
	var assignment_dirty_chunk_ids: Dictionary = {}
	var final_midfield_states: Array[CityPedestrianState] = []
	var final_nearfield_states: Array[CityPedestrianState] = []
	_tier0_state_refs.clear()
	_tier1_state_refs.clear()
	_tier2_state_refs.clear()
	_tier3_state_refs.clear()
	for chunk_id in active_chunk_ids:
		var chunk_snapshot: Dictionary = _chunk_render_snapshots.get(chunk_id, _make_empty_chunk_render_snapshot(chunk_id))
		_reset_chunk_render_snapshot(chunk_snapshot, chunk_id)
		next_chunk_render_snapshots[chunk_id] = chunk_snapshot
	for state_variant in assignment_candidate_states:
		var assignment_state: CityPedestrianState = state_variant
		if assignment_state == null:
			continue
		assignment_candidate_ids[assignment_state.pedestrian_id] = true
		dirty_chunk_ids[assignment_state.chunk_id] = true
		assignment_dirty_chunk_ids[assignment_state.chunk_id] = true

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
			final_nearfield_states.append(state)
			var chunk_tier3_states: Array = chunk_snapshot.get("tier3_states", [])
			chunk_tier3_states.append(state)
			chunk_snapshot["tier3_states"] = chunk_tier3_states
			tier3_count += 1
			chunk_snapshot["tier3_count"] = int(chunk_snapshot.get("tier3_count", 0)) + 1
			continue
		if distance_sq <= tier2_radius_sq and tier2_count < remaining_tier2_budget:
			state.set_tier(CityPedestrianState.TIER_2)
			_tier2_state_refs.append(state)
			final_nearfield_states.append(state)
			var chunk_tier2_states: Array = chunk_snapshot.get("tier2_states", [])
			chunk_tier2_states.append(state)
			chunk_snapshot["tier2_states"] = chunk_tier2_states
			tier2_count += 1
			chunk_snapshot["tier2_count"] = int(chunk_snapshot.get("tier2_count", 0)) + 1
		elif tier1_count < tier1_budget:
			state.set_tier(CityPedestrianState.TIER_1)
			_tier1_state_refs.append(state)
			if assignment_candidate_ids.has(pedestrian_id):
				final_midfield_states.append(state)
			var chunk_tier1_states: Array = chunk_snapshot.get("tier1_states", [])
			chunk_tier1_states.append(state)
			chunk_snapshot["tier1_states"] = chunk_tier1_states
			tier1_count += 1
			chunk_snapshot["tier1_count"] = int(chunk_snapshot.get("tier1_count", 0)) + 1
		else:
			state.set_tier(CityPedestrianState.TIER_0)
			_tier0_state_refs.append(state)
			tier0_count += 1
			chunk_snapshot["tier0_count"] = int(chunk_snapshot.get("tier0_count", 0)) + 1
		next_chunk_render_snapshots[state.chunk_id] = chunk_snapshot
	for state_variant in farfield_states:
		var state: CityPedestrianState = state_variant
		if state == null:
			continue
		if not next_chunk_render_snapshots.has(state.chunk_id):
			var dynamic_chunk_snapshot: Dictionary = _chunk_render_snapshots.get(state.chunk_id, _make_empty_chunk_render_snapshot(state.chunk_id))
			_reset_chunk_render_snapshot(dynamic_chunk_snapshot, state.chunk_id)
			next_chunk_render_snapshots[state.chunk_id] = dynamic_chunk_snapshot
		var chunk_snapshot: Dictionary = next_chunk_render_snapshots[state.chunk_id]
		if tier1_count < tier1_budget:
			state.set_tier(CityPedestrianState.TIER_1)
			_tier1_state_refs.append(state)
			var chunk_tier1_states: Array = chunk_snapshot.get("tier1_states", [])
			chunk_tier1_states.append(state)
			chunk_snapshot["tier1_states"] = chunk_tier1_states
			tier1_count += 1
			chunk_snapshot["tier1_count"] = int(chunk_snapshot.get("tier1_count", 0)) + 1
		else:
			state.set_tier(CityPedestrianState.TIER_0)
			_tier0_state_refs.append(state)
			tier0_count += 1
			chunk_snapshot["tier0_count"] = int(chunk_snapshot.get("tier0_count", 0)) + 1
		next_chunk_render_snapshots[state.chunk_id] = chunk_snapshot
	for chunk_id_variant in next_chunk_render_snapshots.keys():
		var chunk_id := str(chunk_id_variant)
		var next_snapshot: Dictionary = next_chunk_render_snapshots[chunk_id]
		var previous_snapshot: Dictionary = _chunk_render_snapshots.get(chunk_id, {})
		var structure_changed := not _chunk_snapshot_matches(previous_snapshot, next_snapshot)
		next_snapshot["dirty"] = dirty_chunk_ids.has(chunk_id) or structure_changed
		next_snapshot["farfield_render_dirty"] = farfield_render_dirty_chunk_ids.has(chunk_id) \
			and not structure_changed \
			and not assignment_dirty_chunk_ids.has(chunk_id)
		next_chunk_render_snapshots[chunk_id] = next_snapshot
	_set_layer_state_refs(_farfield_state_refs, farfield_states)
	_set_layer_state_refs(_midfield_state_refs, final_midfield_states)
	_set_layer_state_refs(_nearfield_state_refs, final_nearfield_states)
	_rebuild_tier1_step_buckets()
	_rebuild_tier0_step_buckets()
	_chunk_render_snapshots = next_chunk_render_snapshots
	var crowd_snapshot_rebuild_usec := _duration_or_zero(snapshot_rebuild_started_usec, active_states.size())

	var runtime_snapshot: Dictionary = _pedestrian_streamer.get_runtime_summary()
	_update_runtime_snapshot(
		active_chunk_ids.size(),
		active_states.size(),
		tier0_count,
		tier1_count,
		tier2_count,
		tier3_count,
		runtime_snapshot,
		crowd_spawn_usec,
		step_profile,
		crowd_threat_broadcast_usec,
		crowd_assignment_rebuild_usec,
		crowd_snapshot_rebuild_usec,
		_build_layer_profile_counts(
			_farfield_state_refs.size(),
			_midfield_state_refs.size(),
			_nearfield_state_refs.size(),
			assignment_candidate_states.size(),
			threat_candidate_states.size()
		),
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
	return (_chunk_render_snapshots[chunk_id] as Dictionary).duplicate(true)

func get_chunk_snapshot_ref(chunk_id: String) -> Dictionary:
	if not _chunk_render_snapshots.has(chunk_id):
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
	return _chunk_render_snapshots[chunk_id]

func get_state_snapshot(pedestrian_id: String) -> Dictionary:
	return _pedestrian_streamer.get_state_snapshot(pedestrian_id)

func get_layer_state_ids() -> Dictionary:
	return {
		"farfield_ids": _state_ids_from_refs(_farfield_state_refs),
		"midfield_ids": _state_ids_from_refs(_midfield_state_refs),
		"nearfield_ids": _state_ids_from_refs(_nearfield_state_refs),
	}

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
	var runtime_snapshot: Dictionary = _pedestrian_streamer.get_runtime_summary()
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
		"farfield_count": int(_last_profile_stats.get("crowd_farfield_count", 0)),
		"midfield_count": int(_last_profile_stats.get("crowd_midfield_count", 0)),
		"nearfield_count": int(_last_profile_stats.get("crowd_nearfield_count", 0)),
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

func _elapsed_usec_or_one(started_usec: int) -> int:
	return maxi(int(Time.get_ticks_usec() - started_usec), 1)

func _empty_step_profile() -> Dictionary:
	return {
		"total_usec": 0,
		"nearfield_usec": 0,
		"midfield_usec": 0,
		"farfield_usec": 0,
	}

func _step_active_states(active_states: Array, delta: float) -> Dictionary:
	if active_states.is_empty() or delta <= 0.0:
		return _empty_step_profile()
	if not _has_assignment_cache:
		return _step_all_active_states(active_states, delta)

	var nearfield_started_usec := Time.get_ticks_usec()
	var nearfield_step_count := _step_state_refs(_nearfield_state_refs, delta)
	var nearfield_step_usec := _duration_or_zero(nearfield_started_usec, nearfield_step_count)

	_tier1_step_bucket_accumulator_sec += delta
	var midfield_started_usec := Time.get_ticks_usec()
	var midfield_step_count := _step_tier1_state_buckets()
	var midfield_step_usec := _duration_or_zero(midfield_started_usec, midfield_step_count)

	_tier0_step_accumulator_sec += delta
	var farfield_started_usec := Time.get_ticks_usec()
	var farfield_step_count := _step_farfield_state_buckets()
	var farfield_step_usec := _duration_or_zero(farfield_started_usec, farfield_step_count)

	return {
		"total_usec": nearfield_step_usec + midfield_step_usec + farfield_step_usec,
		"nearfield_usec": nearfield_step_usec,
		"midfield_usec": midfield_step_usec,
		"farfield_usec": farfield_step_usec,
	}

func _step_tier1_state_buckets() -> int:
	if _midfield_state_refs.is_empty():
		_tier1_step_bucket_accumulator_sec = 0.0
		_tier1_step_bucket_cursor = 0
		return 0
	if _tier1_step_bucket_count <= 0 or _tier1_step_buckets.is_empty():
		_rebuild_tier1_step_buckets()
	var stepped_state_count := 0
	while _tier1_step_bucket_accumulator_sec >= _tier1_step_bucket_interval_sec:
		_tier1_step_bucket_accumulator_sec -= _tier1_step_bucket_interval_sec
		if _tier1_step_bucket_cursor >= _tier1_step_bucket_count:
			_tier1_step_bucket_cursor = 0
		var bucket: Array = _tier1_step_buckets[_tier1_step_bucket_cursor]
		if not bucket.is_empty():
			stepped_state_count += _step_state_refs(bucket, TIER1_UPDATE_INTERVAL_SEC)
		_tier1_step_bucket_cursor = (_tier1_step_bucket_cursor + 1) % _tier1_step_bucket_count
	return stepped_state_count

func _rebuild_tier1_step_buckets() -> void:
	_tier1_step_buckets.clear()
	if _midfield_state_refs.is_empty():
		_tier1_step_bucket_count = 1
		_tier1_step_bucket_interval_sec = TIER1_UPDATE_INTERVAL_SEC
		_tier1_step_bucket_cursor = 0
		_tier1_step_bucket_accumulator_sec = 0.0
		return
	_tier1_step_bucket_count = mini(TIER1_STEP_BUCKET_COUNT, _midfield_state_refs.size())
	_tier1_step_bucket_interval_sec = TIER1_UPDATE_INTERVAL_SEC / float(_tier1_step_bucket_count)
	if _tier1_step_bucket_interval_sec <= 0.0:
		_tier1_step_bucket_interval_sec = TIER1_UPDATE_INTERVAL_SEC
	_tier1_step_bucket_cursor = posmod(_tier1_step_bucket_cursor, _tier1_step_bucket_count)
	_tier1_step_bucket_accumulator_sec = clampf(_tier1_step_bucket_accumulator_sec, 0.0, _tier1_step_bucket_interval_sec)
	for _bucket_index in range(_tier1_step_bucket_count):
		_tier1_step_buckets.append([])
	for state_index in range(_midfield_state_refs.size()):
		var bucket_index := state_index % _tier1_step_bucket_count
		var bucket: Array = _tier1_step_buckets[bucket_index]
		bucket.append(_midfield_state_refs[state_index])
		_tier1_step_buckets[bucket_index] = bucket

func _step_farfield_state_buckets() -> int:
	if _farfield_state_refs.is_empty():
		_tier0_step_accumulator_sec = 0.0
		_tier0_step_bucket_cursor = 0
		_pending_farfield_render_dirty_chunk_ids.clear()
		return 0
	if _tier0_step_bucket_count <= 0 or _tier0_step_buckets.is_empty():
		_rebuild_tier0_step_buckets()
	var stepped_state_count := 0
	while _tier0_step_accumulator_sec >= _tier0_step_bucket_interval_sec:
		_tier0_step_accumulator_sec -= _tier0_step_bucket_interval_sec
		if _tier0_step_bucket_cursor >= _tier0_step_bucket_count:
			_tier0_step_bucket_cursor = 0
		var bucket: Array = _tier0_step_buckets[_tier0_step_bucket_cursor]
		if not bucket.is_empty():
			stepped_state_count += _step_state_refs(bucket, TIER0_UPDATE_INTERVAL_SEC, false, false)
			_collect_visible_farfield_chunk_ids(bucket, _pending_farfield_render_dirty_chunk_ids)
		_tier0_step_bucket_cursor = (_tier0_step_bucket_cursor + 1) % _tier0_step_bucket_count
		if _tier0_step_bucket_cursor == 0:
			_flush_pending_farfield_render_dirty_chunks()
	return stepped_state_count

func _rebuild_tier0_step_buckets() -> void:
	_tier0_step_buckets.clear()
	if _farfield_state_refs.is_empty():
		_tier0_step_bucket_count = 1
		_tier0_step_bucket_interval_sec = TIER0_UPDATE_INTERVAL_SEC
		_tier0_step_bucket_cursor = 0
		_tier0_step_accumulator_sec = 0.0
		_pending_farfield_render_dirty_chunk_ids.clear()
		return
	_tier0_step_bucket_count = mini(TIER0_STEP_BUCKET_COUNT, _farfield_state_refs.size())
	_tier0_step_bucket_interval_sec = TIER0_UPDATE_INTERVAL_SEC / float(_tier0_step_bucket_count)
	if _tier0_step_bucket_interval_sec <= 0.0:
		_tier0_step_bucket_interval_sec = TIER0_UPDATE_INTERVAL_SEC
	_tier0_step_bucket_cursor = posmod(_tier0_step_bucket_cursor, _tier0_step_bucket_count)
	_tier0_step_accumulator_sec = clampf(_tier0_step_accumulator_sec, 0.0, _tier0_step_bucket_interval_sec)
	for _bucket_index in range(_tier0_step_bucket_count):
		_tier0_step_buckets.append([])
	for state_index in range(_farfield_state_refs.size()):
		var bucket_index := state_index % _tier0_step_bucket_count
		var bucket: Array = _tier0_step_buckets[bucket_index]
		bucket.append(_farfield_state_refs[state_index])
		_tier0_step_buckets[bucket_index] = bucket

func _step_all_active_states(active_states: Array, delta: float) -> Dictionary:
	var step_started_usec := Time.get_ticks_usec()
	var stepped_state_count := 0
	for state_variant in active_states:
		var state: CityPedestrianState = state_variant
		if state == null or not state.is_alive():
			continue
		state.queue_step(delta)
		var step_delta := _resolve_step_delta_for_state(state)
		if step_delta <= 0.0:
			continue
		state.step(step_delta)
		_pedestrian_streamer.ground_state(state)
		_mark_chunk_render_dirty(state.chunk_id)
		stepped_state_count += 1
	var total_usec := _duration_or_zero(step_started_usec, stepped_state_count)
	return {
		"total_usec": total_usec,
		"nearfield_usec": 0,
		"midfield_usec": total_usec,
		"farfield_usec": 0,
	}

func _step_state_refs(states: Array, step_delta: float, mark_render_dirty: bool = true, apply_ground: bool = true) -> int:
	if step_delta <= 0.0 or states.is_empty():
		return 0
	var stepped_state_count := 0
	for state in states:
		if state == null or not state.is_alive():
			continue
		state.step(step_delta)
		if apply_ground:
			_pedestrian_streamer.ground_state(state)
		if mark_render_dirty:
			_mark_chunk_render_dirty(state.chunk_id)
		stepped_state_count += 1
	return stepped_state_count

func _mark_assignment_rebuild_required() -> void:
	_force_assignment_rebuild = true

func _mark_chunk_render_dirty(chunk_id: String, farfield_only: bool = false) -> void:
	if chunk_id == "" or not _chunk_render_snapshots.has(chunk_id):
		return
	var snapshot: Dictionary = _chunk_render_snapshots[chunk_id]
	var already_dirty := bool(snapshot.get("dirty", false))
	var already_farfield_only := bool(snapshot.get("farfield_render_dirty", false))
	snapshot["dirty"] = true
	if farfield_only:
		snapshot["farfield_render_dirty"] = (not already_dirty) or already_farfield_only
	else:
		snapshot["farfield_render_dirty"] = false
	_chunk_render_snapshots[chunk_id] = snapshot

func _should_rebuild_assignments(active_chunk_ids: Array[String], player_position: Vector3, player_velocity: Vector3) -> bool:
	if not _has_assignment_cache:
		return true
	if _force_assignment_rebuild:
		return true
	if not _string_arrays_equal(_last_assignment_chunk_ids, active_chunk_ids):
		return true
	if _can_reuse_farfield_assignments(player_position):
		return false
	if _can_reuse_layered_assignments(player_position):
		return false
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

func _can_reuse_farfield_assignments(player_position: Vector3) -> bool:
	if _last_player_context != _last_assignment_player_context:
		return false
	if int(_global_snapshot.get("tier2_count", 0)) > 0 or int(_global_snapshot.get("tier3_count", 0)) > 0:
		return false
	if player_position.distance_to(_last_assignment_player_position) >= FARFIELD_ASSIGNMENT_REBUILD_DISTANCE_M:
		return false
	return _assignment_rebuild_elapsed_sec < ASSIGNMENT_REBUILD_INTERVAL_SEC

func _can_reuse_layered_assignments(player_position: Vector3) -> bool:
	if _last_player_context != _last_assignment_player_context:
		return false
	if int(_global_snapshot.get("tier2_count", 0)) <= 0 \
			and int(_global_snapshot.get("tier3_count", 0)) <= 0 \
			and int(_last_profile_stats.get("crowd_midfield_count", 0)) <= 0:
		return false
	if player_position.distance_to(_last_assignment_player_position) >= LAYERED_ASSIGNMENT_REBUILD_DISTANCE_M:
		return false
	return _assignment_rebuild_elapsed_sec < ASSIGNMENT_REBUILD_INTERVAL_SEC

func _capture_dirty_chunk_ids() -> Dictionary:
	var dirty_chunk_ids: Dictionary = {}
	for chunk_id_variant in _chunk_render_snapshots.keys():
		var chunk_id := str(chunk_id_variant)
		if bool((_chunk_render_snapshots[chunk_id] as Dictionary).get("dirty", false)):
			dirty_chunk_ids[chunk_id] = true
	return dirty_chunk_ids

func _capture_farfield_render_dirty_chunk_ids() -> Dictionary:
	var dirty_chunk_ids: Dictionary = {}
	for chunk_id_variant in _chunk_render_snapshots.keys():
		var chunk_id := str(chunk_id_variant)
		var snapshot: Dictionary = _chunk_render_snapshots[chunk_id]
		if bool(snapshot.get("dirty", false)) and bool(snapshot.get("farfield_render_dirty", false)):
			dirty_chunk_ids[chunk_id] = true
	return dirty_chunk_ids

func _set_layer_state_refs(target: Array[CityPedestrianState], source: Array) -> void:
	target.clear()
	for state_variant in source:
		var state: CityPedestrianState = state_variant
		if state == null:
			continue
		target.append(state)

func _clear_transient_proximity_reactions(states: Array) -> void:
	for state_variant in states:
		var state: CityPedestrianState = state_variant
		if state == null:
			continue
		if state.reaction_state == "yield" or state.reaction_state == "sidestep":
			state.clear_reaction()

func _state_ids_from_refs(states: Array[CityPedestrianState]) -> Array[String]:
	var ids: Array[String] = []
	for state in states:
		if state == null:
			continue
		ids.append(state.pedestrian_id)
	return ids

func _collect_visible_farfield_chunk_ids(states: Array, target: Dictionary) -> void:
	for state_variant in states:
		var state: CityPedestrianState = state_variant
		if state == null or not state.is_alive():
			continue
		if state.tier != CityPedestrianState.TIER_1:
			continue
		if state.chunk_id == "":
			continue
		target[state.chunk_id] = true

func _flush_pending_farfield_render_dirty_chunks() -> void:
	for chunk_id_variant in _pending_farfield_render_dirty_chunk_ids.keys():
		_mark_chunk_render_dirty(str(chunk_id_variant), true)
	_pending_farfield_render_dirty_chunk_ids.clear()

func _chunk_snapshot_matches(previous_snapshot: Dictionary, next_snapshot: Dictionary) -> bool:
	if previous_snapshot.is_empty():
		return false
	for count_key in ["tier0_count", "tier1_count", "tier2_count", "tier3_count"]:
		if int(previous_snapshot.get(count_key, -1)) != int(next_snapshot.get(count_key, -2)):
			return false
	for state_key in ["tier1_states", "tier2_states", "tier3_states"]:
		if _chunk_snapshot_state_ids(previous_snapshot, state_key) != _chunk_snapshot_state_ids(next_snapshot, state_key):
			return false
	return true

func _chunk_snapshot_state_ids(snapshot: Dictionary, state_key: String) -> Array[String]:
	var state_ids: Array[String] = []
	for state_variant in snapshot.get(state_key, []):
		if state_variant is Dictionary:
			state_ids.append(str((state_variant as Dictionary).get("pedestrian_id", "")))
		elif state_variant != null:
			state_ids.append(str(state_variant.pedestrian_id))
	return state_ids

func _build_layer_profile_counts(farfield_count: int, midfield_count: int, nearfield_count: int, assignment_candidate_count: int, threat_candidate_count: int) -> Dictionary:
	return {
		"crowd_farfield_count": farfield_count,
		"crowd_midfield_count": midfield_count,
		"crowd_nearfield_count": nearfield_count,
		"crowd_assignment_candidate_count": assignment_candidate_count,
		"crowd_threat_candidate_count": threat_candidate_count,
	}

func _update_runtime_snapshot(
	active_chunk_count: int,
	active_state_count: int,
	tier0_count: int,
	tier1_count: int,
	tier2_count: int,
	tier3_count: int,
	runtime_snapshot: Dictionary,
	crowd_spawn_usec: int,
	step_profile: Dictionary,
	crowd_threat_broadcast_usec: int,
	crowd_assignment_rebuild_usec: int,
	crowd_snapshot_rebuild_usec: int,
	layer_profile_counts: Dictionary,
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
		"crowd_step_usec": int(step_profile.get("total_usec", 0)),
		"crowd_reaction_usec": crowd_threat_broadcast_usec,
		"crowd_rank_usec": crowd_assignment_rebuild_usec,
		"crowd_snapshot_rebuild_usec": crowd_snapshot_rebuild_usec,
		"crowd_farfield_count": int(layer_profile_counts.get("crowd_farfield_count", 0)),
		"crowd_midfield_count": int(layer_profile_counts.get("crowd_midfield_count", 0)),
		"crowd_nearfield_count": int(layer_profile_counts.get("crowd_nearfield_count", 0)),
		"crowd_farfield_step_usec": int(step_profile.get("farfield_usec", 0)),
		"crowd_midfield_step_usec": int(step_profile.get("midfield_usec", 0)),
		"crowd_nearfield_step_usec": int(step_profile.get("nearfield_usec", 0)),
		"crowd_assignment_rebuild_usec": crowd_assignment_rebuild_usec,
		"crowd_assignment_candidate_count": int(layer_profile_counts.get("crowd_assignment_candidate_count", 0)),
		"crowd_threat_broadcast_usec": crowd_threat_broadcast_usec,
		"crowd_threat_candidate_count": int(layer_profile_counts.get("crowd_threat_candidate_count", 0)),
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
		"dirty": true,
		"farfield_render_dirty": false,
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
	snapshot["dirty"] = true
	snapshot["farfield_render_dirty"] = false
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

func _get_vehicle_impact_candidates() -> Array[CityPedestrianState]:
	var candidates: Array[CityPedestrianState] = []
	var seen_ids: Dictionary = {}
	for state in _tier3_state_refs:
		if _append_projectile_hit_candidate(candidates, seen_ids, state):
			continue
	for state in _tier2_state_refs:
		if _append_projectile_hit_candidate(candidates, seen_ids, state):
			continue
	return candidates

func _vehicle_impact_hit_for_state(
	state: CityPedestrianState,
	vehicle_position: Vector3,
	forward: Vector3,
	lateral: Vector3,
	hit_radius_m: float,
	front_reach_m: float
) -> Dictionary:
	var planar_delta := Vector3(
		state.world_position.x - vehicle_position.x,
		0.0,
		state.world_position.z - vehicle_position.z
	)
	var forward_distance_m := planar_delta.dot(forward)
	if forward_distance_m < -0.8 or forward_distance_m > front_reach_m:
		return {}
	var lateral_distance_m := absf(planar_delta.dot(lateral))
	var allowed_lateral_m := maxf(hit_radius_m + state.radius_m, 0.6)
	if lateral_distance_m > allowed_lateral_m:
		return {}
	return {
		"state": state,
		"impact_position": state.world_position,
		"forward_distance_m": forward_distance_m,
	}

func _apply_vehicle_impact_panic(source_position: Vector3, victim_id: String) -> Dictionary:
	var candidate_states := _collect_vehicle_impact_panic_candidates(source_position, victim_id)
	candidate_states.sort_custom(func(a: CityPedestrianState, b: CityPedestrianState) -> bool:
		var a_rank := posmod(int(a.seed_value), 1000)
		var b_rank := posmod(int(b.seed_value), 1000)
		if a_rank == b_rank:
			return a.pedestrian_id < b.pedestrian_id
		return a_rank < b_rank
	)
	var responder_count := int(round(float(candidate_states.size()) * float(_budget_contract.get("vehicle_impact_panic_response_ratio", 0.6))))
	if candidate_states.size() > 0:
		responder_count = clampi(responder_count, 1, candidate_states.size())
	var responder_ids: Array[String] = []
	var candidate_ids: Array[String] = []
	var calm_witness_id := ""
	for candidate_index in range(candidate_states.size()):
		var state := candidate_states[candidate_index]
		candidate_ids.append(state.pedestrian_id)
		if candidate_index < responder_count:
			responder_ids.append(state.pedestrian_id)
			state.apply_reaction(_build_vehicle_impact_flee_command(state, source_position))
			continue
		if calm_witness_id == "":
			calm_witness_id = state.pedestrian_id
		state.clear_reaction()
	return {
		"candidate_count": candidate_states.size(),
		"candidate_ids": candidate_ids,
		"responder_count": responder_ids.size(),
		"responder_ids": responder_ids,
		"calm_witness_id": calm_witness_id,
	}

func _collect_vehicle_impact_panic_candidates(source_position: Vector3, victim_id: String) -> Array[CityPedestrianState]:
	var candidates: Array[CityPedestrianState] = []
	var seen_ids: Dictionary = {}
	var radius_m := float(_budget_contract.get("vehicle_impact_panic_radius_m", 16.0))
	for state_ref_group in [_tier3_state_refs, _tier2_state_refs]:
		for state_variant in state_ref_group:
			var state: CityPedestrianState = state_variant
			if state == null or not state.is_alive():
				continue
			if state.pedestrian_id == victim_id or seen_ids.has(state.pedestrian_id):
				continue
			if state.world_position.distance_to(source_position) > radius_m:
				continue
			seen_ids[state.pedestrian_id] = true
			candidates.append(state)
	return candidates

func _build_vehicle_impact_flee_command(state: CityPedestrianState, source_position: Vector3) -> Dictionary:
	var flee_duration_sec := _resolve_vehicle_impact_flee_duration_sec(state)
	var flee_direction := _resolve_vehicle_impact_escape_direction(state, source_position)
	var flee_distance_m := maxf(state.speed_mps * VEHICLE_IMPACT_FLEE_SPEED_MULTIPLIER * flee_duration_sec, 0.1)
	return {
		"reaction_state": "flee",
		"priority": 84,
		"duration_sec": flee_duration_sec,
		"flee_duration_sec": flee_duration_sec,
		"source_position": source_position,
		"flee_anchor_position": source_position,
		"flee_direction": flee_direction,
		"flee_target_position": state.world_position + flee_direction * flee_distance_m,
	}

func _resolve_vehicle_impact_flee_duration_sec(state: CityPedestrianState) -> float:
	var min_duration_sec := maxi(int(round(float(_budget_contract.get("flee_duration_min_sec", 20.0)))), 1)
	var max_duration_sec := maxi(int(round(float(_budget_contract.get("flee_duration_max_sec", float(min_duration_sec))))), min_duration_sec)
	return float(min_duration_sec + posmod(int(state.seed_value), (max_duration_sec - min_duration_sec) + 1))

func _resolve_vehicle_impact_escape_direction(state: CityPedestrianState, source_position: Vector3) -> Vector3:
	var away_vector := Vector3(
		state.world_position.x - source_position.x,
		0.0,
		state.world_position.z - source_position.z
	)
	if away_vector.length_squared() <= 0.0001:
		away_vector = state.heading if state.heading.length_squared() > 0.0001 else Vector3.FORWARD
	away_vector = away_vector.normalized()
	var max_scatter_angle_deg := float(_budget_contract.get("flee_scatter_angle_deg", 42.0))
	var scatter_angles := [
		-max_scatter_angle_deg,
		-max_scatter_angle_deg * 0.35,
		max_scatter_angle_deg * 0.35,
		max_scatter_angle_deg,
	]
	var scatter_index := posmod(int(state.seed_value), scatter_angles.size())
	var escape_direction := away_vector.rotated(Vector3.UP, deg_to_rad(float(scatter_angles[scatter_index])))
	escape_direction.y = 0.0
	if escape_direction.length_squared() <= 0.0001:
		return away_vector
	return escape_direction.normalized()
