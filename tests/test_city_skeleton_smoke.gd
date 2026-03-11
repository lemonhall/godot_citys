extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://city_game/scenes/CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	if world == null:
		T.fail_and_quit(self, "Failed to instantiate CityPrototype.tscn")
		return

	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.name == "CityPrototype", "Root node must be named CityPrototype"):
		return
	if not T.require_true(self, world.get_node_or_null("GeneratedCity") != null, "Missing node CityPrototype/GeneratedCity"):
		return
	if not T.require_true(self, world.get_node_or_null("Player") != null, "Missing node CityPrototype/Player"):
		return
	if not T.require_true(self, world.get_node_or_null("Player/CameraRig") != null, "Missing node CityPrototype/Player/CameraRig"):
		return
	if not T.require_true(self, world.get_node_or_null("Hud") != null, "Missing node CityPrototype/Hud"):
		return

	var city := world.get_node("GeneratedCity")
	if not T.require_true(self, city.has_method("get_block_count"), "GeneratedCity must expose get_block_count()"):
		return
	if not T.require_true(self, city.get_block_count() > 0, "GeneratedCity must generate at least one block"):
		return

	var hud := world.get_node("Hud")
	if not T.require_true(self, hud.has_method("set_status"), "Hud must expose set_status()"):
		return

	world.queue_free()
	T.pass_and_quit(self)
