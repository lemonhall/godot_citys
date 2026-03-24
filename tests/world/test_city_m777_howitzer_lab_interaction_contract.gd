extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/M777HowitzerLab.tscn"
const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)
const RETENTION_OFFSET := Vector3(0.0, 0.0, 12.0)
const RELEASE_OFFSET := Vector3(0.0, 0.0, 22.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 howitzer interaction contract requires a dedicated lab PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	if not T.require_true(self, lab != null, "M777 howitzer interaction contract requires the lab to instantiate as Node3D"):
		return

	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("request_primary_interaction"), "M777 howitzer lab must expose request_primary_interaction() so E ownership can be regression tested"):
		return
	if not T.require_true(self, lab.has_method("get_operation_state"), "M777 howitzer lab must expose get_operation_state() so操炮态 can be inspected directly"):
		return

	var player := lab.get_node_or_null("Player") as CharacterBody3D
	var howitzer := lab.get_node_or_null("ArtilleryRoot/Howitzer") as Node3D
	var hud := lab.get_node_or_null("Hud")
	var lanyard_line := lab.get_node_or_null("ArtilleryRoot/Howitzer/ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/LanyardLine") as Node3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "M777 howitzer interaction contract requires the formal lab player teleport API"):
		return
	if not T.require_true(self, howitzer != null, "M777 howitzer interaction contract requires the formal howitzer node in the lab hierarchy"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_interaction_prompt_state"), "M777 howitzer interaction contract requires HUD prompt introspection via the shared prompt contract"):
		return
	if not T.require_true(self, lanyard_line != null and lanyard_line.has_method("get_debug_state"), "M777 howitzer interaction contract requires a visible lanyard line debug surface so操炮态 can prove the pull-rope really links to the operator"):
		return

	var initial_prompt_state: Dictionary = hud.get_interaction_prompt_state()
	if not T.require_true(self, not bool(initial_prompt_state.get("visible", false)), "Spawned outside interaction radius, the howitzer prompt must stay hidden"):
		return

	var anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var interaction_anchor := anchor.global_position if anchor != null else howitzer.global_position
	player.teleport_to_world_position(interaction_anchor + APPROACH_OFFSET)
	await _settle_frames()

	var approach_prompt_state: Dictionary = hud.get_interaction_prompt_state()
	if not T.require_true(self, bool(approach_prompt_state.get("visible", false)), "Approaching within the frozen 5m radius must surface the E operation prompt"):
		return
	if not T.require_true(self, str(approach_prompt_state.get("prompt_text", "")).find("按 E") >= 0, "The howitzer prompt must explicitly teach the player to press E before artillery controls become active"):
		return

	var pre_operation_yaw_deg := float((lab.get_lab_state() as Dictionary).get("yaw_deg", 0.0))
	_set_key_pressed(KEY_L, true)
	await _advance_frames(12)
	_set_key_pressed(KEY_L, false)
	var blocked_yaw_deg := float((lab.get_lab_state() as Dictionary).get("yaw_deg", 0.0))
	if not T.require_true(self, absf(blocked_yaw_deg - pre_operation_yaw_deg) <= 0.01, "Before entering operation mode, J/L must not rotate the howitzer"):
		return

	_press_key(lab, KEY_E)
	await _settle_frames()

	var active_operation_state: Dictionary = lab.get_operation_state()
	if not T.require_true(self, bool(active_operation_state.get("active", false)), "Pressing E inside range must enter howitzer operation mode"):
		return
	var active_prompt_state: Dictionary = hud.get_interaction_prompt_state()
	if not T.require_true(self, bool(active_prompt_state.get("visible", false)), "After entering operation mode, the HUD must keep a visible artillery control prompt instead of leaving the player blind"):
		return
	if not T.require_true(self, str(active_prompt_state.get("prompt_text", "")).find("J/L") >= 0 and str(active_prompt_state.get("prompt_text", "")).find("I/K") >= 0 and str(active_prompt_state.get("prompt_text", "")).find("Space") >= 0, "The operation prompt must explicitly show J/L, I/K and Space after pressing E so artillery traverse, elevation and fire all remain learnable in-context"):
		return
	var active_lanyard_line_state := lanyard_line.get_debug_state() as Dictionary
	if not T.require_true(self, bool(active_lanyard_line_state.get("visible", false)), "After entering operation mode, the lanyard line must stay visible instead of collapsing into a tiny gun-local stub"):
		return
	if not T.require_true(self, player.has_method("get_bite_feedback_world_position"), "M777 howitzer interaction contract requires PlayerController.get_bite_feedback_world_position() so the operator-side lanyard endpoint can be regression tested"):
		return
	var operator_anchor_world_position := player.get_bite_feedback_world_position() as Vector3
	if not T.require_true(self, (active_lanyard_line_state.get("end_world_position", Vector3.ZERO) as Vector3).distance_to(operator_anchor_world_position) <= 0.9, "Entering operation mode must connect the lanyard line to the player-side operator anchor instead of leaving the rope endpoint near the gun"):
		return

	_set_key_pressed(KEY_L, true)
	await _advance_frames(12)
	_set_key_pressed(KEY_L, false)
	var active_yaw_deg := float((lab.get_lab_state() as Dictionary).get("yaw_deg", 0.0))
	if not T.require_true(self, active_yaw_deg >= blocked_yaw_deg + 0.2, "After entering operation mode, J/L must drive howitzer yaw through the formal lab API"):
		return

	_press_key(lab, KEY_E)
	await _settle_frames()

	var manual_exit_operation_state: Dictionary = lab.get_operation_state()
	if not T.require_true(self, not bool(manual_exit_operation_state.get("active", false)), "Pressing E again near the howitzer must still allow the player to manually exit operation mode"):
		return
	if not T.require_true(self, bool(hud.get_interaction_prompt_state().get("visible", false)), "After manually exiting near the howitzer, the HUD must return to the enter-operation prompt"):
		return

	_press_key(lab, KEY_E)
	await _settle_frames()

	active_operation_state = lab.get_operation_state()
	if not T.require_true(self, bool(active_operation_state.get("active", false)), "The player must be able to re-enter operation mode immediately after a manual exit"):
		return

	player.teleport_to_world_position(interaction_anchor + RETENTION_OFFSET)
	await _settle_frames()
	var retained_operation_state: Dictionary = lab.get_operation_state()
	if not T.require_true(self, bool(retained_operation_state.get("active", false)), "Leaving the enter radius but remaining within the wider retention radius must keep artillery operation active"):
		return
	active_prompt_state = hud.get_interaction_prompt_state()
	if not T.require_true(self, bool(active_prompt_state.get("visible", false)), "While retained inside the wider operation radius, the control prompt must remain visible"):
		return
	var retained_lanyard_line_state := lanyard_line.get_debug_state() as Dictionary
	var retained_operator_anchor_world_position := player.get_bite_feedback_world_position() as Vector3
	if not T.require_true(self, (retained_lanyard_line_state.get("end_world_position", Vector3.ZERO) as Vector3).distance_to(retained_operator_anchor_world_position) <= 0.9, "Inside the wider retention radius, the lanyard line endpoint must continue to follow the moved player instead of staying frozen at the original操炮位置"):
		return

	var retained_yaw_before_deg := float((lab.get_lab_state() as Dictionary).get("yaw_deg", 0.0))
	_set_key_pressed(KEY_L, true)
	await _advance_frames(12)
	_set_key_pressed(KEY_L, false)
	var retained_yaw_after_deg := float((lab.get_lab_state() as Dictionary).get("yaw_deg", 0.0))
	if not T.require_true(self, retained_yaw_after_deg >= retained_yaw_before_deg + 0.2, "Inside the wider retention radius, J/L must continue to control howitzer yaw"):
		return

	player.teleport_to_world_position(interaction_anchor + RELEASE_OFFSET)
	await _settle_frames()

	_press_key(lab, KEY_E)
	var exited_operation_state: Dictionary = lab.get_operation_state()
	if not T.require_true(self, not bool(exited_operation_state.get("active", false)), "Leaving roughly 20m away from the howitzer must automatically release operation mode"):
		return
	if not T.require_true(self, not bool(hud.get_interaction_prompt_state().get("visible", false)), "Once the player leaves the wider retention radius, the artillery prompt must fully disappear until they come back near the howitzer"):
		return

	_set_key_pressed(KEY_L, true)
	await _advance_frames(12)
	_set_key_pressed(KEY_L, false)
	var post_exit_yaw_deg := float((lab.get_lab_state() as Dictionary).get("yaw_deg", 0.0))
	if not T.require_true(self, absf(post_exit_yaw_deg - retained_yaw_after_deg) <= 0.01, "After automatically leaving operation mode, J/L must stop affecting howitzer yaw again"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _press_key(target: Node, keycode: Key) -> void:
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	target._unhandled_input(key_event)

func _set_key_pressed(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.pressed = pressed
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	Input.parse_input_event(event)

func _advance_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _settle_frames(frame_count: int = 4) -> void:
	for _frame_index in range(frame_count):
		await process_frame
