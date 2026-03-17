extends RefCounted
class_name CityMusicRoadRunState

const CROSSING_EPSILON_M := 0.0001

var _definition = null
var _triggered_note_events: Array[Dictionary] = []
var _strip_trigger_time_sec_by_id: Dictionary = {}
var _strip_phase_cache: Dictionary = {}
var _double_fire_count := 0
var _song_success := false
var _last_completed_direction := ""
var _last_completed_run: Dictionary = {}
var _current_local_position := Vector3.ZERO
var _current_time_sec := 0.0
var _current_driving := false
var _current_motion_direction_sign := 0
var _previous_position_valid := false
var _previous_local_position := Vector3.ZERO
var _previous_time_sec := 0.0
var _active_session := {}

func setup(definition_variant: Variant) -> void:
	if definition_variant != null and definition_variant.has_method("get_note_strips"):
		_definition = definition_variant
	else:
		_definition = null
	reset()

func reset() -> void:
	_triggered_note_events.clear()
	_strip_trigger_time_sec_by_id.clear()
	_strip_phase_cache.clear()
	_double_fire_count = 0
	_song_success = false
	_last_completed_direction = ""
	_last_completed_run.clear()
	_current_local_position = Vector3.ZERO
	_current_time_sec = 0.0
	_current_driving = false
	_current_motion_direction_sign = 0
	_previous_position_valid = false
	_previous_local_position = Vector3.ZERO
	_previous_time_sec = 0.0
	_active_session = _build_empty_session()
	if _definition == null:
		return
	for strip in _definition.get_note_strips():
		_strip_trigger_time_sec_by_id[str(strip.get("strip_id", ""))] = -1.0

func advance_local_vehicle_state(vehicle_state: Dictionary, time_sec: float) -> Dictionary:
	if _definition == null or not _definition.is_valid():
		return {
			"frame_triggered_events": [],
		}
	var next_local_position = _resolve_local_position(vehicle_state)
	var next_driving := bool(vehicle_state.get("driving", false))
	var frame_triggered_events: Array[Dictionary] = []
	_current_time_sec = maxf(time_sec, 0.0)
	_current_local_position = next_local_position
	_current_driving = next_driving
	if not _previous_position_valid or _current_time_sec <= _previous_time_sec:
		_previous_position_valid = true
		_previous_local_position = next_local_position
		_previous_time_sec = _current_time_sec
		_current_motion_direction_sign = 0
		_refresh_phase_cache()
		return {
			"frame_triggered_events": frame_triggered_events,
		}

	var delta_time_sec := maxf(_current_time_sec - _previous_time_sec, 0.000001)
	var progress_delta: float = next_local_position.z - _previous_local_position.z
	var direction_sign := 0
	if progress_delta > 0.0001:
		direction_sign = 1
	elif progress_delta < -0.0001:
		direction_sign = -1
	_current_motion_direction_sign = direction_sign

	if not next_driving:
		_refresh_phase_cache()
		_previous_local_position = next_local_position
		_previous_time_sec = _current_time_sec
		return {
			"frame_triggered_events": frame_triggered_events,
		}

	if direction_sign > 0 and _segment_intersects_entry_gate(_previous_local_position, next_local_position):
		_start_new_session(direction_sign, true)

	var crossed_strips: Array[Dictionary] = _collect_crossed_strips(_previous_local_position, next_local_position, direction_sign)
	if not crossed_strips.is_empty():
		var should_start_new_session: bool = not bool(_active_session.get("active", false)) \
			or int(_active_session.get("direction_sign", 0)) != direction_sign
		if should_start_new_session:
			_start_new_session(direction_sign, false)
		var observed_speed_mps: float = absf(progress_delta) / delta_time_sec
		for strip in crossed_strips:
			var strip_id := str(strip.get("strip_id", ""))
			var triggered_strip_ids: Dictionary = _active_session.get("triggered_strip_ids", {})
			if triggered_strip_ids.has(strip_id):
				_double_fire_count += 1
				continue
			var local_center: Vector3 = strip.get("local_center", Vector3.ZERO)
			var crossing_fraction: float = _resolve_crossing_fraction(_previous_local_position.z, next_local_position.z, local_center.z)
			var event_time_sec: float = lerpf(_previous_time_sec, _current_time_sec, crossing_fraction)
			var event := {
				"strip_id": strip_id,
				"order_index": int(strip.get("order_index", -1)),
				"note_id": str(strip.get("note_id", "")),
				"sample_id": str(strip.get("sample_id", "")),
				"midi_note": int(strip.get("midi_note", 0)),
				"duration_sec": float(strip.get("duration_sec", 0.25)),
				"velocity": 96,
				"event_time_sec": event_time_sec,
				"observed_speed_mps": observed_speed_mps,
				"direction": "forward" if direction_sign > 0 else "reverse",
			}
			frame_triggered_events.append(event)
			_triggered_note_events.append(event)
			_strip_trigger_time_sec_by_id[strip_id] = event_time_sec
			triggered_strip_ids[strip_id] = true
			_active_session["triggered_strip_ids"] = triggered_strip_ids
			_active_session["triggered_count"] = int(_active_session.get("triggered_count", 0)) + 1
			if int(_active_session.get("first_order_index", -1)) < 0:
				_active_session["first_order_index"] = int(strip.get("order_index", -1))
			var last_order_index := int(_active_session.get("last_order_index", -1))
			if direction_sign > 0 and last_order_index >= 0 and int(strip.get("order_index", -1)) <= last_order_index:
				_active_session["ordered"] = false
			elif direction_sign < 0 and last_order_index >= 0 and int(strip.get("order_index", -1)) >= last_order_index:
				_active_session["ordered"] = false
			_active_session["last_order_index"] = int(strip.get("order_index", -1))
			_active_session["last_event_time_sec"] = event_time_sec
			if absf(observed_speed_mps - float(_definition.get_value("target_speed_mps", 0.0))) > float(_definition.get_value("speed_tolerance_mps", 0.0)):
				_active_session["speed_in_window"] = false
		if int(_active_session.get("triggered_count", 0)) >= _definition.get_strip_count():
			_finalize_session()

	_refresh_phase_cache()
	_previous_local_position = next_local_position
	_previous_time_sec = _current_time_sec
	return {
		"frame_triggered_events": frame_triggered_events,
	}

func get_strip_phase(strip_id: String) -> Dictionary:
	var cached = _strip_phase_cache.get(strip_id, {})
	if not (cached is Dictionary):
		return {}
	return (cached as Dictionary).duplicate(true)

func get_state() -> Dictionary:
	var triggered_events: Array[Dictionary] = []
	for event in _triggered_note_events:
		triggered_events.append(event.duplicate(true))
	return {
		"song_id": str(_definition.get_value("song_id", "")) if _definition != null else "",
		"strip_count": _definition.get_strip_count() if _definition != null else 0,
		"triggered_note_count": triggered_events.size(),
		"triggered_note_events": triggered_events,
		"song_success": _song_success,
		"double_fire_count": _double_fire_count,
		"last_completed_direction": _last_completed_direction,
		"last_completed_run": _last_completed_run.duplicate(true),
		"road_length_m": float(_definition.get_value("road_length_m", 0.0)) if _definition != null else 0.0,
		"target_speed_mps": float(_definition.get_value("target_speed_mps", 0.0)) if _definition != null else 0.0,
	}

func _build_empty_session() -> Dictionary:
	return {
		"active": false,
		"direction_sign": 0,
		"gate_armed": false,
		"ordered": true,
		"speed_in_window": true,
		"triggered_count": 0,
		"triggered_strip_ids": {},
		"first_order_index": -1,
		"last_order_index": -1,
		"last_event_time_sec": 0.0,
	}

func _start_new_session(direction_sign: int, gate_armed: bool) -> void:
	_active_session = _build_empty_session()
	_active_session["active"] = true
	_active_session["direction_sign"] = direction_sign
	_active_session["gate_armed"] = gate_armed
	_active_session["last_event_time_sec"] = _current_time_sec
	_triggered_note_events.clear()
	_song_success = false
	_last_completed_direction = ""
	_last_completed_run.clear()
	for strip_id in _strip_trigger_time_sec_by_id.keys():
		_strip_trigger_time_sec_by_id[strip_id] = -1.0

func _finalize_session() -> void:
	if not bool(_active_session.get("active", false)):
		return
	var direction_sign := int(_active_session.get("direction_sign", 0))
	_last_completed_direction = "forward" if direction_sign > 0 else "reverse"
	var forward_success: bool = direction_sign > 0 \
		and bool(_active_session.get("gate_armed", false)) \
		and bool(_active_session.get("ordered", false)) \
		and bool(_active_session.get("speed_in_window", false)) \
		and int(_active_session.get("first_order_index", -1)) == 0 \
		and int(_active_session.get("last_order_index", -1)) == _definition.get_strip_count() - 1
	_song_success = forward_success
	_last_completed_run = {
		"song_id": str(_definition.get_value("song_id", "")),
		"song_success": _song_success,
		"triggered_note_count": _triggered_note_events.size(),
		"completed_time_sec": _current_time_sec,
		"direction": _last_completed_direction,
	}
	_active_session["active"] = false

func _collect_crossed_strips(previous_position: Vector3, next_position: Vector3, direction_sign: int) -> Array[Dictionary]:
	if direction_sign == 0:
		return []
	var crossed: Array[Dictionary] = []
	var strips: Array[Dictionary] = _definition.get_note_strips() if direction_sign > 0 else _definition.get_note_strips_descending()
	var lateral_x := next_position.x
	for strip in strips:
		var local_center: Vector3 = strip.get("local_center", Vector3.ZERO)
		if not _strip_center_crossed(previous_position.z, next_position.z, local_center.z, direction_sign):
			continue
		if absf(lateral_x - local_center.x) > float(strip.get("trigger_width_m", 0.0)) * 0.5:
			continue
		crossed.append(strip.duplicate(true))
	return crossed

func _strip_center_crossed(previous_z: float, next_z: float, target_z: float, direction_sign: int) -> bool:
	if direction_sign > 0:
		return target_z > previous_z + CROSSING_EPSILON_M and target_z <= next_z + CROSSING_EPSILON_M
	if direction_sign < 0:
		return target_z < previous_z - CROSSING_EPSILON_M and target_z >= next_z - CROSSING_EPSILON_M
	return false

func _segment_intersects_entry_gate(previous_position: Vector3, next_position: Vector3) -> bool:
	var entry_gate: Dictionary = _definition.get_entry_gate()
	if entry_gate.is_empty():
		return false
	var center: Vector3 = entry_gate.get("local_center", Vector3.ZERO)
	var half_extents: Vector3 = entry_gate.get("half_extents", Vector3.ZERO)
	var min_x := center.x - half_extents.x
	var max_x := center.x + half_extents.x
	var min_z := center.z - half_extents.z
	var max_z := center.z + half_extents.z
	var segment_min_x := minf(previous_position.x, next_position.x)
	var segment_max_x := maxf(previous_position.x, next_position.x)
	var segment_min_z := minf(previous_position.z, next_position.z)
	var segment_max_z := maxf(previous_position.z, next_position.z)
	return segment_max_x >= min_x and segment_min_x <= max_x and segment_max_z >= min_z and segment_min_z <= max_z

func _resolve_crossing_fraction(previous_z: float, next_z: float, target_z: float) -> float:
	var delta_z := next_z - previous_z
	if absf(delta_z) <= 0.000001:
		return 1.0
	return clampf((target_z - previous_z) / delta_z, 0.0, 1.0)

func _resolve_local_position(vehicle_state: Dictionary) -> Vector3:
	var local_position_variant = vehicle_state.get("local_position", null)
	if local_position_variant is Vector3:
		return local_position_variant
	var world_position_variant = vehicle_state.get("world_position", null)
	if world_position_variant is Vector3:
		return world_position_variant
	return Vector3.ZERO

func _refresh_phase_cache() -> void:
	if _definition == null:
		_strip_phase_cache.clear()
		return
	_strip_phase_cache.clear()
	for strip in _definition.get_note_strips():
		var strip_id := str(strip.get("strip_id", ""))
		_strip_phase_cache[strip_id] = _build_strip_phase(strip)

func _build_strip_phase(strip: Dictionary) -> Dictionary:
	var strip_id := str(strip.get("strip_id", ""))
	var last_trigger_time_sec := float(_strip_trigger_time_sec_by_id.get(strip_id, -1.0))
	var hit_flash_duration_sec: float = float(_definition.get_value("hit_flash_duration_sec", 0.0))
	var release_decay_duration_sec: float = float(_definition.get_value("release_decay_duration_sec", 0.0))
	if last_trigger_time_sec >= 0.0:
		var elapsed_since_trigger_sec := _current_time_sec - last_trigger_time_sec
		if elapsed_since_trigger_sec <= hit_flash_duration_sec:
			return {
				"phase": "active",
				"phase_index": 2,
				"phase_strength": 1.0,
			}
		if elapsed_since_trigger_sec <= hit_flash_duration_sec + release_decay_duration_sec:
			var decay_t := 1.0 - ((elapsed_since_trigger_sec - hit_flash_duration_sec) / maxf(release_decay_duration_sec, 0.0001))
			return {
				"phase": "decay",
				"phase_index": 3,
				"phase_strength": clampf(decay_t, 0.0, 1.0),
			}
	if _current_driving and _current_motion_direction_sign != 0:
		var local_center: Vector3 = strip.get("local_center", Vector3.ZERO)
		var distance_along_m := (local_center.z - _current_local_position.z) * float(_current_motion_direction_sign)
		var approach_glow_distance_m := float(_definition.get_value("approach_glow_distance_m", 0.0))
		if distance_along_m >= 0.0 and distance_along_m <= approach_glow_distance_m:
			if absf(_current_local_position.x - local_center.x) <= float(strip.get("trigger_width_m", 0.0)) * 0.5:
				var approach_strength := 1.0 - (distance_along_m / maxf(approach_glow_distance_m, 0.0001))
				return {
					"phase": "approach",
					"phase_index": 1,
					"phase_strength": clampf(approach_strength, 0.0, 1.0),
				}
	return {
		"phase": "idle",
		"phase_index": 0,
		"phase_strength": 0.0,
	}
