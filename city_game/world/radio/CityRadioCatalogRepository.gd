extends RefCounted
class_name CityRadioCatalogRepository

const CityRadioCatalogStoreScript := preload("res://city_game/world/radio/CityRadioCatalogStore.gd")
const CityRadioBrowserApiScript := preload("res://city_game/world/radio/CityRadioBrowserApi.gd")

const DEFAULT_STATIONS_LIMIT := 200

static var _test_api = null

var _store = null
var _api = null
var _stations_limit := DEFAULT_STATIONS_LIMIT

static func install_test_api(api) -> void:
	_test_api = api

static func clear_test_api() -> void:
	_test_api = null

func _init(store = null, api = null, stations_limit: int = DEFAULT_STATIONS_LIMIT) -> void:
	_store = store if store != null else CityRadioCatalogStoreScript.new()
	_api = api if api != null else (_test_api if _test_api != null else CityRadioBrowserApiScript.new())
	_stations_limit = clampi(stations_limit, 1, 500)

func supports_background_sync() -> bool:
	return _api is CityRadioBrowserApi

func ensure_countries_ready(force: bool = false, now_unix_sec: int = -1) -> Dictionary:
	var cached_result: Dictionary = _store.load_countries_index(now_unix_sec) if _store != null else {
		"hit": false,
		"stale": false,
		"countries": [],
		"error": "store_unavailable",
	}
	var cached_countries := (cached_result.get("countries", []) as Array).duplicate(true)
	if not force and bool(cached_result.get("hit", false)) and not bool(cached_result.get("stale", true)) and not cached_countries.is_empty():
		return _build_catalog_result(true, cached_countries, true, false, "fresh_cache", "")
	var api_result := _call_list_countries()
	if bool(api_result.get("success", false)):
		var mapped_countries := _map_countries(api_result.get("countries", []) as Array)
		if not mapped_countries.is_empty():
			var save_result: Dictionary = _store.save_countries_index(mapped_countries, _resolve_timestamp(now_unix_sec), CityRadioCatalogStore.DEFAULT_CATALOG_TTL_SEC)
			if bool(save_result.get("success", false)):
				return _build_catalog_result(true, mapped_countries, false, false, "fresh_sync", "")
			if not cached_countries.is_empty():
				return _build_catalog_result(true, cached_countries, true, bool(cached_result.get("stale", false)), "stale_cache", "save_failed")
			return _build_catalog_result(false, [], false, false, "", "save_failed")
	if not cached_countries.is_empty():
		return _build_catalog_result(true, cached_countries, true, bool(cached_result.get("stale", true)), "stale_cache", str(api_result.get("error", "countries_failed")))
	return _build_catalog_result(false, [], false, false, "", str(api_result.get("error", "countries_failed")))

func ensure_country_station_page_ready(country_code: String, force: bool = false, now_unix_sec: int = -1) -> Dictionary:
	var normalized_country_code := _normalize_country_code(country_code)
	if normalized_country_code == "":
		return _build_station_result(false, [], false, false, "", "invalid_country_code")
	var cached_result: Dictionary = _store.load_country_station_page(normalized_country_code, now_unix_sec) if _store != null else {
		"hit": false,
		"stale": false,
		"stations": [],
		"error": "store_unavailable",
	}
	var cached_stations := (cached_result.get("stations", []) as Array).duplicate(true)
	if not force and bool(cached_result.get("hit", false)) and not bool(cached_result.get("stale", true)):
		return _build_station_result(true, cached_stations, true, false, "fresh_cache", "")
	var countries_result := ensure_countries_ready(false, now_unix_sec)
	var countries := countries_result.get("countries", []) as Array
	var country_entry := _find_country_entry(countries, normalized_country_code)
	if country_entry.is_empty():
		if not cached_stations.is_empty():
			return _build_station_result(true, cached_stations, true, bool(cached_result.get("stale", true)), "stale_cache", "unknown_country")
		return _build_station_result(false, [], false, false, "", "unknown_country")
	var country_name := str(country_entry.get("display_name", "")).strip_edges()
	var api_result := _call_list_stations_by_country(country_name, _stations_limit)
	if bool(api_result.get("success", false)):
		var mapped_stations := _map_stations(
			api_result.get("stations", []) as Array,
			normalized_country_code,
			country_name
		)
		if not mapped_stations.is_empty():
			var save_result: Dictionary = _store.save_country_station_page(
				normalized_country_code,
				mapped_stations,
				_resolve_timestamp(now_unix_sec),
				CityRadioCatalogStore.DEFAULT_CATALOG_TTL_SEC
			)
			if bool(save_result.get("success", false)):
				return _build_station_result(true, mapped_stations, false, false, "fresh_sync", "")
			if not cached_stations.is_empty():
				return _build_station_result(true, cached_stations, true, bool(cached_result.get("stale", false)), "stale_cache", "save_failed")
			return _build_station_result(false, [], false, false, "", "save_failed")
	if not cached_stations.is_empty():
		return _build_station_result(true, cached_stations, true, bool(cached_result.get("stale", true)), "stale_cache", str(api_result.get("error", "stations_failed")))
	return _build_station_result(false, [], false, false, "", str(api_result.get("error", "stations_failed")))

func _call_list_countries() -> Dictionary:
	if _api == null or not _api.has_method("list_countries"):
		return {
			"success": false,
			"countries": [],
			"error": "api_unavailable",
		}
	var result: Variant = _api.list_countries()
	if result is Dictionary:
		var result_dict := result as Dictionary
		return {
			"success": bool(result_dict.get("success", false)),
			"countries": (result_dict.get("countries", []) as Array).duplicate(true),
			"error": str(result_dict.get("error", "")),
		}
	return {
		"success": false,
		"countries": [],
		"error": "invalid_api_result",
	}

func _call_list_stations_by_country(country_name: String, limit: int) -> Dictionary:
	if _api == null or not _api.has_method("list_stations_by_country"):
		return {
			"success": false,
			"stations": [],
			"error": "api_unavailable",
		}
	var result: Variant = _api.list_stations_by_country(country_name, limit)
	if result is Dictionary:
		var result_dict := result as Dictionary
		return {
			"success": bool(result_dict.get("success", false)),
			"stations": (result_dict.get("stations", []) as Array).duplicate(true),
			"error": str(result_dict.get("error", "")),
		}
	return {
		"success": false,
		"stations": [],
		"error": "invalid_api_result",
	}

func _map_countries(raw_countries: Array) -> Array:
	var mapped: Array = []
	var seen_codes := {}
	for country_variant in raw_countries:
		if not (country_variant is Dictionary):
			continue
		var country := country_variant as Dictionary
		var display_name := str(country.get("name", country.get("display_name", ""))).strip_edges()
		var normalized_country_code := _normalize_country_code(str(country.get("iso_3166_1", country.get("country_code", ""))))
		if display_name == "" or normalized_country_code == "":
			continue
		if seen_codes.has(normalized_country_code):
			continue
		seen_codes[normalized_country_code] = true
		mapped.append({
			"country_code": normalized_country_code,
			"display_name": display_name,
			"station_count": maxi(
				int(country.get("stationcount", 0)),
				int(country.get("station_count", 0))
			),
		})
	mapped.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).to_lower() < str(b.get("display_name", "")).to_lower()
	)
	return mapped

func _map_stations(raw_stations: Array, country_code: String, country_name: String) -> Array:
	var mapped: Array = []
	var seen_station_ids := {}
	for station_variant in raw_stations:
		if not (station_variant is Dictionary):
			continue
		var station := station_variant as Dictionary
		var station_uuid := str(station.get("stationuuid", station.get("station_id", ""))).strip_edges()
		var station_name := str(station.get("name", station.get("station_name", ""))).strip_edges()
		var stream_url := str(station.get("url_resolved", station.get("stream_url", station.get("url", "")))).strip_edges()
		if station_uuid == "" or station_name == "" or stream_url == "":
			continue
		var station_id := "radio-browser:%s" % station_uuid
		if seen_station_ids.has(station_id):
			continue
		seen_station_ids[station_id] = true
		mapped.append({
			"station_id": station_id,
			"station_name": station_name,
			"country": country_code,
			"country_name": str(station.get("country", country_name)).strip_edges(),
			"language": str(station.get("language", "")).strip_edges(),
			"codec": str(station.get("codec", "")).strip_edges(),
			"votes": int(station.get("votes", 0)),
			"stream_url": stream_url,
			"homepage_url": str(station.get("homepage", "")).strip_edges(),
			"favicon_url": str(station.get("favicon", "")).strip_edges(),
			"state": str(station.get("state", "")).strip_edges(),
			"tags": _normalize_tags(station.get("tags", [])),
		})
	return mapped

func _normalize_tags(tags_value: Variant) -> Array:
	if tags_value is Array:
		return (tags_value as Array).duplicate(true)
	var raw_tags := str(tags_value).strip_edges()
	if raw_tags == "":
		return []
	var normalized: Array = []
	var seen := {}
	for tag_variant in raw_tags.split(",", false):
		var tag := str(tag_variant).strip_edges()
		if tag == "" or seen.has(tag):
			continue
		seen[tag] = true
		normalized.append(tag)
		if normalized.size() >= 20:
			break
	return normalized

func _find_country_entry(countries: Array, country_code: String) -> Dictionary:
	for country_variant in countries:
		if not (country_variant is Dictionary):
			continue
		var country := country_variant as Dictionary
		if str(country.get("country_code", "")).strip_edges().to_upper() == country_code:
			return country.duplicate(true)
	return {}

func _build_catalog_result(success: bool, countries: Array, used_cache: bool, stale: bool, fallback_kind: String, error: String) -> Dictionary:
	return {
		"success": success,
		"countries": countries.duplicate(true),
		"used_cache": used_cache,
		"stale": stale,
		"fallback_kind": fallback_kind,
		"error": error,
	}

func _build_station_result(success: bool, stations: Array, used_cache: bool, stale: bool, fallback_kind: String, error: String) -> Dictionary:
	return {
		"success": success,
		"stations": stations.duplicate(true),
		"used_cache": used_cache,
		"stale": stale,
		"fallback_kind": fallback_kind,
		"error": error,
	}

func _resolve_timestamp(now_unix_sec: int) -> int:
	return now_unix_sec if now_unix_sec >= 0 else int(Time.get_unix_time_from_system())

func _normalize_country_code(country_code: String) -> String:
	var normalized := country_code.strip_edges().to_upper()
	if normalized.length() != 2:
		return ""
	return normalized
