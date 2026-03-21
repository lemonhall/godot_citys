extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/HelicopterGunshipLab.tscn"
const MISSILE_SCENE_PATH := "res://city_game/combat/CityMissile.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if scene == null:
		T.fail_and_quit(self, "Repeatable helicopter combat contract requires the dedicated lab scene")
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"fire_player_missile_launcher",
		"fire_missile_at_world_position",
		"aim_player_at_world_position",
		"get_active_player_missile_count",
		"get_active_enemy_missile_count",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Helicopter gunship lab combat contract must expose %s()" % required_method):
			return

	var safe_target := Vector3(120.0, 12.0, 220.0)
	lab.aim_player_at_world_position(safe_target)
	await physics_frame

	var player_missile := lab.fire_missile_at_world_position(safe_target) as Node3D
	if not T.require_true(self, player_missile != null, "Helicopter gunship lab must let the player spawn a formal missile for live combat debugging"):
		return
	if not T.require_true(self, player_missile.scene_file_path == MISSILE_SCENE_PATH, "Player missile firing in the helicopter lab must reuse the formal CityMissile scene"):
		return
	if not T.require_true(self, int(lab.get_active_player_missile_count()) >= 1, "Player missile firing must mount the missile under CombatRoot/Missiles"):
		return

	var player := lab.get_node("Player")
	var start_trigger := lab.get_node("EncounterRoot/StartTrigger") as Area3D
	var standing_height := _estimate_standing_height(player)
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(start_trigger.global_position + Vector3(0.0, standing_height, 0.0))
	else:
		player.global_position = start_trigger.global_position + Vector3(0.0, standing_height, 0.0)

	var gunship := await _await_active_gunship(lab, 90)
	if not T.require_true(self, gunship != null, "Entering the ring must activate the live helicopter encounter"):
		return
	if not T.require_true(self, gunship.has_signal("missile_fire_requested"), "Active helicopter gunships must emit missile_fire_requested for runtime-owned enemy missiles"):
		return
	if not T.require_true(self, gunship.has_method("get_combat_state"), "Active helicopter gunships must expose get_combat_state() for focused orbit and fire verification"):
		return

	var initial_gunship_position := gunship.global_position
	var moved := false
	var enemy_missile_seen := false
	for _frame in range(150):
		await physics_frame
		await process_frame
		gunship = lab.get_active_gunship() as Node3D
		if gunship != null and gunship.global_position.distance_to(initial_gunship_position) > 0.8:
			moved = true
		if int(lab.get_active_enemy_missile_count()) > 0:
			enemy_missile_seen = true
			break
	if not T.require_true(self, moved, "Active helicopter gunships must move through an orbit/hover path instead of hanging motionless in the sky"):
		return
	if not T.require_true(self, enemy_missile_seen, "Active helicopter gunships must keep firing enemy missiles with no ammo cap"):
		return

	var enemy_missile_root := lab.get_node("CombatRoot/EnemyMissiles") as Node3D
	var enemy_missile := enemy_missile_root.get_child(0) as Node3D if enemy_missile_root.get_child_count() > 0 else null
	if not T.require_true(self, enemy_missile != null, "Enemy missile root must contain the live missile that the gunship fired"):
		return
	if not T.require_true(self, enemy_missile.scene_file_path == MISSILE_SCENE_PATH, "Gunship missiles must reuse the formal CityMissile scene instead of a placeholder projectile"):
		return
	if not T.require_true(self, is_equal_approx(float(enemy_missile.get("explosion_damage")), 0.0), "Gunship missiles must be configured as zero-damage visuals because this encounter has no player failure state yet"):
		return

	var health_state: Dictionary = gunship.get_health_state()
	if not T.require_true(self, bool(health_state.get("alive", false)), "Fresh encounter gunships must begin alive before the player starts landing missiles"):
		return

	for _hit_index in range(10):
		gunship.apply_projectile_hit(14.0, gunship.global_position, Vector3.ZERO)
	health_state = gunship.get_health_state()
	if not T.require_true(self, bool(health_state.get("alive", false)), "Helicopter gunships must survive ten player missile-equivalent hits before being defeated"):
		return

	var defeated := false
	for _hit_index in range(6):
		gunship = lab.get_active_gunship() as Node3D
		if gunship == null:
			break
		gunship.apply_projectile_hit(14.0, gunship.global_position, Vector3.ZERO)
		await physics_frame
		await process_frame
		var state_after_hit: Dictionary = lab.get_encounter_state()
		if str(state_after_hit.get("phase", "")) == "idle" and lab.get_active_gunship() == null:
			defeated = true
			break
	if not T.require_true(self, defeated, "Sustained player missile damage must eventually defeat the helicopter and end the encounter"):
		return

	var completed_state: Dictionary = lab.get_encounter_state()
	if not T.require_true(self, int(completed_state.get("completion_count", 0)) == 1, "First helicopter takedown must increment completion_count to 1 for repeatable task tracking"):
		return
	if not T.require_true(self, int(lab.get_active_enemy_missile_count()) == 0, "Completing the helicopter encounter must clear leftover enemy missiles before returning to idle"):
		return
	if not T.require_true(self, bool(completed_state.get("start_ring_visible", false)), "Completed helicopter encounters must re-show the green start ring for the next repeat"):
		return

	var reset_position := start_trigger.global_position + Vector3(0.0, standing_height, 32.0)
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(reset_position)
	else:
		player.global_position = reset_position
	for _frame in range(3):
		await physics_frame
		await process_frame

	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(start_trigger.global_position + Vector3(0.0, standing_height, 0.0))
	else:
		player.global_position = start_trigger.global_position + Vector3(0.0, standing_height, 0.0)

	gunship = await _await_active_gunship(lab, 90)
	if not T.require_true(self, gunship != null, "After leaving and re-entering the ring, the repeatable helicopter encounter must activate again"):
		return

	var repeated_state: Dictionary = lab.get_encounter_state()
	if not T.require_true(self, int(repeated_state.get("activation_count", 0)) == 2, "Second ring entry must increment helicopter encounter activation_count to 2"):
		return
	if not T.require_true(self, int(repeated_state.get("completion_count", 0)) == 1, "Starting the next repeat must preserve the cumulative completion_count from earlier clears"):
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
