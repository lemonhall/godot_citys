extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for combat crosshair contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Combat crosshair contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("get_aim_target_world_position"), "PlayerController must expose get_aim_target_world_position() for crosshair alignment"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "Combat crosshair contract requires Hud node"):
		return
	if not T.require_true(self, hud.has_method("get_crosshair_state"), "PrototypeHud must expose get_crosshair_state() for combat verification"):
		return

	var crosshair_state: Dictionary = hud.get_crosshair_state()
	if not T.require_true(self, bool(crosshair_state.get("visible", false)), "Combat HUD must keep a visible crosshair by default"):
		return

	var world_target: Vector3 = player.get_aim_target_world_position()
	var crosshair_world_target: Vector3 = crosshair_state.get("world_target", Vector3.ZERO)
	if not T.require_true(self, crosshair_world_target.distance_to(world_target) <= 0.05, "HUD crosshair world target must stay aligned with the player's actual aim target"):
		return

	var screen_position: Vector2 = crosshair_state.get("screen_position", Vector2.ZERO)
	var viewport_size: Vector2 = crosshair_state.get("viewport_size", Vector2.ZERO)
	if not T.require_true(self, screen_position.x >= 0.0 and screen_position.y >= 0.0, "Crosshair screen position must stay inside the viewport"):
		return
	if not T.require_true(self, screen_position.x <= viewport_size.x and screen_position.y <= viewport_size.y, "Crosshair must stay inside viewport bounds"):
		return

	world.queue_free()
	T.pass_and_quit(self)
