extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityChunkRenderer := preload("res://city_game/world/rendering/CityChunkRenderer.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var renderer := CityChunkRenderer.new()
	root.add_child(renderer)
	await process_frame

	renderer.setup(config, world_data)
	streamer.update_for_world_position(Vector3.ZERO)
	var active_entries: Array = streamer.get_active_chunk_entries()
	renderer.sync_streaming(active_entries, Vector3.ZERO)

	var guard := 0
	while renderer.get_chunk_scene_count() < 1 and guard < 8:
		await process_frame
		renderer.sync_streaming(active_entries, Vector3.ZERO)
		guard += 1

	if not T.require_true(self, renderer.get_chunk_scene_count() > 0, "Chunk renderer must mount at least one chunk for setup profiling"):
		return

	var first_chunk_id := str(renderer.get_chunk_ids()[0])
	var chunk_scene = renderer.get_chunk_scene(first_chunk_id)
	if not T.require_true(self, chunk_scene != null, "Chunk renderer must expose a mounted chunk scene for setup profiling"):
		return
	if not T.require_true(self, chunk_scene.has_method("get_setup_profile"), "Chunk scene must expose get_setup_profile() for mount breakdown analysis"):
		return

	var setup_profile: Dictionary = chunk_scene.get_setup_profile()
	print("CITY_CHUNK_SETUP_PROFILE %s" % JSON.stringify(setup_profile))

	if not T.require_true(self, int(setup_profile.get("total_usec", 0)) > 0, "Chunk setup profile must expose total mount cost"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_usec", 0)) > 0, "Chunk setup profile must expose ground build cost"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_mesh_usec", 0)) > 0, "Chunk setup profile must expose flat-ground mesh build cost"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_mesh_usec", 0)) <= 3000, "Flat-ground chunk setup must keep ground mesh build cost at or below 3000 usec"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_collision_usec", 0)) > 0, "Chunk setup profile must expose ground collision build cost"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_collision_face_count", 0)) > 0, "Chunk setup profile must expose flat-ground collision face counts"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_collision_face_count", 0)) <= 4, "Flat-ground chunk setup must keep collision faces at plane scale instead of terrain-scale tessellation"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_vertex_sample_count", 0)) <= 8, "Flat-ground chunk setup must keep ground vertex sample count at plane scale"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_material_usec", 0)) > 0, "Chunk setup profile must expose ground material build cost"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_mask_textures_usec", 0)) > 0, "Chunk setup profile must expose road mask texture build cost"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_shader_material_usec", 0)) > 0, "Chunk setup profile must expose shader material assembly cost"):
		return
	if not T.require_true(self, int(setup_profile.get("buildings_usec", 0)) > 0, "Chunk setup profile must expose building build cost"):
		return
	if not T.require_true(self, setup_profile.has("road_overlay_usec"), "Chunk setup profile must expose road overlay cost even when it is zero"):
		return
	if not T.require_true(self, int(setup_profile.get("total_usec", 0)) <= 8500, "M4 chunk setup profile must keep total mount cost at or below 8500 usec"):
		return
	if not T.require_true(self, int(setup_profile.get("road_overlay_usec", 0)) <= 1400, "M4 chunk setup profile must keep road overlay cost at or below 1400 usec"):
		return
	if not T.require_true(self, int(setup_profile.get("ground_usec", 0)) <= 1800, "Flat-ground chunk setup must keep ground build cost at or below 1800 usec"):
		return
	if not T.require_true(self, int(setup_profile.get("props_usec", 0)) > 0, "Chunk setup profile must expose prop build cost"):
		return
	if not T.require_true(self, int(setup_profile.get("proxies_usec", 0)) > 0, "Chunk setup profile must expose proxy build cost"):
		return
	if not T.require_true(self, int(setup_profile.get("occluder_usec", 0)) > 0, "Chunk setup profile must expose occluder build cost"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
