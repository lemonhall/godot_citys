extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for minimap cache")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "CityPrototype must expose build_minimap_snapshot()"):
		return
	if not T.require_true(self, world.has_method("get_minimap_cache_stats"), "CityPrototype must expose get_minimap_cache_stats()"):
		return

	world.build_minimap_snapshot()
	var stats_after_first: Dictionary = world.get_minimap_cache_stats()
	world.build_minimap_snapshot()
	var stats_after_second: Dictionary = world.get_minimap_cache_stats()

	if not T.require_true(self, int(stats_after_first.get("miss_count", 0)) >= 1, "First minimap snapshot should register a cache miss"):
		return
	if not T.require_true(self, int(stats_after_second.get("hit_count", 0)) >= 1, "Second identical minimap snapshot should register a cache hit"):
		return
	if not T.require_true(self, int(stats_after_second.get("rebuild_count", 0)) == int(stats_after_first.get("rebuild_count", 0)), "Identical minimap requests must not rebuild the road snapshot twice"):
		return

	world.queue_free()
	T.pass_and_quit(self)
