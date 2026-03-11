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

static func get_template(template_id: String) -> Dictionary:
	if not TEMPLATES.has(template_id):
		return (TEMPLATES["local"] as Dictionary).duplicate(true)
	return (TEMPLATES[template_id] as Dictionary).duplicate(true)

static func get_width_for_class(road_class: String) -> float:
	var template_id := get_template_id_for_class(road_class)
	return float((TEMPLATES[template_id] as Dictionary).get("width_m", 11.0))
