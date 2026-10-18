extends RefCounted

# District layer: districts are derived from geography (river, old-town core,
# railway ring), not from a per-chunk hash.

const CityTerrainPlan := preload("res://city_game/world/generation/plan/CityTerrainPlan.gd")
const CityHistoryPlan := preload("res://city_game/world/generation/plan/CityHistoryPlan.gd")

const ALL_KINDS := ["oldtown", "downtown", "commercial", "residential", "industrial", "waterfront"]

static func build(_world_seed: int, _terrain: Dictionary, _history: Dictionary) -> Dictionary:
	return {
		"core_radius_m": 1400.0,
		"downtown_radius_m": 2600.0,
		"commercial_radius_m": 4200.0,
		"industrial_band_m": 320.0,
		"waterfront_band_m": 260.0,
	}

static func district_at(plan: Dictionary, x: float, z: float) -> String:
	var terrain: Dictionary = plan.get("terrain", {})
	var history: Dictionary = plan.get("history", {})
	var config: Dictionary = plan.get("districts", {})
	var d_water := CityTerrainPlan.river_distance(terrain, x, z)
	if d_water < float(config.get("waterfront_band_m", 260.0)):
		return "waterfront"
	var core: Vector2 = history.get("core", Vector2.ZERO)
	var d_core := Vector2(x, z).distance_to(core)
	if d_core < float(config.get("core_radius_m", 1100.0)):
		return "oldtown"
	var d_rail := CityHistoryPlan.rail_distance(history, x, z)
	if d_rail < float(config.get("industrial_band_m", 320.0)) and d_core > float(config.get("core_radius_m", 1100.0)) * 1.5:
		return "industrial"
	if d_core < float(config.get("downtown_radius_m", 2600.0)):
		return "downtown"
	if d_core < float(config.get("commercial_radius_m", 4200.0)):
		return "commercial"
	return "residential"
