extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	config.base_seed = int(Time.get_ticks_usec() & 0x7fffffff)
	config.world_width_m = 6000
	config.world_depth_m = 6000
	config.district_size_m = 1000

	var generator := CityWorldGenerator.new()
	var first_world: Dictionary = generator.generate_world(config)
	var first_profile: Dictionary = first_world.get("generation_profile", {})
	if not T.require_true(self, first_profile.has("road_graph_cache_hit"), "Generation profile must expose road_graph_cache_hit on first run"):
		return
	if not T.require_true(self, first_profile.has("road_graph_cache_path"), "Generation profile must expose road_graph_cache_path on first run"):
		return
	if not T.require_true(self, not bool(first_profile.get("road_graph_cache_hit", true)), "First road graph generation for a fresh seed should miss disk cache"):
		return

	var second_world: Dictionary = generator.generate_world(config)
	var second_profile: Dictionary = second_world.get("generation_profile", {})
	if not T.require_true(self, bool(second_profile.get("road_graph_cache_hit", false)), "Second road graph generation for the same config should hit disk cache"):
		return

	var cache_path := str(second_profile.get("road_graph_cache_path", ""))
	if not T.require_true(self, cache_path != "", "Road graph cache hit must report a cache path"):
		return
	if not T.require_true(self, FileAccess.file_exists(cache_path), "Road graph cache path must exist on disk after generation"):
		return

	var first_road_graph = first_world.get("road_graph")
	var second_road_graph = second_world.get("road_graph")
	if not T.require_true(self, first_road_graph != null and second_road_graph != null, "World generation must still return road_graph on cache miss and hit"):
		return
	if not T.require_true(self, first_road_graph.get_edge_count() == second_road_graph.get_edge_count(), "Road graph cache hit must preserve edge count"):
		return

	var rect := Rect2(Vector2(-800.0, -800.0), Vector2(1600.0, 1600.0))
	var first_edges: Array = first_road_graph.get_edges_intersecting_rect(rect)
	var second_edges: Array = second_road_graph.get_edges_intersecting_rect(rect)
	if not T.require_true(self, first_edges.size() == second_edges.size(), "Road graph cache hit must preserve query results in the center window"):
		return

	T.pass_and_quit(self)
