extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Destination world marker refresh reuse requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("select_map_destination_from_world_point"), "Destination world marker refresh reuse requires manual destination selection support"):
		return
	if not T.require_true(self, world.has_method("get_destination_world_marker_debug_state"), "Destination world marker refresh reuse requires destination marker debug state access"):
		return

	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(1400.0, 0.0, 26.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Destination world marker refresh reuse requires a valid manual destination"):
		return

	for _frame_index in range(6):
		await physics_frame
		await process_frame

	var debug_state: Dictionary = world.get_destination_world_marker_debug_state()
	if not T.require_true(self, int(debug_state.get("surface_resolve_count", 9999)) == 1, "Unchanged manual destination routes must reuse the cached destination world marker placement instead of re-sampling the ground every frame"):
		return

	world.queue_free()
	T.pass_and_quit(self)
