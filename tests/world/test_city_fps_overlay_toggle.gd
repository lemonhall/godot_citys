extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for FPS overlay toggle")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("handle_debug_keypress"), "CityPrototype must expose handle_debug_keypress() for debug hotkeys in headless tests"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "FPS overlay toggle requires Hud node"):
		return
	if not T.require_true(self, hud.has_method("get_fps_overlay_state"), "PrototypeHud must expose get_fps_overlay_state() for FPS overlay verification"):
		return
	if not T.require_true(self, hud.has_method("set_fps_overlay_sample"), "PrototypeHud must expose set_fps_overlay_sample() for FPS color verification"):
		return

	var fps_label := hud.get_node_or_null("Root/FpsLabel") as Label
	if not T.require_true(self, fps_label != null, "PrototypeHud must create a right-top FpsLabel node"):
		return

	var fps_state: Dictionary = hud.get_fps_overlay_state()
	if not T.require_true(self, not bool(fps_state.get("visible", true)), "FPS overlay must stay hidden by default"):
		return

	world.handle_debug_keypress(KEY_KP_SUBTRACT, KEY_KP_SUBTRACT)
	await process_frame
	fps_state = hud.get_fps_overlay_state()
	if not T.require_true(self, bool(fps_state.get("visible", false)), "Numpad - must toggle the FPS overlay on"):
		return
	if not T.require_true(self, fps_label.visible, "Visible FPS overlay must show the FpsLabel node"):
		return
	if not T.require_true(self, is_equal_approx(fps_label.anchor_left, 1.0) and is_equal_approx(fps_label.anchor_right, 1.0), "FPS overlay must stay anchored to the right edge"):
		return
	if not T.require_true(self, fps_label.offset_right <= -16.0 and fps_label.offset_top >= 12.0, "FPS overlay must stay fixed near the top-right corner"):
		return

	hud.set_fps_overlay_sample(25.0)
	fps_state = hud.get_fps_overlay_state()
	if not T.require_true(self, str(fps_state.get("color_name", "")) == "red", "FPS under 30 must render in red"):
		return

	hud.set_fps_overlay_sample(40.0)
	fps_state = hud.get_fps_overlay_state()
	if not T.require_true(self, str(fps_state.get("color_name", "")) == "yellow", "FPS between 30 and 50 must render in yellow"):
		return

	hud.set_fps_overlay_sample(55.0)
	fps_state = hud.get_fps_overlay_state()
	if not T.require_true(self, str(fps_state.get("color_name", "")) == "green", "FPS above 50 must render in green"):
		return

	world.handle_debug_keypress(KEY_KP_SUBTRACT, KEY_KP_SUBTRACT)
	await process_frame
	fps_state = hud.get_fps_overlay_state()
	if not T.require_true(self, not bool(fps_state.get("visible", true)), "Numpad - must toggle the FPS overlay off on the second press"):
		return

	world.queue_free()
	T.pass_and_quit(self)
