extends SceneTree

const T := preload("res://tests/_test_util.gd")

const BALLISTICS_SCRIPT_PATH := "res://city_game/combat/artillery/CityArtilleryBallistics.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ballistics_script = load(BALLISTICS_SCRIPT_PATH)
	if not T.require_true(self, ballistics_script != null, "Inverse artillery ballistic solver contract requires CityArtilleryBallistics.gd"):
		return

	var ballistics = ballistics_script.new()
	if not T.require_true(self, ballistics != null, "Inverse artillery ballistic solver contract requires CityArtilleryBallistics.gd to instantiate"):
		return

	if not T.require_true(self, ballistics.has_method("solve_firing_solution_to_target"), "Inverse artillery ballistic solver contract requires solve_firing_solution_to_target()"):
		return

	var origin := Vector3(0.0, 72.0, 0.0)
	var target := Vector3(0.0, 72.0, -15000.0)
	var low_arc := ballistics.solve_firing_solution_to_target(origin, target, {
		"shell_type_id": "m795_he",
		"prefer_high_arc": false,
	}) as Dictionary
	var high_arc := ballistics.solve_firing_solution_to_target(origin, target, {
		"shell_type_id": "m795_he",
		"prefer_high_arc": true,
	}) as Dictionary

	if not T.require_true(self, bool(low_arc.get("solved", false)), "Inverse ballistic solver must solve an in-range target on the low arc path"):
		return
	if not T.require_true(self, bool(high_arc.get("solved", false)), "Inverse ballistic solver must solve an in-range target on the high arc path when requested"):
		return
	if not T.require_true(self, absf(float(low_arc.get("world_bearing_deg", -999.0)) - 0.0) <= 0.05, "Inverse ballistic solver must preserve the shared world north contract when solving a straight-north target"):
		return
	if not T.require_true(self, float(high_arc.get("pitch_deg", 0.0)) > float(low_arc.get("pitch_deg", 0.0)), "High arc solve must yield a steeper pitch than low arc solve for the same target"):
		return
	if not T.require_true(self, (low_arc.get("predicted_impact_world_position", Vector3.INF) as Vector3).distance_to(target) <= 0.5, "Low arc inverse solution must carry its own predicted_impact_world_position so callers can immediately verify what was solved"):
		return
	if not T.require_true(self, (high_arc.get("predicted_impact_world_position", Vector3.INF) as Vector3).distance_to(target) <= 0.5, "High arc inverse solution must still round-trip back to the original target instead of becoming a decorative second answer"):
		return
	if not T.require_true(self, str(low_arc.get("range_state", "")) == "within_range" and float(low_arc.get("flight_time_sec", 0.0)) > 0.0, "Inverse ballistic solver must expose within_range and positive flight_time_sec once a valid target solution exists"):
		return

	var too_close := ballistics.solve_firing_solution_to_target(origin, origin + Vector3(0.0, 0.0, -900.0), {
		"shell_type_id": "m795_he",
	}) as Dictionary
	if not T.require_true(self, not bool(too_close.get("solved", true)) and str(too_close.get("range_state", "")) == "below_min_range", "Inverse ballistic solver must reject targets inside the frozen 1.5km minimum envelope instead of returning a fake shallow shot"):
		return

	var too_far := ballistics.solve_firing_solution_to_target(origin, origin + Vector3(0.0, 0.0, -24000.0), {
		"shell_type_id": "m795_he",
	}) as Dictionary
	if not T.require_true(self, not bool(too_far.get("solved", true)) and str(too_far.get("range_state", "")) == "above_max_range", "Inverse ballistic solver must reject targets beyond the frozen 22.5km maximum envelope instead of inventing an unreachable fire solution"):
		return

	T.pass_and_quit(self)
