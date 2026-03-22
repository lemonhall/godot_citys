extends RefCounted

var _schools_by_region_id: Dictionary = {}

func configure(lake_runtimes: Array) -> void:
	_schools_by_region_id.clear()
	for runtime_variant in lake_runtimes:
		var lake_runtime = runtime_variant
		if lake_runtime == null or not lake_runtime.has_method("get_runtime_contract"):
			continue
		var contract: Dictionary = lake_runtime.get_runtime_contract()
		var region_id := str(contract.get("region_id", "")).strip_edges()
		if region_id == "":
			continue
		var school_summaries: Array = []
		for school_variant in contract.get("schools", []):
			if not (school_variant is Dictionary):
				continue
			var school: Dictionary = (school_variant as Dictionary).duplicate(true)
			var school_world_position_variant: Variant = _decode_vector3(school.get("world_position", null))
			if school_world_position_variant == null:
				continue
			var school_world_position := school_world_position_variant as Vector3
			var depth_sample: Dictionary = lake_runtime.sample_depth_at_world_position(school_world_position)
			if not bool(depth_sample.get("inside_region", false)):
				continue
			var water_level_y_m := float(depth_sample.get("water_level_y_m", 0.0))
			var floor_y_m := float(depth_sample.get("floor_y_m", water_level_y_m))
			var target_depth_ratio := clampf(float(school.get("depth_ratio", 0.5)), 0.05, 0.95)
			var school_y := lerpf(floor_y_m + 0.45, water_level_y_m - 0.35, target_depth_ratio)
			school_summaries.append({
				"school_id": str(school.get("school_id", "")),
				"region_id": region_id,
				"species_id": str(school.get("species_id", "lake_fish")),
				"count": int(school.get("count", 1)),
				"swim_radius_m": float(school.get("swim_radius_m", 6.0)),
				"world_position": Vector3(school_world_position.x, school_y, school_world_position.z),
			})
		_schools_by_region_id[region_id] = school_summaries

func get_school_summaries_for_region(region_id: String) -> Array:
	if region_id == "":
		return []
	var school_summaries: Array = _schools_by_region_id.get(region_id, [])
	var snapshot: Array = []
	for school_variant in school_summaries:
		snapshot.append((school_variant as Dictionary).duplicate(true))
	return snapshot

func get_state() -> Dictionary:
	var school_count := 0
	for school_summaries_variant in _schools_by_region_id.values():
		school_count += (school_summaries_variant as Array).size()
	return {
		"region_count": _schools_by_region_id.size(),
		"school_count": school_count,
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
