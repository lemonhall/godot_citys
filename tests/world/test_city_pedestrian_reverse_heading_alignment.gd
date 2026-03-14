extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianState := preload("res://city_game/world/pedestrians/simulation/CityPedestrianState.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var reverse_state := _build_lane_state("reverse_lane", 0.8, 1.0)
	reverse_state.route_direction = -1.0
	if not _require_motion_matches_heading(reverse_state, 0.2, "Reverse lane walk must keep heading aligned with actual motion instead of back-sliding along the lane"):
		return

	var bounce_state := _build_lane_state("bounce_turnaround", 0.95, 1.0)
	if not _require_motion_matches_heading(bounce_state, 1.0, "Lane-end turnaround must flip heading with the bounced motion instead of leaving the pedestrian facing the old direction"):
		return

	T.pass_and_quit(self)

func _require_motion_matches_heading(state: CityPedestrianState, step_delta: float, failure_message: String) -> bool:
	var previous_position := state.world_position
	state.step(step_delta)
	var movement := state.world_position - previous_position
	movement.y = 0.0
	var heading := state.heading
	heading.y = 0.0
	print("CITY_PEDESTRIAN_REVERSE_HEADING_ALIGNMENT %s" % JSON.stringify({
		"pedestrian_id": state.pedestrian_id,
		"route_direction": state.route_direction,
		"movement": movement,
		"heading": heading,
		"route_progress": state.route_progress,
	}))
	if not T.require_true(self, movement.length() > 0.0001, "Reverse heading alignment test requires non-zero planar movement"):
		return false
	if not T.require_true(self, heading.length() > 0.0001, "Reverse heading alignment test requires non-zero planar heading"):
		return false
	return T.require_true(self, movement.normalized().dot(heading.normalized()) > 0.95, failure_message)

func _build_lane_state(label: String, route_progress: float, speed_mps: float) -> CityPedestrianState:
	var state := CityPedestrianState.new()
	state.setup({
		"pedestrian_id": label,
		"chunk_id": "chunk:test",
		"page_id": "page:test",
		"spawn_slot_id": "slot:%s" % label,
		"road_id": "road:test",
		"lane_ref_id": "lane:%s" % label,
		"route_signature": "route:%s" % label,
		"archetype_id": "resident",
		"archetype_signature": "resident:v0",
		"seed": label.hash(),
		"height_m": 1.75,
		"radius_m": 0.28,
		"speed_mps": speed_mps,
		"stride_phase": 0.0,
		"route_progress": route_progress,
		"world_position": Vector3.ZERO,
		"lane_points": [
			Vector3.ZERO,
			Vector3(1.0, 0.0, 0.0),
		],
		"lane_length_m": 1.0,
		"tint": Color(0.7, 0.74, 0.78, 1.0),
	})
	return state
