extends RefCounted

const FEATURE_KIND := "scene_landmark"
const PIN_TYPE := "landmark"
const PIN_SOURCE := "scene_landmark_manifest"
const VISIBILITY_SCOPE := "full_map"
const DEFAULT_PRIORITY := 68

var _entries_by_landmark_id: Dictionary = {}
var _entries_by_chunk_id: Dictionary = {}
var _manifest_read_count := 0

func configure(registry_entries: Dictionary) -> void:
	_entries_by_landmark_id.clear()
	_entries_by_chunk_id.clear()
	_manifest_read_count = 0
	var sorted_landmark_ids: Array[String] = []
	for landmark_id_variant in registry_entries.keys():
		var landmark_id := str(landmark_id_variant).strip_edges()
		if landmark_id == "":
			continue
		sorted_landmark_ids.append(landmark_id)
	sorted_landmark_ids.sort()
	for landmark_id in sorted_landmark_ids:
		var registry_entry: Dictionary = (registry_entries.get(landmark_id, {}) as Dictionary).duplicate(true)
		var resolved_entry := _resolve_registry_entry(landmark_id, registry_entry)
		if resolved_entry.is_empty():
			continue
		_entries_by_landmark_id[landmark_id] = resolved_entry
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
			return str(a.get("landmark_id", "")) < str(b.get("landmark_id", ""))
		)
		_entries_by_chunk_id[chunk_id] = chunk_entries

func get_entries_snapshot() -> Dictionary:
	return _entries_by_landmark_id.duplicate(true)

func get_entries_for_chunk(chunk_id: String) -> Array:
	if chunk_id == "":
		return []
	var chunk_entries: Array = _entries_by_chunk_id.get(chunk_id, [])
	var snapshot: Array = []
	for entry_variant in chunk_entries:
		var entry: Dictionary = entry_variant
		snapshot.append(entry.duplicate(true))
	return snapshot

func get_full_map_pins() -> Array[Dictionary]:
	var pins: Array[Dictionary] = []
	for entry_variant in _entries_by_landmark_id.values():
		var entry: Dictionary = entry_variant
		var pin := _build_pin_from_entry(entry)
		if pin.is_empty():
			continue
		pins.append(pin)
	pins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := int(a.get("priority", 0))
		var b_priority := int(b.get("priority", 0))
		if a_priority == b_priority:
			return str(a.get("pin_id", "")) < str(b.get("pin_id", ""))
		return a_priority < b_priority
	)
	return pins

func get_state() -> Dictionary:
	return {
		"entry_count": _entries_by_landmark_id.size(),
		"chunk_count": _entries_by_chunk_id.size(),
		"manifest_read_count": _manifest_read_count,
		"pin_count": get_full_map_pins().size(),
	}

func _resolve_registry_entry(landmark_id: String, registry_entry: Dictionary) -> Dictionary:
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
	var resolved_landmark_id := str(manifest.get("landmark_id", landmark_id)).strip_edges()
	if resolved_landmark_id == "":
		resolved_landmark_id = landmark_id
	var scene_path := str(manifest.get("scene_path", registry_entry.get("scene_path", ""))).strip_edges()
	if scene_path == "":
		return {}
	var world_position: Variant = _decode_vector3(manifest.get("world_position", null))
	if world_position == null:
		return {}
	var full_map_pin: Dictionary = {}
	var full_map_pin_variant = manifest.get("full_map_pin", {})
	if full_map_pin_variant is Dictionary:
		full_map_pin = (full_map_pin_variant as Dictionary).duplicate(true)
	var far_visibility: Dictionary = {}
	var far_visibility_variant = manifest.get("far_visibility", {})
	if far_visibility_variant is Dictionary:
		far_visibility = (far_visibility_variant as Dictionary).duplicate(true)
	var persistent_mount: Dictionary = {}
	var persistent_mount_variant = manifest.get("persistent_mount", {})
	if persistent_mount_variant is Dictionary:
		persistent_mount = (persistent_mount_variant as Dictionary).duplicate(true)
	return {
		"landmark_id": resolved_landmark_id,
		"display_name": str(manifest.get("display_name", resolved_landmark_id)),
		"feature_kind": feature_kind,
		"anchor_chunk_id": str(manifest.get("anchor_chunk_id", "")),
		"anchor_chunk_key": _decode_vector2i(manifest.get("anchor_chunk_key", null)),
		"world_position": world_position,
		"scene_path": scene_path,
		"manifest_path": manifest_path,
		"music_road_definition_path": str(manifest.get("music_road_definition_path", "")),
		"full_map_pin": full_map_pin,
		"far_visibility": far_visibility,
		"persistent_mount": persistent_mount,
		"yaw_rad": float(manifest.get("yaw_rad", 0.0)),
	}

func _build_pin_from_entry(entry: Dictionary) -> Dictionary:
	var full_map_pin_variant = entry.get("full_map_pin", {})
	if not (full_map_pin_variant is Dictionary):
		return {}
	var full_map_pin: Dictionary = full_map_pin_variant
	if not bool(full_map_pin.get("visible", false)):
		return {}
	var icon_id := str(full_map_pin.get("icon_id", "")).strip_edges()
	if icon_id == "":
		return {}
	var landmark_id := str(entry.get("landmark_id", "")).strip_edges()
	if landmark_id == "":
		return {}
	var world_position: Variant = _decode_vector3(full_map_pin.get("world_position", null))
	if world_position == null:
		world_position = entry.get("world_position", null)
	if not (world_position is Vector3):
		return {}
	var display_name := str(entry.get("display_name", landmark_id)).strip_edges()
	var title := str(full_map_pin.get("title", "")).strip_edges()
	if title == "":
		title = display_name
	var subtitle := str(full_map_pin.get("subtitle", "")).strip_edges()
	if subtitle == "":
		subtitle = display_name
	return {
		"pin_id": "scene_landmark:%s" % landmark_id,
		"pin_type": PIN_TYPE,
		"pin_source": PIN_SOURCE,
		"visibility_scope": VISIBILITY_SCOPE,
		"landmark_id": landmark_id,
		"world_position": world_position,
		"title": title,
		"subtitle": subtitle,
		"priority": int(full_map_pin.get("priority", DEFAULT_PRIORITY)),
		"icon_id": icon_id,
		"is_selectable": false,
		"route_target_override": {},
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
