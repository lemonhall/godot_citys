extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for minimap projection")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "CityPrototype must expose build_minimap_snapshot()"):
		return

	var snapshot: Dictionary = world.build_minimap_snapshot()
	if not T.require_true(self, snapshot.has("player_marker"), "Minimap snapshot must include player_marker"):
		return
	if not T.require_true(self, snapshot.has("road_polylines"), "Minimap snapshot must include road_polylines from shared road graph"):
		return
	if not T.require_true(self, (snapshot.get("road_polylines", []) as Array).size() > 0, "Minimap must render at least one road polyline in the default view"):
		return
	if not T.require_true(self, (snapshot.get("player_marker", {}) as Dictionary).has("position"), "Minimap player marker must expose 2D projected position"):
		return

	world.queue_free()
	T.pass_and_quit(self)
