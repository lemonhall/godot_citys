extends RefCounted

const FEATURE_KIND := "terrain_region_feature"
const REGION_KIND := "lake_basin"
const DEFAULT_PLAYER_WATER_ENTRY_HEIGHT_M := 1.2
const DEFAULT_UNDERWATER_MARGIN_M := 0.2

static func build_runtime_contract(manifest: Dictionary, shoreline_profile: Dictionary, bathymetry_profile: Dictionary, habitat_profile: Dictionary) -> Dictionary:
	var polygon_world_points := _decode_vector3_array(shoreline_profile.get("polygon_world_points", []))
	var polygon_points := _build_polygon_xz(polygon_world_points)
	var polygon_bounds := _build_polygon_bounds(polygon_points)
	return {
		"region_id": str(manifest.get("region_id", "")).strip_edges(),
		"display_name": str(manifest.get("display_name", "Fishing Lake")).strip_edges(),
		"feature_kind": str(manifest.get("feature_kind", FEATURE_KIND)).strip_edges(),
		"region_kind": str(manifest.get("region_kind", REGION_KIND)).strip_edges(),
		"anchor_chunk_id": str(manifest.get("anchor_chunk_id", "")).strip_edges(),
		"anchor_chunk_key": _decode_vector2i(manifest.get("anchor_chunk_key", null)),
		"world_position": _decode_vector3(manifest.get("world_position", null)),
		"surface_normal": _decode_vector3(manifest.get("surface_normal", Vector3.UP)),
		"water_level_y_m": float(manifest.get("water_level_y_m", 0.0)),
		"mean_depth_m": float(manifest.get("mean_depth_m", 10.0)),
		"max_depth_m": float(manifest.get("max_depth_m", 15.0)),
		"manifest_path": str(manifest.get("manifest_path", "")).strip_edges(),
		"shoreline_profile_path": str(manifest.get("shoreline_profile_path", "")).strip_edges(),
		"bathymetry_profile_path": str(manifest.get("bathymetry_profile_path", "")).strip_edges(),
		"habitat_profile_path": str(manifest.get("habitat_profile_path", "")).strip_edges(),
		"linked_venue_ids": (manifest.get("linked_venue_ids", []) as Array).duplicate(true),
		"render_owner_chunk_id": str(manifest.get("render_owner_chunk_id", manifest.get("anchor_chunk_id", ""))).strip_edges(),
		"player_water_entry_height_m": float(manifest.get("player_water_entry_height_m", DEFAULT_PLAYER_WATER_ENTRY_HEIGHT_M)),
		"underwater_margin_m": float(manifest.get("underwater_margin_m", DEFAULT_UNDERWATER_MARGIN_M)),
		"polygon_world_points": polygon_world_points,
		"polygon_points_xz": polygon_points,
		"polygon_bounds_min": polygon_bounds.get("min", Vector2.ZERO),
		"polygon_bounds_max": polygon_bounds.get("max", Vector2.ZERO),
		"shore_blend_distance_m": float(bathymetry_profile.get("shore_blend_distance_m", 28.0)),
		"deep_pockets": (bathymetry_profile.get("deep_pockets", []) as Array).duplicate(true),
		"schools": (habitat_profile.get("schools", []) as Array).duplicate(true),
		"shoreline_profile": shoreline_profile.duplicate(true),
		"bathymetry_profile": bathymetry_profile.duplicate(true),
		"habitat_profile": habitat_profile.duplicate(true),
	}

static func sample_depth_from_contract(contract: Dictionary, world_position: Vector3) -> Dictionary:
	var polygon_points: PackedVector2Array = contract.get("polygon_points_xz", PackedVector2Array())
	if polygon_points.size() < 3:
		var polygon_world_points: Array = contract.get("polygon_world_points", [])
		polygon_points = _build_polygon_xz(polygon_world_points)
	if polygon_points.size() < 3:
		return _build_outside_sample(contract, world_position)
	var sample_point := Vector2(world_position.x, world_position.z)
	var polygon_bounds_min: Vector2 = contract.get("polygon_bounds_min", Vector2.ZERO)
	var polygon_bounds_max: Vector2 = contract.get("polygon_bounds_max", Vector2.ZERO)
	if sample_point.x < polygon_bounds_min.x - 0.35 or sample_point.x > polygon_bounds_max.x + 0.35 or sample_point.y < polygon_bounds_min.y - 0.35 or sample_point.y > polygon_bounds_max.y + 0.35:
		return _build_outside_sample(contract, world_position)
	var inside_region := Geometry2D.is_point_in_polygon(sample_point, polygon_points)
	var edge_distance_m := _distance_to_polygon_edges(sample_point, polygon_points)
	if not inside_region and edge_distance_m <= 0.35:
		inside_region = true
	if not inside_region:
		return _build_outside_sample(contract, world_position)
	var mean_depth_m := float(contract.get("mean_depth_m", 10.0))
	var max_depth_m := float(contract.get("max_depth_m", mean_depth_m))
	var shore_blend_distance_m := maxf(float(contract.get("shore_blend_distance_m", 28.0)), 0.001)
	var depth_m := clampf((edge_distance_m / shore_blend_distance_m) * mean_depth_m, 0.0, mean_depth_m)
	for pocket_variant in contract.get("deep_pockets", []):
		if not (pocket_variant is Dictionary):
			continue
		var pocket: Dictionary = pocket_variant
		var pocket_world_position: Variant = _decode_vector3(pocket.get("world_position", null))
		if pocket_world_position == null:
			continue
		var radius_m := maxf(float(pocket.get("radius_m", 0.0)), 0.001)
		var falloff_exp := maxf(float(pocket.get("falloff_exp", 1.0)), 0.01)
		var distance_m := Vector2(
			world_position.x - (pocket_world_position as Vector3).x,
			world_position.z - (pocket_world_position as Vector3).z
		).length()
		if distance_m >= radius_m:
			continue
		var influence := pow(1.0 - distance_m / radius_m, falloff_exp)
		var pocket_depth_m := mean_depth_m + float(pocket.get("depth_boost_m", 0.0)) * influence
		depth_m = maxf(depth_m, pocket_depth_m)
	depth_m = clampf(depth_m, 0.0, max_depth_m)
	var water_level_y_m := float(contract.get("water_level_y_m", 0.0))
	return {
		"region_id": str(contract.get("region_id", "")),
		"inside_region": true,
		"world_position": world_position,
		"edge_distance_m": edge_distance_m,
		"depth_m": depth_m,
		"water_level_y_m": water_level_y_m,
		"floor_y_m": water_level_y_m - depth_m,
	}

static func build_water_state(contract: Dictionary, world_position: Vector3) -> Dictionary:
	var depth_sample := sample_depth_from_contract(contract, world_position)
	if not bool(depth_sample.get("inside_region", false)):
		return {
			"in_water": false,
			"underwater": false,
			"region_id": "",
			"water_level_y_m": 0.0,
			"depth_m": 0.0,
			"floor_y_m": 0.0,
			"world_position": world_position,
		}
	var water_level_y_m := float(depth_sample.get("water_level_y_m", 0.0))
	var player_water_entry_height_m := maxf(float(contract.get("player_water_entry_height_m", DEFAULT_PLAYER_WATER_ENTRY_HEIGHT_M)), 0.0)
	var underwater_margin_m := maxf(float(contract.get("underwater_margin_m", DEFAULT_UNDERWATER_MARGIN_M)), 0.0)
	var in_water := world_position.y <= water_level_y_m + player_water_entry_height_m
	return {
		"in_water": in_water,
		"underwater": in_water and world_position.y < water_level_y_m - underwater_margin_m,
		"region_id": str(contract.get("region_id", "")),
		"water_level_y_m": water_level_y_m,
		"depth_m": float(depth_sample.get("depth_m", 0.0)),
		"floor_y_m": float(depth_sample.get("floor_y_m", water_level_y_m)),
		"world_position": world_position,
	}

static func _build_outside_sample(contract: Dictionary, world_position: Vector3) -> Dictionary:
	var water_level_y_m := float(contract.get("water_level_y_m", 0.0))
	return {
		"region_id": str(contract.get("region_id", "")),
		"inside_region": false,
		"world_position": world_position,
		"edge_distance_m": INF,
		"depth_m": 0.0,
		"water_level_y_m": water_level_y_m,
		"floor_y_m": water_level_y_m,
	}

static func _distance_to_polygon_edges(point: Vector2, polygon_points: PackedVector2Array) -> float:
	if polygon_points.size() < 2:
		return INF
	var best_distance_m := INF
	for point_index in range(polygon_points.size()):
		var a := polygon_points[point_index]
		var b := polygon_points[(point_index + 1) % polygon_points.size()]
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		best_distance_m = minf(best_distance_m, point.distance_to(closest))
	return best_distance_m

static func _build_polygon_xz(points: Array) -> PackedVector2Array:
	var polygon_points := PackedVector2Array()
	for point_variant in points:
		var point: Variant = _decode_vector3(point_variant)
		if point == null:
			continue
		var world_point := point as Vector3
		polygon_points.append(Vector2(world_point.x, world_point.z))
	return polygon_points

static func _build_polygon_bounds(points: PackedVector2Array) -> Dictionary:
	if points.is_empty():
		return {
			"min": Vector2.ZERO,
			"max": Vector2.ZERO,
		}
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return {
		"min": min_point,
		"max": max_point,
	}

static func _decode_vector3(value: Variant) -> Variant:
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

static func _decode_vector2i(value: Variant) -> Variant:
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

static func _decode_vector3_array(values: Array) -> Array:
	var points: Array = []
	for value in values:
		var point: Variant = _decode_vector3(value)
		if point == null:
			continue
		points.append(point)
	return points
