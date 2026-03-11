extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")

const TEMPLATE_SPECS := {
	"expressway_elevated": {"lane_count_total": 8, "width_m": 34.0},
	"arterial": {"lane_count_total": 4, "width_m": 22.0},
	"local": {"lane_count_total": 2, "width_m": 11.0},
	"service": {"lane_count_total": 1, "width_m": 5.5},
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var saw_local := false
	var saw_higher_capacity := false
	for chunk_x in range(134, 139):
		for chunk_y in range(134, 139):
			var chunk_key := Vector2i(chunk_x, chunk_y)
			var layout: Dictionary = CityRoadLayoutBuilder.build_chunk_roads({
				"chunk_id": config.format_chunk_id(chunk_key),
				"chunk_key": chunk_key,
				"chunk_center": _chunk_center_from_key(config, chunk_key),
				"chunk_size_m": float(config.chunk_size_m),
				"chunk_seed": config.derive_seed("render_chunk", chunk_key),
				"road_graph": world_data.get("road_graph"),
				"world_seed": config.base_seed,
			})

			if not T.require_true(self, str(layout.get("road_mesh_mode", "")) == "terrain_overlay_bridges", "Road layout must advertise terrain-overlay surface roads with 3D bridges"):
				return

			for segment in layout.get("segments", []):
				var segment_dict: Dictionary = segment
				var template_id := str(segment_dict.get("template_id", ""))
				if not T.require_true(self, TEMPLATE_SPECS.has(template_id), "Road segment template_id must be one of the supported lane templates"):
					return
				var spec: Dictionary = TEMPLATE_SPECS[template_id]
				if not T.require_true(self, int(segment_dict.get("lane_count_total", 0)) == int(spec.get("lane_count_total", 0)), "Road lane_count_total must match the declared template"):
					return
				if not T.require_true(self, absf(float(segment_dict.get("width", 0.0)) - float(spec.get("width_m", 0.0))) <= 0.1, "Road width must match the declared template width"):
					return
				saw_local = saw_local or template_id == "local"
				saw_higher_capacity = saw_higher_capacity or template_id == "arterial" or template_id == "expressway_elevated"

	if not T.require_true(self, saw_local, "Center-city sample window must include local 2-lane streets"):
		return
	if not T.require_true(self, saw_higher_capacity, "Center-city sample window must include at least one higher-capacity road template"):
		return

	T.pass_and_quit(self)

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
