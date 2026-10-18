extends RefCounted

# Deterministic district character for the 70km city.
#
# The world is far too large for one architectural language. This module maps a
# world position to a coarse district kind so the chunk profile builder can pick
# a different archetype mix, height band and palette per district:
#
#   downtown     glass towers, hotel towers, tall slabs (the CBD)
#   commercial   office slabs, stepped mid-rises, the occasional tower
#   residential  brick/concrete mid-rises, residential towers, row houses
#   oldtown      low brick row houses, courtyards, stepped blocks
#   industrial   warehouses, sheds, low offices

const DISTRICT_SIZE_M := 2048.0
const DOWNTOWN_RADIUS_M := 4200.0
const INNER_RADIUS_M := DOWNTOWN_RADIUS_M * 2.2

const KIND_DOWNTOWN := "downtown"
const KIND_COMMERCIAL := "commercial"
const KIND_RESIDENTIAL := "residential"
const KIND_OLDTOWN := "oldtown"
const KIND_INDUSTRIAL := "industrial"

const ALL_KINDS := [
	KIND_DOWNTOWN,
	KIND_COMMERCIAL,
	KIND_RESIDENTIAL,
	KIND_OLDTOWN,
	KIND_INDUSTRIAL,
]

static func resolve_kind(world_position: Vector2, world_seed: int) -> String:
	var district_key := Vector2i(
		int(floor(world_position.x / DISTRICT_SIZE_M)),
		int(floor(world_position.y / DISTRICT_SIZE_M))
	)
	var roll := float(_hash(district_key, world_seed) % 1000) / 1000.0
	var distance := world_position.length()
	if distance <= DOWNTOWN_RADIUS_M:
		if roll < 0.66:
			return KIND_DOWNTOWN
		if roll < 0.90:
			return KIND_COMMERCIAL
		return KIND_RESIDENTIAL
	if distance <= INNER_RADIUS_M:
		if roll < 0.26:
			return KIND_DOWNTOWN
		if roll < 0.52:
			return KIND_COMMERCIAL
		if roll < 0.78:
			return KIND_RESIDENTIAL
		if roll < 0.90:
			return KIND_OLDTOWN
		return KIND_INDUSTRIAL
	if roll < 0.14:
		return KIND_COMMERCIAL
	if roll < 0.44:
		return KIND_RESIDENTIAL
	if roll < 0.66:
		return KIND_OLDTOWN
	return KIND_INDUSTRIAL

static func height_scale(kind: String) -> float:
	match kind:
		KIND_DOWNTOWN:
			return 1.18
		KIND_COMMERCIAL:
			return 1.0
		KIND_RESIDENTIAL:
			return 0.80
		KIND_OLDTOWN:
			return 0.70
		KIND_INDUSTRIAL:
			return 0.76
	return 1.0

static func palette_options(kind: String) -> Array:
	match kind:
		KIND_DOWNTOWN:
			return [0, 3]
		KIND_COMMERCIAL:
			return [0, 1, 3]
		KIND_RESIDENTIAL:
			return [1, 2]
		KIND_OLDTOWN:
			return [2, 1]
		KIND_INDUSTRIAL:
			return [3, 0]
	return [0, 1, 2, 3]

static func _hash(key: Vector2i, seed_value: int) -> int:
	var h := (seed_value * 73856093) ^ (key.x * 19349663) ^ (key.y * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return abs(h)
