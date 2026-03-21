extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/HelicopterGunshipLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Helicopter gunship lab contract requires a dedicated F6 lab scene"):
		return

	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Helicopter gunship lab contract must load the lab scene as PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"get_active_gunship",
		"get_encounter_state",
		"start_encounter",
		"reset_lab_state",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Helicopter gunship lab scene must expose %s()" % required_method):
			return

	for required_node_path in [
		"CombatRoot",
		"CombatRoot/Missiles",
		"CombatRoot/EnemyMissiles",
		"Player",
		"EncounterRoot",
		"EncounterRoot/StartTrigger",
		"EncounterRoot/StartTrigger/CollisionShape3D",
		"EncounterRoot/StartRing",
		"EncounterRoot/GunshipSpawnAnchor",
		"EncounterRoot/ActiveGunshipRoot",
	]:
		if not T.require_true(self, lab.get_node_or_null(required_node_path) != null, "Helicopter gunship lab scene must author %s in the scene-first hierarchy" % required_node_path):
			return

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Helicopter gunship lab contract requires the formal Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "Lab player must preserve formal weapon mode switching"):
		return
	if not T.require_true(self, str(player.get_weapon_mode()) == "missile_launcher", "Helicopter gunship lab must boot with the missile launcher equipped"):
		return

	var initial_state: Dictionary = lab.get_encounter_state()
	if not T.require_true(self, str(initial_state.get("phase", "")) == "idle", "Helicopter gunship encounter must boot in idle phase before the ring is entered"):
		return
	if not T.require_true(self, int(initial_state.get("activation_count", -1)) == 0, "Idle helicopter gunship encounters must begin with zero activations"):
		return
	if not T.require_true(self, lab.get_active_gunship() == null, "Idle helicopter gunship lab must not spawn a gunship before the ring trigger"):
		return

	var start_trigger := lab.get_node("EncounterRoot/StartTrigger") as Area3D
	var spawn_anchor := lab.get_node("EncounterRoot/GunshipSpawnAnchor") as Marker3D
	var standing_height := _estimate_standing_height(player)
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(start_trigger.global_position + Vector3(0.0, standing_height, 0.0))
	else:
		player.global_position = start_trigger.global_position + Vector3(0.0, standing_height, 0.0)
	for _frame_index in range(4):
		await physics_frame
		await process_frame

	var active_gunship := lab.get_active_gunship() as Node3D
	if not T.require_true(self, active_gunship != null, "Entering the start ring must formally spawn an active gunship"):
		return
	if not T.require_true(self, active_gunship.scene_file_path == "res://city_game/combat/helicopter/CityHelicopterGunship.tscn", "Lab encounter must spawn the formal gunship scene instead of a script-only substitute"):
		return
	if not T.require_true(self, active_gunship.global_position.distance_to(spawn_anchor.global_position) <= 0.05, "Lab encounter must spawn the gunship at the authored GunshipSpawnAnchor"):
		return

	var active_state: Dictionary = lab.get_encounter_state()
	if not T.require_true(self, str(active_state.get("phase", "")) == "active", "After entering the ring, the encounter phase must become active"):
		return
	if not T.require_true(self, int(active_state.get("activation_count", 0)) == 1, "First ring entry must increment encounter activation_count to 1"):
		return

	lab.start_encounter()
	await process_frame
	if not T.require_true(self, int(lab.get_node("EncounterRoot/ActiveGunshipRoot").get_child_count()) == 1, "Starting an already active encounter must not duplicate the gunship"):
		return

	lab.reset_lab_state()
	await process_frame
	await process_frame

	var reset_state: Dictionary = lab.get_encounter_state()
	if not T.require_true(self, str(reset_state.get("phase", "")) == "idle", "Resetting the lab must restore idle encounter phase"):
		return
	if not T.require_true(self, lab.get_active_gunship() == null, "Resetting the lab must remove the active gunship instance"):
		return

	lab.queue_free()
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
