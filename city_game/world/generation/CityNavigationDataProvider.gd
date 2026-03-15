extends RefCounted

const CityStreetClusterBuilder := preload("res://city_game/world/generation/CityStreetClusterBuilder.gd")
const CityPlaceIndexBuilder := preload("res://city_game/world/generation/CityPlaceIndexBuilder.gd")
const CityPlaceIndexCache := preload("res://city_game/world/generation/CityPlaceIndexCache.gd")
const CityPlaceQuery := preload("res://city_game/world/model/CityPlaceQuery.gd")

var _config = null
var _road_graph = null
var _block_layout = null
var _vehicle_query = null
var _name_candidate_catalog: Dictionary = {}
var _generation_profile: Dictionary = {}
var _street_cluster_catalog = null
var _place_index = null
var _place_query = null

func _init(config = null, road_graph = null, block_layout = null, vehicle_query = null, name_candidate_catalog: Dictionary = {}, generation_profile: Dictionary = {}) -> void:
	if config != null:
		setup(config, road_graph, block_layout, vehicle_query, name_candidate_catalog, generation_profile)

func setup(config, road_graph, block_layout, vehicle_query, name_candidate_catalog: Dictionary = {}, generation_profile: Dictionary = {}) -> void:
	_config = config
	_road_graph = road_graph
	_block_layout = block_layout
	_vehicle_query = vehicle_query
	_name_candidate_catalog = name_candidate_catalog.duplicate(true)
	_generation_profile = generation_profile

func get_street_cluster_catalog():
	_ensure_street_cluster_catalog()
	return _street_cluster_catalog

func get_place_index():
	_ensure_place_index()
	return _place_index

func get_place_query():
	_ensure_place_query()
	return _place_query

func _ensure_street_cluster_catalog() -> void:
	if _street_cluster_catalog != null:
		return
	var started_usec := Time.get_ticks_usec()
	_street_cluster_catalog = CityStreetClusterBuilder.new().build_catalog(_config, _road_graph, _block_layout, _name_candidate_catalog)
	var duration_usec := Time.get_ticks_usec() - started_usec
	_generation_profile["street_cluster_usec"] = duration_usec
	_generation_profile["street_cluster_count"] = _street_cluster_catalog.get_cluster_count() if _street_cluster_catalog != null and _street_cluster_catalog.has_method("get_cluster_count") else 0

func _ensure_place_index() -> void:
	if _place_index != null:
		return
	_ensure_street_cluster_catalog()
	var cache := CityPlaceIndexCache.new()
	var cache_signature := cache.build_world_signature(_config)
	var cache_load_started_usec := Time.get_ticks_usec()
	var cached_result := cache.load_place_index(_config)
	var cache_load_usec := Time.get_ticks_usec() - cache_load_started_usec
	if bool(cached_result.get("hit", false)):
		_place_index = cached_result.get("place_index")
		_generation_profile["place_index_usec"] = cache_load_usec
		_generation_profile["place_index_build_usec"] = 0
		_generation_profile["place_index_cache_hit"] = true
		_generation_profile["place_index_cache_load_usec"] = cache_load_usec
		_generation_profile["place_index_cache_write_usec"] = 0
		_generation_profile["place_index_cache_path"] = str(cached_result.get("path", ""))
		_generation_profile["place_index_cache_signature"] = str(cached_result.get("world_signature", cache_signature))
		_generation_profile["place_index_cache_size_bytes"] = int(cached_result.get("size_bytes", 0))
		return

	var build_started_usec := Time.get_ticks_usec()
	_place_index = CityPlaceIndexBuilder.new().build_index(
		_config,
		_road_graph,
		_block_layout,
		_street_cluster_catalog,
		_name_candidate_catalog,
		_vehicle_query
	)
	var build_usec := Time.get_ticks_usec() - build_started_usec
	var cache_write_started_usec := Time.get_ticks_usec()
	var save_result := cache.save_place_index(_config, _place_index)
	var cache_write_usec := Time.get_ticks_usec() - cache_write_started_usec
	_generation_profile["place_index_usec"] = build_usec + cache_write_usec
	_generation_profile["place_index_build_usec"] = build_usec
	_generation_profile["place_index_cache_hit"] = false
	_generation_profile["place_index_cache_load_usec"] = cache_load_usec
	_generation_profile["place_index_cache_write_usec"] = cache_write_usec
	_generation_profile["place_index_cache_path"] = str(save_result.get("path", ""))
	_generation_profile["place_index_cache_signature"] = str(save_result.get("world_signature", cache_signature))
	_generation_profile["place_index_cache_size_bytes"] = int(save_result.get("size_bytes", 0))

func _ensure_place_query() -> void:
	if _place_query != null:
		return
	_ensure_place_index()
	var started_usec := Time.get_ticks_usec()
	_place_query = CityPlaceQuery.new()
	_place_query.setup(_road_graph, _block_layout, _street_cluster_catalog, _vehicle_query, _place_index)
	_generation_profile["place_query_usec"] = Time.get_ticks_usec() - started_usec
