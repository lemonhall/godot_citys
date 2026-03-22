extends SceneTree

const T := preload("res://tests/_test_util.gd")

const WATER_ENTRY_POINT := Vector3(2838.0, 3.4, 11510.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for lake main-world water traversal contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake main-world water traversal contract requires Player teleport support"):
		return
	if not T.require_true(self, player.has_method("set_water_vertical_input"), "Lake main-world water traversal contract requires synthetic water vertical input support"):
		return
	if not T.require_true(self, player.has_method("clear_water_vertical_input"), "Lake main-world water traversal contract requires synthetic water vertical input cleanup"):
		return
	if not T.require_true(self, world.has_method("get_lake_player_water_state"), "Lake main-world water traversal contract requires get_lake_player_water_state()"):
		return

	player.teleport_to_world_position(WATER_ENTRY_POINT)
	var underwater_state: Dictionary = await _wait_for_submerged_state(world, -0.35)
	if not T.require_true(self, bool(underwater_state.get("underwater", false)), "Jumping into the main-world lake must naturally carry the player below the waterline instead of leaving them standing on a fake water top"):
		return
	if not T.require_true(self, player.global_position.y < float(underwater_state.get("water_level_y_m", 0.0)) - 0.35, "Main-world lake traversal contract must let the player sink measurably below the surface under water drag"):
		return

	var submerged_y := player.global_position.y
	player.set_water_vertical_input(1.0)
	await _settle_frames(36)
	player.clear_water_vertical_input()
	if not T.require_true(self, player.global_position.y >= submerged_y + 0.35, "Main-world lake traversal contract must let Space-style upward input lift the player instead of pinning them underwater"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_submerged_state(world, min_depth_y: float) -> Dictionary:
	for _frame in range(160):
		await physics_frame
		await process_frame
		var water_state: Dictionary = world.get_lake_player_water_state()
		if bool(water_state.get("underwater", false)) and float(water_state.get("world_position", Vector3.ZERO).y) <= min_depth_y:
			return water_state
	return world.get_lake_player_water_state()

func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame
		await process_frame
