extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var runtime_script := load("res://city_game/world/navigation/CityChunkNavRuntime.gd")
	if config_script == null or generator_script == null or runtime_script == null:
		T.fail_and_quit(self, "Route cache test requires CityWorldConfig, CityWorldGenerator, and CityChunkNavRuntime")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)
	var place_query = world_data.get("place_query")
	if not T.require_true(self, place_query != null and place_query.has_method("get_debug_sample_queries"), "Route cache test requires place_query debug samples"):
		return

	var debug_samples: Dictionary = place_query.get_debug_sample_queries()
	var origin_target: Dictionary = place_query.resolve_world_point(Vector3(-1400.0, 1.1, 26.0))
	var destination_target: Dictionary = place_query.resolve_query(str(debug_samples.get("landmark", "")))
	var nav_runtime = runtime_script.new(config, world_data)
	if not T.require_true(self, nav_runtime.has_method("get_route_cache_stats"), "CityChunkNavRuntime must expose get_route_cache_stats() for v12 M3"):
		return

	var before_stats: Dictionary = nav_runtime.get_route_cache_stats()
	var first_route: Dictionary = nav_runtime.plan_route_result(origin_target, destination_target, 0)
	var middle_stats: Dictionary = nav_runtime.get_route_cache_stats()
	var second_route: Dictionary = nav_runtime.plan_route_result(origin_target, destination_target, 0)
	var after_stats: Dictionary = nav_runtime.get_route_cache_stats()

	if not T.require_true(self, not first_route.is_empty() and not second_route.is_empty(), "Route cache test requires two successful route_result queries"):
		return
	if not T.require_true(self, str(first_route.get("route_id", "")) == str(second_route.get("route_id", "")), "Identical route queries must resolve to the same route_id contract"):
		return
	if not T.require_true(self, int(middle_stats.get("miss_count", 0)) > int(before_stats.get("miss_count", 0)), "First route query must register a cache miss"):
		return
	if not T.require_true(self, int(after_stats.get("hit_count", 0)) > int(middle_stats.get("hit_count", 0)), "Repeated route query must register a cache hit"):
		return
	if not T.require_true(self, str(nav_runtime.get_route_graph_version()) != "", "Route runtime must expose a non-empty graph version for cache invalidation"):
		return

	T.pass_and_quit(self)
