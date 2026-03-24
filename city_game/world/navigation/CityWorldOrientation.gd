extends RefCounted

const WORLD_NORTH := Vector3(0.0, 0.0, -1.0)
const WORLD_EAST := Vector3(1.0, 0.0, 0.0)
const WORLD_SOUTH := Vector3(0.0, 0.0, 1.0)
const WORLD_WEST := Vector3(-1.0, 0.0, 0.0)

const COMPASS_HALF_SPAN_DEG := 60.0
const COMPASS_MINOR_TICK_STEP_DEG := 5.0
const COMPASS_MAJOR_TICK_STEP_DEG := 10.0
const COMPASS_LABEL_STEP_DEG := 30.0

func get_orientation_contract() -> Dictionary:
	return {
		"north_up": true,
		"map_north_equals_world_north": true,
		"geographic_north_equals_world_north": true,
		"bearing_clockwise": true,
		"north_world_axis": WORLD_NORTH,
		"east_world_axis": WORLD_EAST,
		"south_world_axis": WORLD_SOUTH,
		"west_world_axis": WORLD_WEST,
		"north_bearing_deg": 0.0,
		"east_bearing_deg": 90.0,
		"south_bearing_deg": 180.0,
		"west_bearing_deg": 270.0,
	}

func normalize_bearing_deg(value: float) -> float:
	var wrapped := fposmod(value, 360.0)
	if wrapped >= 359.999:
		return 0.0
	return wrapped

func bearing_deg_from_world_vector(direction: Vector3) -> float:
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= 0.000001:
		return 0.0
	planar = planar.normalized()
	return normalize_bearing_deg(rad_to_deg(atan2(planar.x, -planar.z)))

func heading_rad_from_world_vector(direction: Vector3) -> float:
	return deg_to_rad(bearing_deg_from_world_vector(direction))

func bearing_deg_from_heading_rad(heading_rad: float) -> float:
	return normalize_bearing_deg(rad_to_deg(heading_rad))

func heading_rad_from_bearing_deg(bearing_deg: float) -> float:
	return deg_to_rad(normalize_bearing_deg(bearing_deg))

func cardinal_text_from_bearing_deg(bearing_deg: float) -> String:
	var resolved_bearing := normalize_bearing_deg(bearing_deg)
	var cardinals := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var index := int(floor((resolved_bearing + 22.5) / 45.0)) % cardinals.size()
	return str(cardinals[index])

func build_compass_state_from_world_vector(direction: Vector3, visible: bool = true) -> Dictionary:
	return build_compass_state_from_bearing_deg(bearing_deg_from_world_vector(direction), visible)

func build_compass_state_from_heading_rad(heading_rad: float, visible: bool = true) -> Dictionary:
	return build_compass_state_from_bearing_deg(bearing_deg_from_heading_rad(heading_rad), visible)

func build_compass_state_from_bearing_deg(bearing_deg: float, visible: bool = true, half_span_deg: float = COMPASS_HALF_SPAN_DEG) -> Dictionary:
	var resolved_bearing := normalize_bearing_deg(bearing_deg)
	var label_value := int(round(resolved_bearing)) % 360
	return {
		"visible": visible,
		"north_up": true,
		"bearing_deg": resolved_bearing,
		"heading_rad": heading_rad_from_bearing_deg(resolved_bearing),
		"bearing_text": "%03d°" % label_value,
		"cardinal_text": cardinal_text_from_bearing_deg(resolved_bearing),
		"tick_entries": _build_compass_tick_entries(resolved_bearing, half_span_deg),
		"half_span_deg": half_span_deg,
		"minor_tick_step_deg": COMPASS_MINOR_TICK_STEP_DEG,
		"major_tick_step_deg": COMPASS_MAJOR_TICK_STEP_DEG,
	}

func shortest_bearing_delta_deg(from_bearing_deg: float, to_bearing_deg: float) -> float:
	return fposmod(to_bearing_deg - from_bearing_deg + 540.0, 360.0) - 180.0

func _build_compass_tick_entries(center_bearing_deg: float, half_span_deg: float) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var step_radius := int(ceil(half_span_deg / COMPASS_MINOR_TICK_STEP_DEG))
	for step_index in range(-step_radius, step_radius + 1):
		var tick_bearing := normalize_bearing_deg(center_bearing_deg + float(step_index) * COMPASS_MINOR_TICK_STEP_DEG)
		var delta_deg := shortest_bearing_delta_deg(center_bearing_deg, tick_bearing)
		if absf(delta_deg) > half_span_deg + 0.001:
			continue
		var rounded_bearing := int(round(tick_bearing)) % 360
		var label := ""
		if rounded_bearing % 90 == 0:
			label = cardinal_text_from_bearing_deg(float(rounded_bearing))
		elif rounded_bearing % int(COMPASS_LABEL_STEP_DEG) == 0:
			label = "%03d" % rounded_bearing
		entries.append({
			"bearing_deg": float(rounded_bearing),
			"offset_ratio": clampf(delta_deg / maxf(half_span_deg, 0.001), -1.0, 1.0),
			"is_major": rounded_bearing % int(COMPASS_MAJOR_TICK_STEP_DEG) == 0,
			"is_cardinal": rounded_bearing % 90 == 0,
			"label": label,
		})
	return entries

