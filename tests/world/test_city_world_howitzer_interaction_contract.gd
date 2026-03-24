extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"
const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)
const RETENTION_OFFSET := Vector3(0.0, 0.0, 12.0)
const RELEASE_OFFSET := Vector3(0.0, 0.0, 22.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH)
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "World howitzer interaction contract requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_active_world_howitzer"), "World howitzer interaction contract requires get_active_world_howitzer()"):
		return
	if not T.require_true(self, world.has_method("get_world_howitzer_operation_state"), "World howitzer interaction contract requires get_world_howitzer_operation_state()"):
		return

	var player := world.get_node_or_null("Player") as CharacterBody3D
	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "World howitzer interaction contract requires a teleportable PlayerController"):
		return
	if not T.require_true(self, player.has_method("get_traversal_state") and player.has_method("get_mobility_tuning"), "World howitzer interaction contract requires PlayerController traversal introspection so Space ownership can be verified"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_interaction_prompt_state") and hud.has_method("get_artillery_solution_state"), "World howitzer interaction contract requires the shared HUD prompt and artillery solution consumers"):
		return

	world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("get_fire_state"), "World howitzer interaction contract requires the summoned formal howitzer runtime"):
		return
	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.teleport_to_world_position(anchor_world + APPROACH_OFFSET)
	await _settle_frames()

	var prompt_state := hud.get_interaction_prompt_state() as Dictionary
	if not T.require_true(self, str(prompt_state.get("prompt_text", "")).find("按 E 操作炮") >= 0, "Approaching the summoned howitzer in the main world must surface the shared 按 E 操作炮 prompt"):
		return

	_press_key(world, KEY_E)
	await _settle_frames()

	var operation_state := world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state.get("active", false)), "Pressing E near the summoned howitzer must enter operation mode in the main world"):
		return
	prompt_state = hud.get_interaction_prompt_state() as Dictionary
	if not T.require_true(self, str(prompt_state.get("prompt_text", "")).find("J/L") >= 0 and str(prompt_state.get("prompt_text", "")).find("Space") >= 0, "Main-world operation mode must expose the same J/L I/K Space control hint contract as the lab"):
		return
	var artillery_solution_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, bool(artillery_solution_state.get("visible", false)), "Entering world howitzer operation mode must show the shared artillery solution HUD"):
		return

	var yaw_before := float(howitzer.get_yaw_degrees())
	var pitch_before := float(howitzer.get_pitch_degrees())
	_press_live_key(KEY_L)
	await _settle_frames(8)
	_release_live_key(KEY_L)
	_press_live_key(KEY_I)
	await _settle_frames(8)
	_release_live_key(KEY_I)
	await _settle_frames()

	if not T.require_true(self, float(howitzer.get_yaw_degrees()) > yaw_before + 0.1, "While operating the main-world howitzer, holding L must rotate yaw through the shared controller instead of doing nothing"):
		return
	if not T.require_true(self, float(howitzer.get_pitch_degrees()) > pitch_before + 0.1, "While operating the main-world howitzer, holding I must raise pitch through the shared controller instead of doing nothing"):
		return

	var fire_count_before := int((howitzer.get_fire_state() as Dictionary).get("fire_count", 0))
	var jump_velocity := float((player.get_mobility_tuning() as Dictionary).get("jump_velocity", 0.0))
	var player_y_before := player.global_position.y
	var space_event := _build_key_event(KEY_SPACE, true)
	Input.parse_input_event(space_event)
	world._unhandled_input(space_event)
	await _settle_frames(10)
	var traversal_state := player.get_traversal_state() as Dictionary
	if not T.require_true(self, float(traversal_state.get("vertical_speed", 0.0)) < jump_velocity * 0.25, "Inside world howitzer operation mode, Space must not leak into player jump ownership"):
		return
	_release_live_key(KEY_SPACE)
	await _settle_frames()

	var fire_state := howitzer.get_fire_state() as Dictionary
	if not T.require_true(self, int(fire_state.get("fire_count", 0)) == fire_count_before + 1, "Inside world howitzer operation mode, pressing Space must trigger exactly one formal howitzer shot"):
		return
	if not T.require_true(self, player.global_position.y <= player_y_before + 0.2, "Inside world howitzer operation mode, firing with Space must keep the player grounded instead of adding a visible hop"):
		return

	player.teleport_to_world_position(anchor_world + RETENTION_OFFSET)
	await _settle_frames()
	operation_state = world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state.get("active", false)), "The main-world howitzer must retain ownership while the player stays inside the 20m retention radius"):
		return

	player.teleport_to_world_position(anchor_world + RELEASE_OFFSET)
	await _settle_frames()
	operation_state = world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, not bool(operation_state.get("active", false)), "Leaving roughly 20m away from the main-world howitzer must auto-release operation mode"):
		return
	artillery_solution_state = hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, not bool(artillery_solution_state.get("visible", false)), "After world howitzer auto-release, the shared artillery solution HUD must hide again"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _build_key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.pressed = pressed
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	return key_event

func _press_key(target: Node, keycode: Key) -> void:
	target._unhandled_input(_build_key_event(keycode, true))

func _press_live_key(keycode: Key) -> void:
	Input.parse_input_event(_build_key_event(keycode, true))

func _release_live_key(keycode: Key) -> void:
	Input.parse_input_event(_build_key_event(keycode, false))

func _settle_frames(frame_count: int = 6) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
