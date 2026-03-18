extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CatalogStore := preload("res://city_game/world/radio/CityRadioCatalogStore.gd")
const UserStateStore := preload("res://city_game/world/radio/CityRadioUserStateStore.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	T.install_vehicle_radio_test_scope("vehicle_radio_hud_idle_contract")
	_seed_browser_catalog()

	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle radio HUD idle contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_vehicle_radio_debug_state"), "Vehicle radio HUD idle contract requires get_vehicle_radio_debug_state()"):
		return
	if not T.require_true(self, world.has_method("open_vehicle_radio_browser"), "Vehicle radio HUD idle contract requires open_vehicle_radio_browser()"):
		return
	if not T.require_true(self, world.has_method("select_vehicle_radio_browser_country"), "Vehicle radio HUD idle contract requires select_vehicle_radio_browser_country()"):
		return
	if not T.require_true(self, world.has_method("set_vehicle_radio_browser_filter_text"), "Vehicle radio HUD idle contract requires set_vehicle_radio_browser_filter_text()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Vehicle radio HUD idle contract requires synthetic drive-mode setup support"):
		return
	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))
	await process_frame

	var initial_debug: Dictionary = world.get_vehicle_radio_debug_state()
	await process_frame
	await process_frame
	await process_frame
	var idle_debug: Dictionary = world.get_vehicle_radio_debug_state()
	if not T.require_true(self, int(idle_debug.get("browser_country_load_count", -1)) == int(initial_debug.get("browser_country_load_count", -2)), "Hidden browser must not reload countries while HUD stays idle"):
		return
	if not T.require_true(self, int(idle_debug.get("browser_station_page_load_count", -1)) == int(initial_debug.get("browser_station_page_load_count", -2)), "Hidden browser must not load station pages while HUD stays idle"):
		return

	if not T.require_true(self, bool(world.open_vehicle_radio_browser().get("success", false)), "Vehicle radio HUD idle contract must open the browser in driving mode"):
		return
	world.select_vehicle_radio_browser_country("CN")
	var country_open_debug: Dictionary = world.get_vehicle_radio_debug_state()
	if not T.require_true(self, int(country_open_debug.get("browser_station_page_load_count", 0)) == int(initial_debug.get("browser_station_page_load_count", 0)) + 1, "Opening a country directory must load exactly one station page into browser cache"):
		return

	world.set_vehicle_radio_browser_filter_text("Traffic")
	world.set_vehicle_radio_browser_filter_text("Xi'an")
	world.set_vehicle_radio_browser_filter_text("")
	var filtered_debug: Dictionary = world.get_vehicle_radio_debug_state()
	if not T.require_true(self, int(filtered_debug.get("browser_station_page_load_count", -1)) == int(country_open_debug.get("browser_station_page_load_count", -2)), "Local browser filtering must reuse the already loaded country page instead of reloading catalog data"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _seed_browser_catalog() -> void:
	var store := CatalogStore.new()
	var user_state_store := UserStateStore.new()
	var seeded_at := int(Time.get_unix_time_from_system())
	if not bool(user_state_store.save_presets([], seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio HUD idle contract failed to reset presets")
		return
	if not bool(user_state_store.save_favorites([], seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio HUD idle contract failed to reset favorites")
		return
	if not bool(user_state_store.save_recents([], seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio HUD idle contract failed to reset recents")
		return
	if not bool(user_state_store.save_session_state({"power_state": "off"}, seeded_at).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio HUD idle contract failed to reset session state")
		return
	if not bool(store.save_countries_index([
		{"country_code": "CN", "display_name": "China", "station_count": 2},
	], seeded_at, 72 * 3600).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio HUD idle contract failed to seed countries index")
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
		T.fail_and_quit(self, "Vehicle radio HUD idle contract failed to seed CN station page")
		return

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:radio_hud_idle_contract",
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
