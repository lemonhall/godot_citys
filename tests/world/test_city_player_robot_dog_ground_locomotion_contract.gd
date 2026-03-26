extends SceneTree

const T := preload("res://tests/_test_util.gd")

const RUNTIME_SCENE_PATH := "res://city_game/world/creatures/quadrupeds/CityRobotDogControlRuntime.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(RUNTIME_SCENE_PATH, "PackedScene"), "Robot dog ground locomotion contract requires CityRobotDogControlRuntime.tscn"):
		return
	var scene := load(RUNTIME_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Robot dog ground locomotion contract must load CityRobotDogControlRuntime as PackedScene"):
		return

	var stage := Node3D.new()
	root.add_child(stage)
	stage.add_child(_build_ground())

	var runtime := scene.instantiate() as Node3D
	stage.add_child(runtime)
	await process_frame
	await process_frame

	for required_method in [
		"activate_at",
		"handle_input_event",
		"get_debug_state",
		"get_visual_robot_dog",
	]:
		if not T.require_true(self, runtime.has_method(required_method), "Robot dog ground locomotion contract requires %s()" % required_method):
			return

	runtime.activate_at(Vector3(0.0, 1.2, 0.0), 0.0)
	await _settle_frames(8)

	var idle_state := runtime.get_debug_state() as Dictionary
	if not T.require_true(self, str(idle_state.get("locomotion_state", "")) == "idle", "Freshly activated robot dog runtime must boot in idle locomotion state"):
		return
	if not T.require_true(self, float(idle_state.get("speed_mps", 1.0)) <= 0.05, "Freshly activated robot dog runtime must report near-zero speed while idle"):
		return

	_press_key(runtime, KEY_W)
	await _settle_frames(14)
	var walk_state := runtime.get_debug_state() as Dictionary
	if not T.require_true(self, str(walk_state.get("locomotion_state", "")) == "walk", "Holding W must place the robot dog into walk locomotion state"):
		return
	if not T.require_true(self, float(walk_state.get("speed_mps", 0.0)) >= 3.0, "Walk locomotion must now feel like the previous usable daily speed instead of the old too-slow crawl"):
		return
	if not T.require_true(self, float(walk_state.get("gait_cycle_hz", 0.0)) >= 0.8, "Walk locomotion must expose a measurable gait_cycle_hz instead of root-sliding without a gait state"):
		return
	var walk_leg_motion_delta := await _sample_leg_motion(runtime, 10)
	if not T.require_true(self, walk_leg_motion_delta >= 2.0, "Walk locomotion must visibly articulate the leg rig over time instead of leaving all joint angles static"):
		return
	var walk_body_motion := await _sample_body_motion(runtime, 18)
	if not T.require_true(self, float(walk_body_motion.get("heave_range_m", 0.0)) >= 0.012, "Walk locomotion must produce visible body heave instead of keeping the torso perfectly locked on a ruler-flat line"):
		return
	if not T.require_true(self, float(walk_body_motion.get("pitch_range_deg", 0.0)) >= 0.8, "Walk locomotion must produce visible body pitch motion instead of keeping the torso perfectly horizontal"):
		return
	if not T.require_true(self, float(walk_body_motion.get("roll_range_deg", 0.0)) >= 0.8, "Walk locomotion must produce visible body roll motion instead of keeping the torso perfectly level left-to-right"):
		return
	var walk_swing_batches := await _collect_walk_swing_start_batches(runtime, 56)
	if not T.require_true(self, int(walk_swing_batches.get("batched_start_count", 0)) >= 4, "Walk locomotion must expose multiple single-leg swing starts so the dog no longer looks like a paired front-leg shove"):
		return
	if not T.require_true(self, not bool(walk_swing_batches.get("saw_multi_leg_start_batch", true)), "Walk locomotion must not start multiple legs in the same beat; one leg at a time is the formal low-speed quadruped contract here"):
		return
	if not T.require_true(self, bool(walk_swing_batches.get("saw_front_leg_start", false)) and bool(walk_swing_batches.get("saw_rear_leg_start", false)), "Walk locomotion must rotate both front and rear legs through the single-leg crawl sequence instead of faking it with one pair only"):
		return

	_press_key(runtime, KEY_SHIFT)
	await _settle_frames(14)
	var run_state := runtime.get_debug_state() as Dictionary
	if not T.require_true(self, str(run_state.get("locomotion_state", "")) == "run", "Holding Shift+W must promote walk into run locomotion state"):
		return
	if not T.require_true(self, float(run_state.get("speed_mps", 0.0)) > float(walk_state.get("speed_mps", 0.0)) + 0.4, "Run locomotion must be faster than walk by a clear margin"):
		return
	if not T.require_true(self, float(run_state.get("gait_cycle_hz", 0.0)) > float(walk_state.get("gait_cycle_hz", 0.0)), "Run locomotion must increase gait_cycle_hz above walk instead of reusing the same cadence"):
		return
	var run_body_motion := await _sample_body_motion(runtime, 18)
	if not T.require_true(self, float(run_body_motion.get("heave_range_m", 0.0)) >= float(walk_body_motion.get("heave_range_m", 0.0)) * 0.9, "Run locomotion must preserve visible body heave instead of flattening the torso back into a rigid brick"):
		return

	_release_key(runtime, KEY_SHIFT)
	_release_key(runtime, KEY_W)
	_press_key(runtime, KEY_S)
	await _settle_frames(14)
	var backward_state := runtime.get_debug_state() as Dictionary
	if not T.require_true(self, str(backward_state.get("locomotion_state", "")) == "backward", "Holding S must place the robot dog into backward locomotion state"):
		return
	if not T.require_true(self, float(backward_state.get("speed_mps", 0.0)) >= 0.35, "Backward locomotion must still move at a measurable speed instead of remaining idle"):
		return
	if not T.require_true(self, float((backward_state.get("move_input", Vector2.ZERO) as Vector2).y) < -0.1, "Backward locomotion must preserve a negative move_input.y instead of pretending it is forward motion"):
		return

	_release_key(runtime, KEY_S)
	var turn_start_position := (runtime as Node3D).global_position
	var turn_start_heading := float((runtime.get_debug_state() as Dictionary).get("heading_deg", 0.0))
	_press_key(runtime, KEY_A)
	await _settle_frames(16)
	var turn_state := runtime.get_debug_state() as Dictionary
	var turn_end_position := (runtime as Node3D).global_position
	var turn_planar_distance := Vector2(turn_end_position.x - turn_start_position.x, turn_end_position.z - turn_start_position.z).length()
	if not T.require_true(self, str(turn_state.get("locomotion_state", "")) == "turn_left", "Holding A without W/S must enter turn_left locomotion state"):
		return
	if not T.require_true(self, absf(float(turn_state.get("heading_deg", 0.0)) - turn_start_heading) >= 8.0, "turn_left locomotion must rotate heading by a visible amount instead of staying static"):
		return
	var turn_left_forward := _planar_forward((runtime as Node3D).global_transform.basis)
	if not T.require_true(self, turn_left_forward.x <= -0.16, "Holding A must yaw the robot dog's nose toward world-left instead of steering it to the right"):
		return
	if not T.require_true(self, turn_planar_distance <= 0.35, "turn_left locomotion must primarily rotate in place instead of sliding forward like walk"):
		return

	_release_key(runtime, KEY_A)
	runtime.activate_at(Vector3(0.0, 1.2, 0.0), 0.0)
	await _settle_frames(8)
	_press_key(runtime, KEY_D)
	await _settle_frames(16)
	var turn_right_state := runtime.get_debug_state() as Dictionary
	var turn_right_forward := _planar_forward((runtime as Node3D).global_transform.basis)
	if not T.require_true(self, absf(float(turn_right_state.get("heading_deg", 0.0))) >= 8.0, "turn_right locomotion must rotate heading by a visible amount instead of staying static"):
		return
	if not T.require_true(self, turn_right_forward.x >= 0.16, "Holding D must yaw the robot dog's nose toward world-right instead of steering it to the left"):
		return
	_release_key(runtime, KEY_D)
	runtime.activate_at(Vector3(0.0, 1.2, 0.0), 0.0)
	await _settle_frames(8)
	var turn_move_start_heading := float((runtime.get_debug_state() as Dictionary).get("heading_deg", 0.0))
	var turn_move_start_position := (runtime as Node3D).global_position
	_press_key(runtime, KEY_W)
	_press_key(runtime, KEY_D)
	await _settle_frames(16)
	var turn_move_state := runtime.get_debug_state() as Dictionary
	var turn_move_end_position := (runtime as Node3D).global_position
	if not T.require_true(self, str(turn_move_state.get("locomotion_state", "")) == "turn_move", "Combining W with A/D must enter turn_move locomotion state"):
		return
	if not T.require_true(self, absf(float(turn_move_state.get("heading_deg", 0.0)) - turn_move_start_heading) >= 6.0, "turn_move locomotion must still rotate heading while moving forward"):
		return
	if not T.require_true(self, Vector2(turn_move_end_position.x - turn_move_start_position.x, turn_move_end_position.z - turn_move_start_position.z).length() >= 0.35, "turn_move locomotion must advance across the ground instead of degenerating into in-place turn only"):
		return

	_release_key(runtime, KEY_D)
	_release_key(runtime, KEY_W)
	_tap_key(runtime, KEY_P)
	await _settle_frames(64)
	var prone_state := runtime.get_debug_state() as Dictionary
	var visual_robot_dog := runtime.get_visual_robot_dog() as Node3D
	if not T.require_true(self, visual_robot_dog != null and visual_robot_dog.has_method("get_pose_debug_state"), "Robot dog ground locomotion contract requires access to the formal visual robot dog pose debug state"):
		return
	var pose_state := visual_robot_dog.get_pose_debug_state() as Dictionary
	if not T.require_true(self, str(prone_state.get("locomotion_state", "")) == "prone", "Pressing P in control runtime must enter prone locomotion state"):
		return
	if not T.require_true(self, float(prone_state.get("speed_mps", 1.0)) <= 0.05, "Prone locomotion must collapse speed back near zero instead of continuing to walk or run"):
		return
	if not T.require_true(self, str(pose_state.get("pose_state", "")) == "crouched", "Prone locomotion must drive the formal visual robot dog into the crouched pose runtime from v60"):
		return

	stage.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _build_ground() -> StaticBody3D:
	var ground := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 2.0, 80.0)
	collision_shape.shape = shape
	collision_shape.position = Vector3(0.0, -1.0, 0.0)
	ground.add_child(collision_shape)
	return ground

func _press_key(target: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	target.handle_input_event(event)

func _release_key(target: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = false
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	target.handle_input_event(event)

func _tap_key(target: Node, keycode: Key) -> void:
	_press_key(target, keycode)
	_release_key(target, keycode)

func _settle_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _sample_leg_motion(runtime: Node, frame_count: int) -> float:
	var visual_robot_dog := runtime.get_visual_robot_dog() as Node3D
	if visual_robot_dog == null or not visual_robot_dog.has_method("get_pose_debug_state"):
		return 0.0
	var baseline_pose := visual_robot_dog.get_pose_debug_state() as Dictionary
	var baseline_legs: Array = baseline_pose.get("legs", [])
	var maximum_delta := 0.0
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
		var next_pose := visual_robot_dog.get_pose_debug_state() as Dictionary
		var next_legs: Array = next_pose.get("legs", [])
		maximum_delta = maxf(maximum_delta, _max_leg_angle_delta_deg(baseline_legs, next_legs))
	return maximum_delta

func _sample_body_motion(runtime: Node, frame_count: int) -> Dictionary:
	var visual_robot_dog := runtime.get_visual_robot_dog() as Node3D
	if visual_robot_dog == null or not visual_robot_dog.has_method("get_pose_debug_state"):
		return {
			"heave_range_m": 0.0,
			"pitch_range_deg": 0.0,
			"roll_range_deg": 0.0,
		}
	var min_heave := INF
	var max_heave := -INF
	var min_pitch := INF
	var max_pitch := -INF
	var min_roll := INF
	var max_roll := -INF
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
		var pose_state := visual_robot_dog.get_pose_debug_state() as Dictionary
		var heave := float(pose_state.get("locomotion_body_heave_m", 0.0))
		var pitch := float(pose_state.get("locomotion_body_pitch_deg", 0.0))
		var roll := float(pose_state.get("locomotion_body_roll_deg", 0.0))
		min_heave = minf(min_heave, heave)
		max_heave = maxf(max_heave, heave)
		min_pitch = minf(min_pitch, pitch)
		max_pitch = maxf(max_pitch, pitch)
		min_roll = minf(min_roll, roll)
		max_roll = maxf(max_roll, roll)
	return {
		"heave_range_m": 0.0 if min_heave == INF else max_heave - min_heave,
		"pitch_range_deg": 0.0 if min_pitch == INF else max_pitch - min_pitch,
		"roll_range_deg": 0.0 if min_roll == INF else max_roll - min_roll,
	}

func _collect_walk_swing_start_batches(runtime: Node, frame_count: int) -> Dictionary:
	var visual_robot_dog := runtime.get_visual_robot_dog() as Node3D
	if visual_robot_dog == null or not visual_robot_dog.has_method("get_pose_debug_state"):
		return {
			"batched_start_count": 0,
			"saw_multi_leg_start_batch": true,
			"saw_front_leg_start": false,
			"saw_rear_leg_start": false,
		}
	var previous_modes := {}
	var batched_start_count := 0
	var saw_multi_leg_start_batch := false
	var saw_front_leg_start := false
	var saw_rear_leg_start := false
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
		var pose_state := visual_robot_dog.get_pose_debug_state() as Dictionary
		var legs: Array = pose_state.get("legs", [])
		var start_batch_size := 0
		for leg_variant in legs:
			var leg := leg_variant as Dictionary
			var leg_id := str(leg.get("leg_id", ""))
			var gait_mode := str(leg.get("gait_mode", ""))
			var previous_mode := str(previous_modes.get(leg_id, "stance"))
			if gait_mode == "swing" and previous_mode != "swing":
				start_batch_size += 1
				if leg_id.ends_with("f"):
					saw_front_leg_start = true
				else:
					saw_rear_leg_start = true
			previous_modes[leg_id] = gait_mode
		if start_batch_size > 0:
			batched_start_count += 1
			if start_batch_size > 1:
				saw_multi_leg_start_batch = true
	return {
		"batched_start_count": batched_start_count,
		"saw_multi_leg_start_batch": saw_multi_leg_start_batch,
		"saw_front_leg_start": saw_front_leg_start,
		"saw_rear_leg_start": saw_rear_leg_start,
	}

func _max_leg_angle_delta_deg(previous_legs: Array, current_legs: Array) -> float:
	var maximum_delta := 0.0
	var pair_count := mini(previous_legs.size(), current_legs.size())
	for index in range(pair_count):
		var previous_leg := previous_legs[index] as Dictionary
		var current_leg := current_legs[index] as Dictionary
		maximum_delta = maxf(maximum_delta, absf(float(current_leg.get("hip_angle_deg", 0.0)) - float(previous_leg.get("hip_angle_deg", 0.0))))
		maximum_delta = maxf(maximum_delta, absf(float(current_leg.get("knee_angle_deg", 0.0)) - float(previous_leg.get("knee_angle_deg", 0.0))))
	return maximum_delta

func _planar_forward(basis: Basis) -> Vector3:
	var forward := -basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3.ZERO
	return forward.normalized()
