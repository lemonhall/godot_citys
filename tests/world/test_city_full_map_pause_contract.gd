extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for full map pause contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "CityPrototype must expose set_full_map_open() for v12 M4"):
		return
	if not T.require_true(self, world.has_method("is_full_map_open"), "CityPrototype must expose is_full_map_open() for v12 M4"):
		return
	if not T.require_true(self, world.has_method("is_world_simulation_paused"), "CityPrototype must expose is_world_simulation_paused() for v12 M4"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "CityPrototype must expose get_map_screen_state() for v12 M4"):
		return

	world.set_full_map_open(true)
	await process_frame

	var map_state: Dictionary = world.get_map_screen_state()
	if not T.require_true(self, world.is_full_map_open(), "Full map must report open after set_full_map_open(true)"):
		return
	if not T.require_true(self, world.is_world_simulation_paused(), "Opening the full map must pause 3D world simulation"):
		return
	if not T.require_true(self, bool(map_state.get("visible", false)), "Map screen must stay visible while the world is paused"):
		return
	if not T.require_true(self, bool(map_state.get("world_paused", false)), "Map screen state must surface the paused-world contract"):
		return
	if not T.require_true(self, (map_state.get("world_bounds", Rect2()) as Rect2).size.length() > 0.0, "Full map must cover the formal world bounds, not a chunk-local view"):
		return

	var player := world.get_node_or_null("Player")
	var renderer := world.get_node_or_null("ChunkRenderer")
	var generated_city := world.get_node_or_null("GeneratedCity")
	if not T.require_true(self, player != null and player.process_mode == Node.PROCESS_MODE_DISABLED, "Opening the full map must disable player simulation without pausing the whole tree"):
		return
	if not T.require_true(self, renderer != null and renderer.process_mode == Node.PROCESS_MODE_DISABLED, "Opening the full map must disable chunk renderer simulation"):
		return
	if not T.require_true(self, generated_city != null and generated_city.process_mode == Node.PROCESS_MODE_DISABLED, "Opening the full map must disable generated city simulation"):
		return

	world.set_full_map_open(false)
	await process_frame
	if not T.require_true(self, not world.is_full_map_open(), "Full map must close when set_full_map_open(false) is called"):
		return
	if not T.require_true(self, not world.is_world_simulation_paused(), "Closing the full map must resume 3D world simulation"):
		return

	world.queue_free()
	T.pass_and_quit(self)
