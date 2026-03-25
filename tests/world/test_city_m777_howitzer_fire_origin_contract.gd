extends SceneTree

const T := preload("res://tests/_test_util.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const SAMPLE_YAW_DEG := 100.0
const SAMPLE_PITCH_DEG := 7.0
const TRANSFORM_TOLERANCE := 0.001
const ORIGIN_TOLERANCE_M := 0.001

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(HOWITZER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 fire origin contract requires the formal howitzer scene"):
		return

	var howitzer := scene.instantiate() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("set_axis_angles_degrees"), "M777 fire origin contract must instantiate the formal howitzer runtime"):
		return

	root.add_child(howitzer)
	await process_frame
	await process_frame

	var muzzle_fx_rig := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig") as Node3D
	var muzzle_ballistics_probe := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleBallisticsProbe") as Node3D
	if not T.require_true(self, muzzle_fx_rig != null and muzzle_ballistics_probe != null and howitzer.has_method("get_firing_solution_snapshot"), "M777 fire origin contract requires the rebuilt runtime rig/probe nodes plus firing-solution introspection"):
		return

	var baseline_fx_local := muzzle_fx_rig.transform
	var baseline_ballistics_local := muzzle_ballistics_probe.transform
	howitzer.set_axis_angles_degrees(SAMPLE_YAW_DEG, SAMPLE_PITCH_DEG)
	await process_frame
	await process_frame

	if not _require_transform_close(self, muzzle_fx_rig.transform, baseline_fx_local, "MuzzleFxRig local attachment transform must stay stable while the gun yaws/pitches instead of being runtime-corrected by hidden offsets", TRANSFORM_TOLERANCE):
		return
	if not _require_transform_close(self, muzzle_ballistics_probe.transform, baseline_ballistics_local, "MuzzleBallisticsProbe local attachment transform must stay stable while the gun yaws/pitches instead of being runtime-corrected by hidden offsets", TRANSFORM_TOLERANCE):
		return
	var firing_solution := howitzer.get_firing_solution_snapshot() as Dictionary
	var origin_world_position := firing_solution.get("origin_world_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, origin_world_position.distance_to(muzzle_ballistics_probe.global_position) <= ORIGIN_TOLERANCE_M, "Firing solution origin_world_position must come directly from MuzzleBallisticsProbe after yaw/pitch changes instead of drifting to another hidden muzzle proxy"):
		return

	howitzer.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _require_transform_close(tree: SceneTree, actual: Transform3D, expected: Transform3D, message: String, tolerance: float) -> bool:
	if actual.origin.distance_to(expected.origin) > tolerance:
		T.fail_and_quit(tree, "%s (origin actual=%s expected=%s)" % [message, actual.origin, expected.origin])
		return false
	for basis_index in 3:
		var actual_axis := actual.basis[basis_index]
		var expected_axis := expected.basis[basis_index]
		if actual_axis.length_squared() <= 0.000001 or expected_axis.length_squared() <= 0.000001:
			T.fail_and_quit(tree, "%s (basis[%d] degenerate actual=%s expected=%s)" % [message, basis_index, actual_axis, expected_axis])
			return false
		if actual_axis.normalized().distance_to(expected_axis.normalized()) > tolerance:
			T.fail_and_quit(tree, "%s (basis[%d] actual=%s expected=%s)" % [message, basis_index, actual_axis.normalized(), expected_axis.normalized()])
			return false
	return true
