extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/LakeFishingLab.tscn"
const WATER_ENTRY_POINT := Vector3(4.0, 3.4, -36.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Lake lab water traversal contract requires LakeFishingLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake lab water traversal contract requires Player teleport support"):
		return
	if not T.require_true(self, player.has_method("set_water_vertical_input"), "Lake lab water traversal contract requires synthetic water vertical input support"):
		return
	if not T.require_true(self, player.has_method("clear_water_vertical_input"), "Lake lab water traversal contract requires synthetic water vertical input cleanup"):
		return

	player.teleport_to_world_position(WATER_ENTRY_POINT)
	var underwater_state: Dictionary = await _wait_for_submerged_state(lab, -0.35)
	if not T.require_true(self, bool(underwater_state.get("underwater", false)), "Jumping into the lake must naturally carry the player below the waterline instead of leaving them standing on a fake water top"):
		return
	if not T.require_true(self, player.global_position.y < float(underwater_state.get("water_level_y_m", 0.0)) - 0.35, "Lake lab water traversal contract must let the player sink measurably below the surface under water drag"):
		return

	var submerged_y := player.global_position.y
	player.set_water_vertical_input(1.0)
	await _settle_frames(36)
	player.clear_water_vertical_input()
	if not T.require_true(self, player.global_position.y >= submerged_y + 0.35, "Water traversal must let Space-style upward input lift the player instead of pinning them to the lake floor"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_submerged_state(lab, min_depth_y: float) -> Dictionary:
	for _frame in range(160):
		await physics_frame
		await process_frame
		var water_state: Dictionary = lab.get_lake_player_water_state()
		if bool(water_state.get("underwater", false)) and float(water_state.get("world_position", Vector3.ZERO).y) <= min_depth_y:
			return water_state
	return lab.get_lake_player_water_state()

func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame
		await process_frame
