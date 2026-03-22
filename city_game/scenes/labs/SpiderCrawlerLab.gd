extends Node3D

const DEMO_MOTION_SPEED_MPS := 6.0
const DEMO_STOP_DISTANCE_M := 2.8
const DEMO_TOGGLE_KEY := KEY_SPACE
const RESET_KEY := KEY_F5

@onready var player := $Player
@onready var hud := $Hud
@onready var spider_crawler := $CrawlerRoot

var _initial_player_position := Vector3.ZERO
var _initial_player_rotation := Vector3.ZERO
var _initial_camera_rig_rotation := Vector3.ZERO
var _demo_motion_active := false

func _ready() -> void:
	_capture_initial_state()
	if spider_crawler != null and spider_crawler.has_method("set_auto_step_enabled"):
		spider_crawler.set_auto_step_enabled(false)
	if _is_rendered_demo_session():
		start_demo_motion()
	_refresh_hud()

func _process(_delta: float) -> void:
	if _demo_motion_active:
		_update_demo_motion_velocity()
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == RESET_KEY:
		reset_lab_state()
		if _is_rendered_demo_session():
			start_demo_motion()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == DEMO_TOGGLE_KEY:
		toggle_demo_motion()
		get_viewport().set_input_as_handled()

func get_spider_crawler() -> Node3D:
	return spider_crawler

func get_crawler_debug_state() -> Dictionary:
	if spider_crawler == null or not spider_crawler.has_method("get_debug_state"):
		return {}
	return spider_crawler.get_debug_state()

func step_spider(delta: float = 0.16, steps: int = 1) -> void:
	if spider_crawler == null or not spider_crawler.has_method("tick_crawler"):
		return
	for _step_index in range(maxi(steps, 1)):
		spider_crawler.tick_crawler(delta)
	_refresh_hud()

func set_spider_motion_velocity(velocity: Vector3) -> void:
	if spider_crawler != null and spider_crawler.has_method("set_debug_motion_velocity"):
		spider_crawler.set_debug_motion_velocity(velocity)

func set_spider_auto_step_enabled(enabled: bool) -> void:
	if spider_crawler != null and spider_crawler.has_method("set_auto_step_enabled"):
		spider_crawler.set_auto_step_enabled(enabled)

func teleport_spider_to_world_position(world_position: Vector3) -> void:
	if spider_crawler != null and spider_crawler.has_method("teleport_body_to_world_position"):
		spider_crawler.teleport_body_to_world_position(world_position)
	_refresh_hud()

func force_spider_replan() -> void:
	if spider_crawler != null and spider_crawler.has_method("debug_force_replan_all_legs"):
		spider_crawler.debug_force_replan_all_legs()
	_refresh_hud()

func reset_lab_state() -> void:
	_restore_player_state()
	if spider_crawler != null and spider_crawler.has_method("reset_crawler_state"):
		spider_crawler.reset_crawler_state()
	_refresh_hud()

func start_demo_motion() -> void:
	_demo_motion_active = true
	_update_demo_motion_velocity()
	set_spider_auto_step_enabled(true)
	_refresh_hud()

func pause_demo_motion() -> void:
	_demo_motion_active = false
	set_spider_auto_step_enabled(false)
	set_spider_motion_velocity(Vector3.ZERO)
	_refresh_hud()

func toggle_demo_motion() -> void:
	var spider_state: Dictionary = get_crawler_debug_state()
	if bool(spider_state.get("auto_step_enabled", false)):
		pause_demo_motion()
	else:
		start_demo_motion()

func _refresh_hud() -> void:
	if hud == null:
		return
	if hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(true)
	if hud.has_method("set_fps_overlay_sample"):
		hud.set_fps_overlay_sample(Engine.get_frames_per_second())
	if hud.has_method("set_status"):
		var spider_state: Dictionary = get_crawler_debug_state()
		hud.set_status(
			"v39 spider crawler lab\nSpider follows player  Space Pause/Run  F5 Reset\nlegs=%d  gait=%s  failures=%d  body_y=%.2f" % [
				int(spider_state.get("leg_count", 0)),
				str(spider_state.get("gait_profile_id", "")),
				int(spider_state.get("failed_replan_count", 0)),
				float((spider_state.get("body_visual_world_position", Vector3.ZERO) as Vector3).y),
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

func _is_rendered_demo_session() -> bool:
	return DisplayServer.get_name() != "headless"

func _update_demo_motion_velocity() -> void:
	if spider_crawler == null or player == null:
		return
	var to_player: Vector3 = player.global_position - spider_crawler.global_position
	to_player.y = 0.0
	if to_player.length() <= DEMO_STOP_DISTANCE_M:
		set_spider_motion_velocity(Vector3.ZERO)
		return
	var planar_direction: Vector3 = to_player.normalized()
	set_spider_motion_velocity(planar_direction * DEMO_MOTION_SPEED_MPS)
	spider_crawler.look_at(spider_crawler.global_position + planar_direction, Vector3.UP)
