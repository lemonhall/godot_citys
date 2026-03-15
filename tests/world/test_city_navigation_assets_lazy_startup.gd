extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	if config_script == null or generator_script == null:
		T.fail_and_quit(self, "Lazy startup test requires CityWorldConfig and CityWorldGenerator")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)
	var generation_profile: Dictionary = world_data.get("generation_profile", {})

	if not T.require_true(self, int(generation_profile.get("street_cluster_usec", -1)) == 0, "Default world startup must not eagerly build street clusters before navigation assets are used"):
		return
	if not T.require_true(self, int(generation_profile.get("place_index_usec", -1)) == 0, "Default world startup must not eagerly build place_index before navigation assets are used"):
		return
	if not T.require_true(self, int(generation_profile.get("place_query_usec", -1)) == 0, "Default world startup must not eagerly build place_query before navigation assets are used"):
		return

	var place_query = world_data.get("place_query")
	if not T.require_true(self, place_query != null and place_query.has_method("get_debug_sample_queries"), "Lazy world startup must still expose a place_query contract"):
		return
	var debug_samples: Dictionary = place_query.get_debug_sample_queries()
	if not T.require_true(self, str(debug_samples.get("road", "")) != "", "Accessing place_query must lazily materialize debug sample queries on demand"):
		return
	generation_profile = world_data.get("generation_profile", {})
	if not T.require_true(self, int(generation_profile.get("street_cluster_usec", 0)) > 0, "Lazy street cluster generation must backfill generation_profile timing once materialized"):
		return
	if not T.require_true(self, int(generation_profile.get("place_index_usec", 0)) > 0, "Lazy place index generation must backfill generation_profile timing once materialized"):
		return

	T.pass_and_quit(self)
