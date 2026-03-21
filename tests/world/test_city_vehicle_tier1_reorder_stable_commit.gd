extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityVehicleTrafficBatch := preload("res://city_game/world/vehicles/rendering/CityVehicleTrafficBatch.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var batch := CityVehicleTrafficBatch.new()
	root.add_child(batch)
	await process_frame

	var chunk_center := Vector3.ZERO
	var base_states: Array = [
		{
			"vehicle_id": "veh:0",
			"world_position": Vector3(5.0, 0.0, 6.0),
			"heading": Vector3.FORWARD,
			"traffic_role": "civilian",
			"model_id": "car_a",
			"seed": 11,
		},
		{
			"vehicle_id": "veh:1",
			"world_position": Vector3(8.0, 0.0, 9.0),
			"heading": Vector3.RIGHT,
			"traffic_role": "service",
			"model_id": "van_a",
			"seed": 13,
		},
	]
	var reordered_states: Array = [
		(base_states[1] as Dictionary).duplicate(true),
		(base_states[0] as Dictionary).duplicate(true),
	]
	var moved_reordered_states: Array = [
		(base_states[1] as Dictionary).duplicate(true),
		(base_states[0] as Dictionary).duplicate(true),
	]
	(moved_reordered_states[0] as Dictionary)["world_position"] = Vector3(8.5, 0.0, 9.0)

	var first_write_count := batch.configure_from_states(base_states, chunk_center)
	var second_write_count := batch.configure_from_states(reordered_states, chunk_center)
	var third_write_count := batch.configure_from_states(moved_reordered_states, chunk_center)

	print(
		"CITY_VEHICLE_TIER1_REORDER_STABLE_COMMIT first=%d second=%d third=%d"
		% [first_write_count, second_write_count, third_write_count]
	)

	if not T.require_true(self, first_write_count == base_states.size(), "First Tier 1 vehicle batch commit must write every slot"):
		return
	if not T.require_true(self, second_write_count == 0, "Pure Tier 1 vehicle reordering must not rewrite stable transforms"):
		return
	if not T.require_true(self, third_write_count == 1, "Tier 1 vehicle reorder plus one movement must dirty exactly one transform write"):
		return

	T.pass_and_quit(self)
