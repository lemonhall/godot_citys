extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityArtilleryBallisticsScript := preload("res://city_game/combat/artillery/CityArtilleryBallistics.gd")
const CityArtilleryShellScript := preload("res://city_game/combat/artillery/CityArtilleryShell.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"
const BOX_SIZE := Vector3(36.0, 8.0, 36.0)
const BOX_CENTER_Y := 54.0
const RAW_IMPACT_PLANE_Y := 0.0
const EXPECTED_SURFACE_SNAP_OFFSET_M := 0.06
const SURFACE_SNAP_TOLERANCE_M := 0.16
const MIN_HEIGHT_GAIN_OVER_RAW_PREDICTION_M := 20.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH)
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for artillery observer surface-snap contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var runtime := world.get_node_or_null("ArtilleryFireMissionRuntime") as Node3D
	if not T.require_true(self, runtime != null and runtime.has_method("start_observation_from_firing_solution"), "Artillery observer surface-snap contract requires the formal ArtilleryFireMissionRuntime node and its start_observation_from_firing_solution() API"):
		return

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null, "Artillery observer surface-snap contract requires the live PlayerController anchor for placing the raised target fixture"):
		return

	var target_world_position := Vector3(player.global_position.x, RAW_IMPACT_PLANE_Y, player.global_position.z - 1900.0)
	var raised_surface_body := _spawn_raised_surface_fixture(world, Vector3(target_world_position.x, BOX_CENTER_Y, target_world_position.z))
	await process_frame
	await process_frame

	var ballistics := CityArtilleryBallisticsScript.new()
	if not T.require_true(self, ballistics != null and ballistics.has_method("solve_firing_solution_to_target") and ballistics.has_method("predict_impact_from_firing_solution"), "Artillery observer surface-snap contract requires the shared artillery ballistics API to build a real firing solution"):
		return

	var origin_world_position := target_world_position + Vector3(0.0, 20.0, 1900.0)
	var solved_solution := ballistics.solve_firing_solution_to_target(origin_world_position, target_world_position, {
		"platform_world_position": origin_world_position,
	}) as Dictionary
	if not T.require_true(self, bool(solved_solution.get("solved", false)), "Artillery observer surface-snap contract requires a valid long-range firing solution onto the raised-surface fixture footprint"):
		return

	var firing_solution := solved_solution.get("firing_solution", {}) as Dictionary
	if not T.require_true(self, not firing_solution.is_empty(), "Artillery observer surface-snap contract requires the solved firing solution payload instead of only decorative solver metadata"):
		return

	var raw_prediction := ballistics.predict_impact_from_firing_solution(firing_solution, {
		"impact_plane_y": RAW_IMPACT_PLANE_Y,
	}) as Dictionary
	var raw_impact_world_position := raw_prediction.get("impact_world_position", Vector3.INF) as Vector3
	if not T.require_true(self, raw_impact_world_position.is_finite(), "Artillery observer surface-snap contract requires a finite raw ballistic prediction against the original flat impact plane"):
		return

	var observation_state := runtime.start_observation_from_firing_solution(firing_solution) as Dictionary
	var snapped_impact_world_position := observation_state.get("predicted_impact_world_position", Vector3.INF) as Vector3
	if not T.require_true(self, snapped_impact_world_position.is_finite(), "Artillery observer surface-snap contract requires a finite predicted impact world position after observer setup"):
		return

	var expected_surface_y := raised_surface_body.global_position.y + BOX_SIZE.y * 0.5 + EXPECTED_SURFACE_SNAP_OFFSET_M
	if not T.require_true(self, absf(snapped_impact_world_position.y - expected_surface_y) <= SURFACE_SNAP_TOLERANCE_M, "Observer setup must snap the predicted impact point onto the raised target surface instead of leaving it buried at the old flat y=0 prediction (snapped_y=%0.2f expected_y=%0.2f raw_y=%0.2f)" % [snapped_impact_world_position.y, expected_surface_y, raw_impact_world_position.y]):
		return
	if not T.require_true(self, snapped_impact_world_position.y >= raw_impact_world_position.y + MIN_HEIGHT_GAIN_OVER_RAW_PREDICTION_M, "Observer setup must visibly lift the impact point up to the first real collision surface instead of keeping it near the raw flat-plane prediction (snapped_y=%0.2f raw_y=%0.2f)" % [snapped_impact_world_position.y, raw_impact_world_position.y]):
		return
	if not T.require_true(self, Vector2(snapped_impact_world_position.x - target_world_position.x, snapped_impact_world_position.z - target_world_position.z).length() <= 0.5, "Observer surface snap must preserve the planned impact footprint in x/z while only correcting height to the actual struck surface"):
		return

	var shell := CityArtilleryShellScript.new()
	if not T.require_true(self, shell != null, "Artillery observer surface-snap contract requires the formal shell runtime so the final forced impact can be verified against the same raised surface"):
		return
	world.add_child(shell)
	var forced_shell_solution := firing_solution.duplicate(true)
	forced_shell_solution["observer_forced_impact_world_position"] = raw_impact_world_position
	forced_shell_solution["observer_force_predicted_impact"] = true
	forced_shell_solution["observer_forced_impact_flight_time_sec"] = 0.01
	forced_shell_solution["observation_ballistic_time_scale"] = 1.0
	shell.configure_from_firing_solution(forced_shell_solution, null, player, world)
	var shell_explosion_result := await _wait_for_shell_explosion(shell, 24)
	if not T.require_true(self, not shell_explosion_result.is_empty(), "Artillery observer surface-snap contract requires the forced shell impact result so the final explosion point can be compared with the snapped observer point"):
		return
	var shell_impact_world_position := shell_explosion_result.get("world_position", Vector3.INF) as Vector3
	if not T.require_true(self, shell_impact_world_position.is_finite(), "Artillery observer surface-snap contract requires a finite shell explosion world position after the forced observer impact"):
		return
	if not T.require_true(self, absf(shell_impact_world_position.y - expected_surface_y) <= SURFACE_SNAP_TOLERANCE_M, "Forced shell impact must also snap the final explosion point onto the raised target surface instead of exploding inside the old flat-plane prediction (shell_y=%0.2f expected_y=%0.2f)" % [shell_impact_world_position.y, expected_surface_y]):
		return
	if not T.require_true(self, shell_impact_world_position.distance_to(snapped_impact_world_position) <= SURFACE_SNAP_TOLERANCE_M, "Observer camera framing point and forced shell explosion point must converge on the same snapped surface position instead of drifting apart between runtime phases"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _spawn_raised_surface_fixture(parent: Node, center_world_position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ObserverSurfaceSnapFixture"
	parent.add_child(body)
	body.global_position = center_world_position

	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = BOX_SIZE
	collision_shape.shape = box_shape
	body.add_child(collision_shape)
	return body

func _wait_for_shell_explosion(shell: Node, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		if shell.has_method("get_last_explosion_result"):
			var result := shell.get_last_explosion_result() as Dictionary
			if not result.is_empty():
				return result
	return {}
