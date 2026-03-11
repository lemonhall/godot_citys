extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

const TERRAIN_PAGE_PROVIDER_PATH := "res://city_game/world/rendering/CityTerrainPageProvider.gd"
const GRID_STEPS := 12

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var provider_script := load(TERRAIN_PAGE_PROVIDER_PATH)
	if not T.require_true(self, provider_script != null, "Terrain page provider script must exist for seam continuity verification"):
		return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var provider = provider_script.new()
	provider.setup(config, world_data)

	var chunk_a := _build_chunk_payload(config, world_data, Vector2i(136, 136))
	var chunk_b := _build_chunk_payload(config, world_data, Vector2i(137, 136))
	var binding_a: Dictionary = provider.resolve_chunk_sample_binding(chunk_a, GRID_STEPS)
	var binding_b: Dictionary = provider.resolve_chunk_sample_binding(chunk_b, GRID_STEPS)
	var heights_a: PackedFloat32Array = binding_a.get("heights", PackedFloat32Array())
	var heights_b: PackedFloat32Array = binding_b.get("heights", PackedFloat32Array())
	var normals_a: PackedVector3Array = binding_a.get("normals", PackedVector3Array())
	var normals_b: PackedVector3Array = binding_b.get("normals", PackedVector3Array())

	if not T.require_true(self, heights_a.size() == (GRID_STEPS + 1) * (GRID_STEPS + 1), "Terrain page binding must provide per-chunk height samples for seam checks"):
		return
	if not T.require_true(self, normals_a.size() == heights_a.size(), "Terrain page binding must provide per-chunk normals alongside height samples"):
		return
	if not T.require_true(self, _edge_height_delta(heights_a, heights_b, GRID_STEPS) <= 0.001, "Adjacent terrain page bindings must keep east/west edge heights continuous"):
		return
	if not T.require_true(self, _edge_normal_delta(normals_a, normals_b, GRID_STEPS) <= 0.001, "Adjacent terrain page bindings must keep east/west edge normals continuous"):
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

func _edge_height_delta(left_chunk: PackedFloat32Array, right_chunk: PackedFloat32Array, grid_steps: int) -> float:
	var row_stride := grid_steps + 1
	var max_delta := 0.0
	for z_index in range(row_stride):
		var left_index := grid_steps * row_stride + z_index
		var right_index := z_index
		max_delta = maxf(max_delta, absf(left_chunk[left_index] - right_chunk[right_index]))
	return max_delta

func _edge_normal_delta(left_chunk: PackedVector3Array, right_chunk: PackedVector3Array, grid_steps: int) -> float:
	var row_stride := grid_steps + 1
	var max_delta := 0.0
	for z_index in range(row_stride):
		var left_index := grid_steps * row_stride + z_index
		var right_index := z_index
		max_delta = maxf(max_delta, left_chunk[left_index].distance_to(right_chunk[right_index]))
	return max_delta
