extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/M777HowitzerLab.tscn"
const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)
const RETENTION_OFFSET := Vector3(0.0, 0.0, 12.0)
const RELEASE_OFFSET := Vector3(0.0, 0.0, 22.0)
const SHORT_TEST_COOLDOWN_SEC := 0.25

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 lab fire interaction contract requires the formal lab PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	if not T.require_true(self, lab != null, "M777 lab fire interaction contract requires the formal lab to instantiate"):
		return

	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player") as CharacterBody3D
	var howitzer := lab.get_node_or_null("ArtilleryRoot/Howitzer") as Node3D
	var hud := lab.get_node_or_null("Hud")
	var fire_audio := lab.get_node_or_null("ArtilleryRoot/Howitzer/ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/FireAudio") as AudioStreamPlayer3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "M777 lab fire interaction contract requires the formal lab player teleport API"):
		return
	if not T.require_true(self, howitzer != null and howitzer.has_method("get_fire_state"), "M777 lab fire interaction contract requires the formal howitzer fire API in the lab hierarchy"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_interaction_prompt_state"), "M777 lab fire interaction contract requires the shared HUD prompt state for prompt verification"):
		return

	howitzer.set("fire_cooldown_sec", SHORT_TEST_COOLDOWN_SEC)

	var initial_lab_state := lab.get_lab_state() as Dictionary
	var initial_fire_state := initial_lab_state.get("fire_state", {}) as Dictionary
	var initial_fire_count := int(initial_fire_state.get("fire_count", 0))
	_press_key(lab, KEY_SPACE)
	await _settle_frames()
	var blocked_outside_state := lab.get_lab_state() as Dictionary
	if not T.require_true(self, int((blocked_outside_state.get("fire_state", {}) as Dictionary).get("fire_count", 0)) == initial_fire_count, "Outside operation mode, Space must not trigger howitzer fire"):
		return

	var anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var interaction_anchor := anchor.global_position if anchor != null else howitzer.global_position
	player.teleport_to_world_position(interaction_anchor + APPROACH_OFFSET)
	await _settle_frames()

	_press_key(lab, KEY_E)
	await _settle_frames()

	var prompt_state := hud.get_interaction_prompt_state() as Dictionary
	if not T.require_true(self, str(prompt_state.get("prompt_text", "")).find("Space") >= 0, "Entering operation mode must teach the player that Space fires the howitzer"):
		return
	if not T.require_true(self, player.has_method("get_traversal_state") and player.has_method("get_mobility_tuning"), "M777 lab fire interaction contract requires PlayerController traversal introspection so fire input can be proven not to leak into jump"):
		return
	await _advance_frames(4)
	if not T.require_true(self, player.is_on_floor(), "Before validating Space fire ownership, the lab player must be settled on the ground"):
		return

	var player_y_before := player.global_position.y
	var jump_velocity := float((player.get_mobility_tuning() as Dictionary).get("jump_velocity", 0.0))
	_press_live_key(lab, KEY_SPACE)
	await _advance_frames(10)
	var held_traversal_state := player.get_traversal_state() as Dictionary
	if not T.require_true(self, float(held_traversal_state.get("vertical_speed", 0.0)) < jump_velocity * 0.25, "Inside operation mode, even while Space is still held down for the fire press, PlayerController must not recover jump ownership and launch the lab capsule upward"):
		return
	_release_live_key(KEY_SPACE)
	await _settle_frames()

	var firing_lab_state := lab.get_lab_state() as Dictionary
	var firing_fire_state := firing_lab_state.get("fire_state", {}) as Dictionary
	if not T.require_true(self, int(firing_fire_state.get("fire_count", 0)) == initial_fire_count + 1, "Inside operation mode, Space must trigger formal howitzer fire exactly once"):
		return
	var traversal_state := player.get_traversal_state() as Dictionary
	if not T.require_true(self, float(traversal_state.get("vertical_speed", 0.0)) < jump_velocity * 0.25, "Inside operation mode, Space must not leak into PlayerController jump input and launch the lab capsule upward"):
		return
	if not T.require_true(self, player.global_position.y <= player_y_before + 0.2, "Inside operation mode, firing with Space must keep the player grounded instead of adding a visible hop on the same button press"):
		return
	if not T.require_true(self, not bool(firing_fire_state.get("can_fire", true)), "Accepted lab fire must drive the mounted howitzer into cooldown"):
		return
	if not T.require_true(self, str(firing_lab_state.get("hud_status_text", "")).find("装填中") >= 0, "While the howitzer is cooling down, the lab HUD must explicitly show 装填中 X.Xs... instead of leaving the player guessing"):
		return

	_press_key(lab, KEY_SPACE)
	await _settle_frames()
	var blocked_cooldown_state := lab.get_lab_state() as Dictionary
	if not T.require_true(self, int((blocked_cooldown_state.get("fire_state", {}) as Dictionary).get("fire_count", 0)) == initial_fire_count + 1, "Pressing Space again during cooldown must not replay the howitzer shot"):
		return

	player.teleport_to_world_position(interaction_anchor + RETENTION_OFFSET)
	await _settle_frames()
	if not T.require_true(self, bool((lab.get_operation_state() as Dictionary).get("active", false)), "The player must retain artillery ownership while staying inside the 20m retention radius"):
		return

	await _advance_frames(40)

	var ready_lab_state := lab.get_lab_state() as Dictionary
	if not T.require_true(self, str(ready_lab_state.get("hud_status_text", "")).find("可击发") >= 0, "When cooldown completes, the lab HUD must explicitly switch to 可击发"):
		return

	_press_key(lab, KEY_SPACE)
	await _settle_frames()
	var retained_fire_state := (lab.get_lab_state() as Dictionary).get("fire_state", {}) as Dictionary
	if not T.require_true(self, int(retained_fire_state.get("fire_count", 0)) == initial_fire_count + 2, "Inside the wider retention radius, Space must still fire the howitzer after cooldown recovery"):
		return

	player.teleport_to_world_position(interaction_anchor + RELEASE_OFFSET)
	await _settle_frames()
	if not T.require_true(self, not bool((lab.get_operation_state() as Dictionary).get("active", false)), "Leaving roughly 20m away from the howitzer must automatically release operation mode before Space can fire again"):
		return

	_press_key(lab, KEY_SPACE)
	await _settle_frames()
	var released_fire_state := (lab.get_lab_state() as Dictionary).get("fire_state", {}) as Dictionary
	if not T.require_true(self, int(released_fire_state.get("fire_count", 0)) == initial_fire_count + 2, "After auto-release, Space must stop firing the howitzer until the player re-enters operation mode"):
		return

	await _wait_for_audio_to_stop(fire_audio)
	lab.queue_free()
	await _advance_frames(8)
	T.pass_and_quit(self)

func _press_key(target: Node, keycode: Key) -> void:
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	target._unhandled_input(key_event)

func _press_live_key(target: Node, keycode: Key) -> void:
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	Input.parse_input_event(key_event)
	target._unhandled_input(key_event)

func _release_live_key(keycode: Key) -> void:
	var key_event := InputEventKey.new()
	key_event.pressed = false
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	Input.parse_input_event(key_event)

func _advance_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _settle_frames(frame_count: int = 4) -> void:
	for _frame_index in range(frame_count):
		await process_frame

func _wait_for_audio_to_stop(audio_player: AudioStreamPlayer3D, max_frames: int = 180) -> void:
	if audio_player == null:
		return
	for _frame_index in range(max_frames):
		if not audio_player.playing:
			return
		await process_frame
		await physics_frame
