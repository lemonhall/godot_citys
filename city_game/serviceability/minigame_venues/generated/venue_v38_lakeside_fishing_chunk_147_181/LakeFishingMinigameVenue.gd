extends Node3D

const DEFAULT_MANIFEST_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/minigame_venue_manifest.json"
const PLAY_HALF_EXTENTS_M := Vector2(70.0, 60.0)
const DEFAULT_RELEASE_BUFFER_M := 32.0
const DEFAULT_POLE_INTERACTION_RADIUS_M := 3.6

var _entry: Dictionary = {}
var _fishing_contract: Dictionary = {}
var _runtime_state: Dictionary = {}
var _pole_visual: Node3D = null
var _bobber_visual: Node3D = null
var _line_visual: Node3D = null
var _bobber_animation_time_sec := 0.0

func _ready() -> void:
	if _entry.is_empty():
		_entry = _load_default_entry()
	else:
		_entry = _merge_entry_with_defaults(_entry)
	_refresh_contracts()
	_resolve_runtime_visuals()
	_apply_runtime_visual_state()

func _process(delta: float) -> void:
	_bobber_animation_time_sec += maxf(delta, 0.0)
	_apply_runtime_visual_state()

func configure_minigame_venue(entry: Dictionary) -> void:
	_entry = _merge_entry_with_defaults(entry)
	_refresh_contracts()
	if is_inside_tree():
		_resolve_runtime_visuals()
		_apply_runtime_visual_state()

func get_venue_contract() -> Dictionary:
	return _entry.duplicate(true)

func get_fishing_contract() -> Dictionary:
	_refresh_contracts()
	return _fishing_contract.duplicate(true)

func get_pole_anchor(anchor_id: String = "") -> Dictionary:
	_refresh_contracts()
	var pole_anchors: Dictionary = _fishing_contract.get("pole_anchors", {})
	var resolved_anchor_id := anchor_id.strip_edges()
	if resolved_anchor_id == "":
		resolved_anchor_id = str(_fishing_contract.get("pole_anchor_id", "pole_rest_anchor"))
	return (pole_anchors.get(resolved_anchor_id, {}) as Dictionary).duplicate(true)

func get_cast_origin_anchor(anchor_id: String = "") -> Dictionary:
	_refresh_contracts()
	var cast_anchors: Dictionary = _fishing_contract.get("cast_origins", {})
	var resolved_anchor_id := anchor_id.strip_edges()
	if resolved_anchor_id == "":
		resolved_anchor_id = str(_fishing_contract.get("cast_origin_anchor_id", "cast_origin_main"))
	return (cast_anchors.get(resolved_anchor_id, {}) as Dictionary).duplicate(true)

func get_bite_zone(zone_id: String = "") -> Dictionary:
	_refresh_contracts()
	var bite_zones: Dictionary = _fishing_contract.get("bite_zones", {})
	var resolved_zone_id := zone_id.strip_edges()
	if resolved_zone_id == "":
		var bite_zone_ids: Array = _fishing_contract.get("bite_zone_ids", [])
		resolved_zone_id = str(bite_zone_ids[0]) if not bite_zone_ids.is_empty() else "bite_zone_main"
	return (bite_zones.get(resolved_zone_id, {}) as Dictionary).duplicate(true)

func sync_fishing_state(state: Dictionary) -> void:
	_runtime_state = state.duplicate(true)
	_resolve_runtime_visuals()
	_apply_runtime_visual_state()

func is_world_point_in_pole_interaction_range(world_position: Vector3) -> bool:
	_refresh_contracts()
	var pole_anchor: Dictionary = get_pole_anchor()
	var pole_world_position: Vector3 = pole_anchor.get("world_position", global_position)
	var radius_m := maxf(float(_fishing_contract.get("pole_interaction_radius_m", DEFAULT_POLE_INTERACTION_RADIUS_M)), 1.5)
	return world_position.distance_squared_to(pole_world_position) <= radius_m * radius_m

func is_world_point_in_play_bounds(world_position: Vector3) -> bool:
	_refresh_contracts()
	var play_bounds: Dictionary = _fishing_contract.get("play_bounds", {})
	var local_center: Vector3 = play_bounds.get("local_center", Vector3.ZERO)
	var local_position := to_local(world_position) - local_center
	var half_extents: Vector2 = play_bounds.get("half_extents_m", PLAY_HALF_EXTENTS_M)
	return absf(local_position.x) <= half_extents.x and absf(local_position.z) <= half_extents.y

func is_world_point_in_release_bounds(world_position: Vector3) -> bool:
	_refresh_contracts()
	var play_bounds: Dictionary = _fishing_contract.get("play_bounds", {})
	var local_center: Vector3 = play_bounds.get("local_center", Vector3.ZERO)
	var local_position := to_local(world_position) - local_center
	var half_extents: Vector2 = play_bounds.get("half_extents_m", PLAY_HALF_EXTENTS_M)
	var release_buffer_m := float(_fishing_contract.get("release_buffer_m", DEFAULT_RELEASE_BUFFER_M))
	return absf(local_position.x) <= half_extents.x + release_buffer_m and absf(local_position.z) <= half_extents.y + release_buffer_m

func _refresh_contracts() -> void:
	if _entry.is_empty():
		return
	var pole_anchor := _build_anchor_contract("pole_rest_anchor", get_node_or_null("FishingPoleRestAnchor") as Node3D)
	var cast_origin := _build_anchor_contract("cast_origin_main", get_node_or_null("CastOriginMain") as Node3D)
	var bite_zone := _build_anchor_contract("bite_zone_main", get_node_or_null("BiteZoneMain") as Node3D)
	var play_center_node := get_node_or_null("PlayAreaCenter") as Node3D
	var play_center_local := play_center_node.position if play_center_node != null else Vector3(0.0, 0.0, -36.0)
	var bite_zone_ids: Array = (_entry.get("bite_zone_ids", []) as Array).duplicate(true)
	_fishing_contract = _entry.duplicate(true)
	_fishing_contract["pole_anchors"] = {
		"pole_rest_anchor": pole_anchor,
	}
	_fishing_contract["cast_origins"] = {
		"cast_origin_main": cast_origin,
	}
	_fishing_contract["bite_zones"] = {
		"bite_zone_main": bite_zone,
	}
	_fishing_contract["pole_anchor_id"] = str(_entry.get("pole_anchor_id", "pole_rest_anchor"))
	_fishing_contract["cast_origin_anchor_id"] = str(_entry.get("cast_origin_anchor_id", "cast_origin_main"))
	_fishing_contract["bite_zone_ids"] = bite_zone_ids if not bite_zone_ids.is_empty() else ["bite_zone_main"]
	_fishing_contract["pole_interaction_radius_m"] = maxf(float(_entry.get("pole_interaction_radius_m", DEFAULT_POLE_INTERACTION_RADIUS_M)), 1.5)
	_fishing_contract["play_bounds"] = {
		"local_center": play_center_local,
		"world_center": _to_world_point(play_center_local),
		"half_extents_m": PLAY_HALF_EXTENTS_M,
		"release_buffer_m": float(_entry.get("release_buffer_m", DEFAULT_RELEASE_BUFFER_M)),
	}

func _resolve_runtime_visuals() -> void:
	if _pole_visual == null or not is_instance_valid(_pole_visual):
		_pole_visual = get_node_or_null("FishingPoleRestAnchor/FishingPoleVisual") as Node3D
	if _bobber_visual == null or not is_instance_valid(_bobber_visual):
		_bobber_visual = get_node_or_null("FishingBobberVisual") as Node3D
	if _line_visual == null or not is_instance_valid(_line_visual):
		_line_visual = get_node_or_null("FishingLineVisual") as Node3D

func _apply_runtime_visual_state() -> void:
	_resolve_runtime_visuals()
	var pole_equipped := bool(_runtime_state.get("pole_equipped", false))
	if _pole_visual != null and is_instance_valid(_pole_visual):
		_pole_visual.visible = not pole_equipped
	var bite_zone_world_position: Vector3 = get_bite_zone().get("world_position", global_position)
	var bobber_world_position: Vector3 = _runtime_state.get("bobber_world_position", bite_zone_world_position)
	var bobber_visible := bool(_runtime_state.get("bobber_visible", false))
	var bite_feedback_active := bool(_runtime_state.get("bobber_bite_feedback_active", false))
	var animated_bobber_world_position := _resolve_bobber_world_position(bobber_world_position, bite_feedback_active)
	if _bobber_visual != null and is_instance_valid(_bobber_visual):
		if _bobber_visual.has_method("set_bobber_state"):
			_bobber_visual.set_bobber_state(bobber_visible, animated_bobber_world_position, bite_feedback_active)
		else:
			_bobber_visual.visible = bobber_visible
			_bobber_visual.global_position = animated_bobber_world_position
	var line_visible := bool(_runtime_state.get("fishing_line_visible", false))
	var line_start_world_position: Vector3 = _runtime_state.get("line_start_world_position", get_cast_origin_anchor().get("world_position", global_position))
	if _line_visual != null and is_instance_valid(_line_visual):
		if _line_visual.has_method("set_line_state"):
			_line_visual.set_line_state(line_visible, line_start_world_position, animated_bobber_world_position, 0.22)
		else:
			_line_visual.visible = line_visible

func _resolve_bobber_world_position(base_world_position: Vector3, bite_feedback_active: bool) -> Vector3:
	var resolved_world_position := base_world_position
	if bite_feedback_active:
		resolved_world_position.y += sin(_bobber_animation_time_sec * 18.0) * 0.18
	else:
		resolved_world_position.y += sin(_bobber_animation_time_sec * 2.4) * 0.02
	return resolved_world_position

func _build_anchor_contract(anchor_id: String, anchor_node: Node3D) -> Dictionary:
	var local_position := anchor_node.position if anchor_node != null else Vector3.ZERO
	return {
		"anchor_id": anchor_id,
		"local_position": local_position,
		"world_position": _to_world_point(local_position),
	}

func _to_world_point(local_point: Vector3) -> Vector3:
	return to_global(local_point) if is_inside_tree() else _resolve_entry_world_position() + _resolve_scene_root_offset() + local_point

func _resolve_entry_world_position() -> Vector3:
	var world_position_variant: Variant = _entry.get("world_position", Vector3.ZERO)
	if world_position_variant is Vector3:
		return world_position_variant as Vector3
	return Vector3.ZERO

func _resolve_scene_root_offset() -> Vector3:
	var root_offset_variant: Variant = _entry.get("scene_root_offset", Vector3.ZERO)
	if root_offset_variant is Vector3:
		return root_offset_variant as Vector3
	return Vector3.ZERO

func _load_default_entry() -> Dictionary:
	var global_path := ProjectSettings.globalize_path(DEFAULT_MANIFEST_PATH)
	if not FileAccess.file_exists(global_path):
		return {}
	var manifest_text := FileAccess.get_file_as_string(global_path)
	if manifest_text.strip_edges() == "":
		return {}
	var manifest_variant = JSON.parse_string(manifest_text)
	if not (manifest_variant is Dictionary):
		return {}
	var manifest: Dictionary = (manifest_variant as Dictionary).duplicate(true)
	return {
		"venue_id": str(manifest.get("venue_id", "")),
		"display_name": str(manifest.get("display_name", "Lakeside Fishing")),
		"feature_kind": str(manifest.get("feature_kind", "scene_minigame_venue")),
		"game_kind": str(manifest.get("game_kind", "lakeside_fishing")),
		"linked_region_id": str(manifest.get("linked_region_id", "")),
		"anchor_chunk_id": str(manifest.get("anchor_chunk_id", "")),
		"anchor_chunk_key": _decode_vector2i(manifest.get("anchor_chunk_key", null)),
		"world_position": _decode_vector3(manifest.get("world_position", null)),
		"surface_normal": _decode_vector3(manifest.get("surface_normal", null)),
		"scene_root_offset": _decode_vector3(manifest.get("scene_root_offset", null)),
		"scene_path": str(manifest.get("scene_path", "")),
		"manifest_path": DEFAULT_MANIFEST_PATH,
		"pole_anchor_id": str(manifest.get("pole_anchor_id", "")),
		"cast_origin_anchor_id": str(manifest.get("cast_origin_anchor_id", "")),
		"bite_zone_ids": (manifest.get("bite_zone_ids", []) as Array).duplicate(true),
		"pole_interaction_radius_m": float(manifest.get("pole_interaction_radius_m", DEFAULT_POLE_INTERACTION_RADIUS_M)),
		"release_buffer_m": float(manifest.get("release_buffer_m", DEFAULT_RELEASE_BUFFER_M)),
		"full_map_pin": (manifest.get("full_map_pin", {}) as Dictionary).duplicate(true),
		"yaw_rad": float(manifest.get("yaw_rad", 0.0)),
	}

func _merge_entry_with_defaults(entry: Dictionary) -> Dictionary:
	var merged_entry := _load_default_entry()
	for key_variant in entry.keys():
		var key := str(key_variant)
		merged_entry[key] = entry.get(key_variant)
	return merged_entry

func _decode_vector3(value: Variant) -> Variant:
	if value is Vector3:
		return value
	if not (value is Dictionary):
		return null
	var payload: Dictionary = value
	if str(payload.get("@type", "")) != "Vector3":
		return null
	return Vector3(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("z", 0.0))
	)

func _decode_vector2i(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if not (value is Dictionary):
		return null
	var payload: Dictionary = value
	if str(payload.get("@type", "")) != "Vector2i":
		return null
	return Vector2i(
		int(payload.get("x", 0)),
		int(payload.get("y", 0))
	)
