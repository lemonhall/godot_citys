extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for runtime streaming diagnostics")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "CityPrototype must expose get_performance_profile() for runtime streaming diagnostics"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "CityPrototype must expose reset_performance_profile() for runtime streaming diagnostics"):
		return
	if not T.require_true(self, world.has_method("set_performance_diagnostics_enabled"), "CityPrototype must expose set_performance_diagnostics_enabled() for runtime streaming diagnostics"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Runtime streaming diagnostics require Player node"):
		return
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "PlayerController must expose advance_toward_world_position() for runtime streaming diagnostics"):
		return

	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")
	world.set_performance_diagnostics_enabled(true)
	world.reset_performance_profile()

	var target_position := Vector3(512.0, player.global_position.y, 96.0)
	for _step in range(12):
		player.advance_toward_world_position(target_position, 24.0)
		await process_frame

	var profile: Dictionary = world.get_performance_profile()
	for required_key in [
		"update_streaming_chunk_streamer_sample_count",
		"update_streaming_chunk_streamer_avg_usec",
		"update_streaming_chunk_streamer_max_usec",
		"update_streaming_renderer_sync_sample_count",
		"update_streaming_renderer_sync_avg_usec",
		"update_streaming_renderer_sync_max_usec",
		"update_streaming_renderer_sync_queue_sample_count",
		"update_streaming_renderer_sync_queue_avg_usec",
		"update_streaming_renderer_sync_queue_max_usec",
		"update_streaming_renderer_sync_queue_retire_sample_count",
		"update_streaming_renderer_sync_queue_retire_avg_usec",
		"update_streaming_renderer_sync_queue_retire_max_usec",
		"update_streaming_renderer_sync_queue_terrain_collect_sample_count",
		"update_streaming_renderer_sync_queue_terrain_collect_avg_usec",
		"update_streaming_renderer_sync_queue_terrain_collect_max_usec",
		"update_streaming_renderer_sync_queue_terrain_dispatch_sample_count",
		"update_streaming_renderer_sync_queue_terrain_dispatch_avg_usec",
		"update_streaming_renderer_sync_queue_terrain_dispatch_max_usec",
		"update_streaming_renderer_sync_queue_surface_collect_sample_count",
		"update_streaming_renderer_sync_queue_surface_collect_avg_usec",
		"update_streaming_renderer_sync_queue_surface_collect_max_usec",
		"update_streaming_renderer_sync_queue_surface_dispatch_sample_count",
		"update_streaming_renderer_sync_queue_surface_dispatch_avg_usec",
		"update_streaming_renderer_sync_queue_surface_dispatch_max_usec",
		"update_streaming_renderer_sync_queue_mount_sample_count",
		"update_streaming_renderer_sync_queue_mount_avg_usec",
		"update_streaming_renderer_sync_queue_mount_max_usec",
		"update_streaming_renderer_sync_queue_prepare_sample_count",
		"update_streaming_renderer_sync_queue_prepare_avg_usec",
		"update_streaming_renderer_sync_queue_prepare_max_usec",
		"update_streaming_renderer_sync_lod_sample_count",
		"update_streaming_renderer_sync_lod_avg_usec",
		"update_streaming_renderer_sync_lod_max_usec",
		"update_streaming_renderer_sync_far_proxy_sample_count",
		"update_streaming_renderer_sync_far_proxy_avg_usec",
		"update_streaming_renderer_sync_far_proxy_max_usec",
		"update_streaming_renderer_sync_crowd_sample_count",
		"update_streaming_renderer_sync_crowd_avg_usec",
		"update_streaming_renderer_sync_crowd_max_usec",
		"update_streaming_renderer_sync_traffic_sample_count",
		"update_streaming_renderer_sync_traffic_avg_usec",
		"update_streaming_renderer_sync_traffic_max_usec",
		"crowd_assignment_decision",
		"crowd_assignment_rebuild_reason",
		"crowd_assignment_player_velocity_mps",
		"crowd_assignment_raw_player_velocity_mps",
		"crowd_assignment_player_speed_delta_mps",
		"crowd_assignment_player_speed_cap_mps",
	]:
		if not T.require_true(self, profile.has(required_key), "Runtime streaming diagnostics must expose %s" % required_key):
			return

	if not T.require_true(self, int(profile.get("update_streaming_chunk_streamer_sample_count", 0)) > 0, "Runtime streaming diagnostics must record chunk streamer samples"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_sample_count", 0)) > 0, "Runtime streaming diagnostics must record renderer sync samples"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_avg_usec", 0)) > 0, "Runtime streaming diagnostics must keep non-zero renderer sync timing"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_queue_sample_count", 0)) > 0, "Runtime streaming diagnostics must record renderer queue phase samples"):
		return
	if not T.require_true(self, profile.has("update_streaming_renderer_sync_queue_prepare_avg_usec"), "Runtime streaming diagnostics must expose renderer queue prepare phase timing"):
		return
	if not T.require_true(self, profile.has("update_streaming_renderer_sync_queue_mount_avg_usec"), "Runtime streaming diagnostics must expose renderer queue mount phase timing"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_lod_sample_count", 0)) > 0, "Runtime streaming diagnostics must record renderer LOD phase samples"):
		return
	if not T.require_true(self, profile.has("update_streaming_renderer_sync_far_proxy_avg_usec"), "Runtime streaming diagnostics must expose renderer far proxy phase timing"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_crowd_sample_count", 0)) > 0, "Runtime streaming diagnostics must record renderer crowd phase samples"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_renderer_sync_traffic_sample_count", 0)) > 0, "Runtime streaming diagnostics must record renderer traffic phase samples"):
		return
	if not T.require_true(self, str(profile.get("crowd_assignment_decision", "")) != "", "Runtime streaming diagnostics must report the last crowd assignment decision"):
		return
	if not T.require_true(self, str(profile.get("crowd_assignment_rebuild_reason", "")) != "", "Runtime streaming diagnostics must report the last crowd assignment rebuild reason"):
		return
	if not T.require_true(self, float(profile.get("crowd_assignment_raw_player_velocity_mps", -1.0)) >= 0.0, "Runtime streaming diagnostics must report the raw crowd player velocity magnitude"):
		return
	if not T.require_true(self, float(profile.get("crowd_assignment_player_velocity_mps", -1.0)) >= 0.0, "Runtime streaming diagnostics must report the effective crowd player velocity magnitude"):
		return

	world.set_performance_diagnostics_enabled(false)
	world.queue_free()
	T.pass_and_quit(self)
