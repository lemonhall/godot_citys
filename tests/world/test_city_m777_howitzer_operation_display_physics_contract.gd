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
const HUD_TO_MODEL_BEARING_TOLERANCE_DEG := 0.35
const HUD_TO_MODEL_PITCH_TOLERANCE_DEG := 0.35

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 operation/display/physics contract requires the dedicated howitzer lab scene"):
		return

	var lab := scene.instantiate() as Node3D
	if not T.require_true(self, lab != null, "M777 operation/display/physics contract must instantiate the lab as Node3D"):
		return

	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player") as CharacterBody3D
	var howitzer := lab.get_node_or_null("ArtilleryRoot/Howitzer") as Node3D
	var hud := lab.get_node_or_null("Hud")
	var orientation := OrientationScript.new()
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "M777 operation/display/physics contract requires the teleportable lab player"):
		return
	if not T.require_true(self, howitzer != null and howitzer.has_method("set_axis_angles_degrees") and howitzer.has_method("get_firing_solution_snapshot"), "M777 operation/display/physics contract requires the formal howitzer runtime in the lab hierarchy"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_artillery_solution_state"), "M777 operation/display/physics contract requires HUD artillery solution introspection"):
		return

	var anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var interaction_anchor := anchor.global_position if anchor != null else howitzer.global_position
	player.teleport_to_world_position(interaction_anchor + INSIDE_INTERACTION_OFFSET)
	await _settle_frames()

	_press_key(lab, KEY_E)
	await _settle_frames()

	var active_state := lab.get("get_operation_state").call() as Dictionary
	if not T.require_true(self, bool(active_state.get("active", false)), "Operation/display/physics contract requires the lab to be in active howitzer operation mode before J/L/I/K semantics are checked"):
		return

	howitzer.set_axis_angles_degrees(MID_CIRCLE_START_YAW_DEG, MID_CIRCLE_START_PITCH_DEG)
	await _settle_frames()

	var baseline_state := _capture_solution_and_model_state(howitzer, hud, orientation)
	if not _require_hud_matches_model(orientation, baseline_state, "Baseline"):
		return

	var yaw_right_state := await _hold_key_and_capture(lab, KEY_L, howitzer, hud, orientation)
	if not _require_bearing_delta(orientation, baseline_state, yaw_right_state, MIN_YAW_RESPONSE_DEG, "positive", "Holding L in operation mode must rotate the HUD bearing clockwise/increasing, except for the explicit 360->0 wrap case"):
		return
	if not _require_bearing_delta(orientation, baseline_state, yaw_right_state, MIN_YAW_RESPONSE_DEG, "positive_model", "Holding L in operation mode must also rotate the real presentation muzzle bearing clockwise/increasing instead of only moving the HUD marker"):
		return
	if not _require_hud_matches_model(orientation, yaw_right_state, "After L"):
		return

	var yaw_left_state := await _hold_key_and_capture(lab, KEY_J, howitzer, hud, orientation)
	if not _require_bearing_delta(orientation, yaw_right_state, yaw_left_state, MIN_YAW_RESPONSE_DEG, "negative", "Holding J in operation mode must rotate the HUD bearing counter-clockwise/decreasing instead of continuing to climb"):
		return
	if not _require_bearing_delta(orientation, yaw_right_state, yaw_left_state, MIN_YAW_RESPONSE_DEG, "negative_model", "Holding J in operation mode must also rotate the real presentation muzzle bearing counter-clockwise/decreasing instead of diverging from the HUD"):
		return
	if not _require_hud_matches_model(orientation, yaw_left_state, "After J"):
		return

	var pitch_up_state := await _hold_key_and_capture(lab, KEY_I, howitzer, hud, orientation)
	if not _require_pitch_delta(yaw_left_state, pitch_up_state, MIN_PITCH_RESPONSE_DEG, "positive", "Holding I in operation mode must raise the HUD pitch/elevation instead of lowering it"):
		return
	if not _require_pitch_delta(yaw_left_state, pitch_up_state, MIN_PITCH_RESPONSE_DEG, "positive_model", "Holding I in operation mode must also raise the real presentation muzzle pitch instead of only changing the HUD number"):
		return
	if not _require_hud_matches_model(orientation, pitch_up_state, "After I"):
		return

	var pitch_down_state := await _hold_key_and_capture(lab, KEY_K, howitzer, hud, orientation)
	if not _require_pitch_delta(pitch_up_state, pitch_down_state, MIN_PITCH_RESPONSE_DEG, "negative", "Holding K in operation mode must lower the HUD pitch/elevation instead of continuing to climb"):
		return
	if not _require_pitch_delta(pitch_up_state, pitch_down_state, MIN_PITCH_RESPONSE_DEG, "negative_model", "Holding K in operation mode must also lower the real presentation muzzle pitch instead of diverging from the HUD"):
		return
	if not _require_hud_matches_model(orientation, pitch_down_state, "After K"):
		return

	howitzer.set_axis_angles_degrees(WRAP_START_YAW_DEG, MID_CIRCLE_START_PITCH_DEG)
	await _settle_frames()
	var wrap_before_state := _capture_solution_and_model_state(howitzer, hud, orientation)
	var wrap_after_state := await _hold_key_and_capture(lab, KEY_L, howitzer, hud, orientation)
	if not _require_bearing_delta(orientation, wrap_before_state, wrap_after_state, MIN_YAW_RESPONSE_DEG, "positive", "Near 360 degrees, holding L must still mean clockwise/increasing yaw across the 360->0 wrap instead of looking like a reversal"):
		return
	if not _require_bearing_delta(orientation, wrap_before_state, wrap_after_state, MIN_YAW_RESPONSE_DEG, "positive_model", "Near 360 degrees, the real presentation muzzle bearing must follow the same clockwise/increasing wrap contract as the HUD"):
		return
	if not _require_hud_matches_model(orientation, wrap_after_state, "After wrapped L"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _hold_key_and_capture(lab: Node, keycode: Key, howitzer: Node3D, hud: Node, orientation) -> Dictionary:
	_set_key_pressed(lab, keycode, true)
	await _advance_frames(CONTROL_HOLD_FRAMES)
	_set_key_pressed(lab, keycode, false)
	await _settle_frames()
	return _capture_solution_and_model_state(howitzer, hud, orientation)

func _capture_solution_and_model_state(howitzer: Node3D, hud: Node, orientation) -> Dictionary:
	var hud_state := hud.get_artillery_solution_state() as Dictionary
	var firing_solution := howitzer.get_firing_solution_snapshot() as Dictionary
	var presentation_direction_world := firing_solution.get("presentation_muzzle_direction_world", Vector3.ZERO) as Vector3
	var normalized_presentation_direction := presentation_direction_world.normalized() if presentation_direction_world.length_squared() > 0.0001 else Vector3.ZERO
	var model_bearing_deg := float(orientation.bearing_deg_from_world_vector(normalized_presentation_direction))
	var model_pitch_deg := rad_to_deg(asin(clampf(normalized_presentation_direction.y, -1.0, 1.0))) if normalized_presentation_direction.length_squared() > 0.0001 else 0.0
	return {
		"hud_visible": bool(hud_state.get("visible", false)),
		"hud_yaw_bearing_deg": float(hud_state.get("yaw_bearing_deg", 0.0)),
		"hud_pitch_deg": float(hud_state.get("pitch_deg", 0.0)),
		"model_bearing_deg": model_bearing_deg,
		"model_pitch_deg": model_pitch_deg,
		"solution_world_bearing_deg": float(firing_solution.get("world_bearing_deg", 0.0)),
		"solution_pitch_deg": float(firing_solution.get("pitch_deg", 0.0)),
	}

func _require_hud_matches_model(orientation, state: Dictionary, label: String) -> bool:
	if not T.require_true(self, bool(state.get("hud_visible", false)), "%s artillery solution state must stay visible throughout active operation mode" % label):
		return false
	var hud_bearing_deg := float(state.get("hud_yaw_bearing_deg", 0.0))
	var model_bearing_deg := float(state.get("model_bearing_deg", 0.0))
	var hud_pitch_deg := float(state.get("hud_pitch_deg", 0.0))
	var model_pitch_deg := float(state.get("model_pitch_deg", 0.0))
	var bearing_delta_deg := absf(float(orientation.shortest_bearing_delta_deg(hud_bearing_deg, model_bearing_deg)))
	var pitch_delta_deg := absf(hud_pitch_deg - model_pitch_deg)
	if not T.require_true(self, bearing_delta_deg <= HUD_TO_MODEL_BEARING_TOLERANCE_DEG, "%s HUD bearing must match the real presentation muzzle bearing instead of drifting away from the actual gun direction (hud=%0.2f model=%0.2f delta=%0.2f)" % [label, hud_bearing_deg, model_bearing_deg, bearing_delta_deg]):
		return false
	if not T.require_true(self, pitch_delta_deg <= HUD_TO_MODEL_PITCH_TOLERANCE_DEG, "%s HUD pitch must match the real presentation muzzle pitch instead of becoming a disconnected number (hud=%0.2f model=%0.2f delta=%0.2f)" % [label, hud_pitch_deg, model_pitch_deg, pitch_delta_deg]):
		return false
	return true

func _require_bearing_delta(orientation, before_state: Dictionary, after_state: Dictionary, min_delta_deg: float, expectation: String, message: String) -> bool:
	var before_bearing_deg := float(before_state.get("hud_yaw_bearing_deg", 0.0))
	var after_bearing_deg := float(after_state.get("hud_yaw_bearing_deg", 0.0))
	if expectation == "positive_model" or expectation == "negative_model":
		before_bearing_deg = float(before_state.get("model_bearing_deg", 0.0))
		after_bearing_deg = float(after_state.get("model_bearing_deg", 0.0))
	var signed_delta_deg := float(orientation.shortest_bearing_delta_deg(before_bearing_deg, after_bearing_deg))
	if expectation == "positive" or expectation == "positive_model":
		return T.require_true(self, signed_delta_deg >= min_delta_deg, "%s (before=%0.2f after=%0.2f signed_delta=%0.2f)" % [message, before_bearing_deg, after_bearing_deg, signed_delta_deg])
	return T.require_true(self, signed_delta_deg <= -min_delta_deg, "%s (before=%0.2f after=%0.2f signed_delta=%0.2f)" % [message, before_bearing_deg, after_bearing_deg, signed_delta_deg])

func _require_pitch_delta(before_state: Dictionary, after_state: Dictionary, min_delta_deg: float, expectation: String, message: String) -> bool:
	var before_pitch_deg := float(before_state.get("hud_pitch_deg", 0.0))
	var after_pitch_deg := float(after_state.get("hud_pitch_deg", 0.0))
	if expectation == "positive_model" or expectation == "negative_model":
		before_pitch_deg = float(before_state.get("model_pitch_deg", 0.0))
		after_pitch_deg = float(after_state.get("model_pitch_deg", 0.0))
	var signed_delta_deg := after_pitch_deg - before_pitch_deg
	if expectation == "positive" or expectation == "positive_model":
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
