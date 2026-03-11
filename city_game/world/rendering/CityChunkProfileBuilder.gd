extends RefCounted

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

static func build_profile(chunk_data: Dictionary) -> Dictionary:
	var chunk_key: Vector2i = chunk_data.get("chunk_key", Vector2i.ZERO)
	var chunk_size_m := float(chunk_data.get("chunk_size_m", 256.0))
	var chunk_seed := int(chunk_data.get("chunk_seed", _fallback_seed(chunk_key)))
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed

	var palette_index := int(posmod(chunk_seed, PALETTES.size()))
	var palette: Dictionary = PALETTES[palette_index]
	var avenue_axis := "x" if (chunk_seed & 1) == 0 else "z"
	var avenue_width := 26.0 + 4.0 * float((chunk_seed >> 2) % 3)
	var avenue_offset := rng.randf_range(-18.0, 18.0)
	var plaza_depth := chunk_size_m * rng.randf_range(0.16, 0.24)

	var podium_height := 4.0 + 2.0 * float((chunk_seed >> 5) % 3)
	var podium_size := Vector3(
		chunk_size_m * rng.randf_range(0.34, 0.48),
		podium_height,
		chunk_size_m * rng.randf_range(0.34, 0.48)
	)

	var towers: Array[Dictionary] = []
	var slots: Array[Vector2] = _build_slot_positions(avenue_axis)
	var used_slots: Dictionary = {}
	var tower_count := 3 + int((chunk_seed >> 1) % 2)
	for tower_index in range(tower_count):
		var slot_index := int((chunk_seed / 17 + tower_index * 3) % slots.size())
		while used_slots.has(slot_index):
			slot_index = (slot_index + 1) % slots.size()
		used_slots[slot_index] = true

		var slot: Vector2 = slots[slot_index]
		var center_2d := slot + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0))
		var width := snappedf(rng.randf_range(18.0, 32.0), 2.0)
		var depth := snappedf(rng.randf_range(18.0, 32.0), 2.0)
		var height := snappedf(rng.randf_range(18.0, 52.0), 2.0)
		var band_count := 2 + int((chunk_seed + tower_index) % 2)
		towers.append({
			"name": "Tower_%d" % tower_index,
			"center": Vector3(center_2d.x, height * 0.5, center_2d.y),
			"size": Vector3(width, height, depth),
			"band_count": band_count,
			"band_width": snappedf(width * rng.randf_range(0.08, 0.14), 0.1),
			"main_color": _tint_color(palette["base"], rng.randf_range(-0.08, 0.08)),
			"band_color": _tint_color(palette["accent"], rng.randf_range(-0.06, 0.12)),
		})

	var profile := {
		"variant_id": "p%d-a%s-t%d" % [palette_index, avenue_axis, tower_count],
		"palette": palette.duplicate(true),
		"avenue": {
			"axis": avenue_axis,
			"width": avenue_width,
			"offset": avenue_offset,
			"plaza_depth": plaza_depth,
		},
		"podium": {
			"center": Vector3(0.0, podium_height * 0.5, 0.0),
			"size": podium_size,
			"color": _tint_color(palette["base"], -0.1),
		},
		"towers": towers,
		"signature": "",
	}
	profile["signature"] = _build_signature(profile)
	return profile

static func _build_slot_positions(avenue_axis: String) -> Array[Vector2]:
	if avenue_axis == "x":
		return [
			Vector2(-76.0, -62.0),
			Vector2(-30.0, -60.0),
			Vector2(24.0, -58.0),
			Vector2(70.0, -60.0),
			Vector2(-72.0, 60.0),
			Vector2(-24.0, 58.0),
			Vector2(30.0, 62.0),
			Vector2(72.0, 58.0),
		]
	return [
		Vector2(-62.0, -76.0),
		Vector2(-60.0, -30.0),
		Vector2(-58.0, 24.0),
		Vector2(-60.0, 70.0),
		Vector2(60.0, -72.0),
		Vector2(58.0, -24.0),
		Vector2(62.0, 30.0),
		Vector2(58.0, 72.0),
	]

static func _build_signature(profile: Dictionary) -> String:
	var avenue: Dictionary = profile.get("avenue", {})
	var signature_parts := PackedStringArray([
		"%s|%.1f|%.1f" % [
			str(avenue.get("axis", "z")),
			float(avenue.get("width", 0.0)),
			float(avenue.get("offset", 0.0)),
		]
	])

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
