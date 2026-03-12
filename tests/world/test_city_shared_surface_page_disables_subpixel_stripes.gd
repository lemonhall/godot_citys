extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityRoadSurfacePageProvider := preload("res://city_game/world/rendering/CityRoadSurfacePageProvider.gd")
const CityTerrainPageProvider := preload("res://city_game/world/rendering/CityTerrainPageProvider.gd")
const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var surface_provider := CityRoadSurfacePageProvider.new()
	surface_provider.setup(config, world_data)
	var terrain_provider := CityTerrainPageProvider.new()
	terrain_provider.setup(config, world_data)

	var chunk_key := Vector2i(136, 136)
	var scene := CityChunkScene.new()
	root.add_child(scene)
	await process_frame
	scene.setup({
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": _chunk_center_from_key(config, chunk_key),
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
		"surface_page_provider": surface_provider,
		"terrain_page_provider": terrain_provider,
		"initial_lod_mode": "near",
	})

	var ground_mesh := scene.get_node_or_null("GroundBody/MeshInstance3D") as MeshInstance3D
	if not T.require_true(self, ground_mesh != null, "Shared surface page stripe review requires GroundBody/MeshInstance3D"):
		return
	var material := ground_mesh.material_override as ShaderMaterial
	if not T.require_true(self, material != null, "Shared surface page stripe review requires a ShaderMaterial override"):
		return

	var contract: Dictionary = scene.get_surface_page_contract()
	if not T.require_true(self, int(contract.get("chunks_per_page", 0)) >= 2, "Shared surface page stripe review requires a multi-chunk page contract"):
		return
	if not T.require_true(
		self,
		not bool(material.get_shader_parameter("stripe_enabled")),
		"When shared road surface pages reduce stripe texel radius below a readable threshold, terrain overlay stripes must disable to avoid orange bleed across grass and road shoulders"
	):
		return

	scene.queue_free()
	T.pass_and_quit(self)

func _chunk_center_from_key(config: CityWorldConfig, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
