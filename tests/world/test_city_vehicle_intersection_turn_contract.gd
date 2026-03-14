extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

const REQUIRED_TURN_TYPES := {
	"straight": true,
	"left_turn": true,
	"right_turn": true,
	"u_turn": true,
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world: Dictionary = CityWorldGenerator.new().generate_world(config)
	var road_graph = world.get("road_graph")
	var vehicle_query = world.get("vehicle_query")
	if not T.require_true(self, road_graph != null, "World data must include road_graph"):
		return
	if not T.require_true(self, vehicle_query != null, "World data must include vehicle_query"):
		return

	var lane_graph = vehicle_query.get_lane_graph()
	if not T.require_true(self, lane_graph.has_method("get_intersection_turn_contract"), "vehicle lane_graph must expose get_intersection_turn_contract()"):
		return

	var intersections: Array = road_graph.get_intersections_in_rect(Rect2(Vector2(-1200.0, -1200.0), Vector2(2400.0, 2400.0)))
	if not T.require_true(self, not intersections.is_empty(), "Road graph must expose center intersections for vehicle turn contract checks"):
		return

	var found_supported_contract := false
	for road_intersection_variant in intersections:
		var road_intersection: Dictionary = road_intersection_variant
		var vehicle_contract: Dictionary = lane_graph.get_intersection_turn_contract(str(road_intersection.get("intersection_id", "")))
		if vehicle_contract.is_empty():
			continue

		var lane_connections: Array = vehicle_contract.get("lane_connections", [])
		if lane_connections.is_empty():
			continue

		var saw_turn_types := REQUIRED_TURN_TYPES.duplicate(true)
		for turn_type in saw_turn_types.keys():
			saw_turn_types[turn_type] = false
		var saw_lane_backed_non_uturn := false
		for lane_connection_variant in lane_connections:
			var lane_connection: Dictionary = lane_connection_variant
			var turn_type := str(lane_connection.get("turn_type", ""))
			if saw_turn_types.has(turn_type):
				saw_turn_types[turn_type] = true
			if turn_type != "u_turn" and not (lane_connection.get("from_lane_ids", []) as Array).is_empty() and not (lane_connection.get("to_lane_ids", []) as Array).is_empty():
				saw_lane_backed_non_uturn = true
		if not _all_turn_types_present(saw_turn_types):
			continue
		if not saw_lane_backed_non_uturn:
			continue

		if not T.require_true(self, str(vehicle_contract.get("intersection_type", "")) == str(road_intersection.get("intersection_type", "")), "Vehicle turn contract must preserve shared road intersection_type"):
			return
		if not T.require_true(self, (vehicle_contract.get("ordered_branches", []) as Array).size() == (road_intersection.get("ordered_branches", []) as Array).size(), "Vehicle turn contract must preserve ordered branch count from shared road graph"):
			return
		if not T.require_true(self, (vehicle_contract.get("branch_connection_semantics", []) as Array).size() == (road_intersection.get("branch_connection_semantics", []) as Array).size(), "Vehicle turn contract must preserve branch_connection_semantics cardinality"):
			return

		found_supported_contract = true
		break

	if not T.require_true(self, found_supported_contract, "At least one center intersection must expose lane-backed straight/left/right/u-turn vehicle contract"):
		return

	T.pass_and_quit(self)

func _all_turn_types_present(turn_state: Dictionary) -> bool:
	for key in turn_state.keys():
		if not bool(turn_state.get(key, false)):
			return false
	return true
