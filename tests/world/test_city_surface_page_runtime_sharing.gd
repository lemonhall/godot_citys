extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkRenderer := preload("res://city_game/world/rendering/CityChunkRenderer.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var renderer := CityChunkRenderer.new()
	root.add_child(renderer)
	await process_frame

	renderer.setup(config, world_data)
	var chunk_a := Vector2i(136, 136)
	var chunk_b := Vector2i(137, 136)
	var entries: Array = [
		{
			"chunk_id": config.format_chunk_id(chunk_a),
			"chunk_key": chunk_a,
			"state": "mount",
		},
		{
			"chunk_id": config.format_chunk_id(chunk_b),
			"chunk_key": chunk_b,
			"state": "mount",
		},
	]
	renderer.sync_streaming(entries, Vector3(128.0, 0.0, 0.0))

	var guard := 0
	while renderer.get_chunk_scene_count() < 2 and guard < 64:
		await process_frame
		renderer.sync_streaming(entries, Vector3(128.0, 0.0, 0.0))
		guard += 1

	if not T.require_true(self, renderer.get_chunk_scene_count() == 2, "Renderer must mount two adjacent chunks to validate shared surface pages"):
		return

	var scene_a = renderer.get_chunk_scene(config.format_chunk_id(chunk_a))
	var scene_b = renderer.get_chunk_scene(config.format_chunk_id(chunk_b))
	if not T.require_true(self, scene_a != null and scene_b != null, "Adjacent same-page chunks must stay addressable after mount"):
		return
	if not T.require_true(self, scene_a.has_method("get_surface_page_contract"), "Chunk scene must expose surface page contract for runtime verification"):
		return
	if not T.require_true(self, scene_b.has_method("get_surface_page_contract"), "Chunk scene must expose surface page contract for runtime verification"):
		return

	var contract_a: Dictionary = scene_a.get_surface_page_contract()
	var contract_b: Dictionary = scene_b.get_surface_page_contract()
	if not T.require_true(self, contract_a.get("page_key", Vector2i.ZERO) == contract_b.get("page_key", Vector2i.ZERO), "Adjacent chunks inside one surface page must share the same runtime page_key"):
		return
	if not T.require_true(self, contract_a.get("uv_rect", Rect2()) != contract_b.get("uv_rect", Rect2()), "Chunks inside one surface page must use different UV sub-rects"):
		return

	var material_a := scene_a.get_node("GroundBody/MeshInstance3D").material_override as ShaderMaterial
	var material_b := scene_b.get_node("GroundBody/MeshInstance3D").material_override as ShaderMaterial
	if not T.require_true(self, material_a != null and material_b != null, "Ground meshes must keep ShaderMaterial bindings when surface pages are enabled"):
		return

	var road_texture_a = material_a.get_shader_parameter("road_mask_texture")
	var road_texture_b = material_b.get_shader_parameter("road_mask_texture")
	if not T.require_true(self, road_texture_a == road_texture_b, "Same-page chunks must share one road mask texture instance instead of duplicating per chunk"):
		return
	if not T.require_true(self, material_a.get_shader_parameter("surface_uv_offset") != material_b.get_shader_parameter("surface_uv_offset"), "Shared surface page chunks must sample different UV offsets"):
		return
	if not T.require_true(self, material_a.get_shader_parameter("surface_uv_scale") == material_b.get_shader_parameter("surface_uv_scale"), "Shared surface page chunks must keep consistent UV scale inside one page"):
		return

	var profile_stats: Dictionary = renderer.get_streaming_profile_stats()
	if not T.require_true(self, int(profile_stats.get("surface_commit_sample_count", 0)) == 1, "One shared surface page should commit textures once for adjacent same-page chunks"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
