extends Node3D

const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityRoadSurfacePageProvider := preload("res://city_game/world/rendering/CityRoadSurfacePageProvider.gd")
const CityTerrainPageProvider := preload("res://city_game/world/rendering/CityTerrainPageProvider.gd")
const CityTerrainMeshBuilder := preload("res://city_game/world/rendering/CityTerrainMeshBuilder.gd")
const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

const PREPARE_BUDGET_PER_TICK := 1
const MOUNT_BUDGET_PER_TICK := 1
const RETIRE_BUDGET_PER_TICK := 1
const MAX_POOLED_CHUNKS := 8
const SURFACE_ASYNC_CONCURRENCY_LIMIT := 1
const TERRAIN_ASYNC_CONCURRENCY_LIMIT := 1

var _config
var _world_data: Dictionary = {}
var _surface_page_provider = CityRoadSurfacePageProvider.new()
var _terrain_page_provider = CityTerrainPageProvider.new()
var _chunk_scenes: Dictionary = {}
var _prepared_payloads: Dictionary = {}
var _pending_prepare: Dictionary = {}
var _surface_waiting_payloads: Dictionary = {}
var _pending_surface_jobs: Dictionary = {}
var _queued_surface_jobs: Array[Dictionary] = []
var _pending_terrain_jobs: Dictionary = {}
var _queued_terrain_jobs: Array[Dictionary] = []
var _pending_mount_ids: Array[String] = []
var _pending_retire_ids: Array[String] = []
var _scene_pool: Array[Node3D] = []
var _last_player_position := Vector3.ZERO
var _last_active_chunk_entries: Array[Dictionary] = []
var _last_prepare_usec := 0
var _last_mount_usec := 0
var _last_retire_usec := 0
var _last_prepare_count := 0
var _last_mount_count := 0
var _last_retire_count := 0
var _last_queue_process_frame := -1
var _prepare_profile_sample_count := 0
var _prepare_profile_total_usec := 0
var _prepare_profile_max_usec := 0
var _prepare_profile_last_usec := 0
var _mount_setup_sample_count := 0
var _mount_setup_total_usec := 0
var _mount_setup_max_usec := 0
var _mount_setup_last_usec := 0
var _surface_async_dispatch_sample_count := 0
var _surface_async_dispatch_total_usec := 0
var _surface_async_dispatch_max_usec := 0
var _surface_async_dispatch_last_usec := 0
var _surface_async_complete_sample_count := 0
var _surface_async_complete_total_usec := 0
var _surface_async_complete_max_usec := 0
var _surface_async_complete_last_usec := 0
var _surface_commit_sample_count := 0
var _surface_commit_total_usec := 0
var _surface_commit_max_usec := 0
var _surface_commit_last_usec := 0
var _terrain_async_dispatch_sample_count := 0
var _terrain_async_dispatch_total_usec := 0
var _terrain_async_dispatch_max_usec := 0
var _terrain_async_dispatch_last_usec := 0
var _terrain_async_complete_sample_count := 0
var _terrain_async_complete_total_usec := 0
var _terrain_async_complete_max_usec := 0
var _terrain_async_complete_last_usec := 0
var _terrain_commit_sample_count := 0
var _terrain_commit_total_usec := 0
var _terrain_commit_max_usec := 0
var _terrain_commit_last_usec := 0
var _pedestrian_tier_controller = null

func setup(config, world_data: Dictionary) -> void:
	_config = config
	_world_data = world_data
	_surface_page_provider = CityRoadSurfacePageProvider.new()
	_surface_page_provider.setup(_config, _world_data)
	_terrain_page_provider = CityTerrainPageProvider.new()
	_terrain_page_provider.setup(_config, _world_data)
	_prepared_payloads.clear()
	_pending_prepare.clear()
	_surface_waiting_payloads.clear()
	_pending_surface_jobs.clear()
	_queued_surface_jobs.clear()
	_pending_terrain_jobs.clear()
	_queued_terrain_jobs.clear()
	_pending_mount_ids.clear()
	_pending_retire_ids.clear()
	_last_active_chunk_entries.clear()
	_last_prepare_usec = 0
	_last_mount_usec = 0
	_last_retire_usec = 0
	_last_prepare_count = 0
	_last_mount_count = 0
	_last_retire_count = 0
	_last_queue_process_frame = -1
	_pedestrian_tier_controller = null
	if _world_data.has("pedestrian_query"):
		_pedestrian_tier_controller = CityPedestrianTierController.new()
		_pedestrian_tier_controller.setup(_config, _world_data)
	reset_streaming_profile_stats()
	set_process(true)

func _process(delta: float) -> void:
	_process_streaming_queues_once_per_frame()
	_update_lod_states(_last_player_position)
	_update_pedestrian_crowd(_last_player_position, delta)

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	for chunk_scene in _scene_pool:
		if is_instance_valid(chunk_scene):
			chunk_scene.free()
	_scene_pool.clear()
	for job in _pending_surface_jobs.values():
		var job_dict: Dictionary = job
		var thread: Thread = job_dict.get("thread")
		if thread != null and thread.is_started():
			thread.wait_to_finish()
	for job in _pending_terrain_jobs.values():
		var job_dict: Dictionary = job
		var thread: Thread = job_dict.get("thread")
		if thread != null and thread.is_started():
			thread.wait_to_finish()
	for chunk_scene in _chunk_scenes.values():
		if is_instance_valid(chunk_scene):
			chunk_scene.free()
	_chunk_scenes.clear()
	_prepared_payloads.clear()
	_pending_prepare.clear()
	_surface_waiting_payloads.clear()
	_pending_surface_jobs.clear()
	_queued_surface_jobs.clear()
	_pending_terrain_jobs.clear()
	_queued_terrain_jobs.clear()
	_pending_mount_ids.clear()
	_pending_retire_ids.clear()
	_last_active_chunk_entries.clear()
	_last_queue_process_frame = -1
	_surface_page_provider.clear()
	_terrain_page_provider.clear()
	_pedestrian_tier_controller = null

func sync_streaming(active_chunk_entries: Array, player_position: Vector3) -> void:
	if _config == null:
		return
	_last_player_position = player_position
	_last_active_chunk_entries.clear()
	for entry_variant in active_chunk_entries:
		_last_active_chunk_entries.append((entry_variant as Dictionary).duplicate(true))

	var target_chunk_entries := _build_target_chunk_map(active_chunk_entries)
	var target_chunk_ids: Dictionary = {}
	for chunk_id in target_chunk_entries.keys():
		target_chunk_ids[chunk_id] = true

	var new_entries: Array[Dictionary] = []
	for entry in active_chunk_entries:
		var chunk_id := str(entry.get("chunk_id", ""))
		if _chunk_scenes.has(chunk_id) or _prepared_payloads.has(chunk_id) or _pending_prepare.has(chunk_id) or _surface_waiting_payloads.has(chunk_id):
			continue
		new_entries.append(entry)
	new_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _distance_to_entry(player_position, a) < _distance_to_entry(player_position, b)
	)
	for entry in new_entries:
		_pending_prepare[str(entry.get("chunk_id", ""))] = entry.duplicate(true)

	for chunk_id in get_chunk_ids():
		if target_chunk_ids.has(chunk_id):
			continue
		_queue_retire(chunk_id)

	for chunk_id in _prepared_payloads.keys():
		if target_chunk_ids.has(chunk_id):
			continue
		_prepared_payloads.erase(chunk_id)

	for chunk_id in _pending_prepare.keys():
		if target_chunk_ids.has(chunk_id):
			continue
		_pending_prepare.erase(chunk_id)

	for chunk_id in _surface_waiting_payloads.keys():
		if target_chunk_ids.has(chunk_id):
			continue
		_surface_waiting_payloads.erase(chunk_id)

	for pending_index in range(_pending_mount_ids.size() - 1, -1, -1):
		var pending_chunk_id := _pending_mount_ids[pending_index]
		if target_chunk_ids.has(pending_chunk_id):
			continue
		_pending_mount_ids.remove_at(pending_index)
	for queued_surface_index in range(_queued_surface_jobs.size() - 1, -1, -1):
		var queued_surface_job: Dictionary = _queued_surface_jobs[queued_surface_index]
		var surface_waiters: Dictionary = queued_surface_job.get("waiter_headers", {})
		var keep_waiter := false
		for waiter_chunk_id in surface_waiters.keys():
			if target_chunk_ids.has(str(waiter_chunk_id)):
				keep_waiter = true
				break
		if keep_waiter:
			continue
		_queued_surface_jobs.remove_at(queued_surface_index)
	for queued_index in range(_queued_terrain_jobs.size() - 1, -1, -1):
		var queued_job: Dictionary = _queued_terrain_jobs[queued_index]
		if target_chunk_ids.has(str(queued_job.get("chunk_id", ""))):
			continue
		_queued_terrain_jobs.remove_at(queued_index)

	_prune_surface_job_waiters(target_chunk_ids)
	_prune_terrain_job_waiters(target_chunk_ids)
	_process_streaming_queues_once_per_frame()
	_update_lod_states(player_position)
	_update_pedestrian_crowd(player_position, 0.0)

func get_chunk_ids() -> Array[String]:
	var ids: Array[String] = []
	for chunk_id in _chunk_scenes.keys():
		ids.append(str(chunk_id))
	ids.sort()
	return ids

func get_chunk_scene_count() -> int:
	return _chunk_scenes.size()

func get_chunk_scene(chunk_id: String):
	return _chunk_scenes.get(chunk_id)

func get_streaming_budget_stats() -> Dictionary:
	return {
		"prepare_budget_per_tick": PREPARE_BUDGET_PER_TICK,
		"mount_budget_per_tick": MOUNT_BUDGET_PER_TICK,
		"retire_budget_per_tick": RETIRE_BUDGET_PER_TICK,
		"pending_prepare_count": _pending_prepare.size(),
		"pending_surface_async_count": _pending_surface_jobs.size(),
		"queued_surface_async_count": _queued_surface_jobs.size(),
		"surface_async_concurrency_limit": SURFACE_ASYNC_CONCURRENCY_LIMIT,
		"pending_terrain_async_count": _pending_terrain_jobs.size(),
		"queued_terrain_async_count": _queued_terrain_jobs.size(),
		"terrain_async_concurrency_limit": TERRAIN_ASYNC_CONCURRENCY_LIMIT,
		"pending_mount_count": _pending_mount_ids.size(),
		"pending_retire_count": _pending_retire_ids.size(),
		"last_prepare_count": _last_prepare_count,
		"last_mount_count": _last_mount_count,
		"last_retire_count": _last_retire_count,
		"last_prepare_usec": _last_prepare_usec,
		"last_mount_usec": _last_mount_usec,
		"last_retire_usec": _last_retire_usec,
		"surface_runtime_page_count": _surface_page_provider.get_runtime_page_count(),
		"terrain_runtime_page_count": _terrain_page_provider.get_runtime_page_count(),
	}

func get_streaming_profile_stats() -> Dictionary:
	return {
		"prepare_profile_sample_count": _prepare_profile_sample_count,
		"prepare_profile_total_usec": _prepare_profile_total_usec,
		"prepare_profile_avg_usec": _average_usec(_prepare_profile_total_usec, _prepare_profile_sample_count),
		"prepare_profile_max_usec": _prepare_profile_max_usec,
		"prepare_profile_last_usec": _prepare_profile_last_usec,
		"mount_setup_sample_count": _mount_setup_sample_count,
		"mount_setup_total_usec": _mount_setup_total_usec,
		"mount_setup_avg_usec": _average_usec(_mount_setup_total_usec, _mount_setup_sample_count),
		"mount_setup_max_usec": _mount_setup_max_usec,
		"mount_setup_last_usec": _mount_setup_last_usec,
		"surface_async_dispatch_sample_count": _surface_async_dispatch_sample_count,
		"surface_async_dispatch_total_usec": _surface_async_dispatch_total_usec,
		"surface_async_dispatch_avg_usec": _average_usec(_surface_async_dispatch_total_usec, _surface_async_dispatch_sample_count),
		"surface_async_dispatch_max_usec": _surface_async_dispatch_max_usec,
		"surface_async_dispatch_last_usec": _surface_async_dispatch_last_usec,
		"surface_async_complete_sample_count": _surface_async_complete_sample_count,
		"surface_async_complete_total_usec": _surface_async_complete_total_usec,
		"surface_async_complete_avg_usec": _average_usec(_surface_async_complete_total_usec, _surface_async_complete_sample_count),
		"surface_async_complete_max_usec": _surface_async_complete_max_usec,
		"surface_async_complete_last_usec": _surface_async_complete_last_usec,
		"surface_commit_sample_count": _surface_commit_sample_count,
		"surface_commit_total_usec": _surface_commit_total_usec,
		"surface_commit_avg_usec": _average_usec(_surface_commit_total_usec, _surface_commit_sample_count),
		"surface_commit_max_usec": _surface_commit_max_usec,
		"surface_commit_last_usec": _surface_commit_last_usec,
		"terrain_async_dispatch_sample_count": _terrain_async_dispatch_sample_count,
		"terrain_async_dispatch_total_usec": _terrain_async_dispatch_total_usec,
		"terrain_async_dispatch_avg_usec": _average_usec(_terrain_async_dispatch_total_usec, _terrain_async_dispatch_sample_count),
		"terrain_async_dispatch_max_usec": _terrain_async_dispatch_max_usec,
		"terrain_async_dispatch_last_usec": _terrain_async_dispatch_last_usec,
		"terrain_async_complete_sample_count": _terrain_async_complete_sample_count,
		"terrain_async_complete_total_usec": _terrain_async_complete_total_usec,
		"terrain_async_complete_avg_usec": _average_usec(_terrain_async_complete_total_usec, _terrain_async_complete_sample_count),
		"terrain_async_complete_max_usec": _terrain_async_complete_max_usec,
		"terrain_async_complete_last_usec": _terrain_async_complete_last_usec,
		"terrain_commit_sample_count": _terrain_commit_sample_count,
		"terrain_commit_total_usec": _terrain_commit_total_usec,
		"terrain_commit_avg_usec": _average_usec(_terrain_commit_total_usec, _terrain_commit_sample_count),
		"terrain_commit_max_usec": _terrain_commit_max_usec,
		"terrain_commit_last_usec": _terrain_commit_last_usec,
	}

func reset_streaming_profile_stats() -> void:
	_prepare_profile_sample_count = 0
	_prepare_profile_total_usec = 0
	_prepare_profile_max_usec = 0
	_prepare_profile_last_usec = 0
	_mount_setup_sample_count = 0
	_mount_setup_total_usec = 0
	_mount_setup_max_usec = 0
	_mount_setup_last_usec = 0
	_surface_async_dispatch_sample_count = 0
	_surface_async_dispatch_total_usec = 0
	_surface_async_dispatch_max_usec = 0
	_surface_async_dispatch_last_usec = 0
	_surface_async_complete_sample_count = 0
	_surface_async_complete_total_usec = 0
	_surface_async_complete_max_usec = 0
	_surface_async_complete_last_usec = 0
	_surface_commit_sample_count = 0
	_surface_commit_total_usec = 0
	_surface_commit_max_usec = 0
	_surface_commit_last_usec = 0
	_terrain_async_dispatch_sample_count = 0
	_terrain_async_dispatch_total_usec = 0
	_terrain_async_dispatch_max_usec = 0
	_terrain_async_dispatch_last_usec = 0
	_terrain_async_complete_sample_count = 0
	_terrain_async_complete_total_usec = 0
	_terrain_async_complete_max_usec = 0
	_terrain_async_complete_last_usec = 0
	_terrain_commit_sample_count = 0
	_terrain_commit_total_usec = 0
	_terrain_commit_max_usec = 0
	_terrain_commit_last_usec = 0

func get_renderer_stats() -> Dictionary:
	var lod_mode_counts := {
		"near": 0,
		"mid": 0,
		"far": 0,
	}
	var multimesh_instance_total := 0
	var pedestrian_multimesh_instance_total := 0
	var pedestrian_tier1_total := 0
	var pedestrian_tier2_total := 0
	for chunk_id in get_chunk_ids():
		var chunk_scene = _chunk_scenes[chunk_id]
		var chunk_stats: Dictionary = chunk_scene.get_renderer_stats()
		var lod_mode := str(chunk_stats.get("lod_mode", ""))
		if lod_mode_counts.has(lod_mode):
			lod_mode_counts[lod_mode] += 1
		multimesh_instance_total += int(chunk_stats.get("multimesh_instance_count", 0))
		pedestrian_multimesh_instance_total += int(chunk_stats.get("pedestrian_multimesh_instance_count", 0))
		pedestrian_tier1_total += int(chunk_stats.get("pedestrian_tier1_count", 0))
		pedestrian_tier2_total += int(chunk_stats.get("pedestrian_tier2_count", 0))
	var pedestrian_budget_contract := {}
	var pedestrian_global_snapshot := {}
	if _pedestrian_tier_controller != null:
		pedestrian_budget_contract = _pedestrian_tier_controller.get_budget_contract()
		pedestrian_global_snapshot = _pedestrian_tier_controller.get_global_snapshot()
	var stats := {
		"active_rendered_chunk_count": get_chunk_scene_count(),
		"multimesh_instance_total": multimesh_instance_total,
		"pedestrian_multimesh_instance_total": pedestrian_multimesh_instance_total,
		"pedestrian_tier1_total": pedestrian_tier1_total,
		"pedestrian_tier2_total": pedestrian_tier2_total,
		"pedestrian_active_state_count": int(pedestrian_global_snapshot.get("active_state_count", 0)),
		"pedestrian_budget_contract": pedestrian_budget_contract.duplicate(true),
		"lod_mode_counts": lod_mode_counts,
	}
	stats.merge(get_streaming_budget_stats(), true)
	stats.merge(get_streaming_profile_stats(), true)
	return stats

func get_chunk_scene_stats(chunk_id: String) -> Dictionary:
	if not _chunk_scenes.has(chunk_id):
		return {}
	return (_chunk_scenes[chunk_id] as Node).get_renderer_stats()

func _build_target_chunk_map(active_chunk_entries: Array) -> Dictionary:
	var map := {}
	for entry in active_chunk_entries:
		map[str(entry.get("chunk_id", ""))] = entry.duplicate(true)
	return map

func _queue_retire(chunk_id: String) -> void:
	if not _chunk_scenes.has(chunk_id):
		return
	if _pending_retire_ids.has(chunk_id):
		return
	_pending_retire_ids.append(chunk_id)

func _process_streaming_queues() -> void:
	_process_retire_budget()
	_collect_completed_terrain_jobs()
	_dispatch_queued_terrain_jobs()
	_collect_completed_surface_jobs()
	_dispatch_queued_surface_jobs()
	_process_mount_budget()
	_process_prepare_budget()

func _process_streaming_queues_once_per_frame() -> void:
	var process_frame := Engine.get_process_frames()
	if _last_queue_process_frame == process_frame:
		return
	_last_queue_process_frame = process_frame
	_process_streaming_queues()

func _process_prepare_budget() -> void:
	var prepare_ids: Array[String] = []
	for chunk_id in _pending_prepare.keys():
		prepare_ids.append(str(chunk_id))
	prepare_ids.sort_custom(func(a: String, b: String) -> bool:
		return _distance_to_entry(_last_player_position, _pending_prepare[a]) < _distance_to_entry(_last_player_position, _pending_prepare[b])
	)

	var started_usec := Time.get_ticks_usec()
	var prepared_count := 0
	for chunk_id in prepare_ids:
		if prepared_count >= PREPARE_BUDGET_PER_TICK:
			break
		var entry: Dictionary = _pending_prepare[chunk_id]
		var payload := _build_chunk_payload(entry)
		var profile_started_usec := Time.get_ticks_usec()
		payload["prepared_profile"] = CityChunkProfileBuilder.build_profile(payload)
		_record_prepare_profile_sample(Time.get_ticks_usec() - profile_started_usec)
		payload["surface_page_provider"] = _surface_page_provider
		payload["terrain_page_provider"] = _terrain_page_provider
		payload["initial_lod_mode"] = _resolve_initial_lod_mode(payload)
		_surface_waiting_payloads[chunk_id] = payload
		var terrain_page_header: Dictionary = _terrain_page_provider.build_chunk_page_header(payload, int(CityChunkScene.TERRAIN_GRID_STEPS))
		payload["terrain_page_header"] = terrain_page_header
		_surface_waiting_payloads[chunk_id] = payload
		var terrain_runtime_key := str(terrain_page_header.get("runtime_key", ""))
		if _terrain_page_provider.has_runtime_bundle(terrain_runtime_key):
			var terrain_runtime_bundle := _terrain_page_provider.get_runtime_bundle(terrain_runtime_key)
			var terrain_page_binding := CityTerrainPageProvider.build_chunk_binding_from_bundle(terrain_page_header, terrain_runtime_bundle, true)
			payload["terrain_page_binding"] = terrain_page_binding
			payload["terrain_lod_mesh_results"] = {
				str(payload.get("initial_lod_mode", CityChunkScene.LOD_NEAR)): _build_terrain_mesh_result_for_payload(payload, terrain_page_binding),
			}
			_surface_waiting_payloads[chunk_id] = payload
		else:
			_queue_terrain_job(chunk_id, payload, terrain_page_header, int(CityChunkScene.TERRAIN_GRID_STEPS), _terrain_lod_grid_steps_by_mode())
		payload = (_surface_waiting_payloads.get(chunk_id, payload) as Dictionary).duplicate(true)
		var detail_mode := _resolve_surface_detail_mode_for_lod(str(payload.get("initial_lod_mode", CityChunkScene.LOD_NEAR)))
		var page_header: Dictionary = _surface_page_provider.build_chunk_page_header(payload, detail_mode)
		payload["surface_page_header"] = page_header
		var runtime_key := str(page_header.get("runtime_key", ""))
		if _surface_page_provider.has_runtime_bundle(runtime_key):
			payload["surface_page_binding"] = _surface_page_provider.build_chunk_binding(
				page_header,
				_surface_page_provider.get_runtime_bundle(runtime_key),
				true
			)
			_surface_waiting_payloads[chunk_id] = payload
		else:
			_surface_waiting_payloads[chunk_id] = payload
			_queue_surface_job(chunk_id, payload, page_header, detail_mode)
		_try_enqueue_waiting_payload(chunk_id)
		_pending_prepare.erase(chunk_id)
		prepared_count += 1
	_last_prepare_count = prepared_count
	_last_prepare_usec = _duration_or_zero(started_usec, prepared_count)

func _process_mount_budget() -> void:
	var started_usec := Time.get_ticks_usec()
	var mounted_count := 0
	while not _pending_mount_ids.is_empty() and mounted_count < MOUNT_BUDGET_PER_TICK:
		var chunk_id: String = str(_pending_mount_ids.pop_front())
		if _chunk_scenes.has(chunk_id):
			continue
		if not _prepared_payloads.has(chunk_id):
			continue
		var payload: Dictionary = _prepared_payloads[chunk_id]
		var chunk_scene := _take_pooled_scene()
		var setup_started_usec := Time.get_ticks_usec()
		chunk_scene.setup(payload)
		if _pedestrian_tier_controller != null and chunk_scene.has_method("apply_pedestrian_chunk_snapshot"):
			chunk_scene.apply_pedestrian_chunk_snapshot(_pedestrian_tier_controller.get_chunk_snapshot(chunk_id))
		_record_mount_setup_sample(Time.get_ticks_usec() - setup_started_usec)
		var setup_profile: Dictionary = chunk_scene.get_setup_profile()
		_record_terrain_commit_sample(int(setup_profile.get("ground_mesh_usec", 0)))
		chunk_scene.visible = true
		add_child(chunk_scene)
		_chunk_scenes[chunk_id] = chunk_scene
		_prepared_payloads.erase(chunk_id)
		mounted_count += 1
	_last_mount_count = mounted_count
	_last_mount_usec = _duration_or_zero(started_usec, mounted_count)

func _process_retire_budget() -> void:
	var started_usec := Time.get_ticks_usec()
	var retired_count := 0
	while not _pending_retire_ids.is_empty() and retired_count < RETIRE_BUDGET_PER_TICK:
		var chunk_id: String = str(_pending_retire_ids.pop_front())
		if not _chunk_scenes.has(chunk_id):
			continue
		var chunk_scene: Node3D = _chunk_scenes[chunk_id]
		_chunk_scenes.erase(chunk_id)
		remove_child(chunk_scene)
		chunk_scene.visible = false
		if _scene_pool.size() < MAX_POOLED_CHUNKS:
			_scene_pool.append(chunk_scene)
		else:
			chunk_scene.queue_free()
		retired_count += 1
	_last_retire_count = retired_count
	_last_retire_usec = _duration_or_zero(started_usec, retired_count)

func _take_pooled_scene() -> Node3D:
	if _scene_pool.is_empty():
		return CityChunkScene.new()
	return _scene_pool.pop_back()

func _update_lod_states(player_position: Vector3) -> void:
	for chunk_id in get_chunk_ids():
		var chunk_scene: Node3D = _chunk_scenes[chunk_id]
		chunk_scene.update_lod_for_distance(player_position.distance_to(chunk_scene.position))

func _update_pedestrian_crowd(player_position: Vector3, delta: float) -> void:
	if _pedestrian_tier_controller == null:
		return
	_pedestrian_tier_controller.update_active_chunks(_last_active_chunk_entries, player_position, delta)
	for chunk_id in get_chunk_ids():
		var chunk_scene: Node3D = _chunk_scenes[chunk_id]
		if chunk_scene.has_method("apply_pedestrian_chunk_snapshot"):
			chunk_scene.apply_pedestrian_chunk_snapshot(_pedestrian_tier_controller.get_chunk_snapshot(chunk_id))

func _distance_to_entry(player_position: Vector3, entry: Dictionary) -> float:
	var chunk_key: Vector2i = entry.get("chunk_key", Vector2i.ZERO)
	var chunk_center := _chunk_center_from_key(chunk_key)
	return player_position.distance_to(chunk_center)

func _resolve_initial_lod_mode(payload: Dictionary) -> String:
	var chunk_center: Vector3 = payload.get("chunk_center", Vector3.ZERO)
	var distance_m := _last_player_position.distance_to(chunk_center)
	if distance_m < float(CityChunkScene.NEAR_THRESHOLD_M):
		return CityChunkScene.LOD_NEAR
	if distance_m < float(CityChunkScene.MID_THRESHOLD_M):
		return CityChunkScene.LOD_MID
	return CityChunkScene.LOD_FAR

func _build_chunk_payload(entry: Dictionary) -> Dictionary:
	var chunk_key: Vector2i = entry.get("chunk_key", Vector2i.ZERO)
	var chunk_id := str(entry.get("chunk_id", ""))
	return {
		"chunk_id": chunk_id,
		"chunk_key": chunk_key,
		"chunk_center": _chunk_center_from_key(chunk_key),
		"chunk_size_m": float(_config.chunk_size_m),
		"chunk_seed": _config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(_config.base_seed),
		"road_graph": _world_data.get("road_graph"),
		"pedestrian_chunk_snapshot": {} if _pedestrian_tier_controller == null else _pedestrian_tier_controller.get_chunk_snapshot(chunk_id),
	}

func _chunk_center_from_key(chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = _config.get_world_bounds()
	var center_x := bounds.position.x + (float(chunk_key.x) + 0.5) * float(_config.chunk_size_m)
	var center_z := bounds.position.y + (float(chunk_key.y) + 0.5) * float(_config.chunk_size_m)
	return Vector3(center_x, 0.0, center_z)

func _duration_or_zero(started_usec: int, item_count: int) -> int:
	if item_count <= 0:
		return 0
	return maxi(int(Time.get_ticks_usec() - started_usec), 1)

func _record_prepare_profile_sample(duration_usec: int) -> void:
	_prepare_profile_sample_count += 1
	_prepare_profile_total_usec += duration_usec
	_prepare_profile_max_usec = maxi(_prepare_profile_max_usec, duration_usec)
	_prepare_profile_last_usec = duration_usec

func _record_mount_setup_sample(duration_usec: int) -> void:
	_mount_setup_sample_count += 1
	_mount_setup_total_usec += duration_usec
	_mount_setup_max_usec = maxi(_mount_setup_max_usec, duration_usec)
	_mount_setup_last_usec = duration_usec

func _record_surface_async_dispatch_sample(duration_usec: int) -> void:
	_surface_async_dispatch_sample_count += 1
	_surface_async_dispatch_total_usec += duration_usec
	_surface_async_dispatch_max_usec = maxi(_surface_async_dispatch_max_usec, duration_usec)
	_surface_async_dispatch_last_usec = duration_usec

func _record_surface_async_complete_sample(duration_usec: int) -> void:
	_surface_async_complete_sample_count += 1
	_surface_async_complete_total_usec += duration_usec
	_surface_async_complete_max_usec = maxi(_surface_async_complete_max_usec, duration_usec)
	_surface_async_complete_last_usec = duration_usec

func _record_surface_commit_sample(duration_usec: int) -> void:
	_surface_commit_sample_count += 1
	_surface_commit_total_usec += duration_usec
	_surface_commit_max_usec = maxi(_surface_commit_max_usec, duration_usec)
	_surface_commit_last_usec = duration_usec

func _record_terrain_async_dispatch_sample(duration_usec: int) -> void:
	_terrain_async_dispatch_sample_count += 1
	_terrain_async_dispatch_total_usec += duration_usec
	_terrain_async_dispatch_max_usec = maxi(_terrain_async_dispatch_max_usec, duration_usec)
	_terrain_async_dispatch_last_usec = duration_usec

func _record_terrain_async_complete_sample(duration_usec: int) -> void:
	_terrain_async_complete_sample_count += 1
	_terrain_async_complete_total_usec += duration_usec
	_terrain_async_complete_max_usec = maxi(_terrain_async_complete_max_usec, duration_usec)
	_terrain_async_complete_last_usec = duration_usec

func _record_terrain_commit_sample(duration_usec: int) -> void:
	if duration_usec <= 0:
		return
	_terrain_commit_sample_count += 1
	_terrain_commit_total_usec += duration_usec
	_terrain_commit_max_usec = maxi(_terrain_commit_max_usec, duration_usec)
	_terrain_commit_last_usec = duration_usec

func _average_usec(total_usec: int, sample_count: int) -> int:
	if sample_count <= 0:
		return 0
	return int(round(float(total_usec) / float(sample_count)))

func _resolve_surface_detail_mode_for_lod(lod_mode: String) -> String:
	return CityChunkScene.SURFACE_DETAIL_FULL if lod_mode == CityChunkScene.LOD_NEAR else CityChunkScene.SURFACE_DETAIL_COARSE

func _enqueue_ready_payload(chunk_id: String, payload: Dictionary) -> void:
	_prepared_payloads[chunk_id] = payload
	if not _pending_mount_ids.has(chunk_id):
		_pending_mount_ids.append(chunk_id)

func _try_enqueue_waiting_payload(chunk_id: String) -> void:
	if not _surface_waiting_payloads.has(chunk_id):
		return
	var payload: Dictionary = _surface_waiting_payloads[chunk_id]
	var surface_binding: Dictionary = payload.get("surface_page_binding", {})
	var terrain_lod_mesh_results: Dictionary = payload.get("terrain_lod_mesh_results", {})
	if surface_binding.is_empty() or terrain_lod_mesh_results.is_empty():
		_surface_waiting_payloads[chunk_id] = payload
		return
	_surface_waiting_payloads.erase(chunk_id)
	_enqueue_ready_payload(chunk_id, payload)

func _queue_terrain_job(chunk_id: String, payload: Dictionary, page_header: Dictionary, grid_steps: int, lod_grid_steps_by_mode: Dictionary) -> void:
	if _pending_terrain_jobs.has(chunk_id):
		return
	var runtime_key := str(page_header.get("runtime_key", ""))
	var existing_runtime_bundle := {}
	var runtime_hit := false
	if _terrain_page_provider.has_runtime_bundle(runtime_key):
		existing_runtime_bundle = _terrain_page_provider.get_runtime_bundle(runtime_key).duplicate(true)
		runtime_hit = true
	var job_request := {
		"chunk_id": chunk_id,
		"chunk_size_m": float(payload.get("chunk_size_m", 256.0)),
		"grid_steps": grid_steps,
		"lod_grid_steps_by_mode": lod_grid_steps_by_mode.duplicate(true),
		"initial_lod_mode": str(payload.get("initial_lod_mode", CityChunkScene.LOD_NEAR)),
		"page_header": page_header.duplicate(true),
		"page_request": _terrain_page_provider.build_page_request(payload, grid_steps, page_header),
		"existing_runtime_bundle": existing_runtime_bundle,
		"runtime_hit": runtime_hit,
	}
	if _pending_terrain_jobs.size() >= TERRAIN_ASYNC_CONCURRENCY_LIMIT:
		_queued_terrain_jobs.append({
			"chunk_id": chunk_id,
			"job_request": job_request,
		})
		return
	_dispatch_terrain_job_request(chunk_id, job_request, runtime_key)

func _dispatch_terrain_job_request(chunk_id: String, job_request: Dictionary, runtime_key: String) -> void:
	var thread := Thread.new()
	var dispatch_started_usec := Time.get_ticks_usec()
	var start_error := thread.start(Callable(self, "_prepare_terrain_request_async").bind(job_request))
	_record_terrain_async_dispatch_sample(Time.get_ticks_usec() - dispatch_started_usec)
	if start_error != OK:
		_apply_completed_terrain_job(_prepare_terrain_request_async(job_request))
		return

	_pending_terrain_jobs[chunk_id] = {
		"thread": thread,
		"runtime_key": runtime_key,
	}

func _dispatch_queued_terrain_jobs() -> void:
	var dispatch_index := 0
	while _pending_terrain_jobs.size() < TERRAIN_ASYNC_CONCURRENCY_LIMIT and dispatch_index < _queued_terrain_jobs.size():
		var queued_job: Dictionary = _queued_terrain_jobs[dispatch_index]
		dispatch_index += 1
		var chunk_id := str(queued_job.get("chunk_id", ""))
		if chunk_id == "" or not _surface_waiting_payloads.has(chunk_id):
			continue
		var job_request: Dictionary = queued_job.get("job_request", {})
		_dispatch_terrain_job_request(chunk_id, job_request, str((job_request.get("page_header", {}) as Dictionary).get("runtime_key", "")))
	if dispatch_index > 0:
		_queued_terrain_jobs = _queued_terrain_jobs.slice(dispatch_index)

func _queue_surface_job(chunk_id: String, payload: Dictionary, page_header: Dictionary, detail_mode: String) -> void:
	var runtime_key := str(page_header.get("runtime_key", ""))
	if _pending_surface_jobs.has(runtime_key):
		var existing_job: Dictionary = _pending_surface_jobs[runtime_key]
		var waiter_headers: Dictionary = existing_job.get("waiter_headers", {})
		waiter_headers[chunk_id] = page_header.duplicate(true)
		existing_job["waiter_headers"] = waiter_headers
		_pending_surface_jobs[runtime_key] = existing_job
		return
	for queued_index in range(_queued_surface_jobs.size()):
		var queued_job: Dictionary = _queued_surface_jobs[queued_index]
		if str(queued_job.get("runtime_key", "")) != runtime_key:
			continue
		var queued_waiters: Dictionary = queued_job.get("waiter_headers", {})
		queued_waiters[chunk_id] = page_header.duplicate(true)
		queued_job["waiter_headers"] = queued_waiters
		_queued_surface_jobs[queued_index] = queued_job
		return

	var page_request := _surface_page_provider.build_page_request(payload, detail_mode, page_header)
	var initial_waiter_headers := {
		chunk_id: page_header.duplicate(true),
	}
	if _pending_surface_jobs.size() >= SURFACE_ASYNC_CONCURRENCY_LIMIT:
		_queued_surface_jobs.append({
			"runtime_key": runtime_key,
			"page_request": page_request,
			"waiter_headers": initial_waiter_headers,
		})
		return
	_dispatch_surface_job_request(runtime_key, page_request, initial_waiter_headers)

func _dispatch_surface_job_request(runtime_key: String, page_request: Dictionary, waiter_headers: Dictionary) -> void:
	var thread := Thread.new()
	var dispatch_started_usec := Time.get_ticks_usec()
	var start_error := thread.start(Callable(self, "_prepare_surface_request_async").bind(page_request.get("surface_request", {})))
	_record_surface_async_dispatch_sample(Time.get_ticks_usec() - dispatch_started_usec)
	if start_error != OK:
		var surface_data := _prepare_surface_request_async(page_request.get("surface_request", {}))
		var surface_stats: Dictionary = surface_data.get("mask_profile_stats", {})
		_record_surface_async_complete_sample(int(surface_stats.get("prepare_total_usec", surface_stats.get("total_usec", 0))))
		var runtime_bundle := _surface_page_provider.store_runtime_bundle(runtime_key, surface_data)
		_record_surface_commit_sample(int(runtime_bundle.get("commit_usec", 0)))
		for waiter_chunk_id in waiter_headers.keys():
			var chunk_id := str(waiter_chunk_id)
			if not _surface_waiting_payloads.has(chunk_id):
				continue
			var payload: Dictionary = _surface_waiting_payloads[chunk_id]
			payload["surface_page_binding"] = _surface_page_provider.build_chunk_binding(waiter_headers[waiter_chunk_id], runtime_bundle, false)
			_surface_waiting_payloads[chunk_id] = payload
			_try_enqueue_waiting_payload(chunk_id)
		return

	_pending_surface_jobs[runtime_key] = {
		"thread": thread,
		"waiter_headers": waiter_headers,
	}

func _dispatch_queued_surface_jobs() -> void:
	var dispatch_index := 0
	while _pending_surface_jobs.size() < SURFACE_ASYNC_CONCURRENCY_LIMIT and dispatch_index < _queued_surface_jobs.size():
		var queued_job: Dictionary = _queued_surface_jobs[dispatch_index]
		dispatch_index += 1
		var waiter_headers: Dictionary = queued_job.get("waiter_headers", {})
		var has_live_waiter := false
		for waiter_chunk_id in waiter_headers.keys():
			if _surface_waiting_payloads.has(str(waiter_chunk_id)):
				has_live_waiter = true
				break
		if not has_live_waiter:
			continue
		_dispatch_surface_job_request(
			str(queued_job.get("runtime_key", "")),
			queued_job.get("page_request", {}),
			waiter_headers
		)
	if dispatch_index > 0:
		_queued_surface_jobs = _queued_surface_jobs.slice(dispatch_index)

func _collect_completed_terrain_jobs() -> void:
	var chunk_ids: Array[String] = []
	for chunk_id in _pending_terrain_jobs.keys():
		chunk_ids.append(str(chunk_id))
	chunk_ids.sort()

	for chunk_id in chunk_ids:
		var job: Dictionary = _pending_terrain_jobs[chunk_id]
		var thread: Thread = job.get("thread")
		if thread == null or thread.is_alive():
			continue
		var thread_result: Variant = thread.wait_to_finish()
		_pending_terrain_jobs.erase(chunk_id)
		if not (thread_result is Dictionary):
			continue
		_apply_completed_terrain_job(thread_result)

func _collect_completed_surface_jobs() -> void:
	var runtime_keys: Array[String] = []
	for runtime_key in _pending_surface_jobs.keys():
		runtime_keys.append(str(runtime_key))
	runtime_keys.sort()

	for runtime_key in runtime_keys:
		var job: Dictionary = _pending_surface_jobs[runtime_key]
		var thread: Thread = job.get("thread")
		if thread == null or thread.is_alive():
			continue
		var thread_result: Variant = thread.wait_to_finish()
		if not (thread_result is Dictionary):
			_pending_surface_jobs.erase(runtime_key)
			continue
		var surface_data: Dictionary = thread_result
		var surface_stats: Dictionary = surface_data.get("mask_profile_stats", {})
		_record_surface_async_complete_sample(int(surface_stats.get("prepare_total_usec", surface_stats.get("total_usec", 0))))
		var runtime_bundle := _surface_page_provider.store_runtime_bundle(runtime_key, surface_data)
		_record_surface_commit_sample(int(runtime_bundle.get("commit_usec", 0)))
		var waiter_headers: Dictionary = job.get("waiter_headers", {})
		for waiter_chunk_id in waiter_headers.keys():
			var chunk_id := str(waiter_chunk_id)
			if not _surface_waiting_payloads.has(chunk_id):
				continue
			var payload: Dictionary = _surface_waiting_payloads[chunk_id]
			payload["surface_page_binding"] = _surface_page_provider.build_chunk_binding(waiter_headers[waiter_chunk_id], runtime_bundle, false)
			_surface_waiting_payloads[chunk_id] = payload
			_try_enqueue_waiting_payload(chunk_id)
		_pending_surface_jobs.erase(runtime_key)

func _prune_surface_job_waiters(target_chunk_ids: Dictionary) -> void:
	for runtime_key in _pending_surface_jobs.keys():
		var job: Dictionary = _pending_surface_jobs[runtime_key]
		var waiter_headers: Dictionary = job.get("waiter_headers", {})
		for waiter_chunk_id in waiter_headers.keys():
			if target_chunk_ids.has(str(waiter_chunk_id)):
				continue
			waiter_headers.erase(waiter_chunk_id)
		job["waiter_headers"] = waiter_headers
		_pending_surface_jobs[runtime_key] = job

func _prune_terrain_job_waiters(target_chunk_ids: Dictionary) -> void:
	for chunk_id in _pending_terrain_jobs.keys():
		if target_chunk_ids.has(str(chunk_id)):
			continue
		var job: Dictionary = _pending_terrain_jobs[chunk_id]
		job["orphaned"] = true
		_pending_terrain_jobs[chunk_id] = job

func _apply_completed_terrain_job(thread_result: Dictionary) -> void:
	var chunk_id := str(thread_result.get("chunk_id", ""))
	_record_terrain_async_complete_sample(int(thread_result.get("prepare_usec", 0)))
	var runtime_key := str(thread_result.get("runtime_key", ""))
	var runtime_hit := bool(thread_result.get("runtime_hit", false))
	if not runtime_hit:
		_terrain_page_provider.store_runtime_bundle(runtime_key, thread_result.get("runtime_bundle", {}))
	if not _surface_waiting_payloads.has(chunk_id):
		return
	var payload: Dictionary = _surface_waiting_payloads[chunk_id]
	payload["terrain_page_binding"] = (thread_result.get("terrain_page_binding", {}) as Dictionary).duplicate(true)
	payload["terrain_lod_mesh_results"] = (thread_result.get("terrain_lod_mesh_results", {}) as Dictionary).duplicate(true)
	_surface_waiting_payloads[chunk_id] = payload
	_try_enqueue_waiting_payload(chunk_id)

func _prepare_surface_request_async(surface_request: Dictionary) -> Dictionary:
	return CityRoadMaskBuilder.prepare_surface_data(surface_request)

func _prepare_terrain_request_async(job_request: Dictionary) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var page_header: Dictionary = job_request.get("page_header", {})
	var runtime_bundle: Dictionary = (job_request.get("existing_runtime_bundle", {}) as Dictionary).duplicate(true)
	var runtime_hit := bool(job_request.get("runtime_hit", false))
	if runtime_bundle.is_empty():
		runtime_bundle = CityTerrainPageProvider.prepare_page_bundle(job_request.get("page_request", {}))
		runtime_hit = false
	var terrain_page_binding := CityTerrainPageProvider.build_chunk_binding_from_bundle(page_header, runtime_bundle, runtime_hit)
	var initial_lod_mode := str(job_request.get("initial_lod_mode", CityChunkScene.LOD_NEAR))
	var lod_grid_steps_by_mode: Dictionary = job_request.get("lod_grid_steps_by_mode", _terrain_lod_grid_steps_by_mode())
	var source_grid_steps := int(job_request.get("grid_steps", CityChunkScene.TERRAIN_GRID_STEPS))
	var terrain_grid_steps := int(lod_grid_steps_by_mode.get(initial_lod_mode, source_grid_steps))
	var terrain_mesh_builder := CityTerrainMeshBuilder.new()
	var terrain_mesh_result: Dictionary
	if terrain_grid_steps == source_grid_steps:
		terrain_mesh_result = terrain_mesh_builder.build_profiled_terrain_arrays_from_binding(
			float(job_request.get("chunk_size_m", 256.0)),
			terrain_grid_steps,
			terrain_page_binding
		)
	else:
		var reduced_results := terrain_mesh_builder.build_profiled_terrain_lod_arrays_from_binding(
			float(job_request.get("chunk_size_m", 256.0)),
			source_grid_steps,
			terrain_page_binding,
			{initial_lod_mode: terrain_grid_steps}
		)
		terrain_mesh_result = (reduced_results.get(initial_lod_mode, {}) as Dictionary).duplicate(true)
	return {
		"chunk_id": str(job_request.get("chunk_id", "")),
		"runtime_key": str(page_header.get("runtime_key", "")),
		"runtime_hit": runtime_hit,
		"runtime_bundle": runtime_bundle,
		"terrain_page_binding": terrain_page_binding,
		"terrain_lod_mesh_results": {
			initial_lod_mode: terrain_mesh_result,
		},
		"prepare_usec": Time.get_ticks_usec() - started_usec,
	}

func _terrain_lod_grid_steps_by_mode() -> Dictionary:
	return {
		CityChunkScene.LOD_NEAR: int(CityChunkScene.TERRAIN_GRID_STEPS),
		CityChunkScene.LOD_MID: int(CityChunkScene.TERRAIN_GRID_STEPS_MID),
		CityChunkScene.LOD_FAR: int(CityChunkScene.TERRAIN_GRID_STEPS_FAR),
	}

func _build_terrain_mesh_result_for_payload(payload: Dictionary, terrain_page_binding: Dictionary) -> Dictionary:
	var initial_lod_mode := str(payload.get("initial_lod_mode", CityChunkScene.LOD_NEAR))
	var lod_grid_steps_by_mode := _terrain_lod_grid_steps_by_mode()
	var source_grid_steps := int(terrain_page_binding.get("grid_steps", CityChunkScene.TERRAIN_GRID_STEPS))
	var terrain_grid_steps := int(lod_grid_steps_by_mode.get(initial_lod_mode, source_grid_steps))
	var terrain_mesh_builder := CityTerrainMeshBuilder.new()
	if terrain_grid_steps == source_grid_steps:
		return terrain_mesh_builder.build_profiled_terrain_arrays_from_binding(
			float(payload.get("chunk_size_m", 256.0)),
			terrain_grid_steps,
			terrain_page_binding
		)
	var reduced_results := terrain_mesh_builder.build_profiled_terrain_lod_arrays_from_binding(
		float(payload.get("chunk_size_m", 256.0)),
		source_grid_steps,
		terrain_page_binding,
		{initial_lod_mode: terrain_grid_steps}
	)
	return (reduced_results.get(initial_lod_mode, {}) as Dictionary).duplicate(true)
