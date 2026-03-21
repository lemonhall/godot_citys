extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityRoadLayoutBuilder := preload("res://city_game/world/rendering/CityRoadLayoutBuilder.gd")
const CityRoadTemplateCatalog := preload("res://city_game/world/rendering/CityRoadTemplateCatalog.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
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

			for segment in layout.get("segments", []):
				var segment_dict: Dictionary = segment
				if not T.require_true(self, not bool(segment_dict.get("bridge", false)), "Flat-ground pivot must disable bridge flags in sampled road segments"):
					return
				var template := CityRoadTemplateCatalog.get_template(str(segment_dict.get("template_id", "local")))
				var allowed_grade := float(template.get("max_grade", 0.1)) + 0.005
				var measured_grade := _measure_max_grade(segment_dict.get("points", []))
				if not T.require_true(self, measured_grade <= allowed_grade, "Flat expressway and arterial geometry must still respect template max_grade"):
					return

	T.pass_and_quit(self)

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)

func _measure_max_grade(points: Array) -> float:
	var max_grade := 0.0
	for point_index in range(points.size() - 1):
		var a: Vector3 = points[point_index]
		var b: Vector3 = points[point_index + 1]
		var horizontal_distance := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		if horizontal_distance <= 0.001:
			continue
		max_grade = maxf(max_grade, absf(b.y - a.y) / horizontal_distance)
	return max_grade
