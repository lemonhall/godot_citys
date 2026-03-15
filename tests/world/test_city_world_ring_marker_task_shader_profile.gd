extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ring_script := load("res://city_game/world/navigation/CityWorldRingMarker.gd")
	if ring_script == null:
		T.fail_and_quit(self, "Task shader marker profile requires CityWorldRingMarker.gd")
		return

	var ring: Node3D = ring_script.new()
	root.add_child(ring)
	await process_frame

	ring.set_marker_theme("destination")
	var destination_state: Dictionary = ring.get_state()
	if not T.require_true(self, str(destination_state.get("effect_driver_id", "")) == "gpu_unified_shader", "Manual destination marker should switch onto the shared GPU-driven shader profile"):
		return
	if not T.require_true(self, int(destination_state.get("shader_layer_count", 0)) >= 3, "Manual destination marker should expose shader-driven outer, inner, and core layers"):
		return

	ring.set_marker_theme("task_available_start")
	var available_task_state: Dictionary = ring.get_state()
	if not T.require_true(self, str(available_task_state.get("effect_driver_id", "")) == str(destination_state.get("effect_driver_id", "")), "Available task marker should share the same GPU driver profile as manual destination markers"):
		return
	if not T.require_true(self, int(available_task_state.get("shader_layer_count", 0)) == int(destination_state.get("shader_layer_count", -1)), "Available task marker should expose the same shader-driven layer count as manual destination markers"):
		return

	ring.set_marker_theme("task_active_objective")
	var active_task_state: Dictionary = ring.get_state()
	if not T.require_true(self, str(active_task_state.get("effect_driver_id", "")) == str(destination_state.get("effect_driver_id", "")), "Active task marker should share the same GPU driver profile as manual destination markers"):
		return
	if not T.require_true(self, int(active_task_state.get("shader_layer_count", 0)) == int(destination_state.get("shader_layer_count", -1)), "Active task marker should expose the same shader-driven layer count as manual destination markers"):
		return

	ring.queue_free()
	T.pass_and_quit(self)
