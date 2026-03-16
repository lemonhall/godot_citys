extends SceneTree

const OUTPUT_PATH := "user://debug/fountain_landmark_capture.png"
const FOUNTAIN_WORLD_POSITION := Vector3(-1848.0, 8.0, 1540.0)
const LOOK_TARGET := Vector3(-1848.0, 60.0, 1480.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		push_error("Missing CityPrototype.tscn")
		quit(1)
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if player == null or not player.has_method("teleport_to_world_position"):
		push_error("Missing Player teleport API")
		quit(1)
		return
	if world.has_method("set_control_mode"):
		world.set_control_mode("inspection")

	player.teleport_to_world_position(FOUNTAIN_WORLD_POSITION)
	for _frame in range(240):
		await process_frame
	if world.has_method("_snap_player_to_active_surface"):
		world.call("_snap_player_to_active_surface")
	for _frame in range(12):
		await process_frame
	player.look_at(LOOK_TARGET, Vector3.UP)
	for _frame in range(12):
		await process_frame

	var image := root.get_viewport().get_texture().get_image()
	var output_global := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(output_global.get_base_dir())
	var save_error := image.save_png(output_global)
	if save_error != OK:
		push_error("Failed to save capture: %s" % str(save_error))
		quit(1)
		return
	print("FOUNTAIN_CAPTURE %s" % output_global)
	quit()
