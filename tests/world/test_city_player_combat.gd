extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player combat contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for combat"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "PlayerController must expose request_primary_fire() for combat input"):
		return
	if not T.require_true(self, player.has_method("set_primary_fire_active"), "PlayerController must expose set_primary_fire_active() for automatic weapon fire"):
		return
	if not T.require_true(self, world.has_method("fire_player_projectile"), "CityPrototype must expose fire_player_projectile() for combat spawning"):
		return
	if not T.require_true(self, world.has_method("get_active_projectile_count"), "CityPrototype must expose get_active_projectile_count() for combat verification"):
		return

	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, camera != null, "Player combat contract requires CameraRig/Camera3D for third-person firing"):
		return

	var projectile_count_before := int(world.get_active_projectile_count())
	var projectile = world.fire_player_projectile()
	if not T.require_true(self, projectile != null, "Player fire request must spawn a projectile node"):
		return
	if not T.require_true(self, int(world.get_active_projectile_count()) == projectile_count_before + 1, "Player fire must increase active projectile count by one"):
		return

	var spawn_offset_local: Vector3 = player.to_local(projectile.global_position)
	if not T.require_true(self, absf(spawn_offset_local.x) >= 0.2, "Third-person projectile spawn must be visibly offset from the player centerline instead of leaving from screen center"):
		return
	if not T.require_true(self, projectile.global_position.distance_to(camera.global_position) >= 3.0, "Third-person projectile must originate near the player shoulder, not near the camera center ray"):
		return

	var initial_position: Vector3 = projectile.global_position
	for _frame in range(4):
		await physics_frame

	if not T.require_true(self, is_instance_valid(projectile), "Fresh player projectile must stay alive for at least a few physics frames"):
		return
	if not T.require_true(self, projectile.global_position.distance_to(initial_position) >= 1.0, "Player projectile must travel forward after firing"):
		return

	var projectile_count_before_auto := int(world.get_active_projectile_count())
	player.set_primary_fire_active(true)
	for _frame in range(24):
		await process_frame
	player.set_primary_fire_active(false)
	if not T.require_true(self, int(world.get_active_projectile_count()) >= projectile_count_before_auto + 2, "Holding primary fire must produce automatic rifle bursts instead of single-shot only"):
		return

	world.queue_free()
	T.pass_and_quit(self)
