extends Node3D

const RESET_KEY := KEY_F5

@export var lab_title := "v61 robot dog lab"
@export var lab_hint := "W/A/S/D Move  Shift Run  P Prone  F5 Reset"

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $Hud
@onready var robot_dog_runtime: Node3D = $RobotDogRoot

var _initial_player_position := Vector3.ZERO
var _initial_player_rotation := Vector3.ZERO
var _initial_camera_rig_rotation := Vector3.ZERO
var _initial_robot_dog_position := Vector3.ZERO
var _initial_robot_dog_heading_rad := 0.0

func _ready() -> void:
	_capture_initial_state()
	_activate_robot_dog_runtime()
	_refresh_hud()

func _process(delta: float) -> void:
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or key_event.echo:
		return
	if key_event.pressed and key_event.keycode == RESET_KEY:
		reset_lab_state()
		get_viewport().set_input_as_handled()
		return
	if robot_dog_runtime != null and robot_dog_runtime.has_method("handle_input_event") and bool(robot_dog_runtime.handle_input_event(event)):
		get_viewport().set_input_as_handled()

func get_robot_dog() -> Node3D:
	if robot_dog_runtime == null or not robot_dog_runtime.has_method("get_visual_robot_dog"):
		return null
	return robot_dog_runtime.get_visual_robot_dog()

func get_robot_dog_runtime() -> Node3D:
	return robot_dog_runtime

func get_robot_dog_debug_state() -> Dictionary:
	if robot_dog_runtime == null:
		return {}
	var combined_state := {}
	if robot_dog_runtime.has_method("get_debug_state"):
		combined_state = robot_dog_runtime.get_debug_state()
	var visual_robot_dog := get_robot_dog()
	if visual_robot_dog != null and visual_robot_dog.has_method("get_debug_state"):
		combined_state.merge(visual_robot_dog.get_debug_state(), true)
	if visual_robot_dog != null and visual_robot_dog.has_method("get_pose_debug_state"):
		combined_state.merge(visual_robot_dog.get_pose_debug_state(), true)
	return combined_state.duplicate(true)

func step_robot_dog(delta: float, iterations: int) -> void:
	var visual_robot_dog := get_robot_dog()
	if visual_robot_dog == null or not visual_robot_dog.has_method("tick_robot_dog"):
		return
	for _index in range(maxi(iterations, 0)):
		visual_robot_dog.tick_robot_dog(delta)

func reset_lab_state() -> void:
	_restore_player_state()
	if robot_dog_runtime != null and robot_dog_runtime.has_method("deactivate"):
		robot_dog_runtime.deactivate()
	_activate_robot_dog_runtime()
	_refresh_hud()

func _capture_initial_state() -> void:
	if player == null:
		return
	_initial_player_position = player.global_position
	_initial_player_rotation = player.rotation
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		_initial_camera_rig_rotation = camera_rig.rotation
	if robot_dog_runtime != null:
		_initial_robot_dog_position = robot_dog_runtime.global_position
		_initial_robot_dog_heading_rad = robot_dog_runtime.rotation.y

func _restore_player_state() -> void:
	if player == null:
		return
	player.global_position = _initial_player_position
	player.rotation = _initial_player_rotation
	player.velocity = Vector3.ZERO
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.rotation = _initial_camera_rig_rotation

func _refresh_hud() -> void:
	if hud == null:
		return
	if hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(true)
	if hud.has_method("set_fps_overlay_sample"):
		hud.set_fps_overlay_sample(Engine.get_frames_per_second())
	if not hud.has_method("set_status"):
		return
	var robot_dog_state := get_robot_dog_debug_state()
	var legs: Array = robot_dog_state.get("legs", [])
	var crouched_leg_count := 0
	for leg_variant in legs:
		if not (leg_variant is Dictionary):
			continue
		if bool((leg_variant as Dictionary).get("is_crouched", false)):
			crouched_leg_count += 1
	hud.set_status(
		"%s\n%s\nspecies=%s  pose=%s  crouch=%.2f  crouched_legs=%d" % [
			lab_title,
			lab_hint,
			str(robot_dog_state.get("species_id", "")),
			str(robot_dog_state.get("pose_state", "")),
			float(robot_dog_state.get("crouch_alpha", 0.0)),
			crouched_leg_count,
		]
	)

func _activate_robot_dog_runtime() -> void:
	if robot_dog_runtime == null:
		return
	if robot_dog_runtime.has_method("bind_player_owner"):
		robot_dog_runtime.bind_player_owner(player)
	if robot_dog_runtime.has_method("activate_at"):
		robot_dog_runtime.activate_at(_initial_robot_dog_position, _initial_robot_dog_heading_rad)
