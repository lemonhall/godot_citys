extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"
const STEP_DELTA := 1.0 / 60.0
const STEP_COUNT := 180

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider lab jitter diagnostic requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("start_demo_motion"), "Spider lab jitter diagnostic requires start_demo_motion()"):
		return
	if not T.require_true(self, lab.has_method("get_spider_crawler"), "Spider lab jitter diagnostic requires get_spider_crawler()"):
		return
	if not T.require_true(self, lab.has_method("get_crawler_debug_state"), "Spider lab jitter diagnostic requires get_crawler_debug_state()"):
		return
	if not T.require_true(self, lab.has_method("step_spider"), "Spider lab jitter diagnostic requires step_spider()"):
		return
	if not T.require_true(self, lab.has_method("_update_demo_motion_velocity"), "Spider lab jitter diagnostic requires _update_demo_motion_velocity()"):
		return

	lab.start_demo_motion()

	var spider := lab.get_spider_crawler() as Node3D
	if not T.require_true(self, spider != null, "Spider lab jitter diagnostic requires a live crawler node"):
		return

	var previous_body_lateral_x := 0.0
	var previous_centroid_lateral_x := 0.0
	var saw_previous := false
	var max_adjacent_body_lateral_dx := 0.0
	var max_adjacent_centroid_lateral_dx := 0.0
	var samples: Array[String] = []

	for tick in range(STEP_COUNT):
		lab.call("_update_demo_motion_velocity")
		lab.step_spider(STEP_DELTA, 1)
		var state: Dictionary = lab.get_crawler_debug_state()
		var body_target_transform: Dictionary = state.get("body_target_transform", {})
		var body_visual_world_position: Vector3 = state.get("body_visual_world_position", Vector3.ZERO)
		var leg_centroid_world_position: Vector3 = body_target_transform.get("leg_centroid_world_position", Vector3.ZERO)
		var support_center_world_position: Vector3 = body_target_transform.get("support_center", Vector3.ZERO)
		var plane_normal: Vector3 = body_target_transform.get("plane_normal", Vector3.ZERO)
		var body_local: Vector3 = spider.to_local(body_visual_world_position)
		var centroid_local: Vector3 = spider.to_local(leg_centroid_world_position)
		var support_local: Vector3 = spider.to_local(support_center_world_position)
		if saw_previous:
			max_adjacent_body_lateral_dx = maxf(max_adjacent_body_lateral_dx, absf(body_local.x - previous_body_lateral_x))
			max_adjacent_centroid_lateral_dx = maxf(max_adjacent_centroid_lateral_dx, absf(centroid_local.x - previous_centroid_lateral_x))
		previous_body_lateral_x = body_local.x
		previous_centroid_lateral_x = centroid_local.x
		saw_previous = true
		samples.append(
			"tick=%02d body_local_x=%.4f centroid_local_x=%.4f support_local_x=%.4f plane=(%.3f,%.3f,%.3f) root_pos=(%.3f,%.3f,%.3f)" % [
				tick,
				body_local.x,
				centroid_local.x,
				support_local.x,
				plane_normal.x,
				plane_normal.y,
				plane_normal.z,
				spider.global_position.x,
				spider.global_position.y,
				spider.global_position.z,
			]
		)

	print("--- spider lab body lateral jitter diagnostic ---")
	for line in samples:
		print(line)
	print("max_adjacent_body_lateral_dx=%.6f" % max_adjacent_body_lateral_dx)
	print("max_adjacent_centroid_lateral_dx=%.6f" % max_adjacent_centroid_lateral_dx)

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
