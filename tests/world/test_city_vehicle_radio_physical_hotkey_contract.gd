extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	T.install_vehicle_radio_test_scope("vehicle_radio_physical_hotkey_contract")
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle radio physical hotkey contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_vehicle_radio_quick_overlay_state"), "Physical hotkey contract requires HUD quick overlay state access"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_vehicle_radio_browser_state"), "Physical hotkey contract requires HUD browser state access"):
		return
	if not T.require_true(self, world.has_method("set_vehicle_radio_selection_sources"), "Physical hotkey contract requires quick bank source setup"):
		return
	if not T.require_true(self, world.has_method("is_world_simulation_paused"), "Physical hotkey contract requires pause state introspection"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Physical hotkey contract requires synthetic drive-mode setup support"):
		return

	world.set_vehicle_radio_selection_sources(_build_station_entries(), _build_aux_station_entries("favorite", 2), _build_aux_station_entries("recent", 2))
	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))
	var browser_control := world.get_node_or_null("Hud/Root/VehicleRadioBrowser") as Control
	if not T.require_true(self, browser_control != null, "Physical hotkey contract requires a dedicated VehicleRadioBrowser control under the HUD"):
		return

	_press_key(world, KEY_O)
	await process_frame
	var quick_overlay_state: Dictionary = hud.get_vehicle_radio_quick_overlay_state()
	if not T.require_true(self, bool(quick_overlay_state.get("visible", false)), "Pressing O while driving must open the radio quick overlay through the physical key path"):
		return
	if not T.require_true(self, bool(world.is_world_simulation_paused()), "Opening the radio quick overlay through the physical key path must pause world simulation"):
		return
	var slot_entries := quick_overlay_state.get("slots", []) as Array
	if not T.require_true(self, slot_entries.size() == 8, "Physical hotkey contract requires the O panel to expose a fixed 8-slot preset bank"):
		return
	if not T.require_true(self, str((slot_entries[3] as Dictionary).get("station_id", "")) == "", "Physical hotkey contract requires preset navigation to ignore favorites/recents instead of leaking them into later preset slots"):
		return
	var quick_overlay_control := world.get_node_or_null("Hud/Root/VehicleRadioQuickOverlay") as Control
	if not T.require_true(self, quick_overlay_control != null, "Physical hotkey contract requires a dedicated VehicleRadioQuickOverlay control under the HUD"):
		return
	var next_index_before := int(quick_overlay_state.get("selected_slot_index", -1))
	_press_key(world, KEY_BRACKETRIGHT)
	await process_frame
	quick_overlay_state = hud.get_vehicle_radio_quick_overlay_state()
	if not T.require_true(self, int(quick_overlay_state.get("selected_slot_index", -1)) == next_index_before + 1, "Pressing ] while quick overlay is open must advance to the next preset slot through the physical key path"):
		return
	_press_key(world, KEY_BRACKETLEFT)
	await process_frame
	quick_overlay_state = hud.get_vehicle_radio_quick_overlay_state()
	if not T.require_true(self, int(quick_overlay_state.get("selected_slot_index", -1)) == next_index_before, "Pressing [ while quick overlay is open must return to the previous preset slot through the physical key path"):
		return

	_press_key(world, KEY_O)
	await process_frame
	quick_overlay_state = hud.get_vehicle_radio_quick_overlay_state()
	if not T.require_true(self, not bool(quick_overlay_state.get("visible", true)), "Pressing O again must close the radio quick overlay through the physical key path"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Closing the radio quick overlay through the physical key path must resume world simulation"):
		return

	_press_key(world, KEY_B)
	await process_frame
	var browser_state: Dictionary = hud.get_vehicle_radio_browser_state()
	if not T.require_true(self, bool(browser_state.get("visible", false)), "Pressing B while driving must open the radio browser through the physical key path"):
		return
	if not T.require_true(self, bool(world.is_world_simulation_paused()), "Opening the radio browser through the physical key path must pause world simulation"):
		return
	if not T.require_true(self, browser_control.mouse_filter == Control.MOUSE_FILTER_STOP, "Radio browser must capture mouse input instead of ignoring it once the browser is meant to be usable"):
		return

	_press_key(world, KEY_B)
	await process_frame
	browser_state = hud.get_vehicle_radio_browser_state()
	if not T.require_true(self, not bool(browser_state.get("visible", true)), "Pressing B again must close the radio browser through the physical key path"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Closing the radio browser through the physical key path must resume world simulation"):
		return

	_press_key(world, KEY_O)
	await process_frame
	_press_key(world, KEY_ESCAPE)
	await process_frame
	quick_overlay_state = hud.get_vehicle_radio_quick_overlay_state()
	if not T.require_true(self, not bool(quick_overlay_state.get("visible", true)), "Pressing Esc must close the radio quick overlay through the physical key path"):
		return

	_press_key(world, KEY_B)
	await process_frame
	_press_key(world, KEY_ESCAPE)
	await process_frame
	browser_state = hud.get_vehicle_radio_browser_state()
	if not T.require_true(self, not bool(browser_state.get("visible", true)), "Pressing Esc must close the radio browser through the physical key path"):
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

func _build_station_entries() -> Array:
	return [
		{
			"station_id": "station:hotkey:0",
			"station_name": "Hotkey Test 0",
			"country": "CN",
			"stream_url": "https://radio.example/hotkey_0.mp3",
		},
		{
			"station_id": "station:hotkey:1",
			"station_name": "Hotkey Test 1",
			"country": "CN",
			"stream_url": "https://radio.example/hotkey_1.mp3",
		},
		{
			"station_id": "station:hotkey:2",
			"station_name": "Hotkey Test 2",
			"country": "CN",
			"stream_url": "https://radio.example/hotkey_2.mp3",
		},
	]

func _build_aux_station_entries(prefix: String, count: int) -> Array:
	var entries: Array = []
	for index in range(count):
		entries.append({
			"station_id": "station:%s:%d" % [prefix, index],
			"station_name": "%s_%d" % [prefix, index],
			"country": "CN",
			"stream_url": "https://radio.example/%s_%d.mp3" % [prefix, index],
		})
	return entries

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:radio_physical_hotkey",
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
