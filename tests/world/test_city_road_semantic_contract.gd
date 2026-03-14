extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityRoadTemplateCatalog := preload("res://city_game/world/rendering/CityRoadTemplateCatalog.gd")

const TEMPLATE_IDS := [
	"expressway_elevated",
	"arterial",
	"local",
	"service",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for template_id in TEMPLATE_IDS:
		var template := CityRoadTemplateCatalog.get_template(template_id)
		if not T.require_true(self, template.has("section_semantics"), "Road template must expose section_semantics contract"):
			return
		var section_semantics: Dictionary = template.get("section_semantics", {})
		var lane_schema: Dictionary = section_semantics.get("lane_schema", {})
		var edge_profile: Dictionary = section_semantics.get("edge_profile", {})
		if not T.require_true(self, not lane_schema.is_empty(), "Road template section_semantics must include lane_schema"):
			return
		if not T.require_true(self, not edge_profile.is_empty(), "Road template section_semantics must include edge_profile"):
			return
		if not T.require_true(self, str(section_semantics.get("marking_profile_id", "")) != "", "Road template section_semantics must include marking_profile_id"):
			return
		var semantic_lane_total := int(lane_schema.get("forward_lane_count", 0)) + int(lane_schema.get("backward_lane_count", 0)) + int(lane_schema.get("shared_center_lane_count", 0))
		if not T.require_true(self, semantic_lane_total == int(template.get("lane_count_total", 0)), "Road template lane_schema must add up to lane_count_total"):
			return
		if not T.require_true(self, absf(float(edge_profile.get("surface_half_width_m", 0.0)) * 2.0 - float(template.get("width_m", 0.0))) <= 0.1, "Road template edge_profile half width must match template width"):
			return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var road_graph = world_data.get("road_graph")
	var world_edges: Array = road_graph.get_edges_intersecting_rect(config.get_world_bounds())
	if not T.require_true(self, world_edges.size() > 0, "World road graph must expose edges for semantic contract checks"):
		return

	var saw_edge_contract := false
	for edge_variant in world_edges:
		var edge: Dictionary = edge_variant
		if not edge.has("section_semantics"):
			continue
		saw_edge_contract = true
		var section_semantics: Dictionary = edge.get("section_semantics", {})
		var lane_schema: Dictionary = section_semantics.get("lane_schema", {})
		if not T.require_true(self, str(edge.get("template_id", "")) != "", "Shared road edge must carry template_id once semantic contract is enabled"):
			return
		if not T.require_true(self, not lane_schema.is_empty(), "Shared road edge section_semantics must include lane_schema"):
			return
		if not T.require_true(
			self,
			absf(float(edge.get("width_m", 0.0)) - float(section_semantics.get("width_m", 0.0))) <= 0.1,
			"Shared road edge width must stay aligned with section_semantics width: edge=%.2f semantic=%.2f template=%s" % [
				float(edge.get("width_m", 0.0)),
				float(section_semantics.get("width_m", 0.0)),
				str(edge.get("template_id", "")),
			]
		):
			return
		if not T.require_true(self, int(edge.get("lane_count_total", 0)) == int(edge.get("lane_count_forward", 0)) + int(edge.get("lane_count_backward", 0)) + int(edge.get("lane_count_shared", 0)), "Shared road edge directional lane counts must add up to lane_count_total"):
			return
		if not T.require_true(self, int(edge.get("lane_count_total", 0)) == int(lane_schema.get("forward_lane_count", 0)) + int(lane_schema.get("backward_lane_count", 0)) + int(lane_schema.get("shared_center_lane_count", 0)), "Shared road edge lane_schema must match edge directional lane counts"):
			return
	if not T.require_true(self, saw_edge_contract, "At least one shared road edge must carry section_semantics metadata"):
		return

	var saw_segment_contract := false
	for chunk_x in range(134, 139):
		for chunk_y in range(134, 139):
			var chunk_key := Vector2i(chunk_x, chunk_y)
			var layout: Dictionary = CityRoadLayoutBuilder.build_chunk_roads({
				"chunk_id": config.format_chunk_id(chunk_key),
				"chunk_key": chunk_key,
				"chunk_center": _chunk_center_from_key(config, chunk_key),
				"chunk_size_m": float(config.chunk_size_m),
				"chunk_seed": config.derive_seed("render_chunk", chunk_key),
				"road_graph": road_graph,
				"world_seed": config.base_seed,
			})
			for segment_variant in layout.get("segments", []):
				var segment: Dictionary = segment_variant
				if not segment.has("section_semantics"):
					continue
				saw_segment_contract = true
				var section_semantics: Dictionary = segment.get("section_semantics", {})
				var lane_schema: Dictionary = section_semantics.get("lane_schema", {})
				if not T.require_true(self, not lane_schema.is_empty(), "Chunk road segment must expose section_semantics lane_schema"):
					return
				if not T.require_true(self, int(segment.get("lane_count_total", 0)) == int(lane_schema.get("forward_lane_count", 0)) + int(lane_schema.get("backward_lane_count", 0)) + int(lane_schema.get("shared_center_lane_count", 0)), "Chunk road segment lane_schema must match lane_count_total"):
					return
				if not T.require_true(
					self,
					absf(float(segment.get("width", 0.0)) - float(section_semantics.get("width_m", 0.0))) <= 0.1,
					"Chunk road segment width must stay aligned with section_semantics width: segment=%s semantic=%.2f template=%s" % [
						str(segment.get("width", "missing")),
						float(section_semantics.get("width_m", 0.0)),
						str(segment.get("template_id", "")),
					]
				):
					return
				break
			if saw_segment_contract:
				break
		if saw_segment_contract:
			break
	if not T.require_true(self, saw_segment_contract, "At least one chunk road segment must expose section_semantics metadata"):
		return

	T.pass_and_quit(self)

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
