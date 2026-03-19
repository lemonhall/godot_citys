extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TENNIS_BALL_SCENE_PATH := "res://city_game/serviceability/interactive_props/generated/prop_v28_tennis_ball_chunk_158_140/tennis_ball_prop.tscn"
const TENNIS_BALL_MANIFEST_PATH := "res://city_game/serviceability/interactive_props/generated/prop_v28_tennis_ball_chunk_158_140/interactive_prop_manifest.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ball_scene := load(TENNIS_BALL_SCENE_PATH)
	if not T.require_true(self, ball_scene is PackedScene, "Tennis ball feedback contract requires the authored tennis ball scene to load as PackedScene"):
		return
	var manifest_variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(TENNIS_BALL_MANIFEST_PATH)))
	if not T.require_true(self, manifest_variant is Dictionary, "Tennis ball feedback contract requires the tennis ball manifest to parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant

	var floor := _build_test_floor()
	root.add_child(floor)
	var ball_node := (ball_scene as PackedScene).instantiate()
	root.add_child(ball_node)
	if ball_node.has_method("configure_interactive_prop"):
		ball_node.configure_interactive_prop(manifest.duplicate(true))
	await process_frame

	if not T.require_true(self, ball_node.has_method("get_ball_feedback_state"), "Tennis ball feedback contract requires get_ball_feedback_state() on the tennis ball prop"):
		return
	var feedback_state: Dictionary = ball_node.get_ball_feedback_state()
	if not T.require_true(self, bool(feedback_state.get("glow_shell_present", false)), "Tennis ball feedback contract requires a high-contrast glow shell for third-person readability"):
		return
	if not T.require_true(self, bool(feedback_state.get("trail_present", false)), "Tennis ball feedback contract requires a motion trail visual for fast incoming shots"):
		return
	if not T.require_true(self, bool(feedback_state.get("impact_audio_player_present", false)), "Tennis ball feedback contract requires an impact audio player for bounce/contact cues"):
		return

	if not (ball_node is RigidBody3D):
		T.fail_and_quit(self, "Tennis ball feedback contract requires the tennis ball prop root to remain a RigidBody3D")
		return
	var rigid_ball := ball_node as RigidBody3D
	rigid_ball.global_position = Vector3(0.0, 2.6, 0.0)
	rigid_ball.linear_velocity = Vector3(18.0, -1.6, 0.0)
	rigid_ball.angular_velocity = Vector3.ZERO
	rigid_ball.sleeping = false

	var trail_visible := await _wait_for_trail_visible(ball_node)
	if not T.require_true(self, trail_visible, "Tennis ball feedback contract requires the motion trail to become visible while the ball is traveling at playable speed"):
		return

	var impact_audio_observed := await _wait_for_impact_audio(ball_node)
	if not T.require_true(self, impact_audio_observed, "Tennis ball feedback contract requires a real bounce/contact to trigger an impact audio event"):
		return
	feedback_state = ball_node.get_ball_feedback_state()
	if not T.require_true(self, int(feedback_state.get("impact_audio_play_count", 0)) >= 1, "Tennis ball feedback contract requires at least one recorded impact audio event after the bounce test"):
		return
	if not T.require_true(self, str(feedback_state.get("last_impact_kind", "")) == "bounce", "Tennis ball feedback contract floor collision should classify as bounce impact feedback"):
		return

	var impact_audio_player := ball_node.get_node_or_null("ImpactAudio") as AudioStreamPlayer3D
	if impact_audio_player != null:
		impact_audio_player.stop()
		impact_audio_player.stream = null
	for _frame in range(6):
		await process_frame
	ball_node.queue_free()
	floor.queue_free()
	await process_frame
	await process_frame
	T.pass_and_quit(self)

func _build_test_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "TestFloor"
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(16.0, 1.0, 16.0)
	collision_shape.shape = box_shape
	floor.add_child(collision_shape)
	floor.position = Vector3(0.0, -0.5, 0.0)
	return floor

func _wait_for_trail_visible(ball_node) -> bool:
	for _frame in range(30):
		await physics_frame
		await process_frame
		var feedback_state: Dictionary = ball_node.get_ball_feedback_state()
		if bool(feedback_state.get("trail_visible", false)):
			return true
	return bool(ball_node.get_ball_feedback_state().get("trail_visible", false))

func _wait_for_impact_audio(ball_node) -> bool:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var feedback_state: Dictionary = ball_node.get_ball_feedback_state()
		if int(feedback_state.get("impact_audio_play_count", 0)) >= 1:
			return true
	return int(ball_node.get_ball_feedback_state().get("impact_audio_play_count", 0)) >= 1
