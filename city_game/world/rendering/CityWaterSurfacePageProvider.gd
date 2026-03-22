extends RefCounted

var _entries_by_chunk_id: Dictionary = {}

func setup(terrain_region_runtime) -> void:
	_entries_by_chunk_id.clear()
	if terrain_region_runtime == null or not terrain_region_runtime.has_method("get_entries_snapshot"):
		return
	_configure_from_entries(terrain_region_runtime.get_entries_snapshot())

func configure(entries: Dictionary) -> void:
	_entries_by_chunk_id.clear()
	_configure_from_entries(entries)

func clear() -> void:
	_entries_by_chunk_id.clear()

func get_entries_for_chunk(chunk_id: String) -> Array:
	if chunk_id == "":
		return []
	var entries: Array = _entries_by_chunk_id.get(chunk_id, [])
	var snapshot: Array = []
	for entry_variant in entries:
		snapshot.append((entry_variant as Dictionary).duplicate(true))
	return snapshot

func _configure_from_entries(entries: Dictionary) -> void:
	for entry_variant in entries.values():
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var lake_contract_variant = entry.get("lake_runtime_contract", {})
		if not (lake_contract_variant is Dictionary):
			continue
		var lake_contract: Dictionary = (lake_contract_variant as Dictionary).duplicate(true)
		var render_owner_chunk_id := str(lake_contract.get("render_owner_chunk_id", lake_contract.get("anchor_chunk_id", ""))).strip_edges()
		if render_owner_chunk_id == "":
			continue
		var chunk_entries: Array = _entries_by_chunk_id.get(render_owner_chunk_id, [])
		chunk_entries.append({
			"region_id": str(entry.get("region_id", "")),
			"region_kind": str(entry.get("region_kind", "")),
			"water_level_y_m": float(lake_contract.get("water_level_y_m", 0.0)),
			"render_owner_chunk_id": render_owner_chunk_id,
			"polygon_world_points": (lake_contract.get("polygon_world_points", []) as Array).duplicate(true),
		})
		_entries_by_chunk_id[render_owner_chunk_id] = chunk_entries
