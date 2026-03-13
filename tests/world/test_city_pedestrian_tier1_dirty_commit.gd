extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianCrowdBatch := preload("res://city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var batch := CityPedestrianCrowdBatch.new()
	root.add_child(batch)
	await process_frame

	var chunk_center := Vector3.ZERO
	var states: Array = [
		{
			"pedestrian_id": "ped:0",
			"world_position": Vector3(1.0, 0.0, 2.0),
			"heading": Vector3.FORWARD,
			"radius_m": 0.28,
			"height_m": 1.75,
		},
		{
			"pedestrian_id": "ped:1",
			"world_position": Vector3(3.0, 0.0, 4.0),
			"heading": Vector3.RIGHT,
			"radius_m": 0.30,
			"height_m": 1.80,
		},
	]

	var first_write_count := batch.configure_from_states(states, chunk_center)
	var second_write_count := batch.configure_from_states(states, chunk_center)

	var changed_states: Array = []
	for state_variant in states:
		changed_states.append((state_variant as Dictionary).duplicate(true))
	(changed_states[1] as Dictionary)["world_position"] = Vector3(3.5, 0.0, 4.0)
	var third_write_count := batch.configure_from_states(changed_states, chunk_center)

	print("CITY_PEDESTRIAN_TIER1_DIRTY_COMMIT first=%d second=%d third=%d" % [first_write_count, second_write_count, third_write_count])

	if not T.require_true(self, first_write_count == states.size(), "First Tier 1 batch commit must write every slot"):
		return
	if not T.require_true(self, second_write_count == 0, "Unchanged Tier 1 batch commit must not rewrite transforms for stable slots"):
		return
	if not T.require_true(self, third_write_count == 1, "Single-slot Tier 1 movement must dirty exactly one transform write"):
		return

	T.pass_and_quit(self)
