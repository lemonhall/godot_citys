extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH)
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Player robot dog flow requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_robot_dog_debug_state"), "Player robot dog flow requires CityPrototype.get_player_robot_dog_debug_state()"):
		return
	if not T.require_true(self, world.has_method("get_active_player_robot_dog"), "Player robot dog flow requires CityPrototype.get_active_player_robot_dog()"):
		return

	_press_world_key(world, KEY_KP_4)
	await _settle_frames(6)
	var runtime := world.get_active_player_robot_dog() as Node3D
	if not T.require_true(self, runtime != null, "Player robot dog flow must summon an active robot dog runtime after pressing KP_4"):
		return
	var walk_start_position := runtime.global_position
	var active_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Player robot dog flow must enter active system state after pressing KP_4"):
		return
	if not T.require_true(self, str(active_state.get("control_owner", "")) == "robot_dog", "Player robot dog flow must transfer control ownership to the robot dog after pressing KP_4"):
		return

	_press_world_key(world, KEY_W)
	await _settle_frames(18)
	var walk_state := world.get_player_robot_dog_debug_state() as Dictionary
	runtime = world.get_active_player_robot_dog() as Node3D
	if not T.require_true(self, str(walk_state.get("locomotion_state", "")) == "walk", "Holding W in the main world must drive the robot dog into walk locomotion state"):
		return
	if not T.require_true(self, runtime != null and runtime.global_position.distance_to(walk_start_position) >= 0.35, "Holding W in the main world must move the robot dog forward instead of only changing debug state text"):
		return

	_press_world_key(world, KEY_SHIFT)
	await _settle_frames(18)
	var run_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(run_state.get("locomotion_state", "")) == "run", "Holding Shift+W in the main world must promote the robot dog into run locomotion state"):
		return
	if not T.require_true(self, float(run_state.get("speed_mps", 0.0)) > float(walk_state.get("speed_mps", 0.0)), "Shift+W in the main world must increase robot dog speed above walk instead of staying at the same pace"):
		return

	_release_world_key(world, KEY_SHIFT)
	_release_world_key(world, KEY_W)
	_tap_world_key(world, KEY_P)
	await _settle_frames(64)
	var prone_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(prone_state.get("locomotion_state", "")) == "prone", "Pressing P while controlling the robot dog in the main world must enter prone locomotion state"):
		return

	_tap_world_key(world, KEY_P)
	await _settle_frames(64)
	var recovered_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(recovered_state.get("locomotion_state", "")) == "idle", "Pressing P again in the main world must return the robot dog from prone back to idle control state"):
		return

	_press_world_key(world, KEY_KP_4)
	await _settle_frames(6)
	var stowed_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(stowed_state.get("system_state", "")) == "stowed", "Pressing KP_4 again in the main world must retract the robot dog back to stowed"):
		return
	if not T.require_true(self, world.get_active_player_robot_dog() == null, "Retracting the robot dog in the main world must release the active runtime"):
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

func _tap_world_key(world: Node, keycode: Key) -> void:
	_press_world_key(world, keycode)
	_release_world_key(world, keycode)

func _settle_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
