extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH)
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Player robot dog camera takeover contract requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("is_control_enabled"), "Player robot dog camera takeover contract requires PlayerController.is_control_enabled()"):
		return
	if not T.require_true(self, player.has_method("is_movement_locked"), "Player robot dog camera takeover contract requires PlayerController.is_movement_locked()"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "Player robot dog camera takeover contract requires PlayerController.request_primary_fire()"):
		return
	if not T.require_true(self, player.has_method("request_ground_slam"), "Player robot dog camera takeover contract requires PlayerController.request_ground_slam()"):
		return
	if not T.require_true(self, world.has_method("get_player_robot_dog_debug_state"), "Player robot dog camera takeover contract requires CityPrototype.get_player_robot_dog_debug_state()"):
		return
	if not T.require_true(self, world.has_method("get_active_player_robot_dog"), "Player robot dog camera takeover contract requires CityPrototype.get_active_player_robot_dog()"):
		return

	var player_camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, player_camera != null and player_camera.current, "Player robot dog camera takeover contract requires the player camera to boot current"):
		return

	var baseline_player_position := Vector3.ZERO
	_press_world_key(world, KEY_KP_4)
	await _settle_frames(3)

	var runtime := world.get_active_player_robot_dog() as Node3D
	if not T.require_true(self, runtime != null, "Robot dog camera takeover contract requires an active robot dog runtime after pressing KP_4"):
		return
	var runtime_camera := runtime.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var runtime_camera_rig := runtime.get_node_or_null("CameraRig") as Node3D
	if not T.require_true(self, runtime_camera != null, "Robot dog camera takeover contract requires a dedicated robot dog third-person camera"):
		return
	if not T.require_true(self, runtime_camera_rig != null, "Robot dog camera takeover contract requires the formal CameraRig pivot once mouse-look is added"):
		return

	var active_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Robot dog camera takeover contract requires the system to settle into active state after pressing KP_4"):
		return
	if not T.require_true(self, str(active_state.get("behavior_mode", "")) == "follow", "KP_4 summon must now boot the robot dog into follow mode before any explicit control takeover"):
		return
	if not T.require_true(self, str(active_state.get("control_owner", "")) == "player", "Summoning the robot dog must leave control_owner on the player until Insert is pressed"):
		return
	if not T.require_true(self, str(active_state.get("camera_mode", "")) == "player", "Summoning the robot dog must keep camera_mode=player until Insert is pressed"):
		return
	if not T.require_true(self, not bool(active_state.get("player_frozen", true)), "Follow-mode robot dog must not freeze the player body"):
		return
	if not T.require_true(self, player_camera.current and not runtime_camera.current, "Follow-mode robot dog must keep the player camera current instead of instantly taking over the view"):
		return
	if not T.require_true(self, bool(player.is_control_enabled()), "Follow-mode robot dog must leave player input enabled"):
		return
	if not T.require_true(self, not bool(player.is_movement_locked()), "Follow-mode robot dog must leave player movement unlocked"):
		return
	if not T.require_true(self, player.request_primary_fire(), "Follow-mode robot dog must still allow the player rifle fire request to go through"):
		return

	_press_world_key(world, KEY_INSERT)
	await _settle_frames(2)
	active_state = world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(active_state.get("behavior_mode", "")) == "controlled", "Pressing Insert while the robot dog is following must transfer it into controlled mode"):
		return
	if not T.require_true(self, str(active_state.get("control_owner", "")) == "robot_dog", "Controlled robot dog mode must transfer control_owner to robot_dog instead of leaving it on the player"):
		return
	if not T.require_true(self, str(active_state.get("camera_mode", "")) == "third_person", "Active robot dog control must expose camera_mode=third_person in the formal debug state"):
		return
	if not T.require_true(self, bool(active_state.get("player_frozen", false)), "Active robot dog control must report player_frozen=true once the player body is locked in place"):
		return
	if not T.require_true(self, runtime_camera.current and not player_camera.current, "Active robot dog control must make the robot dog chase camera current and release the player camera"):
		return
	if not T.require_true(self, not bool(player.is_control_enabled()), "Active robot dog control must disable player control while the dog owns input"):
		return
	if not T.require_true(self, bool(player.is_movement_locked()), "Active robot dog control must lock player movement while the dog owns input"):
		return
	if not T.require_true(self, not player.request_primary_fire(), "Active robot dog control must suppress player rifle fire requests while the dog owns input"):
		return
	if not T.require_true(self, not player.request_ground_slam(), "Active robot dog control must suppress player traversal attack requests while the dog owns input"):
		return

	baseline_player_position = (player as Node3D).global_position
	_press_world_key(world, KEY_W)
	await _settle_frames(5)
	if not T.require_true(self, (player as Node3D).global_position.distance_to(baseline_player_position) <= 0.01, "Active robot dog control must keep the player body frozen in place instead of letting W move the player"):
		return
	_release_world_key(world, KEY_W)

	var baseline_player_heading: float = player.rotation.y
	var baseline_compass_state := world.get_player_compass_state() as Dictionary
	var baseline_pitch_deg := rad_to_deg(runtime_camera_rig.rotation.x)
	_send_world_mouse_motion(world, 160.0, -120.0)
	await _settle_frames(2)
	runtime = world.get_active_player_robot_dog() as Node3D
	runtime_camera_rig = runtime.get_node_or_null("CameraRig") as Node3D
	if not T.require_true(self, runtime_camera_rig != null, "Robot dog camera takeover contract requires CameraRig to remain available after mouse-look input"):
		return
	var turned_compass_state := world.get_player_compass_state() as Dictionary
	var turned_bearing_deg := float(turned_compass_state.get("bearing_deg", 0.0))
	if not T.require_true(self, turned_bearing_deg >= float(baseline_compass_state.get("bearing_deg", 0.0)) + 5.0, "Moving the mouse right while controlling the robot dog must rotate the shared compass bearing clockwise instead of leaving world heading frozen on the player"):
		return
	if not T.require_true(self, absf(player.rotation.y - baseline_player_heading) <= 0.001, "Robot dog mouse-look must not secretly rotate the frozen player body just to move the compass"):
		return
	var lifted_pitch_deg := rad_to_deg(runtime_camera_rig.rotation.x)
	if not T.require_true(self, lifted_pitch_deg >= baseline_pitch_deg + 4.0, "Moving the mouse up while controlling the robot dog must raise the chase camera pitch instead of ignoring vertical look input"):
		return
	_send_world_mouse_motion(world, 0.0, 100000.0)
	await _settle_frames(2)
	var clamped_pitch_deg := rad_to_deg(runtime_camera_rig.rotation.x)
	if not T.require_true(self, clamped_pitch_deg >= -80.0 and clamped_pitch_deg <= 40.0, "Robot dog chase camera pitch must stay within a sane clamped range instead of flipping over on extreme mouse input"):
		return
	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var minimap_player_marker: Dictionary = minimap_snapshot.get("player_marker", {})
	if not T.require_true(self, absf(float(minimap_player_marker.get("bearing_deg", -999.0)) - turned_bearing_deg) <= 0.5, "Minimap player marker must follow the active robot dog heading instead of staying frozen on the player's locked body"):
		return

	_press_world_key(world, KEY_INSERT)
	await _settle_frames(2)
	var resumed_follow_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(resumed_follow_state.get("behavior_mode", "")) == "follow", "Pressing Insert again while controlling the robot dog must return it to follow mode"):
		return
	if not T.require_true(self, str(resumed_follow_state.get("control_owner", "")) == "player", "Leaving controlled mode must restore control_owner back to player"):
		return
	if not T.require_true(self, str(resumed_follow_state.get("camera_mode", "")) == "player", "Leaving controlled mode must restore camera_mode back to player"):
		return
	if not T.require_true(self, not bool(resumed_follow_state.get("player_frozen", true)), "Leaving controlled mode must clear player_frozen in the debug state"):
		return
	if not T.require_true(self, player_camera.current and runtime_camera != null and not runtime_camera.current, "Leaving controlled mode must restore the player camera while keeping the dog runtime mounted"):
		return
	if not T.require_true(self, bool(player.is_control_enabled()) and not bool(player.is_movement_locked()), "Leaving controlled mode must restore player control and movement ownership"):
		return

	_press_world_key(world, KEY_KP_4)
	await _settle_frames(2)
	var recalled_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(recalled_state.get("system_state", "")) == "stowed", "Pressing KP_4 while the dog is active must return the robot dog system to stowed"):
		return
	if not T.require_true(self, str(recalled_state.get("control_owner", "")) == "player", "Retracting the robot dog must restore control_owner back to player"):
		return
	if not T.require_true(self, str(recalled_state.get("camera_mode", "")) == "player", "Retracting the robot dog must restore camera_mode back to player"):
		return
	if not T.require_true(self, not bool(recalled_state.get("player_frozen", true)), "Retracting the robot dog must clear player_frozen in the debug state"):
		return
	if not T.require_true(self, player_camera.current and world.get_active_player_robot_dog() == null, "Retracting the robot dog must restore the player camera and release the active runtime"):
		return
	if not T.require_true(self, bool(player.is_control_enabled()) and not bool(player.is_movement_locked()), "Retracting the robot dog must restore player control and movement ownership"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _press_world_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)

func _release_world_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = false
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)

func _send_world_mouse_motion(world: Node, relative_x: float, relative_y: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(relative_x, relative_y)
	world._unhandled_input(event)

func _settle_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
