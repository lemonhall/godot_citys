extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"
const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH)
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "World howitzer e2e flow requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "World howitzer e2e flow requires the formal PlayerController in the main world"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_interaction_prompt_state") and hud.has_method("get_artillery_solution_state"), "World howitzer e2e flow requires the shared HUD consumers"):
		return
	if not T.require_true(self, world.has_method("get_active_world_howitzer") and world.has_method("get_last_artillery_shell_explosion_result"), "World howitzer e2e flow requires the new world howitzer API surface"):
		return

	world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("set_axis_angles_degrees"), "KP_8 must summon the formal howitzer runtime before the e2e flow can continue"):
		return

	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.teleport_to_world_position(anchor_world + APPROACH_OFFSET)
	await _settle_frames()

	var prompt_state := hud.get_interaction_prompt_state() as Dictionary
	if not T.require_true(self, str(prompt_state.get("prompt_text", "")).find("按 E 操作炮") >= 0, "After summoning the howitzer, approaching it in the main world must offer the shared operate prompt end to end"):
		return

	_press_key(world, KEY_E)
	await _settle_frames()

	var artillery_solution_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, bool(artillery_solution_state.get("visible", false)), "Entering main-world howitzer operation mode must reveal the shared artillery solution HUD end to end"):
		return

	howitzer.set_axis_angles_degrees(0.0, 0.0)
	await _settle_frames()

	var space_event := _build_key_event(KEY_SPACE, true)
	Input.parse_input_event(space_event)
	world._unhandled_input(space_event)
	await _settle_frames(8)
	_release_live_key(KEY_SPACE)

	var explosion_result := await _wait_for_shell_explosion(world, 240)
	if not T.require_true(self, not explosion_result.is_empty(), "The main-world howitzer e2e flow must reach a real shell impact result instead of stopping at muzzle-only presentation"):
		return
	if not T.require_true(self, explosion_result.get("firing_solution", null) is Dictionary, "The end-to-end howitzer flow must preserve the firing solution payload all the way through shell impact"):
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

func _release_live_key(keycode: Key) -> void:
	Input.parse_input_event(_build_key_event(keycode, false))

func _wait_for_shell_explosion(world: Node, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var result := world.get_last_artillery_shell_explosion_result() as Dictionary
		if not result.is_empty():
			return result
	return {}

func _settle_frames(frame_count: int = 6) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
