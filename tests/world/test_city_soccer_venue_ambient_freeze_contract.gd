extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer venue ambient freeze contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer venue ambient freeze contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("is_ambient_simulation_frozen"), "Soccer venue ambient freeze contract requires is_ambient_simulation_frozen()"):
		return
	if not T.require_true(self, world.has_method("get_soccer_venue_runtime_state"), "Soccer venue ambient freeze contract requires get_soccer_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "Soccer venue ambient freeze contract requires get_pedestrian_runtime_snapshot()"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_runtime_snapshot"), "Soccer venue ambient freeze contract requires get_vehicle_runtime_snapshot()"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 1.2, 0.0))
	var runtime_state: Dictionary = await _wait_for_ambient_freeze(world, true)
	if not T.require_true(self, bool(runtime_state.get("ambient_simulation_frozen", false)), "Entering the soccer venue playable area must activate ambient_simulation_freeze"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Ambient freeze must not flip world_simulation_pause to true"):
		return

	var ped_runtime: Dictionary = world.get_pedestrian_runtime_snapshot()
	var veh_runtime: Dictionary = world.get_vehicle_runtime_snapshot()
	if not T.require_true(self, bool(ped_runtime.get("simulation_frozen", false)), "Ambient freeze contract must freeze the pedestrian simulation controller"):
		return
	if not T.require_true(self, bool(veh_runtime.get("simulation_frozen", false)), "Ambient freeze contract must freeze the ambient vehicle simulation controller"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_ambient_freeze(world, expected_state: bool) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if bool(runtime_state.get("ambient_simulation_frozen", false)) == expected_state and bool(world.is_ambient_simulation_frozen()) == expected_state:
			return runtime_state
	return world.get_soccer_venue_runtime_state()
