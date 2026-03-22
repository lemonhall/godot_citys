extends RefCounted

const ACTIVE_VENUE_SCAN_RADIUS_M := 768.0
const BITE_WAIT_MIN_SEC := 0.0
const BITE_WAIT_MAX_SEC := 30.0
const CAST_STATE_IDLE := "idle"
const CAST_STATE_EQUIPPED := "equipped"
const CAST_STATE_CAST_OUT := "cast_out"
const CAST_STATE_BITE_READY := "bite_ready"

var _entries_by_venue_id: Dictionary = {}
var _active_venue_id := ""
var _terrain_region_runtime = null
var _direct_lake_runtime = null
var _fish_school_runtime = null
var _rng := RandomNumberGenerator.new()
var _fishing_mode_active := false
var _pole_equipped := false
var _cast_state := CAST_STATE_IDLE
var _cast_preview_active := false
var _preview_landing_world_position := Vector3.ZERO
var _target_school_id := ""
var _bobber_visible := false
var _bobber_world_position := Vector3.ZERO
var _bobber_bite_feedback_active := false
var _fishing_line_visible := false
var _line_start_world_position := Vector3.ZERO
var _last_catch_result: Dictionary = {}
var _bite_wait_remaining_sec := 0.0
var _debug_bite_delay_override_sec := -1.0
var _feedback_event_token := 0
var _feedback_event_text := ""
var _feedback_event_tone := "neutral"
var _hud_state: Dictionary = {}
var _ambient_simulation_frozen := false
var _last_chunk_renderer: Node = null
var _last_player: Node3D = null
var _last_mounted_venue: Node3D = null

func _init() -> void:
	_rng.seed = 3838

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
		_handle_unavailable_runtime(_pole_equipped)
		return _build_runtime_tick_summary()
	if not _is_player_near_active_venue(entry, player_node):
		_handle_unavailable_runtime(_pole_equipped)
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
		"pole_equipped": _pole_equipped,
		"cast_state": _cast_state,
		"cast_preview_active": _cast_preview_active,
		"preview_landing_world_position": _preview_landing_world_position,
		"target_school_id": _target_school_id,
		"bobber_visible": _bobber_visible,
		"bobber_world_position": _bobber_world_position,
		"bobber_bite_feedback_active": _bobber_bite_feedback_active,
		"fishing_line_visible": _fishing_line_visible,
		"line_start_world_position": _line_start_world_position,
		"bite_wait_remaining_sec": _bite_wait_remaining_sec,
		"ambient_simulation_frozen": _ambient_simulation_frozen,
		"last_catch_result": _last_catch_result.duplicate(true),
		"feedback_event_token": _feedback_event_token,
		"feedback_event_text": _feedback_event_text,
		"feedback_event_tone": _feedback_event_tone,
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
	if _pole_equipped:
		_reset_runtime_state(true)
		_sync_venue_state(venue)
		_refresh_hud_state(venue)
		_publish_feedback("鱼竿已放回原位", "neutral")
		return _build_handled_result(true, "pole_stowed")
	var interaction_state := _build_primary_interaction_state(entry, venue, player_node)
	if not bool(interaction_state.get("visible", false)):
		return {"handled": false, "success": false, "error": "interaction_unavailable"}
	_fishing_mode_active = true
	_pole_equipped = true
	_cast_state = CAST_STATE_EQUIPPED
	_cast_preview_active = false
	_preview_landing_world_position = Vector3.ZERO
	_target_school_id = ""
	_bobber_visible = false
	_bobber_bite_feedback_active = false
	_fishing_line_visible = false
	_bobber_world_position = Vector3.ZERO
	_line_start_world_position = _resolve_line_start_world_position(player_node, venue)
	_last_catch_result.clear()
	_bite_wait_remaining_sec = 0.0
	_publish_feedback("已拿起鱼竿", "action")
	_sync_venue_state(venue)
	_refresh_hud_state(venue)
	return _build_handled_result(true, "pole_equipped")

func set_cast_preview_active(chunk_renderer: Node, player_node: Node3D, active: bool, preview_state: Dictionary = {}) -> Dictionary:
	var entry := _resolve_active_entry()
	if entry.is_empty():
		return {"success": false, "error": "missing_entry"}
	var venue := _resolve_mounted_venue(chunk_renderer, entry)
	return set_cast_preview_active_direct(venue, player_node, active, preview_state)

func set_cast_preview_active_direct(venue: Node3D, player_node: Node3D, active: bool, preview_state: Dictionary = {}) -> Dictionary:
	var entry := _resolve_entry_for_venue(venue)
	if entry.is_empty():
		return {"success": false, "error": "missing_entry"}
	if venue == null or not is_instance_valid(venue):
		return {"success": false, "error": "missing_venue"}
	if player_node == null or not is_instance_valid(player_node):
		return {"success": false, "error": "missing_player"}
	if not active:
		_cast_preview_active = false
		_preview_landing_world_position = Vector3.ZERO
		_sync_venue_state(venue)
		_refresh_hud_state(venue)
		return _build_action_result(true, "preview_cleared")
	if not _pole_equipped or _cast_state != CAST_STATE_EQUIPPED:
		return _build_action_result(false, "preview_unavailable", "preview_unavailable")
	_cast_preview_active = true
	_preview_landing_world_position = _resolve_preview_landing_world_position(preview_state, venue)
	_sync_venue_state(venue)
	_refresh_hud_state(venue)
	return _build_action_result(true, "preview_ready")

func request_cast_action(chunk_renderer: Node, player_node: Node3D, preview_state: Dictionary = {}) -> Dictionary:
	var entry := _resolve_active_entry()
	if entry.is_empty():
		return {"success": false, "error": "missing_entry"}
	var venue := _resolve_mounted_venue(chunk_renderer, entry)
	return request_cast_action_direct(venue, player_node, preview_state)

func request_cast_action_direct(venue: Node3D, player_node: Node3D, preview_state: Dictionary = {}) -> Dictionary:
	var entry := _resolve_entry_for_venue(venue)
	if entry.is_empty():
		return {"success": false, "error": "missing_entry"}
	if venue == null or not is_instance_valid(venue):
		return {"success": false, "error": "missing_venue"}
	if player_node == null or not is_instance_valid(player_node):
		return {"success": false, "error": "missing_player"}
	if not _pole_equipped:
		return _build_action_result(false, "cast_unavailable", "pole_not_equipped")
	match _cast_state:
		CAST_STATE_EQUIPPED:
			if not _cast_preview_active:
				return _build_action_result(false, "cast_unavailable", "preview_required")
			_start_cast(entry, venue, player_node, preview_state)
			return _build_action_result(true, "cast_started")
		CAST_STATE_CAST_OUT:
			_resolve_reel(false)
			_sync_venue_state(venue)
			_refresh_hud_state(venue)
			_publish_feedback("空杆收回", "warning")
			return _build_action_result(true, "reel_missed")
		CAST_STATE_BITE_READY:
			_resolve_reel(true)
			_sync_venue_state(venue)
			_refresh_hud_state(venue)
			_publish_feedback("钓到一条鱼", "success")
			return _build_action_result(true, "catch_resolved")
		_:
			return _build_action_result(false, "cast_unavailable", "unsupported_state")

func debug_set_bite_delay_override(seconds: float) -> void:
	_debug_bite_delay_override_sec = maxf(seconds, 0.0) if seconds >= 0.0 else -1.0

func reset_runtime_state(_release_player: bool = true) -> void:
	_reset_runtime_state(_release_player)

func _update_with_venue(entry: Dictionary, venue: Node3D, player_node: Node3D, delta: float) -> Dictionary:
	_last_mounted_venue = venue
	if venue != null and is_instance_valid(venue):
		entry = _resolve_entry_for_venue(venue)
	if entry.is_empty() or venue == null or not is_instance_valid(venue):
		_handle_unavailable_runtime(_pole_equipped)
		return _build_runtime_tick_summary()
	if _pole_equipped and player_node != null and is_instance_valid(player_node):
		var in_release_bounds := venue.has_method("is_world_point_in_release_bounds") and bool(venue.is_world_point_in_release_bounds(player_node.global_position))
		if not in_release_bounds:
			_reset_runtime_state(true)
			_update_ambient_freeze(player_node, venue)
			_sync_venue_state(venue)
			_refresh_hud_state(venue)
			_publish_feedback("离开湖边，钓鱼已收起", "warning")
			return _build_runtime_tick_summary()
	_update_line_start_world_position(player_node, venue)
	_advance_session_timer(maxf(delta, 0.0))
	_update_ambient_freeze(player_node, venue)
	_sync_venue_state(venue)
	_refresh_hud_state(venue)
	return _build_runtime_tick_summary()

func _advance_session_timer(delta: float) -> void:
	if _cast_state != CAST_STATE_CAST_OUT:
		return
	_bite_wait_remaining_sec = maxf(_bite_wait_remaining_sec - delta, 0.0)
	if _bite_wait_remaining_sec > 0.0:
		return
	_cast_state = CAST_STATE_BITE_READY
	_bobber_bite_feedback_active = true
	_publish_feedback("鱼漂动了，左键收杆", "action")
	_refresh_hud_state(_last_mounted_venue)

func _update_ambient_freeze(player_node: Node3D, venue: Node3D) -> void:
	if player_node == null or not is_instance_valid(player_node) or venue == null:
		_ambient_simulation_frozen = false
		return
	var player_world_position := player_node.global_position
	var in_play_bounds := venue.has_method("is_world_point_in_play_bounds") and bool(venue.is_world_point_in_play_bounds(player_world_position))
	_ambient_simulation_frozen = in_play_bounds or _pole_equipped

func _start_cast(entry: Dictionary, venue: Node3D, player_node: Node3D, preview_state: Dictionary) -> void:
	_cast_state = CAST_STATE_CAST_OUT
	_cast_preview_active = false
	_preview_landing_world_position = _resolve_preview_landing_world_position(preview_state, venue)
	_target_school_id = _resolve_target_school_id(entry, venue, _preview_landing_world_position)
	_bobber_visible = true
	_bobber_world_position = _preview_landing_world_position
	_bobber_bite_feedback_active = false
	_fishing_line_visible = true
	_line_start_world_position = _resolve_line_start_world_position(player_node, venue)
	_last_catch_result.clear()
	_bite_wait_remaining_sec = _resolve_bite_delay_sec()
	_publish_feedback("甩杆完成，等待上钩", "action")
	_sync_venue_state(venue)
	_refresh_hud_state(venue)

func _resolve_reel(success: bool) -> void:
	_cast_state = CAST_STATE_EQUIPPED
	_cast_preview_active = false
	_preview_landing_world_position = Vector3.ZERO
	_bobber_visible = false
	_bobber_bite_feedback_active = false
	_fishing_line_visible = false
	_bite_wait_remaining_sec = 0.0
	_last_catch_result = {
		"result": "caught" if success else "miss",
		"school_id": _target_school_id,
	}

func _refresh_hud_state(venue: Node3D = null) -> void:
	var venue_contract: Dictionary = venue.get_fishing_contract() if venue != null and is_instance_valid(venue) and venue.has_method("get_fishing_contract") else {}
	var state_text := "按 E 拿起鱼竿"
	match _cast_state:
		CAST_STATE_EQUIPPED:
			state_text = "右键预甩 / 左键甩杆 / E 放回"
		CAST_STATE_CAST_OUT:
			state_text = "等待上钩"
		CAST_STATE_BITE_READY:
			state_text = "鱼漂动了，左键收杆"
	var result_text := ""
	if not _last_catch_result.is_empty():
		var result_label := "钓到鱼了" if str(_last_catch_result.get("result", "")) == "caught" else "空杆"
		var school_id := str(_last_catch_result.get("school_id", "")).strip_edges()
		result_text = "%s %s" % [result_label, school_id] if school_id != "" else result_label
	_hud_state = {
		"visible": _pole_equipped,
		"fishing_mode_active": _fishing_mode_active,
		"pole_equipped": _pole_equipped,
		"cast_state": _cast_state,
		"cast_preview_active": _cast_preview_active,
		"target_school_id": _target_school_id,
		"bobber_visible": _bobber_visible,
		"fishing_line_visible": _fishing_line_visible,
		"bobber_bite_feedback_active": _bobber_bite_feedback_active,
		"last_catch_result": _last_catch_result.duplicate(true),
		"display_name": str(venue_contract.get("display_name", "Lakeside Fishing")),
		"state_text": state_text,
		"result_text": result_text,
		"feedback_event_token": _feedback_event_token,
		"feedback_event_text": _feedback_event_text,
		"feedback_event_tone": _feedback_event_tone,
	}

func _build_primary_interaction_state(entry: Dictionary, venue: Node3D, player_node: Node3D) -> Dictionary:
	if player_node == null or not is_instance_valid(player_node) or venue == null or not is_instance_valid(venue):
		return _build_hidden_prompt_state()
	if _pole_equipped:
		return _build_hidden_prompt_state()
	var pole_anchor: Dictionary = venue.get_pole_anchor() if venue.has_method("get_pole_anchor") else {}
	var prompt_world_position: Vector3 = pole_anchor.get("world_position", _resolve_entry_world_position(entry))
	var distance_m := player_node.global_position.distance_to(prompt_world_position)
	var in_range := venue.has_method("is_world_point_in_pole_interaction_range") and bool(venue.is_world_point_in_pole_interaction_range(player_node.global_position))
	if not in_range:
		return _build_hidden_prompt_state()
	return {
		"visible": true,
		"owner_kind": "fishing_venue",
		"venue_id": str(entry.get("venue_id", "")),
		"prompt_text": "按 E 拿起鱼竿",
		"distance_m": distance_m,
	}

func _build_hidden_prompt_state() -> Dictionary:
	return {
		"visible": false,
		"owner_kind": "fishing_venue",
		"venue_id": _active_venue_id,
		"prompt_text": "",
		"distance_m": 0.0,
	}

func _build_handled_result(success: bool, action: String, error: String = "") -> Dictionary:
	return {
		"handled": true,
		"success": success,
		"owner_kind": "fishing_venue",
		"interaction_kind": "lakeside_fishing",
		"action": action,
		"error": error,
		"venue_id": _active_venue_id,
		"cast_state": _cast_state,
		"target_school_id": _target_school_id,
		"last_catch_result": _last_catch_result.duplicate(true),
	}

func _build_action_result(success: bool, action: String, error: String = "") -> Dictionary:
	return {
		"success": success,
		"action": action,
		"error": error,
		"cast_state": _cast_state,
		"target_school_id": _target_school_id,
		"last_catch_result": _last_catch_result.duplicate(true),
	}

func _build_runtime_tick_summary() -> Dictionary:
	return {
		"ambient_simulation_frozen": _ambient_simulation_frozen,
		"match_hud_state": _hud_state.duplicate(true),
	}

func _publish_feedback(text: String, tone: String) -> void:
	_feedback_event_token += 1
	_feedback_event_text = text.strip_edges()
	_feedback_event_tone = tone

func _handle_unavailable_runtime(reset_session: bool) -> void:
	if reset_session:
		_reset_runtime_state(true)
		_sync_venue_state(_last_mounted_venue)
	_ambient_simulation_frozen = false
	_refresh_hud_state()

func _reset_runtime_state(_release_player: bool) -> void:
	_fishing_mode_active = false
	_pole_equipped = false
	_cast_state = CAST_STATE_IDLE
	_cast_preview_active = false
	_preview_landing_world_position = Vector3.ZERO
	_target_school_id = ""
	_bobber_visible = false
	_bobber_world_position = Vector3.ZERO
	_bobber_bite_feedback_active = false
	_fishing_line_visible = false
	_line_start_world_position = Vector3.ZERO
	_last_catch_result.clear()
	_bite_wait_remaining_sec = 0.0
	_refresh_hud_state()

func _resolve_bite_delay_sec() -> float:
	if _debug_bite_delay_override_sec >= 0.0:
		return _debug_bite_delay_override_sec
	return _rng.randf_range(BITE_WAIT_MIN_SEC, BITE_WAIT_MAX_SEC)

func _resolve_preview_landing_world_position(preview_state: Dictionary, venue: Node3D) -> Vector3:
	var preview_variant: Variant = preview_state.get("landing_point", Vector3.ZERO)
	if preview_variant is Vector3:
		var preview_world_position := preview_variant as Vector3
		if preview_world_position != Vector3.ZERO and _is_preview_position_valid(venue, preview_world_position):
			return preview_world_position
	if _preview_landing_world_position != Vector3.ZERO and _is_preview_position_valid(venue, _preview_landing_world_position):
		return _preview_landing_world_position
	var bite_zone: Dictionary = venue.get_bite_zone() if venue != null and venue.has_method("get_bite_zone") else {}
	var bite_world_position: Vector3 = bite_zone.get("world_position", Vector3.ZERO)
	if bite_world_position != Vector3.ZERO:
		return bite_world_position
	var cast_origin: Dictionary = venue.get_cast_origin_anchor() if venue != null and venue.has_method("get_cast_origin_anchor") else {}
	return cast_origin.get("world_position", Vector3.ZERO)

func _is_preview_position_valid(venue: Node3D, world_position: Vector3) -> bool:
	if venue == null or not is_instance_valid(venue):
		return false
	if not venue.has_method("is_world_point_in_play_bounds"):
		return true
	return bool(venue.is_world_point_in_play_bounds(world_position))

func _update_line_start_world_position(player_node: Node3D, venue: Node3D) -> void:
	_line_start_world_position = _resolve_line_start_world_position(player_node, venue)

func _resolve_line_start_world_position(player_node: Node3D, venue: Node3D) -> Vector3:
	if player_node != null and is_instance_valid(player_node) and player_node.has_method("get_fishing_tip_world_position"):
		var tip_world_position: Variant = player_node.get_fishing_tip_world_position()
		if tip_world_position is Vector3:
			return tip_world_position as Vector3
	var cast_origin: Dictionary = venue.get_cast_origin_anchor() if venue != null and venue.has_method("get_cast_origin_anchor") else {}
	return cast_origin.get("world_position", Vector3.ZERO)

func _resolve_target_school_id(entry: Dictionary, venue: Node3D, target_world_position: Vector3 = Vector3.ZERO) -> String:
	var region_id := str(entry.get("linked_region_id", "")).strip_edges()
	if region_id == "" or _fish_school_runtime == null or not _fish_school_runtime.has_method("get_school_summaries_for_region"):
		return ""
	var resolved_world_position := target_world_position
	if resolved_world_position == Vector3.ZERO and venue != null and is_instance_valid(venue) and venue.has_method("get_bite_zone"):
		var bite_zone: Dictionary = venue.get_bite_zone()
		resolved_world_position = bite_zone.get("world_position", Vector3.ZERO)
	var schools: Array = _fish_school_runtime.get_school_summaries_for_region(region_id)
	var best_school_id := ""
	var best_distance_sq := INF
	for school_variant in schools:
		if not (school_variant is Dictionary):
			continue
		var school: Dictionary = school_variant
		var school_world_position_variant: Variant = school.get("world_position", Vector3.ZERO)
		if not (school_world_position_variant is Vector3):
			continue
		var school_position := school_world_position_variant as Vector3
		var distance_sq := school_position.distance_squared_to(resolved_world_position)
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
		"fishing_mode_active": _fishing_mode_active,
		"pole_equipped": _pole_equipped,
		"cast_state": _cast_state,
		"cast_preview_active": _cast_preview_active,
		"preview_landing_world_position": _preview_landing_world_position,
		"target_school_id": _target_school_id,
		"bobber_visible": _bobber_visible,
		"bobber_world_position": _bobber_world_position,
		"bobber_bite_feedback_active": _bobber_bite_feedback_active,
		"fishing_line_visible": _fishing_line_visible,
		"line_start_world_position": _line_start_world_position,
		"last_catch_result": _last_catch_result.duplicate(true),
	})
