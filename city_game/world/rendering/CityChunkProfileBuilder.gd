extends RefCounted

const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

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

const CANDIDATE_SLOTS := [
	Vector2(-74.0, -72.0),
	Vector2(-22.0, -70.0),
	Vector2(32.0, -68.0),
	Vector2(76.0, -18.0),
	Vector2(74.0, 38.0),
	Vector2(34.0, 74.0),
	Vector2(-18.0, 72.0),
	Vector2(-72.0, 36.0),
	Vector2(-68.0, -12.0),
	Vector2(4.0, 8.0),
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

	var eligible_slots := _build_eligible_slots(road_segments)
	if eligible_slots.size() < 3:
		eligible_slots = _duplicate_candidate_slots()

	var road_signature := str(road_layout.get("signature", ""))
	var tower_count := mini(eligible_slots.size(), 3 + int((chunk_seed >> 1) % 2))
	var towers: Array[Dictionary] = []
	var used_indices: Dictionary = {}
	for tower_index in range(tower_count):
		var slot_index := int((chunk_seed / 17 + tower_index * 3) % eligible_slots.size())
		while used_indices.has(slot_index):
			slot_index = (slot_index + 1) % eligible_slots.size()
		used_indices[slot_index] = true

		var slot: Vector2 = eligible_slots[slot_index]
		var center_2d := slot + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
		center_2d = _clamp_to_chunk(center_2d, chunk_size_m * 0.5 - 26.0)
		var width := snappedf(rng.randf_range(18.0, 28.0), 2.0)
		var depth := snappedf(rng.randf_range(18.0, 28.0), 2.0)
		var height := snappedf(rng.randf_range(18.0, 54.0), 2.0)
		var ground_y := CityTerrainSampler.sample_height(chunk_center.x + center_2d.x, chunk_center.z + center_2d.y, world_seed)
		towers.append({
			"name": "Tower_%d" % tower_index,
			"center": Vector3(center_2d.x, ground_y + height * 0.5, center_2d.y),
			"size": Vector3(width, height, depth),
			"band_count": 2 + int((chunk_seed + tower_index) % 2),
			"band_width": snappedf(width * rng.randf_range(0.08, 0.14), 0.1),
			"main_color": _tint_color(palette["base"], rng.randf_range(-0.08, 0.08)),
			"band_color": _tint_color(palette["accent"], rng.randf_range(-0.06, 0.12)),
		})

	var podium_center_2d := _choose_podium_center(eligible_slots, chunk_size_m * 0.5)
	var podium_height := 4.0 + 2.0 * float((chunk_seed >> 5) % 3)
	var podium_ground_y := CityTerrainSampler.sample_height(chunk_center.x + podium_center_2d.x, chunk_center.z + podium_center_2d.y, world_seed)
	var podium_size := Vector3(
		snappedf(rng.randf_range(52.0, 78.0), 2.0),
		podium_height,
		snappedf(rng.randf_range(48.0, 74.0), 2.0)
	)

	var terrain_relief := _measure_terrain_relief(chunk_center, chunk_size_m, world_seed)
	var profile := {
		"variant_id": "p%d-r%d-t%d" % [palette_index, road_segments.size(), tower_count],
		"palette": palette.duplicate(true),
		"podium": {
			"center": Vector3(podium_center_2d.x, podium_ground_y + podium_height * 0.5, podium_center_2d.y),
			"size": podium_size,
			"color": _tint_color(palette["base"], -0.1),
		},
		"towers": towers,
		"road_segments": road_segments,
		"road_boundary_connectors": road_layout.get("connectors", {
			"north": [],
			"south": [],
			"east": [],
			"west": [],
		}),
		"curved_road_segment_count": int(road_layout.get("curved_segment_count", 0)),
		"terrain_relief_m": terrain_relief,
		"signature": "",
	}
	profile["signature"] = _build_signature(profile, road_signature)
	return profile

static func _build_eligible_slots(road_segments: Array) -> Array[Vector2]:
	var slots: Array[Dictionary] = []
	for slot in CANDIDATE_SLOTS:
		var candidate: Vector2 = slot
		slots.append({
			"slot": candidate,
			"clearance": _distance_to_roads(candidate, road_segments),
		})
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("clearance", 0.0)) > float(b.get("clearance", 0.0))
	)

	var eligible: Array[Vector2] = []
	for slot_info in slots:
		if float(slot_info.get("clearance", 0.0)) >= 16.0:
			eligible.append(slot_info.get("slot", Vector2.ZERO))
	return eligible

static func _duplicate_candidate_slots() -> Array[Vector2]:
	var slots: Array[Vector2] = []
	for slot in CANDIDATE_SLOTS:
		slots.append(slot)
	return slots

static func _distance_to_roads(point: Vector2, road_segments: Array) -> float:
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

static func _choose_podium_center(eligible_slots: Array, half_chunk_span: float) -> Vector2:
	if eligible_slots.is_empty():
		return Vector2.ZERO
	var podium_slot: Vector2 = eligible_slots[0]
	return _clamp_to_chunk(podium_slot * 0.35, half_chunk_span - 42.0)

static func _clamp_to_chunk(point: Vector2, half_extent: float) -> Vector2:
	return Vector2(
		clampf(point.x, -half_extent, half_extent),
		clampf(point.y, -half_extent, half_extent)
	)

static func _measure_terrain_relief(chunk_center: Vector3, chunk_size_m: float, world_seed: int) -> float:
	var half_size := chunk_size_m * 0.5
	var sample_positions := [
		Vector2(-half_size, -half_size),
		Vector2(half_size, -half_size),
		Vector2(-half_size, half_size),
		Vector2(half_size, half_size),
		Vector2.ZERO,
	]
	var min_height := INF
	var max_height := -INF
	for sample in sample_positions:
		var position: Vector2 = sample
		var height := CityTerrainSampler.sample_height(chunk_center.x + position.x, chunk_center.z + position.y, world_seed)
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)
	return maxf(max_height - min_height, 0.0)

static func _build_signature(profile: Dictionary, road_signature: String) -> String:
	var signature_parts := PackedStringArray([road_signature])
	var podium: Dictionary = profile.get("podium", {})
	var podium_size: Vector3 = podium.get("size", Vector3.ZERO)
	signature_parts.append("podium:%.1f,%.1f,%.1f" % [podium_size.x, podium_size.y, podium_size.z])
	for tower in profile.get("towers", []):
		var tower_dict: Dictionary = tower
		var center: Vector3 = tower_dict.get("center", Vector3.ZERO)
		var size: Vector3 = tower_dict.get("size", Vector3.ZERO)
		signature_parts.append("tower:%.1f,%.1f,%.1f,%.1f,%.1f" % [
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
