extends SceneTree

const T := preload("res://tests/_test_util.gd")
const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 180
const TARGET_WORLD_POSITION := Vector3(768.0, 0.0, 26.0)
const STEP_DISTANCE_M := 16.0
const PROFILE_STEP_COUNT := 48

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var gameplay_stats := await _capture_renderer_stats("player")
	if gameplay_stats.is_empty():
		return
	var inspection_stats := await _capture_renderer_stats("inspection")
	if inspection_stats.is_empty():
		return

	print("CITY_PEDESTRIAN_GAMEPLAY_RENDER_BUDGET %s" % JSON.stringify({
		"gameplay": gameplay_stats,
		"inspection": inspection_stats,
	}))

	if not T.require_true(self, int(gameplay_stats.get("pedestrian_tier1_total", 0)) > 0, "Gameplay render budget test requires non-zero Tier 1 pedestrian totals"):
		return
	var gameplay_tier1_total := int(gameplay_stats.get("pedestrian_tier1_total", 0))
	var gameplay_visible_tier1 := int(gameplay_stats.get("pedestrian_multimesh_instance_total", 0))
	var inspection_tier1_total := int(inspection_stats.get("pedestrian_tier1_total", 0))
	var inspection_visible_tier1 := int(inspection_stats.get("pedestrian_multimesh_instance_total", 0))
	if not T.require_true(self, gameplay_visible_tier1 <= int(floor(float(gameplay_tier1_total) * 0.85)), "Gameplay render budget must keep visible Tier 1 pedestrian proxies at or below 85% of the controller Tier 1 total"):
		return
	if not T.require_true(self, inspection_visible_tier1 >= int(floor(float(inspection_tier1_total) * 0.95)), "Inspection mode must keep at least 95% of the Tier 1 proxy population visible for diagnostics and scene previewing"):
		return

	T.pass_and_quit(self)

func _capture_renderer_stats(control_mode: String) -> Dictionary:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian gameplay render budget")
		return {}

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "Pedestrian gameplay render budget requires get_streaming_snapshot()"):
		world.queue_free()
		return {}
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Pedestrian gameplay render budget requires get_chunk_renderer()"):
		world.queue_free()
		return {}

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Pedestrian gameplay render budget requires Player node"):
		world.queue_free()
		return {}
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "Pedestrian gameplay render budget requires teleport_to_world_position()"):
		world.queue_free()
		return {}
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "Pedestrian gameplay render budget requires advance_toward_world_position()"):
		world.queue_free()
		return {}

	world.build_minimap_snapshot()
	world.build_minimap_snapshot()
	if world.has_method("set_control_mode"):
		world.set_control_mode(control_mode)
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "Pedestrian gameplay render budget could not reach idle before warm traversal")
		world.queue_free()
		return {}

	var start_position: Vector3 = player.global_position
	var target_position := Vector3(TARGET_WORLD_POSITION.x, player.global_position.y, TARGET_WORLD_POSITION.z)
	if not await _prime_warm_traversal(world, player, start_position, target_position):
		T.fail_and_quit(self, "Pedestrian gameplay render budget could not stabilize the warm traversal corridor")
		world.queue_free()
		return {}

	for _step in range(PROFILE_STEP_COUNT):
		player.advance_toward_world_position(target_position, STEP_DISTANCE_M)
		await process_frame

	var chunk_renderer = world.get_chunk_renderer()
	var stats: Dictionary = {}
	if chunk_renderer != null and chunk_renderer.has_method("get_renderer_stats"):
		stats = chunk_renderer.get_renderer_stats()

	world.queue_free()
	for _frame_index in range(4):
		await process_frame
	return stats

func _wait_for_streaming_idle(world) -> bool:
	var idle_frames := 0
	for _frame_index in range(STREAMING_IDLE_MAX_FRAMES):
		await process_frame
		var snapshot: Dictionary = world.get_streaming_snapshot()
		var pending_total := (
			int(snapshot.get("pending_prepare_count", 0))
			+ int(snapshot.get("pending_surface_async_count", 0))
			+ int(snapshot.get("queued_surface_async_count", 0))
			+ int(snapshot.get("pending_terrain_async_count", 0))
			+ int(snapshot.get("queued_terrain_async_count", 0))
			+ int(snapshot.get("pending_mount_count", 0))
			+ int(snapshot.get("pending_retire_count", 0))
		)
		if pending_total == 0:
			idle_frames += 1
			if idle_frames >= STREAMING_IDLE_STABLE_FRAMES:
				return true
		else:
			idle_frames = 0
	return false

func _prime_warm_traversal(world, player, start_position: Vector3, target_position: Vector3) -> bool:
	for _step in range(PROFILE_STEP_COUNT):
		player.advance_toward_world_position(target_position, STEP_DISTANCE_M)
		await process_frame
	if not await _wait_for_streaming_idle(world):
		return false
	player.teleport_to_world_position(start_position)
	world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
	return await _wait_for_streaming_idle(world)
