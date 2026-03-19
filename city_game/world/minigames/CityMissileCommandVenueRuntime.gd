extends RefCounted

const ACTIVE_VENUE_SCAN_RADIUS_M := 768.0
const DEFAULT_CAMERA_FOV := 58.0
const ZOOM_CAMERA_FOV := 38.0
const BATTERY_CAMERA_LOOK_SENSITIVITY := 0.0032
const BATTERY_CAMERA_YAW_MAX_RAD := deg_to_rad(120.0)
const BATTERY_CAMERA_PITCH_MIN_RAD := deg_to_rad(-55.0)
const BATTERY_CAMERA_PITCH_MAX_RAD := deg_to_rad(68.0)
const INTERCEPTOR_SPEED_MPS := 60.0
const INTERCEPTOR_VISUAL_RADIUS_M := 0.42
const ENEMY_VISUAL_RADIUS_M := 0.85
const EXPLOSION_RADIUS_M := 10.5
const EXPLOSION_DURATION_SEC := 1.8
const WAVE_INTERMISSION_SEC := 1.8
const MISSILES_PER_SILO := 8

const WAVE_CONFIGS := [
	{"enemy_count": 4, "spawn_interval_sec": 1.25, "enemy_speed_mps": 18.0},
	{"enemy_count": 6, "spawn_interval_sec": 0.96, "enemy_speed_mps": 20.0},
	{"enemy_count": 8, "spawn_interval_sec": 0.78, "enemy_speed_mps": 22.0},
]

var _entries_by_venue_id: Dictionary = {}
var _active_venue_id := ""
var _battery_mode_active := false
var _ambient_simulation_frozen := false
var _zoom_active := false
var _wave_index := 0
var _wave_state := "idle"
var _wave_intermission_remaining_sec := 0.0
var _enemy_tracks: Array = []
var _enemy_spawn_queue: Array = []
var _interceptor_tracks: Array = []
var _explosion_tracks: Array = []
var _city_states: Dictionary = {}
var _silo_states: Dictionary = {}
var _selected_silo_index := 0
var _destroyed_enemy_count := 0
var _explosion_spawn_count := 0
var _reticle_world_position := Vector3.ZERO
var _reticle_screen_position := Vector2.ZERO
var _feedback_event_token := 0
var _feedback_event_text := ""
var _feedback_event_tone := "neutral"
var _hud_state: Dictionary = {}
var _start_ring_rearm_required := false
var _forced_wave_seed := 0
var _session_wave_seed := 0
var _session_serial := 0
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _last_chunk_renderer: Node = null
var _last_player: Node3D = null
var _last_mounted_venue: Node3D = null
var _wave_rng := RandomNumberGenerator.new()
var _camera_yaw_offset_rad := 0.0
var _camera_pitch_offset_rad := 0.0

func configure(entries: Dictionary) -> void:
	_entries_by_venue_id.clear()
	var sorted_ids: Array[String] = []
	for venue_id_variant in entries.keys():
		var venue_id := str(venue_id_variant).strip_edges()
		if venue_id == "":
			continue
		var entry: Dictionary = (entries.get(venue_id, {}) as Dictionary).duplicate(true)
		if str(entry.get("game_kind", "")) != "missile_command_battery":
			continue
		_entries_by_venue_id[venue_id] = entry
		sorted_ids.append(venue_id)
	sorted_ids.sort()
	if _active_venue_id == "" or not _entries_by_venue_id.has(_active_venue_id):
		_active_venue_id = sorted_ids[0] if not sorted_ids.is_empty() else ""
	if _active_venue_id == "":
		_reset_runtime_state()
	_refresh_hud_state()

func update(chunk_renderer: Node, player_node: Node3D, delta: float) -> Dictionary:
	_last_chunk_renderer = chunk_renderer
	_last_player = player_node
	var entry := _resolve_active_entry()
	if entry.is_empty():
		_handle_unavailable_runtime()
		return get_state()
	if not _battery_mode_active and not _is_player_near_active_venue(entry, player_node):
		_start_ring_rearm_required = false
		_last_mounted_venue = null
		_handle_unavailable_runtime()
		return get_state()
	var mounted_venue := _resolve_mounted_venue(chunk_renderer, entry)
	_last_mounted_venue = mounted_venue
	if mounted_venue == null:
		_handle_unavailable_runtime()
		return get_state()
	_update_battery_camera_pose(mounted_venue)
	_update_reticle(mounted_venue)
	_apply_camera_fov(mounted_venue)
	if not _battery_mode_active:
		var player_inside_start_ring := _is_player_near_active_venue(entry, player_node) \
			and mounted_venue.has_method("is_world_point_in_match_start_ring") \
			and bool(mounted_venue.is_world_point_in_match_start_ring(player_node.global_position))
		if not player_inside_start_ring:
			_start_ring_rearm_required = false
		if player_inside_start_ring and not _start_ring_rearm_required:
			_enter_battery_mode(player_node, mounted_venue)
	else:
		_advance_live_session(maxf(delta, 0.0), mounted_venue)
	_refresh_hud_state()
	_sync_venue_state(mounted_venue)
	return get_state()

func get_state() -> Dictionary:
	return {
		"active_venue_id": _active_venue_id,
		"venue_entry_count": _entries_by_venue_id.size(),
		"battery_mode_active": _battery_mode_active,
		"ambient_simulation_frozen": _ambient_simulation_frozen,
		"zoom_active": _zoom_active,
		"wave_index": _wave_index,
		"wave_total": WAVE_CONFIGS.size(),
		"wave_state": _wave_state,
		"selected_silo_index": _selected_silo_index,
		"selected_silo_id": _resolve_selected_silo_id(),
		"reticle_world_position": _reticle_world_position,
		"reticle_screen_position": _reticle_screen_position,
		"enemy_tracks": _enemy_tracks.duplicate(true),
		"interceptor_tracks": _interceptor_tracks.duplicate(true),
		"explosion_tracks": _explosion_tracks.duplicate(true),
		"city_states": _city_states.duplicate(true),
		"silo_states": _silo_states.duplicate(true),
		"cities_alive_count": _count_alive_cities(),
		"enemy_remaining_count": _enemy_tracks.size() + _enemy_spawn_queue.size(),
		"destroyed_enemy_count": _destroyed_enemy_count,
		"explosion_spawn_count": _explosion_spawn_count,
		"feedback_event_token": _feedback_event_token,
		"feedback_event_text": _feedback_event_text,
		"feedback_event_tone": _feedback_event_tone,
		"wave_seed": _session_wave_seed,
		"match_hud_state": _hud_state.duplicate(true),
	}

func get_match_hud_state() -> Dictionary:
	return _hud_state.duplicate(true)

func get_crosshair_state() -> Dictionary:
	var viewport_size := _resolve_viewport_size()
	return {
		"visible": _battery_mode_active,
		"screen_position": _reticle_screen_position if _battery_mode_active else viewport_size * 0.5,
		"viewport_size": viewport_size,
		"world_target": _reticle_world_position,
		"aim_down_sights_active": _zoom_active,
	}

func is_ambient_simulation_frozen() -> bool:
	return _ambient_simulation_frozen

func request_primary_fire() -> Dictionary:
	return request_fire_at_world_position(_reticle_world_position)

func request_fire_at_world_position(world_position: Vector3) -> Dictionary:
	if not _battery_mode_active:
		return {"success": false, "error": "battery_mode_inactive"}
	if _wave_state == "idle" or _wave_state == "victory" or _wave_state == "defeat":
		return {"success": false, "error": "wave_inactive"}
	var selected_silo_id := _resolve_selected_silo_id()
	if selected_silo_id == "":
		return {"success": false, "error": "missing_silo"}
	var silo_state: Dictionary = (_silo_states.get(selected_silo_id, {}) as Dictionary).duplicate(true)
	if bool(silo_state.get("destroyed", false)):
		return {"success": false, "error": "silo_destroyed"}
	var missiles_remaining := int(silo_state.get("missiles_remaining", 0))
	if missiles_remaining <= 0:
		return {"success": false, "error": "silo_empty"}
	var contract := _resolve_missile_command_contract()
	if contract.is_empty():
		return {"success": false, "error": "missing_contract"}
	var clamped_world_position := _clamp_world_position_to_gameplay_plane(world_position, contract)
	var start_world_position := silo_state.get("launch_world_position", silo_state.get("world_position", Vector3.ZERO)) as Vector3
	var duration_sec := maxf(start_world_position.distance_to(clamped_world_position) / INTERCEPTOR_SPEED_MPS, 0.08)
	_interceptor_tracks.append({
		"track_id": "interceptor_%d" % Time.get_ticks_usec(),
		"silo_id": selected_silo_id,
		"start_position": start_world_position,
		"target_position": clamped_world_position,
		"current_position": start_world_position,
		"duration_sec": duration_sec,
		"elapsed_sec": 0.0,
		"visual_radius_m": INTERCEPTOR_VISUAL_RADIUS_M,
	})
	silo_state["missiles_remaining"] = missiles_remaining - 1
	_silo_states[selected_silo_id] = silo_state
	_emit_feedback("发射 %s" % selected_silo_id.to_upper(), "action")
	_ensure_selected_silo_is_valid()
	_refresh_hud_state()
	return {
		"success": true,
		"selected_silo_id": selected_silo_id,
		"missiles_remaining": int(silo_state.get("missiles_remaining", 0)),
		"target_world_position": clamped_world_position,
	}

func cycle_silo() -> Dictionary:
	if not _battery_mode_active:
		return {"success": false, "error": "battery_mode_inactive"}
	var silo_ids := _get_silo_ids()
	if silo_ids.is_empty():
		return {"success": false, "error": "missing_silos"}
	var start_index := _selected_silo_index
	for step in range(1, silo_ids.size() + 1):
		var next_index := (start_index + step) % silo_ids.size()
		var silo_id := str(silo_ids[next_index])
		var silo_state: Dictionary = _silo_states.get(silo_id, {})
		if bool(silo_state.get("destroyed", false)):
			continue
		if int(silo_state.get("missiles_remaining", 0)) <= 0:
			continue
		_selected_silo_index = next_index
		_update_battery_camera_pose(_last_mounted_venue)
		_activate_battery_camera(_last_mounted_venue)
		_emit_feedback("切换至 %s" % silo_id.to_upper(), "neutral")
		_refresh_hud_state()
		return {"success": true, "selected_silo_index": _selected_silo_index, "selected_silo_id": _resolve_selected_silo_id()}
	return {"success": false, "error": "no_available_silo"}

func set_zoom_active(active: bool) -> Dictionary:
	if not _battery_mode_active:
		return {"success": false, "error": "battery_mode_inactive"}
	_zoom_active = active
	_apply_camera_fov(_last_mounted_venue)
	_refresh_hud_state()
	return {"success": true, "zoom_active": _zoom_active}

func apply_look_input(relative: Vector2) -> Dictionary:
	if not _battery_mode_active:
		return {"success": false, "error": "battery_mode_inactive"}
	_camera_yaw_offset_rad = clampf(
		_camera_yaw_offset_rad - relative.x * BATTERY_CAMERA_LOOK_SENSITIVITY,
		-BATTERY_CAMERA_YAW_MAX_RAD,
		BATTERY_CAMERA_YAW_MAX_RAD
	)
	_camera_pitch_offset_rad = clampf(
		_camera_pitch_offset_rad - relative.y * BATTERY_CAMERA_LOOK_SENSITIVITY,
		BATTERY_CAMERA_PITCH_MIN_RAD,
		BATTERY_CAMERA_PITCH_MAX_RAD
	)
	_update_battery_camera_pose(_last_mounted_venue)
	return {"success": true}

func exit_battery_mode() -> Dictionary:
	if not _battery_mode_active:
		return {"success": false, "error": "battery_mode_inactive"}
	_exit_battery_mode(true)
	return {"success": true}

func debug_set_wave_seed(seed_value: int) -> Dictionary:
	_forced_wave_seed = maxi(seed_value, 0)
	return {"success": true, "wave_seed": _forced_wave_seed}

func _handle_unavailable_runtime() -> void:
	if _battery_mode_active:
		_exit_battery_mode(false)
	_reset_runtime_state()

func _enter_battery_mode(player_node: Node3D, mounted_venue: Node3D) -> void:
	_reset_runtime_state()
	_initialize_target_states(mounted_venue)
	_seed_wave_rng()
	_battery_mode_active = true
	_ambient_simulation_frozen = true
	_zoom_active = false
	_session_serial += 1
	_camera_yaw_offset_rad = 0.0
	_camera_pitch_offset_rad = 0.0
	if player_node != null and player_node.has_method("set_control_enabled"):
		player_node.set_control_enabled(false)
	_update_battery_camera_pose(mounted_venue)
	_activate_battery_camera(mounted_venue)
	_begin_wave(1)
	_emit_feedback("进入防空模式", "action")
	_start_ring_rearm_required = false
	_refresh_hud_state()

func _exit_battery_mode(reset_session: bool) -> void:
	_battery_mode_active = false
	_ambient_simulation_frozen = false
	_zoom_active = false
	_restore_player_camera()
	if _last_player != null and is_instance_valid(_last_player) and _last_player.has_method("set_control_enabled"):
		_last_player.set_control_enabled(true)
	if reset_session:
		_start_ring_rearm_required = true
		_reset_runtime_state()
	else:
		_refresh_hud_state()

func _reset_runtime_state() -> void:
	_wave_index = 0
	_wave_state = "idle"
	_wave_intermission_remaining_sec = 0.0
	_enemy_tracks.clear()
	_enemy_spawn_queue.clear()
	_interceptor_tracks.clear()
	_explosion_tracks.clear()
	_city_states.clear()
	_silo_states.clear()
	_selected_silo_index = 0
	_destroyed_enemy_count = 0
	_explosion_spawn_count = 0
	_reticle_world_position = Vector3.ZERO
	_reticle_screen_position = Vector2.ZERO
	_feedback_event_token = 0
	_feedback_event_text = ""
	_feedback_event_tone = "neutral"
	_camera_yaw_offset_rad = 0.0
	_camera_pitch_offset_rad = 0.0
	_refresh_hud_state()

func _initialize_target_states(mounted_venue: Node3D) -> void:
	var contract := _resolve_missile_command_contract(mounted_venue)
	var city_contracts: Dictionary = (contract.get("cities", {}) as Dictionary).duplicate(true)
	var silo_contracts: Dictionary = (contract.get("silos", {}) as Dictionary).duplicate(true)
	for city_id_variant in city_contracts.keys():
		var city_id := str(city_id_variant)
		var city_contract: Dictionary = city_contracts.get(city_id, {})
		_city_states[city_id] = {
			"city_id": city_id,
			"world_position": city_contract.get("impact_world_position", city_contract.get("world_position", Vector3.ZERO)),
			"destroyed": false,
		}
	for silo_id_variant in silo_contracts.keys():
		var silo_id := str(silo_id_variant)
		var silo_contract: Dictionary = silo_contracts.get(silo_id, {})
		_silo_states[silo_id] = {
			"silo_id": silo_id,
			"world_position": silo_contract.get("world_position", Vector3.ZERO),
			"launch_world_position": silo_contract.get("launch_world_position", silo_contract.get("world_position", Vector3.ZERO)),
			"destroyed": false,
			"missiles_remaining": MISSILES_PER_SILO,
		}
	var silo_ids := _get_silo_ids()
	_selected_silo_index = maxi(silo_ids.find("silo_center"), 0)
	_ensure_selected_silo_is_valid()

func _seed_wave_rng() -> void:
	if _forced_wave_seed > 0:
		_session_wave_seed = _forced_wave_seed
	else:
		var seed_source := "%s:%d:%d" % [_active_venue_id, _session_serial + 1, Time.get_ticks_usec()]
		_session_wave_seed = seed_source.hash()
		if _session_wave_seed == 0:
			_session_wave_seed = 1
	_wave_rng.seed = _session_wave_seed

func _begin_wave(target_wave_index: int) -> void:
	if target_wave_index <= 0 or target_wave_index > WAVE_CONFIGS.size():
		return
	_wave_index = target_wave_index
	_wave_state = "spawning"
	_enemy_spawn_queue = _build_wave_spawn_queue(target_wave_index)
	_emit_feedback("第 %d 波来袭" % target_wave_index, "warning")

func _advance_live_session(delta: float, mounted_venue: Node3D) -> void:
	if _wave_state == "intermission":
		_wave_intermission_remaining_sec = maxf(_wave_intermission_remaining_sec - delta, 0.0)
		if _wave_intermission_remaining_sec <= 0.0:
			_begin_wave(_wave_index + 1)
	if _wave_state == "spawning" or _wave_state == "in_progress":
		_process_enemy_spawn_queue(delta)
		_update_enemy_tracks(delta)
		_update_interceptor_tracks(delta)
		_update_explosion_tracks(delta)
		_resolve_explosion_damage()
		_resolve_wave_completion()
	if _count_alive_cities() <= 0 and _wave_state != "defeat":
		_wave_state = "defeat"
		_enemy_spawn_queue.clear()
		_emit_feedback("城市全灭", "warning")
	_apply_camera_fov(mounted_venue)
	_update_reticle(mounted_venue)
	_refresh_hud_state()

func _process_enemy_spawn_queue(delta: float) -> void:
	if _enemy_spawn_queue.is_empty():
		if _wave_state == "spawning":
			_wave_state = "in_progress"
		return
	var remaining_queue: Array = []
	var spawned_any := false
	for queued_variant in _enemy_spawn_queue:
		var queued: Dictionary = (queued_variant as Dictionary).duplicate(true)
		var time_remaining := float(queued.get("spawn_after_sec", 0.0)) - delta
		if time_remaining > 0.0:
			queued["spawn_after_sec"] = time_remaining
			remaining_queue.append(queued)
			continue
		_spawn_enemy_track(queued)
		spawned_any = true
	_enemy_spawn_queue = remaining_queue
	if spawned_any:
		_wave_state = "in_progress"

func _spawn_enemy_track(queued: Dictionary) -> void:
	var target_world_position := _resolve_track_target_world_position(str(queued.get("target_kind", "city")), str(queued.get("target_id", "")))
	var start_world_position := queued.get("start_position", Vector3.ZERO) as Vector3
	var speed_mps := float(queued.get("speed_mps", 22.0))
	var duration_sec := maxf(start_world_position.distance_to(target_world_position) / maxf(speed_mps, 0.1), 0.2)
	_enemy_tracks.append({
		"track_id": str(queued.get("track_id", "")),
		"target_kind": str(queued.get("target_kind", "city")),
		"target_id": str(queued.get("target_id", "")),
		"start_position": start_world_position,
		"target_position": target_world_position,
		"current_position": start_world_position,
		"speed_mps": speed_mps,
		"duration_sec": duration_sec,
		"elapsed_sec": 0.0,
		"visual_radius_m": ENEMY_VISUAL_RADIUS_M,
		"recommended_intercept_world_position": start_world_position,
	})

func _update_enemy_tracks(delta: float) -> void:
	var live_tracks: Array = []
	for track_variant in _enemy_tracks:
		var track: Dictionary = (track_variant as Dictionary).duplicate(true)
		var elapsed_sec := float(track.get("elapsed_sec", 0.0)) + delta
		var duration_sec := maxf(float(track.get("duration_sec", 0.0)), 0.01)
		var progress := clampf(elapsed_sec / duration_sec, 0.0, 1.0)
		track["elapsed_sec"] = elapsed_sec
		track["current_position"] = (track.get("start_position", Vector3.ZERO) as Vector3).lerp(track.get("target_position", Vector3.ZERO) as Vector3, progress)
		if progress >= 1.0:
			_apply_enemy_impact(track)
			continue
		track["recommended_intercept_world_position"] = _resolve_recommended_intercept_world_position(track)
		live_tracks.append(track)
	_enemy_tracks = live_tracks

func _update_interceptor_tracks(delta: float) -> void:
	var live_tracks: Array = []
	for track_variant in _interceptor_tracks:
		var track: Dictionary = (track_variant as Dictionary).duplicate(true)
		var elapsed_sec := float(track.get("elapsed_sec", 0.0)) + delta
		var duration_sec := maxf(float(track.get("duration_sec", 0.0)), 0.01)
		var progress := clampf(elapsed_sec / duration_sec, 0.0, 1.0)
		track["elapsed_sec"] = elapsed_sec
		track["current_position"] = (track.get("start_position", Vector3.ZERO) as Vector3).lerp(track.get("target_position", Vector3.ZERO) as Vector3, progress)
		if progress >= 1.0:
			_spawn_explosion(track)
			continue
		live_tracks.append(track)
	_interceptor_tracks = live_tracks

func _update_explosion_tracks(delta: float) -> void:
	var live_tracks: Array = []
	for track_variant in _explosion_tracks:
		var track: Dictionary = (track_variant as Dictionary).duplicate(true)
		var elapsed_sec := float(track.get("elapsed_sec", 0.0)) + delta
		var duration_sec := maxf(float(track.get("duration_sec", 0.0)), 0.01)
		var progress := clampf(elapsed_sec / duration_sec, 0.0, 1.0)
		track["elapsed_sec"] = elapsed_sec
		track["progress"] = progress
		if progress >= 1.0:
			continue
		live_tracks.append(track)
	_explosion_tracks = live_tracks

func _resolve_explosion_damage() -> void:
	if _explosion_tracks.is_empty() or _enemy_tracks.is_empty():
		return
	var survivors: Array = []
	for track_variant in _enemy_tracks:
		var track: Dictionary = track_variant
		var destroyed := false
		for explosion_variant in _explosion_tracks:
			var explosion: Dictionary = explosion_variant
			var radius_m := float(explosion.get("radius_m", EXPLOSION_RADIUS_M))
			var explosion_position := explosion.get("world_position", Vector3.ZERO) as Vector3
			var distance_m := (track.get("current_position", Vector3.ZERO) as Vector3).distance_to(explosion_position)
			var lock_hit := str(explosion.get("locked_enemy_track_id", "")) == str(track.get("track_id", "")) and distance_m <= radius_m * 1.6
			if distance_m <= radius_m or lock_hit:
				destroyed = true
				break
		if destroyed:
			_destroyed_enemy_count += 1
			continue
		survivors.append(track)
	_enemy_tracks = survivors

func _spawn_explosion(interceptor_track: Dictionary) -> void:
	_explosion_spawn_count += 1
	_explosion_tracks.append({
		"track_id": "explosion_%d" % _explosion_spawn_count,
		"world_position": interceptor_track.get("target_position", Vector3.ZERO),
		"radius_m": EXPLOSION_RADIUS_M,
		"duration_sec": EXPLOSION_DURATION_SEC,
		"elapsed_sec": 0.0,
		"progress": 0.0,
		"locked_enemy_track_id": _resolve_enemy_track_id_for_target(interceptor_track.get("target_position", Vector3.ZERO) as Vector3),
	})

func _apply_enemy_impact(track: Dictionary) -> void:
	var target_kind := str(track.get("target_kind", "city"))
	var target_id := str(track.get("target_id", ""))
	if target_kind == "city":
		var city_state: Dictionary = (_city_states.get(target_id, {}) as Dictionary).duplicate(true)
		if not city_state.is_empty() and not bool(city_state.get("destroyed", false)):
			city_state["destroyed"] = true
			_city_states[target_id] = city_state
			_emit_feedback("%s 失守" % target_id.to_upper(), "warning")
		return
	var silo_state: Dictionary = (_silo_states.get(target_id, {}) as Dictionary).duplicate(true)
	if silo_state.is_empty():
		return
	if not bool(silo_state.get("destroyed", false)):
		silo_state["destroyed"] = true
		silo_state["missiles_remaining"] = 0
		_silo_states[target_id] = silo_state
		_emit_feedback("%s 被毁" % target_id.to_upper(), "warning")
		_ensure_selected_silo_is_valid()

func _resolve_wave_completion() -> void:
	if _wave_state == "victory" or _wave_state == "defeat":
		return
	if not _enemy_tracks.is_empty() or not _enemy_spawn_queue.is_empty() or not _interceptor_tracks.is_empty() or not _explosion_tracks.is_empty():
		return
	if _wave_index >= WAVE_CONFIGS.size():
		_wave_state = "victory"
		_emit_feedback("全部波次清除", "success")
		return
	_wave_state = "intermission"
	_wave_intermission_remaining_sec = WAVE_INTERMISSION_SEC
	_emit_feedback("准备第 %d 波" % (_wave_index + 1), "neutral")

func _build_wave_spawn_queue(target_wave_index: int) -> Array:
	var contract := _resolve_missile_command_contract()
	var plane_origin := contract.get("gameplay_plane_origin", Vector3.ZERO) as Vector3
	var plane_right := contract.get("gameplay_plane_right", Vector3.RIGHT) as Vector3
	var plane_up := contract.get("gameplay_plane_up", Vector3.UP) as Vector3
	var half_width_m := float(contract.get("gameplay_plane_half_width_m", 24.0))
	var plane_height_m := float(contract.get("gameplay_plane_height_m", 42.0))
	var city_ids := _get_city_ids()
	var silo_ids := _get_silo_ids()
	var config: Dictionary = WAVE_CONFIGS[target_wave_index - 1]
	var targets: Array[String] = []
	if target_wave_index == 1:
		targets.append_array(city_ids)
		targets.append("silo_center")
	elif target_wave_index == 2:
		targets.append_array(city_ids)
		targets.append_array(["silo_left", "silo_center", "city_center"])
	else:
		targets.append_array(city_ids)
		targets.append_array(["silo_left", "silo_center", "silo_right", "city_left", "city_right"])
	var pool: Array[String] = []
	pool.append_array(city_ids)
	if target_wave_index >= 2:
		pool.append_array(silo_ids)
	var queue: Array = []
	for index in range(int(config.get("enemy_count", 0))):
		var target_id := targets[index] if index < targets.size() else str(pool[_wave_rng.randi_range(0, pool.size() - 1)])
		var target_kind := "silo" if target_id.begins_with("silo_") else "city"
		var x_offset_m := _wave_rng.randf_range(-half_width_m * 0.92, half_width_m * 0.92)
		var y_offset_m := _wave_rng.randf_range(-2.6, 2.6)
		var start_world_position := plane_origin + plane_right * x_offset_m + plane_up * (plane_height_m * 0.5 + y_offset_m)
		queue.append({
			"track_id": "enemy_%d_%d" % [target_wave_index, index],
			"target_kind": target_kind,
			"target_id": target_id,
			"start_position": start_world_position,
			"speed_mps": float(config.get("enemy_speed_mps", 22.0)),
			"spawn_after_sec": float(config.get("spawn_interval_sec", 0.4)) * index,
		})
	return queue

func _resolve_recommended_intercept_world_position(enemy_track: Dictionary) -> Vector3:
	var selected_silo_id := _resolve_selected_silo_id()
	if selected_silo_id == "":
		return enemy_track.get("current_position", Vector3.ZERO) as Vector3
	var silo_state: Dictionary = _silo_states.get(selected_silo_id, {})
	var silo_world_position := silo_state.get("launch_world_position", Vector3.ZERO) as Vector3
	var current_position := enemy_track.get("current_position", Vector3.ZERO) as Vector3
	var target_position := enemy_track.get("target_position", current_position) as Vector3
	var remaining_duration_sec := maxf(float(enemy_track.get("duration_sec", 0.0)) - float(enemy_track.get("elapsed_sec", 0.0)), 0.0)
	if remaining_duration_sec <= 0.001:
		return current_position
	var enemy_velocity := (target_position - current_position) / remaining_duration_sec
	var intercept_time_sec := _solve_intercept_time(silo_world_position, current_position, enemy_velocity, INTERCEPTOR_SPEED_MPS)
	if intercept_time_sec <= 0.0:
		return current_position
	var contract := _resolve_missile_command_contract()
	return _clamp_world_position_to_gameplay_plane(current_position + enemy_velocity * intercept_time_sec, contract)

func _solve_intercept_time(origin: Vector3, target_position: Vector3, target_velocity: Vector3, interceptor_speed_mps: float) -> float:
	var r := target_position - origin
	var a := target_velocity.dot(target_velocity) - interceptor_speed_mps * interceptor_speed_mps
	var b := 2.0 * r.dot(target_velocity)
	var c := r.dot(r)
	if absf(a) <= 0.0001:
		if absf(b) <= 0.0001:
			return -1.0
		var linear_time := -c / b
		return linear_time if linear_time > 0.0 else -1.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var root := sqrt(discriminant)
	var t0 := (-b - root) / (2.0 * a)
	var t1 := (-b + root) / (2.0 * a)
	var best_time := INF
	for candidate in [t0, t1]:
		if candidate > 0.0 and candidate < best_time:
			best_time = candidate
	return best_time if best_time < INF else -1.0

func _update_reticle(mounted_venue: Node3D) -> void:
	var contract := _resolve_missile_command_contract(mounted_venue)
	if contract.is_empty():
		_reticle_world_position = Vector3.ZERO
		_reticle_screen_position = _resolve_viewport_size() * 0.5
		return
	var viewport := _resolve_viewport()
	var viewport_size := _resolve_viewport_size()
	var screen_position := viewport_size * 0.5
	if viewport != null and DisplayServer.get_name() != "headless":
		screen_position = viewport.get_mouse_position()
	_reticle_screen_position = screen_position
	var camera := _resolve_target_camera(mounted_venue)
	if camera == null:
		_reticle_world_position = contract.get("gameplay_plane_origin", Vector3.ZERO)
		return
	var plane_origin := contract.get("gameplay_plane_origin", Vector3.ZERO) as Vector3
	var plane_normal := contract.get("gameplay_plane_normal", Vector3.BACK) as Vector3
	var plane_right := contract.get("gameplay_plane_right", Vector3.RIGHT) as Vector3
	var plane_up := contract.get("gameplay_plane_up", Vector3.UP) as Vector3
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var denominator := plane_normal.dot(ray_direction)
	var world_position := plane_origin
	if absf(denominator) > 0.0001:
		var distance_along_ray := plane_normal.dot(plane_origin - ray_origin) / denominator
		if distance_along_ray > 0.0:
			world_position = ray_origin + ray_direction * distance_along_ray
	var offset := world_position - plane_origin
	var clamped_x := clampf(offset.dot(plane_right), -float(contract.get("gameplay_plane_half_width_m", 12.0)), float(contract.get("gameplay_plane_half_width_m", 12.0)))
	var clamped_y := clampf(offset.dot(plane_up), -float(contract.get("gameplay_plane_height_m", 24.0)) * 0.5, float(contract.get("gameplay_plane_height_m", 24.0)) * 0.5)
	_reticle_world_position = plane_origin + plane_right * clamped_x + plane_up * clamped_y

func _apply_camera_fov(mounted_venue: Node3D) -> void:
	var camera := _resolve_target_camera(mounted_venue)
	if camera == null:
		return
	camera.fov = ZOOM_CAMERA_FOV if _zoom_active else DEFAULT_CAMERA_FOV

func _update_battery_camera_pose(mounted_venue: Node3D) -> void:
	if mounted_venue == null:
		return
	var camera_pivot := _resolve_selected_silo_camera_pivot(mounted_venue)
	var look_target := _resolve_selected_silo_camera_look_target(mounted_venue)
	if camera_pivot == null or look_target == null:
		return
	var contract := _resolve_missile_command_contract(mounted_venue)
	if contract.is_empty():
		return
	var plane_up := contract.get("gameplay_plane_up", Vector3.UP) as Vector3
	var camera_world_position := camera_pivot.global_position
	var base_focus_world_position := look_target.global_position
	var forward := (base_focus_world_position - camera_world_position).normalized()
	if forward.length_squared() <= 0.0001:
		return
	forward = forward.rotated(plane_up, _camera_yaw_offset_rad)
	var pitch_axis := forward.cross(plane_up).normalized()
	if pitch_axis.length_squared() > 0.0001:
		forward = forward.rotated(pitch_axis, _camera_pitch_offset_rad)
	camera_pivot.look_at(camera_world_position + forward * 120.0, plane_up, true)

func _activate_battery_camera(mounted_venue: Node3D) -> void:
	if mounted_venue == null:
		return
	_set_silo_camera_activation(mounted_venue, _resolve_selected_silo_id())
	_apply_camera_fov(mounted_venue)
	if _last_player != null and is_instance_valid(_last_player):
		var player_camera := _last_player.get_node_or_null("CameraRig/Camera3D") as Camera3D
		if player_camera != null:
			player_camera.current = false
	if DisplayServer.get_name() != "headless":
		_previous_mouse_mode = Input.mouse_mode
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _restore_player_camera() -> void:
	if _last_mounted_venue != null and is_instance_valid(_last_mounted_venue):
		_set_silo_camera_activation(_last_mounted_venue, "")
	if _last_player != null and is_instance_valid(_last_player):
		var player_camera := _last_player.get_node_or_null("CameraRig/Camera3D") as Camera3D
		if player_camera != null:
			player_camera.current = true
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(_previous_mouse_mode)

func _resolve_target_camera(mounted_venue: Node3D) -> Camera3D:
	var selected_camera := _resolve_selected_silo_camera(mounted_venue)
	if selected_camera != null:
		return selected_camera
	if _last_player != null and is_instance_valid(_last_player):
		var player_camera := _last_player.get_node_or_null("CameraRig/Camera3D") as Camera3D
		if player_camera != null:
			return player_camera
	return null

func _resolve_selected_silo_camera(mounted_venue: Node3D) -> Camera3D:
	if mounted_venue == null or not mounted_venue.has_method("get_silo_camera"):
		return null
	return mounted_venue.get_silo_camera(_resolve_selected_silo_id()) as Camera3D

func _resolve_selected_silo_camera_pivot(mounted_venue: Node3D) -> Node3D:
	if mounted_venue == null or not mounted_venue.has_method("get_silo_camera_pivot"):
		return null
	return mounted_venue.get_silo_camera_pivot(_resolve_selected_silo_id()) as Node3D

func _resolve_selected_silo_camera_look_target(mounted_venue: Node3D) -> Node3D:
	if mounted_venue == null or not mounted_venue.has_method("get_silo_camera_look_target"):
		return null
	return mounted_venue.get_silo_camera_look_target(_resolve_selected_silo_id()) as Node3D

func _set_silo_camera_activation(mounted_venue: Node3D, active_silo_id: String) -> void:
	if mounted_venue == null or not mounted_venue.has_method("get_silo_camera"):
		return
	var silo_ids := _get_silo_ids()
	if silo_ids.is_empty():
		silo_ids = ["silo_left", "silo_center", "silo_right"]
	for silo_id_variant in silo_ids:
		var silo_id := str(silo_id_variant)
		var silo_camera := mounted_venue.get_silo_camera(silo_id) as Camera3D
		if silo_camera == null:
			continue
		silo_camera.current = silo_id == active_silo_id

func _sync_venue_state(mounted_venue: Node3D) -> void:
	if mounted_venue == null or not mounted_venue.has_method("sync_battery_state"):
		return
	mounted_venue.sync_battery_state({
		"start_ring_visible": not _battery_mode_active,
		"wave_index": _wave_index,
		"wave_total": WAVE_CONFIGS.size(),
		"wave_state": _wave_state,
		"selected_silo_id": _resolve_selected_silo_id(),
		"selected_silo_missiles_remaining": _resolve_selected_silo_missiles_remaining(),
		"cities_alive_count": _count_alive_cities(),
		"enemy_remaining_count": _enemy_tracks.size() + _enemy_spawn_queue.size(),
		"feedback_event_text": _feedback_event_text,
		"city_states": _city_states.duplicate(true),
		"silo_states": _silo_states.duplicate(true),
		"enemy_tracks": _enemy_tracks.duplicate(true),
		"interceptor_tracks": _interceptor_tracks.duplicate(true),
		"explosion_tracks": _explosion_tracks.duplicate(true),
	})

func _refresh_hud_state() -> void:
	_hud_state = {
		"visible": _battery_mode_active,
		"wave_index": _wave_index,
		"wave_total": WAVE_CONFIGS.size(),
		"wave_state": _wave_state,
		"selected_silo_id": _resolve_selected_silo_id(),
		"selected_silo_missiles_remaining": _resolve_selected_silo_missiles_remaining(),
		"cities_alive_count": _count_alive_cities(),
		"enemy_remaining_count": _enemy_tracks.size() + _enemy_spawn_queue.size(),
		"zoom_active": _zoom_active,
		"feedback_event_token": _feedback_event_token,
		"feedback_event_text": _feedback_event_text,
		"feedback_event_tone": _feedback_event_tone,
	}

func _emit_feedback(text: String, tone: String = "neutral") -> void:
	var resolved_text := text.strip_edges()
	if resolved_text == "":
		return
	_feedback_event_token += 1
	_feedback_event_text = resolved_text
	_feedback_event_tone = tone

func _resolve_track_target_world_position(target_kind: String, target_id: String) -> Vector3:
	if target_kind == "silo":
		var silo_state: Dictionary = _silo_states.get(target_id, {})
		return silo_state.get("world_position", Vector3.ZERO)
	var city_state: Dictionary = _city_states.get(target_id, {})
	return city_state.get("world_position", Vector3.ZERO)

func _resolve_enemy_track_id_for_target(target_world_position: Vector3) -> String:
	var best_track_id := ""
	var best_distance_m := INF
	for track_variant in _enemy_tracks:
		var track: Dictionary = track_variant
		var distance_m := (track.get("current_position", Vector3.ZERO) as Vector3).distance_to(target_world_position)
		if distance_m < best_distance_m:
			best_distance_m = distance_m
			best_track_id = str(track.get("track_id", ""))
	return best_track_id

func _ensure_selected_silo_is_valid() -> void:
	var silo_ids := _get_silo_ids()
	if silo_ids.is_empty():
		_selected_silo_index = 0
		return
	var selected_silo_id := _resolve_selected_silo_id()
	if selected_silo_id != "":
		var state: Dictionary = _silo_states.get(selected_silo_id, {})
		if not bool(state.get("destroyed", false)) and int(state.get("missiles_remaining", 0)) > 0:
			return
	for index in range(silo_ids.size()):
		var candidate_id := str(silo_ids[index])
		var candidate_state: Dictionary = _silo_states.get(candidate_id, {})
		if bool(candidate_state.get("destroyed", false)):
			continue
		if int(candidate_state.get("missiles_remaining", 0)) <= 0:
			continue
		_selected_silo_index = index
		return

func _resolve_selected_silo_id() -> String:
	var silo_ids := _get_silo_ids()
	if silo_ids.is_empty():
		return ""
	var clamped_index := clampi(_selected_silo_index, 0, silo_ids.size() - 1)
	return str(silo_ids[clamped_index])

func _resolve_selected_silo_missiles_remaining() -> int:
	var selected_silo_id := _resolve_selected_silo_id()
	if selected_silo_id == "":
		return 0
	return int((_silo_states.get(selected_silo_id, {}) as Dictionary).get("missiles_remaining", 0))

func _count_alive_cities() -> int:
	var alive_count := 0
	for city_state_variant in _city_states.values():
		var city_state: Dictionary = city_state_variant
		if not bool(city_state.get("destroyed", false)):
			alive_count += 1
	return alive_count

func _get_silo_ids() -> Array[String]:
	var contract := _resolve_missile_command_contract()
	var silo_ids: Array[String] = []
	for silo_id_variant in contract.get("silo_ids", []):
		silo_ids.append(str(silo_id_variant))
	return silo_ids

func _get_city_ids() -> Array[String]:
	var contract := _resolve_missile_command_contract()
	var city_ids: Array[String] = []
	for city_id_variant in contract.get("city_ids", []):
		city_ids.append(str(city_id_variant))
	return city_ids

func _resolve_viewport() -> Viewport:
	if _last_mounted_venue != null and is_instance_valid(_last_mounted_venue):
		return _last_mounted_venue.get_viewport()
	if _last_player != null and is_instance_valid(_last_player):
		return _last_player.get_viewport()
	return null

func _resolve_viewport_size() -> Vector2:
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	var viewport := _resolve_viewport()
	if viewport != null:
		var visible_rect := viewport.get_visible_rect()
		if visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0:
			viewport_size = visible_rect.size
	return viewport_size

func _resolve_missile_command_contract(venue_override: Node3D = null) -> Dictionary:
	var venue := venue_override if venue_override != null else _last_mounted_venue
	if venue == null or not is_instance_valid(venue) or not venue.has_method("get_missile_command_contract"):
		return {}
	return venue.get_missile_command_contract()

func _clamp_world_position_to_gameplay_plane(world_position: Vector3, contract: Dictionary) -> Vector3:
	var plane_origin := contract.get("gameplay_plane_origin", Vector3.ZERO) as Vector3
	var plane_right := contract.get("gameplay_plane_right", Vector3.RIGHT) as Vector3
	var plane_up := contract.get("gameplay_plane_up", Vector3.UP) as Vector3
	var offset := world_position - plane_origin
	var clamped_x := clampf(offset.dot(plane_right), -float(contract.get("gameplay_plane_half_width_m", 12.0)), float(contract.get("gameplay_plane_half_width_m", 12.0)))
	var clamped_y := clampf(offset.dot(plane_up), -float(contract.get("gameplay_plane_height_m", 24.0)) * 0.5, float(contract.get("gameplay_plane_height_m", 24.0)) * 0.5)
	return plane_origin + plane_right * clamped_x + plane_up * clamped_y

func _resolve_active_entry() -> Dictionary:
	if _active_venue_id == "":
		return {}
	return (_entries_by_venue_id.get(_active_venue_id, {}) as Dictionary).duplicate(true)

func _resolve_mounted_venue(chunk_renderer: Node, entry: Dictionary) -> Node3D:
	if chunk_renderer == null or not chunk_renderer.has_method("find_scene_minigame_venue_node"):
		return null
	var venue_id := str(entry.get("venue_id", "")).strip_edges()
	if venue_id == "":
		return null
	return chunk_renderer.find_scene_minigame_venue_node(venue_id) as Node3D

func _is_player_near_active_venue(entry: Dictionary, player_node: Node3D) -> bool:
	if player_node == null or not is_instance_valid(player_node):
		return false
	return player_node.global_position.distance_squared_to(_resolve_entry_world_position(entry)) <= ACTIVE_VENUE_SCAN_RADIUS_M * ACTIVE_VENUE_SCAN_RADIUS_M

func _resolve_entry_world_position(entry: Dictionary) -> Vector3:
	var world_position_variant: Variant = entry.get("world_position", Vector3.ZERO)
	if world_position_variant is Vector3:
		return world_position_variant as Vector3
	return Vector3.ZERO
