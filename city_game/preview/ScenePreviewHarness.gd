extends Node3D

const PREVIEW_CAMERA_LOOK_SENSITIVITY := 0.0032
const PREVIEW_CAMERA_MOVE_SPEED_MPS := 9.0
const PREVIEW_CAMERA_SPRINT_MULTIPLIER := 2.4
const PREVIEW_CAMERA_PITCH_MIN_RAD := deg_to_rad(-88.0)
const PREVIEW_CAMERA_PITCH_MAX_RAD := deg_to_rad(88.0)

const FPS_RED_THRESHOLD := 30.0
const FPS_YELLOW_THRESHOLD := 50.0
const FRAME_TIME_GOOD_MS := 16.67
const FRAME_TIME_WARN_MS := 33.33

@export var subject_scene: PackedScene = null
@export_file("*.tscn") var subject_scene_path := ""
@export var stats_overlay_visible := true
@export var auto_capture_mouse := true

var _preview_subject_root: Node3D = null
var _preview_camera_rig: Node3D = null
var _preview_camera: Camera3D = null
var _fps_label: Label = null
var _frame_time_label: Label = null

var _subject_instance: Node = null
var _subject_contract: Dictionary = {}
var _resolved_subject_scene_path := ""
var _follow_target: Node3D = null
var _subject_preview_active := false

var _preview_mouse_captured := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _camera_yaw_rad := 0.0
var _camera_pitch_rad := 0.0
var _camera_local_position := Vector3.ZERO
var _scene_default_camera_local_position := Vector3.ZERO
var _scene_default_camera_yaw_rad := 0.0
var _scene_default_camera_pitch_rad := 0.0

var _move_forward := false
var _move_backward := false
var _move_left := false
var _move_right := false
var _move_up := false
var _move_down := false
var _move_fast := false

var _last_fps_sample := 0.0
var _last_frame_time_ms := 0.0

func _ready() -> void:
	_cache_nodes()
	_capture_scene_camera_defaults()
	_mount_subject()
	_apply_overlay_visibility()
	_update_overlay_state()
	if auto_capture_mouse:
		_capture_mouse()
	else:
		_release_mouse(false)
	if _preview_camera != null:
		_preview_camera.current = true

func _process(delta: float) -> void:
	_sync_follow_anchor()
	_update_camera_movement(delta)
	_update_overlay_state(delta)

func _input(event: InputEvent) -> void:
	handle_preview_input_event(event)

func _exit_tree() -> void:
	_deactivate_subject_preview()
	_restore_mouse_mode()

func handle_preview_input_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _preview_mouse_captured:
		var motion := event as InputEventMouseMotion
		_apply_preview_look_delta(motion.relative)
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and (
			button.button_index == MOUSE_BUTTON_LEFT
			or button.button_index == MOUSE_BUTTON_RIGHT
			or button.button_index == MOUSE_BUTTON_MIDDLE
		):
			_capture_mouse()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		_update_preview_key_state(key_event)
		if key_event.pressed and not key_event.echo and _resolve_event_keycode(key_event) == KEY_ESCAPE:
			_toggle_mouse_capture()

func get_preview_runtime_state() -> Dictionary:
	return {
		"subject_scene_path": _resolved_subject_scene_path,
		"subject_loaded": _subject_instance != null and is_instance_valid(_subject_instance),
		"preview_mouse_captured": _preview_mouse_captured,
		"camera_world_position": _preview_camera.global_position if _preview_camera != null else Vector3.ZERO,
		"camera_local_position": _camera_local_position,
		"camera_forward": (-_preview_camera.transform.basis.z).normalized() if _preview_camera != null else Vector3.FORWARD,
		"preview_camera_current": _preview_camera != null and _preview_camera.current,
		"fps_overlay_visible": _fps_label != null and _fps_label.visible and _frame_time_label != null and _frame_time_label.visible,
		"fps_sample": _last_fps_sample,
		"frame_time_ms": _last_frame_time_ms,
		"subject_preview_active": _subject_preview_active,
	}

func _cache_nodes() -> void:
	_preview_subject_root = get_node_or_null("PreviewSubjectRoot") as Node3D
	_preview_camera_rig = get_node_or_null("PreviewCameraRig") as Node3D
	_preview_camera = get_node_or_null("PreviewCameraRig/PreviewCamera") as Camera3D
	_fps_label = get_node_or_null("Overlay/FpsLabel") as Label
	_frame_time_label = get_node_or_null("Overlay/FrameTimeLabel") as Label

func _capture_scene_camera_defaults() -> void:
	if _preview_camera == null:
		return
	_scene_default_camera_local_position = _preview_camera.position
	var local_forward := (-_preview_camera.transform.basis.z).normalized()
	_scene_default_camera_pitch_rad = clampf(
		asin(clampf(local_forward.y, -1.0, 1.0)),
		PREVIEW_CAMERA_PITCH_MIN_RAD,
		PREVIEW_CAMERA_PITCH_MAX_RAD
	)
	_scene_default_camera_yaw_rad = atan2(local_forward.x, -local_forward.z)
	_camera_local_position = _scene_default_camera_local_position
	_camera_yaw_rad = _scene_default_camera_yaw_rad
	_camera_pitch_rad = _scene_default_camera_pitch_rad
	_apply_camera_transform()

func _mount_subject() -> void:
	_deactivate_subject_preview()
	_subject_contract = {}
	_follow_target = null
	_resolved_subject_scene_path = subject_scene_path.strip_edges()
	if _preview_subject_root == null:
		return
	for child in _preview_subject_root.get_children():
		child.free()
	_subject_instance = null
	var resolved_subject_scene := subject_scene
	if resolved_subject_scene == null and _resolved_subject_scene_path != "":
		if not ResourceLoader.exists(_resolved_subject_scene_path, "PackedScene"):
			return
		resolved_subject_scene = load(_resolved_subject_scene_path) as PackedScene
	if resolved_subject_scene == null:
		return
	if _resolved_subject_scene_path == "":
		_resolved_subject_scene_path = resolved_subject_scene.resource_path
	var instance := resolved_subject_scene.instantiate()
	if instance == null:
		return
	_preview_subject_root.add_child(instance)
	_subject_instance = instance
	call_deferred("_finalize_subject_setup")

func _finalize_subject_setup() -> void:
	if _subject_instance == null or not is_instance_valid(_subject_instance):
		return
	_subject_contract = _resolve_subject_contract(_subject_instance)
	_follow_target = _resolve_follow_target()
	_apply_subject_camera_defaults()
	_sync_follow_anchor()
	_activate_subject_preview()

func _resolve_subject_contract(subject: Node) -> Dictionary:
	if subject == null or not subject.has_method("get_scene_preview_contract"):
		return {}
	var contract_variant: Variant = subject.call("get_scene_preview_contract")
	return contract_variant.duplicate(true) if contract_variant is Dictionary else {}

func _resolve_follow_target() -> Node3D:
	if _subject_instance == null or not is_instance_valid(_subject_instance):
		return null
	var follow_target_path_variant: Variant = _subject_contract.get("follow_target_path", NodePath())
	if follow_target_path_variant is NodePath:
		var follow_node := _subject_instance.get_node_or_null(follow_target_path_variant as NodePath) as Node3D
		if follow_node != null:
			return follow_node
	if _subject_instance is Node3D:
		return _subject_instance as Node3D
	return _preview_subject_root

func _apply_subject_camera_defaults() -> void:
	_camera_local_position = _scene_default_camera_local_position
	_camera_yaw_rad = _scene_default_camera_yaw_rad
	_camera_pitch_rad = _scene_default_camera_pitch_rad
	if _subject_contract.has("default_camera_local_position"):
		var camera_local_position_variant: Variant = _subject_contract.get("default_camera_local_position", _scene_default_camera_local_position)
		if camera_local_position_variant is Vector3:
			_camera_local_position = camera_local_position_variant as Vector3
	if _subject_contract.has("default_camera_focus_local_position"):
		var focus_local_position_variant: Variant = _subject_contract.get("default_camera_focus_local_position", Vector3.ZERO)
		if focus_local_position_variant is Vector3:
			_apply_camera_look_at_local_point(focus_local_position_variant as Vector3)
			return
	_apply_camera_transform()

func _activate_subject_preview() -> void:
	_subject_preview_active = false
	if _subject_instance == null or not is_instance_valid(_subject_instance):
		return
	var capture_mouse_on_activate := bool(_subject_contract.get("capture_mouse_on_activate", auto_capture_mouse))
	if capture_mouse_on_activate:
		_capture_mouse()
	elif _preview_mouse_captured:
		_release_mouse(false)
	if _subject_instance.has_method("set_scene_preview_active"):
		_subject_instance.call("set_scene_preview_active", true, _build_preview_context())
		_subject_preview_active = true

func _deactivate_subject_preview() -> void:
	if not _subject_preview_active:
		return
	if _subject_instance != null and is_instance_valid(_subject_instance) and _subject_instance.has_method("set_scene_preview_active"):
		_subject_instance.call("set_scene_preview_active", false, _build_preview_context())
	_subject_preview_active = false

func _build_preview_context() -> Dictionary:
	return {
		"harness": self,
		"preview_camera": _preview_camera,
		"follow_target": _follow_target,
		"subject_scene_path": _resolved_subject_scene_path,
	}

func _sync_follow_anchor() -> void:
	if _preview_camera_rig == null:
		return
	var anchor_world_position := Vector3.ZERO
	if _follow_target != null and is_instance_valid(_follow_target):
		anchor_world_position = _follow_target.global_position
	_preview_camera_rig.global_position = anchor_world_position

func _update_camera_movement(delta: float) -> void:
	if _preview_camera == null:
		return
	var move_direction := Vector3.ZERO
	var camera_basis := _preview_camera.transform.basis
	if _move_forward:
		move_direction += -camera_basis.z
	if _move_backward:
		move_direction += camera_basis.z
	if _move_left:
		move_direction += -camera_basis.x
	if _move_right:
		move_direction += camera_basis.x
	if _move_up:
		move_direction += Vector3.UP
	if _move_down:
		move_direction += Vector3.DOWN
	if move_direction.length_squared() <= 0.0001:
		return
	var speed_mps := PREVIEW_CAMERA_MOVE_SPEED_MPS * (PREVIEW_CAMERA_SPRINT_MULTIPLIER if _move_fast else 1.0)
	_camera_local_position += move_direction.normalized() * speed_mps * maxf(delta, 0.0)
	_apply_camera_transform()

func _update_overlay_state(delta: float = 0.0) -> void:
	_last_frame_time_ms = maxf(delta, 0.0) * 1000.0
	_last_fps_sample = float(Engine.get_frames_per_second())
	if _fps_label != null:
		_fps_label.text = "FPS %.1f" % _last_fps_sample
		_fps_label.modulate = _resolve_fps_label_color(_last_fps_sample)
	if _frame_time_label != null:
		_frame_time_label.text = "Frame %.2f ms" % _last_frame_time_ms
		_frame_time_label.modulate = _resolve_frame_time_label_color(_last_frame_time_ms)

func _apply_overlay_visibility() -> void:
	var visible := stats_overlay_visible
	if _fps_label != null:
		_fps_label.visible = visible
	if _frame_time_label != null:
		_frame_time_label.visible = visible

func _resolve_fps_label_color(fps: float) -> Color:
	if fps < FPS_RED_THRESHOLD:
		return Color(0.94, 0.3, 0.3, 1.0)
	if fps <= FPS_YELLOW_THRESHOLD:
		return Color(0.95, 0.82, 0.28, 1.0)
	return Color(0.4, 0.92, 0.5, 1.0)

func _resolve_frame_time_label_color(frame_time_ms: float) -> Color:
	if frame_time_ms > FRAME_TIME_WARN_MS:
		return Color(0.94, 0.3, 0.3, 1.0)
	if frame_time_ms > FRAME_TIME_GOOD_MS:
		return Color(0.95, 0.82, 0.28, 1.0)
	return Color(0.72, 0.92, 1.0, 1.0)

func _apply_preview_look_delta(relative: Vector2) -> void:
	_camera_yaw_rad -= relative.x * PREVIEW_CAMERA_LOOK_SENSITIVITY
	_camera_pitch_rad = clampf(
		_camera_pitch_rad - relative.y * PREVIEW_CAMERA_LOOK_SENSITIVITY,
		PREVIEW_CAMERA_PITCH_MIN_RAD,
		PREVIEW_CAMERA_PITCH_MAX_RAD
	)
	_apply_camera_transform()

func _apply_camera_look_at_local_point(local_focus_position: Vector3) -> void:
	var forward := (local_focus_position - _camera_local_position).normalized()
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	_camera_pitch_rad = clampf(
		asin(clampf(forward.y, -1.0, 1.0)),
		PREVIEW_CAMERA_PITCH_MIN_RAD,
		PREVIEW_CAMERA_PITCH_MAX_RAD
	)
	_camera_yaw_rad = atan2(forward.x, -forward.z)
	_apply_camera_transform()

func _apply_camera_transform() -> void:
	if _preview_camera == null:
		return
	var basis := Basis.IDENTITY
	basis = basis.rotated(Vector3.UP, _camera_yaw_rad)
	basis = basis.rotated(Vector3.RIGHT, _camera_pitch_rad)
	_preview_camera.transform = Transform3D(basis.orthonormalized(), _camera_local_position)

func _update_preview_key_state(key_event: InputEventKey) -> void:
	if key_event.echo:
		return
	var keycode := _resolve_event_keycode(key_event)
	var pressed := key_event.pressed
	match keycode:
		KEY_W:
			_move_forward = pressed
		KEY_S:
			_move_backward = pressed
		KEY_A:
			_move_left = pressed
		KEY_D:
			_move_right = pressed
		KEY_E:
			_move_up = pressed
		KEY_Q:
			_move_down = pressed
		KEY_SHIFT:
			_move_fast = pressed

func _resolve_event_keycode(key_event: InputEventKey) -> Key:
	return key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode

func _capture_mouse() -> void:
	if _preview_mouse_captured:
		return
	_previous_mouse_mode = Input.mouse_mode
	_preview_mouse_captured = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _toggle_mouse_capture() -> void:
	if _preview_mouse_captured:
		_release_mouse(false)
	else:
		_capture_mouse()

func _release_mouse(restore_previous: bool = true) -> void:
	_preview_mouse_captured = false
	Input.set_mouse_mode(_previous_mouse_mode if restore_previous else Input.MOUSE_MODE_VISIBLE)

func _restore_mouse_mode() -> void:
	_preview_mouse_captured = false
	Input.set_mouse_mode(_previous_mouse_mode)
