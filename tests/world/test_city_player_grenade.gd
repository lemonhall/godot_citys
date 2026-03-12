extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for grenade combat contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Grenade combat contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for weapon switching"):
		return
	if not T.require_true(self, player.has_method("get_weapon_mode"), "PlayerController must expose get_weapon_mode() for weapon verification"):
		return
	if not T.require_true(self, player.has_method("set_grenade_ready_active"), "PlayerController must expose set_grenade_ready_active() for held-grenade input"):
		return
	if not T.require_true(self, player.has_method("is_grenade_ready_active"), "PlayerController must expose is_grenade_ready_active() for held-grenade state checks"):
		return
	if not T.require_true(self, player.has_method("request_grenade_throw"), "PlayerController must expose request_grenade_throw() for left-click grenade throws"):
		return
	if not T.require_true(self, world.has_method("get_active_grenade_count"), "CityPrototype must expose get_active_grenade_count() for grenade verification"):
		return

	player.set_aim_down_sights_active(true)
	for _frame in range(12):
		await process_frame

	player.set_weapon_mode("grenade")
	await process_frame

	if not T.require_true(self, player.get_weapon_mode() == "grenade", "Pressing 2 must switch the player into grenade mode"):
		return
	if not T.require_true(self, not player.is_aim_down_sights_active(), "Switching to grenade mode must drop ADS instead of keeping the rifle aim state active"):
		return

	var projectile_count_before := int(world.get_active_projectile_count())
	var primary_fire_started: bool = player.request_primary_fire()
	await process_frame
	if not T.require_true(self, not primary_fire_started, "Primary rifle fire must be disabled while grenade mode is selected"):
		return
	if not T.require_true(self, int(world.get_active_projectile_count()) == projectile_count_before, "Grenade mode must not keep spawning rifle bullets"):
		return

	player.set_grenade_ready_active(true)
	if not T.require_true(self, player.is_grenade_ready_active(), "Right-click in grenade mode must hold a grenade in the ready state"):
		return

	var grenade_count_before := int(world.get_active_grenade_count())
	var throw_started: bool = player.request_grenade_throw()
	await process_frame
	if not T.require_true(self, throw_started, "Left-click while grenade-ready must throw a grenade"):
		return
	if not T.require_true(self, int(world.get_active_grenade_count()) == grenade_count_before + 1, "Throwing a grenade must increase the active grenade count by one"):
		return
	if not T.require_true(self, not player.is_grenade_ready_active(), "Throwing must consume the held grenade and exit the ready state"):
		return

	var grenade_root := world.get_node_or_null("CombatRoot/Grenades") as Node3D
	if not T.require_true(self, grenade_root != null and grenade_root.get_child_count() > 0, "Grenade throws must mount under CombatRoot/Grenades"):
		return
	var grenade := grenade_root.get_child(grenade_root.get_child_count() - 1) as Node3D
	if not T.require_true(self, grenade != null, "Grenade mode must spawn a live grenade node"):
		return
	if not T.require_true(self, grenade.has_method("get_velocity"), "Grenade node must expose get_velocity() for trajectory verification"):
		return
	if not T.require_true(self, grenade.has_method("has_exploded"), "Grenade node must expose has_exploded() for explosion verification"):
		return

	var initial_velocity: Vector3 = grenade.get_velocity()
	if not T.require_true(self, initial_velocity.y >= 2.0, "Thrown grenade must leave the hand with an upward component instead of flying as a flat hitscan round"):
		return

	var start_position: Vector3 = grenade.global_position
	for _frame in range(6):
		await physics_frame

	if not T.require_true(self, is_instance_valid(grenade), "Fresh grenade must stay alive for at least a few physics frames of flight"):
		return
	if not T.require_true(self, grenade.global_position.distance_to(start_position) >= 0.75, "Grenade must move through the world after being thrown"):
		return

	var exploded := false
	for _frame in range(180):
		await physics_frame
		if not is_instance_valid(grenade):
			break
		if grenade.has_exploded():
			exploded = true
			break

	if not T.require_true(self, exploded, "Thrown grenade must eventually explode instead of living forever"):
		return

	var fx_state: Dictionary = player.get_traversal_fx_state()
	if not T.require_true(self, float(fx_state.get("camera_shake_remaining_sec", 0.0)) > 0.0, "Grenade explosion must kick player camera shake for impact feedback"):
		return

	world.queue_free()
	T.pass_and_quit(self)
