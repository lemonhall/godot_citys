extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CatalogStore := preload("res://city_game/world/radio/CityRadioCatalogStore.gd")
const CatalogRepository := preload("res://city_game/world/radio/CityRadioCatalogRepository.gd")

class FakeRadioBrowserApi:
	extends RefCounted

	var countries: Array = []
	var stations_by_country := {}

	func list_countries() -> Dictionary:
		return {
			"success": true,
			"countries": countries.duplicate(true),
			"error": "",
		}

	func list_stations_by_country(country_name: String, limit: int) -> Dictionary:
		var rows: Array = []
		var raw_rows: Variant = stations_by_country.get(country_name, [])
		if raw_rows is Array:
			rows = (raw_rows as Array).duplicate(true)
		if limit >= 0 and rows.size() > limit:
			rows.resize(limit)
		return {
			"success": true,
			"stations": rows,
			"error": "",
		}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	CatalogRepository.clear_test_api()
	_seed_empty_catalog()

	var fake_api := FakeRadioBrowserApi.new()
	fake_api.countries = [
		{
			"name": "Testland",
			"stationcount": 1,
			"iso_3166_1": "XZ",
		},
	]
	fake_api.stations_by_country["Testland"] = [
		{
			"stationuuid": "station-tl-001",
			"name": "Testland Drive",
			"url_resolved": "https://radio.example/testland_drive.mp3",
			"country": "Testland",
			"language": "en",
			"codec": "aac",
			"votes": 123,
		},
	]
	CatalogRepository.install_test_api(fake_api)

	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		CatalogRepository.clear_test_api()
		T.fail_and_quit(self, "Missing CityPrototype.tscn for radio browser bootstrap catalog contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Radio browser bootstrap catalog contract requires synthetic drive-mode setup support"):
		CatalogRepository.clear_test_api()
		return
	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))

	var open_result: Dictionary = world.open_vehicle_radio_browser()
	if not T.require_true(self, bool(open_result.get("success", false)), "Radio browser bootstrap catalog contract requires browser open support"):
		CatalogRepository.clear_test_api()
		return
	var browser_state: Dictionary = world.get_vehicle_radio_browser_state()
	var browse_state: Dictionary = browser_state.get("browse", {}) as Dictionary
	var countries := browse_state.get("countries", []) as Array
	if not T.require_true(self, countries.size() == 1, "Fresh runtime must populate countries from the lazy sync repository instead of a built-in demo list"):
		CatalogRepository.clear_test_api()
		return
	var first_country: Dictionary = countries[0] as Dictionary
	if not T.require_true(self, str(first_country.get("country_code", "")) == "XZ", "Fresh runtime must surface the repository-synced country_code rather than a hardcoded demo country"):
		CatalogRepository.clear_test_api()
		return
	if not T.require_true(self, str(first_country.get("display_name", "")) == "Testland", "Fresh runtime must surface the repository-synced display_name rather than a hardcoded demo country"):
		CatalogRepository.clear_test_api()
		return

	world.select_vehicle_radio_browser_country("XZ")
	await process_frame
	browser_state = world.get_vehicle_radio_browser_state()
	browse_state = browser_state.get("browse", {}) as Dictionary
	var stations := browse_state.get("stations", []) as Array
	if not T.require_true(self, stations.size() == 1, "Selecting a synced country must lazily materialize its station page from the repository"):
		CatalogRepository.clear_test_api()
		return
	var first_station: Dictionary = stations[0] as Dictionary
	if not T.require_true(self, str(first_station.get("station_id", "")) == "radio-browser:station-tl-001", "Browser bootstrap contract must surface repository-derived station ids instead of hardcoded demo ids"):
		CatalogRepository.clear_test_api()
		return
	if not T.require_true(self, str(first_station.get("station_name", "")) == "Testland Drive", "Browser bootstrap contract must surface repository-derived station names instead of hardcoded demo rows"):
		CatalogRepository.clear_test_api()
		return

	world.queue_free()
	CatalogRepository.clear_test_api()
	T.pass_and_quit(self)

func _seed_empty_catalog() -> void:
	var store := CatalogStore.new()
	if not bool(store.save_countries_index([], 100, 72 * 3600).get("success", false)):
		T.fail_and_quit(self, "Radio browser bootstrap catalog contract failed to seed empty countries index")
		return
	if not bool(store.save_country_station_page("XZ", [], 100, 72 * 3600).get("success", false)):
		T.fail_and_quit(self, "Radio browser bootstrap catalog contract failed to seed empty XZ station page")
		return

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:radio_browser_bootstrap_catalog",
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
