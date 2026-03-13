extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian crowd breakdown profiling")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_performance_profile"), "CityPrototype must expose get_performance_profile() for pedestrian crowd breakdown profiling"):
		return
	if not T.require_true(self, world.has_method("reset_performance_profile"), "CityPrototype must expose reset_performance_profile() for pedestrian crowd breakdown profiling"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Pedestrian crowd breakdown profiling requires Player node"):
		return
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "PlayerController must expose advance_toward_world_position() for pedestrian crowd breakdown profiling"):
		return

	world.reset_performance_profile()
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	var target_position := Vector3(512.0, player.global_position.y, 96.0)
	for _step in range(12):
		player.advance_toward_world_position(target_position, 24.0)
		await process_frame

	var profile: Dictionary = world.get_performance_profile()
	print("CITY_PEDESTRIAN_CROWD_BREAKDOWN %s" % JSON.stringify(profile))

	for required_key in [
		"crowd_active_state_count",
		"crowd_step_usec",
		"crowd_reaction_usec",
		"crowd_rank_usec",
		"crowd_snapshot_rebuild_usec",
		"crowd_chunk_commit_usec",
		"crowd_tier1_transform_writes",
	]:
		if not T.require_true(self, profile.has(required_key), "Pedestrian crowd breakdown profile must expose %s" % required_key):
			return

	if not T.require_true(self, int(profile.get("crowd_active_state_count", 0)) > 0, "Pedestrian crowd breakdown profile must report at least one active state"):
		return
	if not T.require_true(self, int(profile.get("crowd_chunk_commit_usec", 0)) > 0, "Pedestrian crowd breakdown profile must measure chunk commit time"):
		return
	if not T.require_true(self, int(profile.get("crowd_tier1_transform_writes", -1)) >= 0, "Pedestrian crowd breakdown profile must report Tier 1 transform write counts"):
		return

	world.queue_free()
	T.pass_and_quit(self)
