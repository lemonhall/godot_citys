extends SceneTree

const T := preload("res://tests/_test_util.gd")

const BALLISTICS_SCRIPT_PATH := "res://city_game/combat/artillery/CityArtilleryBallistics.gd"
const SHELL_SCRIPT_PATH := "res://city_game/combat/artillery/CityArtilleryShell.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ballistics_script = load(BALLISTICS_SCRIPT_PATH)
	if not T.require_true(self, ballistics_script != null, "Artillery shell shared ballistic model contract requires CityArtilleryBallistics.gd"):
		return
	var shell_script = load(SHELL_SCRIPT_PATH)
	if not T.require_true(self, shell_script != null, "Artillery shell shared ballistic model contract requires CityArtilleryShell.gd"):
		return

	var ballistics = ballistics_script.new()
	var shell := shell_script.new() as Node3D
	if not T.require_true(self, ballistics != null and shell != null, "Shared ballistic model contract requires both ballistics utility and shell runtime to instantiate"):
		return

	root.add_child(shell)
	await process_frame

	var profile := ballistics.get_shell_profile("m795_he") as Dictionary
	var firing_solution := ballistics.build_firing_solution_from_angles(
		Vector3(512.0, 40.0, -384.0),
		18.0,
		27.5,
		"m795_he"
	) as Dictionary
	firing_solution["muzzle_velocity_mps"] = 999.0
	firing_solution["shell_profile"] = profile.duplicate(true)

	shell.configure_from_firing_solution(firing_solution)
	await process_frame

	var debug_state := shell.get_debug_state() as Dictionary
	var velocity := debug_state.get("velocity", Vector3.ZERO) as Vector3
	if not T.require_true(self, absf(float(debug_state.get("shared_solver_speed_mps", 0.0)) - float(profile.get("solver_muzzle_velocity_mps", 0.0))) <= 0.01, "Live artillery shell debug state must expose the shared solver speed so runtime verification can prove which ballistic profile actually launched the shot"):
		return
	if not T.require_true(self, absf(velocity.length() - float(profile.get("solver_muzzle_velocity_mps", 0.0))) <= 1.0, "Live artillery shell runtime must resolve launch speed from the shared shell_profile / ballistic utility instead of trusting an arbitrary caller-provided muzzle_velocity_mps override"):
		return
	if not T.require_true(self, debug_state.get("firing_solution", null) is Dictionary and ((debug_state.get("firing_solution", {}) as Dictionary).get("shell_profile", null) is Dictionary), "Live artillery shell runtime must preserve shell_profile inside its stored firing_solution so later impact consumers can inspect the exact ballistic model that launched the shot"):
		return

	shell.queue_free()
	await process_frame
	T.pass_and_quit(self)
