extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")
const CityRoadMeshBuilder := preload("res://city_game/world/rendering/CityRoadMeshBuilder.gd")
const CityRoadTemplateCatalog := preload("res://city_game/world/rendering/CityRoadTemplateCatalog.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var layout_semantics := _build_semantics_from_template("arterial", {
		"marking_profile_id": "arterial_divided",
		"lane_schema": {
			"direction_mode": "divided_two_way",
			"forward_lane_count": 2,
			"backward_lane_count": 2,
			"shared_center_lane_count": 0,
			"lane_width_m": 4.75,
		},
		"edge_profile": {
			"surface_half_width_m": 11.0,
			"median_width_m": 1.0,
			"left_shoulder_width_m": 1.0,
			"right_shoulder_width_m": 1.0,
			"roadside_buffer_m": 1.75,
			"curb_profile_id": "rolled_curb",
		},
	})
	var layout_segment := CityRoadLayoutBuilder._make_segment_from_world_polyline({
		"class": "local",
		"template_id": "local",
		"points": [
			Vector2(-16.0, 0.0),
			Vector2(16.0, 0.0),
		],
		"width_m": 6.0,
		"lane_count_total": 1,
		"lane_count_forward": 1,
		"lane_count_backward": 0,
		"lane_count_shared": 0,
		"median_width_m": 0.0,
		"shoulder_width_m": 0.2,
		"section_semantics": layout_semantics,
	}, Vector3.ZERO, 1337, 4242)
	if not T.require_true(self, not layout_segment.is_empty(), "Layout semantic takeover requires _make_segment_from_world_polyline() to return a segment"):
		return
	if not T.require_true(self, absf(float(layout_segment.get("width", 0.0)) - 22.0) <= 0.1, "Chunk road layout must resolve width from section_semantics edge_profile instead of stale width_m"):
		return
	if not T.require_true(self, int(layout_segment.get("lane_count_total", 0)) == 4, "Chunk road layout must resolve lane_count_total from section_semantics lane_schema"):
		return
	if not T.require_true(self, int(layout_segment.get("lane_count_forward", 0)) == 2 and int(layout_segment.get("lane_count_backward", 0)) == 2 and int(layout_segment.get("lane_count_shared", 0)) == 0, "Chunk road layout must resolve directional lane counts from section_semantics lane_schema"):
		return
	if not T.require_true(self, absf(float(layout_segment.get("median_width_m", 0.0)) - 1.0) <= 0.1, "Chunk road layout must resolve median width from section_semantics edge_profile"):
		return

	var mask_segment := {
		"template_id": "local",
		"lane_count_total": 2,
		"width": 4.0,
		"points": [
			Vector3(-12.0, 0.0, 0.0),
			Vector3(12.0, 0.0, 0.0),
		],
		"section_semantics": _build_semantics_from_template("local", {
			"marking_profile_id": "service_single_edge",
			"edge_profile": {
				"surface_half_width_m": 6.0,
				"median_width_m": 0.0,
				"left_shoulder_width_m": 0.7,
				"right_shoulder_width_m": 0.7,
				"roadside_buffer_m": 1.45,
				"curb_profile_id": "soft_edge",
			},
		}),
	}
	var surface_data := CityRoadMaskBuilder.prepare_surface_data({
		"surface_scope": "test",
		"surface_segments": [mask_segment],
		"surface_world_size_m": 64.0,
		"surface_origin_m": Vector2(-32.0, -32.0),
		"mask_resolution": 64,
		"detail_mode": CityRoadMaskBuilder.DETAIL_MODE_FULL,
	})
	var road_pixel_count := _count_nonzero_pixels(surface_data.get("road_bytes", PackedByteArray()))
	var stripe_pixel_count := _count_nonzero_pixels(surface_data.get("stripe_bytes", PackedByteArray()))
	var mask_stats: Dictionary = surface_data.get("mask_profile_stats", {})
	if not T.require_true(self, road_pixel_count >= 160, "Road mask build must paint road coverage from section_semantics surface width instead of stale width"):
		return
	if not T.require_true(self, stripe_pixel_count == 0, "Road mask build must suppress stripe paint when section_semantics marking_profile_id says no center stripe"):
		return
	if not T.require_true(self, int(mask_stats.get("semantic_surface_width_segment_count", 0)) == 1, "Road mask profile stats must report semantic surface width takeover"):
		return
	if not T.require_true(self, int(mask_stats.get("semantic_marking_segment_count", 0)) == 1, "Road mask profile stats must report semantic marking takeover"):
		return
	var mask_marking_counts: Dictionary = mask_stats.get("semantic_marking_profile_counts", {})
	if not T.require_true(self, int(mask_marking_counts.get("service_single_edge", 0)) == 1, "Road mask profile stats must expose semantic marking profile counts"):
		return

	var bridge_segment := {
		"template_id": "local",
		"bridge": true,
		"width": 4.0,
		"deck_thickness_m": 0.5,
		"points": [
			Vector3(-12.0, 9.0, 0.0),
			Vector3(12.0, 9.0, 0.0),
		],
		"section_semantics": _build_semantics_from_template("local", {
			"marking_profile_id": "service_single_edge",
			"edge_profile": {
				"surface_half_width_m": 9.0,
				"median_width_m": 2.0,
				"left_shoulder_width_m": 0.7,
				"right_shoulder_width_m": 0.7,
				"roadside_buffer_m": 1.45,
				"curb_profile_id": "bridge_barrier",
			},
		}),
	}
	var overlay := CityRoadMeshBuilder.build_road_overlay({
		"road_segments": [bridge_segment],
	}, {
		"chunk_center": Vector3.ZERO,
		"world_seed": 1337,
	})
	if not T.require_true(self, overlay != null, "Road mesh builder must return a RoadOverlay node for semantic takeover checks"):
		return
	if not T.require_true(self, overlay.get_node_or_null("RoadStripe") == null, "Bridge stripe mesh must follow section_semantics marking_profile_id instead of template_id shortcuts"):
		return
	var semantic_stats: Dictionary = overlay.get_meta("road_semantic_stats", {})
	if not T.require_true(self, int(semantic_stats.get("semantic_surface_width_segment_count", 0)) == 1, "Road overlay meta must report semantic surface width takeover"):
		return
	if not T.require_true(self, int(semantic_stats.get("semantic_marking_segment_count", 0)) == 1, "Road overlay meta must report semantic marking takeover"):
		return
	var overlay_marking_counts: Dictionary = semantic_stats.get("semantic_marking_profile_counts", {})
	if not T.require_true(self, int(overlay_marking_counts.get("service_single_edge", 0)) == 1, "Road overlay meta must expose semantic marking profile counts"):
		return
	var collision_root := overlay.get_node_or_null("RoadCollisions") as Node3D
	if not T.require_true(self, collision_root != null and collision_root.get_child_count() >= 1, "Bridge semantic takeover test requires RoadCollisions bodies"):
		return
	var bridge_body := collision_root.get_child(0) as StaticBody3D
	if not T.require_true(self, bridge_body != null and bridge_body.get_child_count() >= 1, "Bridge semantic takeover test requires a collision shape body"):
		return
	var bridge_collision_shape := bridge_body.get_child(0) as CollisionShape3D
	var bridge_box := bridge_collision_shape.shape as BoxShape3D
	if not T.require_true(self, bridge_box != null and bridge_box.size.x >= 17.5, "Bridge collision width must follow section_semantics surface width instead of stale width"):
		return
	overlay.free()

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var chunk_key := Vector2i(136, 136)
	var chunk_center := _chunk_center_from_key(config, chunk_key)
	var profile: Dictionary = CityChunkProfileBuilder.build_profile({
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": chunk_center,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(config.base_seed),
		"road_graph": world_data.get("road_graph"),
	})
	if not T.require_true(self, profile.has("road_semantic_consumer_stats"), "Chunk profile must expose road_semantic_consumer_stats once semantic takeover is enabled"):
		return
	var consumer_stats: Dictionary = profile.get("road_semantic_consumer_stats", {})
	if not T.require_true(self, int(consumer_stats.get("layout_segment_contract_count", 0)) > 0, "Chunk profile semantic stats must count layout segments carrying section_semantics"):
		return
	if not T.require_true(self, int(consumer_stats.get("surface_semantic_ready_segment_count", 0)) > 0, "Chunk profile semantic stats must count surface-ready semantic segments"):
		return
	var profile_marking_counts: Dictionary = consumer_stats.get("semantic_marking_profile_counts", {})
	if not T.require_true(self, not profile_marking_counts.is_empty(), "Chunk profile semantic stats must expose marking profile counts"):
		return

	T.pass_and_quit(self)

func _build_semantics_from_template(template_id: String, overrides: Dictionary = {}) -> Dictionary:
	var template := CityRoadTemplateCatalog.get_template(template_id)
	var semantics: Dictionary = (template.get("section_semantics", {}) as Dictionary).duplicate(true)
	for key in overrides.keys():
		var value = overrides[key]
		if value is Dictionary:
			var merged: Dictionary = (semantics.get(key, {}) as Dictionary).duplicate(true)
			for nested_key in (value as Dictionary).keys():
				merged[nested_key] = (value as Dictionary)[nested_key]
			semantics[key] = merged
		else:
			semantics[key] = value
	return semantics

func _count_nonzero_pixels(bytes: PackedByteArray) -> int:
	var count := 0
	for byte_value in bytes:
		if int(byte_value) > 0:
			count += 1
	return count

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
