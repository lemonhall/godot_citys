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

	var chunk_scene = null
	var visible_chunk_id := ""
	var visible_guard := 0
	while chunk_scene == null and visible_guard < 48:
		var visible_result := _find_visible_pedestrian_chunk(renderer)
		chunk_scene = visible_result.get("chunk_scene")
		visible_chunk_id = str(visible_result.get("chunk_id", ""))
		if chunk_scene != null:
			break
		await process_frame
		renderer.sync_streaming(active_entries, Vector3.ZERO)
		visible_guard += 1

	if not T.require_true(self, chunk_scene != null, "Mounted chunk set must contain at least one visible pedestrian batch for Tier 1 validation"):
		return
	await process_frame
	renderer.sync_streaming(active_entries, Vector3.ZERO)
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
	print("CITY_PEDESTRIAN_BATCH_CHUNK %s" % visible_chunk_id)
	if not T.require_true(self, int(chunk_crowd_stats.get("tier1_count", 0)) == pedestrian_batch.multimesh.instance_count, "Chunk crowd stats must match Tier 1 MultiMesh instance count"):
		return
	if not T.require_true(self, int(chunk_crowd_stats.get("tier1_count", 0)) + int(chunk_crowd_stats.get("tier2_count", 0)) > 0, "Chunk crowd stats must report visible pedestrians"):
		return

	var renderer_stats: Dictionary = renderer.get_renderer_stats()
	print("CITY_PEDESTRIAN_BATCH_RENDERING %s" % JSON.stringify(renderer_stats))
	if not T.require_true(self, int(renderer_stats.get("pedestrian_tier1_total", 0)) > 0, "Renderer stats must report Tier 1 pedestrian totals"):
		return
	var mounted_tier1_total := 0
	for chunk_id_variant in renderer.get_chunk_ids():
		var mounted_chunk = renderer.get_chunk_scene(str(chunk_id_variant))
		if mounted_chunk == null or not mounted_chunk.has_method("get_pedestrian_crowd_stats"):
			continue
		var mounted_chunk_stats: Dictionary = mounted_chunk.get_pedestrian_crowd_stats()
		mounted_tier1_total += int(mounted_chunk_stats.get("tier1_count", 0))
	if not T.require_true(self, int(renderer_stats.get("pedestrian_multimesh_instance_total", 0)) >= mounted_tier1_total, "Renderer stats must report pedestrian MultiMesh instances separately from prop instances on mounted chunks"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)

func _find_visible_pedestrian_chunk(renderer) -> Dictionary:
	for chunk_id_variant in renderer.get_chunk_ids():
		var chunk_id := str(chunk_id_variant)
		var candidate = renderer.get_chunk_scene(chunk_id)
		if candidate == null or not candidate.has_method("get_pedestrian_crowd_stats"):
			continue
		var candidate_stats: Dictionary = candidate.get_pedestrian_crowd_stats()
		if int(candidate_stats.get("tier1_count", 0)) + int(candidate_stats.get("tier2_count", 0)) > 0:
			return {
				"chunk_id": chunk_id,
				"chunk_scene": candidate,
			}
	return {
		"chunk_id": "",
		"chunk_scene": null,
	}
