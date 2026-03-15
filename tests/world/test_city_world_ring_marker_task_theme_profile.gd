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
	if not T.require_true(self, int(destination_state.get("visible_flame_column_count", 0)) > 0, "Manual destination marker must keep the higher-fidelity flame columns"):
		return
	if not T.require_true(self, int(destination_state.get("visible_cross_segment_count", 0)) > 0, "Manual destination marker must keep the cross-ring detail"):
		return

	ring.set_marker_theme("task_available_start")
	var available_task_state: Dictionary = ring.get_state()
	if not T.require_true(self, int(available_task_state.get("visible_flame_column_count", 1)) == 0, "Available task markers should disable flame columns to keep the task cue lightweight"):
		return
	if not T.require_true(self, int(available_task_state.get("visible_cross_segment_count", 1)) == 0, "Available task markers should disable the cross-ring layer to reduce per-frame marker churn"):
		return

	ring.set_marker_theme("task_active_objective")
	var active_task_state: Dictionary = ring.get_state()
	if not T.require_true(self, int(active_task_state.get("visible_flame_column_count", 1)) == 0, "Active task markers should disable flame columns to keep the objective cue lightweight"):
		return
	if not T.require_true(self, int(active_task_state.get("visible_cross_segment_count", 1)) == 0, "Active task markers should disable the cross-ring layer to reduce per-frame marker churn"):
		return

	ring.queue_free()
	T.pass_and_quit(self)
