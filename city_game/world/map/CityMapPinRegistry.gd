extends RefCounted

var _pins_by_id: Dictionary = {}

func seed_landmark_pins(place_index) -> void:
	if place_index == null or not place_index.has_method("get_entries_for_type"):
		return
	for entry_variant in place_index.get_entries_for_type("landmark"):
		var entry: Dictionary = entry_variant
		register_pin({
			"pin_id": "landmark:%s" % str(entry.get("place_id", "")),
			"pin_type": "landmark",
			"world_position": entry.get("world_anchor", Vector3.ZERO),
			"title": str(entry.get("display_name", "")),
			"subtitle": str(entry.get("district_id", "")),
			"priority": 50,
			"icon_id": "landmark",
			"is_selectable": true,
			"route_target_override": entry.duplicate(true),
		})

func register_task_pin(pin_id: String, world_position: Vector3, title: String, subtitle: String = "", pin_type: String = "task") -> Dictionary:
	return register_pin({
		"pin_id": pin_id,
		"pin_type": pin_type,
		"world_position": world_position,
		"title": title,
		"subtitle": subtitle,
		"priority": 90,
		"icon_id": pin_type,
		"is_selectable": true,
		"route_target_override": {},
	})

func upsert_destination_pin(target: Dictionary) -> Dictionary:
	if target.is_empty():
		_pins_by_id.erase("destination:active")
		return {}
	return register_pin({
		"pin_id": "destination:active",
		"pin_type": "destination",
		"world_position": target.get("world_anchor", Vector3.ZERO),
		"title": str(target.get("display_name", "Destination")),
		"subtitle": str(target.get("place_id", "")),
		"priority": 120,
		"icon_id": "destination",
		"is_selectable": true,
		"route_target_override": target.duplicate(true),
	})

func register_pin(pin_data: Dictionary) -> Dictionary:
	var stored := pin_data.duplicate(true)
	var pin_id := str(stored.get("pin_id", ""))
	if pin_id == "":
		return {}
	_pins_by_id[pin_id] = stored
	return stored.duplicate(true)

func get_pins() -> Array[Dictionary]:
	var pins: Array[Dictionary] = []
	for pin_variant in _pins_by_id.values():
		pins.append((pin_variant as Dictionary).duplicate(true))
	pins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := int(a.get("priority", 0))
		var b_priority := int(b.get("priority", 0))
		if a_priority == b_priority:
			return str(a.get("pin_id", "")) < str(b.get("pin_id", ""))
		return a_priority < b_priority
	)
	return pins

func get_state() -> Dictionary:
	var pin_types: Array[String] = []
	var type_seen: Dictionary = {}
	for pin_variant in _pins_by_id.values():
		var pin: Dictionary = pin_variant
		var pin_type := str(pin.get("pin_type", ""))
		if pin_type == "" or type_seen.has(pin_type):
			continue
		type_seen[pin_type] = true
		pin_types.append(pin_type)
	return {
		"pin_count": _pins_by_id.size(),
		"pin_types": pin_types,
	}
