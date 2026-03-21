extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for first-visit profiling")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "CityPrototype must expose get_performance_profile()"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "CityPrototype must expose reset_performance_profile()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for first-visit profiling"):
		return
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "PlayerController must support advance_toward_world_position() for first-visit profiling"):
		return

	world.reset_performance_profile()
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var target_position := Vector3(2048.0, player.global_position.y, 768.0)
	var wall_frame_samples: Array[int] = []
	for step in range(48):
		player.advance_toward_world_position(target_position, 24.0)
		var frame_started := Time.get_ticks_usec()
		await process_frame
		var frame_usec := Time.get_ticks_usec() - frame_started
		wall_frame_samples.append(frame_usec)
		print("CITY_FIRST_VISIT_FRAME step=%d frame_usec=%d" % [step, frame_usec])

	var profile: Dictionary = world.get_performance_profile()
	profile["wall_frame_avg_usec"] = _average_usec(wall_frame_samples)
	profile["wall_frame_max_usec"] = _max_usec(wall_frame_samples)
	profile["wall_frame_sample_count"] = wall_frame_samples.size()
	print("CITY_FIRST_VISIT_REPORT %s" % JSON.stringify(profile))

	if not T.require_true(self, int(profile.get("update_streaming_sample_count", 0)) > 0, "First-visit profile must include update_streaming samples"):
		return
	if not T.require_true(self, profile.has("streaming_terrain_async_complete_sample_count"), "First-visit profile must still expose terrain async completion fields for regression accounting"):
		return
	if not T.require_true(self, int(profile.get("streaming_terrain_async_complete_sample_count", 0)) == 0, "Flat-ground first-visit traversal must not depend on terrain async completion"):
		return
	if not T.require_true(self, int(profile.get("streaming_terrain_commit_sample_count", 0)) == 0, "Flat-ground first-visit traversal must not record terrain commit samples"):
		return
	if not T.require_true(self, int(profile.get("streaming_mount_setup_avg_usec", 0)) <= 5500, "M4 first-visit profile must keep mount setup average at or below 5500 usec"):
		return
	if not T.require_true(self, int(profile.get("update_streaming_avg_usec", 0)) <= 14500, "M4 first-visit profile must keep update_streaming average at or below 14500 usec"):
		return
	if not T.require_true(self, int(profile.get("wall_frame_avg_usec", 0)) <= 16667, "First-visit traversal must keep average wall-frame time at or below the 16.67ms redline"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _average_usec(samples: Array[int]) -> int:
	if samples.is_empty():
		return 0
	var total := 0
	for sample in samples:
		total += sample
	return int(round(float(total) / float(samples.size())))

func _max_usec(samples: Array[int]) -> int:
	var current_max := 0
	for sample in samples:
		current_max = maxi(current_max, sample)
	return current_max
