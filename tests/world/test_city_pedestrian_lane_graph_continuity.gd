extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world: Dictionary = CityWorldGenerator.new().generate_world(config)
	var pedestrian_query = world.get("pedestrian_query")
	if not T.require_true(self, pedestrian_query != null, "World data must include pedestrian_query"):
		return
	if not T.require_true(self, pedestrian_query.has_method("get_lane_graph"), "pedestrian_query must expose get_lane_graph()"):
		return

	var lane_graph = pedestrian_query.get_lane_graph()
	if not T.require_true(self, lane_graph.has_method("get_boundary_connectors_for_rect"), "lane_graph must expose get_boundary_connectors_for_rect()"):
		return

	var chunk_key := _center_chunk(config)
	var rect_a := _build_chunk_rect(config, chunk_key)
	var rect_b := _build_chunk_rect(config, chunk_key + Vector2i.RIGHT)
	var rect_c := _build_chunk_rect(config, chunk_key + Vector2i.DOWN)

	var connectors_a: Dictionary = lane_graph.get_boundary_connectors_for_rect(rect_a, ["sidewalk"])
	var connectors_b: Dictionary = lane_graph.get_boundary_connectors_for_rect(rect_b, ["sidewalk"])
	var connectors_c: Dictionary = lane_graph.get_boundary_connectors_for_rect(rect_c, ["sidewalk"])

	if not T.require_true(self, _match_connectors(connectors_a.get("east", []), connectors_b.get("west", [])), "Pedestrian sidewalk connectors must match across east/west chunk boundaries"):
		return
	if not T.require_true(self, _match_connectors(connectors_a.get("south", []), connectors_c.get("north", [])), "Pedestrian sidewalk connectors must match across north/south chunk boundaries"):
		return

	T.pass_and_quit(self)

func _center_chunk(config: CityWorldConfig) -> Vector2i:
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	return Vector2i(
		int(floor(float(chunk_grid.x) * 0.5)),
		int(floor(float(chunk_grid.y) * 0.5))
	)

func _build_chunk_rect(config: CityWorldConfig, chunk_key: Vector2i) -> Rect2:
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_size := float(config.chunk_size_m)
	var chunk_origin := Vector2(
		bounds.position.x + float(chunk_key.x) * chunk_size,
		bounds.position.y + float(chunk_key.y) * chunk_size
	)
	return Rect2(chunk_origin, Vector2.ONE * chunk_size)

func _match_connectors(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		var a_entry: Dictionary = a[index]
		var b_entry: Dictionary = b[index]
		if absf(float(a_entry.get("offset", 0.0)) - float(b_entry.get("offset", 0.0))) > 0.1:
			return false
	return true
