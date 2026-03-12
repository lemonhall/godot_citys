extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for trauma enemy dodge contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for trauma enemy combat tests"):
		return
	if not T.require_true(self, world.has_method("spawn_trauma_enemy"), "CityPrototype must expose spawn_trauma_enemy() for combat encounters"):
		return
	if not T.require_true(self, world.has_method("spawn_trauma_enemy_at_world_position"), "CityPrototype must expose spawn_trauma_enemy_at_world_position() for directed encounter tests"):
		return
	if not T.require_true(self, world.has_method("fire_player_projectile_toward"), "CityPrototype must expose fire_player_projectile_toward() for aimed combat tests"):
		return
	if not T.require_true(self, world.has_method("get_active_enemy_count"), "CityPrototype must expose get_active_enemy_count() for encounter verification"):
		return

	var enemy = world.spawn_trauma_enemy()
	if not T.require_true(self, enemy != null, "Spawn request must create a trauma enemy node"):
		return
	if not T.require_true(self, int(world.get_active_enemy_count()) == 1, "Spawn request must register exactly one active trauma enemy"):
		return
	if not T.require_true(self, enemy.has_method("get_dodge_count"), "Trauma enemy must expose get_dodge_count() for dodge verification"):
		return
	if not T.require_true(self, enemy.has_method("get_last_dodge_offset"), "Trauma enemy must expose get_last_dodge_offset() for dodge verification"):
		return
	if not T.require_true(self, enemy.has_method("get_behavior_mode"), "Trauma enemy must expose get_behavior_mode() for pressure/orbit verification"):
		return
	if not T.require_true(self, enemy.global_position.distance_to(player.global_position) >= 28.0, "Trauma enemy spawn must begin at a meaningful stand-off distance before it starts pressing the player"):
		return

	var projectile = world.fire_player_projectile_toward(enemy.global_position)
	if not T.require_true(self, projectile != null, "Aimed player fire must still spawn a projectile"):
		return

	var dodged := false
	for _frame in range(48):
		await physics_frame
		if not is_instance_valid(enemy):
			break
		if int(enemy.get_dodge_count()) > 0:
			dodged = true
			break

	if not T.require_true(self, dodged, "Trauma enemy must dodge an incoming player projectile instead of face-tanking it"):
		return

	var dodge_offset: Vector3 = enemy.get_last_dodge_offset()
	if not T.require_true(self, dodge_offset.length() >= 4.0, "Trauma enemy dodge must create a clearly visible relocation burst"):
		return
	if not T.require_true(self, int(world.get_active_enemy_count()) == 1, "A successful dodge should keep the trauma enemy alive"):
		return

	var orbit_enemy = world.spawn_trauma_enemy_at_world_position(player.global_position + Vector3(10.0, 0.0, 0.0))
	if not T.require_true(self, orbit_enemy != null, "Directed spawn must create a second trauma enemy for orbit verification"):
		return
	var initial_orbit_vector: Vector3 = orbit_enemy.global_position - player.global_position
	var orbit_mode_seen := false
	for _frame in range(72):
		await physics_frame
		if not is_instance_valid(orbit_enemy):
			break
		if str(orbit_enemy.get_behavior_mode()) == "orbit":
			orbit_mode_seen = true
	if not T.require_true(self, orbit_mode_seen, "Trauma enemy must switch into an orbit/pressure mode near the player instead of ramming straight in"):
		return
	var final_orbit_vector: Vector3 = orbit_enemy.global_position - player.global_position
	var initial_orbit_dir := Vector2(initial_orbit_vector.x, initial_orbit_vector.z).normalized()
	var final_orbit_dir := Vector2(final_orbit_vector.x, final_orbit_vector.z).normalized()
	var orbit_angle := acos(clampf(initial_orbit_dir.dot(final_orbit_dir), -1.0, 1.0))
	if not T.require_true(self, orbit_angle >= 0.25, "Near-player trauma enemy must laterally reposition around the player instead of only pushing inward"):
		return
	if not T.require_true(self, Vector2(final_orbit_vector.x, final_orbit_vector.z).length() >= 6.0, "Orbiting trauma enemy must keep personal-space distance instead of body-slamming the player"):
		return

	world.queue_free()
	T.pass_and_quit(self)
