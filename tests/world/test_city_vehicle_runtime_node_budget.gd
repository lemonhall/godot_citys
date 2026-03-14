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

	for _frame_index in range(12):
		renderer.sync_streaming(active_entries, Vector3.ZERO, 1.0 / 60.0)
		await process_frame

	if not T.require_true(self, renderer.get_chunk_scene_count() > 0, "Vehicle runtime node budget test requires mounted chunks"):
		return
	if not T.require_true(self, renderer.has_method("get_renderer_stats"), "Chunk renderer must expose get_renderer_stats() for vehicle runtime guard checks"):
		return

	var renderer_stats: Dictionary = renderer.get_renderer_stats()
	if not T.require_true(self, renderer_stats.has("vehicle_runtime_guard_totals"), "Chunk renderer must expose aggregated vehicle_runtime_guard_totals"):
		return

	var totals: Dictionary = renderer_stats.get("vehicle_runtime_guard_totals", {})
	var saw_vehicle_chunk := false
	var root_child_total := 0
	var farfield_batch_total := 0
	var tier2_total := 0
	var tier3_total := 0
	var path_total := 0
	var forbidden_total := 0

	for chunk_id in renderer.get_chunk_ids():
		var chunk_scene = renderer.get_chunk_scene(chunk_id)
		if chunk_scene == null:
			continue
		if not T.require_true(self, chunk_scene.has_method("get_runtime_renderer_stats"), "Mounted chunk scene must expose get_runtime_renderer_stats() for vehicle runtime guard checks"):
			return
		var chunk_stats: Dictionary = chunk_scene.get_runtime_renderer_stats()
		if not T.require_true(self, chunk_stats.has("vehicle_runtime_guard_stats"), "Chunk scene must expose vehicle_runtime_guard_stats"):
			return
		var guard_stats: Dictionary = chunk_stats.get("vehicle_runtime_guard_stats", {})
		root_child_total += int(guard_stats.get("vehicle_root_child_count", 0))
		farfield_batch_total += int(guard_stats.get("farfield_multimesh_instance_count", 0))
		tier2_total += int(guard_stats.get("tier2_node_count", 0))
		tier3_total += int(guard_stats.get("tier3_node_count", 0))
		path_total += int(guard_stats.get("path3d_count", 0))
		forbidden_total += int(guard_stats.get("forbidden_runtime_node_count", 0))
		if int(chunk_stats.get("vehicle_tier1_count", 0)) + int(chunk_stats.get("vehicle_tier2_count", 0)) + int(chunk_stats.get("vehicle_tier3_count", 0)) > 0:
			saw_vehicle_chunk = true

		if not T.require_true(self, int(guard_stats.get("vehicle_root_child_count", 0)) <= 3, "Vehicle runtime root must keep a bounded child count instead of per-vehicle farfield nodes"):
			return
		if not T.require_true(self, int(guard_stats.get("farfield_multimesh_instance_count", 0)) <= 1, "Vehicle runtime must keep farfield traffic batched in at most one MultiMeshInstance3D per chunk"):
			return
		if not T.require_true(self, int(guard_stats.get("tier2_node_count", 0)) <= 2, "Vehicle Tier 2 runtime must stay within the lite nearfield node budget"):
			return
		if not T.require_true(self, int(guard_stats.get("tier3_node_count", 0)) <= 1, "Vehicle Tier 3 runtime must stay within the lite nearfield node budget"):
			return
		if not T.require_true(self, int(guard_stats.get("path3d_count", 0)) == 0, "Vehicle runtime guard must forbid Path3D lane trees"):
			return
		if not T.require_true(self, int(guard_stats.get("forbidden_runtime_node_count", 0)) == 0, "Vehicle runtime guard must forbid per-vehicle farfield node families"):
			return

	if not T.require_true(self, saw_vehicle_chunk, "Vehicle runtime node budget test requires at least one mounted chunk with active vehicles"):
		return
	if not T.require_true(self, int(totals.get("vehicle_root_child_count_total", -1)) == root_child_total, "Renderer aggregate vehicle root child count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("farfield_multimesh_instance_count_total", -1)) == farfield_batch_total, "Renderer aggregate farfield batch count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("tier2_node_count_total", -1)) == tier2_total, "Renderer aggregate Tier 2 node count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("tier3_node_count_total", -1)) == tier3_total, "Renderer aggregate Tier 3 node count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("path3d_count_total", -1)) == path_total, "Renderer aggregate Path3D count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("forbidden_runtime_node_count_total", -1)) == forbidden_total, "Renderer aggregate forbidden runtime node count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("path3d_count_total", 1)) == 0, "Vehicle runtime guard totals must report zero Path3D nodes"):
		return
	if not T.require_true(self, int(totals.get("forbidden_runtime_node_count_total", 1)) == 0, "Vehicle runtime guard totals must report zero forbidden runtime nodes"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
