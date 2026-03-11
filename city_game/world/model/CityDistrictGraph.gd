extends RefCounted

var districts: Array[Dictionary] = []

func add_district(district: Dictionary) -> void:
	districts.append(district)

func get_district_count() -> int:
	return districts.size()

func get_district_ids() -> Array[String]:
	var ids: Array[String] = []
	for district in districts:
		ids.append(str(district.get("district_id", "")))
	return ids

