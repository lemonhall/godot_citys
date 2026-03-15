extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for HUD mouse passthrough contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var hud_root := world.get_node_or_null("Hud/Root") as Control
	if not T.require_true(self, hud_root != null, "HUD mouse passthrough contract requires a Root control under Hud"):
		return
	if not T.require_true(self, hud_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD root must ignore mouse input so walk-mode look/fire/ADS still reach PlayerController"):
		return

	world.queue_free()
	T.pass_and_quit(self)
