extends RefCounted

var _config = null
var _pedestrian_config = null
var _road_graph = null
var _lane_graph = null
var _district_profiles_by_id: Dictionary = {}
var _world_stats: Dictionary = {}

func setup(config, pedestrian_config, road_graph, lane_graph, district_profiles_by_id: Dictionary) -> void:
	_config = config
	_pedestrian_config = pedestrian_config
	_road_graph = road_graph
	_lane_graph = lane_graph
	_district_profiles_by_id = district_profiles_by_id.duplicate(true)
	var profile_snapshot: Dictionary = _pedestrian_config.to_snapshot()
	_world_stats = {
		"district_profile_count": _district_profiles_by_id.size(),
		"district_class_count": int((profile_snapshot.get("district_class_density", {}) as Dictionary).size()),
		"road_class_count": int((profile_snapshot.get("road_class_density", {}) as Dictionary).size()),
		"max_spawn_slots_per_chunk": int(profile_snapshot.get("max_spawn_slots_per_chunk", 0)),
		"lane_count": int(_lane_graph.get_lane_count()),
		"sidewalk_lane_count": int(_lane_graph.get_lane_type_count("sidewalk")),
		"crossing_lane_count": int(_lane_graph.get_lane_type_count("crossing")),
	}

func get_world_stats() -> Dictionary:
	return _world_stats.duplicate(true)

func get_profile_snapshot() -> Dictionary:
	return _pedestrian_config.to_snapshot()

func get_lane_graph():
	return _lane_graph

func get_density_for_district_class(district_class: String) -> float:
	return float(_pedestrian_config.get_density_for_district_class(district_class))

func get_density_for_road_class(road_class: String) -> float:
	return float(_pedestrian_config.get_density_for_road_class(road_class))

func get_profile_for_district(district_id: String) -> Dictionary:
	if not _district_profiles_by_id.has(district_id):
		return {}
	return (_district_profiles_by_id[district_id] as Dictionary).duplicate(true)

func get_pedestrian_query_for_chunk(chunk_key: Vector2i) -> Dictionary:
	var chunk_id: String = _config.format_chunk_id(chunk_key)
	var district_key := _chunk_to_district_key(chunk_key)
	var district_id: String = _config.format_district_id(district_key)
	var district_profile: Dictionary = get_profile_for_district(district_id)
	var chunk_rect := _build_chunk_rect(chunk_key)
	var district_density := float(district_profile.get("density_scalar", 0.0))
	var lane_rect := chunk_rect.grow(float(_config.chunk_size_m) * 0.25)
	var chunk_lanes: Array = _lane_graph.get_lanes_intersecting_rect(lane_rect)
	var spawn_result: Dictionary = _build_spawn_result(chunk_key, district_id, district_profile, chunk_lanes, chunk_rect)
	var spawn_slots: Array[Dictionary] = spawn_result.get("spawn_slots", [])
	var road_class_counts: Dictionary = spawn_result.get("road_class_counts", {})
	var lane_ids: Array = spawn_result.get("lane_ids", [])
	if spawn_slots.is_empty():
		var expanded_rect := chunk_rect.grow(float(_config.chunk_size_m) * 1.25)
		chunk_lanes = _lane_graph.get_lanes_intersecting_rect(expanded_rect)
		spawn_result = _build_spawn_result(chunk_key, district_id, district_profile, chunk_lanes, chunk_rect.grow(float(_config.chunk_size_m) * 0.35))
		spawn_slots = spawn_result.get("spawn_slots", [])
		road_class_counts = spawn_result.get("road_class_counts", {})
		lane_ids = spawn_result.get("lane_ids", [])

	return {
		"chunk_id": chunk_id,
		"chunk_key": chunk_key,
		"district_id": district_id,
		"district_key": district_key,
		"lane_page_id": "ped_page_%s" % [chunk_id],
		"density_bucket": str(district_profile.get("density_bucket", "")),
		"density_scalar": district_density,
		"lane_count": chunk_lanes.size(),
		"lane_ids": lane_ids,
		"spawn_capacity": spawn_slots.size(),
		"spawn_slots": spawn_slots,
		"road_class_counts": road_class_counts.duplicate(true),
		"roster_signature": _build_roster_signature(chunk_id, district_profile, road_class_counts, spawn_slots),
	}

func _build_spawn_result(chunk_key: Vector2i, district_id: String, district_profile: Dictionary, chunk_lanes: Array, spawn_rect: Rect2) -> Dictionary:
	var road_class_counts: Dictionary = {}
	var spawn_slots: Array[Dictionary] = []
	var lane_ids: Array[String] = []
	var max_spawn_slots := int(_pedestrian_config.get_max_spawn_slots_per_chunk())
	var district_density := float(district_profile.get("density_scalar", 0.0))
	var slot_counter := 0

	for lane_variant in chunk_lanes:
		var lane: Dictionary = lane_variant
		if str(lane.get("lane_type", "")) != "sidewalk":
			continue
		var lane_id := str(lane.get("lane_id", ""))
		lane_ids.append(lane_id)
		var road_id := str(lane.get("road_id", ""))
		var road_class := str(lane.get("road_class", "local"))
		var road_density := get_density_for_road_class(road_class)
		var slot_count := int(_pedestrian_config.get_spawn_slots_for_edge(district_density, road_density))
		if slot_count <= 0:
			continue
		var lane_length := float(lane.get("path_length_m", 0.0))
		var lane_slot_budget := maxi(1, mini(slot_count, int(floor(lane_length / 10.0))))
		road_class_counts[road_class] = int(road_class_counts.get(road_class, 0)) + lane_slot_budget
		for slot_index in range(lane_slot_budget):
			if spawn_slots.size() >= max_spawn_slots:
				break
			var ratio := float(slot_index + 1) / float(lane_slot_budget + 1)
			var world_position := _sample_lane_position(lane.get("points", []), ratio)
			if not spawn_rect.has_point(Vector2(world_position.x, world_position.z)):
				continue
			var seed_salt := int(lane.get("seed", 0)) + slot_index * 53 + slot_counter * 11
			spawn_slots.append({
				"spawn_slot_id": "%s:%s:%02d" % [_config.format_chunk_id(chunk_key), lane_id, slot_index],
				"lane_ref_id": lane_id,
				"road_id": road_id,
				"road_class": road_class,
				"side": str(lane.get("side", "left")),
				"lane_type": "sidewalk",
				"district_id": district_id,
				"seed": _config.derive_seed("ped_spawn_slot", chunk_key, seed_salt),
				"world_position": world_position,
				"road_clearance_m": float(lane.get("road_clearance_m", 0.0)),
				"archetype_weights": (district_profile.get("archetype_weights", {}) as Dictionary).duplicate(true),
			})
			slot_counter += 1
		if spawn_slots.size() >= max_spawn_slots:
			break

	return {
		"road_class_counts": road_class_counts,
		"spawn_slots": spawn_slots,
		"lane_ids": lane_ids,
	}

func _build_chunk_rect(chunk_key: Vector2i) -> Rect2:
	var bounds: Rect2 = _config.get_world_bounds()
	var chunk_size := float(_config.chunk_size_m)
	var chunk_origin := Vector2(
		bounds.position.x + float(chunk_key.x) * chunk_size,
		bounds.position.y + float(chunk_key.y) * chunk_size
	)
	return Rect2(chunk_origin, Vector2.ONE * chunk_size)

func _chunk_to_district_key(chunk_key: Vector2i) -> Vector2i:
	var district_grid: Vector2i = _config.get_district_grid_size()
	var chunk_grid: Vector2i = _config.get_chunk_grid_size()
	var district_x := mini(int(floor(float(chunk_key.x) * float(district_grid.x) / float(chunk_grid.x))), district_grid.x - 1)
	var district_y := mini(int(floor(float(chunk_key.y) * float(district_grid.y) / float(chunk_grid.y))), district_grid.y - 1)
	return Vector2i(district_x, district_y)

func _build_roster_signature(chunk_id: String, district_profile: Dictionary, road_class_counts: Dictionary, spawn_slots: Array[Dictionary]) -> String:
	var road_parts: PackedStringArray = []
	var sorted_classes := road_class_counts.keys()
	sorted_classes.sort()
	for road_class_variant in sorted_classes:
		var road_class := str(road_class_variant)
		road_parts.append("%s:%d" % [road_class, int(road_class_counts.get(road_class, 0))])
	var slot_parts: PackedStringArray = []
	var preview_count := mini(spawn_slots.size(), 6)
	for slot_index in range(preview_count):
		var slot_data: Dictionary = spawn_slots[slot_index]
		slot_parts.append(str(slot_data.get("spawn_slot_id", "")))
	return "%s|%s|%s|%d|%s" % [
		chunk_id,
		str(district_profile.get("district_class", "")),
		str(district_profile.get("density_bucket", "")),
		spawn_slots.size(),
		"%s|%s" % [";".join(road_parts), ",".join(slot_parts)],
	]

func _sample_lane_position(points: Array, ratio: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	if points.size() == 1:
		return points[0]
	var total_length := 0.0
	for point_index in range(points.size() - 1):
		total_length += (points[point_index + 1] as Vector3).distance_to(points[point_index] as Vector3)
	if total_length <= 0.001:
		return points[0]
	var target_length := total_length * clampf(ratio, 0.0, 1.0)
	var traversed := 0.0
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var segment_length := a.distance_to(b)
		if traversed + segment_length >= target_length:
			var t := 0.0 if segment_length <= 0.001 else (target_length - traversed) / segment_length
			return a.lerp(b, clampf(t, 0.0, 1.0))
		traversed += segment_length
	return points[points.size() - 1]
