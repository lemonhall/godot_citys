extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SPIDER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(SPIDER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider body target stability contract requires CitySpiderCrawler.tscn"):
		return

	var spider := scene.instantiate() as Node3D
	root.add_child(spider)
	await process_frame
	await process_frame

	spider.set_debug_motion_velocity(Vector3(0.0, 0.0, 3.0))

	var previous_origin := Vector3.ZERO
	var saw_previous := false
	for _tick in range(20):
		spider.tick_crawler(0.12)
		var state: Dictionary = spider.get_debug_state()
		var body_target_transform: Dictionary = state.get("body_target_transform", {})
		var grounded_leg_count := int(body_target_transform.get("grounded_leg_count", -1))
		var origin: Vector3 = body_target_transform.get("origin", Vector3.ZERO)
		if not T.require_true(self, grounded_leg_count >= 1, "Spider body target stability contract requires at least one grounded support leg during ground crawling; zero grounded legs causes body origin collapse"):
			return
		if saw_previous:
			if not T.require_true(self, origin.distance_to(previous_origin) < 2.0, "Spider body target stability contract forbids body origin teleports between adjacent crawl ticks"):
				return
		previous_origin = origin
		saw_previous = true

	spider.queue_free()
	await process_frame
	T.pass_and_quit(self)
