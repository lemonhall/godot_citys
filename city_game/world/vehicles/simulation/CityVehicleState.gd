extends RefCounted

const TIER_0 := "tier0"
const TIER_1 := "tier1"
const TIER_2 := "tier2"
const TIER_3 := "tier3"

var vehicle_id := ""
var chunk_id := ""
var page_id := ""
var spawn_slot_id := ""
var road_id := ""
var lane_ref_id := ""
var route_signature := ""
var model_id := ""
var model_signature := ""
var traffic_role := "civilian"
var vehicle_class := "sedan"
var seed_value := 0
var tier := TIER_0
var length_m := 4.4
var width_m := 1.9
var height_m := 1.5
var speed_mps := 10.0
var world_position := Vector3.ZERO
var heading := Vector3.FORWARD
var lane_points: Array[Vector3] = []
var lane_length_m := 0.0
var distance_along_lane_m := 0.0

func setup(data: Dictionary) -> void:
	vehicle_id = str(data.get("vehicle_id", ""))
	chunk_id = str(data.get("chunk_id", ""))
	page_id = str(data.get("page_id", ""))
	spawn_slot_id = str(data.get("spawn_slot_id", ""))
	road_id = str(data.get("road_id", ""))
	lane_ref_id = str(data.get("lane_ref_id", ""))
	route_signature = str(data.get("route_signature", ""))
	model_id = str(data.get("model_id", "car_b"))
	model_signature = str(data.get("model_signature", "car_b:sedan"))
	traffic_role = str(data.get("traffic_role", "civilian"))
	vehicle_class = str(data.get("vehicle_class", "sedan"))
	seed_value = int(data.get("seed", 0))
	length_m = maxf(float(data.get("length_m", 4.4)), 0.5)
	width_m = maxf(float(data.get("width_m", 1.9)), 0.4)
	height_m = maxf(float(data.get("height_m", 1.5)), 0.4)
	speed_mps = maxf(float(data.get("speed_mps", 10.0)), 0.1)
	world_position = data.get("world_position", Vector3.ZERO)
	var lane_points_source: Array = data.get("lane_points", [])
	lane_points.clear()
	for point_variant in lane_points_source:
		lane_points.append(point_variant)
	lane_length_m = maxf(float(data.get("lane_length_m", _measure_lane_length(lane_points))), 0.001)
	distance_along_lane_m = fposmod(float(data.get("distance_along_lane_m", 0.0)), lane_length_m)
	var sample := _sample_lane_state(distance_along_lane_m)
	world_position = sample.position
	heading = sample.heading

func step(delta: float) -> void:
	if delta <= 0.0:
		return
	if lane_points.size() < 2:
		return
	distance_along_lane_m = fposmod(distance_along_lane_m + speed_mps * delta, lane_length_m)
	var sample := _sample_lane_state(distance_along_lane_m)
	world_position = sample.position
	heading = sample.heading

func apply_ground_height(height_y: float) -> void:
	world_position.y = height_y

func set_tier(next_tier: String) -> void:
	tier = next_tier

func to_snapshot() -> Dictionary:
	return {
		"vehicle_id": vehicle_id,
		"chunk_id": chunk_id,
		"page_id": page_id,
		"spawn_slot_id": spawn_slot_id,
		"road_id": road_id,
		"lane_ref_id": lane_ref_id,
		"route_signature": route_signature,
		"model_id": model_id,
		"model_signature": model_signature,
		"traffic_role": traffic_role,
		"vehicle_class": vehicle_class,
		"seed": seed_value,
		"tier": tier,
		"length_m": length_m,
		"width_m": width_m,
		"height_m": height_m,
		"speed_mps": speed_mps,
		"world_position": world_position,
		"heading": heading,
		"distance_along_lane_m": distance_along_lane_m,
	}

func to_render_snapshot() -> Dictionary:
	return {
		"vehicle_id": vehicle_id,
		"world_position": world_position,
		"heading": heading,
		"length_m": length_m,
		"width_m": width_m,
		"height_m": height_m,
		"model_id": model_id,
		"model_signature": model_signature,
		"traffic_role": traffic_role,
	}

func _sample_lane_state(target_distance_m: float) -> Dictionary:
	if lane_points.is_empty():
		return {
			"position": world_position,
			"heading": heading,
		}
	if lane_points.size() == 1:
		return {
			"position": lane_points[0],
			"heading": heading,
		}
	var traversed := 0.0
	for point_index in range(lane_points.size() - 1):
		var a: Vector3 = lane_points[point_index]
		var b: Vector3 = lane_points[point_index + 1]
		var segment := b - a
		var segment_length := segment.length()
		if traversed + segment_length >= target_distance_m:
			var t := 0.0 if segment_length <= 0.001 else (target_distance_m - traversed) / segment_length
			return {
				"position": a.lerp(b, clampf(t, 0.0, 1.0)),
				"heading": segment.normalized(),
			}
		traversed += segment_length
	var last_index := lane_points.size() - 1
	return {
		"position": lane_points[last_index],
		"heading": (lane_points[last_index] - lane_points[last_index - 1]).normalized(),
	}

func _measure_lane_length(points: Array[Vector3]) -> float:
	var total := 0.0
	for point_index in range(points.size() - 1):
		total += points[point_index].distance_to(points[point_index + 1])
	return total
