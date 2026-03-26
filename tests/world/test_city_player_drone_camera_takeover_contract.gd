extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone camera takeover contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("request_primary_fire"), "Player drone camera takeover contract requires PlayerController request_primary_fire() support"):
		return
	if not T.require_true(self, player.has_method("request_ground_slam"), "Player drone camera takeover contract requires PlayerController request_ground_slam() support"):
		return
	if not T.require_true(self, player.has_method("is_control_enabled"), "Player drone camera takeover contract requires PlayerController.is_control_enabled()"):
		return
	if not T.require_true(self, player.has_method("is_movement_locked"), "Player drone camera takeover contract requires PlayerController.is_movement_locked()"):
		return
	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone camera takeover contract requires CityPrototype.get_player_drone_debug_state()"):
		return
	if not T.require_true(self, world.has_method("get_player_drone_squadron_debug_state"), "Player drone camera takeover contract requires CityPrototype.get_player_drone_squadron_debug_state()"):
		return

	var player_camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, player_camera != null, "Player drone camera takeover contract requires the player camera node"):
		return
	var runtime := world.get_node_or_null("PlayerDroneRuntime")
	if not T.require_true(self, runtime != null, "Player drone camera takeover contract requires a mounted PlayerDroneRuntime node"):
		return
	var drone_camera := runtime.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, drone_camera != null, "Player drone camera takeover contract requires a dedicated drone chase camera"):
		return

	var baseline_player_position: Vector3 = player.global_position
	_press_world_key(world, KEY_KP_5)
	await process_frame

	var deploying_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, str(deploying_state.get("system_state", "")) == "deploying", "Numpad 5 must place the drone system into deploying before any camera takeover happens"):
		return
	if not T.require_true(self, str(deploying_state.get("camera_owner", "")) == "player", "Deploying must keep camera ownership on the player until the deploy sequence completes"):
		return
	if not T.require_true(self, str(deploying_state.get("input_owner", "")) == "none", "Deploying must suspend gameplay input ownership instead of giving it to player or drone early"):
		return
	if not T.require_true(self, bool(deploying_state.get("player_locked", false)), "Deploying must report player_locked=true in the formal debug state"):
		return
	if not T.require_true(self, not bool(player.is_control_enabled()), "Deploying must disable player control until the drone is fully active"):
		return
	if not T.require_true(self, bool(player.is_movement_locked()), "Deploying must lock player movement immediately"):
		return
	if not T.require_true(self, player_camera.current and not drone_camera.current, "Deploying must keep the player camera current until the deploy transition finishes"):
		return
	if not T.require_true(self, player.global_position.distance_to(baseline_player_position) <= 0.01, "Deploying must keep the player frozen in place instead of dragging the body during lift-off"):
		return
	if not T.require_true(self, not player.request_primary_fire(), "Deploying must suppress rifle fire requests while the drone is taking off"):
		return
	if not T.require_true(self, not player.request_ground_slam(), "Deploying must suppress traversal attack requests while the drone is taking off"):
		return

	var active_state := await _wait_for_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Player drone camera takeover contract requires deploy to finish and enter active flight"):
		return
	if not T.require_true(self, str(active_state.get("camera_owner", "")) == "drone", "Active drone flight must formally transfer camera ownership to the drone chase camera"):
		return
	if not T.require_true(self, str(active_state.get("input_owner", "")) == "drone", "Active drone flight must formally transfer input ownership to the drone runtime"):
		return
	if not T.require_true(self, player.global_position.distance_to(baseline_player_position) <= 0.01, "Active drone flight must keep the player body frozen at the deployment anchor"):
		return
	if not T.require_true(self, not player_camera.current and drone_camera.current, "Active drone flight must make the drone chase camera current and release the player camera"):
		return
	if not T.require_true(self, not player.request_primary_fire(), "Active drone flight must keep the player weapon chain disabled while the drone owns input"):
		return
	if not T.require_true(self, not player.request_ground_slam(), "Active drone flight must keep the player traversal chain disabled while the drone owns input"):
		return

	await _hold_world_key(world, KEY_KP_5, 40)
	await process_frame
	var recovering_state: Dictionary = world.get_player_drone_debug_state()
	var recovering_squadron_state: Dictionary = world.get_player_drone_squadron_debug_state()
	if not T.require_true(self, str(recovering_state.get("system_state", "")) == "recovering", "Pressing numpad 5 while active must enter recovering instead of snapping directly back to stowed"):
		return
	if not T.require_true(self, str(recovering_state.get("camera_owner", "")) == "drone", "Recovering must keep the drone camera live until the return sequence completes"):
		return
	if not T.require_true(self, str(recovering_state.get("input_owner", "")) == "none", "Recovering must suspend input rather than handing it back to the player early"):
		return
	if not T.require_true(self, int(recovering_squadron_state.get("desired_total_count", -1)) == 0, "Long-hold recall must drop the squadron desired_total_count back to zero before the recover sequence finishes"):
		return
	if not T.require_true(self, not player.request_primary_fire(), "Recovering must continue suppressing player weapon input until the return sequence is fully complete"):
		return

	var stowed_state := await _wait_for_state(world, "stowed", 180)
	if not T.require_true(self, str(stowed_state.get("camera_owner", "")) == "player", "Recover completion must restore camera ownership to the player"):
		return
	if not T.require_true(self, str(stowed_state.get("input_owner", "")) == "player", "Recover completion must restore input ownership to the player"):
		return
	if not T.require_true(self, not bool(stowed_state.get("player_locked", true)), "Recover completion must clear the player lock flag"):
		return
	if not T.require_true(self, bool(player.is_control_enabled()) and not bool(player.is_movement_locked()), "Recover completion must restore player control and movement"):
		return
	if not T.require_true(self, player_camera.current and not drone_camera.current, "Recover completion must return the current camera to the player rig"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_state(world: Node, expected_state: String, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var debug_state: Dictionary = world.get_player_drone_debug_state()
		if str(debug_state.get("system_state", "")) == expected_state:
			return debug_state
	return world.get_player_drone_debug_state()

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

func _hold_world_key(world: Node, keycode: Key, frame_count: int) -> void:
	_press_world_key(world, keycode)
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
	_release_world_key(world, keycode)
