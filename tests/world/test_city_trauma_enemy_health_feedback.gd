extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for trauma health feedback contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "Trauma health feedback contract requires Player node"):
		return
	if not T.require_true(self, world.has_method("spawn_trauma_enemy_at_world_position"), "CityPrototype must expose spawn_trauma_enemy_at_world_position() for trauma health feedback tests"):
		return
	if not T.require_true(self, world.has_method("get_active_enemy_count"), "CityPrototype must expose get_active_enemy_count() for trauma health feedback tests"):
		return

	var enemy = world.spawn_trauma_enemy_at_world_position(player.global_position + Vector3(0.0, 0.0, -18.0))
	if not T.require_true(self, enemy != null, "Trauma health feedback test must spawn an enemy"):
		return
	if not T.require_true(self, enemy.has_method("get_health_ratio"), "Trauma enemy must expose get_health_ratio() for combat readability"):
		return
	if not T.require_true(self, enemy.has_method("get_health_state"), "Trauma enemy must expose get_health_state() for combat readability"):
		return

	var initial_state: Dictionary = enemy.get_health_state()
	if not T.require_true(self, bool(initial_state.get("alive", false)), "New trauma enemy must report itself as alive"):
		return
	if not T.require_true(self, is_equal_approx(float(initial_state.get("ratio", 0.0)), 1.0), "New trauma enemy must begin at full health"):
		return

	var health_bar: Node = enemy.get_node_or_null("HealthBar")
	if not T.require_true(self, health_bar != null, "Trauma enemy must keep a visible HealthBar node so kills are readable in gameplay"):
		return

	enemy.apply_projectile_hit(1.0, enemy.global_position, Vector3.ZERO)
	await process_frame

	var damaged_state: Dictionary = enemy.get_health_state()
	if not T.require_true(self, float(damaged_state.get("current", 0.0)) < float(initial_state.get("current", 0.0)), "Projectile hits must reduce the trauma enemy health state"):
		return
	if not T.require_true(self, float(damaged_state.get("ratio", 1.0)) < 1.0, "Projectile hits must reduce the trauma enemy health ratio"):
		return
	if not T.require_true(self, bool(damaged_state.get("visible", false)), "Trauma enemy health feedback must stay visible after taking damage"):
		return

	enemy.apply_projectile_hit(8.0, enemy.global_position, Vector3.ZERO)
	await physics_frame

	if not T.require_true(self, not is_instance_valid(enemy), "Trauma enemy must only disappear after its health reaches zero"):
		return
	if not T.require_true(self, int(world.get_active_enemy_count()) == 0, "Defeated trauma enemies must be removed from the active enemy count"):
		return

	world.queue_free()
	T.pass_and_quit(self)
