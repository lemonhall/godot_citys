extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var terrain_script := load("res://city_game/world/rendering/CityTerrainSampler.gd")
	if terrain_script == null:
		T.fail_and_quit(self, "Missing CityTerrainSampler.gd")
		return

	var config := CityWorldConfig.new()
	var height_a := float(terrain_script.sample_height(0.0, 0.0, config.base_seed))
	var height_b := float(terrain_script.sample_height(4096.0, 3072.0, config.base_seed))
	var height_a_repeat := float(terrain_script.sample_height(0.0, 0.0, config.base_seed))
	var height_c := float(terrain_script.sample_height(768.0, 512.0, config.base_seed))
	if not T.require_true(self, absf(height_a - height_a_repeat) <= 0.001, "Terrain sampler must be deterministic"):
		return
	if not T.require_true(self, absf(height_a) <= 0.001 and absf(height_b) <= 0.001 and absf(height_c) <= 0.001, "Flat-ground runtime requires terrain sampler to collapse to the shared y=0 plane"):
		return

	var chunk_scene_script := load("res://city_game/world/rendering/CityChunkScene.gd")
	if chunk_scene_script == null:
		T.fail_and_quit(self, "Missing CityChunkScene.gd")
		return

	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var chunk_scene = chunk_scene_script.new()
	root.add_child(chunk_scene)
	await process_frame

	var chunk_key := Vector2i(136, 136)
	chunk_scene.setup({
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": Vector3.ZERO,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
	})

	if not T.require_true(self, chunk_scene.has_method("get_terrain_relief_m"), "Chunk scene must expose get_terrain_relief_m()"):
		return
	if not T.require_true(self, float(chunk_scene.get_terrain_relief_m()) <= 0.001, "Flat-ground runtime requires chunk terrain relief to stay at the shared plane"):
		return
	if not T.require_true(self, chunk_scene.has_method("get_terrain_lod_contract"), "Chunk scene must expose get_terrain_lod_contract()"):
		return
	var terrain_lod_contract: Dictionary = chunk_scene.get_terrain_lod_contract()
	var modes: Dictionary = terrain_lod_contract.get("modes", {})
	for mode_name in ["near", "mid", "far"]:
		if not T.require_true(self, int((modes.get(mode_name, {}) as Dictionary).get("grid_steps", -1)) == 1, "Flat-ground runtime keeps all terrain LOD modes collapsed to one shared plane grid"):
			return
	if not T.require_true(self, int(terrain_lod_contract.get("current_grid_steps", -1)) == 1, "Current terrain LOD grid must also collapse to the flat-ground plane contract"):
		return

	chunk_scene.queue_free()
	T.pass_and_quit(self)
