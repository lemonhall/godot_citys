extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CatalogStore := preload("res://city_game/world/radio/CityRadioCatalogStore.gd")
const CatalogRepository := preload("res://city_game/world/radio/CityRadioCatalogRepository.gd")

class FakeRadioBrowserApi:
	extends RefCounted

	var countries: Array = []
	var stations_by_country := {}
	var fail_countries := false
	var fail_stations := false
	var countries_call_count := 0
	var stations_call_count := 0

	func list_countries() -> Dictionary:
		countries_call_count += 1
		if fail_countries:
			return {
				"success": false,
				"countries": [],
				"error": "countries_failed",
			}
		return {
			"success": true,
			"countries": countries.duplicate(true),
			"error": "",
		}

	func list_stations_by_country(country_name: String, limit: int) -> Dictionary:
		stations_call_count += 1
		if fail_stations:
			return {
				"success": false,
				"stations": [],
				"error": "stations_failed",
			}
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
	T.install_vehicle_radio_test_scope("vehicle_radio_catalog_repository_sync_contract")
	var store := CatalogStore.new()
	if not bool(store.save_countries_index([], 100, 72 * 3600).get("success", false)):
		T.fail_and_quit(self, "Repository sync contract failed to reset countries index")
		return
	if not bool(store.delete_country_station_page("XZ").get("success", false)):
		T.fail_and_quit(self, "Repository sync contract failed to clear any pre-existing XZ station page")
		return
	var fake_api := FakeRadioBrowserApi.new()
	fake_api.countries = [
		{
			"name": "Testland",
			"stationcount": 2,
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

	var repository = CatalogRepository.new(store, fake_api)
	if not T.require_true(self, repository != null and repository.has_method("ensure_countries_ready"), "Vehicle radio catalog repository sync contract requires CityRadioCatalogRepository.ensure_countries_ready()"):
		return
	if not T.require_true(self, repository.has_method("ensure_country_station_page_ready"), "Vehicle radio catalog repository sync contract requires CityRadioCatalogRepository.ensure_country_station_page_ready()"):
		return

	var countries_result: Dictionary = repository.ensure_countries_ready(false, 1000)
	if not T.require_true(self, bool(countries_result.get("success", false)), "Repository sync contract must lazily materialize countries index from the radio browser API when cache is empty"):
		return
	if not T.require_true(self, int(fake_api.countries_call_count) == 1, "Repository sync contract must query the radio browser API exactly once on the first countries sync"):
		return
	var countries := countries_result.get("countries", []) as Array
	if not T.require_true(self, countries.size() == 1, "Repository sync contract must preserve the API country count when materializing cache"):
		return
	var first_country: Dictionary = countries[0] as Dictionary
	if not T.require_true(self, str(first_country.get("country_code", "")) == "XZ", "Repository sync contract must map ISO 3166-1 alpha-2 into the frozen country_code field"):
		return
	if not T.require_true(self, str(first_country.get("display_name", "")) == "Testland", "Repository sync contract must map the API country name into the frozen display_name field"):
		return

	var stations_result: Dictionary = repository.ensure_country_station_page_ready("XZ", false, 1000)
	if not T.require_true(self, bool(stations_result.get("success", false)), "Repository sync contract must lazily materialize station rows for the selected country"):
		return
	if not T.require_true(self, int(fake_api.stations_call_count) == 1, "Repository sync contract must query the radio browser API exactly once on the first station sync"):
		return
	var stations := stations_result.get("stations", []) as Array
	if not T.require_true(self, stations.size() == 1, "Repository sync contract must preserve the API station count when materializing cache"):
		return
	var first_station: Dictionary = stations[0] as Dictionary
	if not T.require_true(self, str(first_station.get("station_id", "")) == "radio-browser:station-tl-001", "Repository sync contract must derive station_id from the remote stationuuid instead of inventing local demo ids"):
		return
	if not T.require_true(self, str(first_station.get("station_name", "")) == "Testland Drive", "Repository sync contract must map the remote station name into station snapshots"):
		return

	fake_api.fail_countries = true
	var stale_countries_result: Dictionary = repository.ensure_countries_ready(false, 1000 + 72 * 3600 + 1)
	if not T.require_true(self, bool(stale_countries_result.get("success", false)), "Repository sync contract must still surface stale countries cache if refresh fails after TTL expiry"):
		return
	if not T.require_true(self, bool(stale_countries_result.get("stale", false)), "Repository sync contract must mark stale countries fallback explicitly"):
		return
	if not T.require_true(self, str(stale_countries_result.get("fallback_kind", "")) == "stale_cache", "Repository sync contract must distinguish stale-cache fallback from a fresh sync"):
		return

	fake_api.fail_stations = true
	var stale_stations_result: Dictionary = repository.ensure_country_station_page_ready("XZ", false, 1000 + 72 * 3600 + 1)
	if not T.require_true(self, bool(stale_stations_result.get("success", false)), "Repository sync contract must still surface stale station pages if refresh fails after TTL expiry"):
		return
	if not T.require_true(self, bool(stale_stations_result.get("stale", false)), "Repository sync contract must mark stale station fallback explicitly"):
		return
	if not T.require_true(self, str(stale_stations_result.get("fallback_kind", "")) == "stale_cache", "Repository sync contract must distinguish stale station fallback from a fresh sync"):
		return

	T.pass_and_quit(self)
