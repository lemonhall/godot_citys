extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider terrain body clearance diagnostic requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("teleport_spider_to_world_position"), "Spider terrain body clearance diagnostic requires deterministic spider teleportation"):
		return
	if not T.require_true(self, lab.has_method("force_spider_replan"), "Spider terrain body clearance diagnostic requires force_spider_replan()"):
		return
	if not T.require_true(self, lab.has_method("step_spider"), "Spider terrain body clearance diagnostic requires step_spider()"):
		return
	if not T.require_true(self, lab.has_method("get_crawler_debug_state"), "Spider terrain body clearance diagnostic requires get_crawler_debug_state()"):
		return

	lab.teleport_spider_to_world_position(Vector3(18.0, 0.0, 0.0))
	lab.force_spider_replan()

	print("--- spider terrain body clearance diagnostic ---")
	for tick in range(16):
		lab.step_spider(1.0 / 60.0, 1)
		var state: Dictionary = lab.get_crawler_debug_state()
		var body_visual_world_position: Vector3 = state.get("body_visual_world_position", Vector3.ZERO)
		var body_target_transform: Dictionary = state.get("body_target_transform", {})
		var body_target_origin: Vector3 = body_target_transform.get("origin", Vector3.ZERO)
		var body_target_up: Vector3 = body_target_transform.get("up", Vector3.UP)
		var min_locked_foot_y := INF
		var max_locked_foot_y := -INF
		for leg_variant in state.get("legs", []):
			if not (leg_variant is Dictionary):
				continue
			var leg_state: Dictionary = leg_variant as Dictionary
			var locked_foothold: Vector3 = leg_state.get("locked_foothold", Vector3.ZERO)
			min_locked_foot_y = minf(min_locked_foot_y, locked_foothold.y)
			max_locked_foot_y = maxf(max_locked_foot_y, locked_foothold.y)
		print(
			"tick=%02d body_visual_y=%.4f body_target_y=%.4f dy=%.4f up_y=%.4f feet=[%.4f, %.4f]" % [
				tick,
				body_visual_world_position.y,
				body_target_origin.y,
				body_target_origin.y - body_visual_world_position.y,
				body_target_up.y,
				min_locked_foot_y,
				max_locked_foot_y,
			]
		)

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
