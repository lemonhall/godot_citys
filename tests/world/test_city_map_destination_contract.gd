extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for map destination contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("select_map_destination_from_world_point"), "CityPrototype must expose select_map_destination_from_world_point() for v12 M4"):
		return
	if not T.require_true(self, world.has_method("get_last_map_selection_contract"), "CityPrototype must expose get_last_map_selection_contract() for v12 M4"):
		return
	if not T.require_true(self, world.has_method("get_active_route_result"), "CityPrototype must expose get_active_route_result() for v12 M4"):
		return

	var selection_world_point := Vector3(1400.0, 0.0, 26.0)
	var selection_contract: Dictionary = world.select_map_destination_from_world_point(selection_world_point)
	if not T.require_true(self, not selection_contract.is_empty(), "Map selection must return a formal destination contract"):
		return
	for required_key in ["selection_mode", "raw_world_anchor", "resolved_target", "route_request_target"]:
		if not T.require_true(self, selection_contract.has(required_key), "Map selection contract must expose %s" % required_key):
			return

	var resolved_target: Dictionary = selection_contract.get("resolved_target", {})
	var route_request_target: Dictionary = selection_contract.get("route_request_target", {})
	if not T.require_true(self, not resolved_target.is_empty(), "Map selection must resolve the clicked world point into a formal resolved_target"):
		return
	if not T.require_true(self, not route_request_target.is_empty(), "Map selection must expose a formal route_request_target"):
		return
	if not T.require_true(self, str(selection_contract.get("selection_mode", "")) == "map_world_point", "Map selection must freeze the selection_mode contract for full map clicks"):
		return

	var last_selection: Dictionary = world.get_last_map_selection_contract()
	if not T.require_true(self, str((last_selection.get("resolved_target", {}) as Dictionary).get("source_kind", "")) != "", "CityPrototype must keep the last formal map selection contract available to consumers"):
		return
	var route_result: Dictionary = world.get_active_route_result()
	if not T.require_true(self, not route_result.is_empty(), "Selecting a map destination must immediately produce an active route_result"):
		return
	if not T.require_true(self, (route_result.get("polyline", []) as Array).size() >= 2, "Map destination selection must create a route_result polyline for HUD/minimap consumers"):
		return

	world.queue_free()
	T.pass_and_quit(self)
