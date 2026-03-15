extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var resolved_target_script := load("res://city_game/world/model/CityResolvedTarget.gd")
	if config_script == null or generator_script == null or resolved_target_script == null:
		T.fail_and_quit(self, "Resolved target contract test requires CityWorldConfig, CityWorldGenerator, and CityResolvedTarget")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)
	var place_query = world_data.get("place_query")
	if not T.require_true(self, place_query != null and place_query.has_method("get_debug_sample_queries"), "Resolved target contract requires place_query debug samples"):
		return

	var sample_queries: Dictionary = place_query.get_debug_sample_queries()
	var landmark_query := str(sample_queries.get("landmark", ""))
	var landmark_target: Dictionary = place_query.resolve_query(landmark_query)
	for required_key in ["source_kind", "source_query", "place_id", "raw_world_anchor", "world_anchor", "routable_anchor", "selection_mode", "source_version"]:
		if not T.require_true(self, landmark_target.has(required_key), "resolved_target must expose %s" % required_key):
			return
	if not T.require_true(self, str(landmark_target.get("source_query", "")) == landmark_query, "resolved_target must preserve source_query verbatim"):
		return
	if not T.require_true(self, str(landmark_target.get("selection_mode", "")) == "query", "Named query resolution must keep selection_mode=query"):
		return
	if not T.require_true(self, str(landmark_target.get("place_id", "")) != "", "Named place queries must preserve place_id"):
		return

	var raw_target: Dictionary = place_query.resolve_world_point(Vector3(128.0, 0.0, -96.0))
	if not T.require_true(self, not raw_target.is_empty(), "place_query must resolve raw world points into resolved_target contract"):
		return
	if not T.require_true(self, str(raw_target.get("selection_mode", "")) == "raw_world_point", "Raw point selection must declare selection_mode=raw_world_point"):
		return
	if not T.require_true(self, raw_target.get("raw_world_anchor", null) != null, "Raw point selection must preserve raw_world_anchor"):
		return

	T.pass_and_quit(self)
