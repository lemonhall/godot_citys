extends SceneTree

const T := preload("res://tests/_test_util.gd")
const STREAMING_IDLE_STABLE_FRAMES := 4
const STREAMING_IDLE_MAX_FRAMES := 180

const WARM_TRAFFIC_UPDATE_AVG_MAX_USEC := 3500
const WARM_TRAFFIC_SPAWN_AVG_MAX_USEC := 1500
const WARM_TRAFFIC_RENDER_COMMIT_AVG_MAX_USEC := 1200

const FIRST_VISIT_TRAFFIC_UPDATE_AVG_MAX_USEC := 5500
const FIRST_VISIT_TRAFFIC_SPAWN_AVG_MAX_USEC := 4000
const FIRST_VISIT_TRAFFIC_RENDER_COMMIT_AVG_MAX_USEC := 1200

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var warm_profile := await _capture_warm_vehicle_profile()
	if warm_profile.is_empty():
		return
	print("CITY_VEHICLE_WARM_PROFILE %s" % JSON.stringify(warm_profile))
	if not _verify_required_vehicle_profile_fields(warm_profile, "warm"):
		return
	if not T.require_true(self, int(warm_profile.get("traffic_update_avg_usec", 0)) <= WARM_TRAFFIC_UPDATE_AVG_MAX_USEC, "Warm vehicle profile must keep traffic_update_avg_usec within the lite runtime budget"):
		return
	if not T.require_true(self, int(warm_profile.get("traffic_spawn_avg_usec", 0)) <= WARM_TRAFFIC_SPAWN_AVG_MAX_USEC, "Warm vehicle profile must keep traffic_spawn_avg_usec within the lite runtime budget"):
		return
	if not T.require_true(self, int(warm_profile.get("traffic_render_commit_avg_usec", 0)) <= WARM_TRAFFIC_RENDER_COMMIT_AVG_MAX_USEC, "Warm vehicle profile must keep traffic_render_commit_avg_usec within the lite runtime budget"):
		return
	if not T.require_true(self, _visible_vehicle_count(warm_profile) >= 4, "Warm vehicle profile must keep at least four visible vehicles resident in the active city window"):
		return

	var first_visit_profile := await _capture_first_visit_vehicle_profile()
	if first_visit_profile.is_empty():
		return
	print("CITY_VEHICLE_FIRST_VISIT_PROFILE %s" % JSON.stringify(first_visit_profile))
	if not _verify_required_vehicle_profile_fields(first_visit_profile, "first-visit"):
		return
	if not T.require_true(self, int(first_visit_profile.get("traffic_update_avg_usec", 0)) <= FIRST_VISIT_TRAFFIC_UPDATE_AVG_MAX_USEC, "First-visit vehicle profile must keep traffic_update_avg_usec within the lite traversal budget"):
		return
	if not T.require_true(self, int(first_visit_profile.get("traffic_spawn_avg_usec", 0)) <= FIRST_VISIT_TRAFFIC_SPAWN_AVG_MAX_USEC, "First-visit vehicle profile must keep traffic_spawn_avg_usec within the lite traversal budget"):
		return
	if not T.require_true(self, int(first_visit_profile.get("traffic_render_commit_avg_usec", 0)) <= FIRST_VISIT_TRAFFIC_RENDER_COMMIT_AVG_MAX_USEC, "First-visit vehicle profile must keep traffic_render_commit_avg_usec within the lite traversal budget"):
		return
	if not T.require_true(self, _visible_vehicle_count(first_visit_profile) >= 4, "First-visit vehicle profile must keep at least four visible vehicles resident in the active traversal window"):
		return

	T.pass_and_quit(self)

func _capture_warm_vehicle_profile() -> Dictionary:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for warm vehicle profiling")
		return {}

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not _validate_vehicle_profile_world(world):
		return {}
	var player = world.get_node_or_null("Player")
	if not _validate_vehicle_profile_player(player):
		return {}

	world.build_minimap_snapshot()
	world.build_minimap_snapshot()
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")
	if not await _wait_for_streaming_idle(world):
		T.fail_and_quit(self, "Warm vehicle profiling could not reach a stable idle streaming window before sampling")
		return {}

	var start_position: Vector3 = player.global_position
	var target_position := Vector3(768.0, player.global_position.y, 26.0)
	if not await _prime_warm_traversal(world, player, start_position, target_position, 16.0):
		T.fail_and_quit(self, "Warm vehicle profiling could not stabilize the traversal corridor before sampling")
		return {}

	world.reset_performance_profile()
	for _step in range(48):
		player.advance_toward_world_position(target_position, 16.0)
		await process_frame

	var profile: Dictionary = world.get_performance_profile()
	world.queue_free()
	await process_frame
	return profile

func _capture_first_visit_vehicle_profile() -> Dictionary:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for first-visit vehicle profiling")
		return {}

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not _validate_vehicle_profile_world(world):
		return {}
	var player = world.get_node_or_null("Player")
	if not _validate_vehicle_profile_player(player):
		return {}

	world.reset_performance_profile()
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var target_position := Vector3(2048.0, player.global_position.y, 768.0)
	for _step in range(48):
		player.advance_toward_world_position(target_position, 24.0)
		await process_frame

	var profile: Dictionary = world.get_performance_profile()
	world.queue_free()
	await process_frame
	return profile

func _validate_vehicle_profile_world(world) -> bool:
	if not T.require_true(self, world.has_method("get_performance_profile"), "CityPrototype must expose get_performance_profile() for vehicle profiling"):
		return false
	if not T.require_true(self, world.has_method("reset_performance_profile"), "CityPrototype must expose reset_performance_profile() for vehicle profiling"):
		return false
	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "CityPrototype must expose get_streaming_snapshot() for vehicle profiling"):
		return false
	return true

func _validate_vehicle_profile_player(player) -> bool:
	if not T.require_true(self, player != null, "Vehicle profiling requires Player node"):
		return false
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must support teleport_to_world_position() for vehicle profiling"):
		return false
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "PlayerController must support advance_toward_world_position() for vehicle profiling"):
		return false
	return true

func _verify_required_vehicle_profile_fields(profile: Dictionary, phase_name: String) -> bool:
	for required_key in [
		"vehicle_mode",
		"traffic_update_avg_usec",
		"traffic_update_sample_count",
		"traffic_spawn_avg_usec",
		"traffic_spawn_sample_count",
		"traffic_render_commit_avg_usec",
		"traffic_render_commit_sample_count",
		"traffic_active_state_count",
		"traffic_tier1_count",
		"traffic_tier2_count",
		"veh_tier0_count",
		"veh_tier1_count",
		"veh_tier2_count",
		"veh_tier3_count",
	]:
		if not T.require_true(self, profile.has(required_key), "%s vehicle profile must expose %s" % [phase_name, required_key]):
			return false
	if not T.require_true(self, str(profile.get("vehicle_mode", "")) == "lite", "%s vehicle profile must report lite vehicle mode" % phase_name.capitalize()):
		return false
	if not T.require_true(self, int(profile.get("traffic_update_sample_count", 0)) > 0, "%s vehicle profile must record traffic update samples" % phase_name.capitalize()):
		return false
	if not T.require_true(self, int(profile.get("traffic_spawn_sample_count", 0)) > 0, "%s vehicle profile must record traffic spawn samples" % phase_name.capitalize()):
		return false
	if not T.require_true(self, int(profile.get("traffic_render_commit_sample_count", 0)) > 0, "%s vehicle profile must record traffic render commit samples" % phase_name.capitalize()):
		return false
	return T.require_true(self, int(profile.get("traffic_active_state_count", 0)) > 0, "%s vehicle profile must keep active traffic state counts above zero during travel" % phase_name.capitalize())

func _visible_vehicle_count(profile: Dictionary) -> int:
	return (
		int(profile.get("veh_tier1_count", 0))
		+ int(profile.get("veh_tier2_count", 0))
		+ int(profile.get("veh_tier3_count", 0))
	)

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

func _prime_warm_traversal(world, player, start_position: Vector3, target_position: Vector3, step_distance: float) -> bool:
	for _step in range(48):
		player.advance_toward_world_position(target_position, step_distance)
		await process_frame
	if not await _wait_for_streaming_idle(world):
		return false
	player.teleport_to_world_position(start_position)
	world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
	return await _wait_for_streaming_idle(world)
