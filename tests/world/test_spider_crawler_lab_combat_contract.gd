extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider crawler lab combat contract requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"get_active_spider_count",
		"get_defeated_spider_count",
		"get_nearest_live_spider_to_player",
		"fire_player_projectile_toward",
		"throw_grenade_toward",
		"fire_laser_at_world_position",
		"fire_missile_at_world_position",
		"get_active_projectile_count",
		"get_active_grenade_count",
		"get_active_laser_beam_count",
		"get_active_missile_count",
		"aim_player_at_world_position",
		"reset_lab_state",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Spider crawler lab combat contract requires %s()" % required_method):
			return

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Spider crawler lab combat contract requires the formal Player node"):
		return
	for player_method in [
		"set_weapon_mode",
		"get_weapon_mode",
		"request_primary_fire",
		"set_grenade_ready_active",
		"request_grenade_throw",
		"request_laser_designator_fire",
		"request_missile_launcher_fire",
	]:
		if not T.require_true(self, player.has_method(player_method), "Spider crawler lab combat contract requires Player.%s()" % player_method):
			return

	for combat_root_path in [
		"CombatRoot",
		"CombatRoot/Projectiles",
		"CombatRoot/Grenades",
		"CombatRoot/LaserBeams",
		"CombatRoot/Missiles",
	]:
		if not T.require_true(self, lab.get_node_or_null(combat_root_path) != null, "Spider crawler lab combat contract requires %s" % combat_root_path):
			return

	if not T.require_true(self, int(lab.get_active_spider_count()) >= 12, "Spider crawler lab combat contract requires a double-digit live spider swarm"):
		return
	if not T.require_true(self, int(lab.get_defeated_spider_count()) == 0, "Spider crawler lab combat contract requires the fresh lab to boot with zero defeated spiders"):
		return

	var rifle_target := _require_live_target(lab, "rifle")
	if rifle_target == null:
		return
	var rifle_health_before := _health_current(rifle_target)
	player.set_weapon_mode("rifle")
	lab.aim_player_at_world_position(_combat_target_position(rifle_target))
	await physics_frame
	var projectile_count_before := int(lab.get_active_projectile_count())
	var rifle_started: bool = player.request_primary_fire()
	if not T.require_true(self, rifle_started, "Spider crawler lab combat contract requires the rifle fire request to succeed"):
		return
	if not T.require_true(self, int(lab.get_active_projectile_count()) == projectile_count_before + 1, "Spider crawler lab combat contract requires rifle fire to mount a live projectile"):
		return
	if not await _await_health_drop(rifle_target, rifle_health_before, 24):
		T.fail_and_quit(self, "Spider crawler lab combat contract requires rifle fire to reduce spider health")
		return

	lab.reset_lab_state()
	await process_frame
	await process_frame

	var grenade_target := _require_live_target(lab, "grenade")
	if grenade_target == null:
		return
	var grenade_health_before := _health_current(grenade_target)
	player.set_weapon_mode("grenade")
	lab.aim_player_at_world_position(_combat_target_position(grenade_target))
	await physics_frame
	player.set_grenade_ready_active(true)
	var grenade_count_before := int(lab.get_active_grenade_count())
	var grenade_started: bool = player.request_grenade_throw()
	if not T.require_true(self, grenade_started, "Spider crawler lab combat contract requires the grenade throw request to succeed"):
		return
	if not T.require_true(self, int(lab.get_active_grenade_count()) == grenade_count_before + 1, "Spider crawler lab combat contract requires grenade throws to mount a live grenade"):
		return
	if not await _await_health_drop(grenade_target, grenade_health_before, 180):
		T.fail_and_quit(self, "Spider crawler lab combat contract requires grenade damage to reduce spider health")
		return

	lab.reset_lab_state()
	await process_frame
	await process_frame

	var laser_target := _require_live_target(lab, "laser")
	if laser_target == null:
		return
	var laser_health_before := _health_current(laser_target)
	player.set_weapon_mode("laser_designator")
	lab.aim_player_at_world_position(_combat_target_position(laser_target))
	await physics_frame
	var beam_count_before := int(lab.get_active_laser_beam_count())
	var laser_started: bool = player.request_laser_designator_fire()
	if not T.require_true(self, laser_started, "Spider crawler lab combat contract requires the laser designator fire request to succeed"):
		return
	if not T.require_true(self, int(lab.get_active_laser_beam_count()) == beam_count_before + 1, "Spider crawler lab combat contract requires laser fire to mount a live beam pulse"):
		return
	if not await _await_health_drop(laser_target, laser_health_before, 10):
		T.fail_and_quit(self, "Spider crawler lab combat contract requires laser hits to reduce spider health")
		return

	lab.reset_lab_state()
	await process_frame
	await process_frame

	var missile_target := _require_live_target(lab, "missile")
	if missile_target == null:
		return
	var missile_health_before := _health_current(missile_target)
	player.set_weapon_mode("missile_launcher")
	lab.aim_player_at_world_position(_combat_target_position(missile_target))
	await physics_frame
	var missile_count_before := int(lab.get_active_missile_count())
	var missile_started: bool = player.request_missile_launcher_fire()
	if not T.require_true(self, missile_started, "Spider crawler lab combat contract requires the missile launcher fire request to succeed"):
		return
	if not T.require_true(self, int(lab.get_active_missile_count()) == missile_count_before + 1, "Spider crawler lab combat contract requires missile fire to mount a live missile"):
		return
	if not await _await_health_drop(missile_target, missile_health_before, 150):
		T.fail_and_quit(self, "Spider crawler lab combat contract requires missile damage to reduce spider health")
		return

	lab.reset_lab_state()
	await process_frame
	await process_frame
	lab.queue_free()
	await process_frame
	await process_frame
	T.pass_and_quit(self)

func _require_live_target(lab: Node3D, label: String) -> Node3D:
	var target := lab.get_nearest_live_spider_to_player() as Node3D
	if not T.require_true(self, target != null, "Spider crawler lab combat contract requires a live %s target" % label):
		return null
	if not T.require_true(self, target.has_method("get_health_state"), "Spider crawler lab combat contract requires spider targets to expose get_health_state()"):
		return null
	var health_state: Dictionary = target.get_health_state()
	if not T.require_true(self, bool(health_state.get("alive", false)), "Spider crawler lab combat contract requires %s targets to boot alive" % label):
		return null
	if not T.require_true(self, float(health_state.get("max", 0.0)) >= 10.0, "Spider crawler lab combat contract requires spiders to be tougher than a single burst"):
		return null
	return target

func _health_current(target: Node3D) -> float:
	return float((target.get_health_state() as Dictionary).get("current", 0.0))

func _combat_target_position(target: Node3D) -> Vector3:
	if target.has_method("get_combat_target_world_position"):
		return target.get_combat_target_world_position()
	return target.global_position + Vector3.UP * 0.8

func _await_health_drop(target: Node3D, baseline_health: float, frame_budget: int) -> bool:
	for _frame in range(frame_budget):
		await physics_frame
		await process_frame
		if target == null or not is_instance_valid(target):
			return true
		if _health_current(target) < baseline_health:
			return true
	return false
