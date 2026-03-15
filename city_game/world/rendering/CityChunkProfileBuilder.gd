extends RefCounted

const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

const ROAD_CLEARANCE_M := 6.0
const BUILDING_MARGIN_M := 3.0
const CANDIDATE_STEP_M := 22.0
const MAX_BUILDINGS_PER_CHUNK := 20
const INFILL_TARGET_EXTRA := 6
const ROAD_ALIGNMENT_DELTA_MAX_DEG := 18.0
const INFILL_CLEARANCE_MIN_M := 10.0
const INFILL_CLEARANCE_TARGET_M := 22.0
const INFILL_CLEARANCE_MAX_M := 84.0

const PALETTES := [
	{
		"ground": Color(0.117647, 0.305882, 0.156863, 1.0),
		"road": Color(0.145098, 0.156863, 0.176471, 1.0),
		"stripe": Color(0.905882, 0.803922, 0.486275, 1.0),
		"base": Color(0.709804, 0.72549, 0.776471, 1.0),
		"accent": Color(0.482353, 0.603922, 0.709804, 1.0),
		"mid": Color(0.427451, 0.486275, 0.556863, 1.0),
		"far": Color(0.286275, 0.337255, 0.396078, 1.0),
	},
	{
		"ground": Color(0.145098, 0.298039, 0.188235, 1.0),
		"road": Color(0.184314, 0.176471, 0.168627, 1.0),
		"stripe": Color(0.8, 0.67451, 0.372549, 1.0),
		"base": Color(0.772549, 0.67451, 0.611765, 1.0),
		"accent": Color(0.631373, 0.454902, 0.376471, 1.0),
		"mid": Color(0.556863, 0.45098, 0.392157, 1.0),
		"far": Color(0.372549, 0.290196, 0.258824, 1.0),
	},
	{
		"ground": Color(0.12549, 0.258824, 0.180392, 1.0),
		"road": Color(0.156863, 0.172549, 0.196078, 1.0),
		"stripe": Color(0.737255, 0.784314, 0.827451, 1.0),
		"base": Color(0.615686, 0.741176, 0.705882, 1.0),
		"accent": Color(0.286275, 0.509804, 0.478431, 1.0),
		"mid": Color(0.32549, 0.486275, 0.458824, 1.0),
		"far": Color(0.215686, 0.321569, 0.317647, 1.0),
	},
	{
		"ground": Color(0.113725, 0.278431, 0.192157, 1.0),
		"road": Color(0.14902, 0.160784, 0.168627, 1.0),
		"stripe": Color(0.905882, 0.643137, 0.435294, 1.0),
		"base": Color(0.686275, 0.701961, 0.611765, 1.0),
		"accent": Color(0.823529, 0.533333, 0.321569, 1.0),
		"mid": Color(0.490196, 0.486275, 0.396078, 1.0),
		"far": Color(0.337255, 0.333333, 0.282353, 1.0),
	},
]

const BUILDING_ARCHETYPES := [
	{
		"id": "slab",
		"min_size": Vector2(20.0, 32.0),
		"max_size": Vector2(28.0, 46.0),
		"height_range": Vector2(22.0, 38.0),
	},
	{
		"id": "needle",
		"min_size": Vector2(16.0, 18.0),
		"max_size": Vector2(22.0, 24.0),
		"height_range": Vector2(44.0, 82.0),
	},
	{
		"id": "courtyard",
		"min_size": Vector2(28.0, 28.0),
		"max_size": Vector2(40.0, 40.0),
		"height_range": Vector2(18.0, 32.0),
	},
	{
		"id": "podium_tower",
		"min_size": Vector2(18.0, 18.0),
		"max_size": Vector2(24.0, 24.0),
		"height_range": Vector2(34.0, 64.0),
		"footprint_scale": 1.9,
	},
	{
		"id": "step_midrise",
		"min_size": Vector2(22.0, 26.0),
		"max_size": Vector2(34.0, 40.0),
		"height_range": Vector2(20.0, 40.0),
	},
	{
		"id": "midrise_bar",
		"min_size": Vector2(20.0, 40.0),
		"max_size": Vector2(28.0, 56.0),
		"height_range": Vector2(16.0, 30.0),
	},
	{
		"id": "industrial",
		"min_size": Vector2(28.0, 34.0),
		"max_size": Vector2(44.0, 60.0),
		"height_range": Vector2(10.0, 20.0),
	},
]

static func build_profile(chunk_data: Dictionary) -> Dictionary:
	var build_started_usec := Time.get_ticks_usec()
	var chunk_key: Vector2i = chunk_data.get("chunk_key", Vector2i.ZERO)
	var chunk_center: Vector3 = chunk_data.get("chunk_center", Vector3.ZERO)
	var chunk_size_m := float(chunk_data.get("chunk_size_m", 256.0))
	var chunk_seed := int(chunk_data.get("chunk_seed", _fallback_seed(chunk_key)))
	var world_seed := int(chunk_data.get("world_seed", chunk_seed))
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed

	var palette_index := int(posmod(chunk_seed, PALETTES.size()))
	var palette: Dictionary = PALETTES[palette_index]
	var road_layout_started_usec := Time.get_ticks_usec()
	var road_layout: Dictionary = CityRoadLayoutBuilder.build_chunk_roads(chunk_data)
	var road_layout_usec := Time.get_ticks_usec() - road_layout_started_usec
	var road_segments: Array = road_layout.get("segments", [])
	var buildings_started_usec := Time.get_ticks_usec()
	var building_result: Dictionary = _build_buildings(chunk_center, chunk_size_m, chunk_seed, world_seed, road_segments)
	var buildings_usec := Time.get_ticks_usec() - buildings_started_usec
	var buildings: Array = building_result.get("buildings", [])
	var building_layout_stats: Dictionary = (building_result.get("layout_stats", {}) as Dictionary).duplicate(true)
	var building_archetype_ids := _collect_building_archetypes(buildings)
	var terrain_relief_started_usec := Time.get_ticks_usec()
	var terrain_relief := _measure_terrain_relief(chunk_center, chunk_size_m, world_seed)
	var terrain_relief_usec := Time.get_ticks_usec() - terrain_relief_started_usec
	var min_clearance := _measure_min_building_clearance(buildings)
	var road_semantic_stats_started_usec := Time.get_ticks_usec()
	var road_semantic_consumer_stats := _build_road_semantic_consumer_stats(road_segments)
	var road_semantic_stats_usec := Time.get_ticks_usec() - road_semantic_stats_started_usec
	var profile := {
		"variant_id": "p%d-r%d-b%d-a%d" % [palette_index, road_segments.size(), buildings.size(), building_archetype_ids.size()],
		"palette": palette.duplicate(true),
		"buildings": buildings,
		"building_count": buildings.size(),
		"building_archetype_ids": building_archetype_ids,
		"min_building_road_clearance_m": min_clearance,
		"road_segments": road_segments,
		"road_boundary_connectors": road_layout.get("connectors", {
			"north": [],
			"south": [],
			"east": [],
			"west": [],
		}),
		"curved_road_segment_count": int(road_layout.get("curved_segment_count", 0)),
		"non_axis_road_segment_count": int(road_layout.get("non_axis_road_segment_count", 0)),
		"bridge_count": int(road_layout.get("bridge_count", 0)),
		"road_mesh_mode": str(road_layout.get("road_mesh_mode", "ribbon")),
		"road_signature": str(road_layout.get("signature", "")),
		"road_template_counts": (road_layout.get("road_template_counts", {}) as Dictionary).duplicate(true),
		"road_semantic_consumer_stats": road_semantic_consumer_stats,
		"bridge_min_clearance_m": float(road_layout.get("bridge_min_clearance_m", 0.0)),
		"bridge_deck_thickness_m": float(road_layout.get("bridge_deck_thickness_m", 0.0)),
		"terrain_relief_m": terrain_relief,
		"building_layout_stats": building_layout_stats,
		"build_profile_stats": {},
		"signature": "",
	}
	var signature_started_usec := Time.get_ticks_usec()
	profile["signature"] = _build_signature(profile, str(road_layout.get("signature", "")))
	var signature_usec := Time.get_ticks_usec() - signature_started_usec
	profile["build_profile_stats"] = {
		"road_layout_usec": road_layout_usec,
		"buildings_usec": buildings_usec,
		"terrain_relief_usec": terrain_relief_usec,
		"road_semantic_stats_usec": road_semantic_stats_usec,
		"signature_usec": signature_usec,
		"total_usec": Time.get_ticks_usec() - build_started_usec,
	}
	return profile

static func _build_buildings(chunk_center: Vector3, chunk_size_m: float, chunk_seed: int, world_seed: int, road_segments: Array) -> Dictionary:
	if road_segments.is_empty():
		return {
			"buildings": [],
			"layout_stats": _build_building_layout_stats([], [], []),
		}
	var candidate_keys: Dictionary = {}
	var streetfront_candidates := _build_streetfront_candidates(chunk_center, chunk_size_m, chunk_seed, road_segments, candidate_keys)
	var infill_candidates := _build_infill_candidates(chunk_center, chunk_size_m, chunk_seed, road_segments, candidate_keys)
	var desired_count := mini(MAX_BUILDINGS_PER_CHUNK, 14 + int((chunk_seed >> 1) % 4))
	var minimum_dense_target := mini(MAX_BUILDINGS_PER_CHUNK, 12)
	var streetfront_cycle := _build_streetfront_archetype_cycle(chunk_seed)
	var archetype_cycle := _build_archetype_cycle(chunk_seed)
	var compact_cycle := _build_compact_archetype_cycle()
	var building_rng := RandomNumberGenerator.new()
	var buildings: Array = []
	var occupied: Array = []
	var half_extent := chunk_size_m * 0.5 - 10.0

	for candidate_index in range(streetfront_candidates.size()):
		if buildings.size() >= desired_count:
			break
		var candidate: Dictionary = streetfront_candidates[candidate_index]
		var archetype: Dictionary = streetfront_cycle[candidate_index % streetfront_cycle.size()]
		var building := _try_build_building(candidate, archetype, chunk_center, half_extent, world_seed, occupied, building_rng)
		if building.is_empty():
			continue
		buildings.append(building)
		_append_occupied_entry(occupied, building)

	if buildings.size() < desired_count:
		for candidate_index in range(streetfront_candidates.size()):
			if buildings.size() >= desired_count:
				break
			var candidate: Dictionary = streetfront_candidates[candidate_index]
			var compact_streetfront_archetype: Dictionary = compact_cycle[candidate_index % compact_cycle.size()]
			var compact_streetfront := _try_build_building(candidate, compact_streetfront_archetype, chunk_center, half_extent, world_seed, occupied, building_rng, 0.74)
			if compact_streetfront.is_empty():
				continue
			buildings.append(compact_streetfront)
			_append_occupied_entry(occupied, compact_streetfront)

	var streetfront_building_count := buildings.size()
	var streetfront_ratio_cap := streetfront_building_count + int(floor(float(streetfront_building_count) * 0.428571))
	var infill_total_cap := mini(
		MAX_BUILDINGS_PER_CHUNK,
		maxi(minimum_dense_target, streetfront_ratio_cap)
	)

	if buildings.size() < desired_count:
		for candidate_index in range(infill_candidates.size()):
			if buildings.size() >= mini(infill_total_cap, desired_count + INFILL_TARGET_EXTRA):
				break
			var candidate: Dictionary = infill_candidates[candidate_index]
			var filler_archetype: Dictionary = archetype_cycle[candidate_index % archetype_cycle.size()]
			var filler := _try_build_building(candidate, filler_archetype, chunk_center, half_extent, world_seed, occupied, building_rng, 0.82)
			if filler.is_empty():
				continue
			buildings.append(filler)
			_append_occupied_entry(occupied, filler)

	if buildings.size() < mini(minimum_dense_target, infill_total_cap):
		for candidate_index in range(infill_candidates.size()):
			if buildings.size() >= mini(minimum_dense_target, infill_total_cap):
				break
			var candidate: Dictionary = infill_candidates[candidate_index]
			var compact_archetype: Dictionary = compact_cycle[candidate_index % compact_cycle.size()]
			var compact := _try_build_building(candidate, compact_archetype, chunk_center, half_extent, world_seed, occupied, building_rng, 0.68)
			if compact.is_empty():
				continue
			buildings.append(compact)
			_append_occupied_entry(occupied, compact)

	return {
		"buildings": buildings,
		"layout_stats": _build_building_layout_stats(buildings, streetfront_candidates, infill_candidates),
	}

static func _build_streetfront_candidates(chunk_center: Vector3, chunk_size_m: float, chunk_seed: int, road_segments: Array, candidate_keys: Dictionary) -> Array:
	var half_extent := chunk_size_m * 0.5 - 18.0
	var candidates: Array = []
	for segment_index in range(road_segments.size()):
		var segment: Dictionary = road_segments[segment_index]
		var road_class := str(segment.get("class", "local"))
		if road_class == "expressway_elevated":
			continue
		var points: Array = segment.get("points", [])
		if points.size() < 2:
			continue
		var road_width := float(segment.get("width", 12.0))
		var step_m := _streetfront_step_for_class(road_class)
		var setback_m := _streetfront_setback_for_class(road_class) + road_width * 0.5
		var class_bias := 12.0
		match road_class:
			"arterial":
				class_bias = 18.0
			"service":
				class_bias = 8.0
		for point_index in range(points.size() - 1):
			var start_point: Vector3 = points[point_index]
			var end_point: Vector3 = points[point_index + 1]
			var start_2d := Vector2(start_point.x, start_point.z)
			var end_2d := Vector2(end_point.x, end_point.z)
			var direction_2d := end_2d - start_2d
			var segment_length := direction_2d.length()
			if segment_length < 12.0:
				continue
			var tangent := direction_2d / segment_length
			var normal := Vector2(-tangent.y, tangent.x)
			var road_angle_rad := atan2(tangent.y, tangent.x)
			var sample_count := maxi(int(floor(segment_length / step_m)), 1)
			for sample_index in range(sample_count):
				var sample_ratio := (float(sample_index) + 0.5) / float(sample_count)
				var sample_point := start_2d.lerp(end_2d, sample_ratio)
				for side_sign in [-1.0, 1.0]:
					var center_2d := _clamp_to_chunk(sample_point + normal * side_sign * setback_m, half_extent)
					var position_key := _candidate_position_key(center_2d)
					if candidate_keys.has(position_key):
						continue
					var road_metrics := _nearest_road_metrics(center_2d, road_segments)
					var clearance := float(road_metrics.get("clearance_m", 9999.0))
					if clearance < setback_m * 0.7:
						continue
					var radial_bias := center_2d.length() / maxf(half_extent, 1.0)
					var score := 118.0 + class_bias - absf(clearance - setback_m) * 0.65 - radial_bias * 10.0
					var candidate := {
						"center_2d": center_2d,
						"clearance": clearance,
						"road_angle_rad": road_angle_rad,
						"score": score,
						"seed": _streetfront_candidate_seed(chunk_seed, road_class, center_2d, side_sign),
						"world_center": Vector2(chunk_center.x + center_2d.x, chunk_center.z + center_2d.y),
						"candidate_kind": "streetfront",
						"road_class": road_class,
					}
					candidate_keys[position_key] = true
					candidates.append(candidate)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	return candidates

static func _build_infill_candidates(chunk_center: Vector3, chunk_size_m: float, chunk_seed: int, road_segments: Array, candidate_keys: Dictionary) -> Array:
	if road_segments.is_empty():
		return []
	var half_extent := chunk_size_m * 0.5 - 18.0
	var candidates: Array = []
	for x_step in range(int(floor((-half_extent) / CANDIDATE_STEP_M)), int(ceil(half_extent / CANDIDATE_STEP_M)) + 1):
		for z_step in range(int(floor((-half_extent) / CANDIDATE_STEP_M)), int(ceil(half_extent / CANDIDATE_STEP_M)) + 1):
			var slot_seed := _slot_seed(chunk_seed, x_step, z_step)
			var center_2d := Vector2(
				float(x_step) * CANDIDATE_STEP_M + sin(float(slot_seed % 4096) * 0.011) * 5.5,
				float(z_step) * CANDIDATE_STEP_M + cos(float((slot_seed >> 2) % 4096) * 0.013) * 5.5
			)
			center_2d = _clamp_to_chunk(center_2d, half_extent)
			var position_key := _candidate_position_key(center_2d)
			if candidate_keys.has(position_key):
				continue
			var road_metrics := _nearest_road_metrics(center_2d, road_segments, 8.0)
			var clearance := float(road_metrics.get("clearance_m", 9999.0))
			if clearance < INFILL_CLEARANCE_MIN_M or clearance > INFILL_CLEARANCE_MAX_M:
				continue
			var radial_bias := center_2d.length() / maxf(half_extent, 1.0)
			var score := 42.0 - absf(clearance - INFILL_CLEARANCE_TARGET_M) * 1.1 - radial_bias * 11.0 + sin(float(slot_seed % 2048) * 0.021) * 4.0
			candidate_keys[position_key] = true
			candidates.append({
				"center_2d": center_2d,
				"clearance": clearance,
				"road_angle_rad": float(road_metrics.get("angle_rad", 0.0)),
				"score": score,
				"seed": slot_seed,
				"world_center": Vector2(chunk_center.x + center_2d.x, chunk_center.z + center_2d.y),
				"candidate_kind": "infill",
				"road_class": "local",
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	return candidates

static func _try_build_building(candidate: Dictionary, archetype: Dictionary, chunk_center: Vector3, half_extent: float, world_seed: int, occupied: Array, building_rng: RandomNumberGenerator, scale_multiplier: float = 1.0) -> Dictionary:
	var local_seed := int(candidate.get("seed", 0)) ^ int(archetype.get("id", "").hash())
	building_rng.seed = local_seed
	var min_size: Vector2 = archetype.get("min_size", Vector2(18.0, 18.0))
	var max_size: Vector2 = archetype.get("max_size", Vector2(28.0, 28.0))
	var height_range: Vector2 = archetype.get("height_range", Vector2(18.0, 36.0))
	var footprint_scale := float(archetype.get("footprint_scale", 1.0))
	var candidate_clearance := float(candidate.get("clearance", ROAD_CLEARANCE_M + 12.0))
	var parcel_scale := clampf((candidate_clearance - ROAD_CLEARANCE_M) / 18.0, 0.72, 1.0)
	if str(candidate.get("candidate_kind", "")) == "streetfront":
		parcel_scale = minf(parcel_scale, 0.84)
	var width := snappedf(building_rng.randf_range(min_size.x, max_size.x) * scale_multiplier * parcel_scale, 2.0)
	var depth := snappedf(building_rng.randf_range(min_size.y, max_size.y) * scale_multiplier * parcel_scale, 2.0)
	var height := snappedf(building_rng.randf_range(height_range.x, height_range.y) * lerpf(0.92, 1.08, building_rng.randf()), 2.0)
	var center_2d: Vector2 = candidate.get("center_2d", Vector2.ZERO)
	var footprint_radius := sqrt(width * width + depth * depth) * 0.5
	var visual_width := width * footprint_scale
	var visual_depth := depth * footprint_scale
	var visual_footprint_radius := sqrt(visual_width * visual_width + visual_depth * visual_depth) * 0.5
	var road_clearance := float(candidate.get("clearance", 0.0)) - footprint_radius
	var visual_road_clearance := float(candidate.get("clearance", 0.0)) - visual_footprint_radius
	if visual_road_clearance < ROAD_CLEARANCE_M:
		return {}
	if absf(center_2d.x) + visual_width * 0.5 >= half_extent or absf(center_2d.y) + visual_depth * 0.5 >= half_extent:
		return {}
	for occupied_item in occupied:
		var occupied_dict: Dictionary = occupied_item
		var other_center: Vector2 = occupied_dict.get("center_2d", Vector2.ZERO)
		var other_radius := float(occupied_dict.get("radius", 0.0))
		if center_2d.distance_to(other_center) < visual_footprint_radius + other_radius + BUILDING_MARGIN_M:
			return {}

	var road_angle_rad := float(candidate.get("road_angle_rad", 0.0))
	var yaw_rad := _resolve_building_yaw(road_angle_rad, local_seed, archetype.get("id", "slab"))
	var world_center: Vector2 = candidate.get("world_center", Vector2(chunk_center.x + center_2d.x, chunk_center.z + center_2d.y))
	var ground_y := CityTerrainSampler.sample_height(world_center.x, world_center.y, world_seed)
	var palette: Dictionary = PALETTES[int(posmod(local_seed, PALETTES.size()))]
	var road_alignment_delta_deg := _measure_street_alignment_delta_deg(yaw_rad, road_angle_rad)
	return {
		"name": "Building_%d_%s" % [abs(local_seed % 10000), str(archetype.get("id", "mass"))],
		"archetype_id": str(archetype.get("id", "mass")),
		"center": Vector3(center_2d.x, ground_y + height * 0.5, center_2d.y),
		"center_2d": center_2d,
		"size": Vector3(width, height, depth),
		"collision_size": Vector3(maxf(width, visual_width), height, maxf(depth, visual_depth)),
		"yaw_rad": yaw_rad,
		"road_angle_rad": road_angle_rad,
		"footprint_radius_m": footprint_radius,
		"visual_footprint_radius_m": visual_footprint_radius,
		"road_clearance_m": road_clearance,
		"visual_road_clearance_m": visual_road_clearance,
		"candidate_kind": str(candidate.get("candidate_kind", "infill")),
		"road_alignment_delta_deg": road_alignment_delta_deg,
		"detail_seed": local_seed,
		"main_color": _tint_color(palette["base"], building_rng.randf_range(-0.08, 0.08)),
		"accent_color": _tint_color(palette["accent"], building_rng.randf_range(-0.06, 0.10)),
		"roof_color": _tint_color(palette["mid"], building_rng.randf_range(-0.08, 0.06)),
	}

static func _append_occupied_entry(occupied: Array, building: Dictionary) -> void:
	occupied.append({
		"center_2d": building.get("center_2d", Vector2.ZERO),
		"radius": building.get("visual_footprint_radius_m", building.get("footprint_radius_m", 0.0)),
	})

static func _build_building_layout_stats(buildings: Array, streetfront_candidates: Array, infill_candidates: Array) -> Dictionary:
	var streetfront_building_count := 0
	var road_aligned_building_count := 0
	for building_variant in buildings:
		var building: Dictionary = building_variant
		if str(building.get("candidate_kind", "")) == "streetfront":
			streetfront_building_count += 1
		if float(building.get("road_alignment_delta_deg", 180.0)) <= ROAD_ALIGNMENT_DELTA_MAX_DEG:
			road_aligned_building_count += 1
	var building_count := float(buildings.size())
	return {
		"building_count": buildings.size(),
		"streetfront_candidate_count": streetfront_candidates.size(),
		"infill_candidate_count": infill_candidates.size(),
		"streetfront_building_count": streetfront_building_count,
		"road_aligned_building_count": road_aligned_building_count,
		"streetfront_building_ratio": 0.0 if building_count <= 0.0 else float(streetfront_building_count) / building_count,
		"road_aligned_building_ratio": 0.0 if building_count <= 0.0 else float(road_aligned_building_count) / building_count,
	}

static func _streetfront_candidate_seed(chunk_seed: int, road_class: String, center_2d: Vector2, side_sign: float) -> int:
	return int((
		chunk_seed * 31
		+ road_class.hash()
		+ int(round(center_2d.x * 10.0)) * 73856093
		+ int(round(center_2d.y * 10.0)) * 19349663
		+ int(sign(side_sign)) * 83492791
	) & 0x7fffffff)

static func _candidate_position_key(center_2d: Vector2) -> String:
	return "%d:%d" % [int(round(center_2d.x / 2.0)), int(round(center_2d.y / 2.0))]

static func _streetfront_step_for_class(road_class: String) -> float:
	match road_class:
		"arterial":
			return 36.0
		"service":
			return 24.0
	return 26.0

static func _streetfront_setback_for_class(road_class: String) -> float:
	match road_class:
		"arterial":
			return 42.0
		"service":
			return 30.0
	return 34.0

static func _measure_street_alignment_delta_deg(yaw_rad: float, road_angle_rad: float) -> float:
	var yaw_deg := rad_to_deg(yaw_rad)
	var road_deg := rad_to_deg(road_angle_rad)
	return minf(
		_angle_delta_deg(yaw_deg, road_deg),
		_angle_delta_deg(yaw_deg, road_deg + 90.0)
	)

static func _angle_delta_deg(a_deg: float, b_deg: float) -> float:
	var delta := fmod(absf(a_deg - b_deg), 180.0)
	if delta > 90.0:
		delta = 180.0 - delta
	return absf(delta)

static func _build_streetfront_archetype_cycle(chunk_seed: int) -> Array:
	var archetypes: Array = [
		(BUILDING_ARCHETYPES[0] as Dictionary).duplicate(true),
		(BUILDING_ARCHETYPES[4] as Dictionary).duplicate(true),
		(BUILDING_ARCHETYPES[1] as Dictionary).duplicate(true),
		(BUILDING_ARCHETYPES[2] as Dictionary).duplicate(true),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed ^ 0x4C7F13
	for index in range(archetypes.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp = archetypes[index]
		archetypes[index] = archetypes[swap_index]
		archetypes[swap_index] = temp
	return archetypes

static func _build_archetype_cycle(chunk_seed: int) -> Array:
	var archetypes: Array = []
	for archetype in BUILDING_ARCHETYPES:
		archetypes.append((archetype as Dictionary).duplicate(true))
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed
	for index in range(archetypes.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp = archetypes[index]
		archetypes[index] = archetypes[swap_index]
		archetypes[swap_index] = temp
	return archetypes

static func _build_compact_archetype_cycle() -> Array:
	return [
		(BUILDING_ARCHETYPES[1] as Dictionary).duplicate(true),
		(BUILDING_ARCHETYPES[0] as Dictionary).duplicate(true),
		(BUILDING_ARCHETYPES[4] as Dictionary).duplicate(true),
		(BUILDING_ARCHETYPES[3] as Dictionary).duplicate(true),
	]

static func _resolve_building_yaw(road_angle_rad: float, local_seed: int, archetype_id: String) -> float:
	var angle := road_angle_rad
	if archetype_id == "needle" or archetype_id == "courtyard":
		return angle + deg_to_rad(float(local_seed % 18) - 9.0)
	if archetype_id == "midrise_bar" or archetype_id == "industrial":
		return angle + PI * 0.5
	return angle

static func _measure_min_building_clearance(buildings: Array) -> float:
	if buildings.is_empty():
		return 0.0
	var min_clearance := INF
	for building in buildings:
		min_clearance = minf(min_clearance, float((building as Dictionary).get("visual_road_clearance_m", (building as Dictionary).get("road_clearance_m", 0.0))))
	return min_clearance if min_clearance != INF else 0.0

static func _collect_building_archetypes(buildings: Array) -> Array:
	var unique: Dictionary = {}
	for building in buildings:
		var archetype_id := str((building as Dictionary).get("archetype_id", ""))
		if archetype_id != "":
			unique[archetype_id] = true
	var archetypes: Array = []
	for archetype_id in unique.keys():
		archetypes.append(str(archetype_id))
	archetypes.sort()
	return archetypes

static func _nearest_road_metrics(point: Vector2, road_segments: Array, early_exit_clearance: float = -1.0) -> Dictionary:
	var min_distance := INF
	var best_angle_rad := 0.0
	for segment in road_segments:
		var segment_dict: Dictionary = segment
		var width := float(segment_dict.get("width", 0.0))
		var points: Array = segment_dict.get("points", [])
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			var distance := _distance_to_segment(point, Vector2(a.x, a.z), Vector2(b.x, b.z)) - width * 0.5
			if distance < min_distance:
				min_distance = distance
				best_angle_rad = atan2(b.z - a.z, b.x - a.x)
				if early_exit_clearance >= 0.0 and min_distance <= early_exit_clearance:
					return {
						"clearance_m": min_distance,
						"angle_rad": best_angle_rad,
					}
	if min_distance == INF:
		return {
			"clearance_m": 9999.0,
			"angle_rad": 0.0,
		}
	return {
		"clearance_m": min_distance,
		"angle_rad": best_angle_rad,
	}

static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(a + segment * t)

static func _clamp_to_chunk(point: Vector2, half_extent: float) -> Vector2:
	return Vector2(
		clampf(point.x, -half_extent, half_extent),
		clampf(point.y, -half_extent, half_extent)
	)

static func _slot_seed(chunk_seed: int, x_step: int, z_step: int) -> int:
	return int((chunk_seed * 31 + x_step * 73856093 + z_step * 19349663) & 0x7fffffff)

static func _measure_terrain_relief(chunk_center: Vector3, chunk_size_m: float, world_seed: int) -> float:
	var half_size := chunk_size_m * 0.5
	var min_height := INF
	var max_height := -INF
	for x_index in range(4):
		for z_index in range(4):
			var position := Vector2(
				lerpf(-half_size, half_size, float(x_index) / 3.0),
				lerpf(-half_size, half_size, float(z_index) / 3.0)
			)
			var height := CityTerrainSampler.sample_height(chunk_center.x + position.x, chunk_center.z + position.y, world_seed)
			min_height = minf(min_height, height)
			max_height = maxf(max_height, height)
	return maxf(max_height - min_height, 0.0)

static func _build_signature(profile: Dictionary, road_signature: String) -> String:
	var signature_parts := PackedStringArray([road_signature])
	for building in profile.get("buildings", []):
		var building_dict: Dictionary = building
		var center: Vector3 = building_dict.get("center", Vector3.ZERO)
		var size: Vector3 = building_dict.get("size", Vector3.ZERO)
		signature_parts.append("%s:%.1f,%.1f,%.1f,%.1f,%.1f" % [
			str(building_dict.get("archetype_id", "mass")),
			center.x,
			center.z,
			size.x,
			size.y,
			size.z,
		])
	return "|".join(signature_parts)

static func _build_road_semantic_consumer_stats(road_segments: Array) -> Dictionary:
	var layout_segment_contract_count := 0
	var semantic_lane_schema_segment_count := 0
	var semantic_surface_width_segment_count := 0
	var semantic_marking_segment_count := 0
	var semantic_median_segment_count := 0
	var surface_semantic_ready_segment_count := 0
	var bridge_semantic_ready_segment_count := 0
	var semantic_marking_profile_counts: Dictionary = {}
	for road_segment in road_segments:
		var segment_dict: Dictionary = road_segment
		var section_semantics: Dictionary = (segment_dict.get("section_semantics", {}) as Dictionary)
		if section_semantics.is_empty():
			continue
		layout_segment_contract_count += 1
		var lane_schema: Dictionary = (section_semantics.get("lane_schema", {}) as Dictionary)
		var edge_profile: Dictionary = (section_semantics.get("edge_profile", {}) as Dictionary)
		if not lane_schema.is_empty():
			semantic_lane_schema_segment_count += 1
		if float(edge_profile.get("surface_half_width_m", 0.0)) > 0.0:
			semantic_surface_width_segment_count += 1
		if edge_profile.has("median_width_m"):
			semantic_median_segment_count += 1
		var marking_profile_id := str(section_semantics.get("marking_profile_id", ""))
		if marking_profile_id != "":
			semantic_marking_segment_count += 1
			semantic_marking_profile_counts[marking_profile_id] = int(semantic_marking_profile_counts.get(marking_profile_id, 0)) + 1
		var semantic_surface_ready := not lane_schema.is_empty() and float(edge_profile.get("surface_half_width_m", 0.0)) > 0.0 and marking_profile_id != ""
		if semantic_surface_ready and not bool(segment_dict.get("bridge", false)):
			surface_semantic_ready_segment_count += 1
		if semantic_surface_ready and bool(segment_dict.get("bridge", false)):
			bridge_semantic_ready_segment_count += 1
	return {
		"layout_segment_contract_count": layout_segment_contract_count,
		"semantic_lane_schema_segment_count": semantic_lane_schema_segment_count,
		"semantic_surface_width_segment_count": semantic_surface_width_segment_count,
		"semantic_marking_segment_count": semantic_marking_segment_count,
		"semantic_median_segment_count": semantic_median_segment_count,
		"surface_semantic_ready_segment_count": surface_semantic_ready_segment_count,
		"bridge_semantic_ready_segment_count": bridge_semantic_ready_segment_count,
		"semantic_marking_profile_counts": semantic_marking_profile_counts,
	}

static func _fallback_seed(chunk_key: Vector2i) -> int:
	return int((chunk_key.x * 92837111 + chunk_key.y * 689287499) & 0x7fffffff)

static func _tint_color(color: Color, delta: float) -> Color:
	if delta >= 0.0:
		return color.lerp(Color.WHITE, delta)
	return color.lerp(Color.BLACK, -delta)
