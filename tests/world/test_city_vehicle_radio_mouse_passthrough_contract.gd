extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle radio mouse passthrough contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var quick_overlay := world.get_node_or_null("Hud/Root/VehicleRadioQuickOverlay") as Control
	if not T.require_true(self, quick_overlay != null, "Vehicle radio mouse passthrough contract requires a HUD quick overlay control"):
		return
	if not T.require_true(self, quick_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Hidden quick overlay root must ignore mouse so gameplay camera input is not intercepted"):
		return
	if not T.require_true(self, not quick_overlay.visible, "Hidden quick overlay root must stay invisible while the overlay is closed"):
		return

	var browser := world.get_node_or_null("Hud/Root/VehicleRadioBrowser") as Control
	if not T.require_true(self, browser != null, "Vehicle radio mouse passthrough contract requires a HUD browser control"):
		return
	if not T.require_true(self, not browser.visible, "Hidden browser root must stay invisible while the browser is closed"):
		return

	world.queue_free()
	T.pass_and_quit(self)
