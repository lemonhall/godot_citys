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

	var mount_guard := 0
	while renderer.get_chunk_scene_count() < 1 and mount_guard < 12:
		await process_frame
		renderer.sync_streaming(active_entries, Vector3.ZERO)
		mount_guard += 1

	if not T.require_true(self, renderer.get_chunk_scene_count() > 0, "Chunk renderer must mount at least one chunk before vehicle batch validation"):
		return

	var chunk_scene = null
	var visible_chunk_id := ""
	var visible_guard := 0
	while chunk_scene == null and visible_guard < 72:
		var visible_result := _find_visible_vehicle_chunk(renderer)
		chunk_scene = visible_result.get("chunk_scene")
		visible_chunk_id = str(visible_result.get("chunk_id", ""))
		if chunk_scene != null:
			break
		await process_frame
		renderer.sync_streaming(active_entries, Vector3.ZERO, 1.0 / 60.0)
		visible_guard += 1

	if not T.require_true(self, chunk_scene != null, "Mounted chunk set must contain at least one visible vehicle batch for Tier 1 validation"):
		return
	await process_frame
	renderer.sync_streaming(active_entries, Vector3.ZERO, 1.0 / 60.0)
	if not T.require_true(self, chunk_scene.has_method("get_vehicle_batch"), "Chunk scene must expose get_vehicle_batch() for Tier 1 vehicle validation"):
		return
	if not T.require_true(self, chunk_scene.has_method("get_vehicle_stats"), "Chunk scene must expose get_vehicle_stats() for vehicle stats validation"):
		return

	var vehicle_batch = chunk_scene.get_vehicle_batch()
	if not T.require_true(self, vehicle_batch is MultiMeshInstance3D, "Tier 1 vehicles must render through MultiMeshInstance3D"):
		return
	if not T.require_true(self, vehicle_batch.multimesh != null, "Tier 1 vehicle batch must own a MultiMesh payload"):
		return
	if not T.require_true(self, vehicle_batch.multimesh.instance_count > 0, "Tier 1 vehicle batch must contain visible instances"):
		return
	var batch_mesh: Mesh = vehicle_batch.multimesh.mesh
	if not T.require_true(self, batch_mesh != null, "Tier 1 vehicle batch must expose a base mesh"):
		return
	if not T.require_true(self, vehicle_batch.has_meta("vehicle_tier1_visual_source"), "Tier 1 vehicle batch must expose its visual source contract"):
		return
	if not T.require_true(self, String(vehicle_batch.get_meta("vehicle_tier1_visual_source", "")).begins_with("asset_proxy:"), "Tier 1 vehicle batch must reuse an asset-derived vehicle proxy instead of a hand-made primitive proxy"):
		return
	if not T.require_true(self, _mesh_aabb_size(batch_mesh).z > 0.2, "Tier 1 vehicle batch must use a volumetric mesh instead of a flat shadow quad"):
		return
	if not T.require_true(self, _collect_unique_axis_levels(batch_mesh, "y").size() >= 3, "Tier 1 vehicle batch mesh must include a raised roof silhouette instead of a single flat slab"):
		return

	var chunk_vehicle_stats: Dictionary = chunk_scene.get_vehicle_stats()
	print("CITY_VEHICLE_BATCH_CHUNK %s" % visible_chunk_id)
	if not T.require_true(self, int(chunk_vehicle_stats.get("tier1_count", 0)) == vehicle_batch.multimesh.instance_count, "Chunk vehicle stats must match Tier 1 MultiMesh instance count"):
		return
	if not T.require_true(self, int(chunk_vehicle_stats.get("tier1_count", 0)) + int(chunk_vehicle_stats.get("tier2_count", 0)) > 0, "Chunk vehicle stats must report visible vehicles"):
		return

	var renderer_stats: Dictionary = renderer.get_renderer_stats()
	print("CITY_VEHICLE_BATCH_RENDERING %s" % JSON.stringify(renderer_stats))
	if not T.require_true(self, int(renderer_stats.get("vehicle_tier1_total", 0)) > 0, "Renderer stats must report Tier 1 vehicle totals"):
		return
	var mounted_tier1_total := 0
	for chunk_id_variant in renderer.get_chunk_ids():
		var mounted_chunk = renderer.get_chunk_scene(str(chunk_id_variant))
		if mounted_chunk == null or not mounted_chunk.has_method("get_vehicle_stats"):
			continue
		var mounted_chunk_stats: Dictionary = mounted_chunk.get_vehicle_stats()
		mounted_tier1_total += int(mounted_chunk_stats.get("tier1_count", 0))
	if not T.require_true(self, int(renderer_stats.get("vehicle_multimesh_instance_total", 0)) >= mounted_tier1_total, "Renderer stats must report vehicle MultiMesh instances separately from props on mounted chunks"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)

func _find_visible_vehicle_chunk(renderer) -> Dictionary:
	for chunk_id_variant in renderer.get_chunk_ids():
		var chunk_id := str(chunk_id_variant)
		var candidate = renderer.get_chunk_scene(chunk_id)
		if candidate == null or not candidate.has_method("get_vehicle_stats"):
			continue
		var candidate_stats: Dictionary = candidate.get_vehicle_stats()
		if int(candidate_stats.get("tier1_count", 0)) > 0:
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
