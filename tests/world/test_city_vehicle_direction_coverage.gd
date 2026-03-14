extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var vehicle_query = world_data.get("vehicle_query")
	if not T.require_true(self, vehicle_query != null and vehicle_query.has_method("get_vehicle_query_for_chunk"), "vehicle_query must exist for direction coverage validation"):
		return
	if not T.require_true(self, vehicle_query.has_method("get_lane_graph"), "vehicle_query must expose get_lane_graph() for direction coverage validation"):
		return

	var lane_graph = vehicle_query.get_lane_graph()
	var candidate := _find_bidirectional_candidate_chunk(config, vehicle_query, lane_graph)
	if not T.require_true(self, not candidate.is_empty(), "Center play corridor must expose at least one chunk with two-way driving lanes and vehicle spawn capacity >= 2"):
		return

	var query: Dictionary = candidate.get("query", {})
	var spawn_directions := _collect_spawn_directions(query.get("spawn_slots", []))
	print("CITY_VEHICLE_DIRECTION_COVERAGE %s" % JSON.stringify({
		"chunk_key": candidate.get("chunk_key", Vector2i.ZERO),
		"road_id": str(candidate.get("road_id", "")),
		"available_directions": candidate.get("available_directions", []),
		"spawn_directions": spawn_directions,
		"spawn_capacity": int(query.get("spawn_capacity", 0)),
	}))

	if not T.require_true(self, spawn_directions.size() >= 2, "Vehicle query must keep both directions visible when a chunk road exposes forward and backward lanes with capacity >= 2"):
		return

	T.pass_and_quit(self)

func _find_bidirectional_candidate_chunk(config, vehicle_query, lane_graph) -> Dictionary:
	var grid: Vector2i = config.get_chunk_grid_size()
	var center_chunk := Vector2i(grid.x / 2, grid.y / 2)
	for y in range(center_chunk.y - 2, center_chunk.y + 3):
		for x in range(center_chunk.x - 2, center_chunk.x + 3):
			if x < 0 or y < 0 or x >= grid.x or y >= grid.y:
				continue
			var chunk_key := Vector2i(x, y)
			var query: Dictionary = vehicle_query.get_vehicle_query_for_chunk(chunk_key)
			if int(query.get("spawn_capacity", 0)) < 2:
				continue
			var dominant_road_id := _resolve_dominant_road_id(query.get("spawn_slots", []))
			if dominant_road_id == "":
				continue
			var chunk_rect := _build_chunk_rect(config, chunk_key).grow(float(config.chunk_size_m) * 0.35)
			var lanes: Array = lane_graph.get_lanes_intersecting_rect(chunk_rect, ["driving"])
			var available_directions := {}
			for lane_variant in lanes:
				var lane: Dictionary = lane_variant
				if str(lane.get("road_id", "")) != dominant_road_id:
					continue
				available_directions[str(lane.get("direction", ""))] = true
			if available_directions.size() >= 2:
				return {
					"chunk_key": chunk_key,
					"query": query,
					"road_id": dominant_road_id,
					"available_directions": available_directions.keys(),
				}
	return {}

func _resolve_dominant_road_id(spawn_slots: Array) -> String:
	var road_counts: Dictionary = {}
	for slot_variant in spawn_slots:
		var slot: Dictionary = slot_variant
		var road_id := str(slot.get("road_id", ""))
		if road_id == "":
			continue
		road_counts[road_id] = int(road_counts.get(road_id, 0)) + 1
	var best_road_id := ""
	var best_count := 0
	for road_id_variant in road_counts.keys():
		var road_id := str(road_id_variant)
		var count := int(road_counts.get(road_id, 0))
		if count > best_count:
			best_road_id = road_id
			best_count = count
	return best_road_id

func _collect_spawn_directions(spawn_slots: Array) -> Array:
	var directions: Array = []
	var seen: Dictionary = {}
	for slot_variant in spawn_slots:
		var slot: Dictionary = slot_variant
		var direction := str(slot.get("direction", ""))
		if direction == "" or seen.has(direction):
			continue
		seen[direction] = true
		directions.append(direction)
	directions.sort()
	return directions

func _build_chunk_rect(config, chunk_key: Vector2i) -> Rect2:
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_size := float(config.chunk_size_m)
	var chunk_origin := Vector2(
		bounds.position.x + float(chunk_key.x) * chunk_size,
		bounds.position.y + float(chunk_key.y) * chunk_size
	)
	return Rect2(chunk_origin, Vector2.ONE * chunk_size)
