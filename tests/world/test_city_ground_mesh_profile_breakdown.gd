extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

const TERRAIN_GRID_STEPS := 12

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var chunk_key := Vector2i(136, 136)
	var chunk_payload := _build_chunk_payload(config, world_data, chunk_key)
	var profile: Dictionary = CityChunkProfileBuilder.build_profile(chunk_payload)
	var chunk_size_m := float(chunk_payload.get("chunk_size_m", 256.0))
	var half_size := chunk_size_m * 0.5

	var current_vertices: Array[Vector2] = []
	for x_index in range(TERRAIN_GRID_STEPS):
		for z_index in range(TERRAIN_GRID_STEPS):
			var x0 := lerpf(-half_size, half_size, float(x_index) / float(TERRAIN_GRID_STEPS))
			var x1 := lerpf(-half_size, half_size, float(x_index + 1) / float(TERRAIN_GRID_STEPS))
			var z0 := lerpf(-half_size, half_size, float(z_index) / float(TERRAIN_GRID_STEPS))
			var z1 := lerpf(-half_size, half_size, float(z_index + 1) / float(TERRAIN_GRID_STEPS))
			current_vertices.append(Vector2(x0, z0))
			current_vertices.append(Vector2(x1, z0))
			current_vertices.append(Vector2(x0, z1))
			current_vertices.append(Vector2(x1, z1))

	var unique_vertices := _build_unique_vertices(half_size)

	var terrain_started_usec := Time.get_ticks_usec()
	for local_point in current_vertices:
		CityTerrainSampler.sample_height(chunk_payload.get("chunk_center", Vector3.ZERO).x + local_point.x, chunk_payload.get("chunk_center", Vector3.ZERO).z + local_point.y, int(chunk_payload.get("world_seed", 0)))
	var raw_terrain_current_usec := Time.get_ticks_usec() - terrain_started_usec

	var shaped_started_usec := Time.get_ticks_usec()
	for local_point in current_vertices:
		CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile)
	var shaped_current_usec := Time.get_ticks_usec() - shaped_started_usec

	var shaped_unique_started_usec := Time.get_ticks_usec()
	for local_point in unique_vertices:
		CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile)
	var shaped_unique_usec := Time.get_ticks_usec() - shaped_unique_started_usec

	var report := {
		"current_vertex_sample_count": current_vertices.size(),
		"unique_vertex_sample_count": unique_vertices.size(),
		"duplicate_sample_count": current_vertices.size() - unique_vertices.size(),
		"raw_terrain_current_usec": raw_terrain_current_usec,
		"shaped_current_usec": shaped_current_usec,
		"shaped_unique_usec": shaped_unique_usec,
		"duplication_ratio": float(current_vertices.size()) / float(maxi(unique_vertices.size(), 1)),
	}
	print("CITY_GROUND_MESH_PROFILE %s" % JSON.stringify(report))

	if not T.require_true(self, current_vertices.size() > unique_vertices.size(), "Current terrain mesh path must sample more vertices than the unique grid point count"):
		return
	if not T.require_true(self, shaped_current_usec > shaped_unique_usec, "Current terrain mesh path must cost more than the unique-vertex sampling baseline"):
		return

	T.pass_and_quit(self)

func _build_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i) -> Dictionary:
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_center := Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
	return {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": chunk_center,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(config.base_seed),
		"road_graph": world_data.get("road_graph"),
	}

func _build_unique_vertices(half_size: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for x_index in range(TERRAIN_GRID_STEPS + 1):
		for z_index in range(TERRAIN_GRID_STEPS + 1):
			points.append(Vector2(
				lerpf(-half_size, half_size, float(x_index) / float(TERRAIN_GRID_STEPS)),
				lerpf(-half_size, half_size, float(z_index) / float(TERRAIN_GRID_STEPS))
			))
	return points
