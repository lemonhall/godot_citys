extends SceneTree

const T := preload("res://tests/_test_util.gd")

const GUNSHIP_TASK_ID := "task_helicopter_gunship_v37"
const GUNSHIP_COMPLETION_EVENT_ID := "encounter:helicopter_gunship_v37"
const GUNSHIP_START_ANCHOR := Vector3(-8981.45, 0.0, 10796.22)
const GUNSHIP_CHUNK_ID := "chunk_101_178"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for helicopter gunship event-completion contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	for required_method in [
		"get_task_runtime",
		"get_task_slot_index",
		"get_helicopter_gunship_encounter_state",
		"get_active_helicopter_gunship",
	]:
		if not T.require_true(self, world.has_method(required_method), "Helicopter gunship event-completion contract requires %s()" % required_method):
			return

	var task_runtime = world.get_task_runtime()
	var task_slot_index = world.get_task_slot_index()
	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Helicopter gunship event-completion contract requires a teleportable Player"):
		return

	var task_snapshot: Dictionary = task_runtime.get_task_snapshot(GUNSHIP_TASK_ID)
	if not T.require_true(self, str(task_snapshot.get("task_id", "")) == GUNSHIP_TASK_ID, "Main world task runtime must expose the formal v37 gunship task id"):
		return
	if not T.require_true(self, str(task_snapshot.get("completion_mode", "")) == "event", "Gunship main-world task must freeze completion_mode to event instead of objective-slot touch completion"):
		return
	if not T.require_true(self, str(task_snapshot.get("completion_event_id", "")) == GUNSHIP_COMPLETION_EVENT_ID, "Gunship main-world task must expose the formal completion_event_id for encounter-driven completion"):
		return
	if not T.require_true(self, bool(task_snapshot.get("repeatable", false)), "Gunship main-world task must be formally marked repeatable"):
		return

	var start_slot: Dictionary = task_slot_index.get_slot_by_id(str(task_snapshot.get("start_slot", "")))
	if not T.require_true(self, str(start_slot.get("chunk_id", "")) == GUNSHIP_CHUNK_ID, "Gunship start slot must live in chunk_101_178"):
		return
	if not T.require_true(self, (start_slot.get("world_anchor", Vector3.ZERO) as Vector3).distance_to(GUNSHIP_START_ANCHOR) <= 0.05, "Gunship start slot must freeze to the authored chunk_101_178 world anchor"):
		return

	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(GUNSHIP_START_ANCHOR + Vector3.UP * standing_height)
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame in range(8):
		await physics_frame
		await process_frame

	task_snapshot = task_runtime.get_task_snapshot(GUNSHIP_TASK_ID)
	if not T.require_true(self, str(task_snapshot.get("status", "")) == "active", "Entering the chunk_101_178 ring must activate the formal gunship task"):
		return

	var objective_slot: Dictionary = task_runtime.get_current_objective_slot(GUNSHIP_TASK_ID)
	if not T.require_true(self, not objective_slot.is_empty(), "Active gunship task must still expose a formal objective slot for shared route/world ring semantics"):
		return

	for _frame in range(10):
		await physics_frame
		await process_frame
	task_snapshot = task_runtime.get_task_snapshot(GUNSHIP_TASK_ID)
	if not T.require_true(self, str(task_snapshot.get("status", "")) == "active", "Standing inside the combat area must not complete the gunship task by slot touch; completion must come from the encounter event"):
		return

	var encounter_state: Dictionary = world.get_helicopter_gunship_encounter_state()
	if not T.require_true(self, str(encounter_state.get("phase", "")) == "active", "Starting the gunship task in main world must boot the live helicopter encounter runtime"):
		return

	var gunship := world.get_active_helicopter_gunship() as Node3D
	if not T.require_true(self, gunship != null and gunship.has_method("apply_projectile_hit"), "Main-world gunship task must expose the live helicopter enemy for formal event-completion verification"):
		return

	var completed := false
	for _hit_index in range(24):
		gunship = world.get_active_helicopter_gunship() as Node3D
		if gunship == null:
			break
		gunship.apply_projectile_hit(14.0, gunship.global_position, Vector3.ZERO)
		await physics_frame
		await process_frame
		task_snapshot = task_runtime.get_task_snapshot(GUNSHIP_TASK_ID)
		if str(task_snapshot.get("status", "")) == "completed":
			completed = true
			break
	if not T.require_true(self, completed, "Destroying the live helicopter in main world must complete the task through the formal encounter event chain"):
		return
	if not T.require_true(self, int(task_snapshot.get("completion_count", 0)) >= 1, "Gunship event completion must increment completion_count when the helicopter is defeated"):
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
