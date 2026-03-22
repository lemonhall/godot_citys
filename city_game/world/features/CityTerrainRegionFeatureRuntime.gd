extends RefCounted

const FEATURE_KIND := "terrain_region_feature"
const REGION_KIND_LAKE_BASIN := "lake_basin"
const CityLakeRegionRuntime := preload("res://city_game/world/features/lake/CityLakeRegionRuntime.gd")

var _entries_by_region_id: Dictionary = {}
var _entries_by_chunk_id: Dictionary = {}
var _lake_runtimes_by_region_id: Dictionary = {}
var _manifest_read_count := 0

func configure(registry_entries: Dictionary) -> void:
	_entries_by_region_id.clear()
	_entries_by_chunk_id.clear()
	_lake_runtimes_by_region_id.clear()
	_manifest_read_count = 0
	var sorted_region_ids: Array[String] = []
	for region_id_variant in registry_entries.keys():
		var region_id := str(region_id_variant).strip_edges()
		if region_id == "":
			continue
		sorted_region_ids.append(region_id)
	sorted_region_ids.sort()
	for region_id in sorted_region_ids:
		var registry_entry: Dictionary = (registry_entries.get(region_id, {}) as Dictionary).duplicate(true)
		var resolved_entry := _resolve_registry_entry(region_id, registry_entry)
		if resolved_entry.is_empty():
			continue
		_entries_by_region_id[region_id] = resolved_entry
		var anchor_chunk_id := str(resolved_entry.get("anchor_chunk_id", "")).strip_edges()
		if anchor_chunk_id == "":
			continue
		var chunk_entries: Array = _entries_by_chunk_id.get(anchor_chunk_id, [])
		chunk_entries.append(resolved_entry.duplicate(true))
		_entries_by_chunk_id[anchor_chunk_id] = chunk_entries
	for chunk_id_variant in _entries_by_chunk_id.keys():
		var chunk_id := str(chunk_id_variant)
		var chunk_entries: Array = _entries_by_chunk_id.get(chunk_id, [])
		chunk_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("region_id", "")) < str(b.get("region_id", ""))
		)
		_entries_by_chunk_id[chunk_id] = chunk_entries

func get_entries_snapshot() -> Dictionary:
	return _entries_by_region_id.duplicate(true)

func get_entries_for_chunk(chunk_id: String) -> Array:
	if chunk_id == "":
		return []
	var chunk_entries: Array = _entries_by_chunk_id.get(chunk_id, [])
	var snapshot: Array = []
	for entry_variant in chunk_entries:
		snapshot.append((entry_variant as Dictionary).duplicate(true))
	return snapshot

func has_entries_for_chunk(chunk_id: String) -> bool:
	if chunk_id == "":
		return false
	return _entries_by_chunk_id.has(chunk_id)

func get_state() -> Dictionary:
	return {
		"entry_count": _entries_by_region_id.size(),
		"chunk_count": _entries_by_chunk_id.size(),
		"manifest_read_count": _manifest_read_count,
	}

func get_lake_runtimes() -> Array:
	var runtimes: Array = []
	var sorted_region_ids: Array[String] = []
	for region_id_variant in _lake_runtimes_by_region_id.keys():
		sorted_region_ids.append(str(region_id_variant))
	sorted_region_ids.sort()
	for region_id in sorted_region_ids:
		runtimes.append(_lake_runtimes_by_region_id[region_id])
	return runtimes

func get_lake_runtime(region_id: String):
	if region_id == "":
		return null
	return _lake_runtimes_by_region_id.get(region_id)

func query_water_state(world_position: Vector3) -> Dictionary:
	var best_state := {
		"in_water": false,
		"underwater": false,
		"region_id": "",
		"world_position": world_position,
	}
	for runtime_variant in _lake_runtimes_by_region_id.values():
		var runtime = runtime_variant
		if runtime == null or not runtime.has_method("query_water_state"):
			continue
		var state: Dictionary = runtime.query_water_state(world_position)
		if bool(state.get("in_water", false)):
			return state.duplicate(true)
	return best_state

func _resolve_registry_entry(region_id: String, registry_entry: Dictionary) -> Dictionary:
	var manifest_path := str(registry_entry.get("manifest_path", "")).strip_edges()
	if manifest_path == "":
		return {}
	var lake_runtime := CityLakeRegionRuntime.new()
	if not lake_runtime.load_from_manifest(manifest_path):
		return {}
	_manifest_read_count += 1
	var runtime_contract: Dictionary = lake_runtime.get_runtime_contract()
	var feature_kind := str(runtime_contract.get("feature_kind", registry_entry.get("feature_kind", FEATURE_KIND))).strip_edges()
	if feature_kind == "" or feature_kind != FEATURE_KIND:
		return {}
	var resolved_region_id := str(runtime_contract.get("region_id", region_id)).strip_edges()
	if resolved_region_id == "":
		return {}
	var region_kind := str(runtime_contract.get("region_kind", registry_entry.get("region_kind", ""))).strip_edges()
	if region_kind == REGION_KIND_LAKE_BASIN:
		_lake_runtimes_by_region_id[resolved_region_id] = lake_runtime
	return {
		"region_id": resolved_region_id,
		"display_name": str(runtime_contract.get("display_name", resolved_region_id)),
		"feature_kind": feature_kind,
		"region_kind": region_kind,
		"anchor_chunk_id": str(runtime_contract.get("anchor_chunk_id", "")),
		"anchor_chunk_key": runtime_contract.get("anchor_chunk_key", Vector2i.ZERO),
		"world_position": runtime_contract.get("world_position", Vector3.ZERO),
		"surface_normal": runtime_contract.get("surface_normal", Vector3.UP),
		"manifest_path": manifest_path,
		"water_level_y_m": float(runtime_contract.get("water_level_y_m", 0.0)),
		"mean_depth_m": float(runtime_contract.get("mean_depth_m", 0.0)),
		"max_depth_m": float(runtime_contract.get("max_depth_m", 0.0)),
		"linked_venue_ids": (runtime_contract.get("linked_venue_ids", []) as Array).duplicate(true),
		"render_owner_chunk_id": str(runtime_contract.get("render_owner_chunk_id", "")),
		"lake_runtime_contract": runtime_contract.duplicate(true),
	}
