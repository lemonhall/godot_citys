extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var surface_request := {
		"surface_scope": "page",
		"surface_world_size_m": 1024.0,
		"surface_origin_m": Vector2(-128.0, -128.0),
		"mask_resolution": 512,
		"detail_mode": "coarse",
		"surface_segments": [
			{
				"template_id": "arterial",
				"lane_count_total": 4,
				"width": 22.0,
				"points": [
					Vector3(-96.0, 0.0, 0.0),
					Vector3(96.0, 0.0, 0.0),
				],
			}
		],
	}
	var surface_data: Dictionary = CityRoadMaskBuilder.prepare_surface_data(surface_request)
	var road_bytes: PackedByteArray = surface_data.get("road_bytes", PackedByteArray())
	if not T.require_true(self, road_bytes.size() == 512 * 512, "Road surface prepare path must preserve requested page mask resolution"):
		return

	var expected_tile_sample := _sample_mask(road_bytes, 512, Vector2(0.125, 0.125))
	var wrong_center_sample := _sample_mask(road_bytes, 512, Vector2(0.5, 0.5))
	if not T.require_true(self, expected_tile_sample > 0, "Page road mask must honor surface_origin_m so first tile roads stay in the first tile instead of drifting toward page center"):
		return
	if not T.require_true(self, wrong_center_sample == 0, "Page road mask alignment fix must stop first tile roads from being painted into the page center"):
		return

	T.pass_and_quit(self)

func _sample_mask(mask_bytes: PackedByteArray, resolution: int, normalized: Vector2) -> int:
	var pixel_x := clampi(int(round(normalized.x * float(resolution - 1))), 0, resolution - 1)
	var pixel_y := clampi(int(round(normalized.y * float(resolution - 1))), 0, resolution - 1)
	return int(mask_bytes[pixel_y * resolution + pixel_x])
