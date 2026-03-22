extends SceneTree

const T := preload("res://tests/_test_util.gd")

const WATER_ENTRY_POINT := Vector3(2838.0, 0.8, 11510.0)
const UNDERWATER_POINT := Vector3(2838.0, -1.2, 11510.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for lake swim observer contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake swim observer contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_lake_player_water_state"), "Lake swim observer contract requires get_lake_player_water_state()"):
		return

	player.teleport_to_world_position(WATER_ENTRY_POINT)
	var water_state: Dictionary = await _wait_for_water_state(world, true)
	if not T.require_true(self, bool(water_state.get("in_water", false)), "Entering the lake must expose a formal in_water state"):
		return
	if not T.require_true(self, str(water_state.get("region_id", "")) == "region:v38:fishing_lake:chunk_147_181", "Lake water observer contract must report the formal region_id while in water"):
		return
	if not T.require_true(self, is_equal_approx(float(water_state.get("water_level_y_m", 999.0)), 0.0), "Lake water observer contract must report the stable water_level_y_m = 0.0"):
		return

	player.teleport_to_world_position(UNDERWATER_POINT)
	var underwater_state: Dictionary = await _wait_for_underwater_state(world)
	if not T.require_true(self, bool(underwater_state.get("underwater", false)), "Crossing below the lake surface must expose a formal underwater observation state"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_water_state(world, expected_state: bool) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var water_state: Dictionary = world.get_lake_player_water_state()
		if bool(water_state.get("in_water", false)) == expected_state:
			return water_state
	return world.get_lake_player_water_state()

func _wait_for_underwater_state(world) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var water_state: Dictionary = world.get_lake_player_water_state()
		if bool(water_state.get("underwater", false)):
			return water_state
	return world.get_lake_player_water_state()
