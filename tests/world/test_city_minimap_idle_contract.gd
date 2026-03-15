extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for idle minimap contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var route_overlay: Dictionary = minimap_snapshot.get("route_overlay", {})
	var pin_overlay: Dictionary = minimap_snapshot.get("pin_overlay", {})
	if not T.require_true(self, route_overlay.is_empty(), "Idle minimap must not render a route overlay before any destination is selected"):
		return
	if not T.require_true(self, int(pin_overlay.get("pin_count", -1)) == 0, "Idle minimap must not render blue pin markers before navigation or task pins are explicitly created"):
		return

	world.queue_free()
	T.pass_and_quit(self)
