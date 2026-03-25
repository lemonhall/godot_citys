extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SHELL_SCRIPT_PATH := "res://city_game/combat/artillery/CityArtilleryShell.gd"
const FORCED_IMPACT_WORLD_POSITION := Vector3(0.0, 2.0, -120.0)
const TRIGGER_TIMEOUT_FRAMES := 90

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var shell_script = load(SHELL_SCRIPT_PATH)
	if shell_script == null:
		T.fail_and_quit(self, "Observer forced-impact contract requires CityArtilleryShell.gd")
		return

	var shell := shell_script.new() as Node3D
	if shell == null:
		T.fail_and_quit(self, "Observer forced-impact contract requires CityArtilleryShell.gd to instantiate as Node3D")
		return

	var obstacle := StaticBody3D.new()
	obstacle.name = "MidFlightObstacle"
	var obstacle_shape := CollisionShape3D.new()
	var obstacle_box := BoxShape3D.new()
	obstacle_box.size = Vector3(14.0, 14.0, 2.4)
	obstacle_shape.shape = obstacle_box
	obstacle.add_child(obstacle_shape)
	obstacle.position = Vector3(0.0, 2.0, -24.0)
	root.add_child(obstacle)

	root.add_child(shell)
	await process_frame

	if not T.require_true(self, shell.has_method("configure_from_firing_solution") and shell.has_method("get_last_explosion_result"), "Observer forced-impact contract requires artillery shell configure/get_last_explosion_result APIs"):
		return

	shell.configure_from_firing_solution({
		"origin_world_position": Vector3(0.0, 2.0, 0.0),
		"muzzle_direction_world": Vector3(0.0, 0.0, -1.0),
		"muzzle_velocity_mps": 120.0,
		"observer_force_predicted_impact": true,
		"observer_forced_impact_world_position": FORCED_IMPACT_WORLD_POSITION,
		"observer_forced_impact_flight_time_sec": 1.0,
	})

	var explosion_result := await _wait_for_shell_explosion(shell, TRIGGER_TIMEOUT_FRAMES)
	if not T.require_true(self, not explosion_result.is_empty(), "Observer forced-impact contract requires the shell to explode during the bounded test window"):
		return

	if not T.require_true(self, str(explosion_result.get("trigger_kind", "")) == "forced_predicted_impact", "Observer forced-impact contract must ignore mid-flight obstacle collisions and keep the shell alive until the forced observer impact point is reached"):
		return

	var explosion_world_position := explosion_result.get("world_position", Vector3.INF) as Vector3
	if not T.require_true(self, explosion_world_position.is_finite(), "Observer forced-impact contract requires a finite forced impact world position"):
		return

	if not T.require_true(self, explosion_world_position.distance_to(FORCED_IMPACT_WORLD_POSITION) <= 0.01, "Observer forced-impact contract must explode at the forced observer impact point instead of the first obstacle along the path (distance=%0.3fm)" % explosion_world_position.distance_to(FORCED_IMPACT_WORLD_POSITION)):
		return

	shell.queue_free()
	obstacle.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_shell_explosion(shell: Node, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var result := shell.get_last_explosion_result() as Dictionary
		if not result.is_empty():
			return result
	return {}
