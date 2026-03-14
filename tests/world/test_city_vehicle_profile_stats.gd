extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle profile stats")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "CityPrototype must expose get_performance_profile() for vehicle profile stats"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "CityPrototype must expose reset_performance_profile() for vehicle profile stats"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_runtime_snapshot"), "CityPrototype must expose get_vehicle_runtime_snapshot() for vehicle profile stats"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Vehicle profile stats require Player node"):
		return
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "PlayerController must expose advance_toward_world_position() for vehicle profile stats"):
		return

	world.reset_performance_profile()
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var target_position := Vector3(512.0, player.global_position.y, 96.0)
	for _step in range(12):
		player.advance_toward_world_position(target_position, 24.0)
		await process_frame

	var profile: Dictionary = world.get_performance_profile()
	for required_key in [
		"vehicle_mode",
		"traffic_update_avg_usec",
		"traffic_spawn_avg_usec",
		"traffic_render_commit_avg_usec",
		"traffic_active_state_count",
		"veh_tier0_count",
		"veh_tier1_count",
		"veh_tier2_count",
		"veh_tier3_count",
		"veh_page_cache_hit_count",
		"veh_page_cache_miss_count",
	]:
		if not T.require_true(self, profile.has(required_key), "Vehicle performance profile must expose %s" % required_key):
			return

	if not T.require_true(self, str(profile.get("vehicle_mode", "")) == "lite", "Vehicle profile stats must report the lite vehicle mode"):
		return

	var visible_vehicle_count := int(profile.get("veh_tier0_count", 0)) + int(profile.get("veh_tier1_count", 0)) + int(profile.get("veh_tier2_count", 0)) + int(profile.get("veh_tier3_count", 0))
	if not T.require_true(self, visible_vehicle_count > 0, "Vehicle profile stats must report at least one resident vehicle while the city is active"):
		return

	world.queue_free()
	T.pass_and_quit(self)
