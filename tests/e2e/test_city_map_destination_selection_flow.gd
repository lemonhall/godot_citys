extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for map destination selection flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "CityPrototype must expose set_full_map_open() for map selection flow"):
		return
	if not T.require_true(self, world.has_method("select_map_destination_from_world_point"), "CityPrototype must expose select_map_destination_from_world_point() for map selection flow"):
		return
	if not T.require_true(self, world.has_method("get_active_route_result"), "CityPrototype must expose get_active_route_result() for map selection flow"):
		return

	world.set_full_map_open(true)
	await process_frame
	if not T.require_true(self, world.is_full_map_open(), "Map destination selection flow must open the full map before choosing a destination"):
		return

	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(1400.0, 0.0, 26.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Map destination selection flow must allow destination selection while the world is paused"):
		return
	var route_id := str(world.get_active_route_result().get("route_id", ""))
	if not T.require_true(self, route_id != "", "Map destination selection flow must keep the planned route active immediately after selection"):
		return

	world.set_full_map_open(false)
	await process_frame
	if not T.require_true(self, not world.is_full_map_open(), "Map destination selection flow must close the full map after selection"):
		return
	if not T.require_true(self, not world.is_world_simulation_paused(), "Map destination selection flow must resume the world after closing the map"):
		return
	if not T.require_true(self, str(world.get_active_route_result().get("route_id", "")) == route_id, "Closing the full map must not discard the active route"):
		return

	world.queue_free()
	T.pass_and_quit(self)
