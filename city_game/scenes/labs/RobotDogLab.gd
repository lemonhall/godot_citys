extends Node3D

const RESET_KEY := KEY_F5
const PRONE_TOGGLE_KEY := KEY_P

@export var lab_title := "v60 robot dog lab"
@export var lab_hint := "P Prone or Stand  F5 Reset"

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $Hud
@onready var robot_dog: Node3D = $RobotDogRoot

var _initial_player_position := Vector3.ZERO
var _initial_player_rotation := Vector3.ZERO
var _initial_camera_rig_rotation := Vector3.ZERO

func _ready() -> void:
	_capture_initial_state()
	_refresh_hud()

func _process(delta: float) -> void:
	if robot_dog != null and robot_dog.has_method("tick_robot_dog"):
		robot_dog.tick_robot_dog(delta)
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == RESET_KEY:
		reset_lab_state()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == PRONE_TOGGLE_KEY:
		if robot_dog != null and robot_dog.has_method("toggle_crouch_requested"):
			robot_dog.toggle_crouch_requested()
		get_viewport().set_input_as_handled()

func get_robot_dog() -> Node3D:
	return robot_dog

func get_robot_dog_debug_state() -> Dictionary:
	if robot_dog == null:
		return {}
	var combined_state := {}
	if robot_dog.has_method("get_debug_state"):
		combined_state = robot_dog.get_debug_state()
	if robot_dog.has_method("get_pose_debug_state"):
		combined_state.merge(robot_dog.get_pose_debug_state(), true)
	return combined_state.duplicate(true)

func step_robot_dog(delta: float, iterations: int) -> void:
	if robot_dog == null or not robot_dog.has_method("tick_robot_dog"):
		return
	for _index in range(maxi(iterations, 0)):
		robot_dog.tick_robot_dog(delta)

func reset_lab_state() -> void:
	_restore_player_state()
	if robot_dog != null and robot_dog.has_method("reset_robot_dog_pose"):
		robot_dog.reset_robot_dog_pose()
	_refresh_hud()

func _capture_initial_state() -> void:
	if player == null:
		return
	_initial_player_position = player.global_position
	_initial_player_rotation = player.rotation
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		_initial_camera_rig_rotation = camera_rig.rotation

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
