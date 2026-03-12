extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world: Dictionary = CityWorldGenerator.new().generate_world(config)
	if not T.require_true(self, world.has("pedestrian_query"), "World data must include pedestrian_query"):
		return

	var pedestrian_query = world["pedestrian_query"]
	if not T.require_true(self, pedestrian_query.has_method("get_lane_graph"), "pedestrian_query must expose get_lane_graph()"):
		return
	var lane_graph = pedestrian_query.get_lane_graph()
	if not T.require_true(self, lane_graph != null, "lane_graph must exist"):
		return
	if not T.require_true(self, lane_graph.has_method("get_lane_count"), "lane_graph must expose get_lane_count()"):
		return
	if not T.require_true(self, lane_graph.has_method("get_lanes_intersecting_rect"), "lane_graph must expose get_lanes_intersecting_rect()"):
		return
	if not T.require_true(self, lane_graph.has_method("get_lane_by_id"), "lane_graph must expose get_lane_by_id()"):
		return
	if not T.require_true(self, lane_graph.get_lane_count() > 0, "lane_graph must contain lanes"):
		return

	var center_chunk := _center_chunk(config)
	var chunk_query: Dictionary = pedestrian_query.get_pedestrian_query_for_chunk(center_chunk)
	var chunk_rect := _build_chunk_rect(config, center_chunk)
	var chunk_lanes: Array = lane_graph.get_lanes_intersecting_rect(chunk_rect.grow(float(config.chunk_size_m) * 0.25))
	if not T.require_true(self, not chunk_lanes.is_empty(), "Center chunk lane query must return lanes"):
		return

	var sidewalk_count := 0
	var crossing_count := 0
	for lane_variant in chunk_lanes:
		var lane: Dictionary = lane_variant
		var lane_type := str(lane.get("lane_type", ""))
		if lane_type == "sidewalk":
			sidewalk_count += 1
		elif lane_type == "crossing":
			crossing_count += 1
	if not T.require_true(self, sidewalk_count > 0, "Center chunk lane query must include sidewalk lanes"):
		return
	if not T.require_true(self, crossing_count > 0, "Center chunk lane query must include crossing lanes"):
		return

	var spawn_slots: Array = chunk_query.get("spawn_slots", [])
	if not T.require_true(self, not spawn_slots.is_empty(), "Center chunk query must expose spawn_slots sourced from lane graph"):
		return
	var first_slot: Dictionary = spawn_slots[0]
	var slot_lane: Dictionary = lane_graph.get_lane_by_id(str(first_slot.get("lane_ref_id", "")))
	if not T.require_true(self, str(slot_lane.get("lane_type", "")) == "sidewalk", "Spawn slots must bind to sidewalk lanes"):
		return
	if not T.require_true(self, str(slot_lane.get("road_id", "")) == str(first_slot.get("road_id", "")), "Spawn slot road_id must match lane road_id"):
		return
	if not T.require_true(self, str(slot_lane.get("side", "")) == str(first_slot.get("side", "")), "Spawn slot side must match lane side"):
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
