extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for map pin overlay")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("register_task_pin"), "CityPrototype must expose register_task_pin() for v12 M4"):
		return
	if not T.require_true(self, world.has_method("get_pin_registry_state"), "CityPrototype must expose get_pin_registry_state() for v12 M4"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "CityPrototype must expose get_map_screen_state() for v12 M4"):
		return

	var initial_registry_state: Dictionary = world.get_pin_registry_state()
	var initial_types: Array = initial_registry_state.get("pin_types", [])
	if not T.require_true(self, initial_types.has("landmark"), "Pin registry must seed landmark pins from the place index"):
		return

	var player := world.get_node_or_null("Player")
	var task_world_position: Vector3 = player.global_position + Vector3(40.0, 0.0, 22.0) if player != null else Vector3(40.0, 0.0, 22.0)
	var task_pin: Dictionary = world.register_task_pin("task:test", task_world_position, "Debug Task", "Pin Overlay Contract")
	if not T.require_true(self, str(task_pin.get("pin_id", "")) == "task:test", "register_task_pin() must return the stored task pin contract"):
		return

	var registry_state: Dictionary = world.get_pin_registry_state()
	var pin_types: Array = registry_state.get("pin_types", [])
	if not T.require_true(self, pin_types.has("landmark") and pin_types.has("task"), "Pin registry must allow landmark and task pins to coexist"):
		return

	world.set_full_map_open(true)
	await process_frame
	var map_state: Dictionary = world.get_map_screen_state()
	if not T.require_true(self, (map_state.get("pin_types", []) as Array).has("task"), "Full map must render task pins from the shared pin registry"):
		return
	if not T.require_true(self, (map_state.get("pin_types", []) as Array).has("landmark"), "Full map must keep landmark pins visible alongside task pins"):
		return

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var pin_overlay: Dictionary = minimap_snapshot.get("pin_overlay", {})
	if not T.require_true(self, not pin_overlay.is_empty(), "Minimap snapshot must expose a pin_overlay payload"):
		return
	if not T.require_true(self, (pin_overlay.get("pin_types", []) as Array).has("task"), "Minimap pin overlay must project nearby task pins into the HUD snapshot"):
		return

	world.queue_free()
	T.pass_and_quit(self)
