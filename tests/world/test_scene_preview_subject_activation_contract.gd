extends SceneTree

const T := preload("res://tests/_test_util.gd")

const PREVIEW_WRAPPER_SCENE_PATH := "res://city_game/assets/minigames/missile_command/projectiles/InterceptorMissileVisualPreview.tscn"
const SUBJECT_SCENE_PATH := "res://city_game/assets/minigames/missile_command/projectiles/InterceptorMissileVisual.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(PREVIEW_WRAPPER_SCENE_PATH, "PackedScene"), "Scene preview subject activation contract requires the committed InterceptorMissileVisualPreview.tscn wrapper scene"):
		return
	var wrapper_scene := load(PREVIEW_WRAPPER_SCENE_PATH) as PackedScene
	if not T.require_true(self, wrapper_scene != null, "Scene preview subject activation contract must load the committed missile preview wrapper as PackedScene"):
		return

	var harness := wrapper_scene.instantiate() as Node3D
	if not T.require_true(self, harness != null, "Scene preview subject activation contract must instantiate the committed wrapper as Node3D"):
		return
	if not T.require_true(self, harness.has_method("get_preview_runtime_state"), "Scene preview subject activation contract requires the wrapper to be rooted in the preview harness"):
		return
	if not T.require_true(self, harness.has_method("handle_preview_input_event"), "Scene preview subject activation contract requires deterministic input routing through the harness"):
		return

	root.add_child(harness)
	await process_frame
	await process_frame

	var runtime_state := harness.get_preview_runtime_state() as Dictionary
	if not T.require_true(self, bool(runtime_state.get("subject_loaded", false)), "Scene preview subject activation contract must mount the missile visual subject into the harness"):
		return
	if not T.require_true(self, str(runtime_state.get("subject_scene_path", "")) == SUBJECT_SCENE_PATH, "Scene preview subject activation contract must preserve the missile subject scene path at runtime"):
		return
	if not T.require_true(self, bool(runtime_state.get("preview_mouse_captured", false)), "Scene preview subject activation contract must start with mouse capture enabled"):
		return

	var subject := harness.get_node_or_null("PreviewSubjectRoot/InterceptorMissileVisual") as Node3D
	if not T.require_true(self, subject != null, "Scene preview subject activation contract must mount InterceptorMissileVisual beneath PreviewSubjectRoot"):
		return
	if not T.require_true(self, subject.has_method("get_scene_preview_contract"), "Scene preview subject activation contract requires get_scene_preview_contract() on InterceptorMissileVisual"):
		return
	if not T.require_true(self, subject.has_method("set_scene_preview_active"), "Scene preview subject activation contract requires set_scene_preview_active() on InterceptorMissileVisual"):
		return
	if not T.require_true(self, subject.get_node_or_null("PreviewCamera") == null, "Scene preview subject activation contract must migrate preview camera ownership into the harness instead of leaving PreviewCamera on the subject scene"):
		return
	if not T.require_true(self, subject.get_node_or_null("PreviewLight") == null, "Scene preview subject activation contract must migrate preview light ownership into the harness instead of leaving PreviewLight on the subject scene"):
		return

	var initial_subject_world_position := subject.global_position
	var subject_debug_state := await _wait_for_subject_preview_activation(subject)
	if not T.require_true(self, bool(subject_debug_state.get("preview_active", false)), "Scene preview subject activation contract must formally activate the missile subject preview behavior through the harness contract"):
		return
	if not T.require_true(self, bool(subject_debug_state.get("trail_visible", false)), "Scene preview subject activation contract must light the missile tail flame once harness-driven preview activates"):
		return
	if not T.require_true(self, (subject.global_position.distance_to(initial_subject_world_position) > 0.18), "Scene preview subject activation contract must let the missile subject animate through space during harness preview"):
		return

	var camera_forward_before := runtime_state.get("camera_forward", Vector3.FORWARD) as Vector3
	_send_mouse_motion(harness, Vector2(-72.0, 28.0))
	await process_frame
	runtime_state = harness.get_preview_runtime_state() as Dictionary
	if not T.require_true(self, ((runtime_state.get("camera_forward", Vector3.FORWARD) as Vector3).distance_to(camera_forward_before) > 0.02), "Scene preview subject activation contract must preserve harness-driven free-look after the missile preview subject is activated"):
		return

	harness.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_subject_preview_activation(subject: Node3D) -> Dictionary:
	for _frame in range(90):
		await process_frame
		if not subject.has_method("get_debug_state"):
			break
		var debug_state := subject.get_debug_state() as Dictionary
		if bool(debug_state.get("preview_active", false)) and bool(debug_state.get("trail_visible", false)):
			return debug_state
	return subject.get_debug_state() as Dictionary if subject.has_method("get_debug_state") else {}

func _send_mouse_motion(harness: Node, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = Vector2(640.0, 360.0)
	harness.handle_preview_input_event(event)
