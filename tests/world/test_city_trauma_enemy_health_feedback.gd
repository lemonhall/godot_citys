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
	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, camera != null, "Trauma health feedback contract requires CameraRig/Camera3D so health bars stay readable from third-person camera angles"):
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
	if not T.require_true(self, enemy.has_method("is_combat_active"), "Trauma enemy must expose is_combat_active() so HUD and combat systems can ignore corpses"):
		return
	if not T.require_true(self, enemy.has_method("set_corpse_cleanup_delay_sec"), "Trauma enemy must expose set_corpse_cleanup_delay_sec() so tests can shorten the corpse cleanup delay"):
		return
	enemy.set_corpse_cleanup_delay_sec(0.2)

	var initial_state: Dictionary = enemy.get_health_state()
	if not T.require_true(self, bool(initial_state.get("alive", false)), "New trauma enemy must report itself as alive"):
		return
	if not T.require_true(self, is_equal_approx(float(initial_state.get("ratio", 0.0)), 1.0), "New trauma enemy must begin at full health"):
		return

	var health_bar: Node = enemy.get_node_or_null("HealthBar")
	if not T.require_true(self, health_bar != null, "Trauma enemy must keep a visible HealthBar node so kills are readable in gameplay"):
		return
	var health_bar_root := health_bar as Node3D
	if not T.require_true(self, health_bar_root != null, "Trauma enemy health bar contract requires HealthBar to remain a Node3D"):
		return
	var back := health_bar.get_node_or_null("Back") as MeshInstance3D
	if not T.require_true(self, back != null, "Trauma enemy health bar must keep a dark Back mesh for contrast"):
		return
	var back_material := back.material_override as StandardMaterial3D
	if not T.require_true(self, back_material != null, "Trauma enemy health bar background must keep its own StandardMaterial3D for combat readability"):
		return
	var fill_anchor := health_bar.get_node_or_null("FillAnchor") as Node3D
	if not T.require_true(self, fill_anchor != null, "Trauma enemy health bar must keep a FillAnchor node so damage can visibly shrink the fill"):
		return
	var fill := health_bar.get_node_or_null("FillAnchor/Fill") as MeshInstance3D
	if not T.require_true(self, fill != null, "Trauma enemy health bar must keep a visible Fill mesh instead of only a dark background"):
		return
	var fill_material := fill.material_override as StandardMaterial3D
	if not T.require_true(self, fill_material != null, "Trauma enemy health bar fill must keep its own StandardMaterial3D so health can stay readable"):
		return
	if not T.require_true(self, back.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and fill.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Trauma enemy health bar meshes must not cast world shadows that read as stray black slashes on the ground"):
		return
	if not T.require_true(self, fill_material.albedo_color.r > 0.5, "Trauma enemy health bar fill must start bright enough to read as full health instead of an all-black bar"):
		return
	if not T.require_true(self, fill.position.z < back.position.z - 0.005, "Trauma enemy health bar fill must sit in front of the dark background so full health does not read as black"):
		return
	if not T.require_true(self, is_equal_approx(fill_anchor.scale.x, 1.0), "Full-health trauma enemies must start with an unshrunk health bar fill"):
		return
	for _frame in range(4):
		await physics_frame
	if not T.require_true(self, health_bar_root.top_level, "Trauma enemy health bar root must decouple from enemy body rotation so the third-person camera can read it from side angles"):
		return
	var initial_alignment := _planar_facing_alignment(health_bar_root, camera)
	if not T.require_true(self, initial_alignment >= 0.92, "Trauma enemy health bar must face the active gameplay camera instead of only inheriting the enemy body yaw (alignment=%0.3f)" % initial_alignment):
		return
	player.rotate_y(deg_to_rad(90.0))
	for _frame in range(4):
		await physics_frame
	var rotated_alignment := _planar_facing_alignment(health_bar_root, camera)
	if not T.require_true(self, rotated_alignment >= 0.92, "Rotating the third-person camera around the player must keep the trauma enemy health bar facing the camera instead of turning edge-on (alignment=%0.3f)" % rotated_alignment):
		return

	enemy.apply_projectile_hit(1.0, enemy.global_position, Vector3.ZERO)
	await process_frame

	var damaged_state: Dictionary = enemy.get_health_state()
	if not T.require_true(self, float(damaged_state.get("current", 0.0)) < float(initial_state.get("current", 0.0)), "Projectile hits must reduce the trauma enemy health state"):
		return
	if not T.require_true(self, float(damaged_state.get("ratio", 1.0)) < 1.0, "Projectile hits must reduce the trauma enemy health ratio"):
		return
	if not T.require_true(self, is_equal_approx(fill_anchor.scale.x, 2.0 / 3.0), "A 3-health trauma enemy must visibly lose about one third of the bar after a 1-damage projectile hit"):
		return
	if not T.require_true(self, bool(damaged_state.get("visible", false)), "Trauma enemy health feedback must stay visible after taking damage"):
		return

	enemy.apply_projectile_hit(8.0, enemy.global_position, Vector3.ZERO)
	await physics_frame

	if not T.require_true(self, is_instance_valid(enemy), "Trauma enemy must remain in the scene briefly as a corpse instead of disappearing the instant health reaches zero"):
		return
	if not T.require_true(self, not enemy.is_combat_active(), "Defeated trauma enemy corpse must stop counting as an active combatant"):
		return
	var defeated_state: Dictionary = enemy.get_health_state()
	if not T.require_true(self, not bool(defeated_state.get("alive", true)), "Trauma enemy must report itself as dead once health reaches zero"):
		return
	if not T.require_true(self, not bool(defeated_state.get("visible", true)), "Trauma enemy health bar must hide once the enemy becomes a corpse"):
		return
	var body := enemy.get_node_or_null("Body") as Node3D
	if not T.require_true(self, body != null, "Trauma enemy corpse verification requires the Body visual node"):
		return
	if not T.require_true(self, absf(body.rotation.z) >= 1.4, "Defeated trauma enemies must visually fall over instead of remaining upright"):
		return
	if not T.require_true(self, body.position.y <= 0.8, "Defeated trauma enemy body must settle near the ground instead of hovering at standing height"):
		return
	if not T.require_true(self, int(world.get_active_enemy_count()) == 0, "Defeated trauma enemies must be removed from the active enemy count"):
		return
	await create_timer(0.25).timeout
	await process_frame
	if not T.require_true(self, not is_instance_valid(enemy), "Trauma enemy corpse must be cleaned up after the corpse delay expires"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _planar_facing_alignment(node: Node3D, camera: Camera3D) -> float:
	var to_camera := camera.global_position - node.global_position
	to_camera.y = 0.0
	if to_camera.length_squared() <= 0.0001:
		return 1.0
	var facing := -node.global_transform.basis.z
	facing.y = 0.0
	if facing.length_squared() <= 0.0001:
		return -1.0
	return facing.normalized().dot(to_camera.normalized())
