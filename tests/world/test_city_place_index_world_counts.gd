extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	if config_script == null or generator_script == null:
		T.fail_and_quit(self, "Place index world counts test requires CityWorldConfig and CityWorldGenerator")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)
	var generation_profile: Dictionary = world_data.get("generation_profile", {})

	if not T.require_true(self, world_data.has("street_cluster_catalog"), "World generation must expose street_cluster_catalog for v12 M1 counts freeze"):
		return
	var street_cluster_catalog = world_data.get("street_cluster_catalog")
	if not T.require_true(self, street_cluster_catalog != null and street_cluster_catalog.has_method("get_cluster_count"), "street_cluster_catalog must expose get_cluster_count()"):
		return
	if not T.require_true(self, street_cluster_catalog.has_method("get_world_counts"), "street_cluster_catalog must expose get_world_counts()"):
		return

	var cluster_count := int(street_cluster_catalog.get_cluster_count())
	var world_counts: Dictionary = street_cluster_catalog.get_world_counts()
	if not T.require_true(self, cluster_count >= 5000 and cluster_count <= 7000, "Canonical street cluster count must freeze into the 6000 +/- 1000 band"):
		return
	if not T.require_true(self, int(world_counts.get("road_edge_count", 0)) >= 30000, "World counts must report the full road edge order of magnitude for v12 planning"):
		return
	if not T.require_true(self, int(world_counts.get("intersection_count", 0)) >= 10000, "World counts must report the full world intersection order of magnitude for v12 planning"):
		return
	if not T.require_true(self, int(world_counts.get("block_count", 0)) == 300304, "World counts must preserve the frozen block count"):
		return
	if not T.require_true(self, int(world_counts.get("parcel_count", 0)) == 1201216, "World counts must preserve the frozen parcel count"):
		return
	if not T.require_true(self, int(generation_profile.get("street_cluster_count", 0)) == cluster_count, "Generation profile must surface the canonical street cluster count"):
		return

	T.pass_and_quit(self)
