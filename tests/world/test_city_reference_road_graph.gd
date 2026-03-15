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
	if not T.require_true(self, int(growth_stats.get("population_center_count", 0)) >= 3, "Reference-style road graph must expose one main center plus multiple satellites in v13"):
		return
	if not T.require_true(self, int(growth_stats.get("satellite_center_count", 0)) >= 2, "Reference-style road graph must expose satellite centers in v13"):
		return
	if not T.require_true(self, int(growth_stats.get("corridor_count", 0)) >= 2, "Reference-style road graph must expose corridor links between centers in v13"):
		return
	var corridors: Array = growth_stats.get("corridors", [])
	if not T.require_true(self, corridors.size() >= 2, "Reference-style road graph must publish corridor metadata for continuity validation"):
		return
	var population_centers: Array = growth_stats.get("population_centers", [])
	if not T.require_true(self, population_centers.size() >= 3, "Reference-style road graph must publish population center metadata for overview validation"):
		return
	var road_windows_with_edges := 0
	for center_variant in population_centers:
		var center_record: Dictionary = center_variant
		var center_position: Vector2 = center_record.get("position", Vector2.ZERO)
		var window_edges: Array = road_graph.get_edges_intersecting_rect(Rect2(center_position - Vector2.ONE * 900.0, Vector2.ONE * 1800.0))
		if not window_edges.is_empty():
			road_windows_with_edges += 1
	if not T.require_true(self, road_windows_with_edges >= 3, "Main center plus satellite windows must all contain real road edges"):
		return
	for corridor_variant in corridors:
		var corridor: Dictionary = corridor_variant
		if str(corridor.get("corridor_kind", "")) != "main_satellite":
			continue
		var samples_with_roads := 0
		var start: Vector2 = corridor.get("start", Vector2.ZERO)
		var finish: Vector2 = corridor.get("end", Vector2.ZERO)
		for sample_index in range(1, 6):
			var ratio := float(sample_index) / 6.0
			var sample_point := start.lerp(finish, ratio)
			var corridor_window := Rect2(sample_point - Vector2.ONE * 1200.0, Vector2.ONE * 2400.0)
			if not road_graph.get_edges_intersecting_rect(corridor_window).is_empty():
				samples_with_roads += 1
		if not T.require_true(self, samples_with_roads >= 5, "Each published corridor must stay continuously occupied by road coverage between main and satellite centers"):
			return

	var intersections: Array = road_graph.get_intersections_in_rect(Rect2(Vector2(-1200.0, -1200.0), Vector2(2400.0, 2400.0)))
	if not T.require_true(self, intersections.size() > 0, "City center must expose real intersection nodes from the shared road graph"):
		return
	if not T.require_true(self, int((intersections[0] as Dictionary).get("degree", 0)) >= 3, "Shared road graph intersections must include degree metadata for routing and minimap display"):
		return

	T.pass_and_quit(self)
