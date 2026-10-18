extends RefCounted

# Runtime access to the world plan: one cached plan per world seed, plus the
# 1km vertical slice test used to keep the rest of the world on v62.

const Generator := preload("res://city_game/world/generation/plan/CityPlanGenerator.gd")
const Cache := preload("res://city_game/world/generation/plan/CityPlanCache.gd")
const Sampler := preload("res://city_game/world/generation/plan/CityPlanSampler.gd")

const SLICE_HALF_M := 700.0

static var _seed := -999999
static var _plan: Dictionary = {}
static var _sampler = null

static func get_sampler(world_seed: int):
	if _sampler != null and _seed == world_seed:
		return _sampler
	var cache = Cache.new()
	var plan: Dictionary = cache.load_plan(world_seed)
	if plan.is_empty():
		plan = Generator.generate(world_seed)
		cache.store(plan)
	_seed = world_seed
	_plan = plan
	_sampler = Sampler.new(plan)
	return _sampler

static func get_plan(world_seed: int) -> Dictionary:
	get_sampler(world_seed)
	return _plan

static func in_slice(world_x: float, world_z: float) -> bool:
	return absf(world_x) <= SLICE_HALF_M and absf(world_z) <= SLICE_HALF_M

static func chunk_overlaps_slice(chunk_center: Vector3, chunk_size_m: float) -> bool:
	var half := chunk_size_m * 0.5
	return absf(chunk_center.x) - half <= SLICE_HALF_M and absf(chunk_center.z) - half <= SLICE_HALF_M
