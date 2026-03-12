extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for trauma enemy suppressive fire contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "Combat suppressive fire test requires Player node"):
		return
	if not T.require_true(self, world.has_method("spawn_trauma_enemy_at_world_position"), "CityPrototype must expose spawn_trauma_enemy_at_world_position() for suppressive fire tests"):
		return
	if not T.require_true(self, world.has_method("get_active_enemy_projectile_count"), "CityPrototype must expose get_active_enemy_projectile_count() for suppressive fire verification"):
		return

	var enemy = world.spawn_trauma_enemy_at_world_position(player.global_position + Vector3(0.0, 0.0, -22.0))
	if not T.require_true(self, enemy != null, "Suppressive fire test must spawn a trauma enemy"):
		return
	if not T.require_true(self, enemy.has_method("get_role_id"), "Trauma enemy must expose get_role_id() for MaxTac role verification"):
		return
	if not T.require_true(self, str(enemy.get_role_id()) == "assault", "Current trauma enemy prototype must represent a MaxTac assault operator"):
		return

	var projectile_count_before := int(world.get_active_enemy_projectile_count())
	var suppressive_fire_seen := false
	for _frame in range(120):
		await physics_frame
		if int(world.get_active_enemy_projectile_count()) > projectile_count_before:
			suppressive_fire_seen = true
			break

	if not T.require_true(self, suppressive_fire_seen, "MaxTac assault operator must open suppressive fire at medium range instead of only moving and dodging"):
		return

	world.queue_free()
	T.pass_and_quit(self)
