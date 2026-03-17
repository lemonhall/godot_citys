extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle radio quick overlay contract")
		return

	for action_name in [
		"vehicle_radio_quick_open",
		"vehicle_radio_next",
		"vehicle_radio_prev",
		"vehicle_radio_power_toggle",
		"vehicle_radio_browser_open",
		"vehicle_radio_confirm",
		"vehicle_radio_cancel",
	]:
		if not T.require_true(self, InputMap.has_action(action_name), "Vehicle radio quick overlay contract requires InputMap action %s" % action_name):
			return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_vehicle_radio_quick_overlay_state"), "PrototypeHud must expose get_vehicle_radio_quick_overlay_state() for vehicle radio quick overlay contract"):
		return
	if not T.require_true(self, world.has_method("open_vehicle_radio_quick_overlay"), "CityPrototype must expose open_vehicle_radio_quick_overlay() for vehicle radio quick overlay contract"):
		return
	if not T.require_true(self, world.has_method("close_vehicle_radio_quick_overlay"), "CityPrototype must expose close_vehicle_radio_quick_overlay() for vehicle radio quick overlay contract"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_radio_quick_overlay_state"), "CityPrototype must expose get_vehicle_radio_quick_overlay_state() for vehicle radio quick overlay contract"):
		return
	if not T.require_true(self, world.has_method("set_vehicle_radio_selection_sources"), "CityPrototype must expose set_vehicle_radio_selection_sources() for quick bank source setup"):
		return
	if not T.require_true(self, world.has_method("is_world_simulation_paused"), "CityPrototype must expose is_world_simulation_paused() for quick overlay pause contract"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Quick overlay contract requires synthetic drive-mode setup support"):
		return

	var blocked_result: Dictionary = world.open_vehicle_radio_quick_overlay()
	if not T.require_true(self, not bool(blocked_result.get("success", true)), "Quick overlay must stay closed while the player is not driving"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Blocked quick overlay open must not pause world simulation"):
		return

	world.set_vehicle_radio_selection_sources(_build_slot_entries("preset", 6), _build_slot_entries("favorite", 4), _build_slot_entries("recent", 3))
	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))
	var open_result: Dictionary = world.open_vehicle_radio_quick_overlay()
	if not T.require_true(self, bool(open_result.get("success", false)), "Quick overlay must open in driving mode"):
		return
	if not T.require_true(self, bool(world.is_world_simulation_paused()), "Opening quick overlay must pause world simulation through the shared pause contract"):
		return

	var overlay_state: Dictionary = world.get_vehicle_radio_quick_overlay_state()
	var slot_entries := overlay_state.get("slots", []) as Array
	if not T.require_true(self, bool(overlay_state.get("visible", false)), "Quick overlay state must surface visible=true after open"):
		return
	if not T.require_true(self, slot_entries.size() == 8, "Quick overlay must clamp the quick bank to exactly 8 visible slots even when source lists are larger"):
		return
	if not T.require_true(self, bool(overlay_state.get("power_action_available", false)), "Quick overlay must surface a dedicated power action instead of consuming a quick slot"):
		return
	if not T.require_true(self, bool(overlay_state.get("browser_action_available", false)), "Quick overlay must surface a dedicated browser action instead of consuming a quick slot"):
		return

	_press_action(world, "vehicle_radio_cancel")
	await process_frame
	overlay_state = hud.get_vehicle_radio_quick_overlay_state()
	if not T.require_true(self, not bool(overlay_state.get("visible", true)), "vehicle_radio_cancel must close the quick overlay"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Closing quick overlay must restore world simulation pause state"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _press_action(world: Node, action_name: String) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	world._unhandled_input(event)

func _build_slot_entries(prefix: String, count: int) -> Array:
	var entries: Array = []
	for index in range(count):
		entries.append({
			"station_id": "station:%s:%d" % [prefix, index],
			"station_name": "%s_%d" % [prefix, index],
			"country": "CN",
		})
	return entries

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:radio_quick_overlay",
		"model_id": "car_b",
		"heading": Vector3(1.0, 0.0, 0.0),
		"world_position": player.global_position - Vector3.UP * standing_height,
		"length_m": 4.4,
		"width_m": 1.9,
		"height_m": 1.6,
		"speed_mps": 0.0,
	}

func _estimate_standing_height(player) -> float:
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0
