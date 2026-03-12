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
	if not T.require_true(self, player.has_method("get_grenade_preview_state"), "PlayerController must expose get_grenade_preview_state() for grenade landing previews"):
		return
	if not T.require_true(self, world.has_method("get_active_grenade_count"), "CityPrototype must expose get_active_grenade_count() for grenade verification"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "Grenade combat contract requires Hud node"):
		return
	if not T.require_true(self, hud.has_method("get_crosshair_state"), "PrototypeHud must expose get_crosshair_state() for grenade HUD verification"):
		return

	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if not T.require_true(self, camera_rig != null, "Grenade combat contract requires CameraRig for trajectory preview verification"):
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
	var crosshair_state: Dictionary = hud.get_crosshair_state()
	if not T.require_true(self, not bool(crosshair_state.get("visible", true)), "Grenade mode must hide the rifle crosshair instead of keeping the ADS reticle on screen"):
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
	var preview_state: Dictionary = player.get_grenade_preview_state()
	if not T.require_true(self, bool(preview_state.get("visible", false)), "Holding a grenade must show a trajectory/landing preview ghost"):
		return
	if not T.require_true(self, int(preview_state.get("sample_count", 0)) >= 4, "Grenade preview must expose multiple trajectory samples instead of a single fixed landing point"):
		return

	var initial_landing_point: Vector3 = preview_state.get("landing_point", Vector3.ZERO)
	camera_rig.rotation.x = deg_to_rad(14.0)
	await process_frame
	var raised_preview_state: Dictionary = player.get_grenade_preview_state()
	var raised_landing_point: Vector3 = raised_preview_state.get("landing_point", Vector3.ZERO)
	if not T.require_true(self, raised_landing_point.distance_to(initial_landing_point) >= 2.0, "Raising the camera must shift the predicted grenade landing point instead of keeping a fixed throw distance"):
		return

	player.rotate_y(deg_to_rad(30.0))
	await process_frame
	var rotated_preview_state: Dictionary = player.get_grenade_preview_state()
	var rotated_landing_point: Vector3 = rotated_preview_state.get("landing_point", Vector3.ZERO)
	if not T.require_true(self, rotated_landing_point.distance_to(raised_landing_point) >= 2.5, "Turning the player left/right must rotate the grenade landing ghost with the current aim direction"):
		return

	var grenade_count_before := int(world.get_active_grenade_count())
	var throw_started: bool = player.request_grenade_throw()
	await process_frame
	if not T.require_true(self, throw_started, "Left-click while grenade-ready must throw a grenade"):
		return
	if not T.require_true(self, int(world.get_active_grenade_count()) == grenade_count_before + 1, "Throwing a grenade must increase the active grenade count by one"):
		return
	if not T.require_true(self, player.is_grenade_ready_active(), "Holding right-click must automatically ready the next grenade after each throw instead of forcing another right-click"):
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
	if not T.require_true(self, initial_velocity.length() >= 30.0, "Thrown grenade must move much faster than the initial slow arc so the throw feels usable in combat"):
		return

	var grenade_count_before_second_throw := int(world.get_active_grenade_count())
	var second_throw_started: bool = player.request_grenade_throw()
	await process_frame
	if not T.require_true(self, second_throw_started, "Keeping right-click held must let the player chain another grenade throw without re-priming manually"):
		return
	if not T.require_true(self, int(world.get_active_grenade_count()) == grenade_count_before_second_throw + 1, "Auto-readied grenade state must spawn a second grenade on the next left-click"):
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
	if not T.require_true(self, float(fx_state.get("camera_shake_amplitude_m", 0.0)) >= 0.28, "Grenade explosion feedback must shake harder than the current weak placeholder effect"):
		return

	world.queue_free()
	T.pass_and_quit(self)
