extends RefCounted

const REACTION_NONE := "none"
const REACTION_YIELD := "yield"
const REACTION_SIDESTEP := "sidestep"
const REACTION_PANIC := "panic"
const REACTION_FLEE := "flee"

var _events: Array[Dictionary] = []
var _player_position := Vector3.ZERO
var _player_velocity := Vector3.ZERO
var _has_player_context := false
var _player_context: Dictionary = {}

func reset() -> void:
	_events.clear()
	_player_position = Vector3.ZERO
	_player_velocity = Vector3.ZERO
	_has_player_context = false
	_player_context.clear()

func set_player_context(player_position: Vector3, player_velocity: Vector3 = Vector3.ZERO, context: Dictionary = {}) -> void:
	_player_position = player_position
	_player_velocity = player_velocity
	_has_player_context = true
	_player_context = context.duplicate(true)

func notify_projectile_event(origin: Vector3, direction: Vector3, range_m: float) -> void:
	var normalized_direction := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	_events.append({
		"type": "projectile",
		"origin": origin,
		"direction": normalized_direction,
		"range_m": maxf(range_m, 1.0),
		"ttl_sec": 0.65,
	})
	_events.append({
		"type": "gunshot",
		"position": origin,
		"ttl_sec": 0.85,
	})

func notify_explosion_event(world_position: Vector3, radius_m: float, threat_radius_m: float = -1.0) -> void:
	_events.append({
		"type": "explosion",
		"position": world_position,
		"radius_m": maxf(radius_m, 0.0),
		"threat_radius_m": threat_radius_m,
		"ttl_sec": 1.4,
	})

func notify_casualty_event(world_position: Vector3, witness_radius_m: float = -1.0) -> void:
	_events.append({
		"type": "casualty",
		"position": world_position,
		"witness_radius_m": witness_radius_m,
		"ttl_sec": 2.2,
	})

func update_reactions(active_states: Array, budget_contract: Dictionary, delta: float) -> Array[Dictionary]:
	_age_events(delta)
	var player_speed_mps := _player_velocity.length()
	var reactive_candidates: Array[Dictionary] = []
	for state_variant in active_states:
		var state = state_variant
		if state.has_method("is_alive") and not state.is_alive():
			continue
		var command := _build_command_for_state(state, budget_contract, player_speed_mps)
		if not command.is_empty():
			state.apply_reaction(command)
		if state.is_reactive():
			reactive_candidates.append({
				"pedestrian_id": state.pedestrian_id,
				"reaction_priority": int(state.reaction_priority),
				"reaction_state": str(state.reaction_state),
				"distance_m": _resolve_reactive_selection_distance(state),
			})
	return reactive_candidates

func get_event_count() -> int:
	return _events.size()

func _age_events(delta: float) -> void:
	if delta <= 0.0:
		return
	var surviving_events: Array[Dictionary] = []
	for event_variant in _events:
		var event: Dictionary = event_variant
		var ttl_sec := float(event.get("ttl_sec", 0.0)) - delta
		if ttl_sec <= 0.0:
			continue
		event["ttl_sec"] = ttl_sec
		surviving_events.append(event)
	_events = surviving_events

func _build_command_for_state(state, budget_contract: Dictionary, player_speed_mps: float) -> Dictionary:
	var best_command: Dictionary = {}
	if _has_player_context:
		var distance_to_player: float = state.world_position.distance_to(_player_position)
		var personal_space_radius := float(budget_contract.get("player_personal_space_m", 3.25))
		var near_radius := float(budget_contract.get("player_near_radius_m", 6.5))
		var is_inspection_mode := _is_inspection_context()
		var player_is_fast := (not is_inspection_mode) and player_speed_mps >= float(budget_contract.get("player_fast_speed_mps", 10.0))
		if distance_to_player <= personal_space_radius:
			best_command = {
				"reaction_state": REACTION_SIDESTEP if player_is_fast else REACTION_YIELD,
				"priority": 48 if player_is_fast else 36,
				"duration_sec": 1.1,
				"source_position": _player_position,
			}
		elif distance_to_player <= near_radius:
			best_command = {
				"reaction_state": REACTION_YIELD,
				"priority": 24,
				"duration_sec": 0.9,
				"source_position": _player_position,
			}

	for event_variant in _events:
		var event: Dictionary = event_variant
		var event_type := str(event.get("type", ""))
		var candidate: Dictionary = {}
		match event_type:
			"projectile":
				var closest_distance := _distance_to_projectile_path(state.world_position, event)
				if closest_distance <= float(budget_contract.get("projectile_reaction_radius_m", 4.5)):
					candidate = {
						"reaction_state": REACTION_SIDESTEP,
						"priority": 88,
						"duration_sec": 1.4,
						"source_position": event.get("origin", state.world_position),
					}
			"gunshot":
				if state.world_position.distance_to(event.get("position", Vector3.ZERO)) <= float(budget_contract.get("gunshot_radius_m", 24.0)):
					candidate = _build_escape_command(
						state,
						REACTION_PANIC,
						72,
						event.get("position", state.world_position),
						1.8,
						budget_contract
					)
			"explosion":
				var explosion_center: Vector3 = event.get("position", Vector3.ZERO)
				var explosion_radius := float(event.get("threat_radius_m", -1.0))
				if explosion_radius < 0.0:
					explosion_radius = float(event.get("radius_m", 0.0)) + float(budget_contract.get("explosion_reaction_radius_m", 18.0))
				if state.world_position.distance_to(explosion_center) <= explosion_radius:
					candidate = _build_escape_command(
						state,
						REACTION_FLEE,
						100,
						explosion_center,
						2.6,
						budget_contract
					)
			"casualty":
				var casualty_center: Vector3 = event.get("position", Vector3.ZERO)
				var casualty_radius := float(event.get("witness_radius_m", -1.0))
				if casualty_radius < 0.0:
					casualty_radius = float(budget_contract.get("casualty_witness_radius_m", 18.0))
				if state.world_position.distance_to(casualty_center) <= casualty_radius:
					candidate = _build_escape_command(
						state,
						REACTION_FLEE,
						96,
						casualty_center,
						float(budget_contract.get("casualty_reaction_duration_sec", 2.8)),
						budget_contract
					)
		if candidate.is_empty():
			continue
		if best_command.is_empty() or int(candidate.get("priority", 0)) > int(best_command.get("priority", 0)):
			best_command = candidate
	return best_command

func _build_escape_command(state, reaction_state: String, priority: int, source_position: Vector3, duration_sec: float, budget_contract: Dictionary) -> Dictionary:
	var anchor_position := _player_position if _has_player_context else source_position
	var escape_direction := _resolve_escape_direction(state, anchor_position, source_position, budget_contract)
	var flee_distance_m := float(budget_contract.get("flee_min_distance_m", 500.0))
	return {
		"reaction_state": reaction_state,
		"priority": priority,
		"duration_sec": duration_sec,
		"source_position": source_position,
		"flee_anchor_position": anchor_position,
		"flee_target_position": state.world_position + escape_direction * flee_distance_m,
	}

func _resolve_escape_direction(state, anchor_position: Vector3, source_position: Vector3, budget_contract: Dictionary) -> Vector3:
	var away_vector := Vector3(
		state.world_position.x - anchor_position.x,
		0.0,
		state.world_position.z - anchor_position.z
	)
	if away_vector.length_squared() <= 0.0001:
		away_vector = Vector3(
			state.world_position.x - source_position.x,
			0.0,
			state.world_position.z - source_position.z
		)
	if away_vector.length_squared() <= 0.0001:
		away_vector = state.heading if state.heading.length_squared() > 0.0001 else Vector3.FORWARD
	away_vector = away_vector.normalized()
	var max_scatter_angle_deg := float(budget_contract.get("flee_scatter_angle_deg", 42.0))
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

func _resolve_reactive_selection_distance(state) -> float:
	var player_distance_m: float = INF
	if _has_player_context:
		player_distance_m = _player_position.distance_to(state.world_position)
	var source_distance_m: float = state.world_position.distance_to(state.reaction_source_position)
	if state.reaction_state == REACTION_PANIC or state.reaction_state == REACTION_FLEE:
		return minf(player_distance_m, source_distance_m)
	if _has_player_context:
		return player_distance_m
	return source_distance_m

func _distance_to_projectile_path(world_position: Vector3, event: Dictionary) -> float:
	var origin: Vector3 = event.get("origin", Vector3.ZERO)
	var direction: Vector3 = event.get("direction", Vector3.FORWARD)
	var range_m := float(event.get("range_m", 0.0))
	var end_position := origin + direction * range_m
	var origin_2d := Vector2(origin.x, origin.z)
	var end_2d := Vector2(end_position.x, end_position.z)
	var point_2d := Vector2(world_position.x, world_position.z)
	var segment := end_2d - origin_2d
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point_2d.distance_to(origin_2d)
	var t := clampf((point_2d - origin_2d).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point_2d.distance_to(origin_2d + segment * t)

func _is_inspection_context() -> bool:
	var control_mode := str(_player_context.get("control_mode", ""))
	if control_mode == "inspection":
		return true
	var speed_profile := str(_player_context.get("speed_profile", ""))
	return speed_profile == "inspection"
