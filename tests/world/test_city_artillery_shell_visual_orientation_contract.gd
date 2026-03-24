extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SHELL_SCRIPT_PATH := "res://city_game/combat/artillery/CityArtilleryShell.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var shell_script = load(SHELL_SCRIPT_PATH)
	if shell_script == null:
		T.fail_and_quit(self, "Artillery shell visual orientation contract requires CityArtilleryShell.gd")
		return

	var shell := shell_script.new() as Node3D
	if shell == null:
		T.fail_and_quit(self, "Artillery shell visual orientation contract requires CityArtilleryShell.gd to instantiate as Node3D")
		return
	root.add_child(shell)
	await process_frame

	if not T.require_true(self, shell.has_method("configure_from_firing_solution"), "Artillery shell visual orientation contract requires configure_from_firing_solution()"):
		return

	var launch_direction := Vector3(0.82, 0.34, -0.46).normalized()
	shell.configure_from_firing_solution({
		"origin_world_position": Vector3(1024.0, 48.0, -768.0),
		"muzzle_direction_world": launch_direction,
		"muzzle_velocity_mps": 827.0,
	})
	await process_frame

	var visual_root := shell.get_node_or_null("VisualRoot") as Node3D
	if not T.require_true(self, visual_root != null, "Artillery shell visual orientation contract requires a VisualRoot node once configured"):
		return

	var forward_before := (-visual_root.global_transform.basis.z).normalized()
	shell.set("_velocity", Vector3.ZERO)
	shell.call("_sync_flight_visual", Vector3.ZERO, true)
	var forward_after := (-visual_root.global_transform.basis.z).normalized()

	if not T.require_true(self, forward_before.dot(forward_after) >= 0.999, "When shell visual sync receives no valid motion vector, it must preserve the last valid facing instead of snapping to a fallback forward axis"):
		return

	var debug_state_before := shell.get_debug_state() as Dictionary
	var guard_count_before := int(debug_state_before.get("visual_sync_guard_count", -1))
	if not T.require_true(self, guard_count_before >= 0, "Artillery shell debug state must expose visual_sync_guard_count so look_at guard regressions can be verified explicitly"):
		return

	shell.global_position = Vector3(1.0e20, 48.0, -768.0)
	shell.call("_sync_flight_visual", Vector3.RIGHT, true)
	var debug_state_after := shell.get_debug_state() as Dictionary
	if not T.require_true(self, int(debug_state_after.get("visual_sync_guard_count", -1)) == guard_count_before + 1, "When shell look_target collapses onto the same world position as the origin, visual sync must trip the explicit guard instead of still calling look_at()"):
		return
	if not T.require_true(self, str(debug_state_after.get("last_visual_sync_guard_reason", "")) == "look_target_same_as_origin", "Collapsed look_target guard must report look_target_same_as_origin so runtime debugging can distinguish it from zero-vector and non-finite cases"):
		return

	shell.queue_free()
	await process_frame
	T.pass_and_quit(self)
