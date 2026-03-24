extends SceneTree

const T := preload("res://tests/_test_util.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const ORIENTATION_SCRIPT_PATH := "res://city_game/world/navigation/CityWorldOrientation.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(HOWITZER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 firing solution contract requires the formal howitzer scene"):
		return

	var howitzer := scene.instantiate() as Node3D
	if not T.require_true(self, howitzer != null, "M777 firing solution contract must instantiate the formal howitzer runtime"):
		return

	root.add_child(howitzer)
	await process_frame
	await process_frame

	if not T.require_true(self, howitzer.has_method("get_firing_solution_snapshot"), "M777 runtime must expose get_firing_solution_snapshot() so future projectile and ballistic systems can consume a formal shot payload"):
		return
	if not T.require_true(self, howitzer.has_method("get_last_fired_solution"), "M777 runtime must expose get_last_fired_solution() so the accepted-shot payload survives after the visual flash has started"):
		return

	var orientation_script := load(ORIENTATION_SCRIPT_PATH)
	var orientation = orientation_script.new()
	if not T.require_true(self, orientation != null, "M777 firing solution contract requires the shared orientation helper so world bearing can be validated against the formal north contract"):
		return

	howitzer.set_axis_angles_degrees(32.5, 18.25)
	await process_frame

	var snapshot := howitzer.get_firing_solution_snapshot() as Dictionary
	if not T.require_true(self, snapshot.get("origin_world_position", null) is Vector3, "Firing solution snapshot must expose the muzzle origin world position"):
		return
	if not T.require_true(self, snapshot.get("platform_world_position", null) is Vector3, "Firing solution snapshot must expose the howitzer platform world position"):
		return
	if not T.require_true(self, snapshot.get("muzzle_direction_world", null) is Vector3, "Firing solution snapshot must expose the muzzle world direction vector"):
		return
	if not T.require_true(self, snapshot.get("chunk_key", null) is Vector2i, "Firing solution snapshot must expose chunk_key so later world systems can resolve where the shot originated"):
		return
	if not T.require_true(self, str(snapshot.get("chunk_id", "")) != "", "Firing solution snapshot must expose chunk_id so later logs and world events can reference the shot origin chunk"):
		return
	if not T.require_true(self, str(snapshot.get("shell_type_id", "")) != "", "Firing solution snapshot must expose shell_type_id so later ballistic branches are not forced to guess ammunition kind"):
		return
	if not T.require_true(self, float(snapshot.get("muzzle_velocity_mps", 0.0)) > 0.0, "Firing solution snapshot must expose a positive muzzle_velocity_mps value instead of leaving ballistics without a launch speed"):
		return
	if not T.require_true(self, absf(float(snapshot.get("pitch_deg", -999.0)) - 18.25) <= 0.01, "Firing solution snapshot must reuse the formal calibrated pitch contract instead of a separate raw pivot angle"):
		return

	var expected_bearing := _resolve_expected_world_bearing_deg(howitzer, orientation)
	if not T.require_true(self, absf(float(snapshot.get("world_bearing_deg", -999.0)) - expected_bearing) <= 0.05, "Firing solution snapshot must compute yaw as the muzzle's formal world bearing instead of leaking howitzer-local yaw"):
		return

	var snapshot_before_world_turn := snapshot.duplicate(true)
	howitzer.rotation.y = deg_to_rad(111.0)
	await process_frame

	var snapshot_after_world_turn := howitzer.get_firing_solution_snapshot() as Dictionary
	var expected_bearing_after_world_turn := _resolve_expected_world_bearing_deg(howitzer, orientation)
	if not T.require_true(self, absf(float(snapshot_after_world_turn.get("world_bearing_deg", -999.0)) - expected_bearing_after_world_turn) <= 0.05, "Firing solution snapshot must follow the howitzer's true world-facing muzzle direction after the whole platform is turned in world space"):
		return
	if not T.require_true(self, absf(float(snapshot_after_world_turn.get("world_bearing_deg", 0.0)) - float(snapshot_before_world_turn.get("world_bearing_deg", 0.0))) >= 20.0, "Firing solution world bearing must noticeably change when the entire howitzer rotates in world space; otherwise the payload is still reporting a local yaw proxy"):
		return

	var fire_result := howitzer.request_fire() as Dictionary
	if not T.require_true(self, bool(fire_result.get("accepted", false)), "Firing solution contract requires a successful accepted shot so the persisted payload can be verified"):
		return
	if not T.require_true(self, fire_result.get("firing_solution", null) is Dictionary, "Accepted request_fire() must return the formal firing_solution payload instead of only cooldown metadata"):
		return

	var fired_solution := fire_result.get("firing_solution", {}) as Dictionary
	var last_fired_solution := howitzer.get_last_fired_solution() as Dictionary
	if not T.require_true(self, not last_fired_solution.is_empty(), "Accepted fire must persist a last_fired_solution payload on the howitzer runtime"):
		return
	if not T.require_true(self, absf(float(last_fired_solution.get("world_bearing_deg", -999.0)) - float(fired_solution.get("world_bearing_deg", 0.0))) <= 0.01, "Persisted last_fired_solution must match the firing_solution returned from the accepted shot"):
		return
	if not T.require_true(self, absf(float(last_fired_solution.get("pitch_deg", -999.0)) - float(fired_solution.get("pitch_deg", 0.0))) <= 0.01, "Persisted last_fired_solution must preserve the accepted shot's pitch value"):
		return
	if not T.require_true(self, last_fired_solution.get("origin_world_position", null) is Vector3 and (last_fired_solution.get("origin_world_position", Vector3.ZERO) as Vector3).distance_to(fired_solution.get("origin_world_position", Vector3.ZERO) as Vector3) <= 0.001, "Persisted last_fired_solution must preserve the accepted shot's world origin position"):
		return

	howitzer.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _resolve_expected_world_bearing_deg(howitzer: Node3D, orientation) -> float:
	var pitch_pivot := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot") as Node3D
	var muzzle_flash := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFlash") as Node3D
	if pitch_pivot == null or muzzle_flash == null:
		return -999.0
	var world_direction := muzzle_flash.global_position - pitch_pivot.global_position
	world_direction.y = 0.0
	return float(orientation.bearing_deg_from_world_vector(world_direction))
