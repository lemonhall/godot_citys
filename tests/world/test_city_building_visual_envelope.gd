extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var found_building := false
	var found_expanded_envelope := false

	for chunk_x in range(132, 141):
		for chunk_y in range(132, 141):
			var chunk_key := Vector2i(chunk_x, chunk_y)
			var profile := CityChunkProfileBuilder.build_profile({
				"chunk_id": config.format_chunk_id(chunk_key),
				"chunk_key": chunk_key,
				"chunk_center": _chunk_center_from_key(config, chunk_key),
				"chunk_size_m": float(config.chunk_size_m),
				"chunk_seed": config.derive_seed("render_chunk", chunk_key),
				"road_graph": world_data.get("road_graph"),
				"world_seed": config.base_seed,
			})
			for building in profile.get("buildings", []):
				var building_dict: Dictionary = building
				found_building = true
				if not T.require_true(self, building_dict.has("visual_footprint_radius_m"), "Buildings must expose visual_footprint_radius_m so oversized podiums stay out of elevated roads"):
					return
				if not T.require_true(self, building_dict.has("visual_road_clearance_m"), "Buildings must expose visual_road_clearance_m using their real visible envelope"):
					return
				var footprint_radius := float(building_dict.get("footprint_radius_m", 0.0))
				var visual_radius := float(building_dict.get("visual_footprint_radius_m", 0.0))
				if not T.require_true(self, visual_radius >= footprint_radius, "Visual footprint radius must never be smaller than the gameplay footprint"):
					return
				if not T.require_true(self, float(building_dict.get("visual_road_clearance_m", 0.0)) >= 6.0, "Building visual envelope must stay out of road and bridge corridors"):
					return
				found_expanded_envelope = found_expanded_envelope or visual_radius > footprint_radius + 1.0

	if not T.require_true(self, found_building, "Sample window must include generated buildings for envelope validation"):
		return
	if not T.require_true(self, found_expanded_envelope, "Sample window must include at least one building whose visible envelope is larger than its core tower footprint"):
		return

	T.pass_and_quit(self)

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
