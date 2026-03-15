extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for minimap navigation HUD")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_navigation_state"), "PrototypeHud must expose get_navigation_state() for v12 M4"):
		return

	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(1400.0, 0.0, 26.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Navigation HUD test requires a successful map destination selection"):
		return

	var route_result: Dictionary = world.get_active_route_result()
	if not T.require_true(self, not route_result.is_empty(), "Map destination selection must create an active route before HUD assertions run"):
		return

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var route_overlay: Dictionary = minimap_snapshot.get("route_overlay", {})
	if not T.require_true(self, not route_overlay.is_empty(), "Minimap snapshot must expose a route overlay after a destination is selected"):
		return
	if not T.require_true(self, (route_overlay.get("polyline", PackedVector2Array()) as PackedVector2Array).size() >= 2, "Minimap route overlay must project the active route polyline"):
		return

	var navigation_state: Dictionary = hud.get_navigation_state()
	if not T.require_true(self, str(navigation_state.get("route_id", "")) == str(route_result.get("route_id", "")), "HUD navigation state must consume the same route generation as the active route_result"):
		return
	if not T.require_true(self, str(navigation_state.get("instruction_short", "")) != "", "HUD navigation state must expose the next maneuver instruction"):
		return

	world.queue_free()
	T.pass_and_quit(self)
