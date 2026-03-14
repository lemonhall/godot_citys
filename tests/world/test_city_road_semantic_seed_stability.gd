extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var signature_a := _build_semantic_signature(config)
	var signature_b := _build_semantic_signature(config)

	if not T.require_true(self, signature_a != "", "Semantic signature must not be empty"):
		return
	if not T.require_true(self, signature_a == signature_b, "Fixed seed road semantic contract must be stable across world generation runs"):
		return

	T.pass_and_quit(self)

func _build_semantic_signature(config: CityWorldConfig) -> String:
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var road_graph = world_data.get("road_graph")
	var center_rect := Rect2(Vector2(-1600.0, -1600.0), Vector2(3200.0, 3200.0))
	var edges: Array = road_graph.get_edges_intersecting_rect(center_rect)
	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("edge_id", "")) < str(b.get("edge_id", ""))
	)
	var parts := PackedStringArray()
	for edge_variant in edges:
		var edge: Dictionary = edge_variant
		var section_semantics: Dictionary = edge.get("section_semantics", {})
		var lane_schema: Dictionary = section_semantics.get("lane_schema", {})
		if section_semantics.is_empty() or lane_schema.is_empty():
			continue
		parts.append("%s|%s|%d|%d|%d|%s|%.2f" % [
			str(edge.get("edge_id", "")),
			str(edge.get("template_id", "")),
			int(lane_schema.get("forward_lane_count", -1)),
			int(lane_schema.get("backward_lane_count", -1)),
			int(lane_schema.get("shared_center_lane_count", -1)),
			str(section_semantics.get("marking_profile_id", "")),
			float(section_semantics.get("width_m", -1.0)),
		])
	return "|".join(parts)
