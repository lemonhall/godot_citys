extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ring_script := load("res://city_game/world/navigation/CityWorldRingMarker.gd")
	if ring_script == null:
		T.fail_and_quit(self, "Task theme marker profile requires CityWorldRingMarker.gd")
		return

	var ring: Node3D = ring_script.new()
	root.add_child(ring)
	await process_frame

	ring.set_marker_theme("destination")
	var destination_state: Dictionary = ring.get_state()
	if not T.require_true(self, int(destination_state.get("visible_flame_column_count", -1)) == 0, "Unified world marker profile should keep destination flames disabled just like task markers"):
		return
	if not T.require_true(self, int(destination_state.get("visible_cross_segment_count", -1)) == 0, "Unified world marker profile should keep destination cross-ring detail aligned with task markers"):
		return

	ring.set_marker_theme("task_available_start")
	var available_task_state: Dictionary = ring.get_state()
	if not T.require_true(self, int(available_task_state.get("visible_flame_column_count", -1)) == int(destination_state.get("visible_flame_column_count", -2)), "Available task marker should share the same flame visibility profile as destination markers"):
		return
	if not T.require_true(self, int(available_task_state.get("visible_cross_segment_count", -1)) == int(destination_state.get("visible_cross_segment_count", -2)), "Available task marker should share the same cross-ring visibility profile as destination markers"):
		return

	ring.set_marker_theme("task_active_objective")
	var active_task_state: Dictionary = ring.get_state()
	if not T.require_true(self, int(active_task_state.get("visible_flame_column_count", -1)) == int(destination_state.get("visible_flame_column_count", -2)), "Active task marker should share the same flame visibility profile as destination markers"):
		return
	if not T.require_true(self, int(active_task_state.get("visible_cross_segment_count", -1)) == int(destination_state.get("visible_cross_segment_count", -2)), "Active task marker should share the same cross-ring visibility profile as destination markers"):
		return

	ring.queue_free()
	T.pass_and_quit(self)
