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

	var start := Vector3(-1400.0, 1.1, 26.0)
	var goal := Vector3(1400.0, 1.1, 26.0)
	var route: Array = world.plan_macro_route(start, goal)
	if not T.require_true(self, route.size() >= 8, "Macro route must decompose into at least 8 chunk-level targets"):
		return

	for index in range(1, route.size()):
		var prev_chunk_key: Vector2i = route[index - 1]["chunk_key"]
		var next_chunk_key: Vector2i = route[index]["chunk_key"]
		var manhattan := absi(prev_chunk_key.x - next_chunk_key.x) + absi(prev_chunk_key.y - next_chunk_key.y)
		if not T.require_true(self, manhattan <= 1, "Macro route must move one chunk at a time"):
			return

	world.queue_free()
	T.pass_and_quit(self)
