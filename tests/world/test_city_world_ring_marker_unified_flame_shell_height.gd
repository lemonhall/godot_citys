extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ring_script := load("res://city_game/world/navigation/CityWorldRingMarker.gd")
	if ring_script == null:
		T.fail_and_quit(self, "Unified flame shell height requires CityWorldRingMarker.gd")
		return

	var ring: Node3D = ring_script.new()
	root.add_child(ring)
	await process_frame

	ring.set_marker_theme("destination")
	var destination_state: Dictionary = ring.get_state()
	if not T.require_true(self, float(destination_state.get("outer_shell_height_m", 0.0)) >= 2.0, "Unified GPU route marker should expose a tall outer flame shell for far-distance readability"):
		return

	ring.set_marker_theme("task_available_start")
	var available_state: Dictionary = ring.get_state()
	if not T.require_true(self, is_equal_approx(float(available_state.get("outer_shell_height_m", -1.0)), float(destination_state.get("outer_shell_height_m", -2.0))), "Available task marker should share the same outer flame shell height as manual destination markers"):
		return

	ring.set_marker_theme("task_active_objective")
	var active_state: Dictionary = ring.get_state()
	if not T.require_true(self, is_equal_approx(float(active_state.get("outer_shell_height_m", -1.0)), float(destination_state.get("outer_shell_height_m", -2.0))), "Active task marker should share the same outer flame shell height as manual destination markers"):
		return

	ring.queue_free()
	T.pass_and_quit(self)
