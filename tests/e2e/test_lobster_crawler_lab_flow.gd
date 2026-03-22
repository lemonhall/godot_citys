extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/LobsterCrawlerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Lobster crawler lab flow requires LobsterCrawlerLab.tscn"):
		return
	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"teleport_lobster_to_world_position",
		"set_lobster_motion_velocity",
		"force_lobster_replan",
		"step_lobster",
		"reset_lab_state",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Lobster crawler lab flow requires %s()" % required_method):
			return

	lab.teleport_lobster_to_world_position(Vector3(38.0, 0.0, 0.0))
	lab.set_lobster_motion_velocity(Vector3(2.6, 0.0, 0.0))
	lab.force_lobster_replan()
	lab.step_lobster(0.18, 8)

	var runtime_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, str(runtime_state.get("species_id", "")) == "lobster", "Lobster crawler lab flow must preserve lobster as the active species"):
		return
	if not T.require_true(self, str(runtime_state.get("gait_profile_id", "")) == "metachronal_forward", "Lobster crawler lab flow must preserve the metachronal gait id in the live lab state"):
		return
	if not T.require_true(self, int(runtime_state.get("leg_count", 0)) == 10, "Lobster crawler lab flow must preserve 10 lobster limbs in the live lab state"):
		return
	if not T.require_true(self, float(runtime_state.get("phase_time", 0.0)) > 1.0, "Lobster crawler lab flow must advance phase_time after the deterministic step sequence"):
		return
	if not T.require_true(self, int(runtime_state.get("failed_replan_count", -1)) == 0, "Lobster crawler lab flow must stay on the success path across the authored dry lab fixtures"):
		return
	var body_visual_world_position: Vector3 = runtime_state.get("body_visual_world_position", Vector3.ZERO)
	if not T.require_true(self, body_visual_world_position.y > 0.15 and body_visual_world_position.y < 1.45, "Lobster crawler lab flow must keep the body lower than the spider while traversing the authored shelf lane"):
		return

	lab.reset_lab_state()
	var reset_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, float(reset_state.get("phase_time", 999.0)) == 0.0, "Lobster crawler lab flow must restore phase_time to zero after reset"):
		return
	if not T.require_true(self, (reset_state.get("body_anchor_world_position", Vector3.ZERO) as Vector3).distance_to(Vector3(-24.0, 0.0, 0.0)) <= 0.01, "Lobster crawler lab flow reset must restore the authored crawler spawn anchor"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
