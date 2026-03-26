extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"
const ROBOT_DOG_RUNTIME_SCRIPT_PATH := "res://city_game/world/creatures/quadrupeds/CityRobotDogControlRuntime.gd"
const MAX_SPAWN_HEADING_DELTA_DEG := 8.0
const MIN_RIGHT_SLOT_ALIGNMENT := 0.68

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH)
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Player robot dog toggle contract requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_robot_dog_debug_state"), "Player robot dog toggle contract requires CityPrototype.get_player_robot_dog_debug_state()"):
		return
	if not T.require_true(self, world.has_method("get_active_player_robot_dog"), "Player robot dog toggle contract requires CityPrototype.get_active_player_robot_dog()"):
		return

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "Player robot dog toggle contract requires the main-world Player node"):
		return

	var initial_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(initial_state.get("system_state", "")) == "stowed", "Player robot dog system must boot in the stowed state"):
		return
	if not T.require_true(self, not bool(initial_state.get("active_robot_dog", true)), "Stowed robot dog system must report active_robot_dog=false"):
		return
	if not T.require_true(self, world.get_active_player_robot_dog() == null, "Before pressing KP_4, the main world must not already hold an active robot dog runtime"):
		return

	_press_world_key(world, KEY_4)
	await process_frame
	var main_keyboard_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(main_keyboard_state.get("system_state", "")) == "stowed", "Main keyboard 4 must not trigger the robot dog system; only numpad 4 is formal input"):
		return

	var player_spawn_position := player.global_position
	var player_forward := _planar_forward(player.global_transform.basis)
	var player_right := _planar_right(player.global_transform.basis)
	_press_world_key(world, KEY_KP_4)
	await _settle_frames(4)

	var active_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Pressing KP_4 from stowed must immediately enter the active robot dog runtime state"):
		return
	if not T.require_true(self, bool(active_state.get("active_robot_dog", false)), "Pressing KP_4 from stowed must report active_robot_dog=true"):
		return
	if not T.require_true(self, str(active_state.get("behavior_mode", "")) == "follow", "Pressing KP_4 from stowed must now summon the robot dog into follow mode instead of immediately stealing control"):
		return
	if not T.require_true(self, str(active_state.get("control_owner", "")) == "player", "Summoning the robot dog must leave control ownership on the player until Insert is pressed"):
		return
	if not T.require_true(self, str(active_state.get("camera_mode", "")) == "player", "Summoning the robot dog must keep the player camera current until Insert explicitly transfers control"):
		return
	if not T.require_true(self, not bool(active_state.get("player_frozen", true)), "Summoning the robot dog into follow mode must not freeze the player body"):
		return

	var runtime := world.get_active_player_robot_dog() as Node3D
	if not T.require_true(self, runtime != null, "KP_4 summon must instantiate the formal robot dog control runtime in the main world"):
		return
	var runtime_script := runtime.get_script() as Script
	if not T.require_true(self, runtime_script != null and str(runtime_script.resource_path) == ROBOT_DOG_RUNTIME_SCRIPT_PATH, "The mounted robot dog runtime must point at world/creatures/quadrupeds/CityRobotDogControlRuntime.gd"):
		return

	var spawn_delta := runtime.global_position - player_spawn_position
	var planar_distance_m := Vector2(spawn_delta.x, spawn_delta.z).length()
	if not T.require_true(self, planar_distance_m >= 1.0 and planar_distance_m <= 3.0, "Summoned robot dog must appear near the formal companion slot instead of underfoot or far away"):
		return
	var spawn_direction := Vector3(spawn_delta.x, 0.0, spawn_delta.z).normalized()
	if not T.require_true(self, player_forward.length_squared() > 0.0001 and player_right.length_squared() > 0.0001 and spawn_direction.length_squared() > 0.0001, "Robot dog summon must produce measurable planar forward/right vectors for the player and spawn direction"):
		return
	if not T.require_true(self, player_right.dot(spawn_direction) >= MIN_RIGHT_SLOT_ALIGNMENT, "Summoned robot dog must appear on the player's right-side companion slot instead of in front of the player"):
		return
	var runtime_forward := _planar_forward(runtime.global_transform.basis)
	if not T.require_true(self, rad_to_deg(acos(clampf(player_forward.dot(runtime_forward), -1.0, 1.0))) <= MAX_SPAWN_HEADING_DELTA_DEG, "Summoned robot dog must inherit the player's facing direction instead of spawning with a different heading"):
		return

	_press_world_key(world, KEY_KP_4)
	await _settle_frames(2)
	var recalled_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(recalled_state.get("system_state", "")) == "stowed", "Pressing KP_4 while active must retract the current robot dog runtime back to stowed"):
		return
	if not T.require_true(self, not bool(recalled_state.get("active_robot_dog", true)), "Retracting the robot dog must clear active_robot_dog instead of leaving the runtime half-mounted"):
		return
	if not T.require_true(self, world.get_active_player_robot_dog() == null, "Retracting the robot dog must clear CityPrototype.get_active_player_robot_dog()"):
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

func _planar_forward(basis: Basis) -> Vector3:
	var forward := -basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3.ZERO
	return forward.normalized()

func _planar_right(basis: Basis) -> Vector3:
	var right := basis.x
	right.y = 0.0
	if right.length_squared() <= 0.0001:
		return Vector3.ZERO
	return right.normalized()
