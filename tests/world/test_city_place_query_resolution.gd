extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	if config_script == null or generator_script == null:
		T.fail_and_quit(self, "Place query resolution test requires CityWorldConfig and CityWorldGenerator")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)

	if not T.require_true(self, world_data.has("place_index"), "World generation must expose place_index for v12 M2"):
		return
	if not T.require_true(self, world_data.has("place_query"), "World generation must expose place_query for v12 M2"):
		return
	if not T.require_true(self, world_data.has("route_target_index"), "World generation must expose route_target_index for v12 M2"):
		return

	var place_query = world_data.get("place_query")
	if not T.require_true(self, place_query != null and place_query.has_method("resolve_query"), "place_query must expose resolve_query()"):
		return
	if not T.require_true(self, place_query.has_method("get_debug_sample_queries"), "place_query must expose get_debug_sample_queries()"):
		return

	var sample_queries: Dictionary = place_query.get_debug_sample_queries()
	for sample_key in ["road", "intersection", "landmark", "address"]:
		if not T.require_true(self, str(sample_queries.get(sample_key, "")) != "", "place_query must provide a non-empty %s sample query" % sample_key):
			return
		var resolved_target: Dictionary = place_query.resolve_query(str(sample_queries.get(sample_key, "")))
		if not T.require_true(self, not resolved_target.is_empty(), "place_query must resolve the %s sample query" % sample_key):
			return
		if not T.require_true(self, resolved_target.has("world_anchor"), "Resolved %s target must include world_anchor" % sample_key):
			return
		if not T.require_true(self, resolved_target.has("routable_anchor"), "Resolved %s target must include routable_anchor" % sample_key):
			return

	T.pass_and_quit(self)
