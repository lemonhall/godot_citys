extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityVehicleTrafficRenderer := preload("res://city_game/world/vehicles/rendering/CityVehicleTrafficRenderer.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var renderer := CityVehicleTrafficRenderer.new()
	root.add_child(renderer)

	renderer.setup({
		"chunk_center": Vector3.ZERO,
		"vehicle_chunk_snapshot": {
			"chunk_id": "chunk_0_0",
			"tier0_count": 0,
			"tier1_count": 1,
			"tier2_count": 0,
			"tier3_count": 0,
			"tier1_states": [{
				"vehicle_id": "veh:test",
				"world_position": Vector3(4.0, 0.0, 8.0),
				"heading": Vector3.FORWARD,
				"model_id": "car_b",
				"traffic_role": "civilian",
				"seed": 7,
			}],
			"tier2_states": [],
			"tier3_states": [],
		},
	})

	var stats: Dictionary = renderer.get_vehicle_stats()
	if not T.require_true(self, int(stats.get("tier1_count", 0)) == 1, "Vehicle traffic renderer setup must preserve initial tier1 counts from chunk snapshots"):
		return
	if not T.require_true(self, int(stats.get("tier1_instance_count", 0)) == 1, "Vehicle traffic renderer setup must materialize initial tier1 snapshots without a second apply call"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
