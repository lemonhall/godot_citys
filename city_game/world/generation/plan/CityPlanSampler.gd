extends RefCounted

# O(1) chunk-side sampling over a CityPlan.

const CityTerrainPlan := preload("res://city_game/world/generation/plan/CityTerrainPlan.gd")
const CityDistrictPlan := preload("res://city_game/world/generation/plan/CityDistrictPlan.gd")

var _plan: Dictionary

func _init(plan: Dictionary) -> void:
	_plan = plan

func terrain() -> Dictionary:
	return _plan.get("terrain", {})

func height_at(x: float, z: float) -> float:
	return CityTerrainPlan.height_at(terrain(), x, z)

func water_mask_at(x: float, z: float) -> bool:
	return CityTerrainPlan.is_water(terrain(), x, z)

func river_distance(x: float, z: float) -> float:
	return CityTerrainPlan.river_distance(terrain(), x, z)

func district_at(x: float, z: float) -> String:
	return CityDistrictPlan.district_at(_plan, x, z)

func landmarks() -> Array:
	return (_plan.get("landmarks", {}) as Dictionary).get("landmarks", [])

func plan_hash() -> String:
	return str(_plan.get("plan_hash", ""))
