extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	if config_script == null:
		T.fail_and_quit(self, "Missing res://city_game/world/model/CityWorldConfig.gd")
		return

	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	if generator_script == null:
		T.fail_and_quit(self, "Missing res://city_game/world/generation/CityWorldGenerator.gd")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world: Dictionary = generator.generate_world(config)
	if not T.require_true(self, world.has("pedestrian_query"), "World data must include pedestrian_query"):
		return

	var pedestrian_query = world["pedestrian_query"]
	if not T.require_true(self, pedestrian_query.has_method("get_density_for_district_class"), "pedestrian_query must expose get_density_for_district_class()"):
		return
	if not T.require_true(self, pedestrian_query.has_method("get_density_for_road_class"), "pedestrian_query must expose get_density_for_road_class()"):
		return
	if not T.require_true(self, pedestrian_query.has_method("get_profile_for_district"), "pedestrian_query must expose get_profile_for_district()"):
		return

	var core_density := float(pedestrian_query.get_density_for_district_class("core"))
	var periphery_density := float(pedestrian_query.get_density_for_district_class("periphery"))
	if not T.require_true(self, core_density > periphery_density, "core district density must be greater than periphery density"):
		return

	var arterial_density := float(pedestrian_query.get_density_for_road_class("arterial"))
	var expressway_density := float(pedestrian_query.get_density_for_road_class("expressway_elevated"))
	if not T.require_true(self, arterial_density > expressway_density, "arterial road density must exceed expressway density"):
		return

	var district_grid: Vector2i = config.get_district_grid_size()
	var center_district_key := Vector2i(
		int(floor(float(district_grid.x) * 0.5)),
		int(floor(float(district_grid.y) * 0.5))
	)
	var center_profile: Dictionary = pedestrian_query.get_profile_for_district(config.format_district_id(center_district_key))
	if not T.require_true(self, str(center_profile.get("district_class", "")).length() > 0, "District profile must expose district_class"):
		return
	if not T.require_true(self, str(center_profile.get("density_bucket", "")).length() > 0, "District profile must expose density_bucket"):
		return
	if not T.require_true(self, float(center_profile.get("density_scalar", 0.0)) > 0.0, "District profile must expose density_scalar"):
		return
	var archetype_weights: Dictionary = center_profile.get("archetype_weights", {})
	if not T.require_true(self, not archetype_weights.is_empty(), "District profile must expose archetype_weights"):
		return

	var snapshot: Dictionary = pedestrian_query.get_profile_snapshot()
	if not T.require_true(self, snapshot.has("district_class_density"), "profile snapshot must expose district_class_density"):
		return
	if not T.require_true(self, snapshot.has("road_class_density"), "profile snapshot must expose road_class_density"):
		return
	if not T.require_true(self, snapshot.has("default_archetype_weights"), "profile snapshot must expose default_archetype_weights"):
		return

	var district_density_snapshot: Dictionary = snapshot.get("district_class_density", {})
	var expected_district_mins := {
		"core": 0.78,
		"mixed": 0.62,
		"residential": 0.46,
		"industrial": 0.30,
		"periphery": 0.16,
	}
	for district_class in ["core", "mixed", "residential", "industrial", "periphery"]:
		if not T.require_true(self, float(district_density_snapshot.get(district_class, 0.0)) >= float(expected_district_mins.get(district_class, 0.0)), "lite district density for %s must meet the M7 uplift floor" % district_class):
			return
	var ordered_districts := ["core", "mixed", "residential", "industrial", "periphery"]
	for district_index in range(ordered_districts.size() - 1):
		var current_district := str(ordered_districts[district_index])
		var next_district := str(ordered_districts[district_index + 1])
		if not T.require_true(self, float(district_density_snapshot.get(current_district, 0.0)) > float(district_density_snapshot.get(next_district, 0.0)), "lite district density must keep %s denser than %s" % [current_district, next_district]):
			return

	var road_density_snapshot: Dictionary = snapshot.get("road_class_density", {})
	var expected_road_mins := {
		"arterial": 0.45,
		"secondary": 0.32,
		"collector": 0.20,
		"local": 0.12,
		"expressway_elevated": 0.0,
	}
	for road_class in ["arterial", "secondary", "collector", "local", "expressway_elevated"]:
		if not T.require_true(self, float(road_density_snapshot.get(road_class, -1.0)) >= float(expected_road_mins.get(road_class, 0.0)), "lite road density for %s must meet the M7 uplift floor" % road_class):
			return
	var ordered_road_classes := ["arterial", "secondary", "collector", "local", "expressway_elevated"]
	for road_index in range(ordered_road_classes.size() - 1):
		var current_road_class := str(ordered_road_classes[road_index])
		var next_road_class := str(ordered_road_classes[road_index + 1])
		if not T.require_true(self, float(road_density_snapshot.get(current_road_class, 0.0)) > float(road_density_snapshot.get(next_road_class, 0.0)), "lite road density must keep %s denser than %s" % [current_road_class, next_road_class]):
			return

	T.pass_and_quit(self)
