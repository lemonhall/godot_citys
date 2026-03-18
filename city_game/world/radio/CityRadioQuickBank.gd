extends RefCounted
class_name CityRadioQuickBank

const MAX_SLOT_COUNT := 8

func build_slots(presets: Array, favorites: Array, recents: Array) -> Array:
	var _ignored_favorites := favorites
	var _ignored_recents := recents
	var slots: Array = []
	for slot_index in range(MAX_SLOT_COUNT):
		slots.append(_build_slot_snapshot(slot_index, {}))
	var next_fill_slot_index := 0
	for preset_variant in presets:
		if not (preset_variant is Dictionary):
			continue
		var preset_entry: Dictionary = preset_variant as Dictionary
		var station_snapshot := _extract_station_snapshot(preset_entry)
		if preset_entry.has("slot_index"):
			var explicit_slot_index := int(preset_entry.get("slot_index", -1))
			if explicit_slot_index < 0 or explicit_slot_index >= MAX_SLOT_COUNT:
				continue
			slots[explicit_slot_index] = _build_slot_snapshot(explicit_slot_index, station_snapshot)
			continue
		while next_fill_slot_index < MAX_SLOT_COUNT and not bool((slots[next_fill_slot_index] as Dictionary).get("is_empty", true)):
			next_fill_slot_index += 1
		if next_fill_slot_index >= MAX_SLOT_COUNT:
			break
		slots[next_fill_slot_index] = _build_slot_snapshot(next_fill_slot_index, station_snapshot)
		next_fill_slot_index += 1
	return slots

func _extract_station_snapshot(source_variant: Variant) -> Dictionary:
	if not (source_variant is Dictionary):
		return {}
	var source: Dictionary = source_variant
	if source.has("station_snapshot") and source.get("station_snapshot") is Dictionary:
		return (source.get("station_snapshot", {}) as Dictionary).duplicate(true)
	return source.duplicate(true)

func _build_slot_snapshot(slot_index: int, station_snapshot: Dictionary) -> Dictionary:
	var slot_snapshot := station_snapshot.duplicate(true)
	var station_id := str(slot_snapshot.get("station_id", "")).strip_edges()
	if station_id == "":
		slot_snapshot.clear()
	slot_snapshot["slot_index"] = slot_index
	slot_snapshot["station_id"] = station_id if station_id != "" else ""
	slot_snapshot["station_name"] = str(slot_snapshot.get("station_name", "")).strip_edges()
	slot_snapshot["is_empty"] = station_id == ""
	return slot_snapshot
