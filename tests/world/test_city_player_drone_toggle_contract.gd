extends SceneTree

const T := preload("res://tests/_test_util.gd")
const DRONE_RUNTIME_SCRIPT_PATH := "res://city_game/combat/drone/CityPlayerDroneRuntime.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone toggle contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone toggle contract requires CityPrototype.get_player_drone_debug_state()"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime")
	if not T.require_true(self, runtime != null, "Player drone toggle contract requires a mounted PlayerDroneRuntime node on CityPrototype"):
		return
	var runtime_script := runtime.get_script() as Script
	if not T.require_true(self, runtime_script != null and str(runtime_script.resource_path) == DRONE_RUNTIME_SCRIPT_PATH, "Player drone toggle contract requires the mounted runtime to point at combat/drone/CityPlayerDroneRuntime.gd"):
		return

	var initial_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, str(initial_state.get("system_state", "")) == "stowed", "Player drone system must boot in the stowed state"):
		return
	if not T.require_true(self, str(initial_state.get("camera_owner", "")) == "player", "Stowed drone system must leave the camera owned by the player"):
		return
	if not T.require_true(self, str(initial_state.get("input_owner", "")) == "player", "Stowed drone system must leave input owned by the player"):
		return

	_press_world_key(world, KEY_5)
	await process_frame
	var main_keyboard_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, str(main_keyboard_state.get("system_state", "")) == "stowed", "Main keyboard 5 must not trigger the player drone system; only numpad 5 is formal input"):
		return

	_press_world_key(world, KEY_KP_5)
	await process_frame
	var deploying_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, str(deploying_state.get("system_state", "")) == "deploying", "Pressing numpad 5 from stowed must enter the deploying state"):
		return
	if not T.require_true(self, bool(deploying_state.get("player_locked", false)), "Deploying must immediately lock the player controller"):
		return

	_press_world_key(world, KEY_KP_5)
	await process_frame
	var repeated_state: Dictionary = world.get_player_drone_debug_state()
	if not T.require_true(self, str(repeated_state.get("system_state", "")) == "deploying", "Repeated numpad 5 presses during deploy must be ignored instead of corrupting the transition state machine"):
		return
	if not T.require_true(self, float(repeated_state.get("transition_progress", 0.0)) >= float(deploying_state.get("transition_progress", 0.0)), "Ignored deploy-time toggle presses must not rewind transition progress"):
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
