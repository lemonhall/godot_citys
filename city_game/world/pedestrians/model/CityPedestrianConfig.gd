extends RefCounted

const DEFAULT_DISTRICT_CLASS_DENSITY := {
	"core": 1.0,
	"mixed": 0.78,
	"residential": 0.56,
	"industrial": 0.42,
	"periphery": 0.16,
}

const DEFAULT_ROAD_CLASS_DENSITY := {
	"expressway_elevated": 0.0,
	"arterial": 0.9,
	"secondary": 0.66,
	"collector": 0.5,
	"local": 0.38,
}

const DEFAULT_DISTRICT_CLASS_ARCHETYPE_WEIGHTS := {
	"core": {
		"commuter": 0.4,
		"shopper": 0.3,
		"resident": 0.15,
		"courier": 0.15,
	},
	"mixed": {
		"resident": 0.34,
		"commuter": 0.3,
		"shopper": 0.2,
		"courier": 0.16,
	},
	"residential": {
		"resident": 0.52,
		"commuter": 0.2,
		"shopper": 0.16,
		"courier": 0.12,
	},
	"industrial": {
		"worker": 0.42,
		"commuter": 0.28,
		"courier": 0.18,
		"resident": 0.12,
	},
	"periphery": {
		"resident": 0.44,
		"courier": 0.22,
		"commuter": 0.18,
		"walker": 0.16,
	},
}

const DEFAULT_ARCHETYPE_WEIGHTS := {
	"resident": 0.35,
	"commuter": 0.3,
	"shopper": 0.2,
	"courier": 0.15,
}

var district_class_density: Dictionary = DEFAULT_DISTRICT_CLASS_DENSITY.duplicate(true)
var road_class_density: Dictionary = DEFAULT_ROAD_CLASS_DENSITY.duplicate(true)
var district_class_archetype_weights: Dictionary = DEFAULT_DISTRICT_CLASS_ARCHETYPE_WEIGHTS.duplicate(true)
var default_archetype_weights: Dictionary = DEFAULT_ARCHETYPE_WEIGHTS.duplicate(true)
var max_spawn_slots_per_chunk := 48

func get_density_for_district_class(district_class: String) -> float:
	return float(district_class_density.get(district_class, 0.0))

func get_density_for_road_class(road_class: String) -> float:
	return float(road_class_density.get(road_class, road_class_density.get("local", 0.0)))

func get_archetype_weights_for_district_class(district_class: String) -> Dictionary:
	if not district_class_archetype_weights.has(district_class):
		return default_archetype_weights.duplicate(true)
	return (district_class_archetype_weights[district_class] as Dictionary).duplicate(true)

func resolve_density_bucket(density_scalar: float) -> String:
	if density_scalar >= 0.85:
		return "packed"
	if density_scalar >= 0.65:
		return "busy"
	if density_scalar >= 0.45:
		return "steady"
	if density_scalar >= 0.2:
		return "sparse"
	return "quiet"

func get_spawn_slots_for_edge(district_density: float, road_density: float) -> int:
	var combined_density := clampf(district_density * road_density, 0.0, 1.0)
	if combined_density <= 0.05:
		return 0
	if combined_density <= 0.18:
		return 1
	if combined_density <= 0.36:
		return 2
	if combined_density <= 0.58:
		return 3
	if combined_density <= 0.78:
		return 4
	return 6

func get_max_spawn_slots_per_chunk() -> int:
	return max_spawn_slots_per_chunk

func to_snapshot() -> Dictionary:
	return {
		"district_class_density": district_class_density.duplicate(true),
		"road_class_density": road_class_density.duplicate(true),
		"default_archetype_weights": default_archetype_weights.duplicate(true),
		"district_class_archetype_weights": district_class_archetype_weights.duplicate(true),
		"max_spawn_slots_per_chunk": max_spawn_slots_per_chunk,
	}
