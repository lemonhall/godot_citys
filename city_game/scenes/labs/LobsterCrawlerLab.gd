extends Node3D

@onready var player: Node3D = $Player
@onready var hud := $Hud
@onready var lobster_crawler: Node3D = $LobsterRoot

var _initial_player_position := Vector3.ZERO
var _initial_player_rotation := Vector3.ZERO
var _initial_camera_rig_rotation := Vector3.ZERO

func _ready() -> void:
	_capture_initial_state()
	if lobster_crawler != null and lobster_crawler.has_method("set_auto_step_enabled"):
		lobster_crawler.set_auto_step_enabled(false)
	_refresh_hud()

func _process(_delta: float) -> void:
	_refresh_hud()

func get_lobster_crawler() -> Node3D:
	return lobster_crawler

func get_crawler_debug_state() -> Dictionary:
	if lobster_crawler == null or not lobster_crawler.has_method("get_debug_state"):
		return {}
	return lobster_crawler.get_debug_state()

func step_lobster(delta: float = 0.16, steps: int = 1) -> void:
	if lobster_crawler == null or not lobster_crawler.has_method("tick_crawler"):
		return
	for _step_index in range(maxi(steps, 1)):
		lobster_crawler.tick_crawler(delta)
	_refresh_hud()

func set_lobster_motion_velocity(velocity: Vector3) -> void:
	if lobster_crawler != null and lobster_crawler.has_method("set_debug_motion_velocity"):
		lobster_crawler.set_debug_motion_velocity(velocity)

func set_lobster_auto_step_enabled(enabled: bool) -> void:
	if lobster_crawler != null and lobster_crawler.has_method("set_auto_step_enabled"):
		lobster_crawler.set_auto_step_enabled(enabled)

func teleport_lobster_to_world_position(world_position: Vector3) -> void:
	if lobster_crawler != null and lobster_crawler.has_method("teleport_body_to_world_position"):
		lobster_crawler.teleport_body_to_world_position(world_position)
	_refresh_hud()

func force_lobster_replan() -> void:
	if lobster_crawler != null and lobster_crawler.has_method("debug_force_replan_all_legs"):
		lobster_crawler.debug_force_replan_all_legs()
	_refresh_hud()

func reset_lab_state() -> void:
	_restore_player_state()
	if lobster_crawler != null and lobster_crawler.has_method("reset_crawler_state"):
		lobster_crawler.reset_crawler_state()
	_refresh_hud()

func _refresh_hud() -> void:
	if hud == null:
		return
	if hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(true)
	if hud.has_method("set_fps_overlay_sample"):
		hud.set_fps_overlay_sample(Engine.get_frames_per_second())
	if hud.has_method("set_status"):
		var lobster_state: Dictionary = get_crawler_debug_state()
		hud.set_status(
			"v39 lobster crawler lab\nF5 Reset  Shared arthropod spine metachronal probe\nlegs=%d  gait=%s  failures=%d  body_y=%.2f" % [
				int(lobster_state.get("leg_count", 0)),
				str(lobster_state.get("gait_profile_id", "")),
				int(lobster_state.get("failed_replan_count", 0)),
				float((lobster_state.get("body_visual_world_position", Vector3.ZERO) as Vector3).y),
			]
		)

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
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.rotation = _initial_camera_rig_rotation
	if player.has_method("set_aim_down_sights_active"):
		player.set_aim_down_sights_active(false)
