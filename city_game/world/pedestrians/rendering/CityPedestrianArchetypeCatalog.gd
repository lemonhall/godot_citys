extends RefCounted

const ARCHETYPES := {
	"resident": {
		"height_range_m": Vector2(1.62, 1.84),
		"radius_m": 0.28,
		"speed_mps": Vector2(1.15, 1.45),
		"tint": Color(0.705882, 0.74902, 0.784314, 1.0),
	},
	"commuter": {
		"height_range_m": Vector2(1.68, 1.92),
		"radius_m": 0.27,
		"speed_mps": Vector2(1.35, 1.72),
		"tint": Color(0.596078, 0.686275, 0.772549, 1.0),
	},
	"shopper": {
		"height_range_m": Vector2(1.58, 1.8),
		"radius_m": 0.29,
		"speed_mps": Vector2(1.0, 1.34),
		"tint": Color(0.776471, 0.682353, 0.572549, 1.0),
	},
	"courier": {
		"height_range_m": Vector2(1.66, 1.88),
		"radius_m": 0.26,
		"speed_mps": Vector2(1.55, 2.1),
		"tint": Color(0.827451, 0.564706, 0.396078, 1.0),
	},
	"worker": {
		"height_range_m": Vector2(1.7, 1.94),
		"radius_m": 0.3,
		"speed_mps": Vector2(1.12, 1.48),
		"tint": Color(0.611765, 0.627451, 0.541176, 1.0),
	},
	"walker": {
		"height_range_m": Vector2(1.56, 1.76),
		"radius_m": 0.27,
		"speed_mps": Vector2(0.92, 1.2),
		"tint": Color(0.54902, 0.658824, 0.596078, 1.0),
	},
}

func build_descriptor(spawn_slot: Dictionary) -> Dictionary:
	var local_seed := int(spawn_slot.get("seed", 0))
	var archetype_weights: Dictionary = (spawn_slot.get("archetype_weights", {}) as Dictionary).duplicate(true)
	var archetype_id := _select_archetype_id(archetype_weights, local_seed)
	var definition: Dictionary = (ARCHETYPES.get(archetype_id, ARCHETYPES["resident"]) as Dictionary).duplicate(true)
	var variant_index := int(posmod(local_seed / 31, 3))
	var variant_t := float(variant_index) * 0.5
	var height_range: Vector2 = definition.get("height_range_m", Vector2(1.65, 1.85))
	var speed_range: Vector2 = definition.get("speed_mps", Vector2(1.1, 1.4))
	return {
		"archetype_id": archetype_id,
		"archetype_signature": "%s:v%d" % [archetype_id, variant_index],
		"height_m": lerpf(height_range.x, height_range.y, variant_t),
		"radius_m": float(definition.get("radius_m", 0.28)),
		"speed_mps": lerpf(speed_range.x, speed_range.y, clampf(0.25 + variant_t * 0.5, 0.0, 1.0)),
		"tint": definition.get("tint", Color(0.7, 0.74, 0.78, 1.0)),
		"stride_phase": fposmod(float(posmod(local_seed, 997)) / 997.0, 1.0),
	}

func _select_archetype_id(archetype_weights: Dictionary, local_seed: int) -> String:
	if archetype_weights.is_empty():
		return "resident"
	var total_weight := 0.0
	var archetype_ids := archetype_weights.keys()
	archetype_ids.sort()
	for archetype_id_variant in archetype_ids:
		total_weight += maxf(float(archetype_weights.get(archetype_id_variant, 0.0)), 0.0)
	if total_weight <= 0.001:
		return str(archetype_ids[0])
	var threshold := fposmod(float(local_seed) * 0.61803398875, 1.0) * total_weight
	var cursor := 0.0
	for archetype_id_variant in archetype_ids:
		var archetype_id := str(archetype_id_variant)
		cursor += maxf(float(archetype_weights.get(archetype_id, 0.0)), 0.0)
		if threshold <= cursor:
			return archetype_id
	return str(archetype_ids[archetype_ids.size() - 1])
