extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for controls help overlay contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_controls_help_state"), "Controls help overlay contract requires HUD state introspection"):
		return
	if not T.require_true(self, world.has_method("is_world_simulation_paused"), "Controls help overlay contract requires pause state introspection"):
		return
	if not T.require_true(self, world.has_method("is_controls_help_open"), "Controls help overlay contract requires controls-help open state introspection"):
		return

	var help_overlay := world.get_node_or_null("Hud/Root/ControlsHelp") as Control
	if not T.require_true(self, help_overlay != null, "Controls help overlay contract requires a dedicated ControlsHelp control under the HUD"):
		return

	_press_key(world, KEY_F1)
	await process_frame

	var help_state: Dictionary = hud.get_controls_help_state()
	if not T.require_true(self, world.is_controls_help_open(), "Pressing F1 must open the controls help overlay"):
		return
	if not T.require_true(self, bool(world.is_world_simulation_paused()), "Opening the controls help overlay must pause world simulation"):
		return
	if not T.require_true(self, bool(help_state.get("visible", false)), "Controls help overlay state must surface visible=true after pressing F1"):
		return
	if not T.require_true(self, (help_state.get("sections", []) as Array).size() >= 3, "Controls help overlay must publish multiple control sections instead of a one-line hint"):
		return
	if not T.require_true(self, help_overlay.size.x >= 400.0 and help_overlay.size.y >= 300.0, "Controls help overlay must receive a real fullscreen layout instead of collapsing"):
		return

	_press_key(world, KEY_F1)
	await process_frame

	help_state = hud.get_controls_help_state()
	if not T.require_true(self, not world.is_controls_help_open(), "Pressing F1 again must close the controls help overlay"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Closing the controls help overlay must resume world simulation"):
		return
	if not T.require_true(self, not bool(help_state.get("visible", true)), "Controls help overlay state must surface visible=false after closing"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _press_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)
