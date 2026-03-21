extends SceneTree

const T := preload("res://tests/_test_util.gd")

const GUNSHIP_TASK_ID := "task_helicopter_gunship_v37"
const GUNSHIP_START_ANCHOR := Vector3(-8981.45, 0.0, 10796.22)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for helicopter gunship main-world flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	for required_method in [
		"get_task_runtime",
		"get_task_world_marker_state",
		"get_active_route_result",
		"select_task_for_tracking",
		"build_minimap_snapshot",
		"get_helicopter_gunship_encounter_state",
		"get_active_helicopter_gunship",
	]:
		if not T.require_true(self, world.has_method(required_method), "Helicopter gunship flow requires %s()" % required_method):
			return

	var task_runtime = world.get_task_runtime()
	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Helicopter gunship flow requires a teleportable Player"):
		return

	var selected: Dictionary = world.select_task_for_tracking(GUNSHIP_TASK_ID)
	if not T.require_true(self, str(selected.get("task_id", "")) == GUNSHIP_TASK_ID, "Main-world flow must allow the formal gunship task to be tracked directly"):
		return
	if not T.require_true(self, str(world.get_active_route_result().get("route_style_id", "")) == "task_available", "Tracked available gunship task must project the green available route before start"):
		return
	if not T.require_true(self, (world.get_task_world_marker_state().get("themes", []) as Array).has("task_available_start"), "Tracked available gunship task must project the green start ring in world space"):
		return

	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(GUNSHIP_START_ANCHOR + Vector3.UP * standing_height)
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame in range(10):
		await physics_frame
		await process_frame

	if not T.require_true(self, str(task_runtime.get_task_snapshot(GUNSHIP_TASK_ID).get("status", "")) == "active", "Entering the authored chunk_101_178 ring must activate the gunship task end to end"):
		return
	if not T.require_true(self, str(world.get_active_route_result().get("route_style_id", "")) == "task_active", "Active gunship task must switch onto the blue active-task route style"):
		return
	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var route_overlay: Dictionary = minimap_snapshot.get("route_overlay", {})
	if not T.require_true(self, str(route_overlay.get("route_style_id", "")) == "task_active", "Active gunship task must project the blue route style into the minimap overlay"):
		return
	if not T.require_true(self, (world.get_task_world_marker_state().get("themes", []) as Array).has("task_active_objective"), "Active gunship task must project the blue combat objective ring in world space"):
		return
	if not T.require_true(self, str(world.get_helicopter_gunship_encounter_state().get("phase", "")) == "active", "Active gunship task must boot the live main-world helicopter encounter"):
		return

	var gunship := world.get_active_helicopter_gunship() as Node3D
	if not T.require_true(self, gunship != null and gunship.has_method("apply_projectile_hit"), "Main-world helicopter flow requires the live gunship enemy node"):
		return
	for _hit_index in range(24):
		gunship = world.get_active_helicopter_gunship() as Node3D
		if gunship == null:
			break
		gunship.apply_projectile_hit(14.0, gunship.global_position, Vector3.ZERO)
		await physics_frame
		await process_frame

	var reset_observed := false
	for _frame in range(240):
		await physics_frame
		await process_frame
		if str(task_runtime.get_task_snapshot(GUNSHIP_TASK_ID).get("status", "")) == "available":
			reset_observed = true
			break
	if not T.require_true(self, reset_observed, "Main-world gunship flow must loop back to available after helicopter takedown closeout"):
		return
	if not T.require_true(self, str(world.get_active_route_result().get("route_style_id", "")) == "task_available", "After repeatable reset, the tracked gunship task must restore the green available route toward the start ring"):
		return
	if not T.require_true(self, (world.get_task_world_marker_state().get("themes", []) as Array).has("task_available_start"), "After repeatable reset, the green start ring must return in world space"):
		return

	player.teleport_to_world_position(GUNSHIP_START_ANCHOR + Vector3(40.0, standing_height, 0.0))
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame in range(6):
		await physics_frame
		await process_frame
	player.teleport_to_world_position(GUNSHIP_START_ANCHOR + Vector3.UP * standing_height)
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame in range(10):
		await physics_frame
		await process_frame

	if not T.require_true(self, str(task_runtime.get_task_snapshot(GUNSHIP_TASK_ID).get("status", "")) == "active", "After the repeatable reset, re-entering the ring must boot the second helicopter run end to end"):
		return
	if not T.require_true(self, int(world.get_helicopter_gunship_encounter_state().get("activation_count", 0)) >= 2, "Second main-world entry must increment the helicopter encounter activation counter"):
		return

	world.queue_free()
	await process_frame
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
