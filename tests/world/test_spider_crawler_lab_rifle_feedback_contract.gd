extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider crawler lab rifle feedback contract requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Spider crawler lab rifle feedback contract requires the formal Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "Spider crawler lab rifle feedback contract requires Player.set_weapon_mode()"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "Spider crawler lab rifle feedback contract requires Player.request_primary_fire()"):
		return
	if not T.require_true(self, player.has_method("get_rifle_visual_state"), "Spider crawler lab rifle feedback contract requires Player.get_rifle_visual_state()"):
		return
	if not T.require_true(self, lab.has_method("get_active_projectile_count"), "Spider crawler lab rifle feedback contract requires get_active_projectile_count()"):
		return
	if not T.require_true(self, lab.has_method("get_active_projectile_tracer_count"), "Spider crawler lab rifle feedback contract requires get_active_projectile_tracer_count()"):
		return
	if not T.require_true(self, lab.has_method("get_nearest_live_spider_to_player"), "Spider crawler lab rifle feedback contract requires get_nearest_live_spider_to_player()"):
		return
	if not T.require_true(self, lab.has_method("aim_player_at_world_position"), "Spider crawler lab rifle feedback contract requires aim_player_at_world_position()"):
		return

	var target := lab.get_nearest_live_spider_to_player() as Node3D
	if not T.require_true(self, target != null, "Spider crawler lab rifle feedback contract requires a live spider target"):
		return
	if not T.require_true(self, target.has_method("get_health_state"), "Spider crawler lab rifle feedback contract requires spiders to expose get_health_state()"):
		return
	var health_before := float((target.get_health_state() as Dictionary).get("current", 0.0))

	player.set_weapon_mode("rifle")
	lab.aim_player_at_world_position(_combat_target_position(target))
	await physics_frame

	var visual_state_before: Dictionary = player.get_rifle_visual_state()
	var projectile_count_before := int(lab.get_active_projectile_count())
	var tracer_count_before := int(lab.get_active_projectile_tracer_count())
	var fire_started: bool = player.request_primary_fire()

	if not T.require_true(self, fire_started, "Spider crawler lab rifle feedback contract requires rifle fire to start successfully"):
		return
	var visual_state: Dictionary = player.get_rifle_visual_state()
	if not T.require_true(self, bool(visual_state.get("fire_fx_active", false)), "Spider crawler lab rifle fire must trigger the same muzzle flash FX as the main world"):
		return
	if not T.require_true(self, int(visual_state.get("fire_count", 0)) == int(visual_state_before.get("fire_count", 0)) + 1, "Spider crawler lab rifle fire must increment the formal rifle fire_count"):
		return
	if not T.require_true(self, int(lab.get_active_projectile_count()) == projectile_count_before + 1, "Spider crawler lab rifle fire must still mount a live projectile"):
		return
	if not T.require_true(self, int(lab.get_active_projectile_tracer_count()) >= tracer_count_before + 1, "Spider crawler lab rifle fire must also spawn the smoke tracer visual"):
		return

	var projectile_root := lab.get_node_or_null("CombatRoot/Projectiles") as Node3D
	if not T.require_true(self, projectile_root != null and projectile_root.get_child_count() > 0, "Spider crawler lab rifle feedback contract requires CombatRoot/Projectiles to hold the live shot"):
		return
	var projectile := projectile_root.get_child(projectile_root.get_child_count() - 1) as Node3D
	if not T.require_true(self, projectile != null and projectile.has_method("get_visual_state"), "Spider crawler lab rifle feedback contract requires projectile visual introspection"):
		return
	var projectile_visual_state: Dictionary = projectile.get_visual_state()
	if not T.require_true(self, str(projectile_visual_state.get("visual_profile", "")) == "rifle_smoke_trace", "Spider crawler lab must reuse the same rifle smoke-trace projectile profile"):
		return
	if not T.require_true(self, not bool(projectile_visual_state.get("body_visible", true)), "Spider crawler lab rifle projectiles must not resurrect the legacy visible blue orb body"):
		return
	if not T.require_true(self, float(projectile.get("speed_mps")) >= 700.0, "Spider crawler lab rifle projectiles must keep the faster ballistic speed contract"):
		return
	if not T.require_true(self, float(projectile.get("max_distance_m")) >= 800.0, "Spider crawler lab rifle projectiles must keep the long-range reach contract"):
		return
	var tracer_root := lab.get_node_or_null("CombatRoot/ProjectileTracers") as Node3D
	if not T.require_true(self, tracer_root != null and tracer_root.get_child_count() > 0, "Spider crawler lab rifle feedback contract requires the smoke tracer visual to be mounted under CombatRoot/ProjectileTracers"):
		return
	var tracer := tracer_root.get_child(tracer_root.get_child_count() - 1) as Node3D
	if not T.require_true(self, tracer != null and tracer.has_method("get_debug_state"), "Spider crawler lab smoke tracer visual must expose get_debug_state() for extended-length regression coverage"):
		return
	var tracer_state: Dictionary = tracer.get_debug_state()
	if not T.require_true(self, float(tracer_state.get("segment_length_m", 0.0)) >= 9.0, "Spider crawler lab must reuse the longer rifle smoke trail instead of falling back to the shorter pre-tuning trace"):
		return
	await process_frame
	await physics_frame

	var health_dropped := await _await_health_drop(target, health_before, 32)
	if not T.require_true(self, health_dropped, "Spider crawler lab rifle fire must still damage spiders after the visual/ballistic upgrade"):
		return

	var tracer_cleared := false
	for _frame in range(18):
		await process_frame
		if int(lab.get_active_projectile_tracer_count()) <= tracer_count_before:
			tracer_cleared = true
			break
	if not T.require_true(self, tracer_cleared, "Spider crawler lab smoke tracer visuals must remain transient instead of lingering forever"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

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
		var health_state: Dictionary = target.get_health_state()
		if float(health_state.get("current", baseline_health)) < baseline_health:
			return true
	return false
