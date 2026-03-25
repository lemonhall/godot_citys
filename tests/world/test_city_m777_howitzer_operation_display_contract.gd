extends SceneTree

const T := preload("res://tests/_test_util.gd")
const OrientationScript := preload("res://city_game/world/navigation/CityWorldOrientation.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/M777HowitzerLab.tscn"
const INSIDE_INTERACTION_OFFSET := Vector3(0.0, 0.0, 6.8)
const MID_CIRCLE_START_YAW_DEG := 120.0
const MID_CIRCLE_START_PITCH_DEG := 18.0
const WRAP_START_YAW_DEG := 358.5
const CONTROL_HOLD_FRAMES := 8
const MIN_YAW_RESPONSE_DEG := 1.0
const MIN_PITCH_RESPONSE_DEG := 0.5

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 operation/display contract requires the dedicated howitzer lab scene"):
		return

	var lab := scene.instantiate() as Node3D
	if not T.require_true(self, lab != null, "M777 operation/display contract must instantiate the lab as Node3D"):
		return

	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player") as CharacterBody3D
	var howitzer := lab.get_node_or_null("ArtilleryRoot/Howitzer") as Node3D
	var hud := lab.get_node_or_null("Hud")
	var orientation := OrientationScript.new()
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "M777 operation/display contract requires the teleportable lab player"):
		return
	if not T.require_true(self, howitzer != null and howitzer.has_method("set_axis_angles_degrees"), "M777 operation/display contract requires the formal howitzer runtime in the lab hierarchy"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_artillery_solution_state"), "M777 operation/display contract requires HUD artillery solution introspection"):
		return

	var anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var interaction_anchor := anchor.global_position if anchor != null else howitzer.global_position
	player.teleport_to_world_position(interaction_anchor + INSIDE_INTERACTION_OFFSET)
	await _settle_frames()

	_press_key(lab, KEY_E)
	await _settle_frames()

	var active_state := lab.call("get_operation_state") as Dictionary
	if not T.require_true(self, bool(active_state.get("active", false)), "Operation/display contract requires the lab to be in active howitzer operation mode before J/L/I/K semantics are checked"):
		return

	howitzer.set_axis_angles_degrees(MID_CIRCLE_START_YAW_DEG, MID_CIRCLE_START_PITCH_DEG)
	await _settle_frames()
	var baseline_state := _capture_hud_state(hud)

	var yaw_right_state := await _hold_key_and_capture_hud(lab, KEY_L, hud)
	if not _require_bearing_delta(orientation, baseline_state, yaw_right_state, MIN_YAW_RESPONSE_DEG, "positive", "Holding L in operation mode must make the HUD bearing increase clockwise instead of decreasing"):
		return

	var yaw_left_state := await _hold_key_and_capture_hud(lab, KEY_J, hud)
	if not _require_bearing_delta(orientation, yaw_right_state, yaw_left_state, MIN_YAW_RESPONSE_DEG, "negative", "Holding J in operation mode must make the HUD bearing decrease counter-clockwise instead of continuing to increase"):
		return

	var pitch_up_state := await _hold_key_and_capture_hud(lab, KEY_I, hud)
	if not _require_pitch_delta(yaw_left_state, pitch_up_state, MIN_PITCH_RESPONSE_DEG, "positive", "Holding I in operation mode must make the HUD pitch increase instead of decrease"):
		return

	var pitch_down_state := await _hold_key_and_capture_hud(lab, KEY_K, hud)
	if not _require_pitch_delta(pitch_up_state, pitch_down_state, MIN_PITCH_RESPONSE_DEG, "negative", "Holding K in operation mode must make the HUD pitch decrease instead of continue climbing"):
		return

	howitzer.set_axis_angles_degrees(WRAP_START_YAW_DEG, MID_CIRCLE_START_PITCH_DEG)
	await _settle_frames()
	var wrap_before_state := _capture_hud_state(hud)
	var wrap_after_state := await _hold_key_and_capture_hud(lab, KEY_L, hud)
	if not _require_bearing_delta(orientation, wrap_before_state, wrap_after_state, MIN_YAW_RESPONSE_DEG, "positive", "Near 360 degrees, holding L must still mean clockwise/increasing HUD yaw across the 360->0 wrap instead of looking like a reversal"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _hold_key_and_capture_hud(lab: Node, keycode: Key, hud: Node) -> Dictionary:
	_set_key_pressed(lab, keycode, true)
	await _advance_frames(CONTROL_HOLD_FRAMES)
	_set_key_pressed(lab, keycode, false)
	await _settle_frames()
	return _capture_hud_state(hud)

func _capture_hud_state(hud: Node) -> Dictionary:
	var hud_state := hud.get_artillery_solution_state() as Dictionary
	return {
		"visible": bool(hud_state.get("visible", false)),
		"yaw_bearing_deg": float(hud_state.get("yaw_bearing_deg", 0.0)),
		"pitch_deg": float(hud_state.get("pitch_deg", 0.0)),
	}

func _require_bearing_delta(orientation, before_state: Dictionary, after_state: Dictionary, min_delta_deg: float, expectation: String, message: String) -> bool:
	if not T.require_true(self, bool(before_state.get("visible", false)) and bool(after_state.get("visible", false)), "Operation/display contract requires HUD artillery solution state to remain visible while keys are held"):
		return false
	var before_bearing_deg := float(before_state.get("yaw_bearing_deg", 0.0))
	var after_bearing_deg := float(after_state.get("yaw_bearing_deg", 0.0))
	var signed_delta_deg := float(orientation.shortest_bearing_delta_deg(before_bearing_deg, after_bearing_deg))
	if expectation == "positive":
		return T.require_true(self, signed_delta_deg >= min_delta_deg, "%s (before=%0.2f after=%0.2f signed_delta=%0.2f)" % [message, before_bearing_deg, after_bearing_deg, signed_delta_deg])
	return T.require_true(self, signed_delta_deg <= -min_delta_deg, "%s (before=%0.2f after=%0.2f signed_delta=%0.2f)" % [message, before_bearing_deg, after_bearing_deg, signed_delta_deg])

func _require_pitch_delta(before_state: Dictionary, after_state: Dictionary, min_delta_deg: float, expectation: String, message: String) -> bool:
	if not T.require_true(self, bool(before_state.get("visible", false)) and bool(after_state.get("visible", false)), "Operation/display contract requires HUD artillery solution state to remain visible while keys are held"):
		return false
	var before_pitch_deg := float(before_state.get("pitch_deg", 0.0))
	var after_pitch_deg := float(after_state.get("pitch_deg", 0.0))
	var signed_delta_deg := after_pitch_deg - before_pitch_deg
	if expectation == "positive":
		return T.require_true(self, signed_delta_deg >= min_delta_deg, "%s (before=%0.2f after=%0.2f signed_delta=%0.2f)" % [message, before_pitch_deg, after_pitch_deg, signed_delta_deg])
	return T.require_true(self, signed_delta_deg <= -min_delta_deg, "%s (before=%0.2f after=%0.2f signed_delta=%0.2f)" % [message, before_pitch_deg, after_pitch_deg, signed_delta_deg])

func _press_key(target: Node, keycode: Key) -> void:
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	target._unhandled_input(key_event)

func _set_key_pressed(target: Node, keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.pressed = pressed
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	Input.parse_input_event(event)
	target._input(event)

func _advance_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _settle_frames(frame_count: int = 4) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
