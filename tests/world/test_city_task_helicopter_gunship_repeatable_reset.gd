extends SceneTree

const T := preload("res://tests/_test_util.gd")

const GUNSHIP_TASK_ID := "task_helicopter_gunship_v37"
const GUNSHIP_START_ANCHOR := Vector3(-8981.45, 0.0, 10796.22)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for helicopter gunship repeatable-reset contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	for required_method in [
		"get_task_runtime",
		"get_helicopter_gunship_encounter_state",
		"get_active_helicopter_gunship",
	]:
		if not T.require_true(self, world.has_method(required_method), "Helicopter gunship repeatable-reset contract requires %s()" % required_method):
			return

	var task_runtime = world.get_task_runtime()
	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Helicopter gunship repeatable-reset contract requires a teleportable Player"):
		return

	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(GUNSHIP_START_ANCHOR + Vector3.UP * standing_height)
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame in range(8):
		await physics_frame
		await process_frame

	var gunship := world.get_active_helicopter_gunship() as Node3D
	if not T.require_true(self, gunship != null, "Repeatable-reset contract requires the first gunship run to start from the main-world ring"):
		return

	for _hit_index in range(24):
		gunship = world.get_active_helicopter_gunship() as Node3D
		if gunship == null:
			break
		gunship.apply_projectile_hit(14.0, gunship.global_position, Vector3.ZERO)
		await physics_frame
		await process_frame

	var saw_completed := false
	var reset_to_available := false
	for _frame in range(240):
		await physics_frame
		await process_frame
		var task_snapshot: Dictionary = task_runtime.get_task_snapshot(GUNSHIP_TASK_ID)
		if str(task_snapshot.get("status", "")) == "completed":
			saw_completed = true
		if str(task_snapshot.get("status", "")) == "available":
			reset_to_available = true
			break
	if not T.require_true(self, saw_completed, "Repeatable gunship task must pass through completed before resetting to available again"):
		return
	if not T.require_true(self, reset_to_available, "After helicopter defeat closeout, the main-world task must reset back to available for replay"):
		return

	for _frame in range(12):
		await physics_frame
		await process_frame
	if not T.require_true(self, str(task_runtime.get_task_snapshot(GUNSHIP_TASK_ID).get("status", "")) == "available", "Standing inside the ring after reset must not auto-restart the repeatable gunship task without a fresh re-entry"):
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

	if not T.require_true(self, str(task_runtime.get_task_snapshot(GUNSHIP_TASK_ID).get("status", "")) == "active", "Leaving the reset ring and re-entering it must start a second gunship run"):
		return
	var encounter_state: Dictionary = world.get_helicopter_gunship_encounter_state()
	if not T.require_true(self, int(encounter_state.get("activation_count", 0)) >= 2, "Second main-world ring entry must increment the encounter activation count for the replayable gunship run"):
		return
	if not T.require_true(self, int(task_runtime.get_task_snapshot(GUNSHIP_TASK_ID).get("completion_count", 0)) >= 1, "Repeatable reset must preserve cumulative completion_count across later runs"):
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
