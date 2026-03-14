extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var signature_a := _build_intersection_signature(config)
	var signature_b := _build_intersection_signature(config)

	if not T.require_true(self, str(signature_a.get("error", "")) == "", str(signature_a.get("error", "Unknown branch order error"))):
		return
	if not T.require_true(self, str(signature_b.get("error", "")) == "", str(signature_b.get("error", "Unknown branch order error"))):
		return
	if not T.require_true(self, str(signature_a.get("signature", "")) != "", "Intersection branch-order signature must not be empty"):
		return
	if not T.require_true(self, str(signature_a.get("signature", "")) == str(signature_b.get("signature", "")), "Fixed seed intersection branch ordering and connection semantics must be stable across world generation runs"):
		return

	T.pass_and_quit(self)

func _build_intersection_signature(config: CityWorldConfig) -> Dictionary:
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var road_graph = world_data.get("road_graph")
	var intersections: Array = road_graph.get_intersections_in_rect(Rect2(Vector2(-1600.0, -1600.0), Vector2(3200.0, 3200.0)))
	intersections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("intersection_id", "")) < str(b.get("intersection_id", ""))
	)

	var parts := PackedStringArray()
	for intersection_variant in intersections:
		var intersection: Dictionary = intersection_variant
		var ordered_branches: Array = intersection.get("ordered_branches", [])
		var connection_semantics: Array = intersection.get("branch_connection_semantics", [])
		if ordered_branches.is_empty():
			continue

		var previous_bearing := -1.0
		var branch_rows := PackedStringArray()
		for branch_variant in ordered_branches:
			var branch: Dictionary = branch_variant
			var branch_index := int(branch.get("branch_index", -1))
			var bearing_deg := float(branch.get("bearing_deg", -1.0))
			if branch_index != branch_rows.size():
				return {
					"error": "Ordered branches must be stored with contiguous branch_index values that match their array order",
					"signature": "",
				}
			if bearing_deg < 0.0 or bearing_deg >= 360.0:
				return {
					"error": "Ordered branch bearing_deg must stay within [0, 360): intersection=%s branch=%d bearing=%.4f" % [
						str(intersection.get("intersection_id", "")),
						branch_index,
						bearing_deg,
					],
					"signature": "",
				}
			if previous_bearing >= 0.0 and bearing_deg <= previous_bearing:
				return {
					"error": "Ordered branches must be sorted by strictly increasing bearing_deg",
					"signature": "",
				}
			previous_bearing = bearing_deg

			var turn_rows := PackedStringArray()
			for to_branch_index in range(ordered_branches.size()):
				var turn_type := _find_turn_type(connection_semantics, branch_index, to_branch_index)
				if turn_type == "":
					return {
						"error": "Connection semantics must expose every from/to branch pair in deterministic order",
						"signature": "",
					}
				turn_rows.append(turn_type)
			branch_rows.append("%d:%.2f:%s" % [
				branch_index,
				bearing_deg,
				",".join(turn_rows),
			])

		parts.append("%s|%s|%s" % [
			str(intersection.get("intersection_id", "")),
			str(intersection.get("intersection_type", "")),
			";".join(branch_rows),
		])

	return {
		"error": "",
		"signature": "|".join(parts),
	}

func _find_turn_type(connection_semantics: Array, from_branch_index: int, to_branch_index: int) -> String:
	for connection_variant in connection_semantics:
		var connection: Dictionary = connection_variant
		if int(connection.get("from_branch_index", -1)) != from_branch_index:
			continue
		if int(connection.get("to_branch_index", -1)) != to_branch_index:
			continue
		return str(connection.get("turn_type", ""))
	return ""
