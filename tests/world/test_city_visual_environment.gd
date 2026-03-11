extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for visual environment")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var world_environment := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not T.require_true(self, world_environment != null, "CityPrototype must include WorldEnvironment"):
		return
	if not T.require_true(self, world_environment.environment != null, "WorldEnvironment must provide Environment resource"):
		return

	var environment := world_environment.environment
	if not T.require_true(self, environment.sky != null, "Environment must provide a sky resource"):
		return
	if not T.require_true(self, environment.fog_enabled, "Environment must enable fog for aerial perspective"):
		return
	if not T.require_true(self, environment.fog_aerial_perspective > 0.0, "Environment fog must affect distant sky/buildings"):
		return

	world.queue_free()
	T.pass_and_quit(self)
