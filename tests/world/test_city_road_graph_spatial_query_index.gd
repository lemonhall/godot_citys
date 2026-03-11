extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var road_graph = world_data.get("road_graph")
	if not T.require_true(self, road_graph != null, "World generation must expose road_graph for spatial query indexing"):
		return
	if not T.require_true(self, road_graph.has_method("get_query_stats"), "road_graph must expose get_query_stats() for spatial query diagnostics"):
		return
	if not T.require_true(self, road_graph.has_method("reset_query_stats"), "road_graph must expose reset_query_stats() for spatial query diagnostics"):
		return

	road_graph.reset_query_stats()
	var rect := Rect2(Vector2(-640.0, -640.0), Vector2(1280.0, 1280.0))
	var center_edges: Array = road_graph.get_edges_intersecting_rect(rect)
	var stats: Dictionary = road_graph.get_query_stats()

	if not T.require_true(self, center_edges.size() > 0, "Center query must still return road graph edges after spatial indexing"):
		return
	if not T.require_true(self, int(stats.get("last_result_count", -1)) == center_edges.size(), "Spatial query stats must report the same result count returned to callers"):
		return
	if not T.require_true(self, int(stats.get("last_candidate_count", 0)) > 0, "Spatial query stats must report candidate edges for the queried cells"):
		return
	if not T.require_true(self, int(stats.get("last_candidate_count", 0)) < road_graph.get_edge_count(), "Small window queries must not fall back to scanning every edge in the entire road graph"):
		return

	T.pass_and_quit(self)
