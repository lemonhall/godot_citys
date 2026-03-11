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
					Vector3(96.0, 0.0, 0.0),
					Vector3(160.0, 0.0, 0.0),
				],
			}
		],
	}
	var surface_data: Dictionary = CityRoadMaskBuilder.prepare_surface_data(surface_request)
	var road_bytes: PackedByteArray = surface_data.get("road_bytes", PackedByteArray())

	var left_of_seam := _sample_mask(road_bytes, 512, Vector2(0.242, 0.125))
	var right_of_seam := _sample_mask(road_bytes, 512, Vector2(0.258, 0.125))
	if not T.require_true(self, left_of_seam > 0, "Road mask must stay painted on the left side of a page tile seam when a road crosses that seam"):
		return
	if not T.require_true(self, right_of_seam > 0, "Road mask must stay painted on the right side of a page tile seam when a road crosses that seam"):
		return

	T.pass_and_quit(self)

func _sample_mask(mask_bytes: PackedByteArray, resolution: int, normalized: Vector2) -> int:
	var pixel_x := clampi(int(round(normalized.x * float(resolution - 1))), 0, resolution - 1)
	var pixel_y := clampi(int(round(normalized.y * float(resolution - 1))), 0, resolution - 1)
	return int(mask_bytes[pixel_y * resolution + pixel_x])
