extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world: Dictionary = CityWorldGenerator.new().generate_world(config)
	var vehicle_query = world.get("vehicle_query")
	if not T.require_true(self, vehicle_query != null, "World data must include vehicle_query"):
		return
	if not T.require_true(self, vehicle_query.has_method("get_vehicle_query_for_chunk"), "vehicle_query must expose get_vehicle_query_for_chunk()"):
		return
	if not T.require_true(self, vehicle_query.has_method("get_min_headway_for_road_class"), "vehicle_query must expose get_min_headway_for_road_class()"):
		return

	var target_query := _find_multi_vehicle_spacing_query(config, vehicle_query)
	if not T.require_true(self, not target_query.is_empty(), "At least one center-adjacent chunk must produce multiple same-road vehicles for spacing checks"):
		return

	var spawn_slots: Array = target_query.get("spawn_slots", [])
	var saw_spacing_check := false
	for slot_index in range(spawn_slots.size() - 1):
		var current_slot: Dictionary = spawn_slots[slot_index]
		for next_index in range(slot_index + 1, spawn_slots.size()):
			var next_slot: Dictionary = spawn_slots[next_index]
			if str(current_slot.get("road_id", "")) != str(next_slot.get("road_id", "")):
				continue
			saw_spacing_check = true
			var world_gap := (current_slot.get("world_position", Vector3.ZERO) as Vector3).distance_to(next_slot.get("world_position", Vector3.ZERO))
			var min_headway := maxf(
				float(current_slot.get("min_headway_m", 0.0)),
				float(next_slot.get("min_headway_m", 0.0)),
			)
			var same_lane := str(current_slot.get("lane_ref_id", "")) == str(next_slot.get("lane_ref_id", ""))
			var same_direction := str(current_slot.get("direction", "")) == str(next_slot.get("direction", ""))
			if same_lane:
				var lane_delta := absf(float(next_slot.get("distance_along_lane_m", 0.0)) - float(current_slot.get("distance_along_lane_m", 0.0)))
				if not T.require_true(self, lane_delta + 0.01 >= min_headway - 0.5, "Vehicle spawn slots on the same lane must preserve minimum headway spacing"):
					return
			elif same_direction:
				if not T.require_true(self, world_gap >= maxf(min_headway * 0.85, 12.0), "Same-road vehicles in the same direction must keep a stronger world-space following gap"):
					return
			elif not T.require_true(self, world_gap >= 2.75, "Opposing-direction vehicles on the same road must remain lane-separated instead of collapsing into one another"):
				return
	if not T.require_true(self, saw_spacing_check, "Headway test must validate at least one same-road vehicle spacing pair"):
		return

	T.pass_and_quit(self)

func _find_multi_vehicle_spacing_query(config: CityWorldConfig, vehicle_query) -> Dictionary:
	var center_chunk := _center_chunk(config)
	for offset_x in range(-2, 3):
		for offset_y in range(-2, 3):
			var chunk_key := center_chunk + Vector2i(offset_x, offset_y)
			if chunk_key.x < 0 or chunk_key.y < 0:
				continue
			var chunk_query: Dictionary = vehicle_query.get_vehicle_query_for_chunk(chunk_key)
			if _has_same_road_pair(chunk_query.get("spawn_slots", [])):
				return chunk_query
	return {}

func _has_same_road_pair(spawn_slots: Array) -> bool:
	var road_counts: Dictionary = {}
	for slot_variant in spawn_slots:
		var slot: Dictionary = slot_variant
		var road_id := str(slot.get("road_id", ""))
		if road_id == "":
			continue
		road_counts[road_id] = int(road_counts.get(road_id, 0)) + 1
		if int(road_counts.get(road_id, 0)) >= 2:
			return true
	return false

func _center_chunk(config: CityWorldConfig) -> Vector2i:
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	return Vector2i(
		int(floor(float(chunk_grid.x) * 0.5)),
		int(floor(float(chunk_grid.y) * 0.5))
	)
