extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CatalogStore := preload("res://city_game/world/radio/CityRadioCatalogStore.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	T.install_vehicle_radio_test_scope("vehicle_radio_browser_modal_hotkey_contract")
	_seed_browser_catalog()
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for radio browser modal hotkey contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Radio browser modal hotkey contract requires synthetic drive-mode setup support"):
		return
	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))

	var open_result: Dictionary = world.open_vehicle_radio_browser()
	if not T.require_true(self, bool(open_result.get("success", false)), "Radio browser modal hotkey contract requires browser open support"):
		return
	world.select_vehicle_radio_browser_country("CN")
	await process_frame

	var filter_edit := world.get_node_or_null("Hud/Root/VehicleRadioBrowser/Panel/Shell/Body/LeftPanel/LeftVBox/Toolbar/FilterEdit") as LineEdit
	if not T.require_true(self, filter_edit != null, "Radio browser modal hotkey contract requires a filter LineEdit once station browse is visible"):
		return
	filter_edit.grab_focus()
	await process_frame

	Input.parse_input_event(_build_key_event(KEY_B))
	await process_frame
	await process_frame
	var browser_state: Dictionary = world.get_vehicle_radio_browser_state()
	if not T.require_true(self, not bool(browser_state.get("visible", true)), "Pressing B through the real input pipeline must still close the radio browser even when an inner widget owns focus"):
		return

	var quick_open_result: Dictionary = world.open_vehicle_radio_quick_overlay()
	if not T.require_true(self, bool(quick_open_result.get("success", false)), "Radio browser modal hotkey contract requires quick overlay open support"):
		return
	Input.parse_input_event(_build_key_event(KEY_O))
	await process_frame
	await process_frame
	var quick_state: Dictionary = world.get_vehicle_radio_quick_overlay_state()
	if not T.require_true(self, not bool(quick_state.get("visible", true)), "Pressing O through the real input pipeline must close the quick overlay"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _seed_browser_catalog() -> void:
	var store := CatalogStore.new()
	var seeded_at := int(Time.get_unix_time_from_system())
	if not bool(store.save_countries_index([
		{"country_code": "CN", "display_name": "China", "station_count": 1},
	], seeded_at, 72 * 3600).get("success", false)):
		T.fail_and_quit(self, "Radio browser modal hotkey contract failed to seed countries index")
		return
	if not bool(store.save_country_station_page("CN", [
		{
			"station_id": "station:cn:traffic",
			"station_name": "Xi'an Traffic FM",
			"country": "CN",
			"language": "zh",
			"codec": "aac",
			"votes": 88,
			"stream_url": "https://radio.example/xian_traffic.mp3",
		},
	], seeded_at, 72 * 3600).get("success", false)):
		T.fail_and_quit(self, "Radio browser modal hotkey contract failed to seed station page")
		return

func _build_key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	return event

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:radio_browser_modal_hotkey",
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
