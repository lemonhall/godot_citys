extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"
const STEP_DELTA := 1.0 / 60.0
const STEP_COUNT := 180
const MAX_ALLOWED_ADJACENT_BODY_LATERAL_DX := 0.35

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider lab body jitter contract requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"start_demo_motion",
		"get_spider_crawler",
		"get_crawler_debug_state",
		"step_spider",
		"_update_demo_motion_velocity",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Spider lab body jitter contract requires %s()" % required_method):
			return

	lab.start_demo_motion()

	var spider := lab.get_spider_crawler() as Node3D
	if not T.require_true(self, spider != null, "Spider lab body jitter contract requires a live crawler node"):
		return

	var previous_body_lateral_x := 0.0
	var saw_previous := false
	var max_adjacent_body_lateral_dx := 0.0

	for _tick in range(STEP_COUNT):
		lab.call("_update_demo_motion_velocity")
		lab.step_spider(STEP_DELTA, 1)
		var state: Dictionary = lab.get_crawler_debug_state()
		var body_visual_world_position: Vector3 = state.get("body_visual_world_position", Vector3.ZERO)
		var body_local: Vector3 = spider.to_local(body_visual_world_position)
		if saw_previous:
			max_adjacent_body_lateral_dx = maxf(max_adjacent_body_lateral_dx, absf(body_local.x - previous_body_lateral_x))
		previous_body_lateral_x = body_local.x
		saw_previous = true

	if not T.require_true(
		self,
		max_adjacent_body_lateral_dx <= MAX_ALLOWED_ADJACENT_BODY_LATERAL_DX,
		"Spider lab body jitter contract forbids adjacent body lateral jumps above %.2fm during chase gait; large jumps show up as 1-2 frame torso ghosting" % MAX_ALLOWED_ADJACENT_BODY_LATERAL_DX
	):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
