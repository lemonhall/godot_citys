extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var runtime_script := load("res://city_game/world/navigation/CityChunkNavRuntime.gd")
	if config_script == null or generator_script == null or runtime_script == null:
		T.fail_and_quit(self, "Route query contract test requires CityWorldConfig, CityWorldGenerator, and CityChunkNavRuntime")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)
	var place_query = world_data.get("place_query")
	if not T.require_true(self, place_query != null and place_query.has_method("resolve_world_point"), "Route query contract requires place_query.resolve_world_point()"):
		return
	if not T.require_true(self, place_query.has_method("get_debug_sample_queries"), "Route query contract requires place_query debug samples"):
		return

	var debug_samples: Dictionary = place_query.get_debug_sample_queries()
	var origin_target: Dictionary = place_query.resolve_world_point(Vector3(-1400.0, 1.1, 26.0))
	var destination_target: Dictionary = place_query.resolve_query(str(debug_samples.get("landmark", "")))
	var nav_runtime = runtime_script.new(config, world_data)
	if not T.require_true(self, nav_runtime.has_method("plan_route_result"), "CityChunkNavRuntime must expose plan_route_result() for v12 M3"):
		return

	var route_result: Dictionary = nav_runtime.plan_route_result(origin_target, destination_target, 0)
	if not T.require_true(self, not route_result.is_empty(), "Route planner must return a non-empty route_result"):
		if nav_runtime.has_method("get_route_debug_graph_stats"):
			print("ROUTE_DEBUG %s" % JSON.stringify(nav_runtime.get_route_debug_graph_stats()))
		if nav_runtime.has_method("debug_plan_route"):
			print("ROUTE_PLAN_DEBUG %s" % JSON.stringify(nav_runtime.debug_plan_route(origin_target, destination_target)))
		return
	for required_key in ["route_id", "origin_target_id", "destination_target_id", "snapped_origin", "snapped_destination", "polyline", "steps", "maneuvers", "distance_m", "estimated_time_s", "reroute_generation", "source_version"]:
		if not T.require_true(self, route_result.has(required_key), "route_result must expose %s" % required_key):
			return
	if not T.require_true(self, str(route_result.get("graph_source", "")) == "vehicle_lane_graph_view", "Formal route planner must declare vehicle_lane_graph_view as its source"):
		return
	if not T.require_true(self, (route_result.get("polyline", []) as Array).size() >= 2, "route_result polyline must contain at least start and destination anchors"):
		return
	if not T.require_true(self, (route_result.get("steps", []) as Array).size() > 0, "route_result must expose at least one step"):
		return
	if not T.require_true(self, (route_result.get("maneuvers", []) as Array).size() >= 2, "route_result must expose at least depart/arrive maneuvers"):
		return
	var first_turn: Dictionary = (route_result.get("maneuvers", []) as Array)[0]
	for maneuver_key in ["turn_type", "distance_to_next_m", "road_name_from", "road_name_to", "world_anchor", "instruction_short"]:
		if not T.require_true(self, first_turn.has(maneuver_key), "maneuver entries must expose %s" % maneuver_key):
			return

	T.pass_and_quit(self)
