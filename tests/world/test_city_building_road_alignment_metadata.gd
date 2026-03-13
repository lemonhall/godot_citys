extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")

const EXACT_ALIGNMENT_EPSILON_RAD := 0.001
const OFFSET_ALIGNMENT_EPSILON_RAD := 0.17

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var found_building := false
	var found_direct_alignment := false
	var found_offset_alignment := false

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
				if not T.require_true(self, building_dict.has("road_angle_rad"), "Buildings must expose road_angle_rad so road alignment can be reused without rescanning roads"):
					return
				var road_angle_rad := float(building_dict.get("road_angle_rad", 0.0))
				var yaw_rad := float(building_dict.get("yaw_rad", 0.0))
				var archetype_id := str(building_dict.get("archetype_id", ""))
				match archetype_id:
					"slab", "podium_tower", "step_midrise":
						found_direct_alignment = true
						if not T.require_true(self, _angles_close(yaw_rad, road_angle_rad, EXACT_ALIGNMENT_EPSILON_RAD), "Direct-aligned buildings must keep yaw_rad equal to road_angle_rad"):
							return
					"midrise_bar", "industrial":
						found_direct_alignment = true
						if not T.require_true(self, _angles_close(yaw_rad, road_angle_rad + PI * 0.5, EXACT_ALIGNMENT_EPSILON_RAD), "Perpendicular buildings must keep yaw_rad locked to road_angle_rad plus ninety degrees"):
							return
					"needle", "courtyard":
						found_offset_alignment = true
						var delta_rad := absf(_wrapped_angle_delta(yaw_rad, road_angle_rad))
						if not T.require_true(self, delta_rad <= OFFSET_ALIGNMENT_EPSILON_RAD, "Offset buildings must stay within the expected local road-angle jitter window"):
							return

	if not T.require_true(self, found_building, "Sample window must include generated buildings for road alignment metadata validation"):
		return
	if not T.require_true(self, found_direct_alignment, "Sample window must include directly aligned building archetypes"):
		return
	if not T.require_true(self, found_offset_alignment, "Sample window must include offset building archetypes"):
		return

	T.pass_and_quit(self)

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)

func _angles_close(lhs: float, rhs: float, epsilon_rad: float) -> bool:
	return absf(_wrapped_angle_delta(lhs, rhs)) <= epsilon_rad

func _wrapped_angle_delta(lhs: float, rhs: float) -> float:
	return wrapf(lhs - rhs + PI, 0.0, TAU) - PI
