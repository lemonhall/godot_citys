extends RefCounted

const SOURCE_VERSION := "v12-address-grammar-1"

func build_address_record(block_data: Dictionary, parcel_data: Dictionary, frontage_slot_index: int, canonical_road_name: String, side_hint: String = "") -> Dictionary:
	var parcel_id := str(parcel_data.get("parcel_id", ""))
	var block_serial_index := int(block_data.get("block_serial_index", 0))
	var parcel_local_index := int(parcel_data.get("parcel_local_index", parcel_data.get("parcel_index", 0)))
	var parity_even := _is_even_side(side_hint, parcel_data)
	var block_face_serial := block_serial_index * 4 + parcel_local_index
	var hundred_base := (block_face_serial + 1) * 100
	var house_number := hundred_base + frontage_slot_index * 2 + (0 if parity_even else 1)
	return {
		"place_id": build_address_place_id(parcel_id, frontage_slot_index),
		"parcel_id": parcel_id,
		"frontage_slot_index": frontage_slot_index,
		"house_number": house_number,
		"canonical_road_name": canonical_road_name,
		"normalized_road_name": normalize_name(canonical_road_name),
		"display_name": "%d %s" % [house_number, canonical_road_name],
		"normalized_display_name": normalize_name("%d %s" % [house_number, canonical_road_name]),
		"side_parity": "even" if parity_even else "odd",
		"source_version": SOURCE_VERSION,
	}

func build_intersection_name(road_a: String, road_b: String) -> String:
	var roads := [road_a.strip_edges(), road_b.strip_edges()]
	roads.sort()
	return "%s & %s" % [roads[0], roads[1]]

func build_address_place_id(parcel_id: String, frontage_slot_index: int) -> String:
	return "addr:%s:%d" % [parcel_id, frontage_slot_index]

func parse_address_query(query: String) -> Dictionary:
	var trimmed := query.strip_edges()
	if trimmed == "":
		return {}
	var split_index := -1
	for index in range(trimmed.length()):
		var code := trimmed.unicode_at(index)
		if code < 48 or code > 57:
			split_index = index
			break
	if split_index <= 0:
		return {}
	var house_number := int(trimmed.substr(0, split_index))
	var road_name := trimmed.substr(split_index).strip_edges()
	if road_name == "":
		return {}
	return {
		"house_number": house_number,
		"road_name": road_name,
		"normalized_road_name": normalize_name(road_name),
	}

func decode_house_number(house_number: int) -> Dictionary:
	if house_number < 100:
		return {}
	var block_face_serial := int(floor(float(house_number) / 100.0)) - 1
	if block_face_serial < 0:
		return {}
	var hundred_base := (block_face_serial + 1) * 100
	var remainder := house_number - hundred_base
	if remainder < 0:
		return {}
	return {
		"house_number": house_number,
		"block_face_serial": block_face_serial,
		"block_serial_index": int(floor(float(block_face_serial) / 4.0)),
		"parcel_local_index": posmod(block_face_serial, 4),
		"frontage_slot_index": int(floor(float(remainder) / 2.0)),
		"side_parity": "even" if posmod(remainder, 2) == 0 else "odd",
	}

func normalize_name(value: String) -> String:
	var lowered := value.strip_edges().to_lower()
	var characters := PackedStringArray()
	for index in range(lowered.length()):
		var code := lowered.unicode_at(index)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
			characters.append(lowered.substr(index, 1))
		else:
			characters.append(" ")
	var normalized := " ".join("".join(characters).split(" ", false))
	return normalized.strip_edges()

func _is_even_side(side_hint: String, parcel_data: Dictionary) -> bool:
	var resolved_side := side_hint.strip_edges().to_lower()
	if resolved_side == "":
		resolved_side = str(parcel_data.get("frontage_side", "right")).to_lower()
	return resolved_side == "right" or resolved_side == "east" or resolved_side == "south"
