extends RefCounted

# Parcel layer: walk the major roads and cut street-front parcels with the
# district grammar, leaving alleys between them.

const CityParcelGrammar := preload("res://city_game/world/generation/plan/CityParcelGrammar.gd")
const CityDistrictPlan := preload("res://city_game/world/generation/plan/CityDistrictPlan.gd")

const MAX_PARCELS := 4000

static func build(plan: Dictionary, region_radius_m: float = 5000.0) -> Dictionary:
	var roads: Array = (plan.get("roads", {}) as Dictionary).get("roads", [])
	var core: Vector2 = (plan.get("history", {}) as Dictionary).get("core", Vector2.ZERO)
	var parcels: Array = []
	var alleys: Array = []
	var seed_value := int(plan.get("seed", 0))
	for road_index in range(roads.size()):
		var road: Dictionary = roads[road_index]
		var points: Array = road.get("points", [])
		if points.size() < 2:
			continue
		var road_half := float(road.get("width_m", 16.0)) * 0.5
		for side in [-1.0, 1.0]:
			_build_side(plan, points, side, road_half, core, region_radius_m, seed_value + road_index * 977, parcels, alleys)
			if parcels.size() >= MAX_PARCELS:
				break
	return {"parcels": parcels, "alleys": alleys}

static func _build_side(plan: Dictionary, points: Array, side: float, road_half: float, core: Vector2, region_radius_m: float, seed_value: int, parcels: Array, alleys: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for segment_index in range(points.size() - 1):
		var a: Vector3 = points[segment_index]
		var b: Vector3 = points[segment_index + 1]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var segment_length := a2.distance_to(b2)
		if segment_length < 1.0:
			continue
		var tangent := (b2 - a2) / segment_length
		var normal := Vector2(-tangent.y, tangent.x) * side
		var cursor := 0.0
		var slot := 0
		while cursor < segment_length:
			var frontage_point := a2 + tangent * (cursor + 2.0)
			var district := CityDistrictPlan.district_at(plan, frontage_point.x, frontage_point.y)
			var grammar := CityParcelGrammar.config(district)
			var width: float = rng.randf_range(grammar["width"].x, grammar["width"].y)
			var depth: float = rng.randf_range(grammar["depth"].x, grammar["depth"].y)
			var frontage := float(grammar["frontage_m"])
			var alley_width := float(grammar["alley_width_m"])
			var alley_every := int(grammar["alley_every"])
			var needs_alley := slot > 0 and slot % alley_every == 0
			if needs_alley:
				var alley_start := a2 + tangent * cursor + normal * (road_half + 0.1)
				var alley_end := a2 + tangent * cursor + normal * (road_half + frontage + depth)
				alleys.append({
					"width_m": alley_width,
					"start": alley_start,
					"end": alley_end,
					"district": district,
					"connected_to_road": true,
				})
				cursor += alley_width
			if cursor + width > segment_length:
				break
			var along := cursor + width * 0.5
			var center_front := a2 + tangent * along
			var parcel_center := center_front + normal * (road_half + frontage + depth * 0.5)
			if parcel_center.distance_to(core) > region_radius_m:
				cursor += width
				slot += 1
				continue
			var courtyard := rng.randf() < float(grammar["courtyard_chance"])
			parcels.append({
				"id": "p%d_%d_%d" % [seed_value, slot, parcels.size()],
				"district": district,
				"era": CityParcelGrammar.era_for_district(district),
				"center": parcel_center,
				"width_m": width,
				"depth_m": depth,
				"frontage_m": frontage,
				"has_courtyard": courtyard,
				"tangent": tangent,
				"side": side,
			})
			cursor += width
			slot += 1
