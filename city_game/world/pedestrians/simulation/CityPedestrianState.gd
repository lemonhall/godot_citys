extends RefCounted

const TIER_0 := "tier0"
const TIER_1 := "tier1"
const TIER_2 := "tier2"

var pedestrian_id := ""
var chunk_id := ""
var spawn_slot_id := ""
var lane_ref_id := ""
var route_signature := ""
var archetype_id := ""
var archetype_signature := ""
var seed_value := 0
var tier := TIER_0
var height_m := 1.75
var radius_m := 0.28
var speed_mps := 1.25
var stride_phase := 0.0
var route_progress := 0.0
var route_direction := 1.0
var world_position := Vector3.ZERO
var heading := Vector3.FORWARD
var lane_points: Array[Vector3] = []
var lane_length_m := 0.0
var tint := Color(0.7, 0.74, 0.78, 1.0)

func setup(data: Dictionary) -> void:
	pedestrian_id = str(data.get("pedestrian_id", ""))
	chunk_id = str(data.get("chunk_id", ""))
	spawn_slot_id = str(data.get("spawn_slot_id", ""))
	lane_ref_id = str(data.get("lane_ref_id", ""))
	route_signature = str(data.get("route_signature", ""))
	archetype_id = str(data.get("archetype_id", "resident"))
	archetype_signature = str(data.get("archetype_signature", "resident:v0"))
	seed_value = int(data.get("seed", 0))
	height_m = float(data.get("height_m", 1.75))
	radius_m = float(data.get("radius_m", 0.28))
	speed_mps = float(data.get("speed_mps", 1.25))
	stride_phase = clampf(float(data.get("stride_phase", 0.0)), 0.0, 1.0)
	route_progress = clampf(float(data.get("route_progress", 0.0)), 0.0, 1.0)
	world_position = data.get("world_position", Vector3.ZERO)
	tint = data.get("tint", Color(0.7, 0.74, 0.78, 1.0))
	var lane_points_source: Array = data.get("lane_points", [])
	lane_points.clear()
	for point in lane_points_source:
		lane_points.append(point)
	lane_length_m = maxf(float(data.get("lane_length_m", _measure_lane_length(lane_points))), 0.001)
	var initial_sample := _sample_lane_state(route_progress)
	world_position.x = initial_sample.position.x
	world_position.z = initial_sample.position.z
	heading = initial_sample.heading

func step(delta: float) -> void:
	if delta <= 0.0:
		return
	if lane_points.size() < 2:
		stride_phase = fposmod(stride_phase + delta * 0.9, 1.0)
		return
	var progress_delta := (speed_mps * delta) / maxf(lane_length_m, 0.001)
	route_progress += progress_delta * route_direction
	if route_progress > 1.0:
		route_progress = 2.0 - route_progress
		route_direction = -1.0
	elif route_progress < 0.0:
		route_progress = -route_progress
		route_direction = 1.0
	var sample := _sample_lane_state(route_progress)
	world_position.x = sample.position.x
	world_position.z = sample.position.z
	heading = sample.heading
	stride_phase = fposmod(stride_phase + delta * maxf(speed_mps * 0.55, 0.5), 1.0)

func apply_ground_height(height_y: float) -> void:
	world_position.y = height_y

func set_tier(next_tier: String) -> void:
	tier = next_tier

func to_snapshot() -> Dictionary:
	return {
		"pedestrian_id": pedestrian_id,
		"chunk_id": chunk_id,
		"spawn_slot_id": spawn_slot_id,
		"lane_ref_id": lane_ref_id,
		"route_signature": route_signature,
		"archetype_id": archetype_id,
		"archetype_signature": archetype_signature,
		"seed": seed_value,
		"tier": tier,
		"height_m": height_m,
		"radius_m": radius_m,
		"speed_mps": speed_mps,
		"stride_phase": stride_phase,
		"route_progress": route_progress,
		"world_position": world_position,
		"heading": heading,
		"tint": tint,
	}

func _sample_lane_state(progress: float) -> Dictionary:
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
	var target_length := lane_length_m * clampf(progress, 0.0, 1.0)
	var traversed := 0.0
	for point_index in range(lane_points.size() - 1):
		var a: Vector3 = lane_points[point_index]
		var b: Vector3 = lane_points[point_index + 1]
		var segment := b - a
		var segment_length := segment.length()
		if traversed + segment_length >= target_length:
			var t := 0.0 if segment_length <= 0.001 else (target_length - traversed) / segment_length
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
