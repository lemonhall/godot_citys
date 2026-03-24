extends SceneTree

const T := preload("res://tests/_test_util.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(HOWITZER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Howitzer ballistic profile payload contract requires the formal howitzer scene"):
		return

	var howitzer := scene.instantiate() as Node3D
	if not T.require_true(self, howitzer != null, "Howitzer ballistic profile payload contract requires the formal howitzer runtime to instantiate"):
		return

	root.add_child(howitzer)
	await process_frame
	await process_frame

	if not T.require_true(self, howitzer.has_method("get_firing_solution_snapshot"), "Howitzer ballistic profile payload contract requires get_firing_solution_snapshot()"):
		return

	var snapshot := howitzer.get_firing_solution_snapshot() as Dictionary
	if not T.require_true(self, snapshot.get("shell_profile", null) is Dictionary, "Howitzer firing solution snapshot must embed the resolved shell_profile so downstream solvers and live shell runtime do not guess from shell_type_id alone"):
		return
	var shell_profile := snapshot.get("shell_profile", {}) as Dictionary
	if not T.require_true(self, str(shell_profile.get("shell_type_id", "")) == str(snapshot.get("shell_type_id", "")), "Howitzer firing solution snapshot must keep shell_profile.shell_type_id aligned with shell_type_id"):
		return
	if not T.require_true(self, float(shell_profile.get("min_range_m", 0.0)) == 1500.0 and float(shell_profile.get("max_range_m", 0.0)) == 22500.0, "Howitzer firing solution snapshot must carry the frozen gameplay range envelope forward instead of discarding it before solver/runtime consumption"):
		return
	if not T.require_true(self, absf(float(shell_profile.get("solver_muzzle_velocity_mps", 0.0)) - float(snapshot.get("muzzle_velocity_mps", -1.0))) <= 0.01, "Howitzer firing solution snapshot must expose the shared solver velocity as its formal gameplay muzzle_velocity_mps so runtime and prediction stay co-linear"):
		return
	if not T.require_true(self, float(snapshot.get("reference_muzzle_velocity_mps", 0.0)) >= float(snapshot.get("muzzle_velocity_mps", 0.0)), "Howitzer firing solution snapshot must preserve a separate reference_muzzle_velocity_mps field once gameplay solver velocity is tuned down to the 22.5km envelope"):
		return

	howitzer.queue_free()
	await process_frame
	T.pass_and_quit(self)
