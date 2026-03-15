extends RefCounted

const CityAddressGrammar := preload("res://city_game/world/model/CityAddressGrammar.gd")
const SOURCE_VERSION := "v12-place-index-1"

var _entries: Array[Dictionary] = []
var _entries_by_id: Dictionary = {}
var _place_ids_by_normalized_name: Dictionary = {}
var _place_ids_by_token: Dictionary = {}
var _place_ids_by_type: Dictionary = {}
var _debug_sample_queries: Dictionary = {}
var _cache_contract: Dictionary = {}
var _source_version := SOURCE_VERSION

func setup(entries: Array, debug_sample_queries: Dictionary = {}, cache_contract: Dictionary = {}, source_version: String = SOURCE_VERSION) -> void:
	_entries.clear()
	_entries_by_id.clear()
	_place_ids_by_normalized_name.clear()
	_place_ids_by_token.clear()
	_place_ids_by_type.clear()
	_debug_sample_queries = debug_sample_queries.duplicate(true)
	_cache_contract = cache_contract.duplicate(true)
	_source_version = source_version
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var stored := (entry_variant as Dictionary).duplicate(true)
		var place_id := str(stored.get("place_id", ""))
		if place_id == "":
			continue
		var place_type := str(stored.get("place_type", "place"))
		var normalized_name := str(stored.get("normalized_name", ""))
		var search_tokens := _normalize_search_tokens(stored.get("search_tokens", []))
		stored["place_id"] = place_id
		stored["place_type"] = place_type
		stored["normalized_name"] = normalized_name
		stored["search_tokens"] = search_tokens.duplicate()
		stored["source_version"] = str(stored.get("source_version", _source_version))
		_entries.append(stored)
		_entries_by_id[place_id] = stored
		if not _place_ids_by_type.has(place_type):
			_place_ids_by_type[place_type] = []
		(_place_ids_by_type[place_type] as Array).append(place_id)
		if normalized_name != "":
			_register_lookup_value(_place_ids_by_normalized_name, normalized_name, place_id)
		for token in search_tokens:
			_register_lookup_value(_place_ids_by_token, str(token), place_id)

func load_from_cache_payload(payload: Dictionary) -> void:
	setup(
		payload.get("entries", []),
		payload.get("debug_sample_queries", {}),
		payload.get("cache_contract", {}),
		str(payload.get("source_version", SOURCE_VERSION))
	)

func to_cache_payload() -> Dictionary:
	return {
		"source_version": _source_version,
		"entries": get_entries(),
		"debug_sample_queries": get_debug_sample_queries(),
		"cache_contract": get_cache_contract(),
	}

func set_cache_contract(cache_contract: Dictionary) -> void:
	_cache_contract = cache_contract.duplicate(true)

func get_cache_contract() -> Dictionary:
	return _cache_contract.duplicate(true)

func get_debug_sample_queries() -> Dictionary:
	return _debug_sample_queries.duplicate(true)

func get_entry_count() -> int:
	return _entries.size()

func get_entries() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry_variant in _entries:
		results.append((entry_variant as Dictionary).duplicate(true))
	return results

func get_entry_by_id(place_id: String) -> Dictionary:
	if not _entries_by_id.has(place_id):
		return {}
	return (_entries_by_id[place_id] as Dictionary).duplicate(true)

func get_entries_for_type(place_type: String) -> Array[Dictionary]:
	if not _place_ids_by_type.has(place_type):
		return []
	var results: Array[Dictionary] = []
	for place_id_variant in _place_ids_by_type[place_type]:
		var place_id := str(place_id_variant)
		if _entries_by_id.has(place_id):
			results.append((_entries_by_id[place_id] as Dictionary).duplicate(true))
	return results

func get_entries_intersecting_rect(rect: Rect2, allowed_types: Array = []) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry_variant in _entries:
		var entry: Dictionary = entry_variant
		var place_type := str(entry.get("place_type", ""))
		if not allowed_types.is_empty() and not allowed_types.has(place_type):
			continue
		var world_anchor: Vector3 = entry.get("world_anchor", Vector3.ZERO)
		if rect.has_point(Vector2(world_anchor.x, world_anchor.z)):
			results.append(entry.duplicate(true))
	return results

func find_best_match(query: String, allowed_types: Array = []) -> Dictionary:
	var normalized_query := _normalize_query(query)
	if normalized_query == "":
		return {}
	var exact_match := _pick_best_scored_match(_resolve_candidate_ids_for_query(normalized_query, true), normalized_query, allowed_types)
	if not exact_match.is_empty():
		return exact_match
	return _pick_best_scored_match(_resolve_candidate_ids_for_query(normalized_query, false), normalized_query, allowed_types)

func _resolve_candidate_ids_for_query(normalized_query: String, exact_only: bool) -> Array[String]:
	var candidate_map: Dictionary = {}
	if _place_ids_by_normalized_name.has(normalized_query):
		for place_id_variant in _place_ids_by_normalized_name[normalized_query]:
			candidate_map[str(place_id_variant)] = true
	if exact_only:
		return _collect_sorted_candidate_ids(candidate_map)
	for token in normalized_query.split(" ", false):
		if not _place_ids_by_token.has(token):
			continue
		for place_id_variant in _place_ids_by_token[token]:
			candidate_map[str(place_id_variant)] = true
	return _collect_sorted_candidate_ids(candidate_map)

func _pick_best_scored_match(candidate_ids: Array[String], normalized_query: String, allowed_types: Array = []) -> Dictionary:
	var query_tokens := normalized_query.split(" ", false)
	var best_score := -INF
	var best_entry := {}
	for place_id in candidate_ids:
		if not _entries_by_id.has(place_id):
			continue
		var entry: Dictionary = _entries_by_id[place_id]
		var place_type := str(entry.get("place_type", ""))
		if not allowed_types.is_empty() and not allowed_types.has(place_type):
			continue
		var normalized_name := str(entry.get("normalized_name", ""))
		var entry_tokens := _normalize_search_tokens(entry.get("search_tokens", []))
		var score := 0.0
		if normalized_name == normalized_query:
			score += 10000.0
		var matched_token_count := 0
		var all_tokens_present := not query_tokens.is_empty()
		for token in query_tokens:
			if entry_tokens.has(token):
				matched_token_count += 1
			else:
				all_tokens_present = false
		if all_tokens_present:
			score += 1000.0 + float(matched_token_count) * 25.0
		else:
			score += float(matched_token_count) * 10.0
		score += _place_type_priority(place_type)
		if score > best_score:
			best_score = score
			best_entry = entry.duplicate(true)
	return best_entry

func _collect_sorted_candidate_ids(candidate_map: Dictionary) -> Array[String]:
	var candidate_ids: Array[String] = []
	for place_id_variant in candidate_map.keys():
		candidate_ids.append(str(place_id_variant))
	candidate_ids.sort()
	return candidate_ids

func _register_lookup_value(target: Dictionary, key: String, place_id: String) -> void:
	if key == "":
		return
	if not target.has(key):
		target[key] = []
	var entries: Array = target[key]
	if not entries.has(place_id):
		entries.append(place_id)
	target[key] = entries

func _normalize_query(value: String) -> String:
	return CityAddressGrammar.new().normalize_name(value)

func _normalize_search_tokens(tokens_variant: Variant) -> Array[String]:
	var normalized_tokens: Array[String] = []
	var seen: Dictionary = {}
	if tokens_variant is Array:
		for token_variant in tokens_variant:
			var token := _normalize_query(str(token_variant))
			if token == "" or seen.has(token):
				continue
			seen[token] = true
			normalized_tokens.append(token)
	return normalized_tokens

func _place_type_priority(place_type: String) -> float:
	match place_type:
		"address":
			return 4.0
		"landmark":
			return 3.0
		"intersection":
			return 2.0
		"road":
			return 1.0
	return 0.0
