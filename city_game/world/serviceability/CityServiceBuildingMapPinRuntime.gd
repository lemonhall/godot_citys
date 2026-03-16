extends RefCounted

const PIN_TYPE := "service_building"
const PIN_SOURCE := "service_building_manifest"
const VISIBILITY_SCOPE := "full_map"
const DEFAULT_PRIORITY := 72

var _entries_by_building_id: Dictionary = {}
var _processed_signatures: Dictionary = {}
var _pins_by_building_id: Dictionary = {}
var _pending_building_ids: Array[String] = []
var _manifest_read_count := 0

func configure(entries: Dictionary) -> void:
	var normalized_entries: Dictionary = {}
	var sorted_building_ids: Array[String] = []
	for building_id_variant in entries.keys():
		var building_id := str(building_id_variant)
		if building_id == "":
			continue
		var entry: Dictionary = (entries.get(building_id_variant, {}) as Dictionary).duplicate(true)
		if entry.is_empty():
			continue
		entry["building_id"] = building_id
		normalized_entries[building_id] = entry
		sorted_building_ids.append(building_id)
	sorted_building_ids.sort()
	_entries_by_building_id = normalized_entries
	_pending_building_ids.clear()

	var stale_building_ids: Array[String] = []
	for building_id_variant in _processed_signatures.keys():
		var building_id := str(building_id_variant)
		if normalized_entries.has(building_id):
			continue
		stale_building_ids.append(building_id)
	for building_id in stale_building_ids:
		_processed_signatures.erase(building_id)
		_pins_by_building_id.erase(building_id)

	for building_id in sorted_building_ids:
		var signature := _build_entry_signature(normalized_entries.get(building_id, {}))
		if signature == "" or str(_processed_signatures.get(building_id, "")) == signature:
			continue
		_processed_signatures.erase(building_id)
		_pins_by_building_id.erase(building_id)
		_pending_building_ids.append(building_id)

func advance(max_entries: int = 1, time_budget_usec: int = 0) -> Dictionary:
	var resolved_max_entries := maxi(max_entries, 0)
	var processed_in_batch := 0
	var did_change := false
	var did_pin_delta := false
	var pin_upserts: Array[Dictionary] = []
	var pin_remove_ids: Array[String] = []
	var batch_started_usec := Time.get_ticks_usec()
	while processed_in_batch < resolved_max_entries and not _pending_building_ids.is_empty():
		if time_budget_usec > 0 and processed_in_batch > 0 and Time.get_ticks_usec() - batch_started_usec >= time_budget_usec:
			break
		var building_id: String = str(_pending_building_ids.pop_front())
		var entry: Dictionary = (_entries_by_building_id.get(building_id, {}) as Dictionary).duplicate(true)
		var signature := _build_entry_signature(entry)
		var pin_delta := _process_entry(building_id, entry)
		var upsert_pin_variant = pin_delta.get("upsert_pin", {})
		if upsert_pin_variant is Dictionary and not (upsert_pin_variant as Dictionary).is_empty():
			pin_upserts.append((upsert_pin_variant as Dictionary).duplicate(true))
			did_pin_delta = true
		var remove_pin_id := str(pin_delta.get("remove_pin_id", "")).strip_edges()
		if remove_pin_id != "":
			pin_remove_ids.append(remove_pin_id)
			did_pin_delta = true
		if signature != "":
			_processed_signatures[building_id] = signature
		processed_in_batch += 1
		did_change = true
	return {
		"did_change": did_change,
		"did_pin_delta": did_pin_delta,
		"processed_in_batch": processed_in_batch,
		"pin_upserts": pin_upserts,
		"pin_remove_ids": pin_remove_ids,
		"state": get_state(),
	}

func get_pins() -> Array[Dictionary]:
	var pins: Array[Dictionary] = []
	for pin_variant in _pins_by_building_id.values():
		var pin: Dictionary = pin_variant
		pins.append(pin.duplicate(true))
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
		"loading": not _pending_building_ids.is_empty(),
		"pending_entry_count": _pending_building_ids.size(),
		"loaded_entry_count": _count_loaded_entries(),
		"pin_count": _pins_by_building_id.size(),
		"manifest_read_count": _manifest_read_count,
	}

func _count_loaded_entries() -> int:
	var loaded_count := 0
	for building_id_variant in _entries_by_building_id.keys():
		var building_id := str(building_id_variant)
		var signature := _build_entry_signature(_entries_by_building_id.get(building_id, {}))
		if signature != "" and str(_processed_signatures.get(building_id, "")) == signature:
			loaded_count += 1
	return loaded_count

func _process_entry(building_id: String, entry: Dictionary) -> Dictionary:
	var previous_pin: Dictionary = (_pins_by_building_id.get(building_id, {}) as Dictionary).duplicate(true)
	var manifest_path := str(entry.get("manifest_path", "")).strip_edges()
	if manifest_path == "":
		_pins_by_building_id.erase(building_id)
		return _build_remove_delta(previous_pin)
	var global_manifest_path := _globalize_path(manifest_path)
	if not FileAccess.file_exists(global_manifest_path):
		_pins_by_building_id.erase(building_id)
		return _build_remove_delta(previous_pin)
	_manifest_read_count += 1
	var manifest_text := FileAccess.get_file_as_string(global_manifest_path)
	if manifest_text.strip_edges() == "":
		_pins_by_building_id.erase(building_id)
		return _build_remove_delta(previous_pin)
	var manifest_variant = JSON.parse_string(manifest_text)
	if not (manifest_variant is Dictionary):
		_pins_by_building_id.erase(building_id)
		return _build_remove_delta(previous_pin)
	var pin := _build_pin_from_manifest(building_id, manifest_variant as Dictionary)
	if pin.is_empty():
		_pins_by_building_id.erase(building_id)
		return _build_remove_delta(previous_pin)
	_pins_by_building_id[building_id] = pin
	var delta := {
		"upsert_pin": pin.duplicate(true),
	}
	var previous_pin_id := str(previous_pin.get("pin_id", "")).strip_edges()
	var current_pin_id := str(pin.get("pin_id", "")).strip_edges()
	if previous_pin_id != "" and previous_pin_id != current_pin_id:
		delta["remove_pin_id"] = previous_pin_id
	return delta

func _build_remove_delta(previous_pin: Dictionary) -> Dictionary:
	var previous_pin_id := str(previous_pin.get("pin_id", "")).strip_edges()
	if previous_pin_id == "":
		return {}
	return {
		"remove_pin_id": previous_pin_id,
	}

func _build_pin_from_manifest(building_id: String, manifest: Dictionary) -> Dictionary:
	var full_map_pin_variant = manifest.get("full_map_pin", {})
	if not (full_map_pin_variant is Dictionary):
		return {}
	var full_map_pin: Dictionary = full_map_pin_variant
	if not bool(full_map_pin.get("visible", false)):
		return {}
	var icon_id := str(full_map_pin.get("icon_id", "")).strip_edges()
	if icon_id == "":
		return {}
	var world_position: Variant = _resolve_manifest_world_position(manifest)
	if world_position == null:
		return {}
	var resolved_building_id := str(manifest.get("building_id", building_id)).strip_edges()
	if resolved_building_id == "":
		resolved_building_id = building_id
	var display_name := str(manifest.get("display_name", "")).strip_edges()
	var title := str(full_map_pin.get("title", "")).strip_edges()
	if title == "":
		title = display_name
	var subtitle := str(full_map_pin.get("subtitle", "")).strip_edges()
	if subtitle == "":
		subtitle = display_name
	return {
		"pin_id": "service_building:%s" % resolved_building_id,
		"pin_type": PIN_TYPE,
		"pin_source": PIN_SOURCE,
		"visibility_scope": VISIBILITY_SCOPE,
		"building_id": resolved_building_id,
		"world_position": world_position,
		"title": title,
		"subtitle": subtitle,
		"priority": int(full_map_pin.get("priority", DEFAULT_PRIORITY)),
		"icon_id": icon_id,
		"is_selectable": false,
		"route_target_override": {},
	}

func _resolve_manifest_world_position(manifest: Dictionary) -> Variant:
	var source_contract_variant = manifest.get("source_building_contract", {})
	if not (source_contract_variant is Dictionary):
		return null
	var source_contract: Dictionary = source_contract_variant
	var inspection_payload_variant = source_contract.get("inspection_payload", {})
	if inspection_payload_variant is Dictionary:
		var inspection_payload: Dictionary = inspection_payload_variant
		var inspection_world_position: Variant = _decode_vector3(inspection_payload.get("world_position", null))
		if inspection_world_position != null:
			return inspection_world_position
	return _decode_vector3(source_contract.get("center", null))

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

func _build_entry_signature(entry_variant: Variant) -> String:
	if not (entry_variant is Dictionary):
		return ""
	var entry: Dictionary = entry_variant
	var building_id := str(entry.get("building_id", "")).strip_edges()
	var manifest_path := str(entry.get("manifest_path", "")).strip_edges()
	var scene_path := str(entry.get("scene_path", "")).strip_edges()
	return "%s|%s|%s" % [building_id, manifest_path, scene_path]

func _globalize_path(path: String) -> String:
	var normalized := path.replace("\\", "/").trim_suffix("/").strip_edges()
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized)
	return normalized
