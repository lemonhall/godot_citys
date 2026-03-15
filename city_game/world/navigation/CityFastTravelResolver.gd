extends RefCounted

const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")

var _config = null
var _world_data: Dictionary = {}

func _init(config = null, world_data: Dictionary = {}) -> void:
	if config != null:
		setup(config, world_data)

func setup(config, world_data: Dictionary = {}) -> void:
	_config = config
	_world_data = world_data

func resolve_target(resolved_target: Dictionary, route_result: Dictionary = {}, standing_height: float = 1.0) -> Dictionary:
	if resolved_target.is_empty():
		return {}
	var anchor: Vector3 = route_result.get("snapped_destination", resolved_target.get("routable_anchor", resolved_target.get("world_anchor", Vector3.ZERO)))
	var safe_drop_anchor := _sample_surface_anchor(anchor, standing_height)
	var arrival_heading := _resolve_arrival_heading(route_result, resolved_target, anchor)
	return {
		"safe_drop_anchor": safe_drop_anchor,
		"arrival_heading": arrival_heading,
		"source_target_id": _resolve_source_target_id(resolved_target),
	}

func _resolve_source_target_id(resolved_target: Dictionary) -> String:
	var place_id := str(resolved_target.get("place_id", ""))
	if place_id != "":
		return place_id
	var anchor: Vector3 = resolved_target.get("routable_anchor", resolved_target.get("world_anchor", Vector3.ZERO))
	return "raw:%d:%d:%d" % [int(round(anchor.x)), int(round(anchor.y)), int(round(anchor.z))]

func _resolve_arrival_heading(route_result: Dictionary, resolved_target: Dictionary, anchor: Vector3) -> Vector3:
	var polyline: Array = route_result.get("polyline", [])
	if polyline.size() >= 2:
		var previous_point: Vector3 = polyline[polyline.size() - 2]
		var route_heading := Vector3(anchor.x - previous_point.x, 0.0, anchor.z - previous_point.z)
		if route_heading.length_squared() > 0.0001:
			return route_heading.normalized()
	var world_anchor: Vector3 = resolved_target.get("world_anchor", anchor)
	var anchor_heading := Vector3(world_anchor.x - anchor.x, 0.0, world_anchor.z - anchor.z)
	if anchor_heading.length_squared() > 0.0001:
		return anchor_heading.normalized()
	return Vector3.FORWARD

func _sample_surface_anchor(anchor: Vector3, standing_height: float) -> Vector3:
	if _config == null or not _config.has_method("get_world_bounds"):
		return anchor + Vector3.UP * standing_height
	var chunk_payload := _build_chunk_payload_for_world_position(anchor)
	var profile := CityChunkProfileBuilder.build_profile(chunk_payload)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := Vector2(anchor.x - chunk_center.x, anchor.z - chunk_center.z)
	return Vector3(
		anchor.x,
		CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile) + standing_height,
		anchor.z
	)

func _build_chunk_payload_for_world_position(world_position: Vector3) -> Dictionary:
	var chunk_key := CityChunkKey.world_to_chunk_key(_config, world_position)
	var bounds: Rect2 = _config.get_world_bounds()
	var chunk_center := Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(_config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(_config.chunk_size_m)
	)
	return {
		"chunk_id": _config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": chunk_center,
		"chunk_size_m": float(_config.chunk_size_m),
		"chunk_seed": _config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(_config.base_seed),
		"road_graph": _world_data.get("road_graph"),
	}
