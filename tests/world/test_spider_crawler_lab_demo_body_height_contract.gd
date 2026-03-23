extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"
const MAX_DEMO_BODY_LOCAL_Y_M := 2.0
const DEMO_CLUSTER_FRAME_WINDOW := 240

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider crawler lab demo body height contract requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("start_demo_motion"), "Spider crawler lab demo body height contract requires start_demo_motion()"):
		return
	if not T.require_true(self, lab.has_method("get_spider_crawlers"), "Spider crawler lab demo body height contract requires get_spider_crawlers()"):
		return

	lab.start_demo_motion()
	for _frame in range(DEMO_CLUSTER_FRAME_WINDOW):
		await physics_frame
		await process_frame

	var worst_body_local_y := -INF
	for spider_variant in lab.get_spider_crawlers():
		var spider := spider_variant as Node3D
		if spider == null or not spider.has_method("get_debug_state"):
			continue
		var state: Dictionary = spider.get_debug_state()
		var body_visual_world_position: Vector3 = state.get("body_visual_world_position", Vector3.ZERO)
		var body_local_position: Vector3 = spider.to_local(body_visual_world_position)
		worst_body_local_y = maxf(worst_body_local_y, body_local_position.y)

	if not T.require_true(
		self,
		worst_body_local_y < MAX_DEMO_BODY_LOCAL_Y_M,
		"Spider crawler demo body height contract forbids the swarm from standing upright into the air (worst local y %.3fm)" % worst_body_local_y
	):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
