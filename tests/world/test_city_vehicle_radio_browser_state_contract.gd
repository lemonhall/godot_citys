extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CatalogStore := preload("res://city_game/world/radio/CityRadioCatalogStore.gd")
const UserStateStore := preload("res://city_game/world/radio/CityRadioUserStateStore.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_seed_radio_browser_sources()

	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle radio browser state contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("open_vehicle_radio_browser"), "Vehicle radio browser state contract requires open_vehicle_radio_browser()"):
		return
	if not T.require_true(self, world.has_method("close_vehicle_radio_browser"), "Vehicle radio browser state contract requires close_vehicle_radio_browser()"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_radio_browser_state"), "Vehicle radio browser state contract requires get_vehicle_radio_browser_state()"):
		return
	if not T.require_true(self, world.has_method("is_world_simulation_paused"), "Vehicle radio browser state contract requires is_world_simulation_paused()"):
		return

	var open_on_foot_result: Dictionary = world.open_vehicle_radio_browser()
	if not T.require_true(self, bool(open_on_foot_result.get("success", false)), "Vehicle radio browser must now be openable even while the player is not driving"):
		return
	if not T.require_true(self, bool(world.is_world_simulation_paused()), "Opening vehicle radio browser on foot must still share world pause semantics"):
		return
	if not T.require_true(self, bool(world.close_vehicle_radio_browser().get("success", false)), "Vehicle radio browser state contract requires browser close support after opening on foot"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Closing the on-foot browser must restore world simulation pause state"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Vehicle radio browser state contract requires synthetic drive-mode setup support"):
		return
	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))

	var open_result: Dictionary = world.open_vehicle_radio_browser()
	if not T.require_true(self, bool(open_result.get("success", false)), "Vehicle radio browser must still open in driving mode"):
		return
	if not T.require_true(self, bool(world.is_world_simulation_paused()), "Opening vehicle radio browser must share world pause semantics"):
		return

	var browser_state: Dictionary = world.get_vehicle_radio_browser_state()
	if not T.require_true(self, bool(browser_state.get("visible", false)), "Vehicle radio browser state must surface visible=true after open"):
		return
	if not T.require_true(self, str(browser_state.get("selected_tab_id", "")) == "browse", "Vehicle radio browser must default to the Browse tab"):
		return

	var tabs := browser_state.get("tabs", []) as Array
	var tab_ids := PackedStringArray()
	for tab_variant in tabs:
		var tab: Dictionary = tab_variant as Dictionary
		tab_ids.append(str(tab.get("tab_id", "")))
	if not T.require_true(self, tab_ids == PackedStringArray(["now_playing", "presets", "favorites", "recents", "browse"]), "Vehicle radio browser must expose the frozen tab family in order"):
		return

	var browse_state: Dictionary = browser_state.get("browse", {}) as Dictionary
	if not T.require_true(self, str(browse_state.get("root_kind", "")) == "countries", "Vehicle radio browser Browse root must stay at countries index instead of flattening stations globally"):
		return
	var countries := browse_state.get("countries", []) as Array
	if not T.require_true(self, countries.size() == 2, "Vehicle radio browser Browse root must surface cached country directory entries"):
		return
	if not T.require_true(self, int((browse_state.get("stations", []) as Array).size()) == 0, "Vehicle radio browser countries root must not eagerly materialize station rows"):
		return

	var close_result: Dictionary = world.close_vehicle_radio_browser()
	if not T.require_true(self, bool(close_result.get("success", false)), "Vehicle radio browser must close cleanly"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Closing vehicle radio browser must restore world simulation pause state"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _seed_radio_browser_sources() -> void:
	var catalog_store := CatalogStore.new()
	var user_state_store := UserStateStore.new()
	var seeded_at := int(Time.get_unix_time_from_system())
	var countries := [
		{"country_code": "CN", "display_name": "China", "station_count": 200},
		{"country_code": "JP", "display_name": "Japan", "station_count": 180},
	]
	var presets := [
		{
			"slot_index": 0,
			"station_snapshot": {
				"station_id": "station:cn:1",
				"station_name": "Xi'an Traffic FM",
				"country": "CN",
			},
		}
	]
	var favorites := [
		{
			"station_id": "station:jp:1",
			"station_name": "Tokyo Groove Radio",
			"country": "JP",
		}
	]
	var recents := [
		{
			"station_id": "station:cn:2",
			"station_name": "Shaanxi News Radio",
			"country": "CN",
		}
	]
	if not bool(catalog_store.save_countries_index(countries, seeded_at, 72 * 3600).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio browser state contract failed to seed countries index")
		return
	if not bool(user_state_store.save_presets(presets, seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio browser state contract failed to seed presets")
		return
	if not bool(user_state_store.save_favorites(favorites, seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio browser state contract failed to seed favorites")
		return
	if not bool(user_state_store.save_recents(recents, seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio browser state contract failed to seed recents")
		return

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:radio_browser_state_contract",
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
