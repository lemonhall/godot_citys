extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for navigation flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("plan_macro_route"), "CityPrototype must expose plan_macro_route()"):
		return
	if not T.require_true(self, world.has_method("plan_route_result"), "CityPrototype must expose plan_route_result() for v12 navigation"):
		return

	var start := Vector3(-1400.0, 1.1, 26.0)
	var goal := Vector3(1400.0, 1.1, 26.0)
	var route_result: Dictionary = world.plan_route_result(start, goal, 0)
	if not T.require_true(self, not route_result.is_empty(), "Navigation flow must return a formal route_result"):
		return
	if not T.require_true(self, (route_result.get("polyline", []) as Array).size() >= 2, "Navigation flow route_result must expose a world polyline"):
		return
	if not T.require_true(self, (route_result.get("steps", []) as Array).size() >= 4, "Long cross-city navigation must yield multiple route steps"):
		return
	if not T.require_true(self, (route_result.get("maneuvers", []) as Array).size() >= 2, "Navigation flow must expose formal maneuvers instead of chunk-only hints"):
		return

	world.queue_free()
	T.pass_and_quit(self)
