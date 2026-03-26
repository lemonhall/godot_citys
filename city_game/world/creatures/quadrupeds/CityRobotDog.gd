extends Node3D

const SPECIES_ID := "robot_dog"
const JOINT_ANCHOR_NAMES := [
	"lf_hip",
	"lf_knee",
	"rf_hip",
	"rf_knee",
	"lr_hip",
	"lr_knee",
	"rr_hip",
	"rr_knee",
]

const JOINT_CONSTRAINTS := {
	"lf_hip": {"axis_name": "z", "axis": Vector3(0.0, 0.0, 1.0), "min_deg": -60.0, "max_deg": 5.0},
	"lf_knee": {"axis_name": "z", "axis": Vector3(0.0, 0.0, 1.0), "min_deg": -80.0, "max_deg": 80.0},
	"rf_hip": {"axis_name": "z", "axis": Vector3(0.0, 0.0, 1.0), "min_deg": -60.0, "max_deg": 5.0},
	"rf_knee": {"axis_name": "z", "axis": Vector3(0.0, 0.0, 1.0), "min_deg": -80.0, "max_deg": 80.0},
	"lr_hip": {"axis_name": "z", "axis": Vector3(0.0, 0.0, 1.0), "min_deg": -60.0, "max_deg": 5.0},
	"lr_knee": {"axis_name": "z", "axis": Vector3(0.0, 0.0, 1.0), "min_deg": -80.0, "max_deg": 80.0},
	"rr_hip": {"axis_name": "z", "axis": Vector3(0.0, 0.0, 1.0), "min_deg": -60.0, "max_deg": 5.0},
	"rr_knee": {"axis_name": "z", "axis": Vector3(0.0, 0.0, 1.0), "min_deg": -80.0, "max_deg": 80.0},
}

const LEG_CONFIGS := {
	"lf": {
		"leg_id": "lf",
		"hip_joint_name": "lf_hip",
		"knee_joint_name": "lf_knee",
		"side_sign": -1.0,
		"gait_phase_offset_rad": 0.0,
		"hip_mesh_source_path": "BodyPivot/Model/ParentNode/L_Fore_Hip",
		"calf_mesh_source_path": "BodyPivot/Model/ParentNode/L_Fore_Calf",
		"hip_mesh_name": "L_Fore_Hip",
		"calf_mesh_name": "L_Fore_Calf",
	},
	"rf": {
		"leg_id": "rf",
		"hip_joint_name": "rf_hip",
		"knee_joint_name": "rf_knee",
		"side_sign": 1.0,
		"gait_phase_offset_rad": PI,
		"hip_mesh_source_path": "BodyPivot/Model/ParentNode/R_Fore_Hip",
		"calf_mesh_source_path": "BodyPivot/Model/ParentNode/R_Fore_Calf",
		"hip_mesh_name": "R_Fore_Hip",
		"calf_mesh_name": "R_Fore_Calf",
	},
	"lr": {
		"leg_id": "lr",
		"hip_joint_name": "lr_hip",
		"knee_joint_name": "lr_knee",
		"side_sign": -1.0,
		"gait_phase_offset_rad": PI,
		"hip_mesh_source_path": "BodyPivot/Model/ParentNode/L_Hind_Hip",
		"calf_mesh_source_path": "BodyPivot/Model/ParentNode/L_Hind_Calf",
		"hip_mesh_name": "L_Hind_Hip",
		"calf_mesh_name": "L_Hind_Calf",
	},
	"rr": {
		"leg_id": "rr",
		"hip_joint_name": "rr_hip",
		"knee_joint_name": "rr_knee",
		"side_sign": 1.0,
		"gait_phase_offset_rad": 0.0,
		"hip_mesh_source_path": "BodyPivot/Model/ParentNode/R_Hind_Hip",
		"calf_mesh_source_path": "BodyPivot/Model/ParentNode/R_Hind_Calf",
		"hip_mesh_name": "R_Hind_Hip",
		"calf_mesh_name": "R_Hind_Calf",
	},
}

const CROUCH_TRANSITION_SECONDS := 0.8
const CROUCH_BODY_DROP_M := 0.16
const CROUCH_TARGET_HIP_DEG := -40.0
const LOCOMOTION_STATE_IDLE := "idle"
const LOCOMOTION_STATE_WALK := "walk"
const LOCOMOTION_STATE_RUN := "run"
const LOCOMOTION_STATE_BACKWARD := "backward"
const LOCOMOTION_STATE_TURN_LEFT := "turn_left"
const LOCOMOTION_STATE_TURN_RIGHT := "turn_right"
const LOCOMOTION_STATE_TURN_MOVE := "turn_move"
const LOCOMOTION_STATE_PRONE := "prone"
const INPUT_DEADZONE := 0.05

@onready var body_pivot: Node3D = $BodyPivot
@onready var model_root: Node3D = $BodyPivot/Model
@onready var leg_pivot_root: Node3D = $BodyPivot/LegPivotRoot
@onready var joint_anchor_root: Node3D = $JointAnchors

var _initial_root_transform := Transform3D.IDENTITY
var _initial_body_pivot_transform := Transform3D.IDENTITY
var _initial_joint_anchor_local_transforms: Dictionary = {}
var _leg_runtimes_by_id: Dictionary = {}
var _crouch_requested := false
var _crouch_alpha := 0.0
var _body_height_offset_m := 0.0
var _pose_state := "standing"
var _move_input := Vector2.ZERO
var _turn_input := 0.0
var _sprint_requested := false
var _commanded_speed_mps := 0.0
var _locomotion_state := LOCOMOTION_STATE_IDLE
var _gait_cycle_phase_rad := 0.0
var _gait_cycle_hz := 0.0
var _gait_stride_direction := 0.0

func _ready() -> void:
	_ensure_leg_visual_pivots()
	_capture_initial_pose()
	_cache_leg_runtimes()
	_apply_pose_from_alpha(0.0)

func get_joint_anchor_names() -> Array:
	var names: Array = []
	for joint_anchor_name in JOINT_ANCHOR_NAMES:
		names.append(joint_anchor_name)
	return names

func get_joint_anchor_state() -> Dictionary:
	var joint_anchor_state := {}
	for joint_anchor_name in JOINT_ANCHOR_NAMES:
		var joint_anchor := _get_joint_anchor_node(joint_anchor_name)
		if joint_anchor == null:
			continue
		joint_anchor_state[joint_anchor_name] = {
			"local_position": joint_anchor.position,
			"global_position": joint_anchor.global_position,
			"node_path": str(joint_anchor.get_path()),
		}
	return joint_anchor_state

func get_joint_constraint_contract() -> Dictionary:
	return JOINT_CONSTRAINTS.duplicate(true)

func get_debug_state() -> Dictionary:
	return {
		"species_id": SPECIES_ID,
		"model_scene_path": model_root.scene_file_path if model_root != null else "",
		"joint_anchor_count": get_joint_anchor_names().size(),
		"joint_anchor_names": get_joint_anchor_names(),
		"joint_anchor_state": get_joint_anchor_state().duplicate(true),
		"pose_debug_state": get_pose_debug_state(),
	}.duplicate(true)

func get_pose_debug_state() -> Dictionary:
	var debug_state := {
		"species_id": SPECIES_ID,
		"pose_state": _pose_state,
		"crouch_requested": _crouch_requested,
		"crouch_alpha": _crouch_alpha,
		"body_height_offset_m": _body_height_offset_m,
		"joint_constraints": get_joint_constraint_contract(),
		"legs": _build_leg_debug_state(),
	}
	debug_state.merge(get_locomotion_debug_state(), true)
	return debug_state.duplicate(true)

func get_locomotion_debug_state() -> Dictionary:
	return {
		"locomotion_state": _locomotion_state,
		"move_input": _move_input,
		"turn_input": _turn_input,
		"sprint_requested": _sprint_requested,
		"commanded_speed_mps": _commanded_speed_mps,
		"gait_cycle_phase_deg": rad_to_deg(_gait_cycle_phase_rad),
		"gait_cycle_hz": _gait_cycle_hz,
		"gait_stride_direction": _gait_stride_direction,
	}.duplicate(true)

func set_motion_command(move_input: Vector2, turn_input: float, sprint_requested: bool, commanded_speed_mps: float = 0.0) -> void:
	_move_input = Vector2(
		clampf(move_input.x, -1.0, 1.0),
		clampf(move_input.y, -1.0, 1.0)
	)
	_turn_input = clampf(turn_input, -1.0, 1.0)
	_sprint_requested = sprint_requested
	_commanded_speed_mps = maxf(commanded_speed_mps, 0.0)

func set_crouch_requested(requested: bool) -> void:
	_crouch_requested = requested
	_update_pose_state_label()

func toggle_crouch_requested() -> void:
	set_crouch_requested(not _crouch_requested)

func tick_robot_dog(delta: float) -> void:
	var target_alpha := 1.0 if _crouch_requested else 0.0
	var step := maxf(delta, 0.0) / maxf(CROUCH_TRANSITION_SECONDS, 0.001)
	_crouch_alpha = move_toward(_crouch_alpha, target_alpha, step)
	_update_locomotion_state(delta)
	_apply_pose_from_alpha(_crouch_alpha)

func reset_robot_dog_pose() -> void:
	transform = _initial_root_transform
	if body_pivot != null:
		body_pivot.transform = _initial_body_pivot_transform
	for joint_anchor_name in JOINT_ANCHOR_NAMES:
		var joint_anchor := _get_joint_anchor_node(joint_anchor_name)
		if joint_anchor == null:
			continue
		if not _initial_joint_anchor_local_transforms.has(joint_anchor_name):
			continue
		joint_anchor.transform = _initial_joint_anchor_local_transforms[joint_anchor_name]
	_reset_leg_visual_rest_pose()
	_crouch_requested = false
	_crouch_alpha = 0.0
	_body_height_offset_m = 0.0
	_pose_state = "standing"
	_move_input = Vector2.ZERO
	_turn_input = 0.0
	_sprint_requested = false
	_commanded_speed_mps = 0.0
	_locomotion_state = LOCOMOTION_STATE_IDLE
	_gait_cycle_phase_rad = 0.0
	_gait_cycle_hz = 0.0
	_gait_stride_direction = 0.0
	_apply_pose_from_alpha(0.0)

func _capture_initial_pose() -> void:
	_initial_root_transform = transform
	if body_pivot != null:
		_initial_body_pivot_transform = body_pivot.transform
	_initial_joint_anchor_local_transforms.clear()
	for joint_anchor_name in JOINT_ANCHOR_NAMES:
		var joint_anchor := _get_joint_anchor_node(joint_anchor_name)
		if joint_anchor == null:
			continue
		_initial_joint_anchor_local_transforms[joint_anchor_name] = joint_anchor.transform

func _cache_leg_runtimes() -> void:
	_leg_runtimes_by_id.clear()
	for leg_id in LEG_CONFIGS.keys():
		var leg_config: Dictionary = LEG_CONFIGS.get(leg_id, {})
		var hip_joint := _get_joint_anchor_node(str(leg_config.get("hip_joint_name", "")))
		var knee_joint := _get_joint_anchor_node(str(leg_config.get("knee_joint_name", "")))
		var leg_root := leg_pivot_root.get_node_or_null(leg_id) as Node3D if leg_pivot_root != null else null
		var hip_pivot := leg_root.get_node_or_null("HipPivot") as Node3D if leg_root != null else null
		var calf_pivot := leg_root.get_node_or_null("CalfPivot") as Node3D if leg_root != null else null
		var hip_mesh := hip_pivot.get_node_or_null(str(leg_config.get("hip_mesh_name", ""))) as Node3D if hip_pivot != null else null
		var calf_mesh := calf_pivot.get_node_or_null(str(leg_config.get("calf_mesh_name", ""))) as Node3D if calf_pivot != null else null
		if hip_joint == null or knee_joint == null or hip_pivot == null or calf_pivot == null or hip_mesh == null or calf_mesh == null:
			continue
		var hip_joint_local := body_pivot.to_local(hip_joint.global_position)
		var knee_joint_local := body_pivot.to_local(knee_joint.global_position)
		var upper_rest_vector := knee_joint_local - hip_joint_local
		var calf_tip_rest_vector := _resolve_calf_tip_rest_vector(calf_mesh)
		var foot_rest_local := knee_joint_local + calf_tip_rest_vector
		_leg_runtimes_by_id[leg_id] = {
			"leg_id": leg_id,
			"hip_joint_name": str(leg_config.get("hip_joint_name", "")),
			"knee_joint_name": str(leg_config.get("knee_joint_name", "")),
			"hip_pivot": hip_pivot,
			"calf_pivot": calf_pivot,
			"hip_mesh": hip_mesh,
			"calf_mesh": calf_mesh,
			"hip_joint_local": hip_joint_local,
			"knee_joint_local": knee_joint_local,
			"upper_rest_vector": upper_rest_vector,
			"calf_tip_rest_vector": calf_tip_rest_vector,
			"foot_rest_local": foot_rest_local,
			"hip_target_deg": CROUCH_TARGET_HIP_DEG,
			"hip_pivot_rest_transform": hip_pivot.transform,
			"calf_pivot_rest_transform": calf_pivot.transform,
			"hip_mesh_rest_local_transform": hip_mesh.transform,
			"calf_mesh_rest_local_transform": calf_mesh.transform,
		}

func _resolve_calf_tip_rest_vector(calf_node: Node3D) -> Vector3:
	var mesh_offset := calf_node.position if calf_node != null else Vector3.ZERO
	if calf_node == null or not (calf_node is MeshInstance3D):
		return mesh_offset + Vector3(0.22, -0.24, 0.0)
	var mesh_node := calf_node as MeshInstance3D
	var aabb := mesh_node.get_aabb()
	var best_corner := Vector3(0.22, -0.24, 0.0)
	var best_score := -INF
	for corner in _aabb_corners(aabb):
		var score := (-corner.y * 2.0) + corner.length()
		if score <= best_score:
			continue
		best_score = score
		best_corner = corner
	return mesh_offset + best_corner

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var base := aabb.position
	var size := aabb.size
	return [
		base,
		base + Vector3(size.x, 0.0, 0.0),
		base + Vector3(0.0, size.y, 0.0),
		base + Vector3(0.0, 0.0, size.z),
		base + Vector3(size.x, size.y, 0.0),
		base + Vector3(size.x, 0.0, size.z),
		base + Vector3(0.0, size.y, size.z),
		base + size,
	]

func _apply_pose_from_alpha(alpha: float) -> void:
	_crouch_alpha = clampf(alpha, 0.0, 1.0)
	_body_height_offset_m = CROUCH_BODY_DROP_M * _ease_in_out(_crouch_alpha)
	if body_pivot != null:
		body_pivot.transform = _initial_body_pivot_transform
		var body_origin := body_pivot.position
		body_origin.y -= _body_height_offset_m
		body_pivot.position = body_origin
	for leg_id in _leg_runtimes_by_id.keys():
		_apply_leg_pose(_leg_runtimes_by_id.get(leg_id, {}), _crouch_alpha)
	_update_pose_state_label()

func _apply_leg_pose(leg_runtime: Dictionary, alpha: float) -> void:
	if leg_runtime.is_empty():
		return
	var hip_pivot := leg_runtime.get("hip_pivot") as Node3D
	var calf_pivot := leg_runtime.get("calf_pivot") as Node3D
	var hip_mesh := leg_runtime.get("hip_mesh") as Node3D
	var calf_mesh := leg_runtime.get("calf_mesh") as Node3D
	if hip_pivot == null or calf_pivot == null or hip_mesh == null or calf_mesh == null:
		return
	var hip_joint_local: Vector3 = leg_runtime.get("hip_joint_local", Vector3.ZERO)
	var upper_rest_vector: Vector3 = leg_runtime.get("upper_rest_vector", Vector3.LEFT * 0.25)
	var foot_rest_local: Vector3 = leg_runtime.get("foot_rest_local", Vector3.ZERO)
	var calf_tip_rest_vector: Vector3 = leg_runtime.get("calf_tip_rest_vector", Vector3(0.22, -0.24, 0.0))
	var hip_constraint: Dictionary = JOINT_CONSTRAINTS.get(str(leg_runtime.get("hip_joint_name", "")), {})
	var knee_constraint: Dictionary = JOINT_CONSTRAINTS.get(str(leg_runtime.get("knee_joint_name", "")), {})

	var hip_target_deg := float(leg_runtime.get("hip_target_deg", CROUCH_TARGET_HIP_DEG)) * _ease_in_out(alpha)
	var gait_offsets := _resolve_leg_gait_offsets(leg_runtime)
	hip_target_deg += float(gait_offsets.get("hip_offset_deg", 0.0))
	hip_target_deg = clampf(hip_target_deg, float(hip_constraint.get("min_deg", -60.0)), float(hip_constraint.get("max_deg", 5.0)))
	var hip_angle_rad := deg_to_rad(hip_target_deg)
	var rotated_upper := upper_rest_vector.rotated(Vector3(0.0, 0.0, 1.0), hip_angle_rad)
	var knee_local := hip_joint_local + rotated_upper
	var foot_target_local := foot_rest_local + Vector3(0.0, _body_height_offset_m, 0.0)
	var target_calf_vector := foot_target_local - knee_local
	var calf_angle_deg := _compute_local_z_delta_deg(calf_tip_rest_vector, target_calf_vector)
	calf_angle_deg += float(gait_offsets.get("knee_offset_deg", 0.0))
	calf_angle_deg = clampf(calf_angle_deg, float(knee_constraint.get("min_deg", -80.0)), float(knee_constraint.get("max_deg", 80.0)))

	hip_mesh.transform = leg_runtime.get("hip_mesh_rest_local_transform", hip_mesh.transform)
	calf_mesh.transform = leg_runtime.get("calf_mesh_rest_local_transform", calf_mesh.transform)
	hip_pivot.position = hip_joint_local
	var hip_rotation := hip_pivot.rotation
	hip_rotation.x = 0.0
	hip_rotation.y = 0.0
	hip_rotation.z = deg_to_rad(hip_target_deg)
	hip_pivot.rotation = hip_rotation

	calf_pivot.position = knee_local
	var calf_rotation := calf_pivot.rotation
	calf_rotation.x = 0.0
	calf_rotation.y = 0.0
	calf_rotation.z = deg_to_rad(calf_angle_deg)
	calf_pivot.rotation = calf_rotation

	leg_runtime["current_hip_angle_deg"] = hip_target_deg
	leg_runtime["current_knee_angle_deg"] = calf_angle_deg
	leg_runtime["current_body_to_thigh_angle_deg"] = _compute_body_to_thigh_angle_deg(rotated_upper)
	leg_runtime["current_is_crouched"] = alpha >= 0.99
	_leg_runtimes_by_id[leg_runtime.get("leg_id")] = leg_runtime

func _compute_local_z_delta_deg(from_vector: Vector3, to_vector: Vector3) -> float:
	var from_xy := Vector2(from_vector.x, from_vector.y)
	var to_xy := Vector2(to_vector.x, to_vector.y)
	if from_xy.length() <= 0.0001 or to_xy.length() <= 0.0001:
		return 0.0
	var from_angle := atan2(from_xy.y, from_xy.x)
	var to_angle := atan2(to_xy.y, to_xy.x)
	return rad_to_deg(wrapf(to_angle - from_angle, -PI, PI))

func _compute_body_to_thigh_angle_deg(upper_vector: Vector3) -> float:
	var upper_xy := Vector2(upper_vector.x, upper_vector.y)
	if upper_xy.length() <= 0.0001:
		return 999.0
	var reference := Vector2(-1.0, 0.0)
	var angle := acos(clampf(reference.normalized().dot(upper_xy.normalized()), -1.0, 1.0))
	return rad_to_deg(angle)

func _ease_in_out(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _build_leg_debug_state() -> Array:
	var legs: Array = []
	var ordered_leg_ids := ["lf", "rf", "lr", "rr"]
	for leg_id in ordered_leg_ids:
		var leg_runtime: Dictionary = _leg_runtimes_by_id.get(leg_id, {})
		if leg_runtime.is_empty():
			continue
		legs.append({
			"leg_id": leg_id,
			"hip_joint_name": str(leg_runtime.get("hip_joint_name", "")),
			"knee_joint_name": str(leg_runtime.get("knee_joint_name", "")),
			"hip_angle_deg": float(leg_runtime.get("current_hip_angle_deg", 0.0)),
			"knee_angle_deg": float(leg_runtime.get("current_knee_angle_deg", 0.0)),
			"body_to_thigh_angle_deg": float(leg_runtime.get("current_body_to_thigh_angle_deg", 999.0)),
			"crouch_target_hip_angle_deg": float(leg_runtime.get("hip_target_deg", CROUCH_TARGET_HIP_DEG)),
			"is_crouched": bool(leg_runtime.get("current_is_crouched", false)),
		})
	return legs

func _update_pose_state_label() -> void:
	if _crouch_requested:
		_pose_state = "crouched" if _crouch_alpha >= 0.99 else "transition_to_crouched"
		return
	_pose_state = "standing" if _crouch_alpha <= 0.01 else "transition_to_standing"

func _update_locomotion_state(delta: float) -> void:
	_locomotion_state = _resolve_locomotion_state()
	var gait_profile := _resolve_gait_profile()
	_gait_cycle_hz = float(gait_profile.get("cycle_hz", 0.0))
	_gait_stride_direction = float(gait_profile.get("stride_direction", 0.0))
	if _gait_cycle_hz > 0.0:
		_gait_cycle_phase_rad = wrapf(_gait_cycle_phase_rad + TAU * _gait_cycle_hz * maxf(delta, 0.0), 0.0, TAU)
	else:
		_gait_cycle_phase_rad = 0.0

func _resolve_locomotion_state() -> String:
	if _crouch_requested or _crouch_alpha > 0.05:
		return LOCOMOTION_STATE_PRONE
	var forward_axis := _move_input.y
	var turn_axis := _turn_input
	var has_forward_motion := absf(forward_axis) > INPUT_DEADZONE
	var has_turn_motion := absf(turn_axis) > INPUT_DEADZONE
	if not has_forward_motion and not has_turn_motion:
		return LOCOMOTION_STATE_IDLE
	if not has_forward_motion:
		return LOCOMOTION_STATE_TURN_LEFT if turn_axis < 0.0 else LOCOMOTION_STATE_TURN_RIGHT
	if forward_axis < 0.0:
		return LOCOMOTION_STATE_BACKWARD if not has_turn_motion else LOCOMOTION_STATE_TURN_MOVE
	if has_turn_motion:
		return LOCOMOTION_STATE_TURN_MOVE
	return LOCOMOTION_STATE_RUN if _sprint_requested else LOCOMOTION_STATE_WALK

func _resolve_gait_profile() -> Dictionary:
	match _locomotion_state:
		LOCOMOTION_STATE_WALK:
			return {"cycle_hz": 1.25, "hip_amp_deg": 7.5, "knee_amp_deg": 10.0, "stride_direction": 1.0}
		LOCOMOTION_STATE_RUN:
			return {"cycle_hz": 2.35, "hip_amp_deg": 12.0, "knee_amp_deg": 15.0, "stride_direction": 1.0}
		LOCOMOTION_STATE_BACKWARD:
			return {"cycle_hz": 1.1, "hip_amp_deg": 6.5, "knee_amp_deg": 8.5, "stride_direction": -1.0}
		LOCOMOTION_STATE_TURN_LEFT:
			return {"cycle_hz": 1.15, "hip_amp_deg": 6.5, "knee_amp_deg": 8.0, "stride_direction": 0.0}
		LOCOMOTION_STATE_TURN_RIGHT:
			return {"cycle_hz": 1.15, "hip_amp_deg": 6.5, "knee_amp_deg": 8.0, "stride_direction": 0.0}
		LOCOMOTION_STATE_TURN_MOVE:
			var forward_cycle_hz := 2.05 if _sprint_requested and _move_input.y > INPUT_DEADZONE else 1.45
			var forward_hip_amp_deg := 11.0 if _sprint_requested and _move_input.y > INPUT_DEADZONE else 8.5
			var forward_knee_amp_deg := 13.5 if _sprint_requested and _move_input.y > INPUT_DEADZONE else 10.5
			var stride_direction := -1.0 if _move_input.y < -INPUT_DEADZONE else 1.0
			return {
				"cycle_hz": forward_cycle_hz,
				"hip_amp_deg": forward_hip_amp_deg,
				"knee_amp_deg": forward_knee_amp_deg,
				"stride_direction": stride_direction,
			}
		_:
			return {"cycle_hz": 0.0, "hip_amp_deg": 0.0, "knee_amp_deg": 0.0, "stride_direction": 0.0}

func _resolve_leg_gait_offsets(leg_runtime: Dictionary) -> Dictionary:
	var gait_profile := _resolve_gait_profile()
	var cycle_hz := float(gait_profile.get("cycle_hz", 0.0))
	if cycle_hz <= 0.0 or _locomotion_state == LOCOMOTION_STATE_PRONE:
		return {
			"hip_offset_deg": 0.0,
			"knee_offset_deg": 0.0,
		}
	var phase_offset := float(leg_runtime.get("gait_phase_offset_rad", 0.0))
	var side_sign := float(leg_runtime.get("side_sign", 1.0))
	var phase := _gait_cycle_phase_rad + phase_offset
	var hip_wave := sin(phase)
	var lift_wave := maxf(0.0, sin(phase))
	var hip_amp_deg := float(gait_profile.get("hip_amp_deg", 0.0))
	var knee_amp_deg := float(gait_profile.get("knee_amp_deg", 0.0))
	var stride_direction := float(gait_profile.get("stride_direction", 0.0))
	var stride_scale := 1.0
	if _locomotion_state == LOCOMOTION_STATE_TURN_LEFT:
		stride_direction = 0.0
		stride_scale = 0.58 if side_sign < 0.0 else 1.18
		hip_wave = sin(phase) * (1.0 if side_sign > 0.0 else -1.0)
	elif _locomotion_state == LOCOMOTION_STATE_TURN_RIGHT:
		stride_direction = 0.0
		stride_scale = 1.18 if side_sign < 0.0 else 0.58
		hip_wave = sin(phase) * (1.0 if side_sign < 0.0 else -1.0)
	elif _locomotion_state == LOCOMOTION_STATE_TURN_MOVE:
		var turn_bias := clampf(_turn_input, -1.0, 1.0)
		stride_scale = clampf(1.0 - turn_bias * side_sign * 0.42, 0.55, 1.45)
	var hip_offset_deg := hip_wave * hip_amp_deg * maxf(stride_scale, 0.2)
	if absf(stride_direction) > 0.01:
		hip_offset_deg *= stride_direction
	var knee_offset_deg := lift_wave * knee_amp_deg * maxf(stride_scale, 0.35)
	return {
		"hip_offset_deg": hip_offset_deg,
		"knee_offset_deg": knee_offset_deg,
	}

func _get_joint_anchor_node(joint_anchor_name: String) -> Marker3D:
	if joint_anchor_root == null:
		return null
	return joint_anchor_root.get_node_or_null(joint_anchor_name) as Marker3D

func _ensure_leg_visual_pivots() -> void:
	if body_pivot == null or leg_pivot_root == null:
		return
	for leg_id in LEG_CONFIGS.keys():
		var leg_config: Dictionary = LEG_CONFIGS.get(leg_id, {})
		var hip_joint := _get_joint_anchor_node(str(leg_config.get("hip_joint_name", "")))
		var knee_joint := _get_joint_anchor_node(str(leg_config.get("knee_joint_name", "")))
		if hip_joint == null or knee_joint == null:
			continue
		var leg_root := leg_pivot_root.get_node_or_null(leg_id) as Node3D
		if leg_root == null:
			leg_root = Node3D.new()
			leg_root.name = leg_id
			leg_pivot_root.add_child(leg_root)
		var hip_pivot := leg_root.get_node_or_null("HipPivot") as Node3D
		if hip_pivot == null:
			hip_pivot = Node3D.new()
			hip_pivot.name = "HipPivot"
			leg_root.add_child(hip_pivot)
		var calf_pivot := leg_root.get_node_or_null("CalfPivot") as Node3D
		if calf_pivot == null:
			calf_pivot = Node3D.new()
			calf_pivot.name = "CalfPivot"
			leg_root.add_child(calf_pivot)
		hip_pivot.position = body_pivot.to_local(hip_joint.global_position)
		calf_pivot.position = body_pivot.to_local(knee_joint.global_position)
		_reparent_leg_mesh_if_needed(
			hip_pivot,
			str(leg_config.get("hip_mesh_source_path", "")),
			str(leg_config.get("hip_mesh_name", ""))
		)
		_reparent_leg_mesh_if_needed(
			calf_pivot,
			str(leg_config.get("calf_mesh_source_path", "")),
			str(leg_config.get("calf_mesh_name", ""))
		)

func _reparent_leg_mesh_if_needed(target_pivot: Node3D, source_path: String, mesh_name: String) -> void:
	if target_pivot == null or mesh_name == "":
		return
	var mesh_node := target_pivot.get_node_or_null(mesh_name) as Node3D
	if mesh_node == null and source_path != "":
		mesh_node = get_node_or_null(source_path) as Node3D
	if mesh_node == null or mesh_node.get_parent() == target_pivot:
		return
	mesh_node.reparent(target_pivot, true)

func _reset_leg_visual_rest_pose() -> void:
	for leg_runtime_variant in _leg_runtimes_by_id.values():
		var leg_runtime := leg_runtime_variant as Dictionary
		var hip_pivot := leg_runtime.get("hip_pivot") as Node3D
		var calf_pivot := leg_runtime.get("calf_pivot") as Node3D
		var hip_mesh := leg_runtime.get("hip_mesh") as Node3D
		var calf_mesh := leg_runtime.get("calf_mesh") as Node3D
		if hip_pivot != null:
			hip_pivot.transform = leg_runtime.get("hip_pivot_rest_transform", hip_pivot.transform)
		if calf_pivot != null:
			calf_pivot.transform = leg_runtime.get("calf_pivot_rest_transform", calf_pivot.transform)
		if hip_mesh != null:
			hip_mesh.transform = leg_runtime.get("hip_mesh_rest_local_transform", hip_mesh.transform)
		if calf_mesh != null:
			calf_mesh.transform = leg_runtime.get("calf_mesh_rest_local_transform", calf_mesh.transform)
