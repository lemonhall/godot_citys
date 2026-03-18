extends RefCounted

const FEATURE_KIND := "scene_interactive_prop"

var _entries_by_prop_id: Dictionary = {}
var _entries_by_chunk_id: Dictionary = {}
var _manifest_read_count := 0

func configure(registry_entries: Dictionary) -> void:
	_entries_by_prop_id.clear()
	_entries_by_chunk_id.clear()
	_manifest_read_count = 0
	var sorted_prop_ids: Array[String] = []
	for prop_id_variant in registry_entries.keys():
		var prop_id := str(prop_id_variant).strip_edges()
		if prop_id == "":
			continue
		sorted_prop_ids.append(prop_id)
	sorted_prop_ids.sort()
	for prop_id in sorted_prop_ids:
		var registry_entry: Dictionary = (registry_entries.get(prop_id, {}) as Dictionary).duplicate(true)
		var resolved_entry := _resolve_registry_entry(prop_id, registry_entry)
		if resolved_entry.is_empty():
			continue
		_entries_by_prop_id[prop_id] = resolved_entry
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
			return str(a.get("prop_id", "")) < str(b.get("prop_id", ""))
		)
		_entries_by_chunk_id[chunk_id] = chunk_entries

func get_entries_snapshot() -> Dictionary:
	return _entries_by_prop_id.duplicate(true)

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
		"entry_count": _entries_by_prop_id.size(),
		"chunk_count": _entries_by_chunk_id.size(),
		"manifest_read_count": _manifest_read_count,
	}

func _resolve_registry_entry(prop_id: String, registry_entry: Dictionary) -> Dictionary:
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
	var resolved_prop_id := str(manifest.get("prop_id", prop_id)).strip_edges()
	if resolved_prop_id == "":
		resolved_prop_id = prop_id
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
		"prop_id": resolved_prop_id,
		"display_name": str(manifest.get("display_name", resolved_prop_id)),
		"feature_kind": feature_kind,
		"anchor_chunk_id": str(manifest.get("anchor_chunk_id", "")),
		"anchor_chunk_key": anchor_chunk_key,
		"world_position": world_position,
		"surface_normal": surface_normal,
		"scene_root_offset": scene_root_offset,
		"scene_path": scene_path,
		"manifest_path": manifest_path,
		"interaction_kind": str(manifest.get("interaction_kind", "kick")),
		"interaction_radius_m": float(manifest.get("interaction_radius_m", 1.8)),
		"prompt_text": str(manifest.get("prompt_text", "")),
		"target_diameter_m": float(manifest.get("target_diameter_m", 0.22)),
		"physics_mass_kg": float(manifest.get("physics_mass_kg", 0.43)),
		"kick_impulse": float(manifest.get("kick_impulse", 1.7)),
		"kick_lift_impulse": float(manifest.get("kick_lift_impulse", 0.38)),
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
