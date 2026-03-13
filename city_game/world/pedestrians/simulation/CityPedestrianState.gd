extends RefCounted

const TIER_0 := "tier0"
const TIER_1 := "tier1"
const TIER_2 := "tier2"
const TIER_3 := "tier3"
const LIFE_ALIVE := "alive"
const LIFE_DEAD := "dead"
const FLEE_BUDGET_TICKS_PER_SEC := 60

var pedestrian_id := ""
var chunk_id := ""
var page_id := ""
var spawn_slot_id := ""
var road_id := ""
var lane_ref_id := ""
var route_signature := ""
var archetype_id := ""
var archetype_signature := ""
var seed_value := 0
var tier := TIER_0
var height_m := 1.75
var radius_m := 0.28
var speed_mps := 1.25
var stride_phase := 0.0
var route_progress := 0.0
var route_direction := 1.0
var world_position := Vector3.ZERO
var heading := Vector3.FORWARD
var lane_points: Array[Vector3] = []
var lane_length_m := 0.0
var tint := Color(0.7, 0.74, 0.78, 1.0)
var reaction_state := "none"
var reaction_priority := 0
var reaction_timer_sec := 0.0
var reaction_source_position := Vector3.ZERO
var lateral_offset_m := 0.0
var lateral_offset_sign := 1.0
var life_state := LIFE_ALIVE
var death_cause := ""
var death_source_position := Vector3.ZERO
var flee_target_position := Vector3.ZERO
var flee_anchor_position := Vector3.ZERO
var flee_direction := Vector3.ZERO
var flee_stop_distance_m := 0.0
var flee_budget_ticks_remaining := 0
var flee_budget_tick_remainder_sec := 0.0
var _has_flee_target := false
var _parked_after_flee := false
var _queued_step_sec := 0.0

func setup(data: Dictionary) -> void:
	pedestrian_id = str(data.get("pedestrian_id", ""))
	chunk_id = str(data.get("chunk_id", ""))
	page_id = str(data.get("page_id", ""))
	spawn_slot_id = str(data.get("spawn_slot_id", ""))
	road_id = str(data.get("road_id", ""))
	lane_ref_id = str(data.get("lane_ref_id", ""))
	route_signature = str(data.get("route_signature", ""))
	archetype_id = str(data.get("archetype_id", "resident"))
	archetype_signature = str(data.get("archetype_signature", "resident:v0"))
	seed_value = int(data.get("seed", 0))
	height_m = float(data.get("height_m", 1.75))
	radius_m = float(data.get("radius_m", 0.28))
	speed_mps = float(data.get("speed_mps", 1.25))
	stride_phase = clampf(float(data.get("stride_phase", 0.0)), 0.0, 1.0)
	route_progress = clampf(float(data.get("route_progress", 0.0)), 0.0, 1.0)
	world_position = data.get("world_position", Vector3.ZERO)
	tint = data.get("tint", Color(0.7, 0.74, 0.78, 1.0))
	var lane_points_source: Array = data.get("lane_points", [])
	lane_points.clear()
	for point in lane_points_source:
		lane_points.append(point)
	lane_length_m = maxf(float(data.get("lane_length_m", _measure_lane_length(lane_points))), 0.001)
	var initial_sample := _sample_lane_state(route_progress)
	world_position.x = initial_sample.position.x
	world_position.z = initial_sample.position.z
	heading = initial_sample.heading

func step(delta: float) -> void:
	if delta <= 0.0:
		return
	if not is_alive():
		return
	if _parked_after_flee and reaction_state == "none":
		return
	if reaction_state == "panic" or reaction_state == "flee":
		if _has_flee_target:
			_step_flee(delta)
			return
		_align_route_direction_away_from_source()
	if lane_points.size() < 2:
		stride_phase = fposmod(stride_phase + delta * 0.9, 1.0)
		_advance_reaction_timers(delta)
		return
	var progress_delta := (speed_mps * _reaction_speed_multiplier() * delta) / maxf(lane_length_m, 0.001)
	route_progress += progress_delta * route_direction
	if route_progress > 1.0:
		route_progress = 2.0 - route_progress
		route_direction = -1.0
	elif route_progress < 0.0:
		route_progress = -route_progress
		route_direction = 1.0
	var sample := _sample_lane_state(route_progress)
	var lateral := Vector3(-sample.heading.z, 0.0, sample.heading.x)
	if lateral.length_squared() <= 0.0001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized()
	lateral_offset_m = move_toward(lateral_offset_m, _target_lateral_offset_m(), delta * 2.5)
	var adjusted_position: Vector3 = sample.position + lateral * lateral_offset_m
	world_position.x = adjusted_position.x
	world_position.z = adjusted_position.z
	heading = sample.heading
	stride_phase = fposmod(stride_phase + delta * maxf(speed_mps * 0.55, 0.5), 1.0)
	_advance_reaction_timers(delta)

func apply_ground_height(height_y: float) -> void:
	world_position.y = height_y

func set_tier(next_tier: String) -> void:
	tier = next_tier

func apply_reaction(data: Dictionary) -> void:
	if not is_alive():
		return
	var next_reaction_state := str(data.get("reaction_state", "none"))
	if next_reaction_state == "none":
		return
	var next_priority := int(data.get("priority", reaction_priority))
	if _should_preserve_current_reaction(next_reaction_state, next_priority):
		reaction_timer_sec = maxf(reaction_timer_sec, float(data.get("duration_sec", 0.0)))
		return
	var next_source_position: Vector3 = data.get("source_position", world_position)
	if reaction_state != next_reaction_state:
		lateral_offset_sign = _resolve_lateral_offset_sign(next_source_position)
	_parked_after_flee = false
	if is_zero_approx(route_direction):
		route_direction = 1.0
	reaction_state = next_reaction_state
	reaction_priority = next_priority
	reaction_source_position = next_source_position
	if reaction_state == "panic" or reaction_state == "flee":
		_configure_flee_motion(data, next_source_position)
	else:
		_clear_flee_target()
	if _has_flee_target:
		reaction_timer_sec = _resolve_flee_budget_seconds()
	else:
		reaction_timer_sec = maxf(reaction_timer_sec, float(data.get("duration_sec", 0.0)))

func clear_reaction() -> void:
	reaction_state = "none"
	reaction_priority = 0
	reaction_timer_sec = 0.0
	reaction_source_position = world_position
	_clear_flee_target()
	_parked_after_flee = false

func queue_step(delta: float) -> void:
	if delta <= 0.0:
		return
	if not is_alive():
		return
	_queued_step_sec += delta

func consume_queued_step(min_interval_sec: float) -> float:
	if _queued_step_sec < min_interval_sec:
		return 0.0
	var queued_delta := _queued_step_sec
	_queued_step_sec = 0.0
	return queued_delta

func flush_queued_step() -> float:
	var queued_delta := _queued_step_sec
	_queued_step_sec = 0.0
	return queued_delta

func is_reactive() -> bool:
	return reaction_state != "none" and reaction_timer_sec > 0.0

func is_alive() -> bool:
	return life_state == LIFE_ALIVE

func mark_dead(cause: String, source_position: Vector3 = Vector3.ZERO) -> void:
	life_state = LIFE_DEAD
	death_cause = cause
	death_source_position = source_position
	tier = TIER_0
	_queued_step_sec = 0.0
	clear_reaction()

func to_snapshot() -> Dictionary:
	return {
		"pedestrian_id": pedestrian_id,
		"chunk_id": chunk_id,
		"page_id": page_id,
		"spawn_slot_id": spawn_slot_id,
		"road_id": road_id,
		"lane_ref_id": lane_ref_id,
		"route_signature": route_signature,
		"archetype_id": archetype_id,
		"archetype_signature": archetype_signature,
		"seed": seed_value,
		"tier": tier,
		"height_m": height_m,
		"radius_m": radius_m,
		"speed_mps": speed_mps,
		"stride_phase": stride_phase,
		"route_progress": route_progress,
		"world_position": world_position,
		"heading": heading,
		"tint": tint,
		"reaction_state": reaction_state,
		"reaction_priority": reaction_priority,
		"reaction_timer_sec": reaction_timer_sec,
		"life_state": life_state,
		"death_cause": death_cause,
		"death_source_position": death_source_position,
	}

func to_render_snapshot() -> Dictionary:
	return {
		"pedestrian_id": pedestrian_id,
		"world_position": world_position,
		"heading": heading,
		"height_m": height_m,
		"radius_m": radius_m,
	}

func _sample_lane_state(progress: float) -> Dictionary:
	if lane_points.is_empty():
		return {
			"position": world_position,
			"heading": heading,
		}
	if lane_points.size() == 1:
		return {
			"position": lane_points[0],
			"heading": heading,
		}
	var target_length := lane_length_m * clampf(progress, 0.0, 1.0)
	var traversed := 0.0
	for point_index in range(lane_points.size() - 1):
		var a: Vector3 = lane_points[point_index]
		var b: Vector3 = lane_points[point_index + 1]
		var segment := b - a
		var segment_length := segment.length()
		if traversed + segment_length >= target_length:
			var t := 0.0 if segment_length <= 0.001 else (target_length - traversed) / segment_length
			return {
				"position": a.lerp(b, clampf(t, 0.0, 1.0)),
				"heading": segment.normalized(),
			}
		traversed += segment_length
	var last_index := lane_points.size() - 1
	return {
		"position": lane_points[last_index],
		"heading": (lane_points[last_index] - lane_points[last_index - 1]).normalized(),
	}

func _measure_lane_length(points: Array[Vector3]) -> float:
	var total := 0.0
	for point_index in range(points.size() - 1):
		total += points[point_index].distance_to(points[point_index + 1])
	return total

func _advance_reaction_timers(delta: float) -> void:
	if reaction_timer_sec <= 0.0:
		clear_reaction()
		return
	reaction_timer_sec = maxf(reaction_timer_sec - delta, 0.0)
	if reaction_timer_sec <= 0.0:
		clear_reaction()

func _configure_flee_motion(data: Dictionary, fallback_anchor: Vector3) -> void:
	if not data.has("flee_target_position"):
		_clear_flee_target()
		return
	flee_target_position = data.get("flee_target_position", world_position)
	flee_anchor_position = data.get("flee_anchor_position", fallback_anchor)
	flee_direction = data.get("flee_direction", Vector3.ZERO)
	if flee_direction.length_squared() <= 0.0001:
		flee_direction = Vector3(
			flee_target_position.x - world_position.x,
			0.0,
			flee_target_position.z - world_position.z
		)
	if flee_direction.length_squared() > 0.0001:
		flee_direction = flee_direction.normalized()
	flee_stop_distance_m = world_position.distance_to(flee_target_position)
	var flee_duration_sec := maxf(float(data.get("flee_duration_sec", data.get("duration_sec", 0.0))), 0.0)
	flee_budget_ticks_remaining = maxi(int(round(flee_duration_sec * float(FLEE_BUDGET_TICKS_PER_SEC))), 0)
	flee_budget_tick_remainder_sec = 0.0
	_has_flee_target = flee_stop_distance_m > 0.05 and flee_budget_ticks_remaining > 0 and flee_direction.length_squared() > 0.0001
	if not _has_flee_target:
		flee_target_position = world_position

func _clear_flee_target() -> void:
	flee_target_position = Vector3.ZERO
	flee_anchor_position = Vector3.ZERO
	flee_direction = Vector3.ZERO
	flee_stop_distance_m = 0.0
	flee_budget_ticks_remaining = 0
	flee_budget_tick_remainder_sec = 0.0
	_has_flee_target = false

func _step_flee(delta: float) -> void:
	if flee_budget_ticks_remaining <= 0:
		_finish_flee()
		return
	var remaining_budget_sec := _resolve_flee_budget_seconds()
	if remaining_budget_sec <= 0.0:
		_finish_flee()
		return
	var applied_delta := minf(delta, remaining_budget_sec)
	if applied_delta <= 0.0:
		_finish_flee()
		return
	var move_direction := flee_direction
	if move_direction.length_squared() <= 0.0001:
		move_direction = Vector3(
			flee_target_position.x - world_position.x,
			0.0,
			flee_target_position.z - world_position.z
		)
		if move_direction.length_squared() <= 0.0001:
			_finish_flee()
			return
		move_direction = move_direction.normalized()
		flee_direction = move_direction
	var travel_distance_m := _resolve_flee_speed_mps() * applied_delta
	world_position.x += move_direction.x * travel_distance_m
	world_position.z += move_direction.z * travel_distance_m
	heading = move_direction
	lateral_offset_m = move_toward(lateral_offset_m, 0.0, applied_delta * 4.0)
	stride_phase = fposmod(stride_phase + applied_delta * maxf(speed_mps * 0.8, 0.75), 1.0)
	_consume_flee_budget(applied_delta)
	reaction_timer_sec = _resolve_flee_budget_seconds()
	if flee_budget_ticks_remaining <= 0:
		world_position.x = flee_target_position.x
		world_position.z = flee_target_position.z
		_finish_flee()

func _finish_flee() -> void:
	reaction_state = "none"
	reaction_priority = 0
	reaction_timer_sec = 0.0
	reaction_source_position = world_position
	_clear_flee_target()
	lateral_offset_m = 0.0
	route_direction = 0.0
	_parked_after_flee = true

func _consume_flee_budget(delta: float) -> void:
	if delta <= 0.0 or flee_budget_ticks_remaining <= 0:
		return
	var total_budget_sec := flee_budget_tick_remainder_sec + delta
	var ticks_to_consume := mini(
		int(floor(total_budget_sec * float(FLEE_BUDGET_TICKS_PER_SEC))),
		flee_budget_ticks_remaining
	)
	if ticks_to_consume <= 0:
		flee_budget_tick_remainder_sec = total_budget_sec
		return
	flee_budget_ticks_remaining -= ticks_to_consume
	flee_budget_tick_remainder_sec = total_budget_sec - (float(ticks_to_consume) / float(FLEE_BUDGET_TICKS_PER_SEC))

func _resolve_flee_budget_seconds() -> float:
	if flee_budget_ticks_remaining <= 0:
		return 0.0
	return float(flee_budget_ticks_remaining) / float(FLEE_BUDGET_TICKS_PER_SEC)

func _reaction_speed_multiplier() -> float:
	match reaction_state:
		"yield":
			return 0.15
		"sidestep":
			return 0.65
		"panic", "flee":
			return 4.0
		_:
			return 1.0

func _resolve_flee_speed_mps() -> float:
	return maxf(speed_mps * _reaction_speed_multiplier(), 0.1)

func _target_lateral_offset_m() -> float:
	match reaction_state:
		"yield":
			return 0.3 * lateral_offset_sign
		"sidestep":
			return 1.05 * lateral_offset_sign
		"panic", "flee":
			return 0.55 * lateral_offset_sign
		_:
			return 0.0

func _resolve_lateral_offset_sign(source_position: Vector3) -> float:
	var away_vector := Vector3(world_position.x - source_position.x, 0.0, world_position.z - source_position.z)
	if away_vector.length_squared() <= 0.0001:
		return 1.0 if posmod(seed_value, 2) == 0 else -1.0
	var lateral := Vector3(-heading.z, 0.0, heading.x)
	if lateral.length_squared() <= 0.0001:
		lateral = Vector3.RIGHT
	return 1.0 if lateral.normalized().dot(away_vector.normalized()) >= 0.0 else -1.0

func _align_route_direction_away_from_source() -> void:
	var away_vector := Vector3(world_position.x - reaction_source_position.x, 0.0, world_position.z - reaction_source_position.z)
	if away_vector.length_squared() <= 0.0001:
		return
	var normalized_away := away_vector.normalized()
	if heading.dot(normalized_away) < 0.0:
		route_direction = -1.0
	else:
		route_direction = 1.0

func _should_preserve_current_reaction(next_reaction_state: String, next_priority: int) -> bool:
	if reaction_timer_sec <= 0.0:
		return false
	var current_is_violent := _is_violent_reaction_state(reaction_state)
	var next_is_violent := _is_violent_reaction_state(next_reaction_state)
	if current_is_violent and not next_is_violent:
		return true
	if current_is_violent and next_is_violent and next_priority < reaction_priority:
		return true
	return false

func _is_violent_reaction_state(value: String) -> bool:
	return value == "panic" or value == "flee"
