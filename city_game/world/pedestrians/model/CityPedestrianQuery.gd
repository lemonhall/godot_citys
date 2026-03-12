extends RefCounted

var _config = null
var _pedestrian_config = null
var _road_graph = null
var _district_profiles_by_id: Dictionary = {}
var _world_stats: Dictionary = {}

func setup(config, pedestrian_config, road_graph, district_profiles_by_id: Dictionary) -> void:
	_config = config
	_pedestrian_config = pedestrian_config
	_road_graph = road_graph
	_district_profiles_by_id = district_profiles_by_id.duplicate(true)
	var profile_snapshot: Dictionary = _pedestrian_config.to_snapshot()
	_world_stats = {
		"district_profile_count": _district_profiles_by_id.size(),
		"district_class_count": int((profile_snapshot.get("district_class_density", {}) as Dictionary).size()),
		"road_class_count": int((profile_snapshot.get("road_class_density", {}) as Dictionary).size()),
		"max_spawn_slots_per_chunk": int(profile_snapshot.get("max_spawn_slots_per_chunk", 0)),
	}

func get_world_stats() -> Dictionary:
	return _world_stats.duplicate(true)

func get_profile_snapshot() -> Dictionary:
	return _pedestrian_config.to_snapshot()

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
	var spawn_result := _build_spawn_result(chunk_key, district_id, district_profile, _road_graph.get_edges_intersecting_rect(chunk_rect))
	var spawn_slots: Array[Dictionary] = spawn_result.get("spawn_slots", [])
	var road_class_counts: Dictionary = spawn_result.get("road_class_counts", {})
	if spawn_slots.is_empty():
		var expanded_rect := chunk_rect.grow(float(_config.chunk_size_m) * 1.25)
		spawn_result = _build_spawn_result(chunk_key, district_id, district_profile, _road_graph.get_edges_intersecting_rect(expanded_rect))
		spawn_slots = spawn_result.get("spawn_slots", [])
		road_class_counts = spawn_result.get("road_class_counts", {})

	return {
		"chunk_id": chunk_id,
		"chunk_key": chunk_key,
		"district_id": district_id,
		"district_key": district_key,
		"lane_page_id": "ped_page_%s" % [chunk_id],
		"density_bucket": str(district_profile.get("density_bucket", "")),
		"density_scalar": district_density,
		"spawn_capacity": spawn_slots.size(),
		"spawn_slots": spawn_slots,
		"road_class_counts": road_class_counts.duplicate(true),
		"roster_signature": _build_roster_signature(chunk_id, district_profile, road_class_counts, spawn_slots),
	}

func _build_spawn_result(chunk_key: Vector2i, district_id: String, district_profile: Dictionary, road_edges: Array[Dictionary]) -> Dictionary:
	var road_class_counts: Dictionary = {}
	var spawn_slots: Array[Dictionary] = []
	var max_spawn_slots := int(_pedestrian_config.get_max_spawn_slots_per_chunk())
	var district_density := float(district_profile.get("density_scalar", 0.0))
	var slot_counter := 0

	for road_edge in road_edges:
		var edge: Dictionary = road_edge
		var road_id := str(edge.get("road_id", edge.get("edge_id", "")))
		var road_class := str(edge.get("class", "local"))
		var road_density := get_density_for_road_class(road_class)
		var slot_count := int(_pedestrian_config.get_spawn_slots_for_edge(district_density, road_density))
		if slot_count <= 0:
			continue
		road_class_counts[road_class] = int(road_class_counts.get(road_class, 0)) + slot_count
		for slot_index in range(slot_count):
			if spawn_slots.size() >= max_spawn_slots:
				break
			var side_label := "left" if slot_index % 2 == 0 else "right"
			var seed_salt := int(edge.get("seed", 0)) + slot_index * 53 + slot_counter * 11
			spawn_slots.append({
				"spawn_slot_id": "%s:%s:%02d" % [_config.format_chunk_id(chunk_key), road_id, slot_index],
				"lane_ref_id": _build_lane_ref_id(road_id, side_label, slot_index),
				"road_id": road_id,
				"road_class": road_class,
				"side": side_label,
				"district_id": district_id,
				"seed": _config.derive_seed("ped_spawn_slot", chunk_key, seed_salt),
				"archetype_weights": (district_profile.get("archetype_weights", {}) as Dictionary).duplicate(true),
			})
			slot_counter += 1
		if spawn_slots.size() >= max_spawn_slots:
			break

	return {
		"road_class_counts": road_class_counts,
		"spawn_slots": spawn_slots,
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

func _build_lane_ref_id(road_id: String, side_label: String, slot_index: int) -> String:
	return "ped_lane_ref_%s_%s_%02d" % [road_id, side_label, slot_index]

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
