extends RefCounted

const SCRIPT_PATH := "res://city_game/world/features/music_road/CityMusicRoadDefinition.gd"
const EXPERIENCE_KIND := "music_road"

var _source_path := ""
var _raw_data: Dictionary = {}
var _entry_gate: Dictionary = {}
var _note_strips: Array[Dictionary] = []
var _note_strips_desc: Array[Dictionary] = []
var _strip_by_id: Dictionary = {}

static func load_from_path(path: String):
	var definition = load(SCRIPT_PATH).new()
	if not definition._load_from_path(path):
		return null
	return definition

func get_value(key: String, default_value: Variant = null) -> Variant:
	match key:
		"source_path":
			return _source_path
		"entry_gate":
			return _entry_gate.duplicate(true)
		"note_strips":
			return get_note_strips()
		"strip_count":
			return _note_strips.size()
		_:
			return _raw_data.get(key, default_value)

func get_note_strips() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for strip in _note_strips:
		snapshot.append(strip.duplicate(true))
	return snapshot

func get_note_strips_descending() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for strip in _note_strips_desc:
		snapshot.append(strip.duplicate(true))
	return snapshot

func get_strip(strip_id: String) -> Dictionary:
	var strip_variant = _strip_by_id.get(strip_id, {})
	if not (strip_variant is Dictionary):
		return {}
	return (strip_variant as Dictionary).duplicate(true)

func get_strip_count() -> int:
	return _note_strips.size()

func get_entry_gate() -> Dictionary:
	return _entry_gate.duplicate(true)

func is_valid() -> bool:
	return str(_raw_data.get("experience_kind", "")) == EXPERIENCE_KIND and not _note_strips.is_empty()

func _load_from_path(path: String) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return false
	var json_text := FileAccess.get_file_as_string(global_path)
	if json_text.strip_edges() == "":
		return false
	var parsed = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return false
	var raw_data: Dictionary = (parsed as Dictionary).duplicate(true)
	if str(raw_data.get("experience_kind", "")).strip_edges() != EXPERIENCE_KIND:
		return false
	var entry_gate := _normalize_entry_gate(raw_data.get("entry_gate", {}))
	if entry_gate.is_empty():
		return false
	var normalized_strips := _normalize_note_strips(raw_data.get("note_strips", []))
	if normalized_strips.is_empty():
		return false
	_source_path = path
	_raw_data = raw_data
	_entry_gate = entry_gate
	_note_strips = normalized_strips
	_note_strips_desc = _note_strips.duplicate(true)
	_note_strips_desc.reverse()
	_strip_by_id.clear()
	for strip in _note_strips:
		_strip_by_id[str(strip.get("strip_id", ""))] = strip.duplicate(true)
	return true

func _normalize_entry_gate(entry_gate_variant: Variant) -> Dictionary:
	if not (entry_gate_variant is Dictionary):
		return {}
	var entry_gate: Dictionary = entry_gate_variant
	var local_center = _decode_vector3(entry_gate.get("local_center", null))
	var half_extents = _decode_vector3(entry_gate.get("half_extents", null))
	if local_center == null or half_extents == null:
		return {}
	return {
		"shape": str(entry_gate.get("shape", "box")).strip_edges(),
		"local_center": local_center,
		"half_extents": half_extents,
	}

func _normalize_note_strips(note_strips_variant: Variant) -> Array[Dictionary]:
	if not (note_strips_variant is Array):
		return []
	var note_strips: Array[Dictionary] = []
	for strip_variant in note_strips_variant:
		if not (strip_variant is Dictionary):
			continue
		var strip_source: Dictionary = strip_variant
		var strip_id := str(strip_source.get("strip_id", "")).strip_edges()
		var local_center = _decode_vector3(strip_source.get("local_center", null))
		if strip_id == "" or local_center == null:
			continue
		var normalized_strip := strip_source.duplicate(true)
		normalized_strip["strip_id"] = strip_id
		normalized_strip["order_index"] = int(strip_source.get("order_index", -1))
		normalized_strip["local_center"] = local_center
		normalized_strip["trigger_width_m"] = float(strip_source.get("trigger_width_m", 0.0))
		normalized_strip["trigger_length_m"] = float(strip_source.get("trigger_length_m", 0.0))
		normalized_strip["visual_width_m"] = float(strip_source.get("visual_width_m", strip_source.get("trigger_width_m", 0.0)))
		normalized_strip["visual_length_m"] = float(strip_source.get("visual_length_m", strip_source.get("trigger_length_m", 0.0)))
		normalized_strip["note_id"] = str(strip_source.get("note_id", "")).strip_edges()
		normalized_strip["sample_id"] = str(strip_source.get("sample_id", "")).strip_edges()
		normalized_strip["visual_key_kind"] = str(strip_source.get("visual_key_kind", "white")).strip_edges()
		normalized_strip["midi_note"] = int(strip_source.get("midi_note", 0))
		normalized_strip["start_sec"] = float(strip_source.get("start_sec", 0.0))
		normalized_strip["duration_sec"] = float(strip_source.get("duration_sec", 0.0))
		if int(normalized_strip.get("order_index", -1)) < 0:
			continue
		if float(normalized_strip.get("trigger_width_m", 0.0)) <= 0.0:
			continue
		if float(normalized_strip.get("trigger_length_m", 0.0)) <= 0.0:
			continue
		note_strips.append(normalized_strip)
	note_strips.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order_index", -1)) < int(b.get("order_index", -1))
	)
	return note_strips

static func _decode_vector3(value: Variant) -> Variant:
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
