extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var streamer_script := load("res://city_game/world/streaming/CityChunkStreamer.gd")
	var renderer_script := load("res://city_game/world/rendering/CityChunkRenderer.gd")
	if config_script == null:
		T.fail_and_quit(self, "Missing CityWorldConfig.gd")
		return
	if generator_script == null:
		T.fail_and_quit(self, "Missing CityWorldGenerator.gd")
		return
	if streamer_script == null:
		T.fail_and_quit(self, "Missing CityChunkStreamer.gd")
		return
	if renderer_script == null:
		T.fail_and_quit(self, "Missing CityChunkRenderer.gd")
		return

	var config = config_script.new()
	var world_data: Dictionary = generator_script.new().generate_world(config)
	var streamer = streamer_script.new(config, world_data)
	streamer.update_for_world_position(Vector3.ZERO)

	var renderer = renderer_script.new()
	root.add_child(renderer)
	await process_frame

	renderer.setup(config, world_data)
	renderer.sync_streaming(streamer.get_active_chunk_entries(), Vector3.ZERO)

	var guard := 0
	while renderer.get_chunk_scene_count() < 1 and guard < 8:
		await process_frame
		renderer.sync_streaming(streamer.get_active_chunk_entries(), Vector3.ZERO)
		guard += 1

	if not T.require_true(self, renderer.get_chunk_scene_count() > 0, "Chunk renderer must create visible chunk scenes"):
		return
	var first_chunk_id: String = str(renderer.get_chunk_ids()[0])
	var chunk_scene = renderer.get_chunk_scene(first_chunk_id)
	if not T.require_true(self, chunk_scene != null, "Chunk renderer must expose chunk scenes by id"):
		return
	if not T.require_true(self, chunk_scene.has_method("get_prop_multimesh"), "Chunk scene must expose get_prop_multimesh()"):
		return
	var prop_multimesh = chunk_scene.get_prop_multimesh()
	if not T.require_true(self, prop_multimesh is MultiMeshInstance3D, "Repeated props must use MultiMeshInstance3D"):
		return
	if not T.require_true(self, prop_multimesh.multimesh.instance_count > 0, "MultiMesh must contain instances"):
		return

	var stats: Dictionary = renderer.get_renderer_stats()
	if not T.require_true(self, int(stats.get("multimesh_instance_total", 0)) > 0, "Renderer stats must report multimesh instances"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
