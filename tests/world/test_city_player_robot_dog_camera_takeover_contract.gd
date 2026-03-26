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

	var baseline_player_position := (player as Node3D).global_position
	_press_world_key(world, KEY_KP_4)
	await _settle_frames(3)

	var runtime := world.get_active_player_robot_dog() as Node3D
	if not T.require_true(self, runtime != null, "Robot dog camera takeover contract requires an active robot dog runtime after pressing KP_4"):
		return
	var runtime_camera := runtime.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, runtime_camera != null, "Robot dog camera takeover contract requires a dedicated robot dog third-person camera"):
		return

	var active_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Robot dog camera takeover contract requires the system to settle into active state after pressing KP_4"):
		return
	if not T.require_true(self, str(active_state.get("control_owner", "")) == "robot_dog", "Active robot dog control must transfer control_owner to robot_dog instead of leaving it on the player"):
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

	_press_world_key(world, KEY_W)
	await _settle_frames(5)
	if not T.require_true(self, (player as Node3D).global_position.distance_to(baseline_player_position) <= 0.01, "Active robot dog control must keep the player body frozen in place instead of letting W move the player"):
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

func _settle_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
