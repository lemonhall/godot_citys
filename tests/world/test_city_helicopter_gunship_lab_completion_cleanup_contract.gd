extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/HelicopterGunshipLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Helicopter gunship lab completion cleanup contract requires the dedicated lab scene"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player")
	var start_trigger := lab.get_node_or_null("EncounterRoot/StartTrigger") as Area3D
	if not T.require_true(self, player != null and start_trigger != null, "Helicopter gunship lab completion cleanup contract requires the formal Player and EncounterRoot/StartTrigger nodes"):
		return

	var standing_height := _estimate_standing_height(player)
	_move_player(player, start_trigger.global_position + Vector3(0.0, standing_height, 0.0))
	var gunship := await _await_active_gunship(lab, 120)
	if not T.require_true(self, gunship != null, "Entering the start ring must activate a gunship before cleanup can be verified"):
		return

	var missiles_fired := 0
	for _shot in range(20):
		gunship = lab.get_active_gunship() as Node3D
		if gunship == null:
			break
		lab.aim_player_at_world_position(gunship.global_position)
		lab.fire_missile_at_world_position(gunship.global_position)
		missiles_fired += 1
		for _frame in range(18):
			await physics_frame
			await process_frame
		if str(lab.get_encounter_state().get("phase", "")) == "idle":
			break

	if not T.require_true(self, missiles_fired >= 12, "Cleanup verification must drive the helicopter down through the live player-missile path instead of direct fake damage"):
		return

	var encounter_state: Dictionary = lab.get_encounter_state()
	if not T.require_true(self, str(encounter_state.get("phase", "")) == "idle", "Defeating the helicopter through live missiles must return the encounter to idle phase"):
		return
	if not T.require_true(self, int(encounter_state.get("completion_count", 0)) == 1, "First live missile takedown must increment completion_count to 1"):
		return
	if not T.require_true(self, int(lab.get_active_enemy_missile_count()) == 0, "Encounter completion must clear all enemy missiles before the next repeat begins"):
		return
	if not T.require_true(self, int(lab.get_active_player_missile_count()) == 0, "Encounter completion must also clear leftover player missiles so the lab truly returns to its initial repeatable state"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _await_active_gunship(lab: Node3D, frame_budget: int) -> Node3D:
	for _frame in range(frame_budget):
		await physics_frame
		await process_frame
		var gunship := lab.get_active_gunship() as Node3D
		if gunship != null:
			return gunship
	return null

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

func _move_player(player, world_position: Vector3) -> void:
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(world_position)
	else:
		player.global_position = world_position
