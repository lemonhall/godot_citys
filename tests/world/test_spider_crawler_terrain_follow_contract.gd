extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Spider terrain follow contract requires SpiderCrawlerLab.tscn"):
		return
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider terrain follow contract must load SpiderCrawlerLab as PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("teleport_spider_to_world_position"), "Spider terrain follow contract requires deterministic spider teleportation"):
		return
	if not T.require_true(self, lab.has_method("force_spider_replan"), "Spider terrain follow contract requires force_spider_replan()"):
		return

	lab.teleport_spider_to_world_position(Vector3(18.0, 0.0, 0.0))
	lab.force_spider_replan()
	lab.step_spider(0.18, 4)

	var ramp_state: Dictionary = lab.get_crawler_debug_state()
	var legs: Array = ramp_state.get("legs", [])
	var elevated_leg_count := 0
	var sloped_leg_count := 0
	for leg_variant in legs:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		var locked_foothold: Vector3 = leg_state.get("locked_foothold", Vector3.ZERO)
		var surface_normal: Vector3 = leg_state.get("surface_normal", Vector3.UP)
		if locked_foothold.y > 1.0:
			elevated_leg_count += 1
		if surface_normal.y < 0.985:
			sloped_leg_count += 1
	if not T.require_true(self, elevated_leg_count >= 4, "Spider terrain follow contract requires at least four legs to resolve onto the authored ramp elevation"):
		return
	if not T.require_true(self, sloped_leg_count >= 4, "Spider terrain follow contract requires at least four legs to inherit a non-flat surface normal on the ramp"):
		return
	var body_target_transform: Dictionary = ramp_state.get("body_target_transform", {})
	var body_origin: Vector3 = body_target_transform.get("origin", Vector3.ZERO)
	var body_up: Vector3 = body_target_transform.get("up", Vector3.UP)
	if not T.require_true(self, body_origin.y > 1.5, "Spider terrain follow contract requires the body target to rise above flat-ground clearance when replanned onto the ramp"):
		return
	if not T.require_true(self, body_up.y < 0.99, "Spider terrain follow contract requires body up-vector tilt to follow the authored ramp plane"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
