extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Spider gait contract requires SpiderCrawlerLab.tscn"):
		return
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider gait contract must load SpiderCrawlerLab as PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("set_spider_motion_velocity"), "Spider gait contract requires lab velocity control for deterministic stepping"):
		return
	if not T.require_true(self, lab.has_method("step_spider"), "Spider gait contract requires step_spider()"):
		return

	var boot_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, int(boot_state.get("leg_count", 0)) == 8, "Spider gait contract must start with 8 configured legs"):
		return
	if not T.require_true(self, float(boot_state.get("phase_time", 0.0)) == 0.0, "Spider gait contract must boot with zero phase_time before stepping"):
		return

	lab.set_spider_motion_velocity(Vector3(3.0, 0.0, 0.0))
	lab.step_spider(0.18, 8)

	var stepped_state: Dictionary = lab.get_crawler_debug_state()
	var phase_time := float(stepped_state.get("phase_time", 0.0))
	if not T.require_true(self, absf(phase_time - 1.44) <= 0.02, "Spider gait contract must accumulate phase_time after repeated stepping"):
		return
	var legs: Array = stepped_state.get("legs", [])
	var stance_count := 0
	var airborne_count := 0
	var total_replans := 0
	var mode_seen: Dictionary = {}
	for leg_variant in legs:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		var mode: String = str(leg_state.get("mode", ""))
		mode_seen[mode] = true
		if mode == "stance":
			stance_count += 1
		else:
			airborne_count += 1
		total_replans += int(leg_state.get("replan_count", 0))
	if not T.require_true(self, stance_count >= 2, "Spider gait contract requires at least two stance legs during stepping so the spider keeps a support polygon"):
		return
	if not T.require_true(self, airborne_count >= 2, "Spider gait contract requires at least two non-stance legs during stepping so the spider is not frozen in one pose"):
		return
	if not T.require_true(self, total_replans > 0, "Spider gait contract requires stepping with forward motion to trigger at least one foothold replan"):
		return
	if not T.require_true(self, int(stepped_state.get("failed_replan_count", -1)) == 0, "Spider gait contract should not accumulate failed foothold replans on the authored flat start lane"):
		return
	if not T.require_true(self, mode_seen.size() >= 2, "Spider gait contract requires more than one active per-leg mode after stepping"):
		return

	lab.reset_lab_state()
	var reset_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, float(reset_state.get("phase_time", 999.0)) == 0.0, "Resetting SpiderCrawlerLab must restore phase_time to zero"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
