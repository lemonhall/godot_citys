extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider crawler lab flow requires SpiderCrawlerLab.tscn"):
		return
	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"teleport_spider_to_world_position",
		"set_spider_motion_velocity",
		"force_spider_replan",
		"step_spider",
		"reset_lab_state",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Spider crawler lab flow requires %s()" % required_method):
			return

	lab.teleport_spider_to_world_position(Vector3(18.0, 0.0, 0.0))
	lab.set_spider_motion_velocity(Vector3(2.8, 0.0, 0.0))
	lab.force_spider_replan()
	lab.step_spider(0.18, 6)

	var ramp_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, str(ramp_state.get("species_id", "")) == "spider", "Spider crawler lab flow must preserve spider as the active species"):
		return
	if not T.require_true(self, int(ramp_state.get("leg_count", 0)) == 8, "Spider crawler lab flow must preserve 8 spider legs in the live lab state"):
		return
	if not T.require_true(self, float(ramp_state.get("phase_time", 0.0)) > 1.0, "Spider crawler lab flow must advance phase_time after the deterministic step sequence"):
		return
	var body_target_transform: Dictionary = ramp_state.get("body_target_transform", {})
	if not T.require_true(self, float((body_target_transform.get("origin", Vector3.ZERO) as Vector3).y) > 1.5, "Spider crawler lab flow must carry the body target upward when the crawler crosses the authored ramp"):
		return

	lab.reset_lab_state()
	var reset_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, float(reset_state.get("phase_time", 999.0)) == 0.0, "Spider crawler lab flow must restore phase_time to zero after reset"):
		return
	if not T.require_true(self, (reset_state.get("body_anchor_world_position", Vector3.ZERO) as Vector3).distance_to(Vector3(-26.0, 0.0, 0.0)) <= 0.01, "Spider crawler lab flow reset must restore the authored crawler spawn anchor"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
