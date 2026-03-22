extends RefCounted

const ACTIVE_VENUE_SCAN_RADIUS_M := 768.0
const CAST_TO_BITE_DELAY_SEC := 1.2
const BITE_WINDOW_DURATION_SEC := 1.4
const CAST_STATE_IDLE := "idle"
const CAST_STATE_SEATED := "seated"
const CAST_STATE_CAST_OUT := "cast_out"
const CAST_STATE_BITE_WINDOW := "bite_window"
const CAST_STATE_CATCH_RESOLVED := "catch_resolved"
const CAST_STATE_MISSED := "missed"

var _entries_by_venue_id: Dictionary = {}
var _active_venue_id := ""
var _terrain_region_runtime = null
var _direct_lake_runtime = null
var _fish_school_runtime = null
var _fishing_mode_active := false
var _active_seat_id := ""
var _cast_state := CAST_STATE_IDLE
var _target_school_id := ""
var _bite_window_active := false
var _ambient_simulation_frozen := false
var _last_catch_result: Dictionary = {}
var _state_timer_sec := 0.0
var _hud_state: Dictionary = {}
var _last_chunk_renderer: Node = null
var _last_player: Node3D = null
var _last_mounted_venue: Node3D = null

func configure(entries: Dictionary) -> void:
	_entries_by_venue_id.clear()
	var sorted_ids: Array[String] = []
	for venue_id_variant in entries.keys():
		var venue_id := str(venue_id_variant).strip_edges()
		if venue_id == "":
			continue
		var entry: Dictionary = (entries.get(venue_id, {}) as Dictionary).duplicate(true)
		if str(entry.get("game_kind", "")) != "lakeside_fishing":
			continue
		_entries_by_venue_id[venue_id] = entry
		sorted_ids.append(venue_id)
	sorted_ids.sort()
	if _active_venue_id == "" or not _entries_by_venue_id.has(_active_venue_id):
		_active_venue_id = sorted_ids[0] if not sorted_ids.is_empty() else ""
	_reset_runtime_state(false)

func set_lake_context(terrain_region_runtime, fish_school_runtime) -> void:
	_terrain_region_runtime = terrain_region_runtime if terrain_region_runtime != null and terrain_region_runtime.has_method("get_lake_runtime") else null
	_direct_lake_runtime = terrain_region_runtime if terrain_region_runtime != null and terrain_region_runtime.has_method("sample_depth_at_world_position") else null
	_fish_school_runtime = fish_school_runtime

func update(chunk_renderer: Node, player_node: Node3D, delta: float) -> Dictionary:
	_last_chunk_renderer = chunk_renderer
	_last_player = player_node
	var entry := _resolve_active_entry()
	if entry.is_empty():
		_handle_unavailable_runtime(false)
		return _build_runtime_tick_summary()
	if not _is_player_near_active_venue(entry, player_node):
		_handle_unavailable_runtime(false)
		return _build_runtime_tick_summary()
	var mounted_venue := _resolve_mounted_venue(chunk_renderer, entry)
	return _update_with_venue(entry, mounted_venue, player_node, delta)

func update_direct(venue_node: Node3D, player_node: Node3D, delta: float) -> Dictionary:
	_last_player = player_node
	var entry := _resolve_entry_for_venue(venue_node)
	return _update_with_venue(entry, venue_node, player_node, delta)

func get_state() -> Dictionary:
	return {
		"active_venue_id": _active_venue_id,
		"venue_entry_count": _entries_by_venue_id.size(),
		"fishing_mode_active": _fishing_mode_active,
		"active_seat_id": _active_seat_id,
		"cast_state": _cast_state,
		"target_school_id": _target_school_id,
		"bite_window_active": _bite_window_active,
		"ambient_simulation_frozen": _ambient_simulation_frozen,
		"last_catch_result": _last_catch_result.duplicate(true),
		"match_hud_state": _hud_state.duplicate(true),
	}

func get_match_hud_state() -> Dictionary:
	return _hud_state.duplicate(true)

func is_ambient_simulation_frozen() -> bool:
	return _ambient_simulation_frozen

func get_primary_interaction_state(player_node: Node3D = null) -> Dictionary:
	var resolved_player := player_node if player_node != null else _last_player
	var venue := _last_mounted_venue
	var entry := _resolve_active_entry()
	if venue == null or not is_instance_valid(venue):
		return _build_hidden_prompt_state()
	if entry.is_empty():
		entry = _resolve_entry_for_venue(venue)
	return _build_primary_interaction_state(entry, venue, resolved_player)

func handle_primary_interaction(chunk_renderer: Node, player_node: Node3D) -> Dictionary:
	var entry := _resolve_active_entry()
	if entry.is_empty():
		return {"handled": false, "success": false, "error": "missing_entry"}
	var venue := _resolve_mounted_venue(chunk_renderer, entry)
	return handle_primary_interaction_direct(venue, player_node)

func handle_primary_interaction_direct(venue: Node3D, player_node: Node3D) -> Dictionary:
	var entry := _resolve_entry_for_venue(venue)
	if entry.is_empty():
		return {"handled": false, "success": false, "error": "missing_entry"}
	if venue == null or not is_instance_valid(venue):
		return {"handled": false, "success": false, "error": "missing_venue"}
	if player_node == null or not is_instance_valid(player_node):
		return {"handled": true, "success": false, "error": "missing_player"}
	var interaction_state := _build_primary_interaction_state(entry, venue, player_node)
	if not bool(interaction_state.get("visible", false)) and not _fishing_mode_active:
		return {"handled": false, "success": false, "error": "interaction_unavailable"}
	match _cast_state:
		CAST_STATE_IDLE:
			if not venue.has_method("is_world_point_in_match_start_ring") or not bool(venue.is_world_point_in_match_start_ring(player_node.global_position)):
				return {"handled": false, "success": false, "error": "outside_start_ring"}
			_begin_fishing_mode(entry, venue, player_node)
			return _build_handled_result(true, "seat_entered")
		CAST_STATE_SEATED:
			_start_cast(entry, venue)
			return _build_handled_result(true, "cast_started")
		CAST_STATE_CAST_OUT:
			return _build_handled_result(false, "bite_pending")
		CAST_STATE_BITE_WINDOW:
			_resolve_catch(entry, venue)
			return _build_handled_result(true, "catch_resolved")
		CAST_STATE_CATCH_RESOLVED, CAST_STATE_MISSED:
			_reset_runtime_state(true)
			_sync_venue_state(venue)
			return _build_handled_result(true, "session_reset")
		_:
			return _build_handled_result(false, "unsupported_state")

func reset_runtime_state(release_player: bool = true) -> void:
	_reset_runtime_state(release_player)

func _update_with_venue(entry: Dictionary, venue: Node3D, player_node: Node3D, delta: float) -> Dictionary:
	_last_mounted_venue = venue
	if venue != null and is_instance_valid(venue):
		entry = _resolve_entry_for_venue(venue)
	if entry.is_empty() or venue == null or not is_instance_valid(venue):
		_handle_unavailable_runtime(false)
		return _build_runtime_tick_summary()
	if _fishing_mode_active and player_node != null and is_instance_valid(player_node):
		var in_release_bounds := venue.has_method("is_world_point_in_release_bounds") and bool(venue.is_world_point_in_release_bounds(player_node.global_position))
		if not in_release_bounds:
			_reset_runtime_state(true)
			_update_ambient_freeze(player_node, venue)
			_sync_venue_state(venue)
			_refresh_hud_state(venue)
			return _build_runtime_tick_summary()
	_update_ambient_freeze(player_node, venue)
	if _fishing_mode_active and player_node != null and is_instance_valid(player_node):
		_apply_player_to_seat(player_node, venue, _active_seat_id)
	_advance_session_timer(maxf(delta, 0.0))
	_sync_venue_state(venue)
	_refresh_hud_state(venue)
	return _build_runtime_tick_summary()

func _advance_session_timer(delta: float) -> void:
	if _cast_state != CAST_STATE_CAST_OUT and _cast_state != CAST_STATE_BITE_WINDOW:
		return
	_state_timer_sec = maxf(_state_timer_sec - delta, 0.0)
	if _state_timer_sec > 0.0:
		return
	if _cast_state == CAST_STATE_CAST_OUT:
		_cast_state = CAST_STATE_BITE_WINDOW
		_bite_window_active = true
		_state_timer_sec = BITE_WINDOW_DURATION_SEC
		_refresh_hud_state(_last_mounted_venue)
		return
	if _cast_state == CAST_STATE_BITE_WINDOW:
		_cast_state = CAST_STATE_MISSED
		_bite_window_active = false
		_last_catch_result = {
			"result": "miss",
			"school_id": _target_school_id,
		}
		_refresh_hud_state(_last_mounted_venue)

func _update_ambient_freeze(player_node: Node3D, venue: Node3D) -> void:
	if player_node == null or not is_instance_valid(player_node) or venue == null:
		_ambient_simulation_frozen = false
		return
	var player_world_position := player_node.global_position
	var in_play_bounds := venue.has_method("is_world_point_in_play_bounds") and bool(venue.is_world_point_in_play_bounds(player_world_position))
	if in_play_bounds or _fishing_mode_active:
		_ambient_simulation_frozen = true
		return
	var in_release_bounds := venue.has_method("is_world_point_in_release_bounds") and bool(venue.is_world_point_in_release_bounds(player_world_position))
	if not in_release_bounds:
		_ambient_simulation_frozen = false

func _begin_fishing_mode(_entry: Dictionary, venue: Node3D, player_node: Node3D) -> void:
	var contract: Dictionary = venue.get_fishing_contract() if venue.has_method("get_fishing_contract") else {}
	var seat_anchor_ids: Array = contract.get("seat_anchor_ids", [])
	_fishing_mode_active = true
	_active_seat_id = str(seat_anchor_ids[0]) if not seat_anchor_ids.is_empty() else ""
	_cast_state = CAST_STATE_SEATED
	_target_school_id = ""
	_bite_window_active = false
	_last_catch_result.clear()
	_state_timer_sec = 0.0
	_apply_player_to_seat(player_node, venue, _active_seat_id)
	_sync_venue_state(venue)
	_refresh_hud_state(venue)

func _start_cast(entry: Dictionary, venue: Node3D) -> void:
	_cast_state = CAST_STATE_CAST_OUT
	_target_school_id = _resolve_target_school_id(entry, venue)
	_bite_window_active = false
	_last_catch_result.clear()
	_state_timer_sec = CAST_TO_BITE_DELAY_SEC
	_sync_venue_state(venue)
	_refresh_hud_state(venue)

func _resolve_catch(entry: Dictionary, venue: Node3D) -> void:
	var target_school_id := _resolve_target_school_id(entry, venue)
	if target_school_id != "":
		_target_school_id = target_school_id
	_cast_state = CAST_STATE_CATCH_RESOLVED
	_bite_window_active = false
	_state_timer_sec = 0.0
	_last_catch_result = {
		"result": "caught",
		"school_id": _target_school_id,
	}
	_sync_venue_state(venue)
	_refresh_hud_state(venue)

func _refresh_hud_state(venue: Node3D = null) -> void:
	var venue_contract: Dictionary = venue.get_fishing_contract() if venue != null and is_instance_valid(venue) and venue.has_method("get_fishing_contract") else {}
	_hud_state = {
		"visible": _fishing_mode_active,
		"fishing_mode_active": _fishing_mode_active,
		"cast_state": _cast_state,
		"bite_window_active": _bite_window_active,
		"target_school_id": _target_school_id,
		"last_catch_result": _last_catch_result.duplicate(true),
		"active_seat_id": _active_seat_id,
		"display_name": str(venue_contract.get("display_name", "Lakeside Fishing")),
	}

func _build_primary_interaction_state(entry: Dictionary, venue: Node3D, player_node: Node3D) -> Dictionary:
	if player_node == null or not is_instance_valid(player_node) or venue == null or not is_instance_valid(venue):
		return _build_hidden_prompt_state()
	var start_contract: Dictionary = venue.get_match_start_contract() if venue.has_method("get_match_start_contract") else {}
	var prompt_world_position: Vector3 = start_contract.get("world_position", _resolve_entry_world_position(entry))
	var distance_m := player_node.global_position.distance_to(prompt_world_position)
	match _cast_state:
		CAST_STATE_IDLE:
			var in_ring := venue.has_method("is_world_point_in_match_start_ring") and bool(venue.is_world_point_in_match_start_ring(player_node.global_position))
			if not in_ring:
				return _build_hidden_prompt_state()
			return {
				"visible": true,
				"owner_kind": "fishing_venue",
				"venue_id": str(entry.get("venue_id", "")),
				"prompt_text": "按 E 坐下钓鱼",
				"distance_m": distance_m,
			}
		CAST_STATE_SEATED:
			return {
				"visible": true,
				"owner_kind": "fishing_venue",
				"venue_id": str(entry.get("venue_id", "")),
				"prompt_text": "按 E 抛竿",
				"distance_m": distance_m,
			}
		CAST_STATE_BITE_WINDOW:
			return {
				"visible": true,
				"owner_kind": "fishing_venue",
				"venue_id": str(entry.get("venue_id", "")),
				"prompt_text": "按 E 收线",
				"distance_m": distance_m,
			}
		CAST_STATE_CATCH_RESOLVED, CAST_STATE_MISSED:
			return {
				"visible": true,
				"owner_kind": "fishing_venue",
				"venue_id": str(entry.get("venue_id", "")),
				"prompt_text": "按 E 收竿重置",
				"distance_m": distance_m,
			}
		_:
			return _build_hidden_prompt_state()

func _build_hidden_prompt_state() -> Dictionary:
	return {
		"visible": false,
		"owner_kind": "fishing_venue",
		"venue_id": _active_venue_id,
		"prompt_text": "",
		"distance_m": 0.0,
	}

func _build_handled_result(success: bool, action: String) -> Dictionary:
	return {
		"handled": true,
		"success": success,
		"owner_kind": "fishing_venue",
		"interaction_kind": "lakeside_fishing",
		"action": action,
		"venue_id": _active_venue_id,
		"cast_state": _cast_state,
		"target_school_id": _target_school_id,
		"last_catch_result": _last_catch_result.duplicate(true),
	}

func _build_runtime_tick_summary() -> Dictionary:
	return {
		"ambient_simulation_frozen": _ambient_simulation_frozen,
		"match_hud_state": _hud_state,
	}

func _apply_player_to_seat(player_node: Node3D, venue: Node3D, seat_id: String) -> void:
	if player_node == null or not is_instance_valid(player_node) or venue == null or not venue.has_method("get_seat_anchor"):
		return
	var seat_anchor: Dictionary = venue.get_seat_anchor(seat_id)
	var seat_world_position: Vector3 = seat_anchor.get("world_position", player_node.global_position)
	if player_node.has_method("set_movement_locked"):
		player_node.set_movement_locked(true)
	if player_node.has_method("teleport_to_world_position"):
		player_node.teleport_to_world_position(seat_world_position + Vector3.UP * _estimate_standing_height(player_node))
	else:
		player_node.global_position = seat_world_position + Vector3.UP * _estimate_standing_height(player_node)
	var cast_origin: Dictionary = venue.get_cast_origin_anchor() if venue.has_method("get_cast_origin_anchor") else {}
	var cast_world_position: Vector3 = cast_origin.get("world_position", seat_world_position + Vector3.FORWARD)
	var look_delta := cast_world_position - seat_world_position
	look_delta.y = 0.0
	if look_delta.length_squared() > 0.0001:
		player_node.rotation.y = atan2(-look_delta.x, -look_delta.z)

func _estimate_standing_height(player_node: Node3D) -> float:
	var collision_shape := player_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0

func _handle_unavailable_runtime(reset_session: bool) -> void:
	if reset_session:
		_reset_runtime_state(true)
	_ambient_simulation_frozen = false
	_refresh_hud_state()

func _reset_runtime_state(release_player: bool) -> void:
	if release_player and _last_player != null and is_instance_valid(_last_player) and _last_player.has_method("set_movement_locked"):
		_last_player.set_movement_locked(false)
	_fishing_mode_active = false
	_active_seat_id = ""
	_cast_state = CAST_STATE_IDLE
	_target_school_id = ""
	_bite_window_active = false
	_last_catch_result.clear()
	_state_timer_sec = 0.0
	_refresh_hud_state()

func _resolve_target_school_id(entry: Dictionary, venue: Node3D) -> String:
	var region_id := str(entry.get("linked_region_id", "")).strip_edges()
	if region_id == "" or _fish_school_runtime == null or not _fish_school_runtime.has_method("get_school_summaries_for_region"):
		return ""
	var target_position := Vector3.ZERO
	if venue != null and is_instance_valid(venue):
		if venue.has_method("get_bite_zone"):
			var bite_zone: Dictionary = venue.get_bite_zone()
			target_position = bite_zone.get("world_position", Vector3.ZERO)
		if target_position == Vector3.ZERO and venue.has_method("get_cast_origin_anchor"):
			var cast_origin: Dictionary = venue.get_cast_origin_anchor()
			target_position = cast_origin.get("world_position", Vector3.ZERO)
	var schools: Array = _fish_school_runtime.get_school_summaries_for_region(region_id)
	var best_school_id := ""
	var best_distance_sq := INF
	for school_variant in schools:
		if not (school_variant is Dictionary):
			continue
		var school: Dictionary = school_variant
		var school_world_position: Variant = school.get("world_position", Vector3.ZERO)
		if not (school_world_position is Vector3):
			continue
		var school_position := school_world_position as Vector3
		var distance_sq := school_position.distance_squared_to(target_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_school_id = str(school.get("school_id", ""))
	return best_school_id

func _resolve_entry_for_venue(venue: Node3D) -> Dictionary:
	var entry := _resolve_active_entry()
	if venue == null or not is_instance_valid(venue) or not venue.has_method("get_fishing_contract"):
		return entry
	var contract: Dictionary = venue.get_fishing_contract()
	var venue_id := str(contract.get("venue_id", "")).strip_edges()
	if venue_id == "":
		return entry
	var merged_entry: Dictionary = contract.duplicate(true)
	for key_variant in entry.keys():
		var key := str(key_variant)
		if merged_entry.has(key):
			continue
		merged_entry[key] = entry.get(key_variant)
	_entries_by_venue_id[venue_id] = merged_entry.duplicate(true)
	_active_venue_id = venue_id
	return merged_entry

func _resolve_active_entry() -> Dictionary:
	if _active_venue_id == "":
		var sorted_ids: Array[String] = []
		for venue_id_variant in _entries_by_venue_id.keys():
			sorted_ids.append(str(venue_id_variant))
		sorted_ids.sort()
		_active_venue_id = sorted_ids[0] if not sorted_ids.is_empty() else ""
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

func _sync_venue_state(venue: Node3D) -> void:
	if venue == null or not is_instance_valid(venue) or not venue.has_method("sync_fishing_state"):
		return
	venue.sync_fishing_state({
		"start_ring_visible": not _fishing_mode_active,
		"fishing_mode_active": _fishing_mode_active,
		"active_seat_id": _active_seat_id,
		"cast_state": _cast_state,
		"target_school_id": _target_school_id,
		"bite_window_active": _bite_window_active,
		"last_catch_result": _last_catch_result.duplicate(true),
	})
