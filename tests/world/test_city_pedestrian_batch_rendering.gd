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
	var batch_mesh: Mesh = pedestrian_batch.multimesh.mesh
	if not T.require_true(self, batch_mesh != null, "Tier 1 pedestrian batch must expose a base mesh"):
		return
	if not T.require_true(self, pedestrian_batch.has_meta("pedestrian_tier1_visual_source"), "Tier 1 pedestrian batch must expose its visual source contract"):
		return
	if not T.require_true(self, String(pedestrian_batch.get_meta("pedestrian_tier1_visual_source", "")).begins_with("primitive_proxy:"), "Tier 1 pedestrian batch must use a static primitive proxy so far pedestrians do not expose skinned bind-pose T-poses"):
		return
	if not T.require_true(self, pedestrian_batch.has_meta("pedestrian_tier1_proxy_scale_profile"), "Tier 1 pedestrian batch must expose a proxy scale profile contract"):
		return
	var proxy_scale_profile: Dictionary = pedestrian_batch.get_meta("pedestrian_tier1_proxy_scale_profile", {})
	if not T.require_true(self, is_equal_approx(float(proxy_scale_profile.get("height_scale", 0.0)), 1.0), "Tier 1 pedestrian proxy height scale must stay at 1.0 so the fixed proxy is not stretched at runtime"):
		return
	if not T.require_true(self, is_equal_approx(float(proxy_scale_profile.get("width_scale", 0.0)), 1.0), "Tier 1 pedestrian proxy width scale must stay at 1.0 so the fixed proxy is not stretched at runtime"):
		return
	if not T.require_true(self, is_equal_approx(float(proxy_scale_profile.get("depth_scale", 0.0)), 1.0), "Tier 1 pedestrian proxy depth scale must stay at 1.0 so the fixed proxy is not stretched at runtime"):
		return
	var proxy_mesh_size := _mesh_aabb_size(batch_mesh)
	if not T.require_true(self, proxy_mesh_size.y > 1.6, "Tier 1 pedestrian batch must keep a human-height volumetric mesh instead of a short placeholder box"):
		return
	if not T.require_true(self, proxy_mesh_size.x < proxy_mesh_size.y * 0.6, "Tier 1 pedestrian batch must keep a relaxed arms-down silhouette instead of a wide T-pose proxy"):
		return
	if not T.require_true(self, _collect_unique_axis_levels(batch_mesh, "y").size() >= 5, "Tier 1 pedestrian proxy mesh must expose a readable head-torso-leg silhouette instead of a single rod"):
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

func _mesh_aabb_size(mesh: Mesh) -> Vector3:
	if mesh == null:
		return Vector3.ZERO
	return mesh.get_aabb().size

func _collect_unique_axis_levels(mesh: Mesh, axis: String) -> Array:
	var unique_levels: Array = []
	if mesh == null:
		return unique_levels
	for surface_index in range(mesh.get_surface_count()):
		var surface_arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var coordinate := 0.0
			match axis:
				"x":
					coordinate = vertex.x
				"z":
					coordinate = vertex.z
				_:
					coordinate = vertex.y
			var found := false
			for existing_level_variant in unique_levels:
				if is_equal_approx(float(existing_level_variant), coordinate):
					found = true
					break
			if not found:
				unique_levels.append(coordinate)
	return unique_levels
