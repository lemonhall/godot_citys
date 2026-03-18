extends RefCounted

const FEATURE_KIND := "scene_minigame_venue"

var _entries_by_venue_id: Dictionary = {}
var _entries_by_chunk_id: Dictionary = {}
var _manifest_read_count := 0

func configure(registry_entries: Dictionary) -> void:
	_entries_by_venue_id.clear()
	_entries_by_chunk_id.clear()
	_manifest_read_count = 0
	var sorted_venue_ids: Array[String] = []
	for venue_id_variant in registry_entries.keys():
		var venue_id := str(venue_id_variant).strip_edges()
		if venue_id == "":
			continue
		sorted_venue_ids.append(venue_id)
	sorted_venue_ids.sort()
	for venue_id in sorted_venue_ids:
		var registry_entry: Dictionary = (registry_entries.get(venue_id, {}) as Dictionary).duplicate(true)
		var resolved_entry := _resolve_registry_entry(venue_id, registry_entry)
		if resolved_entry.is_empty():
			continue
		_entries_by_venue_id[venue_id] = resolved_entry
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
			return str(a.get("venue_id", "")) < str(b.get("venue_id", ""))
		)
		_entries_by_chunk_id[chunk_id] = chunk_entries

func get_entries_snapshot() -> Dictionary:
	return _entries_by_venue_id.duplicate(true)

func get_entries_for_chunk(chunk_id: String) -> Array:
	if chunk_id == "":
		return []
	var chunk_entries: Array = _entries_by_chunk_id.get(chunk_id, [])
	var snapshot: Array = []
	for entry_variant in chunk_entries:
		var entry: Dictionary = entry_variant
		snapshot.append(entry.duplicate(true))
	return snapshot

func get_state() -> Dictionary:
	return {
		"entry_count": _entries_by_venue_id.size(),
		"chunk_count": _entries_by_chunk_id.size(),
		"manifest_read_count": _manifest_read_count,
	}

func _resolve_registry_entry(venue_id: String, registry_entry: Dictionary) -> Dictionary:
	var manifest_path := str(registry_entry.get("manifest_path", "")).strip_edges()
	if manifest_path == "":
		return {}
	var global_manifest_path := _globalize_path(manifest_path)
	if not FileAccess.file_exists(global_manifest_path):
		return {}
	var manifest_text := FileAccess.get_file_as_string(global_manifest_path)
	if manifest_text.strip_edges() == "":
		return {}
	var manifest_variant = JSON.parse_string(manifest_text)
	if not (manifest_variant is Dictionary):
		return {}
	_manifest_read_count += 1
	var manifest: Dictionary = manifest_variant
	var feature_kind := str(manifest.get("feature_kind", registry_entry.get("feature_kind", FEATURE_KIND))).strip_edges()
	if feature_kind == "":
		feature_kind = FEATURE_KIND
	if feature_kind != FEATURE_KIND:
		return {}
	var resolved_venue_id := str(manifest.get("venue_id", venue_id)).strip_edges()
	if resolved_venue_id == "":
		resolved_venue_id = venue_id
	var scene_path := str(manifest.get("scene_path", registry_entry.get("scene_path", ""))).strip_edges()
	if scene_path == "":
		return {}
	var world_position: Variant = _decode_vector3(manifest.get("world_position", null))
	var surface_normal: Variant = _decode_vector3(manifest.get("surface_normal", null))
	var scene_root_offset: Variant = _decode_vector3(manifest.get("scene_root_offset", null))
	var anchor_chunk_key: Variant = _decode_vector2i(manifest.get("anchor_chunk_key", null))
	if world_position == null or surface_normal == null or scene_root_offset == null or anchor_chunk_key == null:
		return {}
	return {
		"venue_id": resolved_venue_id,
		"display_name": str(manifest.get("display_name", resolved_venue_id)),
		"feature_kind": feature_kind,
		"game_kind": str(manifest.get("game_kind", "")),
		"anchor_chunk_id": str(manifest.get("anchor_chunk_id", "")),
		"anchor_chunk_key": anchor_chunk_key,
		"world_position": world_position,
		"surface_normal": surface_normal,
		"scene_root_offset": scene_root_offset,
		"scene_path": scene_path,
		"manifest_path": manifest_path,
		"primary_ball_prop_id": str(manifest.get("primary_ball_prop_id", "")),
		"yaw_rad": float(manifest.get("yaw_rad", 0.0)),
	}

func _decode_vector3(value: Variant) -> Variant:
	if value is Vector3:
		return value
	if not (value is Dictionary):
		return null
	var payload: Dictionary = value
	if str(payload.get("@type", "")) != "Vector3":
		return null
	return Vector3(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("z", 0.0))
	)

func _decode_vector2i(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if not (value is Dictionary):
		return null
	var payload: Dictionary = value
	if str(payload.get("@type", "")) != "Vector2i":
		return null
	return Vector2i(
		int(payload.get("x", 0)),
		int(payload.get("y", 0))
	)

func _globalize_path(path: String) -> String:
	var normalized := path.replace("\\", "/").trim_suffix("/").strip_edges()
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized)
	return normalized
