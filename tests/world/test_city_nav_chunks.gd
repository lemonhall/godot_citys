extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var nav_runtime_script := load("res://city_game/world/navigation/CityChunkNavRuntime.gd")
	if config_script == null:
		T.fail_and_quit(self, "Missing CityWorldConfig.gd")
		return
	if generator_script == null:
		T.fail_and_quit(self, "Missing CityWorldGenerator.gd")
		return
	if nav_runtime_script == null:
		T.fail_and_quit(self, "Missing CityChunkNavRuntime.gd")
		return

	var config = config_script.new()
	var world_data: Dictionary = generator_script.new().generate_world(config)
	var nav_runtime = nav_runtime_script.new(config, world_data)
	var left_chunk := Vector2i(13, 13)
	var right_chunk := Vector2i(14, 13)

	if not T.require_true(self, nav_runtime.are_adjacent_chunks_connected(left_chunk, right_chunk), "Adjacent chunks must be navigation-connected"):
		return

	var portals: Dictionary = nav_runtime.get_boundary_portals(left_chunk, right_chunk)
	if not T.require_true(self, portals.has("from_exit") and portals.has("to_entry"), "Boundary portals must expose from_exit and to_entry"):
		return
	if not T.require_true(self, portals["from_exit"].distance_to(portals["to_entry"]) <= 0.01, "Adjacent chunk portals must align on the shared border"):
		return

	T.pass_and_quit(self)
