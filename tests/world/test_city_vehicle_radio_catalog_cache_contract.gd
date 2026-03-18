extends SceneTree

const T := preload("res://tests/_test_util.gd")
const STORE_PATH := "res://city_game/world/radio/CityRadioCatalogStore.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var store_script := load(STORE_PATH)
	if not T.require_true(self, store_script != null, "Vehicle radio catalog cache contract requires CityRadioCatalogStore.gd"):
		return

	var store = store_script.new()
	if not T.require_true(self, store != null and store.has_method("build_countries_index_path"), "Vehicle radio catalog cache contract requires build_countries_index_path()"):
		return
	if not T.require_true(self, store.has_method("save_countries_index"), "Vehicle radio catalog cache contract requires save_countries_index()"):
		return
	if not T.require_true(self, store.has_method("load_countries_index"), "Vehicle radio catalog cache contract requires load_countries_index()"):
		return
	if not T.require_true(self, store.has_method("delete_countries_index"), "Vehicle radio catalog cache contract requires delete_countries_index()"):
		return
	if not T.require_true(self, store_script.has_method("install_test_scope"), "Vehicle radio catalog cache contract requires install_test_scope() so headless tests do not pollute the real runtime cache"):
		return
	if not T.require_true(self, store_script.has_method("clear_test_scope"), "Vehicle radio catalog cache contract requires clear_test_scope() so radio tests can restore the default cache root"):
		return
	if not T.require_true(self, store.has_method("save_country_station_page"), "Vehicle radio catalog cache contract requires save_country_station_page()"):
		return
	if not T.require_true(self, store.has_method("load_country_station_page"), "Vehicle radio catalog cache contract requires load_country_station_page()"):
		return
	if not T.require_true(self, store.has_method("delete_country_station_page"), "Vehicle radio catalog cache contract requires delete_country_station_page()"):
		return
	if not T.require_true(self, store.has_method("save_stream_resolve_cache"), "Vehicle radio catalog cache contract requires save_stream_resolve_cache()"):
		return
	if not T.require_true(self, store.has_method("load_stream_resolve_cache"), "Vehicle radio catalog cache contract requires load_stream_resolve_cache()"):
		return

	var countries_index_path := str(store.build_countries_index_path())
	var countries_meta_path := str(store.build_countries_meta_path())
	var station_index_path := str(store.build_country_station_index_path("CN"))
	var station_meta_path := str(store.build_country_station_meta_path("CN"))
	var resolve_cache_path := str(store.build_stream_resolve_cache_path())
	if not T.require_true(self, countries_index_path == "user://cache/radio/countries.index.json", "Countries index path must freeze to user://cache/radio/countries.index.json"):
		return
	if not T.require_true(self, countries_meta_path == "user://cache/radio/countries.meta.json", "Countries meta path must freeze to user://cache/radio/countries.meta.json"):
		return
	if not T.require_true(self, station_index_path == "user://cache/radio/countries/CN/stations.index.json", "Country station index path must freeze to user://cache/radio/countries/<country_code>/stations.index.json"):
		return
	if not T.require_true(self, station_meta_path == "user://cache/radio/countries/CN/stations.meta.json", "Country station meta path must freeze to user://cache/radio/countries/<country_code>/stations.meta.json"):
		return
	if not T.require_true(self, resolve_cache_path == "user://cache/radio/stream_resolve_cache.json", "Resolve cache path must freeze to user://cache/radio/stream_resolve_cache.json"):
		return
	store_script.install_test_scope("catalog_cache_contract")
	var scoped_store = store_script.new()
	if not T.require_true(self, str(scoped_store.build_countries_index_path()) == "user://cache/radio/test_scopes/catalog_cache_contract/countries.index.json", "Catalog test scope must redirect countries index writes away from the real runtime cache root"):
		return
	if not T.require_true(self, str(scoped_store.build_country_station_index_path("CN")) == "user://cache/radio/test_scopes/catalog_cache_contract/countries/CN/stations.index.json", "Catalog test scope must redirect station-page writes away from the real runtime cache root"):
		return
	store = scoped_store
	countries_index_path = str(store.build_countries_index_path())
	countries_meta_path = str(store.build_countries_meta_path())
	station_index_path = str(store.build_country_station_index_path("CN"))
	station_meta_path = str(store.build_country_station_meta_path("CN"))
	resolve_cache_path = str(store.build_stream_resolve_cache_path())

	var countries := [
		{"country_code": "CN", "display_name": "China", "station_count": 200},
		{"country_code": "JP", "display_name": "Japan", "station_count": 180},
	]
	var save_countries_result: Dictionary = store.save_countries_index(countries, 100, 72 * 3600)
	if not T.require_true(self, bool(save_countries_result.get("success", false)), "Countries index save must succeed"):
		return
	if not T.require_true(self, FileAccess.file_exists(countries_index_path), "Countries index JSON must exist on disk after save"):
		return
	if not _require_pretty_json(countries_index_path):
		return

	var fresh_countries: Dictionary = store.load_countries_index(110)
	if not T.require_true(self, bool(fresh_countries.get("hit", false)), "Fresh countries index must load as a cache hit"):
		return
	if not T.require_true(self, not bool(fresh_countries.get("stale", true)), "Fresh countries index must not be marked stale before TTL expiry"):
		return
	if not T.require_true(self, int((fresh_countries.get("countries", []) as Array).size()) == 2, "Countries index load must preserve country entry count"):
		return

	var stale_countries: Dictionary = store.load_countries_index(100 + 72 * 3600 + 1)
	if not T.require_true(self, bool(stale_countries.get("hit", false)), "Expired countries index must still be readable for stale fallback"):
		return
	if not T.require_true(self, bool(stale_countries.get("stale", false)), "Expired countries index must surface stale=true"):
		return
	var delete_countries_result: Dictionary = store.delete_countries_index()
	if not T.require_true(self, bool(delete_countries_result.get("success", false)), "Deleting countries index must succeed for fixture-cache hygiene"):
		return
	if not T.require_true(self, not FileAccess.file_exists(countries_index_path), "Deleting countries index must remove countries.index.json from disk"):
		return
	if not T.require_true(self, not FileAccess.file_exists(countries_meta_path), "Deleting countries index must remove countries.meta.json from disk"):
		return
	save_countries_result = store.save_countries_index(countries, 100, 72 * 3600)
	if not T.require_true(self, bool(save_countries_result.get("success", false)), "Countries index must still be writable after delete/recreate"):
		return

	var stations := [
		{
			"station_id": "station:cn:1",
			"station_name": "Xi'an Traffic FM",
			"country": "CN",
			"language": "zh",
			"codec": "aac",
			"votes": 42,
		},
	]
	var save_station_result: Dictionary = store.save_country_station_page("CN", stations, 220, 72 * 3600)
	if not T.require_true(self, bool(save_station_result.get("success", false)), "Country station page save must succeed"):
		return
	if not T.require_true(self, FileAccess.file_exists(station_index_path), "Country station index JSON must exist on disk after save"):
		return
	if not _require_pretty_json(station_index_path):
		return
	var station_page: Dictionary = store.load_country_station_page("CN", 240)
	if not T.require_true(self, bool(station_page.get("hit", false)), "Country station page must load as a cache hit after save"):
		return
	if not T.require_true(self, int((station_page.get("stations", []) as Array).size()) == 1, "Country station page load must preserve station count"):
		return
	var delete_station_result: Dictionary = store.delete_country_station_page("CN")
	if not T.require_true(self, bool(delete_station_result.get("success", false)), "Deleting country station page must succeed for fixture-cache hygiene"):
		return
	if not T.require_true(self, not FileAccess.file_exists(station_index_path), "Deleting country station page must remove stations.index.json from disk"):
		return
	if not T.require_true(self, not FileAccess.file_exists(station_meta_path), "Deleting country station page must remove stations.meta.json from disk"):
		return
	save_station_result = store.save_country_station_page("CN", stations, 220, 72 * 3600)
	if not T.require_true(self, bool(save_station_result.get("success", false)), "Country station page must still be writable after delete/recreate"):
		return

	var resolve_entries := {
		"station:cn:1": {
			"classification": "direct",
			"final_url": "https://radio.example/live.mp3",
			"resolved_at_unix_sec": 300,
		}
	}
	var save_resolve_result: Dictionary = store.save_stream_resolve_cache(resolve_entries, 300, 6 * 3600)
	if not T.require_true(self, bool(save_resolve_result.get("success", false)), "Resolve cache save must succeed"):
		return
	if not T.require_true(self, FileAccess.file_exists(resolve_cache_path), "Resolve cache JSON must exist on disk after save"):
		return
	if not _require_pretty_json(resolve_cache_path):
		return
	var resolve_cache: Dictionary = store.load_stream_resolve_cache(320)
	if not T.require_true(self, bool(resolve_cache.get("hit", false)), "Resolve cache must load as a cache hit after save"):
		return
	var entries: Dictionary = resolve_cache.get("entries", {}) as Dictionary
	if not T.require_true(self, entries.has("station:cn:1"), "Resolve cache load must preserve entry keys"):
		return

	T.pass_and_quit(self)

func _require_pretty_json(path: String) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	var text := FileAccess.get_file_as_string(global_path)
	if not T.require_true(self, text.contains("\n"), "Radio cache JSON must be multi-line pretty-print: %s" % path):
		return false
	if not T.require_true(self, text.contains("  \"") or text.contains("\t\""), "Radio cache JSON must contain indented object keys: %s" % path):
		return false
	return true
