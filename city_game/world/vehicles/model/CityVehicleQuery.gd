extends RefCounted

var _config = null
var _vehicle_config = null
var _road_graph = null
var _lane_graph = null
var _district_profiles_by_id: Dictionary = {}
var _world_stats: Dictionary = {}

func setup(config, vehicle_config, road_graph, lane_graph, district_profiles_by_id: Dictionary) -> void:
	_config = config
	_vehicle_config = vehicle_config
	_road_graph = road_graph
	_lane_graph = lane_graph
	_district_profiles_by_id = district_profiles_by_id.duplicate(true)
	var profile_snapshot: Dictionary = _vehicle_config.to_snapshot()
	_world_stats = {
		"district_profile_count": _district_profiles_by_id.size(),
		"district_class_count": int((profile_snapshot.get("district_class_density", {}) as Dictionary).size()),
		"road_class_count": int((profile_snapshot.get("road_class_density", {}) as Dictionary).size()),
		"max_spawn_slots_per_chunk": int(profile_snapshot.get("max_spawn_slots_per_chunk", 0)),
		"lane_count": int(_lane_graph.get_lane_count()),
		"driving_lane_count": int(_lane_graph.get_lane_type_count("driving")),
		"intersection_turn_contract_count": int(_lane_graph.get_intersection_turn_contract_count()),
	}

func get_world_stats() -> Dictionary:
	return _world_stats.duplicate(true)

func get_profile_snapshot() -> Dictionary:
	return _vehicle_config.to_snapshot()

func get_lane_graph():
	return _lane_graph

func get_density_for_district_class(district_class: String) -> float:
	return float(_vehicle_config.get_density_for_district_class(district_class))

func get_density_for_road_class(road_class: String) -> float:
	return float(_vehicle_config.get_density_for_road_class(road_class))

func get_min_headway_for_road_class(road_class: String) -> float:
	return float(_vehicle_config.get_min_headway_for_road_class(road_class))

func get_profile_for_district(district_id: String) -> Dictionary:
	if not _district_profiles_by_id.has(district_id):
		return {}
	return (_district_profiles_by_id[district_id] as Dictionary).duplicate(true)

func get_vehicle_query_for_chunk(chunk_key: Vector2i) -> Dictionary:
	var chunk_id: String = _config.format_chunk_id(chunk_key)
	var district_key := _chunk_to_district_key(chunk_key)
	var district_id: String = _config.format_district_id(district_key)
	var district_profile: Dictionary = get_profile_for_district(district_id)
	var chunk_rect := _build_chunk_rect(chunk_key)
	var district_density := float(district_profile.get("density_scalar", 0.0))
	var lane_rect := chunk_rect.grow(float(_config.chunk_size_m) * 0.35)
	var chunk_lanes: Array = _lane_graph.get_lanes_intersecting_rect(lane_rect, ["driving"])
	var spawn_result: Dictionary = _build_spawn_result(chunk_key, district_id, district_profile, chunk_lanes, chunk_rect)
	var spawn_slots: Array = spawn_result.get("spawn_slots", [])
	var road_class_counts: Dictionary = spawn_result.get("road_class_counts", {})
	var lane_ids: Array = spawn_result.get("lane_ids", [])
	if spawn_slots.is_empty():
		var expanded_rect := chunk_rect.grow(float(_config.chunk_size_m) * 1.25)
		chunk_lanes = _lane_graph.get_lanes_intersecting_rect(expanded_rect, ["driving"])
		spawn_result = _build_spawn_result(chunk_key, district_id, district_profile, chunk_lanes, chunk_rect.grow(float(_config.chunk_size_m) * 0.35))
		spawn_slots = spawn_result.get("spawn_slots", [])
		road_class_counts = spawn_result.get("road_class_counts", {})
		lane_ids = spawn_result.get("lane_ids", [])

	return {
		"chunk_id": chunk_id,
		"chunk_key": chunk_key,
		"district_id": district_id,
		"district_key": district_key,
		"lane_page_id": "veh_page_%s" % [chunk_id],
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
	var sorted_lanes: Array = chunk_lanes.duplicate(true)
	sorted_lanes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("lane_id", "")) < str(b.get("lane_id", ""))
	)
	var lane_ids: Array[String] = []
	var max_spawn_slots := int(_vehicle_config.get_max_spawn_slots_per_chunk())
	var district_density := float(district_profile.get("density_scalar", 0.0))
	var chunk_id: String = _config.format_chunk_id(chunk_key)
	var lane_candidates_by_direction := {
		"forward": [],
		"backward": [],
		"other": [],
	}

	for lane_variant in sorted_lanes:
		var lane: Dictionary = lane_variant
		var lane_id := str(lane.get("lane_id", ""))
		lane_ids.append(lane_id)
		var road_class := str(lane.get("road_class", "local"))
		var headway_m := get_min_headway_for_road_class(road_class)
		var candidate_samples := _collect_candidate_samples_in_rect(lane.get("points", []), headway_m, spawn_rect)
		if candidate_samples.is_empty():
			continue
		var density_factor := clampf(district_density * get_density_for_road_class(road_class), 0.0, 1.0)
		var selected_count := _resolve_selected_slot_count(candidate_samples.size(), density_factor)
		if selected_count <= 0:
			continue
		var selected_indices := _pick_evenly_spaced_indices(candidate_samples.size(), selected_count)
		var direction_bucket := _resolve_direction_bucket(str(lane.get("direction", "")))
		(lane_candidates_by_direction[direction_bucket] as Array).append({
			"lane": lane.duplicate(true),
			"road_class": road_class,
			"headway_m": headway_m,
			"candidate_samples": candidate_samples.duplicate(true),
			"selected_indices": selected_indices.duplicate(true),
			"next_pick_index": 0,
		})

	var ordered_candidates := _build_balanced_lane_candidate_order(lane_candidates_by_direction)
	var has_pending_candidates := true
	while spawn_slots.size() < max_spawn_slots and has_pending_candidates:
		has_pending_candidates = false
		for candidate_index in range(ordered_candidates.size()):
			var candidate: Dictionary = ordered_candidates[candidate_index]
			var selected_indices: Array = candidate.get("selected_indices", [])
			var next_pick_index := int(candidate.get("next_pick_index", 0))
			if next_pick_index >= selected_indices.size():
				continue
			has_pending_candidates = true
			var lane: Dictionary = candidate.get("lane", {})
			var lane_id := str(lane.get("lane_id", ""))
			var road_class := str(candidate.get("road_class", lane.get("road_class", "local")))
			var headway_m := float(candidate.get("headway_m", 0.0))
			var candidate_samples: Array = candidate.get("candidate_samples", [])
			while next_pick_index < selected_indices.size():
				var selected_index := int(selected_indices[next_pick_index])
				next_pick_index += 1
				if selected_index < 0 or selected_index >= candidate_samples.size():
					continue
				var sample: Dictionary = candidate_samples[selected_index]
				if not _is_spawn_slot_spacing_clear(spawn_slots, sample, lane, headway_m):
					continue
				var seed_salt := int(lane.get("seed", 0)) + selected_index * 53 + spawn_slots.size() * 19
				spawn_slots.append({
					"spawn_slot_id": "%s:%s:%02d" % [chunk_id, lane_id, selected_index],
					"lane_ref_id": lane_id,
					"road_id": str(lane.get("road_id", "")),
					"road_class": road_class,
					"lane_type": "driving",
					"direction": str(lane.get("direction", "")),
					"district_id": district_id,
					"seed": _config.derive_seed("veh_spawn_slot", chunk_key, seed_salt),
					"world_position": sample.get("world_position", Vector3.ZERO),
					"heading_deg": float(sample.get("heading_deg", 0.0)),
					"distance_along_lane_m": float(sample.get("distance_along_lane_m", 0.0)),
					"min_headway_m": headway_m,
				})
				road_class_counts[road_class] = int(road_class_counts.get(road_class, 0)) + 1
				break
			candidate["next_pick_index"] = next_pick_index
			ordered_candidates[candidate_index] = candidate
			if spawn_slots.size() >= max_spawn_slots:
				break

	return {
		"road_class_counts": road_class_counts,
		"spawn_slots": spawn_slots,
		"lane_ids": lane_ids,
	}

func _resolve_selected_slot_count(candidate_count: int, density_factor: float) -> int:
	if candidate_count <= 0 or density_factor <= 0.54:
		return 0
	var raw_count := int(round(float(candidate_count) * density_factor))
	if raw_count <= 0 and density_factor >= 0.6:
		raw_count = 1
	return clampi(raw_count, 0, candidate_count)

func _is_spawn_slot_spacing_clear(existing_slots: Array[Dictionary], sample: Dictionary, lane: Dictionary, min_headway_m: float) -> bool:
	var candidate_position: Vector3 = sample.get("world_position", Vector3.ZERO)
	var candidate_lane_id := str(lane.get("lane_id", ""))
	var candidate_road_id := str(lane.get("road_id", ""))
	var candidate_direction := str(lane.get("direction", ""))
	var candidate_distance := float(sample.get("distance_along_lane_m", 0.0))
	for slot in existing_slots:
		var existing_position: Vector3 = slot.get("world_position", Vector3.ZERO)
		var existing_lane_id := str(slot.get("lane_ref_id", ""))
		var existing_road_id := str(slot.get("road_id", ""))
		var existing_direction := str(slot.get("direction", ""))
		var existing_headway_m := float(slot.get("min_headway_m", min_headway_m))
		var required_headway_m := maxf(min_headway_m, existing_headway_m)
		var world_gap_m := existing_position.distance_to(candidate_position)
		if existing_lane_id == candidate_lane_id:
			var existing_distance := float(slot.get("distance_along_lane_m", 0.0))
			if absf(existing_distance - candidate_distance) + 0.01 < required_headway_m - 0.5:
				return false
			continue
		if existing_road_id == candidate_road_id:
			if existing_direction == candidate_direction:
				if world_gap_m < maxf(required_headway_m * 0.85, 12.0):
					return false
			elif world_gap_m < 2.75:
				return false
			continue
		if world_gap_m < 4.5:
			return false
	return true

func _build_balanced_lane_candidate_order(lane_candidates_by_direction: Dictionary) -> Array:
	var forward_candidates: Array = (lane_candidates_by_direction.get("forward", []) as Array).duplicate(true)
	var backward_candidates: Array = (lane_candidates_by_direction.get("backward", []) as Array).duplicate(true)
	var other_candidates: Array = (lane_candidates_by_direction.get("other", []) as Array).duplicate(true)
	for candidates in [forward_candidates, backward_candidates, other_candidates]:
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_lane: Dictionary = a.get("lane", {})
			var b_lane: Dictionary = b.get("lane", {})
			var a_road_id := str(a_lane.get("road_id", ""))
			var b_road_id := str(b_lane.get("road_id", ""))
			if a_road_id == b_road_id:
				return str(a_lane.get("lane_id", "")) < str(b_lane.get("lane_id", ""))
			return a_road_id < b_road_id
		)
	var ordered_candidates: Array = []
	var max_count := maxi(forward_candidates.size(), maxi(backward_candidates.size(), other_candidates.size()))
	for candidate_index in range(max_count):
		if candidate_index < forward_candidates.size():
			ordered_candidates.append(forward_candidates[candidate_index])
		if candidate_index < backward_candidates.size():
			ordered_candidates.append(backward_candidates[candidate_index])
		if candidate_index < other_candidates.size():
			ordered_candidates.append(other_candidates[candidate_index])
	return ordered_candidates

func _resolve_direction_bucket(direction: String) -> String:
	if direction == "forward":
		return "forward"
	if direction == "backward":
		return "backward"
	return "other"

func _pick_evenly_spaced_indices(total_count: int, selected_count: int) -> Array[int]:
	var indices: Array[int] = []
	if total_count <= 0 or selected_count <= 0:
		return indices
	if selected_count >= total_count:
		for index in range(total_count):
			indices.append(index)
		return indices
	var used: Dictionary = {}
	for pick_index in range(selected_count):
		var raw_position := (float(pick_index) + 0.5) * float(total_count) / float(selected_count)
		var candidate := clampi(int(floor(raw_position)), 0, total_count - 1)
		while used.has(candidate) and candidate < total_count - 1:
			candidate += 1
		while used.has(candidate) and candidate > 0:
			candidate -= 1
		if used.has(candidate):
			continue
		used[candidate] = true
		indices.append(candidate)
	indices.sort()
	return indices

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

func _collect_candidate_samples_in_rect(points: Array, spacing_m: float, rect: Rect2) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var total_length := _compute_lane_length(points)
	if total_length <= spacing_m * 0.5:
		return candidates
	var distance_cursor := spacing_m * 0.5
	while distance_cursor < total_length:
		var sample := _sample_lane_position_by_distance(points, distance_cursor)
		var world_position: Vector3 = sample.get("world_position", Vector3.ZERO)
		if rect.has_point(Vector2(world_position.x, world_position.z)):
			candidates.append({
				"world_position": world_position,
				"distance_along_lane_m": distance_cursor,
				"heading_deg": float(sample.get("heading_deg", 0.0)),
			})
		distance_cursor += spacing_m
	return candidates

func _sample_lane_position_by_distance(points: Array, target_distance: float) -> Dictionary:
	if points.is_empty():
		return {}
	if points.size() == 1:
		return {
			"world_position": points[0],
			"heading_deg": 0.0,
		}
	var traversed := 0.0
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var segment_length := a.distance_to(b)
		if traversed + segment_length >= target_distance:
			var t := 0.0 if segment_length <= 0.001 else (target_distance - traversed) / segment_length
			var tangent := (b - a).normalized()
			return {
				"world_position": a.lerp(b, clampf(t, 0.0, 1.0)),
				"heading_deg": _heading_from_vector3(tangent),
			}
		traversed += segment_length
	var last: Vector3 = points[points.size() - 1]
	var previous: Vector3 = points[points.size() - 2]
	return {
		"world_position": last,
		"heading_deg": _heading_from_vector3((last - previous).normalized()),
	}

func _compute_lane_length(points: Array) -> float:
	if points.size() <= 1:
		return 0.0
	var total_length := 0.0
	for point_index in range(points.size() - 1):
		total_length += (points[point_index + 1] as Vector3).distance_to(points[point_index] as Vector3)
	return total_length

func _heading_from_vector3(direction: Vector3) -> float:
	var heading := fposmod(rad_to_deg(atan2(direction.x, direction.z)), 360.0)
	if heading >= 359.999:
		return 0.0
	return heading
