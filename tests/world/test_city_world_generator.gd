extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	if config_script == null:
		T.fail_and_quit(self, "Missing res://city_game/world/model/CityWorldConfig.gd")
		return

	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	if generator_script == null:
		T.fail_and_quit(self, "Missing res://city_game/world/generation/CityWorldGenerator.gd")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	if not T.require_true(self, generator != null, "CityWorldGenerator must instantiate"):
		return

	var world_a: Dictionary = generator.generate_world(config)
	var world_b: Dictionary = generator.generate_world(config)

	if not T.require_true(self, world_a.has("district_graph"), "World data must include district_graph"):
		return
	if not T.require_true(self, world_a.has("road_graph"), "World data must include road_graph"):
		return
	if not T.require_true(self, world_a.has("block_layout"), "World data must include block_layout"):
		return

	var district_graph = world_a["district_graph"]
	if not T.require_true(self, district_graph.has_method("get_district_count"), "district_graph must expose get_district_count()"):
		return
	if not T.require_true(self, district_graph.get_district_count() == 4900, "district_graph must contain 4900 districts"):
		return

	var road_graph = world_a["road_graph"]
	if not T.require_true(self, road_graph.has_method("get_edge_count"), "road_graph must expose get_edge_count()"):
		return
	if not T.require_true(self, road_graph.has_method("get_edges_intersecting_rect"), "road_graph must expose get_edges_intersecting_rect() for chunk-local road queries"):
		return
	if not T.require_true(self, road_graph.has_method("get_growth_stats"), "road_graph must expose get_growth_stats() for world morphology validation"):
		return
	if not T.require_true(self, road_graph.get_edge_count() < 5000, "v13 road_graph must stop using the full-world district lattice as the visible road backbone"):
		return
	var growth_stats: Dictionary = road_graph.get_growth_stats()
	if not T.require_true(self, int(growth_stats.get("population_center_count", 0)) >= 3, "v13 world generation must expose at least one main center plus multiple satellite centers"):
		return
	if not T.require_true(self, int(growth_stats.get("satellite_center_count", 0)) >= 2, "v13 world generation must expose at least two satellite centers"):
		return
	if not T.require_true(self, int(growth_stats.get("corridor_count", 0)) >= 2, "v13 world generation must expose corridor links between centers"):
		return
	var center_edges: Array = road_graph.get_edges_intersecting_rect(Rect2(Vector2(-640.0, -640.0), Vector2(1280.0, 1280.0)))
	if not T.require_true(self, center_edges.size() > 0, "road_graph must provide world-space edges around the city center window"):
		return
	if not T.require_true(self, (center_edges[0] as Dictionary).get("points", []).size() >= 3, "road_graph edges must carry curved world-space polyline points"):
		return
	var population_centers: Array = growth_stats.get("population_centers", [])
	var windows_with_roads := 0
	for center_variant in population_centers:
		var center_record: Dictionary = center_variant
		var position: Vector2 = center_record.get("position", Vector2.ZERO)
		var sample_edges: Array = road_graph.get_edges_intersecting_rect(Rect2(position - Vector2.ONE * 900.0, Vector2.ONE * 1800.0))
		if not sample_edges.is_empty():
			windows_with_roads += 1
	if not T.require_true(self, windows_with_roads >= 3, "Main center plus satellite centers must all own real local road windows"):
		return

	var block_layout = world_a["block_layout"]
	if not T.require_true(self, block_layout.has_method("get_block_count"), "block_layout must expose get_block_count()"):
		return
	if not T.require_true(self, block_layout.has_method("get_parcel_count"), "block_layout must expose get_parcel_count()"):
		return
	if not T.require_true(self, block_layout.has_method("get_blocks_for_chunk"), "block_layout must expose get_blocks_for_chunk() for lazy chunk queries"):
		return
	if not T.require_true(self, block_layout.has_method("get_first_block_id"), "block_layout must expose get_first_block_id() for deterministic sampling"):
		return
	if not T.require_true(self, block_layout.get_block_count() == 300304, "block_layout must report the full 70km block count"):
		return
	if not T.require_true(self, block_layout.get_parcel_count() == 1201216, "block_layout must report the full 70km parcel count"):
		return
	if not T.require_true(self, block_layout.get_parcel_count() > block_layout.get_block_count(), "parcel count must be greater than block count"):
		return

	var sample_blocks: Array = block_layout.get_blocks_for_chunk(Vector2i(0, 0))
	if not T.require_true(self, sample_blocks.size() == 4, "Each chunk query must yield 4 deterministic blocks"):
		return
	if not T.require_true(self, str(sample_blocks[0].get("chunk_id", "")) == config.format_chunk_id(Vector2i(0, 0)), "Lazy chunk blocks must preserve chunk_id"):
		return

	if not T.require_true(self, district_graph.get_district_ids()[0] == world_b["district_graph"].get_district_ids()[0], "district ids must be deterministic across runs"):
		return
	if not T.require_true(self, block_layout.get_first_block_id() == world_b["block_layout"].get_first_block_id(), "block ids must be deterministic across runs"):
		return
	if not T.require_true(self, str(world_a.get("summary", "")).begins_with("70km x 70km"), "summary must report the 70km world dimensions"):
		return

	T.pass_and_quit(self)
