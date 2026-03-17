extends RefCounted
class_name CityRadioQuickBank

const MAX_SLOT_COUNT := 8

func build_slots(presets: Array, favorites: Array, recents: Array) -> Array:
	var slots: Array = []
	var seen_station_ids: Dictionary = {}
	_append_sources(slots, seen_station_ids, presets)
	_append_sources(slots, seen_station_ids, favorites)
	_append_sources(slots, seen_station_ids, recents)
	if slots.size() > MAX_SLOT_COUNT:
		slots.resize(MAX_SLOT_COUNT)
	return slots

func _append_sources(target: Array, seen_station_ids: Dictionary, sources: Array) -> void:
	if target.size() >= MAX_SLOT_COUNT:
		return
	for source_variant in sources:
		var station_snapshot := _extract_station_snapshot(source_variant)
		if station_snapshot.is_empty():
			continue
		var station_id := str(station_snapshot.get("station_id", "")).strip_edges()
		if station_id == "" or seen_station_ids.has(station_id):
			continue
		seen_station_ids[station_id] = true
		target.append(station_snapshot)
		if target.size() >= MAX_SLOT_COUNT:
			return

func _extract_station_snapshot(source_variant: Variant) -> Dictionary:
	if not (source_variant is Dictionary):
		return {}
	var source: Dictionary = source_variant
	if source.has("station_snapshot") and source.get("station_snapshot") is Dictionary:
		return (source.get("station_snapshot", {}) as Dictionary).duplicate(true)
	return source.duplicate(true)
