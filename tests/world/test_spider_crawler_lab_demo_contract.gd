extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Spider crawler lab demo contract requires SpiderCrawlerLab.tscn"):
		return
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider crawler lab demo contract must load SpiderCrawlerLab as PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"start_demo_motion",
		"pause_demo_motion",
		"toggle_demo_motion",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Spider crawler lab demo contract requires %s()" % required_method):
			return

	var boot_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, not bool(boot_state.get("auto_step_enabled", true)), "Headless boot must stay deterministic before demo motion is started explicitly"):
		return

	lab.start_demo_motion()
	var start_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, bool(start_state.get("auto_step_enabled", false)), "Starting spider demo motion must enable auto stepping"):
		return
	var player := lab.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "Spider crawler lab demo contract requires the authored Player node as the demo chase target"):
		return
	var debug_motion_velocity: Vector3 = start_state.get("debug_motion_velocity", Vector3.ZERO)
	if not T.require_true(self, debug_motion_velocity.length() > 0.1, "Starting spider demo motion must inject a non-zero motion velocity"):
		return
	var start_position: Vector3 = start_state.get("body_anchor_world_position", Vector3.ZERO)
	var to_player := player.global_position - start_position
	to_player.y = 0.0
	if not T.require_true(self, to_player.length() > 0.1, "Spider crawler lab demo contract requires a non-degenerate player chase vector"):
		return
	if not T.require_true(self, debug_motion_velocity.normalized().dot(to_player.normalized()) >= 0.9, "Spider demo motion must steer toward the player instead of following an arbitrary canned direction"):
		return
	for _frame in range(12):
		await physics_frame
		await process_frame
	var moved_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, float(moved_state.get("phase_time", 0.0)) > 0.0, "Spider demo motion must advance phase_time after a few rendered frames"):
		return
	var moved_position: Vector3 = moved_state.get("body_anchor_world_position", Vector3.ZERO)
	if not T.require_true(self, moved_position.distance_to(start_position) > 0.05, "Spider demo motion must visibly move the crawler anchor instead of only mutating hidden debug state"):
		return
	var moved_distance_to_player := moved_position.distance_to(player.global_position)
	if not T.require_true(self, moved_distance_to_player < start_position.distance_to(player.global_position), "Spider demo motion must bring the crawler closer to the player over time"):
		return

	lab.pause_demo_motion()
	var paused_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, not bool(paused_state.get("auto_step_enabled", true)), "Pausing spider demo motion must disable auto stepping"):
		return
	if not T.require_true(self, (paused_state.get("debug_motion_velocity", Vector3.ONE) as Vector3).length() <= 0.001, "Pausing spider demo motion must zero the motion velocity"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
