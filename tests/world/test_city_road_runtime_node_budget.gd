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
		renderer.sync_streaming(active_entries, Vector3.ZERO)
		await process_frame

	if not T.require_true(self, renderer.get_chunk_scene_count() > 0, "Road runtime node budget test requires mounted chunks"):
		return
	if not T.require_true(self, renderer.has_method("get_renderer_stats"), "Chunk renderer must expose get_renderer_stats() for road runtime guard checks"):
		return

	var renderer_stats: Dictionary = renderer.get_renderer_stats()
	if not T.require_true(self, renderer_stats.has("road_runtime_guard_totals"), "Chunk renderer must expose aggregated road_runtime_guard_totals"):
		return

	var totals: Dictionary = renderer_stats.get("road_runtime_guard_totals", {})
	var saw_road_chunk := false
	var overlay_child_total := 0
	var render_mesh_total := 0
	var render_multimesh_total := 0
	var path_total := 0
	var forbidden_total := 0

	for chunk_id in renderer.get_chunk_ids():
		var chunk_scene = renderer.get_chunk_scene(chunk_id)
		if chunk_scene == null:
			continue
		if not T.require_true(self, chunk_scene.has_method("get_renderer_stats"), "Mounted chunk scene must expose get_renderer_stats() for road runtime guard checks"):
			return
		var chunk_stats: Dictionary = chunk_scene.get_renderer_stats()
		if not T.require_true(self, chunk_stats.has("road_runtime_guard_stats"), "Chunk scene must expose road_runtime_guard_stats"):
			return
		var guard_stats: Dictionary = chunk_stats.get("road_runtime_guard_stats", {})
		overlay_child_total += int(guard_stats.get("road_overlay_child_count", 0))
		render_mesh_total += int(guard_stats.get("render_mesh_instance_count", 0))
		render_multimesh_total += int(guard_stats.get("render_multimesh_instance_count", 0))
		path_total += int(guard_stats.get("path3d_count", 0))
		forbidden_total += int(guard_stats.get("forbidden_runtime_node_count", 0))
		if int(chunk_stats.get("road_segment_count", 0)) > 0:
			saw_road_chunk = true

		if not T.require_true(self, int(guard_stats.get("road_overlay_child_count", 0)) <= 4, "Road overlay must keep a bounded child count instead of per-segment render nodes"):
			return
		if not T.require_true(self, int(guard_stats.get("render_mesh_instance_count", 0)) <= 2, "Road overlay render path must stay capped at shared surface/stripe meshes"):
			return
		if not T.require_true(self, int(guard_stats.get("render_multimesh_instance_count", 0)) <= 1, "Road overlay render path must keep bridge supports batched in at most one MultiMeshInstance3D"):
			return
		if not T.require_true(self, int(guard_stats.get("path3d_count", 0)) == 0, "Road runtime guard must forbid Path3D lane trees"):
			return
		if not T.require_true(self, int(guard_stats.get("forbidden_runtime_node_count", 0)) == 0, "Road runtime guard must forbid per-road/per-lane runtime node families"):
			return

	if not T.require_true(self, saw_road_chunk, "Road runtime node budget test requires at least one mounted chunk with road segments"):
		return
	if not T.require_true(self, int(totals.get("road_overlay_child_count_total", -1)) == overlay_child_total, "Renderer aggregate road overlay child count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("render_mesh_instance_count_total", -1)) == render_mesh_total, "Renderer aggregate render mesh count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("render_multimesh_instance_count_total", -1)) == render_multimesh_total, "Renderer aggregate render multimesh count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("path3d_count_total", -1)) == path_total, "Renderer aggregate Path3D count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("forbidden_runtime_node_count_total", -1)) == forbidden_total, "Renderer aggregate forbidden runtime node count must match chunk totals"):
		return
	if not T.require_true(self, int(totals.get("path3d_count_total", 1)) == 0, "Road runtime guard totals must report zero Path3D nodes"):
		return
	if not T.require_true(self, int(totals.get("forbidden_runtime_node_count_total", 1)) == 0, "Road runtime guard totals must report zero forbidden runtime nodes"):
		return

	renderer.queue_free()
	T.pass_and_quit(self)
