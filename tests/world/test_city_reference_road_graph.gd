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

	if not T.require_true(self, road_graph != null, "World data must include road_graph for reference-style generation"):
		return
	if not T.require_true(self, road_graph.has_method("get_growth_stats"), "road_graph must expose get_growth_stats() for reference-style growth evidence"):
		return
	if not T.require_true(self, road_graph.has_method("get_intersections_in_rect"), "road_graph must expose get_intersections_in_rect() so chunk systems can query actual intersection nodes"):
		return

	var growth_stats: Dictionary = road_graph.get_growth_stats()
	if not T.require_true(self, int(growth_stats.get("seed_count", 0)) >= 2, "Reference-style road graph must start from multiple seed segments, not one coarse grid pass"):
		return
	if not T.require_true(self, int(growth_stats.get("non_axis_edge_count", 0)) > 0, "Reference-style road graph must contain non-axis edges"):
		return
	if not T.require_true(self, int(growth_stats.get("snap_event_count", 0)) > 0, "Reference-style road graph must record endpoint snap events"):
		return
	if not T.require_true(self, int(growth_stats.get("split_event_count", 0)) > 0, "Reference-style road graph must record intersection split events"):
		return

	var intersections: Array = road_graph.get_intersections_in_rect(Rect2(Vector2(-1200.0, -1200.0), Vector2(2400.0, 2400.0)))
	if not T.require_true(self, intersections.size() > 0, "City center must expose real intersection nodes from the shared road graph"):
		return
	if not T.require_true(self, int((intersections[0] as Dictionary).get("degree", 0)) >= 3, "Shared road graph intersections must include degree metadata for routing and minimap display"):
		return

	T.pass_and_quit(self)
