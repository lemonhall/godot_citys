extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/HelicopterGunshipLab.tscn"
const MISSILE_SCENE_PATH := "res://city_game/combat/CityMissile.tscn"
const MAX_ALLOWED_GUNSHIP_MISSILES_WITHIN_OBSERVATION := 4
const MIN_WINDPRESSURE_CROSSHAIR_OFFSET_PX := 5.0
const MIN_WINDPRESSURE_PROJECTILE_DRIFT_DEG := 0.6
const MIN_GUNSHIP_ALTITUDE_WEAVE_M := 8.5
const MIN_CRASH_DROP_M := 5.0

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

	var hud := lab.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "Helicopter gunship lab must mount a formal Hud so the combat crosshair stays visible"):
		return
	if not T.require_true(self, hud.has_method("get_crosshair_state"), "Helicopter gunship lab Hud must expose get_crosshair_state() for aim verification"):
		return

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
	if not T.require_true(self, player.has_method("get_pitch_limits_degrees"), "Helicopter gunship lab player must expose pitch limit introspection for anti-air combat tuning"):
		return
	var pitch_limits: Dictionary = player.get_pitch_limits_degrees()
	if not T.require_true(self, float(pitch_limits.get("min", 0.0)) <= -80.0, "Helicopter gunship lab must allow a steeper upward look angle so the player can lock the gunship overhead"):
		return
	var crosshair_state: Dictionary = hud.get_crosshair_state()
	if not T.require_true(self, bool(crosshair_state.get("visible", false)), "Helicopter gunship lab HUD must keep the crosshair visible during missile combat"):
		return
	if not T.require_true(self, crosshair_state.get("world_target", null) is Vector3, "Helicopter gunship lab crosshair state must preserve a world_target Vector3"):
		return
	if not T.require_true(self, (crosshair_state.get("world_target", Vector3.ZERO) as Vector3).distance_to(player.get_aim_target_world_position()) <= 0.1, "Helicopter gunship lab HUD crosshair must stay aligned with the player aim target"):
		return

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
	if not T.require_true(self, player.has_method("get_traversal_fx_state"), "Helicopter gunship lab player must expose traversal FX state so close-range wind pressure camera shake can be verified"):
		return

	var ambient_pressure_shake_seen := false
	var wind_pressure_crosshair_offset_px := 0.0
	var wind_pressure_projectile_drift_deg := 0.0
	lab.aim_player_at_world_position(safe_target)
	await physics_frame
	var calm_spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	var calm_ideal_direction := (safe_target - calm_spawn_transform.origin).normalized()
	for _frame in range(24):
		await physics_frame
		await process_frame
		var ambient_fx_state: Dictionary = player.get_traversal_fx_state()
		if float(ambient_fx_state.get("camera_shake_remaining_sec", 0.0)) > 0.0 and float(ambient_fx_state.get("camera_shake_amplitude_m", 0.0)) >= 0.04:
			ambient_pressure_shake_seen = true
		var disturbed_crosshair_state: Dictionary = hud.get_crosshair_state()
		var viewport_size: Vector2 = disturbed_crosshair_state.get("viewport_size", Vector2.ZERO)
		var crosshair_screen_position: Vector2 = disturbed_crosshair_state.get("screen_position", viewport_size * 0.5)
		wind_pressure_crosshair_offset_px = maxf(
			wind_pressure_crosshair_offset_px,
			crosshair_screen_position.distance_to(viewport_size * 0.5)
		)
		var disturbed_direction: Vector3 = player.get_projectile_direction()
		if disturbed_direction.length_squared() > 0.0001 and calm_ideal_direction.length_squared() > 0.0001:
			wind_pressure_projectile_drift_deg = maxf(
				wind_pressure_projectile_drift_deg,
				rad_to_deg(disturbed_direction.angle_to(calm_ideal_direction))
			)
	if not T.require_true(self, ambient_pressure_shake_seen, "Helicopter gunships hovering only 28m away must impose an immediate wind-pressure camera shake even before missiles start landing nearby"):
		return
	if not T.require_true(self, wind_pressure_crosshair_offset_px >= MIN_WINDPRESSURE_CROSSHAIR_OFFSET_PX, "Gunship wind pressure must visibly drag the crosshair off screen center instead of only shaking the camera transform behind a perfectly stable reticle"):
		return
	if not T.require_true(self, wind_pressure_projectile_drift_deg >= MIN_WINDPRESSURE_PROJECTILE_DRIFT_DEG, "Gunship wind pressure must perturb the actual missile launch direction, not just the look of the camera shake"):
		return

	var disturbed_player_missile := lab.fire_player_missile_launcher() as Node3D
	if not T.require_true(self, disturbed_player_missile != null, "Wind-pressure combat contract requires a live player missile to verify disturbed launch direction"):
		return
	if not T.require_true(self, disturbed_player_missile.has_method("get_velocity"), "Wind-pressure missile verification requires live missiles to expose get_velocity()"):
		return
	var disturbed_launch_direction := (disturbed_player_missile.get_velocity() as Vector3).normalized()
	if not T.require_true(self, rad_to_deg(disturbed_launch_direction.angle_to(calm_ideal_direction)) >= MIN_WINDPRESSURE_PROJECTILE_DRIFT_DEG, "Player missiles fired under rotor wash must actually leave the tube on a disturbed heading instead of secretly preserving the calm ideal aim vector"):
		return

	var initial_gunship_position := gunship.global_position
	var moved := false
	var enemy_missile_seen := false
	var enemy_explosion_shake_seen := false
	var min_gunship_height := gunship.global_position.y
	var max_gunship_height := gunship.global_position.y
	var max_missile_fire_index := 0
	var observed_enemy_missile_scene_path := ""
	var observed_enemy_missile_damage := -1.0
	for _frame in range(240):
		await physics_frame
		await process_frame
		gunship = lab.get_active_gunship() as Node3D
		if gunship != null:
			if gunship.global_position.distance_to(initial_gunship_position) > 0.8:
				moved = true
			min_gunship_height = minf(min_gunship_height, gunship.global_position.y)
			max_gunship_height = maxf(max_gunship_height, gunship.global_position.y)
			var combat_state: Dictionary = gunship.get_combat_state()
			max_missile_fire_index = maxi(max_missile_fire_index, int(combat_state.get("missile_fire_index", 0)))
		if int(lab.get_active_enemy_missile_count()) > 0 and moved and max_gunship_height - min_gunship_height > 1.6:
			enemy_missile_seen = true
			if observed_enemy_missile_scene_path == "":
				var enemy_missile_root_during_combat := lab.get_node("CombatRoot/EnemyMissiles") as Node3D
				if enemy_missile_root_during_combat != null and enemy_missile_root_during_combat.get_child_count() > 0:
					var observed_enemy_missile := enemy_missile_root_during_combat.get_child(0) as Node3D
					if observed_enemy_missile != null:
						observed_enemy_missile_scene_path = observed_enemy_missile.scene_file_path
						observed_enemy_missile_damage = float(observed_enemy_missile.get("explosion_damage"))
		var fx_state_during_combat: Dictionary = player.get_traversal_fx_state()
		if float(fx_state_during_combat.get("camera_shake_remaining_sec", 0.0)) > 0.0 and float(fx_state_during_combat.get("camera_shake_amplitude_m", 0.0)) >= 0.12:
			enemy_explosion_shake_seen = true
	if not T.require_true(self, moved, "Active helicopter gunships must move through an orbit/hover path instead of hanging motionless in the sky"):
		return
	if not T.require_true(self, max_gunship_height - min_gunship_height >= MIN_GUNSHIP_ALTITUDE_WEAVE_M, "Active helicopter gunships must climb roughly ten meters above their baseline and then come back down, otherwise the vertical motion still reads too flat in combat"):
		return
	if not T.require_true(self, enemy_missile_seen, "Active helicopter gunships must keep firing enemy missiles with no ammo cap"):
		return
	if not T.require_true(self, max_missile_fire_index > 0 and max_missile_fire_index <= MAX_ALLOWED_GUNSHIP_MISSILES_WITHIN_OBSERVATION, "Helicopter gunships must attack less aggressively now; the current fire rate is still too spammy for close-range air combat"):
		return
	if not T.require_true(self, enemy_explosion_shake_seen, "Helicopter gunship missile explosions must kick visible player camera shake even though the encounter still has no failure state"):
		return

	if not T.require_true(self, observed_enemy_missile_scene_path != "", "Combat observation must capture at least one live enemy missile instance for runtime contract verification"):
		return
	if not T.require_true(self, observed_enemy_missile_scene_path == MISSILE_SCENE_PATH, "Gunship missiles must reuse the formal CityMissile scene instead of a placeholder projectile"):
		return
	if not T.require_true(self, is_equal_approx(observed_enemy_missile_damage, 0.0), "Gunship missiles must be configured as zero-damage visuals because this encounter has no player failure state yet"):
		return

	var health_state: Dictionary = gunship.get_health_state()
	if not T.require_true(self, bool(health_state.get("alive", false)), "Fresh encounter gunships must begin alive before the player starts landing missiles"):
		return

	for _hit_index in range(10):
		gunship.apply_projectile_hit(14.0, gunship.global_position, Vector3.ZERO)
	health_state = gunship.get_health_state()
	if not T.require_true(self, bool(health_state.get("alive", false)), "Helicopter gunships must survive ten player missile-equivalent hits before being defeated"):
		return

	var crash_started := false
	var crash_fx_visible := false
	var crash_start_height := 0.0
	var crash_drop_distance_m := 0.0
	for _hit_index in range(6):
		gunship = lab.get_active_gunship() as Node3D
		if gunship == null:
			break
		gunship.apply_projectile_hit(14.0, gunship.global_position, Vector3.ZERO)
		await physics_frame
		await process_frame
		gunship = lab.get_active_gunship() as Node3D
		if gunship == null:
			break
		var crash_state: Dictionary = gunship.get_combat_state()
		if str(crash_state.get("crash_state", "")) != "":
			crash_started = true
			crash_start_height = gunship.global_position.y
			crash_fx_visible = bool(crash_state.get("death_fx_visible", false))
			break
	if not T.require_true(self, crash_started, "Defeated helicopter gunships must enter an airburst crash sequence instead of disappearing the instant their health reaches zero"):
		return

	var defeated := false
	for _frame in range(150):
		await physics_frame
		await process_frame
		gunship = lab.get_active_gunship() as Node3D
		if gunship == null:
			var state_after_crash: Dictionary = lab.get_encounter_state()
			if str(state_after_crash.get("phase", "")) == "idle":
				defeated = true
				break
			continue
		var crash_state: Dictionary = gunship.get_combat_state()
		crash_fx_visible = crash_fx_visible or bool(crash_state.get("death_fx_visible", false))
		crash_drop_distance_m = maxf(crash_drop_distance_m, crash_start_height - gunship.global_position.y)
	if not T.require_true(self, crash_fx_visible, "Defeated helicopter gunships must show an airborne explosion effect before the crash cleanup completes"):
		return
	if not T.require_true(self, crash_drop_distance_m >= MIN_CRASH_DROP_M, "Defeated helicopter gunships must visibly lose altitude and fall after the airburst instead of vanishing in place"):
		return
	if not T.require_true(self, defeated, "Sustained player missile damage must eventually defeat the helicopter, finish the crash sequence, and end the encounter"):
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
