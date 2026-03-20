extends SceneTree

const T := preload("res://tests/_test_util.gd")

const HARNESS_SCENE_PATH := "res://city_game/preview/ScenePreviewHarness.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(HARNESS_SCENE_PATH, "PackedScene"), "Scene preview harness contract requires ScenePreviewHarness.tscn"):
		return
	var harness_scene := load(HARNESS_SCENE_PATH) as PackedScene
	if not T.require_true(self, harness_scene != null, "Scene preview harness contract must load ScenePreviewHarness.tscn as PackedScene"):
		return

	var harness := harness_scene.instantiate() as Node3D
	if not T.require_true(self, harness != null, "Scene preview harness contract must instantiate the harness scene as Node3D"):
		return
	if not T.require_true(self, harness.has_method("get_preview_runtime_state"), "Scene preview harness contract requires get_preview_runtime_state() on the harness root"):
		return
	if not T.require_true(self, harness.has_method("handle_preview_input_event"), "Scene preview harness contract requires handle_preview_input_event() so focused tests can drive preview input deterministically"):
		return

	var subject_scene := _build_static_subject_scene()
	if not T.require_true(self, subject_scene != null, "Scene preview harness contract requires a packed zero-code subject scene for mount verification"):
		return
	harness.subject_scene = subject_scene
	harness.subject_scene_path = "res://tests/virtual/StaticPreviewSubject.tscn"

	root.add_child(harness)
	await process_frame
	await process_frame

	for required_node_path in [
		"PreviewSubjectRoot",
		"PreviewCameraRig",
		"PreviewCameraRig/PreviewCamera",
		"PreviewLight",
		"PreviewEnvironment",
		"PreviewFloor",
		"Overlay",
		"Overlay/FpsLabel",
		"Overlay/FrameTimeLabel",
	]:
		if not T.require_true(self, harness.get_node_or_null(required_node_path) != null, "Scene preview harness contract must author %s in the scene-first harness hierarchy" % required_node_path):
			return

	var runtime_state := harness.get_preview_runtime_state() as Dictionary
	if not T.require_true(self, bool(runtime_state.get("subject_loaded", false)), "Scene preview harness contract must mount the configured subject scene into PreviewSubjectRoot"):
		return
	if not T.require_true(self, runtime_state.get("camera_world_position", null) is Vector3, "Scene preview harness contract must expose camera_world_position in the runtime state"):
		return
	if not T.require_true(self, runtime_state.get("camera_forward", null) is Vector3, "Scene preview harness contract must expose camera_forward in the runtime state"):
		return
	if not T.require_true(self, bool(runtime_state.get("fps_overlay_visible", false)), "Scene preview harness contract must keep the stats overlay visible during preview"):
		return
	if not T.require_true(self, runtime_state.get("frame_time_ms", null) is float, "Scene preview harness contract must expose frame_time_ms as a float runtime sample"):
		return
	if not T.require_true(self, bool(runtime_state.get("preview_mouse_captured", false)), "Scene preview harness contract must capture the mouse by default so preview look starts immediately"):
		return

	var fps_label := harness.get_node("Overlay/FpsLabel") as Label
	var frame_time_label := harness.get_node("Overlay/FrameTimeLabel") as Label
	if not T.require_true(self, fps_label.visible and frame_time_label.visible, "Scene preview harness contract must show both FPS and frame-time labels"):
		return
	if not T.require_true(self, fps_label.text.begins_with("FPS "), "Scene preview harness contract must render an FPS-prefixed label"):
		return
	if not T.require_true(self, frame_time_label.text.find("ms") >= 0, "Scene preview harness contract must render a frame-time label with ms units"):
		return

	var subject_instance := harness.get_node("PreviewSubjectRoot").get_child(0) as Node3D
	if not T.require_true(self, subject_instance != null, "Scene preview harness contract must materialize a Node3D subject child under PreviewSubjectRoot"):
		return
	var camera_world_before_follow := runtime_state.get("camera_world_position", Vector3.ZERO) as Vector3
	subject_instance.global_position += Vector3(0.0, 0.0, 4.0)
	await process_frame
	await process_frame
	runtime_state = harness.get_preview_runtime_state() as Dictionary
	var camera_world_after_follow := runtime_state.get("camera_world_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, camera_world_after_follow.distance_to(camera_world_before_follow) > 3.5, "Scene preview harness contract must follow subject translation instead of leaving the camera anchored to world zero"):
		return

	var camera_forward_before_look := runtime_state.get("camera_forward", Vector3.FORWARD) as Vector3
	_send_mouse_motion(harness, Vector2(84.0, -32.0))
	await process_frame
	runtime_state = harness.get_preview_runtime_state() as Dictionary
	if not T.require_true(self, ((runtime_state.get("camera_forward", Vector3.FORWARD) as Vector3).distance_to(camera_forward_before_look) > 0.02), "Scene preview harness contract must rotate the preview camera in response to mouse motion"):
		return

	var camera_world_before_move := runtime_state.get("camera_world_position", Vector3.ZERO) as Vector3
	_send_key(harness, KEY_W, true)
	for _frame in range(10):
		await process_frame
	_send_key(harness, KEY_W, false)
	await process_frame
	runtime_state = harness.get_preview_runtime_state() as Dictionary
	var walk_distance := (runtime_state.get("camera_world_position", Vector3.ZERO) as Vector3).distance_to(camera_world_before_move)
	if not T.require_true(self, walk_distance > 0.18, "Scene preview harness contract must move the camera forward when W is held"):
		return

	camera_world_before_move = runtime_state.get("camera_world_position", Vector3.ZERO) as Vector3
	_send_key(harness, KEY_E, true)
	for _frame in range(8):
		await process_frame
	_send_key(harness, KEY_E, false)
	await process_frame
	runtime_state = harness.get_preview_runtime_state() as Dictionary
	var vertical_distance := (runtime_state.get("camera_world_position", Vector3.ZERO) as Vector3).y - camera_world_before_move.y
	if not T.require_true(self, vertical_distance > 0.12, "Scene preview harness contract must move the camera upward when E is held"):
		return

	camera_world_before_move = runtime_state.get("camera_world_position", Vector3.ZERO) as Vector3
	_send_key(harness, KEY_W, true)
	for _frame in range(6):
		await process_frame
	_send_key(harness, KEY_W, false)
	await process_frame
	runtime_state = harness.get_preview_runtime_state() as Dictionary
	var normal_move_distance := (runtime_state.get("camera_world_position", Vector3.ZERO) as Vector3).distance_to(camera_world_before_move)

	camera_world_before_move = runtime_state.get("camera_world_position", Vector3.ZERO) as Vector3
	_send_key(harness, KEY_SHIFT, true)
	_send_key(harness, KEY_W, true)
	for _frame in range(6):
		await process_frame
	_send_key(harness, KEY_W, false)
	_send_key(harness, KEY_SHIFT, false)
	await process_frame
	runtime_state = harness.get_preview_runtime_state() as Dictionary
	var sprint_move_distance := (runtime_state.get("camera_world_position", Vector3.ZERO) as Vector3).distance_to(camera_world_before_move)
	if not T.require_true(self, sprint_move_distance > normal_move_distance * 1.35, "Scene preview harness contract must accelerate fly movement when Shift is held"):
		return

	_send_key(harness, KEY_ESCAPE, true)
	_send_key(harness, KEY_ESCAPE, false)
	await process_frame
	runtime_state = harness.get_preview_runtime_state() as Dictionary
	if not T.require_true(self, not bool(runtime_state.get("preview_mouse_captured", true)), "Scene preview harness contract must release mouse capture when Escape is pressed"):
		return

	_send_mouse_button(harness, MOUSE_BUTTON_LEFT, true)
	await process_frame
	runtime_state = harness.get_preview_runtime_state() as Dictionary
	if not T.require_true(self, bool(runtime_state.get("preview_mouse_captured", false)), "Scene preview harness contract must recapture the mouse on a pressed mouse button"):
		return

	harness.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _build_static_subject_scene() -> PackedScene:
	var subject_root := Node3D.new()
	subject_root.name = "StaticPreviewSubject"
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = BoxMesh.new()
	subject_root.add_child(mesh_instance)
	mesh_instance.owner = subject_root
	var subject_scene := PackedScene.new()
	var pack_error := subject_scene.pack(subject_root)
	if pack_error != OK:
		subject_root.free()
		return null
	subject_root.free()
	return subject_scene

func _send_key(harness: Node, keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.pressed = pressed
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	harness.handle_preview_input_event(event)

func _send_mouse_motion(harness: Node, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = Vector2(640.0, 360.0)
	harness.handle_preview_input_event(event)

func _send_mouse_button(harness: Node, button_index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = Vector2(640.0, 360.0)
	harness.handle_preview_input_event(event)
