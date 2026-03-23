extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SPIDER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(SPIDER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider reference step contract requires CitySpiderCrawler.tscn"):
		return

	var spider := scene.instantiate() as Node3D
	root.add_child(spider)
	await process_frame
	await process_frame

	if not T.require_true(self, spider.has_method("get_debug_state"), "Spider reference step contract requires get_debug_state()"):
		return

	var boot_state: Dictionary = spider.get_debug_state()
	if not T.require_true(self, str(boot_state.get("step_controller_id", "")) == "reference_anchor_prediction_v1", "Spider reference step contract requires a reference-driven step controller id instead of an opaque hand-tuned gait"):
		return

	spider.set_debug_motion_velocity(Vector3(0.0, 0.0, 3.0))
	var seen_active_step := false
	var seen_predicted_forward := false
	for _step in range(10):
		spider.tick_crawler(0.12)
		var stepped_state: Dictionary = spider.get_debug_state()
		var legs: Array = stepped_state.get("legs", [])
		for leg_variant in legs:
			if not (leg_variant is Dictionary):
				continue
			var leg_state: Dictionary = leg_variant as Dictionary
			var mode: String = str(leg_state.get("mode", ""))
			if mode == "stance":
				continue
			seen_active_step = true
			var locked_foothold: Vector3 = leg_state.get("locked_foothold", Vector3.ZERO)
			var display_foot_world_position: Vector3 = leg_state.get("display_foot_world_position", Vector3.ZERO)
			var step_goal_world_position: Vector3 = leg_state.get("step_goal_world_position", Vector3.ZERO)
			var default_anchor_world_position: Vector3 = leg_state.get("default_anchor_world_position", Vector3.ZERO)
			if display_foot_world_position.distance_to(locked_foothold) > 0.02 and step_goal_world_position.distance_to(locked_foothold) > 0.08 and step_goal_world_position.z > default_anchor_world_position.z + 0.03:
				seen_predicted_forward = true
	if not T.require_true(self, seen_active_step, "Spider reference step contract requires at least one active stepping leg during forward motion"):
		return
	if not T.require_true(self, seen_predicted_forward, "Spider reference step contract requires at least one stepping leg to place its goal ahead of the default anchor in motion direction, following anchor+overshoot+prediction logic"):
		return

	spider.queue_free()
	await process_frame
	T.pass_and_quit(self)
