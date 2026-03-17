extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CatalogStore := preload("res://city_game/world/radio/CityRadioCatalogStore.gd")
const UserStateStore := preload("res://city_game/world/radio/CityRadioUserStateStore.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_seed_browser_catalog()

	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle radio browser flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("open_vehicle_radio_browser"), "Vehicle radio browser flow requires open_vehicle_radio_browser()"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_radio_browser_state"), "Vehicle radio browser flow requires get_vehicle_radio_browser_state()"):
		return
	if not T.require_true(self, world.has_method("select_vehicle_radio_browser_country"), "Vehicle radio browser flow requires select_vehicle_radio_browser_country()"):
		return
	if not T.require_true(self, world.has_method("set_vehicle_radio_browser_filter_text"), "Vehicle radio browser flow requires set_vehicle_radio_browser_filter_text()"):
		return
	if not T.require_true(self, world.has_method("toggle_vehicle_radio_browser_favorite"), "Vehicle radio browser flow requires toggle_vehicle_radio_browser_favorite()"):
		return
	if not T.require_true(self, world.has_method("assign_vehicle_radio_browser_preset"), "Vehicle radio browser flow requires assign_vehicle_radio_browser_preset()"):
		return
	if not T.require_true(self, world.has_method("select_vehicle_radio_browser_station"), "Vehicle radio browser flow requires select_vehicle_radio_browser_station()"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_radio_runtime_state"), "Vehicle radio browser flow requires get_vehicle_radio_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("open_vehicle_radio_quick_overlay"), "Vehicle radio browser flow requires open_vehicle_radio_quick_overlay()"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_radio_quick_overlay_state"), "Vehicle radio browser flow requires get_vehicle_radio_quick_overlay_state()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Vehicle radio browser flow requires synthetic drive-mode setup support"):
		return
	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))

	var open_result: Dictionary = world.open_vehicle_radio_browser()
	if not T.require_true(self, bool(open_result.get("success", false)), "Vehicle radio browser must open in driving mode"):
		return

	world.select_vehicle_radio_browser_country("CN")
	world.set_vehicle_radio_browser_filter_text("Traffic")
	var browser_state: Dictionary = world.get_vehicle_radio_browser_state()
	var browse_state: Dictionary = browser_state.get("browse", {}) as Dictionary
	var station_rows := browse_state.get("stations", []) as Array
	if not T.require_true(self, str(browse_state.get("root_kind", "")) == "stations", "Selecting a country in browser flow must switch Browse root to stations"):
		return
	if not T.require_true(self, str(browse_state.get("selected_country_code", "")) == "CN", "Browser flow must preserve the selected country code in Browse state"):
		return
	if not T.require_true(self, station_rows.size() == 1, "Browser local filter must keep only the matching station rows"):
		return
	var filtered_station: Dictionary = station_rows[0] as Dictionary
	if not T.require_true(self, str(filtered_station.get("station_id", "")) == "station:cn:traffic", "Browser filter must keep Xi'an Traffic FM as the remaining station row"):
		return

	var select_result: Dictionary = world.select_vehicle_radio_browser_station("station:cn:traffic")
	if not T.require_true(self, bool(select_result.get("success", false)), "Browser flow must allow clicking a station row to enter the playback chain immediately"):
		return
	var runtime_state: Dictionary = world.get_vehicle_radio_runtime_state()
	if not T.require_true(self, str(runtime_state.get("selected_station_id", "")) == "station:cn:traffic", "Browser flow must promote the clicked station into the runtime selected_station_id"):
		return
	if not T.require_true(self, str(runtime_state.get("power_state", "")) == "on", "Clicking a station in browser flow must auto-power the radio on"):
		return
	if not T.require_true(self, str(runtime_state.get("playback_state", "")) == "playing", "Clicking a station in browser flow must transition the backend into playing state while driving"):
		return

	var favorite_result: Dictionary = world.toggle_vehicle_radio_browser_favorite("station:cn:traffic")
	if not T.require_true(self, bool(favorite_result.get("success", false)), "Browser flow must allow adding the filtered station to favorites"):
		return
	var preset_result: Dictionary = world.assign_vehicle_radio_browser_preset(0, "station:cn:traffic")
	if not T.require_true(self, bool(preset_result.get("success", false)), "Browser flow must allow assigning the filtered station into preset slot 0"):
		return

	browser_state = world.get_vehicle_radio_browser_state()
	var favorites := browser_state.get("favorites", []) as Array
	var presets := browser_state.get("presets", []) as Array
	if not T.require_true(self, favorites.size() == 1, "Browser flow must surface the new favorite immediately in browser state"):
		return
	if not T.require_true(self, presets.size() >= 1, "Browser flow must surface the edited preset bank in browser state"):
		return

	var close_browser_result: Dictionary = world.close_vehicle_radio_browser()
	if not T.require_true(self, bool(close_browser_result.get("success", false)), "Browser flow must close the full-screen browser cleanly"):
		return
	var open_overlay_result: Dictionary = world.open_vehicle_radio_quick_overlay()
	if not T.require_true(self, bool(open_overlay_result.get("success", false)), "Browser flow must leave quick overlay usable after closing the browser"):
		return
	var overlay_state: Dictionary = world.get_vehicle_radio_quick_overlay_state()
	var slots := overlay_state.get("slots", []) as Array
	if not T.require_true(self, slots.size() >= 1, "Quick overlay must rebuild with at least one slot after browser preset editing"):
		return
	if not T.require_true(self, str((slots[0] as Dictionary).get("station_id", "")) == "station:cn:traffic", "Preset editing in browser flow must feed the quick bank first slot"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _seed_browser_catalog() -> void:
	var store := CatalogStore.new()
	var user_state_store := UserStateStore.new()
	var seeded_at := int(Time.get_unix_time_from_system())
	if not bool(user_state_store.save_presets([], seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio browser flow failed to reset presets")
		return
	if not bool(user_state_store.save_favorites([], seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio browser flow failed to reset favorites")
		return
	if not bool(user_state_store.save_recents([], seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio browser flow failed to reset recents")
		return
	if not bool(user_state_store.save_session_state({"power_state": "off"}, seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio browser flow failed to reset session state")
		return
	if not bool(store.save_countries_index([
		{"country_code": "CN", "display_name": "China", "station_count": 2},
		{"country_code": "JP", "display_name": "Japan", "station_count": 1},
	], seeded_at, 72 * 3600).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio browser flow failed to seed countries index")
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
		{
			"station_id": "station:cn:news",
			"station_name": "Shaanxi News Radio",
			"country": "CN",
			"language": "zh",
			"codec": "aac",
			"votes": 64,
			"stream_url": "https://radio.example/shaanxi_news.mp3",
		},
	], seeded_at, 72 * 3600).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio browser flow failed to seed CN station page")
		return

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:radio_browser_flow",
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
