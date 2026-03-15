extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for full-map pan/zoom contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	world.set_full_map_open(true)
	await process_frame

	var full_map := world.get_node_or_null("Hud/Root/FullMap") as Control
	if not T.require_true(self, full_map != null, "Full-map pan/zoom contract requires a mounted FullMap control"):
		return

	var initial_state: Dictionary = world.get_map_screen_state()
	var initial_half_extent_x_m := float(initial_state.get("view_half_extent_x_m", 0.0))
	var initial_center: Vector2 = initial_state.get("view_center_world", Vector2.ZERO)
	if not T.require_true(self, initial_half_extent_x_m > 0.0, "Full map must expose a positive initial world half-extent for zoom control"):
		return

	var wheel_in := InputEventMouseButton.new()
	wheel_in.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_in.pressed = true
	wheel_in.position = full_map.size * 0.5
	full_map._gui_input(wheel_in)
	await process_frame

	var zoomed_state: Dictionary = world.get_map_screen_state()
	if not T.require_true(self, float(zoomed_state.get("view_half_extent_x_m", initial_half_extent_x_m)) < initial_half_extent_x_m, "Mouse wheel zoom-in must shrink the visible world span"):
		return

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = full_map.size * 0.5
	full_map._gui_input(press)

	var drag_delta := Vector2(96.0, 48.0)
	var motion := InputEventMouseMotion.new()
	motion.position = press.position + drag_delta
	motion.relative = drag_delta
	full_map._gui_input(motion)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	full_map._gui_input(release)
	await process_frame

	var panned_state: Dictionary = world.get_map_screen_state()
	var panned_center: Vector2 = panned_state.get("view_center_world", Vector2.ZERO)
	if not T.require_true(self, panned_center.distance_to(initial_center) > 1.0, "Dragging the full map must pan the visible world center"):
		return
	if not T.require_true(self, world.get_last_map_selection_contract().is_empty(), "Dragging the full map must not misfire into a destination selection"):
		return

	world.queue_free()
	T.pass_and_quit(self)
