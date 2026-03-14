extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

const VALID_TURN_TYPES := {
	"left_turn": true,
	"right_turn": true,
	"straight": true,
	"u_turn": true,
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var road_graph = world_data.get("road_graph")
	var intersections: Array = road_graph.get_intersections_in_rect(Rect2(Vector2(-1200.0, -1200.0), Vector2(2400.0, 2400.0)))
	var outskirts_anchor: Vector2 = road_graph.get_node_by_id(config.format_district_id(Vector2i(2, 2))).get("center", Vector2.ZERO)
	var outskirts_intersections: Array = road_graph.get_intersections_in_rect(Rect2(outskirts_anchor - Vector2.ONE * 384.0, Vector2.ONE * 768.0))

	if not T.require_true(self, intersections.size() > 0, "Road graph must expose center intersections for topology contract checks"):
		return
	if not T.require_true(self, outskirts_intersections.size() > 0, "Shared road graph must also expose outskirts intersections once topology contract is formalized"):
		return

	var saw_topology_contract := false
	for intersection_variant in intersections:
		var intersection: Dictionary = intersection_variant
		if not intersection.has("ordered_branches"):
			continue
		saw_topology_contract = true

		var ordered_branches: Array = intersection.get("ordered_branches", [])
		var connection_semantics: Array = intersection.get("branch_connection_semantics", [])
		var degree := int(intersection.get("degree", 0))
		var intersection_type := str(intersection.get("intersection_type", ""))

		if not T.require_true(self, str(intersection.get("intersection_id", "")) != "", "Intersection topology contract must expose intersection_id"):
			return
		if not T.require_true(self, ordered_branches.size() >= 3, "Topology contract must expose at least three ordered branches for real intersections"):
			return
		if not T.require_true(self, degree == ordered_branches.size(), "Intersection degree must match ordered_branches size once topology contract is enabled"):
			return
		if not T.require_true(self, intersection_type != "", "Intersection topology contract must expose intersection_type"):
			return
		if degree == 3:
			if not T.require_true(self, intersection_type == "tee" or intersection_type == "fork", "Three-way intersection must classify as tee or fork"):
				return
		elif degree == 4:
			if not T.require_true(self, intersection_type == "cross" or intersection_type == "four_way", "Four-way intersection must classify as cross or four_way"):
				return
		else:
			if not T.require_true(self, intersection_type == "multi_way", "Five-or-more branch intersection must classify as multi_way"):
				return

		var branch_index_set: Dictionary = {}
		for branch_variant in ordered_branches:
			var branch: Dictionary = branch_variant
			var branch_index := int(branch.get("branch_index", -1))
			branch_index_set[branch_index] = true
			if not T.require_true(self, branch_index >= 0, "Ordered branch must expose non-negative branch_index"):
				return
			if not T.require_true(self, str(branch.get("edge_id", "")) != "", "Ordered branch must reference edge_id"):
				return
			if not T.require_true(self, str(branch.get("road_class", "")) != "", "Ordered branch must expose road_class"):
				return
			if not T.require_true(self, str(branch.get("template_id", "")) != "", "Ordered branch must expose template_id"):
				return
			if not T.require_true(self, float(branch.get("bearing_deg", -1.0)) >= 0.0, "Ordered branch must expose bearing_deg in degrees"):
				return

		if not T.require_true(self, branch_index_set.size() == ordered_branches.size(), "Ordered branch indices must be unique"):
			return
		if not T.require_true(self, connection_semantics.size() == ordered_branches.size() * ordered_branches.size(), "Intersection connection semantics must cover every from/to branch pair, including u-turns"):
			return

		for connection_variant in connection_semantics:
			var connection: Dictionary = connection_variant
			var from_branch_index := int(connection.get("from_branch_index", -1))
			var to_branch_index := int(connection.get("to_branch_index", -1))
			if not T.require_true(self, branch_index_set.has(from_branch_index), "Connection semantics from_branch_index must reference an ordered branch"):
				return
			if not T.require_true(self, branch_index_set.has(to_branch_index), "Connection semantics to_branch_index must reference an ordered branch"):
				return
			if not T.require_true(self, VALID_TURN_TYPES.has(str(connection.get("turn_type", ""))), "Connection semantics must classify each branch pair with a known turn_type"):
				return

	if not T.require_true(self, saw_topology_contract, "At least one shared road graph intersection must expose the topology contract"):
		return
	if not T.require_true(self, _has_topology_contract(outskirts_intersections), "Outskirts intersections must expose the same topology contract as center intersections"):
		return

	T.pass_and_quit(self)

func _has_topology_contract(intersections: Array) -> bool:
	for intersection_variant in intersections:
		var intersection: Dictionary = intersection_variant
		if intersection.has("ordered_branches") and not (intersection.get("ordered_branches", []) as Array).is_empty():
			return true
	return false
