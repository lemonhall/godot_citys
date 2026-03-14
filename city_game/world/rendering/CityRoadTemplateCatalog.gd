extends RefCounted

const TEMPLATES := {
	"expressway_elevated": {
		"template_id": "expressway_elevated",
		"lane_count_total": 8,
		"width_m": 34.0,
		"median_width_m": 2.0,
		"shoulder_width_m": 1.5,
		"deck_thickness_m": 1.3,
		"max_grade": 0.05,
	},
	"arterial": {
		"template_id": "arterial",
		"lane_count_total": 4,
		"width_m": 22.0,
		"median_width_m": 1.0,
		"shoulder_width_m": 1.0,
		"deck_thickness_m": 0.8,
		"max_grade": 0.07,
	},
	"local": {
		"template_id": "local",
		"lane_count_total": 2,
		"width_m": 11.0,
		"median_width_m": 0.0,
		"shoulder_width_m": 0.7,
		"deck_thickness_m": 0.45,
		"max_grade": 0.09,
	},
	"service": {
		"template_id": "service",
		"lane_count_total": 1,
		"width_m": 5.5,
		"median_width_m": 0.0,
		"shoulder_width_m": 0.35,
		"deck_thickness_m": 0.32,
		"max_grade": 0.1,
	},
}

static func get_template_id_for_class(road_class: String) -> String:
	match road_class:
		"expressway", "expressway_elevated":
			return "expressway_elevated"
		"arterial", "secondary":
			return "arterial"
		"service":
			return "service"
		"collector", "local":
			return "local"
	return "local"

static func get_template_for_class(road_class: String) -> Dictionary:
	return get_template(get_template_id_for_class(road_class))

static func get_template(template_id: String) -> Dictionary:
	var raw_template: Dictionary
	if not TEMPLATES.has(template_id):
		raw_template = (TEMPLATES["local"] as Dictionary).duplicate(true)
	else:
		raw_template = (TEMPLATES[template_id] as Dictionary).duplicate(true)
	return _enrich_template(raw_template)

static func get_width_for_class(road_class: String) -> float:
	return float(get_template_for_class(road_class).get("width_m", 11.0))

static func _enrich_template(template: Dictionary) -> Dictionary:
	var template_id := str(template.get("template_id", "local"))
	var lane_schema := _build_lane_schema(template)
	template["lane_count_forward"] = int(lane_schema.get("forward_lane_count", 0))
	template["lane_count_backward"] = int(lane_schema.get("backward_lane_count", 0))
	template["lane_count_shared"] = int(lane_schema.get("shared_center_lane_count", 0))
	template["section_semantics"] = {
		"template_id": template_id,
		"section_profile_id": template_id,
		"width_m": float(template.get("width_m", 11.0)),
		"marking_profile_id": _resolve_marking_profile_id(template_id),
		"lane_schema": lane_schema,
		"edge_profile": _build_edge_profile(template),
	}
	return template

static func _build_lane_schema(template: Dictionary) -> Dictionary:
	var template_id := str(template.get("template_id", "local"))
	var lane_width_m := _resolve_lane_width_m(template)
	match template_id:
		"expressway_elevated":
			return {
				"direction_mode": "divided_one_way_pair",
				"forward_lane_count": 4,
				"backward_lane_count": 4,
				"shared_center_lane_count": 0,
				"lane_width_m": lane_width_m,
			}
		"arterial":
			return {
				"direction_mode": "divided_two_way",
				"forward_lane_count": 2,
				"backward_lane_count": 2,
				"shared_center_lane_count": 0,
				"lane_width_m": lane_width_m,
			}
		"service":
			return {
				"direction_mode": "one_way_single_lane",
				"forward_lane_count": 1,
				"backward_lane_count": 0,
				"shared_center_lane_count": 0,
				"lane_width_m": lane_width_m,
			}
		_:
			return {
				"direction_mode": "two_way",
				"forward_lane_count": 1,
				"backward_lane_count": 1,
				"shared_center_lane_count": 0,
				"lane_width_m": lane_width_m,
			}

static func _build_edge_profile(template: Dictionary) -> Dictionary:
	var width_m := float(template.get("width_m", 11.0))
	var shoulder_width_m := float(template.get("shoulder_width_m", 0.0))
	return {
		"surface_half_width_m": width_m * 0.5,
		"median_width_m": float(template.get("median_width_m", 0.0)),
		"left_shoulder_width_m": shoulder_width_m,
		"right_shoulder_width_m": shoulder_width_m,
		"roadside_buffer_m": shoulder_width_m + 0.75,
		"curb_profile_id": _resolve_curb_profile_id(str(template.get("template_id", "local"))),
	}

static func _resolve_lane_width_m(template: Dictionary) -> float:
	var lane_count_total: int = maxi(int(template.get("lane_count_total", 1)), 1)
	var width_m := float(template.get("width_m", 11.0))
	var median_width_m := float(template.get("median_width_m", 0.0))
	var shoulder_width_m := float(template.get("shoulder_width_m", 0.0))
	var lane_surface_width_m := maxf(width_m - median_width_m - shoulder_width_m * 2.0, 1.0)
	return lane_surface_width_m / float(lane_count_total)

static func _resolve_marking_profile_id(template_id: String) -> String:
	match template_id:
		"expressway_elevated":
			return "expressway_divided"
		"arterial":
			return "arterial_divided"
		"service":
			return "service_single_edge"
		_:
			return "local_centerline"

static func _resolve_curb_profile_id(template_id: String) -> String:
	match template_id:
		"expressway_elevated":
			return "bridge_barrier"
		"arterial":
			return "rolled_curb"
		"service":
			return "soft_edge"
		_:
			return "raised_curb"
