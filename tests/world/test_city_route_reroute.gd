extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var runtime_script := load("res://city_game/world/navigation/CityChunkNavRuntime.gd")
	if config_script == null or generator_script == null or runtime_script == null:
		T.fail_and_quit(self, "Route reroute test requires CityWorldConfig, CityWorldGenerator, and CityChunkNavRuntime")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)
	var place_query = world_data.get("place_query")
	if not T.require_true(self, place_query != null and place_query.has_method("get_debug_sample_queries"), "Route reroute test requires place_query debug samples"):
		return

	var debug_samples: Dictionary = place_query.get_debug_sample_queries()
	var destination_target: Dictionary = place_query.resolve_query(str(debug_samples.get("address", "")))
	var nav_runtime = runtime_script.new(config, world_data)
	if not T.require_true(self, nav_runtime.has_method("reroute_from_world_position"), "CityChunkNavRuntime must expose reroute_from_world_position() for v12 M3"):
		return

	var initial_origin: Dictionary = place_query.resolve_world_point(Vector3(-1600.0, 1.1, 32.0))
	var first_route: Dictionary = nav_runtime.plan_route_result(initial_origin, destination_target, 0)
	if not T.require_true(self, not first_route.is_empty(), "Initial route_result must succeed before reroute assertions run"):
		return
	var rerouted: Dictionary = nav_runtime.reroute_from_world_position(Vector3(640.0, 1.1, 480.0), destination_target, int(first_route.get("reroute_generation", 0)))
	if not T.require_true(self, not rerouted.is_empty(), "Reroute flow must return a new route_result after the origin changes"):
		return
	if not T.require_true(self, int(rerouted.get("reroute_generation", -1)) == int(first_route.get("reroute_generation", 0)) + 1, "Reroute flow must increment reroute_generation exactly once"):
		return
	if not T.require_true(self, str(rerouted.get("route_id", "")) != str(first_route.get("route_id", "")), "Rerouted route_result must produce a new route_id"):
		return

	T.pass_and_quit(self)
