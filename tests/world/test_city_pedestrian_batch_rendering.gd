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

	if not T.require_true(self, renderer.get_chunk_scene_count() > 0, "Chunk renderer must mount at least one chunk before pedestrian batch validation"):
		return

	var first_chunk_id := str(renderer.get_chunk_ids()[0])
	var chunk_scene = renderer.get_chunk_scene(first_chunk_id)
	if not T.require_true(self, chunk_scene != null, "Chunk renderer must expose mounted chunk scenes"):
		return
	if not T.require_true(self, chunk_scene.has_method("get_pedestrian_batch"), "Chunk scene must expose get_pedestrian_batch() for Tier 1 crowd validation"):
		return
	if not T.require_true(self, chunk_scene.has_method("get_pedestrian_crowd_stats"), "Chunk scene must expose get_pedestrian_crowd_stats() for crowd stats validation"):
		return

	var pedestrian_batch = chunk_scene.get_pedestrian_batch()
	if not T.require_true(self, pedestrian_batch is MultiMeshInstance3D, "Tier 1 pedestrians must render through MultiMeshInstance3D"):
		return
	if not T.require_true(self, pedestrian_batch.multimesh != null, "Tier 1 pedestrian batch must own a MultiMesh payload"):
		return
	if not T.require_true(self, pedestrian_batch.multimesh.instance_count > 0, "Tier 1 pedestrian batch must contain visible instances"):
		return

	var chunk_crowd_stats: Dictionary = chunk_scene.get_pedestrian_crowd_stats()
	if not T.require_true(self, int(chunk_crowd_stats.get("tier1_count", 0)) == pedestrian_batch.multimesh.instance_count, "Chunk crowd stats must match Tier 1 MultiMesh instance count"):
		return
	if not T.require_true(self, int(chunk_crowd_stats.get("tier1_count", 0)) + int(chunk_crowd_stats.get("tier2_count", 0)) > 0, "Chunk crowd stats must report visible pedestrians"):
		return

	var renderer_stats: Dictionary = renderer.get_renderer_stats()
	print("CITY_PEDESTRIAN_BATCH_RENDERING %s" % JSON.stringify(renderer_stats))
	if not T.require_true(self, int(renderer_stats.get("pedestrian_tier1_total", 0)) > 0, "Renderer stats must report Tier 1 pedestrian totals"):
		return
	if not T.require_true(self, int(renderer_stats.get("pedestrian_multimesh_instance_total", 0)) >= int(renderer_stats.get("pedestrian_tier1_total", 0)), "Renderer stats must report pedestrian MultiMesh instances separately from prop instances"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
