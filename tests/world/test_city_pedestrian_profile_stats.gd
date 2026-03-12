extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian profile stats")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "CityPrototype must expose get_performance_profile() for pedestrian profile stats"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "CityPrototype must expose reset_performance_profile() for pedestrian profile stats"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Pedestrian profile stats require Player node"):
		return
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "PlayerController must expose advance_toward_world_position() for pedestrian profile stats"):
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
		"pedestrian_mode",
		"crowd_update_avg_usec",
		"crowd_spawn_avg_usec",
		"crowd_render_commit_avg_usec",
		"ped_tier0_count",
		"ped_tier1_count",
		"ped_tier2_count",
		"ped_tier3_count",
		"ped_page_cache_hit_count",
		"ped_page_cache_miss_count",
	]:
		if not T.require_true(self, profile.has(required_key), "Pedestrian performance profile must expose %s" % required_key):
			return

	if not T.require_true(self, str(profile.get("pedestrian_mode", "")) == "lite", "Pedestrian profile stats must report the lite pedestrian mode"):
		return

	var visible_pedestrian_count := int(profile.get("ped_tier0_count", 0)) + int(profile.get("ped_tier1_count", 0)) + int(profile.get("ped_tier2_count", 0)) + int(profile.get("ped_tier3_count", 0))
	if not T.require_true(self, visible_pedestrian_count > 0, "Pedestrian profile stats must report at least one resident pedestrian while the city is active"):
		return

	world.queue_free()
	T.pass_and_quit(self)
