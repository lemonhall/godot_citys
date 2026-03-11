extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for minimap route overlay")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("build_minimap_route_overlay"), "CityPrototype must expose build_minimap_route_overlay()"):
		return

	var overlay: Dictionary = world.build_minimap_route_overlay(Vector3(-1400.0, 1.1, 26.0), Vector3(1400.0, 1.1, 26.0))
	if not T.require_true(self, overlay.has("polyline"), "Minimap route overlay must expose polyline points"):
		return
	if not T.require_true(self, (overlay.get("polyline", []) as Array).size() >= 2, "Minimap route overlay must contain at least start/end projected points"):
		return
	if not T.require_true(self, overlay.has("start_marker"), "Minimap route overlay must expose start_marker"):
		return
	if not T.require_true(self, overlay.has("goal_marker"), "Minimap route overlay must expose goal_marker"):
		return

	world.queue_free()
	T.pass_and_quit(self)
