extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for rifle vfx/ballistics contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Rifle vfx/ballistics contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for rifle mode verification"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "PlayerController must expose request_primary_fire() for rifle fire verification"):
		return
	if not T.require_true(self, player.has_method("get_rifle_visual_state"), "PlayerController must expose get_rifle_visual_state() for rifle fire FX verification"):
		return
	if not T.require_true(self, player.has_method("get_aim_trace_segment"), "PlayerController must expose get_aim_trace_segment() for rifle range verification"):
		return
	if not T.require_true(self, world.has_method("get_active_projectile_count"), "CityPrototype must expose get_active_projectile_count() for rifle verification"):
		return
	if not T.require_true(self, world.has_method("get_active_projectile_tracer_count"), "CityPrototype must expose get_active_projectile_tracer_count() for rifle tracer verification"):
		return

	player.set_weapon_mode("rifle")
	await process_frame

	var visual_state_before: Dictionary = player.get_rifle_visual_state()
	var projectile_count_before := int(world.get_active_projectile_count())
	var tracer_count_before := int(world.get_active_projectile_tracer_count())
	var fire_started: bool = player.request_primary_fire()

	if not T.require_true(self, fire_started, "Rifle mode must accept primary fire requests"):
		return
	var visual_state: Dictionary = player.get_rifle_visual_state()
	if not T.require_true(self, bool(visual_state.get("fire_fx_active", false)), "Rifle fire must trigger a formal muzzle flash FX window"):
		return
	if not T.require_true(self, int(visual_state.get("fire_count", 0)) == int(visual_state_before.get("fire_count", 0)) + 1, "Rifle fire FX must increment fire_count exactly once per accepted shot"):
		return
	if not T.require_true(self, int(world.get_active_projectile_count()) == projectile_count_before + 1, "Rifle fire must still mount a live projectile node under the formal combat chain"):
		return
	if not T.require_true(self, int(world.get_active_projectile_tracer_count()) >= tracer_count_before + 1, "Rifle fire must spawn at least one short-lived smoke tracer visual"):
		return

	var projectile_root := world.get_node_or_null("CombatRoot/Projectiles") as Node3D
	if not T.require_true(self, projectile_root != null and projectile_root.get_child_count() > 0, "Rifle vfx/ballistics contract requires CombatRoot/Projectiles to hold the live projectile"):
		return
	var projectile := projectile_root.get_child(projectile_root.get_child_count() - 1) as Node3D
	if not T.require_true(self, projectile != null, "Rifle fire must spawn a projectile node instance"):
		return
	if not T.require_true(self, projectile.has_method("get_visual_state"), "CityProjectile must expose get_visual_state() for rifle visual regression coverage"):
		return

	var projectile_visual_state: Dictionary = projectile.get_visual_state()
	if not T.require_true(self, str(projectile_visual_state.get("visual_profile", "")) == "rifle_smoke_trace", "Player rifle projectiles must switch from the legacy blue orb to the formal rifle smoke-trace profile"):
		return
	if not T.require_true(self, not bool(projectile_visual_state.get("body_visible", true)), "Player rifle bullets must no longer render a visible candy-like projectile body"):
		return
	if not T.require_true(self, float(projectile.get("speed_mps")) >= 700.0, "Player rifle projectiles must travel at a much faster muzzle velocity than the legacy slow projectile"):
		return
	if not T.require_true(self, float(projectile.get("max_distance_m")) >= 800.0, "Player rifle projectiles must preserve a long-range reach well beyond the legacy ~200m feel"):
		return

	var trace_segment: Dictionary = player.get_aim_trace_segment()
	if not T.require_true(self, float(trace_segment.get("distance_m", 0.0)) >= 800.0, "Player aim trace distance must be extended to match the new rifle long-range ballistic contract"):
		return

	var tracer_root := world.get_node_or_null("CombatRoot/ProjectileTracers") as Node3D
	if not T.require_true(self, tracer_root != null and tracer_root.get_child_count() > 0, "Rifle vfx/ballistics contract requires CombatRoot/ProjectileTracers to hold the smoke trace visual"):
		return
	var tracer := tracer_root.get_child(tracer_root.get_child_count() - 1) as Node3D
	if not T.require_true(self, tracer != null and tracer.has_method("get_debug_state"), "Smoke tracer visual must expose get_debug_state() for regression verification"):
		return
	var tracer_state: Dictionary = tracer.get_debug_state()
	if not T.require_true(self, bool(tracer_state.get("active", false)), "Freshly spawned rifle tracer must report itself active during the short visibility window"):
		return
	if not T.require_true(self, float(tracer_state.get("segment_length_m", 0.0)) >= 3.5, "Rifle tracer must expose a non-trivial visible segment length instead of an imperceptible blip"):
		return
	await process_frame
	await physics_frame

	var tracer_cleared := false
	for _frame in range(18):
		await process_frame
		if int(world.get_active_projectile_tracer_count()) <= tracer_count_before:
			tracer_cleared = true
			break
	if not T.require_true(self, tracer_cleared, "Rifle smoke tracer visuals must stay transient and clear shortly after the shot"):
		return

	world.queue_free()
	T.pass_and_quit(self)
