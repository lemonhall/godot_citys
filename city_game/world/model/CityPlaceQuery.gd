extends RefCounted

const CityAddressGrammar := preload("res://city_game/world/model/CityAddressGrammar.gd")
const CityResolvedTarget := preload("res://city_game/world/model/CityResolvedTarget.gd")
const CityPlaceIndexBuilder := preload("res://city_game/world/generation/CityPlaceIndexBuilder.gd")

var _road_graph = null
var _block_layout = null
var _street_cluster_catalog = null
var _vehicle_query = null
var _place_index = null
var _address_grammar := CityAddressGrammar.new()

func setup(road_graph, block_layout, street_cluster_catalog, vehicle_query, place_index) -> void:
	_road_graph = road_graph
	_block_layout = block_layout
	_street_cluster_catalog = street_cluster_catalog
	_vehicle_query = vehicle_query
	_place_index = place_index

func get_debug_sample_queries() -> Dictionary:
	if _place_index == null or not _place_index.has_method("get_debug_sample_queries"):
		return {}
	return _place_index.get_debug_sample_queries()

func resolve_query(query: String) -> Dictionary:
	var trimmed := query.strip_edges()
	if trimmed == "" or _place_index == null:
		return {}
	var address_parts: Dictionary = _address_grammar.parse_address_query(trimmed)
	if not address_parts.is_empty():
		var address_target := _resolve_address_query(trimmed, address_parts)
		if not address_target.is_empty():
			return address_target
	var place_entry: Dictionary = _place_index.find_best_match(trimmed)
	if place_entry.is_empty():
		return {}
	return CityResolvedTarget.build_from_place_entry(place_entry, str(place_entry.get("place_type", "query")), trimmed, null, "query")

func resolve_world_point(world_position: Vector3) -> Dictionary:
	var routable_anchor := CityPlaceIndexBuilder.snap_world_anchor_to_driving_lane(_vehicle_query, world_position)
	return CityResolvedTarget.build_raw_world_point(world_position, routable_anchor)

func _resolve_address_query(source_query: String, address_parts: Dictionary) -> Dictionary:
	var decoded: Dictionary = _address_grammar.decode_house_number(int(address_parts.get("house_number", -1)))
	if decoded.is_empty():
		return {}
	var resolved := CityPlaceIndexBuilder.resolve_address_target_data(
		_block_layout,
		_road_graph,
		_street_cluster_catalog,
		_vehicle_query,
		int(decoded.get("block_serial_index", -1)),
		int(decoded.get("parcel_local_index", -1)),
		int(decoded.get("frontage_slot_index", 0))
	)
	if resolved.is_empty():
		return {}
	var address_record: Dictionary = resolved.get("address_record", {})
	if str(address_record.get("normalized_road_name", "")) != str(address_parts.get("normalized_road_name", "")):
		return {}
	var place_entry := {
		"place_id": str(address_record.get("place_id", "")),
		"place_type": "address",
		"display_name": str(address_record.get("display_name", "")),
		"normalized_name": str(address_record.get("normalized_display_name", "")),
		"world_anchor": resolved.get("world_anchor", Vector3.ZERO),
		"routable_anchor": resolved.get("routable_anchor", resolved.get("world_anchor", Vector3.ZERO)),
		"district_id": str((resolved.get("block_data", {}) as Dictionary).get("district_id", "")),
		"search_tokens": CityPlaceIndexBuilder.tokenize_string(str(address_record.get("display_name", ""))),
		"source_version": str(address_record.get("source_version", CityResolvedTarget.SOURCE_VERSION)),
	}
	return CityResolvedTarget.build_from_place_entry(place_entry, "address", source_query, null, "query")
