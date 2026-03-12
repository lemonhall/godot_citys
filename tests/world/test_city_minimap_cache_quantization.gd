extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for minimap cache quantization")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "CityPrototype must expose build_minimap_snapshot()"):
		return
	if not T.require_true(self, world.has_method("get_minimap_cache_stats"), "CityPrototype must expose get_minimap_cache_stats()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for minimap cache quantization"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must support teleport_to_world_position() for minimap cache quantization"):
		return

	world.build_minimap_snapshot()
	var initial_stats: Dictionary = world.get_minimap_cache_stats()
	var moved_position: Vector3 = player.global_position + Vector3(48.0, 0.0, 0.0)
	player.teleport_to_world_position(moved_position)
	world.build_minimap_snapshot()
	var moved_stats: Dictionary = world.get_minimap_cache_stats()

	if not T.require_true(self, int(initial_stats.get("rebuild_count", 0)) == 1, "First minimap snapshot should rebuild exactly once"):
		return
	if not T.require_true(self, int(moved_stats.get("rebuild_count", 0)) == 1, "Small player movement within one minimap quantization cell must reuse the cached road snapshot"):
		return
	if not T.require_true(self, int(moved_stats.get("hit_count", 0)) >= 1, "Small player movement should hit the minimap cache instead of repainting the same roads"):
		return

	world.queue_free()
	T.pass_and_quit(self)
