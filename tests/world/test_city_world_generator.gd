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
	if not T.require_true(self, district_graph.get_district_count() == 49, "district_graph must contain 49 districts"):
		return

	var road_graph = world_a["road_graph"]
	if not T.require_true(self, road_graph.has_method("get_edge_count"), "road_graph must expose get_edge_count()"):
		return
	if not T.require_true(self, road_graph.get_edge_count() > 0, "road_graph must contain edges"):
		return

	var block_layout = world_a["block_layout"]
	if not T.require_true(self, block_layout.has_method("get_block_count"), "block_layout must expose get_block_count()"):
		return
	if not T.require_true(self, block_layout.has_method("get_parcel_count"), "block_layout must expose get_parcel_count()"):
		return
	if not T.require_true(self, block_layout.get_block_count() > 0, "block_layout must contain blocks"):
		return
	if not T.require_true(self, block_layout.get_parcel_count() > block_layout.get_block_count(), "parcel count must be greater than block count"):
		return

	if not T.require_true(self, district_graph.get_district_ids()[0] == world_b["district_graph"].get_district_ids()[0], "district ids must be deterministic across runs"):
		return
	if not T.require_true(self, block_layout.get_block_ids()[0] == world_b["block_layout"].get_block_ids()[0], "block ids must be deterministic across runs"):
		return

	T.pass_and_quit(self)
