extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for fast travel map flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	var origin_position: Vector3 = player.global_position if player != null else Vector3.ZERO

	world.set_full_map_open(true)
	await process_frame
	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(1400.0, 0.0, 26.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Fast travel map flow must select a destination from the full map before teleporting"):
		return

	var fast_travel_result: Dictionary = world.fast_travel_to_active_destination()
	if not T.require_true(self, bool(fast_travel_result.get("success", false)), "Fast travel map flow must successfully resolve and teleport to the active destination"):
		return

	world.set_full_map_open(false)
	await process_frame
	if not T.require_true(self, not world.is_full_map_open(), "Fast travel map flow must close the full map after teleporting"):
		return
	if not T.require_true(self, player != null and origin_position.distance_to(player.global_position) >= 400.0, "Fast travel map flow must materially move the player across the city"):
		return
	if not T.require_true(self, not world.get_active_route_result().is_empty(), "Fast travel map flow must keep the active route contract available after teleport"):
		return

	world.queue_free()
	T.pass_and_quit(self)
