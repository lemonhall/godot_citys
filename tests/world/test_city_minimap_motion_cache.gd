extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LEGACY_STEP_M := 18.0
const TARGET_STEP_M := 64.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for minimap motion cache")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for minimap motion cache"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for minimap motion cache"):
		return
	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "CityPrototype must expose build_minimap_snapshot()"):
		return
	if not T.require_true(self, world.has_method("get_minimap_cache_stats"), "CityPrototype must expose get_minimap_cache_stats()"):
		return

	world.build_minimap_snapshot()
	var stats_after_first: Dictionary = world.get_minimap_cache_stats()
	var delta_x := _find_cache_test_delta(player.global_position.x)
	if not T.require_true(self, delta_x != 0.0, "Test setup must find a delta that crosses legacy minimap buckets without crossing the target bucket"):
		return

	var moved_position: Vector3 = player.global_position + Vector3(delta_x, 0.0, 0.0)
	player.teleport_to_world_position(moved_position)
	world.build_minimap_snapshot()
	var stats_after_move: Dictionary = world.get_minimap_cache_stats()

	if not T.require_true(self, int(stats_after_move.get("hit_count", 0)) > int(stats_after_first.get("hit_count", 0)), "Small player motion inside the same coarse minimap bucket should hit cache instead of rebuilding the road base"):
		return
	if not T.require_true(self, int(stats_after_move.get("rebuild_count", 0)) == int(stats_after_first.get("rebuild_count", 0)), "Small player motion inside one coarse minimap bucket must not rebuild the road base"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _find_cache_test_delta(start_x: float) -> float:
	for candidate in range(4, 32):
		var delta := float(candidate)
		if _bucket_index(start_x, LEGACY_STEP_M) == _bucket_index(start_x + delta, LEGACY_STEP_M):
			continue
		if _bucket_index(start_x, TARGET_STEP_M) != _bucket_index(start_x + delta, TARGET_STEP_M):
			continue
		return delta
	return 0.0

func _bucket_index(value: float, step_m: float) -> int:
	return int(round(value / step_m))
