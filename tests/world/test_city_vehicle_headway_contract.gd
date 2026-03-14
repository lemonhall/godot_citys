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

	var target_query := _find_multi_vehicle_lane_query(config, vehicle_query)
	if not T.require_true(self, not target_query.is_empty(), "At least one center-adjacent chunk must produce multiple vehicles on the same lane for headway checks"):
		return

	var grouped_slots := _group_slots_by_lane(target_query.get("spawn_slots", []))
	var saw_headway_check := false
	for lane_id_variant in grouped_slots.keys():
		var lane_id := str(lane_id_variant)
		var lane_slots: Array = grouped_slots[lane_id]
		if lane_slots.size() < 2:
			continue
		lane_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("distance_along_lane_m", 0.0)) < float(b.get("distance_along_lane_m", 0.0))
		)
		var min_headway := float(vehicle_query.get_min_headway_for_road_class(str((lane_slots[0] as Dictionary).get("road_class", ""))))
		for slot_index in range(lane_slots.size() - 1):
			saw_headway_check = true
			var current_slot: Dictionary = lane_slots[slot_index]
			var next_slot: Dictionary = lane_slots[slot_index + 1]
			var lane_delta := float(next_slot.get("distance_along_lane_m", 0.0)) - float(current_slot.get("distance_along_lane_m", 0.0))
			if not T.require_true(self, lane_delta + 0.01 >= min_headway - 0.5, "Vehicle spawn slots on the same lane must preserve minimum headway spacing"):
				return
	if not T.require_true(self, saw_headway_check, "Headway test must validate at least one same-lane vehicle spacing pair"):
		return

	T.pass_and_quit(self)

func _find_multi_vehicle_lane_query(config: CityWorldConfig, vehicle_query) -> Dictionary:
	var center_chunk := _center_chunk(config)
	for offset_x in range(-2, 3):
		for offset_y in range(-2, 3):
			var chunk_key := center_chunk + Vector2i(offset_x, offset_y)
			if chunk_key.x < 0 or chunk_key.y < 0:
				continue
			var chunk_query: Dictionary = vehicle_query.get_vehicle_query_for_chunk(chunk_key)
			var grouped_slots := _group_slots_by_lane(chunk_query.get("spawn_slots", []))
			for lane_id_variant in grouped_slots.keys():
				if (grouped_slots[lane_id_variant] as Array).size() >= 2:
					return chunk_query
	return {}

func _group_slots_by_lane(spawn_slots: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for slot_variant in spawn_slots:
		var slot: Dictionary = slot_variant
		var lane_id := str(slot.get("lane_ref_id", ""))
		if not grouped.has(lane_id):
			grouped[lane_id] = []
		(grouped[lane_id] as Array).append(slot)
	return grouped

func _center_chunk(config: CityWorldConfig) -> Vector2i:
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	return Vector2i(
		int(floor(float(chunk_grid.x) * 0.5)),
		int(floor(float(chunk_grid.y) * 0.5))
	)
