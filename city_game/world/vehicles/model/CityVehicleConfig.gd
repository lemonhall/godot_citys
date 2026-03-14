extends RefCounted

const DISTRICT_CLASS_DENSITY := {
	"core": 1.0,
	"mixed": 0.82,
	"industrial": 0.66,
	"residential": 0.56,
	"periphery": 0.34,
}

const ROAD_CLASS_DENSITY := {
	"expressway_elevated": 1.0,
	"arterial": 0.84,
	"secondary": 0.68,
	"collector": 0.54,
	"local": 0.42,
	"service": 0.24,
}

const ROAD_CLASS_MIN_HEADWAY_M := {
	"expressway_elevated": 28.0,
	"arterial": 22.0,
	"secondary": 20.0,
	"collector": 18.0,
	"local": 16.0,
	"service": 14.0,
}

const MAX_SPAWN_SLOTS_PER_CHUNK := 96

func to_snapshot() -> Dictionary:
	return {
		"district_class_density": DISTRICT_CLASS_DENSITY.duplicate(true),
		"road_class_density": ROAD_CLASS_DENSITY.duplicate(true),
		"road_class_min_headway_m": ROAD_CLASS_MIN_HEADWAY_M.duplicate(true),
		"max_spawn_slots_per_chunk": MAX_SPAWN_SLOTS_PER_CHUNK,
	}

func get_density_for_district_class(district_class: String) -> float:
	return float(DISTRICT_CLASS_DENSITY.get(district_class, DISTRICT_CLASS_DENSITY["residential"]))

func get_density_for_road_class(road_class: String) -> float:
	return float(ROAD_CLASS_DENSITY.get(road_class, ROAD_CLASS_DENSITY["local"]))

func get_min_headway_for_road_class(road_class: String) -> float:
	return float(ROAD_CLASS_MIN_HEADWAY_M.get(road_class, ROAD_CLASS_MIN_HEADWAY_M["local"]))

func get_max_spawn_slots_per_chunk() -> int:
	return MAX_SPAWN_SLOTS_PER_CHUNK

func resolve_density_bucket(density_scalar: float) -> String:
	if density_scalar >= 0.78:
		return "high"
	if density_scalar >= 0.56:
		return "medium"
	if density_scalar >= 0.34:
		return "low"
	return "sparse"
