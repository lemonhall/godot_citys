extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for trauma camouflage contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("spawn_trauma_enemy"), "CityPrototype must expose spawn_trauma_enemy() for trauma camouflage tests"):
		return
	if not T.require_true(self, world.has_method("fire_player_projectile_toward"), "CityPrototype must expose fire_player_projectile_toward() for trauma camouflage tests"):
		return

	var enemy = world.spawn_trauma_enemy()
	if not T.require_true(self, enemy != null, "Trauma camouflage test must spawn an enemy"):
		return
	if not T.require_true(self, enemy.has_method("get_camouflage_state"), "Trauma enemy must expose get_camouflage_state() for optical camouflage verification"):
		return

	var projectile = world.fire_player_projectile_toward(enemy.global_position)
	if not T.require_true(self, projectile != null, "Trauma camouflage test requires a player projectile to provoke dodge behavior"):
		return

	var camouflage_seen := false
	var minimum_alpha := 1.0
	for _frame in range(48):
		await physics_frame
		if not is_instance_valid(enemy):
			break
		var camouflage_state: Dictionary = enemy.get_camouflage_state()
		if bool(camouflage_state.get("active", false)):
			camouflage_seen = true
			minimum_alpha = minf(minimum_alpha, float(camouflage_state.get("alpha", 1.0)))
			if minimum_alpha <= 0.4:
				break

	if not T.require_true(self, camouflage_seen, "Trauma enemy dodge must trigger a short optical camouflage state instead of only teleporting"):
		return
	if not T.require_true(self, minimum_alpha <= 0.4, "Trauma enemy camouflage must visibly lower body opacity during the dodge window"):
		return

	world.queue_free()
	T.pass_and_quit(self)
