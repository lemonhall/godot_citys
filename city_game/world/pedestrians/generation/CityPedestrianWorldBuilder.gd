extends RefCounted

const CityPedestrianConfig := preload("res://city_game/world/pedestrians/model/CityPedestrianConfig.gd")
const CityPedestrianProfile := preload("res://city_game/world/pedestrians/model/CityPedestrianProfile.gd")
const CityPedestrianQuery := preload("res://city_game/world/pedestrians/model/CityPedestrianQuery.gd")

func build(config, district_graph, road_graph):
	var pedestrian_config = CityPedestrianConfig.new()
	var district_profiles_by_id: Dictionary = {}

	for district_entry in district_graph.districts:
		var district_data: Dictionary = district_entry
		var profile := _build_profile_for_district(config, pedestrian_config, district_data)
		district_profiles_by_id[profile.district_id] = profile.to_dictionary()

	var query = CityPedestrianQuery.new()
	query.setup(config, pedestrian_config, road_graph, district_profiles_by_id)
	return query

func _build_profile_for_district(config, pedestrian_config: CityPedestrianConfig, district_data: Dictionary) -> CityPedestrianProfile:
	var district_key: Vector2i = district_data.get("district_key", Vector2i.ZERO)
	var district_class := _resolve_district_class(config, district_data)
	var density_scalar := pedestrian_config.get_density_for_district_class(district_class)
	var profile := CityPedestrianProfile.new()
	profile.setup({
		"district_id": str(district_data.get("district_id", "")),
		"district_key": district_key,
		"district_class": district_class,
		"density_scalar": density_scalar,
		"density_bucket": pedestrian_config.resolve_density_bucket(density_scalar),
		"archetype_weights": pedestrian_config.get_archetype_weights_for_district_class(district_class),
		"profile_seed": int(district_data.get("seed", 0)),
	})
	return profile

func _resolve_district_class(config, district_data: Dictionary) -> String:
	var center: Vector2 = district_data.get("center", Vector2.ZERO)
	var bounds: Rect2 = config.get_world_bounds()
	var half_size := bounds.size * 0.5
	var radial_x := absf(center.x) / maxf(half_size.x, 1.0)
	var radial_y := absf(center.y) / maxf(half_size.y, 1.0)
	var radial_factor := sqrt(radial_x * radial_x + radial_y * radial_y)
	var district_seed_value := int(district_data.get("seed", 0))
	var district_key: Vector2i = district_data.get("district_key", Vector2i.ZERO)

	if radial_factor < 0.24:
		return "core"
	if radial_factor < 0.46:
		if district_seed_value % 7 == 0:
			return "industrial"
		return "mixed"
	if radial_factor < 0.78:
		if (district_key.x + district_key.y) % 6 == 0:
			return "industrial"
		return "residential"
	return "periphery"
