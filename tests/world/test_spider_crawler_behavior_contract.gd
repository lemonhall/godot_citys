extends SceneTree

const T := preload("res://tests/_test_util.gd")
const SPIDER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var spider_scene := load(SPIDER_SCENE_PATH) as PackedScene
	if not T.require_true(self, spider_scene != null, "Spider behavior contract requires CitySpiderCrawler.tscn"):
		return

	var root_anchor := Node3D.new()
	root.add_child(root_anchor)

	var primary := spider_scene.instantiate() as Node3D
	var secondary := spider_scene.instantiate() as Node3D
	if not T.require_true(self, primary != null and secondary != null, "Spider behavior contract must instantiate two spider crawlers"):
		return
	root_anchor.add_child(primary)
	root_anchor.add_child(secondary)
	secondary.position = Vector3(6.0, 0.0, 0.0)
	await process_frame
	await process_frame

	if not T.require_true(self, primary.has_method("set_behavior_seed"), "Spider behavior contract requires set_behavior_seed()"):
		return
	if not T.require_true(self, primary.has_method("get_debug_state"), "Spider behavior contract requires get_debug_state()"):
		return
	if not T.require_true(self, primary.has_method("apply_projectile_hit"), "Spider behavior contract requires apply_projectile_hit()"):
		return

	primary.set_behavior_seed(101)
	secondary.set_behavior_seed(202)
	if primary.has_method("reset_crawler_state"):
		primary.reset_crawler_state()
	if secondary.has_method("reset_crawler_state"):
		secondary.reset_crawler_state()
	await process_frame
	await process_frame

	var primary_prosoma := primary.get_node_or_null("BodyPivot/ProsomaMesh") as MeshInstance3D
	var secondary_prosoma := secondary.get_node_or_null("BodyPivot/ProsomaMesh") as MeshInstance3D
	if not T.require_true(self, primary_prosoma != null and secondary_prosoma != null, "Spider behavior contract requires prosoma meshes for feedback isolation"):
		return
	var primary_material := primary_prosoma.material_override as StandardMaterial3D
	var secondary_material := secondary_prosoma.material_override as StandardMaterial3D
	if not T.require_true(self, primary_material != null and secondary_material != null, "Spider behavior contract requires per-spider prosoma materials"):
		return
	if not T.require_true(self, primary_material != secondary_material, "Spider behavior contract requires each spider instance to own its feedback material"):
		return

	var secondary_color_before := secondary_material.albedo_color
	var hit_result: Dictionary = primary.apply_projectile_hit(1.0, primary.global_position, Vector3.ZERO)
	if not T.require_true(self, bool(hit_result.get("accepted", false)), "Spider behavior contract requires projectile hits to be accepted on living spiders"):
		return
	await process_frame
	var primary_color_after := primary_material.albedo_color
	var secondary_color_after := secondary_material.albedo_color
	if not T.require_true(self, primary_color_after != secondary_color_before, "Spider behavior contract requires the hit spider to tint red"):
		return
	if not T.require_true(self, secondary_color_after == secondary_color_before, "Spider behavior contract requires unharmed spiders to keep their original tint"):
		return

	if primary.has_method("teleport_body_to_world_position"):
		primary.teleport_body_to_world_position(Vector3.ZERO)
	if primary.has_method("reset_health_state"):
		primary.reset_health_state()
	if primary.has_method("set_debug_motion_velocity"):
		primary.set_debug_motion_velocity(Vector3(0.0, 0.0, -4.0))
	primary.apply_projectile_hit(1.0, primary.global_position, Vector3.ZERO)
	var stun_state: Dictionary = primary.get_debug_state()
	var hit_stun_remaining := float(stun_state.get("hit_stun_remaining_seconds", 0.0))
	if not T.require_true(self, hit_stun_remaining >= 0.5 and hit_stun_remaining <= 1.0, "Spider behavior contract requires hits to apply a 0.5s-1.0s stun window"):
		return
	var stunned_position := primary.global_position
	for _frame in range(4):
		primary.tick_crawler(0.12)
	if not T.require_true(self, primary.global_position.distance_to(stunned_position) <= 0.05, "Spider behavior contract requires stunned spiders to stay in place during the stun window"):
		return
	for _frame in range(8):
		primary.tick_crawler(0.12)
	if not T.require_true(self, primary.global_position.distance_to(stunned_position) > 0.2, "Spider behavior contract requires spiders to resume movement after stun expires"):
		return

	if primary.has_method("teleport_body_to_world_position"):
		primary.teleport_body_to_world_position(Vector3.ZERO)
	if primary.has_method("reset_health_state"):
		primary.reset_health_state()
	if primary.has_method("set_debug_motion_velocity"):
		primary.set_debug_motion_velocity(Vector3(0.0, 0.0, -4.0))
	if primary.has_method("set_auto_step_enabled"):
		primary.set_auto_step_enabled(false)
	var pounce_count := 0
	var max_pounce_lift_m := 0.0
	for _frame in range(64):
		primary.tick_crawler(0.1)
		var debug_state: Dictionary = primary.get_debug_state()
		pounce_count = maxi(pounce_count, int(debug_state.get("pounce_total_count", 0)))
		max_pounce_lift_m = maxf(max_pounce_lift_m, float(debug_state.get("pounce_lift_m", 0.0)))
	if not T.require_true(self, pounce_count >= 1, "Spider behavior contract requires moving spiders to occasionally perform a pounce"):
		return
	if not T.require_true(self, max_pounce_lift_m >= 0.12, "Spider behavior contract requires the pounce to visibly lift the body off the ground"):
		return

	root_anchor.queue_free()
	await process_frame
	T.pass_and_quit(self)
