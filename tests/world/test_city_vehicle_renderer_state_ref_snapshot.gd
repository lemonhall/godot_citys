extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityVehicleTrafficRenderer := preload("res://city_game/world/vehicles/rendering/CityVehicleTrafficRenderer.gd")
const CityVehicleState := preload("res://city_game/world/vehicles/simulation/CityVehicleState.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var renderer := CityVehicleTrafficRenderer.new()
	root.add_child(renderer)

	var tier1_state := CityVehicleState.new()
	tier1_state.setup(_build_vehicle_state_data("veh:tier1", Vector3(4.0, 0.0, 8.0), Vector3.FORWARD, "civilian"))
	tier1_state.set_tier(CityVehicleState.TIER_1)

	var tier2_state := CityVehicleState.new()
	tier2_state.setup(_build_vehicle_state_data("veh:tier2", Vector3(6.0, 0.0, 10.0), Vector3.LEFT, "service"))
	tier2_state.set_tier(CityVehicleState.TIER_2)

	renderer.setup({
		"chunk_center": Vector3.ZERO,
		"vehicle_chunk_snapshot": {
			"chunk_id": "chunk_0_0",
			"tier0_count": 0,
			"tier1_count": 1,
			"tier2_count": 1,
			"tier3_count": 0,
			"tier1_states": [tier1_state],
			"tier2_states": [tier2_state],
			"tier3_states": [],
		},
	})

	var stats: Dictionary = renderer.get_vehicle_stats()
	if not T.require_true(self, int(stats.get("tier1_count", 0)) == 1, "Vehicle traffic renderer must preserve Tier 1 counts when chunk snapshots carry state refs"):
		return
	if not T.require_true(self, int(stats.get("tier1_instance_count", 0)) == 1, "Vehicle traffic renderer must materialize Tier 1 state refs into MultiMesh instances"):
		return
	if not T.require_true(self, int(stats.get("tier2_count", 0)) == 1, "Vehicle traffic renderer must preserve Tier 2 counts when chunk snapshots carry state refs"):
		return
	if not T.require_true(self, int(stats.get("tier2_node_count", 0)) == 1, "Vehicle traffic renderer must materialize Tier 2 state refs into nearfield nodes"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)

func _build_vehicle_state_data(vehicle_id: String, world_position: Vector3, heading: Vector3, traffic_role: String) -> Dictionary:
	return {
		"vehicle_id": vehicle_id,
		"chunk_id": "chunk_0_0",
		"page_id": "page_0",
		"spawn_slot_id": "slot_%s" % vehicle_id,
		"road_id": "road:test",
		"lane_ref_id": "lane:test",
		"route_signature": "route:test",
		"model_id": "car_b",
		"model_signature": "car_b:sedan",
		"traffic_role": traffic_role,
		"vehicle_class": "sedan",
		"seed": 7,
		"length_m": 4.4,
		"width_m": 1.9,
		"height_m": 1.5,
		"speed_mps": 0.1,
		"world_position": world_position,
		"heading": heading,
		"lane_points": [world_position, world_position + heading.normalized() * 4.0],
		"lane_length_m": 4.0,
		"distance_along_lane_m": 0.0,
	}
