extends RefCounted

const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

const ROAD_CLEARANCE_M := 6.0
const BUILDING_MARGIN_M := 4.0
const CANDIDATE_STEP_M := 28.0
const MAX_BUILDINGS_PER_CHUNK := 18
const INFILL_TARGET_EXTRA := 4

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
	var chunk_key: Vector2i = chunk_data.get("chunk_key", Vector2i.ZERO)
	var chunk_center: Vector3 = chunk_data.get("chunk_center", Vector3.ZERO)
	var chunk_size_m := float(chunk_data.get("chunk_size_m", 256.0))
	var chunk_seed := int(chunk_data.get("chunk_seed", _fallback_seed(chunk_key)))
	var world_seed := int(chunk_data.get("world_seed", chunk_seed))
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed

	var palette_index := int(posmod(chunk_seed, PALETTES.size()))
	var palette: Dictionary = PALETTES[palette_index]
	var road_layout: Dictionary = CityRoadLayoutBuilder.build_chunk_roads(chunk_data)
	var road_segments: Array = road_layout.get("segments", [])
	var buildings: Array = _build_buildings(chunk_center, chunk_size_m, chunk_seed, world_seed, road_segments)
	var building_archetype_ids := _collect_building_archetypes(buildings)
	var terrain_relief := _measure_terrain_relief(chunk_center, chunk_size_m, world_seed)
	var min_clearance := _measure_min_building_clearance(buildings)
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
		"road_template_counts": (road_layout.get("road_template_counts", {}) as Dictionary).duplicate(true),
		"bridge_min_clearance_m": float(road_layout.get("bridge_min_clearance_m", 0.0)),
		"bridge_deck_thickness_m": float(road_layout.get("bridge_deck_thickness_m", 0.0)),
		"terrain_relief_m": terrain_relief,
		"signature": "",
	}
	profile["signature"] = _build_signature(profile, str(road_layout.get("signature", "")))
	return profile

static func _build_buildings(chunk_center: Vector3, chunk_size_m: float, chunk_seed: int, world_seed: int, road_segments: Array) -> Array:
	var candidates := _build_candidate_slots(chunk_center, chunk_size_m, chunk_seed, road_segments)
	var desired_count := mini(MAX_BUILDINGS_PER_CHUNK, 14 + int((chunk_seed >> 1) % 4))
	var archetype_cycle := _build_archetype_cycle(chunk_seed)
	var buildings: Array = []
	var occupied: Array = []
	var half_extent := chunk_size_m * 0.5 - 10.0

	for candidate_index in range(candidates.size()):
		if buildings.size() >= desired_count:
			break
		var candidate: Dictionary = candidates[candidate_index]
		var archetype: Dictionary = archetype_cycle[candidate_index % archetype_cycle.size()]
		var building := _try_build_building(candidate, archetype, chunk_center, half_extent, world_seed, road_segments, occupied)
		if building.is_empty():
			continue
		buildings.append(building)
		occupied.append({
			"center_2d": building.get("center_2d", Vector2.ZERO),
			"radius": building.get("visual_footprint_radius_m", building.get("footprint_radius_m", 0.0)),
		})

	if buildings.size() < desired_count:
		for candidate_index in range(candidates.size()):
			if buildings.size() >= mini(MAX_BUILDINGS_PER_CHUNK, desired_count + INFILL_TARGET_EXTRA):
				break
			var candidate: Dictionary = candidates[candidate_index]
			var filler_archetype: Dictionary = BUILDING_ARCHETYPES[(candidate_index + 3) % BUILDING_ARCHETYPES.size()]
			var filler := _try_build_building(candidate, filler_archetype, chunk_center, half_extent, world_seed, road_segments, occupied, 0.82)
			if filler.is_empty():
				continue
			buildings.append(filler)
			occupied.append({
				"center_2d": filler.get("center_2d", Vector2.ZERO),
				"radius": filler.get("visual_footprint_radius_m", filler.get("footprint_radius_m", 0.0)),
			})
	return buildings

static func _build_candidate_slots(chunk_center: Vector3, chunk_size_m: float, chunk_seed: int, road_segments: Array) -> Array:
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
			var clearance := _distance_to_roads(center_2d, road_segments, 10.0)
			if clearance < 10.0:
				continue
			var radial_bias := center_2d.length() / maxf(half_extent, 1.0)
			var score := 52.0 - absf(clearance - 22.0) * 1.1 - radial_bias * 10.0 + sin(float(slot_seed % 2048) * 0.021) * 6.0
			candidates.append({
				"center_2d": center_2d,
				"clearance": clearance,
				"score": score,
				"seed": slot_seed,
				"world_center": Vector2(chunk_center.x + center_2d.x, chunk_center.z + center_2d.y),
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	return candidates

static func _try_build_building(candidate: Dictionary, archetype: Dictionary, chunk_center: Vector3, half_extent: float, world_seed: int, road_segments: Array, occupied: Array, scale_multiplier: float = 1.0) -> Dictionary:
	var local_seed := int(candidate.get("seed", 0)) ^ int(archetype.get("id", "").hash())
	var rng := RandomNumberGenerator.new()
	rng.seed = local_seed
	var min_size: Vector2 = archetype.get("min_size", Vector2(18.0, 18.0))
	var max_size: Vector2 = archetype.get("max_size", Vector2(28.0, 28.0))
	var height_range: Vector2 = archetype.get("height_range", Vector2(18.0, 36.0))
	var footprint_scale := float(archetype.get("footprint_scale", 1.0))
	var width := snappedf(rng.randf_range(min_size.x, max_size.x) * scale_multiplier, 2.0)
	var depth := snappedf(rng.randf_range(min_size.y, max_size.y) * scale_multiplier, 2.0)
	var height := snappedf(rng.randf_range(height_range.x, height_range.y) * lerpf(0.92, 1.08, rng.randf()), 2.0)
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

	var yaw_rad := _resolve_building_yaw(center_2d, road_segments, local_seed, archetype.get("id", "slab"))
	var world_center: Vector2 = candidate.get("world_center", Vector2(chunk_center.x + center_2d.x, chunk_center.z + center_2d.y))
	var ground_y := CityTerrainSampler.sample_height(world_center.x, world_center.y, world_seed)
	var palette: Dictionary = PALETTES[int(posmod(local_seed, PALETTES.size()))]
	return {
		"name": "Building_%d_%s" % [abs(local_seed % 10000), str(archetype.get("id", "mass"))],
		"archetype_id": str(archetype.get("id", "mass")),
		"center": Vector3(center_2d.x, ground_y + height * 0.5, center_2d.y),
		"center_2d": center_2d,
		"size": Vector3(width, height, depth),
		"collision_size": Vector3(maxf(width, visual_width), height, maxf(depth, visual_depth)),
		"yaw_rad": yaw_rad,
		"footprint_radius_m": footprint_radius,
		"visual_footprint_radius_m": visual_footprint_radius,
		"road_clearance_m": road_clearance,
		"visual_road_clearance_m": visual_road_clearance,
		"detail_seed": local_seed,
		"main_color": _tint_color(palette["base"], rng.randf_range(-0.08, 0.08)),
		"accent_color": _tint_color(palette["accent"], rng.randf_range(-0.06, 0.10)),
		"roof_color": _tint_color(palette["mid"], rng.randf_range(-0.08, 0.06)),
	}

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

static func _resolve_building_yaw(center_2d: Vector2, road_segments: Array, local_seed: int, archetype_id: String) -> float:
	var angle := _nearest_road_angle(center_2d, road_segments)
	if archetype_id == "needle" or archetype_id == "courtyard":
		return angle + deg_to_rad(float(local_seed % 18) - 9.0)
	if archetype_id == "midrise_bar" or archetype_id == "industrial":
		return angle + PI * 0.5
	return angle

static func _nearest_road_angle(point: Vector2, road_segments: Array) -> float:
	var best_distance := INF
	var best_angle := 0.0
	for segment in road_segments:
		var segment_dict: Dictionary = segment
		var points: Array = segment_dict.get("points", [])
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			var distance := _distance_to_segment(point, Vector2(a.x, a.z), Vector2(b.x, b.z))
			if distance < best_distance:
				best_distance = distance
				best_angle = atan2(b.z - a.z, b.x - a.x)
	return best_angle

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

static func _distance_to_roads(point: Vector2, road_segments: Array, early_exit_clearance: float = -1.0) -> float:
	var min_distance := INF
	for segment in road_segments:
		var segment_dict: Dictionary = segment
		var width := float(segment_dict.get("width", 0.0))
		var points: Array = segment_dict.get("points", [])
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			min_distance = minf(
				min_distance,
				_distance_to_segment(point, Vector2(a.x, a.z), Vector2(b.x, b.z)) - width * 0.5
			)
			if early_exit_clearance >= 0.0 and min_distance <= early_exit_clearance:
				return min_distance
	if min_distance == INF:
		return 9999.0
	return min_distance

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

static func _fallback_seed(chunk_key: Vector2i) -> int:
	return int((chunk_key.x * 92837111 + chunk_key.y * 689287499) & 0x7fffffff)

static func _tint_color(color: Color, delta: float) -> Color:
	if delta >= 0.0:
		return color.lerp(Color.WHITE, delta)
	return color.lerp(Color.BLACK, -delta)
