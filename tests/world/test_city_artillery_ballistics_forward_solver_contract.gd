extends SceneTree

const T := preload("res://tests/_test_util.gd")

const BALLISTICS_SCRIPT_PATH := "res://city_game/combat/artillery/CityArtilleryBallistics.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ballistics_script = load(BALLISTICS_SCRIPT_PATH)
	if not T.require_true(self, ballistics_script != null, "Forward artillery ballistic solver contract requires CityArtilleryBallistics.gd"):
		return

	var ballistics = ballistics_script.new()
	if not T.require_true(self, ballistics != null, "Forward artillery ballistic solver contract requires CityArtilleryBallistics.gd to instantiate"):
		return

	if not T.require_true(self, ballistics.has_method("build_firing_solution_from_angles"), "Forward artillery ballistic solver contract requires build_firing_solution_from_angles()"):
		return
	if not T.require_true(self, ballistics.has_method("predict_impact_from_firing_solution"), "Forward artillery ballistic solver contract requires predict_impact_from_firing_solution()"):
		return

	var firing_solution := ballistics.build_firing_solution_from_angles(
		Vector3(0.0, 64.0, 0.0),
		0.0,
		45.0,
		"m795_he"
	) as Dictionary
	if not T.require_true(self, not firing_solution.is_empty(), "Forward ballistic solver contract requires a formal firing_solution builder instead of ad-hoc dictionaries in each caller"):
		return

	var predicted := ballistics.predict_impact_from_firing_solution(firing_solution) as Dictionary
	if not T.require_true(self, bool(predicted.get("valid", false)), "Forward ballistic solver must accept a valid in-envelope 45 degree shot"):
		return
	if not T.require_true(self, absf(float(predicted.get("horizontal_distance_m", -999.0)) - 22500.0) <= 5.0, "Gameplay forward solver must freeze the current howitzer's 45 degree extremal range at roughly 22.5km instead of letting it drift back to raw 827m/s vacuum range"):
		return
	if not T.require_true(self, predicted.get("impact_world_position", null) is Vector3, "Forward ballistic solver must expose a structured impact_world_position instead of leaving downstream systems to reconstruct it themselves"):
		return
	if not T.require_true(self, absf((predicted.get("impact_world_position", Vector3.ZERO) as Vector3).y - 64.0) <= 0.05, "Forward ballistic solver must preserve equal-elevation impacts on the same plane for the formal no-wind gameplay model"):
		return
	if not T.require_true(self, predicted.get("launch_velocity_world", null) is Vector3, "Forward ballistic solver must expose launch_velocity_world so live shell runtime can share the same launch state"):
		return
	if not T.require_true(self, float(predicted.get("flight_time_sec", 0.0)) > 0.0 and str(predicted.get("range_state", "")) == "within_range", "Forward ballistic solver must surface positive flight_time_sec and an explicit within_range state"):
		return

	T.pass_and_quit(self)
