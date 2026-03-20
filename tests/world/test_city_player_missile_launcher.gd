extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for missile launcher contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Missile launcher contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for missile weapon switching"):
		return
	if not T.require_true(self, player.has_method("get_weapon_mode"), "PlayerController must expose get_weapon_mode() for missile weapon verification"):
		return
	if not T.require_true(self, player.has_method("request_missile_launcher_fire"), "PlayerController must expose request_missile_launcher_fire() for missile left-click contract"):
		return
	if not T.require_true(self, world.has_method("get_active_missile_count"), "CityPrototype must expose get_active_missile_count() for missile verification"):
		return
	if not T.require_true(self, world.has_method("get_last_missile_explosion_result"), "CityPrototype must expose get_last_missile_explosion_result() for missile explosion verification"):
		return
	if not T.require_true(self, world.has_method("get_active_projectile_count"), "Missile launcher regression test requires projectile count introspection"):
		return
	if not T.require_true(self, world.has_method("get_active_grenade_count"), "Missile launcher regression test requires grenade count introspection"):
		return
	if not T.require_true(self, world.has_method("get_active_laser_beam_count"), "Missile launcher regression test requires laser beam count introspection"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_crosshair_state"), "Missile launcher contract requires crosshair HUD state"):
		return

	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if not T.require_true(self, camera_rig != null, "Missile launcher contract requires CameraRig for aiming"):
		return

	player.set_weapon_mode("missile_launcher")
	await process_frame

	if not T.require_true(self, player.get_weapon_mode() == "missile_launcher", "Missile launcher must be a formal eighth weapon mode"):
		return
	var launcher_visual := player.get_node_or_null("Visual/RpgLauncherEquippedVisual") as Node3D
	if not T.require_true(self, launcher_visual != null, "Missile launcher mode must mount a dedicated shoulder launcher visual under Player/Visual"):
		return
	if not T.require_true(self, player.has_method("get_missile_launcher_visual_state"), "Missile launcher visual regression requires get_missile_launcher_visual_state()"):
		return
	var launcher_visual_state: Dictionary = player.get_missile_launcher_visual_state()
	if not T.require_true(self, bool(launcher_visual_state.get("equipped_visible", false)), "Switching to weapon 8 must reveal the shoulder-mounted RPG visual"):
		return

	player.set_aim_down_sights_active(true)
	for _frame in range(8):
		await process_frame
	var crosshair_state: Dictionary = hud.get_crosshair_state()
	if not T.require_true(self, bool(crosshair_state.get("visible", false)), "Missile launcher mode must keep the screen-space crosshair visible"):
		return

	var projectile_count_before := int(world.get_active_projectile_count())
	var grenade_count_before := int(world.get_active_grenade_count())
	var laser_beam_count_before := int(world.get_active_laser_beam_count())
	var rifle_fire_started: bool = player.request_primary_fire()
	await process_frame
	if not T.require_true(self, not rifle_fire_started, "Missile launcher mode must not keep firing rifle bullets through request_primary_fire()"):
		return
	if not T.require_true(self, int(world.get_active_projectile_count()) == projectile_count_before, "Missile launcher mode must not spawn projectile nodes"):
		return
	if not T.require_true(self, int(world.get_active_grenade_count()) == grenade_count_before, "Missile launcher mode must not spawn grenade nodes"):
		return
	if not T.require_true(self, int(world.get_active_laser_beam_count()) == laser_beam_count_before, "Missile launcher mode must not spawn laser beams"):
		return

	camera_rig.rotation.x = deg_to_rad(-4.0)
	await process_frame
	var impact_wall := _spawn_test_impact_wall(world, player, 18.0)
	if not T.require_true(self, impact_wall != null, "Missile launcher contract requires a deterministic impact wall for collision verification"):
		return
	await physics_frame
	_aim_player_at_world_position(player, impact_wall.global_position)
	await physics_frame
	var missile_count_before := int(world.get_active_missile_count())
	var impact_fire_started: bool = player.request_missile_launcher_fire()
	await process_frame
	if not T.require_true(self, impact_fire_started, "Missile launcher mode must accept left-click fire requests"):
		return
	launcher_visual_state = player.get_missile_launcher_visual_state()
	if not T.require_true(self, bool(launcher_visual_state.get("fire_fx_active", false)), "Missile launcher fire must trigger the shoulder launcher muzzle flash/recoil FX"):
		return
	if not T.require_true(self, int(launcher_visual_state.get("fire_count", 0)) >= 1, "Missile launcher fire FX must record at least one fire event"):
		return
	if not T.require_true(self, int(world.get_active_missile_count()) == missile_count_before + 1, "Missile launcher fire must increase the active missile count by one"):
		return

	var missile_root := world.get_node_or_null("CombatRoot/Missiles") as Node3D
	if not T.require_true(self, missile_root != null and missile_root.get_child_count() > 0, "Missile launcher must mount live missiles under CombatRoot/Missiles"):
		return
	var impact_missile := missile_root.get_child(missile_root.get_child_count() - 1) as Node3D
	if not T.require_true(self, impact_missile != null, "Missile launcher mode must spawn a live missile node"):
		return
	if not T.require_true(self, impact_missile.has_method("get_velocity"), "Missile node must expose get_velocity() for runtime verification"):
		return
	if not T.require_true(self, impact_missile.has_method("has_exploded"), "Missile node must expose has_exploded() for explosion verification"):
		return
	if not T.require_true(self, impact_missile.has_method("get_distance_travelled_m"), "Missile node must expose get_distance_travelled_m() for 500m self-destruct verification"):
		return

	var missile_visual := impact_missile.find_child("InterceptorMissileVisual", true, false) as Node3D
	if not T.require_true(self, missile_visual != null, "Live missile must reuse the formal InterceptorMissileVisual asset instead of a placeholder sphere"):
		return

	var initial_speed := (impact_missile.get_velocity() as Vector3).length()
	if not T.require_true(self, initial_speed >= 90.0, "Live missile must launch with clearly higher speed than a grenade lob"):
		return

	var impact_exploded := false
	for _frame in range(90):
		await physics_frame
		if impact_missile == null or not is_instance_valid(impact_missile):
			break
		if impact_missile.has_exploded():
			impact_exploded = true
			break
	if not T.require_true(self, impact_exploded, "A wall-targeted missile must explode on world impact instead of tunneling forever"):
		return

	var impact_result: Dictionary = world.get_last_missile_explosion_result()
	if not T.require_true(self, str(impact_result.get("trigger_kind", "")) == "impact", "Impact-fired missile must report impact as the explosion trigger kind"):
		return
	if not T.require_true(self, impact_result.get("world_position", null) is Vector3, "Missile explosion result must expose world_position"):
		return

	var fx_state: Dictionary = player.get_traversal_fx_state()
	if not T.require_true(self, float(fx_state.get("camera_shake_remaining_sec", 0.0)) > 0.0, "Missile explosion must trigger camera shake feedback"):
		return

	camera_rig.rotation.x = deg_to_rad(35.0)
	await process_frame
	missile_count_before = int(world.get_active_missile_count())
	var distance_fire_started: bool = player.request_missile_launcher_fire()
	await process_frame
	if not T.require_true(self, distance_fire_started, "Missile launcher must allow a second fire request for long-flight verification"):
		return
	if not T.require_true(self, int(world.get_active_missile_count()) == missile_count_before + 1, "Second missile fire must spawn another active missile"):
		return

	var distance_missile := missile_root.get_child(missile_root.get_child_count() - 1) as Node3D
	if not T.require_true(self, distance_missile != null, "Missile launcher contract requires the long-flight missile node"):
		return

	var start_position: Vector3 = distance_missile.global_position
	var initial_velocity: Vector3 = distance_missile.get_velocity()
	var initial_direction := initial_velocity.normalized()
	var sway_observed := false
	for _frame in range(28):
		await physics_frame
		if distance_missile == null or not is_instance_valid(distance_missile) or distance_missile.has_exploded():
			break
		var offset := distance_missile.global_position - start_position
		var projected_distance := offset.dot(initial_direction)
		if projected_distance <= 0.0:
			continue
		var projected_position := start_position + initial_direction * projected_distance
		var lateral_offset := distance_missile.global_position.distance_to(projected_position)
		if lateral_offset >= 0.05:
			sway_observed = true
			break
	if not T.require_true(self, sway_observed, "Live missile flight must show non-zero lateral sway instead of a perfectly rigid straight track"):
		return

	var distance_exploded := false
	for _frame in range(260):
		await physics_frame
		if distance_missile == null or not is_instance_valid(distance_missile):
			break
		if distance_missile.has_exploded():
			distance_exploded = true
			break
	if not T.require_true(self, distance_exploded, "Long-flight missile must eventually self-destruct instead of flying forever"):
		return

	var distance_result: Dictionary = world.get_last_missile_explosion_result()
	if not T.require_true(self, str(distance_result.get("trigger_kind", "")) == "max_distance", "Long-flight missile must report max_distance as the explosion trigger kind"):
		return
	if not T.require_true(self, float(distance_result.get("distance_travelled_m", 0.0)) >= 500.0, "Missile max-distance self-destruct must be tied to the formal 500m travel contract"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _spawn_test_impact_wall(world, player, distance_m: float) -> StaticBody3D:
	if world == null or player == null:
		return null
	var trace_segment: Dictionary = player.get_aim_trace_segment() if player.has_method("get_aim_trace_segment") else {}
	var origin: Vector3 = trace_segment.get("origin", player.global_position + Vector3.UP * 1.4)
	var target: Vector3 = trace_segment.get("target", origin + Vector3.FORWARD * distance_m)
	var direction := (target - origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	var wall := StaticBody3D.new()
	wall.name = "MissileImpactWall"
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(10.0, 10.0, 1.2)
	collision_shape.shape = box_shape
	wall.add_child(collision_shape)
	world.add_child(wall)
	wall.global_position = origin + direction * maxf(distance_m, 8.0)
	wall.look_at(origin, Vector3.UP, true)
	return wall

func _aim_player_at_world_position(player, target_world_position: Vector3) -> void:
	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig == null:
		return
	var aim_origin: Vector3 = camera.global_position if camera != null else player.global_position + Vector3.UP * 1.4
	var delta: Vector3 = target_world_position - aim_origin
	var planar_length := maxf(Vector2(delta.x, delta.z).length(), 0.001)
	player.rotation.y = atan2(-delta.x, -delta.z)
	var pitch_limits: Dictionary = player.get_pitch_limits_degrees()
	var min_pitch := deg_to_rad(float(pitch_limits.get("min", -68.0)))
	var max_pitch := deg_to_rad(float(pitch_limits.get("max", 35.0)))
	camera_rig.rotation.x = clampf(-atan2(delta.y, planar_length), min_pitch, max_pitch)
