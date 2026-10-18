extends RefCounted

# Landmark layer: three authored landmarks with stable ids. They are the only
# buildings allowed to taper, and each exposes a roof access point.

const CityTerrainPlan := preload("res://city_game/world/generation/plan/CityTerrainPlan.gd")

static func build(world_seed: int, terrain: Dictionary, history: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x9E37
	var core: Vector2 = history.get("core", Vector2.ZERO)
	var landmarks: Array = []
	var spire_offset := Vector2(rng.randf_range(-160.0, 160.0), rng.randf_range(-160.0, 160.0))
	landmarks.append(_make_landmark("landmark_spire", "spire", core + spire_offset, 220.0, false))
	var twin_x := rng.randf_range(520.0, 760.0)
	var twin_z := rng.randf_range(-240.0, 240.0)
	landmarks.append(_make_landmark("landmark_twin_a", "twin", core + Vector2(twin_x, twin_z), 140.0, true))
	landmarks.append(_make_landmark("landmark_twin_b", "twin", core + Vector2(twin_x + 90.0, twin_z), 140.0, true))
	# The water tower sits on the bank, outside the water mask.
	var water_tower_position := _find_bank(terrain, core)
	if water_tower_position != Vector2.INF:
		landmarks.append(_make_landmark("landmark_water_tower", "water_tower", water_tower_position, 160.0, false))
	return {"landmarks": landmarks, "skybridge_height_m": 88.0}

static func _make_landmark(id: String, kind: String, position: Vector2, height_m: float, skybridge: bool) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"position": position,
		"height_m": height_m,
		"roof_access": true,
		"skybridge": skybridge,
	}

static func _find_bank(terrain: Dictionary, core: Vector2) -> Vector2:
	for step in range(1, 40):
		var candidate := core + Vector2(0.0, 260.0 + float(step) * 20.0)
		if not CityTerrainPlan.is_water(terrain, candidate.x, candidate.y):
			return candidate
		candidate = core - Vector2(0.0, 260.0 + float(step) * 20.0)
		if not CityTerrainPlan.is_water(terrain, candidate.x, candidate.y):
			return candidate
	return Vector2.INF
