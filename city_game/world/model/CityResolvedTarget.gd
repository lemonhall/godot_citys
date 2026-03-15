extends RefCounted

const SOURCE_VERSION := "v12-resolved-target-1"

static func build_from_place_entry(place_entry: Dictionary, source_kind: String, source_query: String, raw_world_anchor: Variant = null, selection_mode: String = "query") -> Dictionary:
	var world_anchor: Variant = place_entry.get("world_anchor", raw_world_anchor if raw_world_anchor != null else Vector3.ZERO)
	var routable_anchor: Variant = place_entry.get("routable_anchor", world_anchor)
	return {
		"source_kind": source_kind,
		"source_query": source_query,
		"place_id": str(place_entry.get("place_id", "")),
		"place_type": str(place_entry.get("place_type", source_kind)),
		"raw_world_anchor": raw_world_anchor,
		"world_anchor": world_anchor,
		"routable_anchor": routable_anchor,
		"selection_mode": selection_mode,
		"source_version": str(place_entry.get("source_version", SOURCE_VERSION)),
		"display_name": str(place_entry.get("display_name", "")),
		"normalized_name": str(place_entry.get("normalized_name", "")),
		"district_id": str(place_entry.get("district_id", "")),
	}

static func build_raw_world_point(raw_world_anchor: Vector3, routable_anchor: Vector3) -> Dictionary:
	return {
		"source_kind": "raw_world_point",
		"source_query": "",
		"place_id": "",
		"place_type": "raw_world_point",
		"raw_world_anchor": raw_world_anchor,
		"world_anchor": raw_world_anchor,
		"routable_anchor": routable_anchor,
		"selection_mode": "raw_world_point",
		"source_version": SOURCE_VERSION,
		"display_name": "",
		"normalized_name": "",
		"district_id": "",
	}
