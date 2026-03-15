extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ring_script := load("res://city_game/world/navigation/CityWorldRingMarker.gd")
	var destination_script := load("res://city_game/world/navigation/CityDestinationWorldMarker.gd")
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if ring_script == null or destination_script == null or scene == null:
		T.fail_and_quit(self, "Task world ring marker contract requires CityWorldRingMarker, CityDestinationWorldMarker, and CityPrototype.tscn")
		return

	var shared_ring = ring_script.new()
	var destination_ring = destination_script.new()
	root.add_child(shared_ring)
	root.add_child(destination_ring)
	await process_frame
	if not T.require_true(self, shared_ring.has_method("set_marker_theme"), "Shared ring marker must expose set_marker_theme()"):
		return
	if not T.require_true(self, destination_ring.has_method("set_marker_theme"), "Destination ring marker must share the set_marker_theme() contract"):
		return
	shared_ring.set_marker_theme("task_available_start")
	destination_ring.set_marker_theme("destination")
	var shared_ring_state: Dictionary = shared_ring.get_state()
	var destination_ring_state: Dictionary = destination_ring.get_state()
	if not T.require_true(self, str(shared_ring_state.get("family_id", "")) == str(destination_ring_state.get("family_id", "")), "Task ring and destination ring must report the same shared marker family id"):
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	if not T.require_true(self, world.has_method("get_task_runtime"), "Task world ring marker contract requires task runtime access"):
		return
	if not T.require_true(self, world.has_method("get_task_slot_index"), "Task world ring marker contract requires task slot index access"):
		return
	if not T.require_true(self, world.has_method("get_task_world_marker_state"), "CityPrototype must expose get_task_world_marker_state() for v14 M3"):
		return

	var task_runtime = world.get_task_runtime()
	var task_slot_index = world.get_task_slot_index()
	var available_tasks: Array = task_runtime.get_tasks_for_status("available")
	var first_task: Dictionary = available_tasks[0]
	var start_slot: Dictionary = task_slot_index.get_slot_by_id(str(first_task.get("start_slot", "")))
	var player := world.get_node_or_null("Player")
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_slot.get("world_anchor", Vector3.ZERO) + Vector3(float(start_slot.get("trigger_radius_m", 0.0)) + 6.0, standing_height, 0.0))
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame_index in range(6):
		await physics_frame
		await process_frame

	var marker_state: Dictionary = world.get_task_world_marker_state()
	if not T.require_true(self, (marker_state.get("themes", []) as Array).has("task_available_start"), "Nearby available start slots must project green task_available_start rings in the world"):
		return
	if not T.require_true(self, (marker_state.get("family_ids", []) as Array).has(str(shared_ring_state.get("family_id", ""))), "World task markers must use the shared world ring family instead of a second marker stack"):
		return

	task_runtime.start_task(str(first_task.get("task_id", "")))
	world.select_task_for_tracking(str(first_task.get("task_id", "")))
	for _frame_index in range(6):
		await physics_frame
		await process_frame

	marker_state = world.get_task_world_marker_state()
	if not T.require_true(self, (marker_state.get("themes", []) as Array).has("task_active_objective"), "Active tasks must project blue task_active_objective rings in the world"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _estimate_standing_height(player) -> float:
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0
