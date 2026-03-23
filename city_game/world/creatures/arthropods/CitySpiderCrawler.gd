extends Node3D
class_name CitySpiderCrawler

const CityArthropodLocomotionProfileScript := preload("res://city_game/world/creatures/arthropods/CityArthropodLocomotionProfile.gd")
const CityArthropodCrawlerRuntimeScript := preload("res://city_game/world/creatures/arthropods/CityArthropodCrawlerRuntime.gd")
const CityArthropodFootholdResolverScript := preload("res://city_game/world/creatures/arthropods/CityArthropodFootholdResolver.gd")
const CityArthropodBodySolverScript := preload("res://city_game/world/creatures/arthropods/CityArthropodBodySolver.gd")
const SHARED_RUNTIME_SCRIPT_PATH := "res://city_game/world/creatures/arthropods/CityArthropodCrawlerRuntime.gd"
const DEFAULT_SPIDER_VARIANT_ID := "hybrid_focus"
const REFERENCE_STEP_CONTROLLER_ID := "reference_anchor_prediction_v1"
const REFERENCE_STEP_SCHEDULER_ID := "reference_tetrapod_timer_v2"
const REFERENCE_BODY_SOLVER_ID := "reference_leg_centroid_plane_v3"
const REFERENCE_STOP_STEPPING_AFTER_SECONDS_STILL := 0.42
const REFERENCE_LEG_CENTROID_NORMAL_WEIGHT := 1.0
const REFERENCE_LEG_CENTROID_TANGENT_WEIGHT := 1.0
const REFERENCE_LEG_NORMAL_WEIGHT := 0.4
const REFERENCE_BODY_CENTROID_ADJUST_SPEED := 12.0
const REFERENCE_BODY_NORMAL_ADJUST_SPEED := 10.0
const REFERENCE_BODY_SMOOTHING_FALLBACK_DELTA_SECONDS := 1.0 / 60.0
const REFERENCE_BODY_OBSTACLE_CLEARANCE_MARGIN_M := 0.04
const REFERENCE_GROUP_A := ["lf_front", "rf_mid_a", "lf_mid_b", "rf_rear"]
const REFERENCE_GROUP_B := ["rf_front", "lf_mid_a", "rf_mid_b", "lf_rear"]
const UPPER_LEG_SEGMENT_RADIUS_M := 0.055
const LOWER_LEG_SEGMENT_TOP_RADIUS_M := 0.04
const LOWER_LEG_SEGMENT_BOTTOM_RADIUS_M := 0.028
const KNEE_JOINT_RADIUS_M := 0.08
const FOOT_TIP_RADIUS_M := 0.045
const PROSOMA_BASE_COLOR := Color(0.13, 0.13, 0.16, 1.0)
const ABDOMEN_BASE_COLOR := Color(0.18, 0.17, 0.16, 1.0)
const UPPER_LEG_BASE_COLOR := Color(0.16, 0.16, 0.18, 1.0)
const LOWER_LEG_BASE_COLOR := Color(0.28, 0.24, 0.22, 1.0)
const KNEE_BASE_COLOR := Color(0.66, 0.42, 0.22, 1.0)
const FOOT_BASE_COLOR := Color(0.22, 0.18, 0.16, 1.0)
const WOUNDED_TINT_COLOR := Color(0.62, 0.18, 0.16, 1.0)
const DEAD_TINT_COLOR := Color(0.08, 0.05, 0.05, 1.0)
const HURTBOX_LOCAL_OFFSET := Vector3(0.0, 0.2, 0.22)
const HIT_STUN_MIN_SECONDS := 0.5
const HIT_STUN_MAX_SECONDS := 1.0
const HIT_STUN_DAMAGE_DURATION_SCALE := 0.18
const POUNCE_INTERVAL_MIN_SECONDS := 0.85
const POUNCE_INTERVAL_MAX_SECONDS := 1.65
const POUNCE_DURATION_MIN_SECONDS := 0.48
const POUNCE_DURATION_MAX_SECONDS := 0.76
const POUNCE_SPEED_MULTIPLIER_MIN := 2.20
const POUNCE_SPEED_MULTIPLIER_MAX := 3.10
const POUNCE_LIFT_MIN_M := 0.52
const POUNCE_LIFT_MAX_M := 0.88
const POUNCE_FORWARD_OFFSET_MIN_M := 0.42
const POUNCE_FORWARD_OFFSET_MAX_M := 0.96
const POUNCE_MIN_TRIGGER_SPEED_MPS := 1.2
const BEHAVIOR_GAIT_CYCLE_SCALE_MIN := 0.92
const BEHAVIOR_GAIT_CYCLE_SCALE_MAX := 1.10
const BEHAVIOR_STEP_DURATION_SCALE_MIN := 0.92
const BEHAVIOR_STEP_DURATION_SCALE_MAX := 1.14
const BEHAVIOR_STEP_COOLDOWN_SCALE_MIN := 0.88
const BEHAVIOR_STEP_COOLDOWN_SCALE_MAX := 1.12
const BEHAVIOR_LEG_PHASE_JITTER_MAX := 0.08
const BEHAVIOR_STEP_TRIGGER_JITTER_M := 0.08
const BEHAVIOR_INITIAL_COOLDOWN_MAX_SECONDS := 0.24

const LEG_ORDER := [
	"lf_front",
	"rf_front",
	"lf_mid_a",
	"rf_mid_a",
	"lf_mid_b",
	"rf_mid_b",
	"lf_rear",
	"rf_rear",
]

const LEG_PHASE_OFFSETS := {
	"lf_front": 0.0,
	"rf_front": 0.5,
	"lf_mid_a": 0.5,
	"rf_mid_a": 0.0,
	"lf_mid_b": 0.0,
	"rf_mid_b": 0.5,
	"lf_rear": 0.5,
	"rf_rear": 0.0,
}

const LEG_STRIDE_SCALES := {
	"lf_front": 1.0,
	"rf_front": 1.0,
	"lf_mid_a": 1.0,
	"rf_mid_a": 1.0,
	"lf_mid_b": 1.0,
	"rf_mid_b": 1.0,
	"lf_rear": 1.0,
	"rf_rear": 1.0,
}

@export var spider_variant_id := DEFAULT_SPIDER_VARIANT_ID
@export var behavior_seed := 0
@export var gait_phase_duration_seconds := 1.6
@export var gait_duty_factor := 0.62
@export var body_clearance_m := 0.72
@export var step_height_m := 0.22
@export var replan_distance_m := 0.58
@export var max_health := 12.0
@export_range(0.1, 1.0, 0.05) var heavy_hit_damage_multiplier := 0.45

@onready var body_pivot: Node3D = $BodyPivot
@onready var prosoma_mesh: MeshInstance3D = $BodyPivot/ProsomaMesh
@onready var abdomen_mesh: MeshInstance3D = $BodyPivot/AbdomenMesh
@onready var enemy_hurtbox: AnimatableBody3D = $EnemyHurtbox
@onready var enemy_hurtbox_shape: CollisionShape3D = $EnemyHurtbox/CollisionShape3D
@onready var leg_socket_root: Node3D = $LegSockets
@onready var leg_visual_root: Node3D = $LegVisualRoot
@onready var foot_debug_root: Node3D = $FootDebugRoot

var _profile: CityArthropodLocomotionProfile = null
var _runtime: CityArthropodCrawlerRuntime = null
var _foothold_resolver: CityArthropodFootholdResolver = null
var _body_solver: CityArthropodBodySolver = null
var _active_variant_contract: Dictionary = {}
var _socket_offsets_by_leg_id: Dictionary = {}
var _default_foothold_offsets_by_leg_id: Dictionary = {}
var _stride_scale_by_leg_id: Dictionary = {}
var _stride_length_by_leg_id: Dictionary = {}
var _leg_visual_contracts_by_leg_id: Dictionary = {}
var _phase_offsets_by_leg_id: Dictionary = LEG_PHASE_OFFSETS.duplicate(true)
var _gait_profile_id := "tetrapod_ground"
var _reference_step_clock := 0.0
var _reference_active_group_id := "A"
var _reference_next_group_switch_time := 0.0
var _reference_group_step_time_seconds := 0.0
var _reference_group_switch_count := 0
var _reference_time_standing_still_seconds := 0.0
var _reference_body_is_moving := false
var _reference_last_body_anchor_world_position := Vector3.ZERO
var _initial_step_cooldown_by_leg_id: Dictionary = {}
var _reference_step_states_by_leg_id: Dictionary = {}
var _leg_visual_nodes_by_leg_id: Dictionary = {}
var _foot_debug_nodes_by_leg_id: Dictionary = {}
var _initial_anchor_world_position := Vector3.ZERO
var _auto_step_enabled := false
var _debug_motion_velocity := Vector3.ZERO
var _health := 0.0
var _dead := false
var _last_hit_world_position := Vector3.ZERO
var _last_hit_impulse := Vector3.ZERO
var _behavior_profile_rng := RandomNumberGenerator.new()
var _behavior_runtime_rng := RandomNumberGenerator.new()
var _gait_cycle_scale := 1.0
var _step_duration_scale := 1.0
var _step_cooldown_scale := 1.0
var _reference_step_clock_bias_seconds := 0.0
var _hit_stun_remaining_seconds := 0.0
var _pounce_cooldown_remaining_seconds := 0.0
var _pounce_elapsed_seconds := 0.0
var _pounce_duration_seconds := 0.0
var _pounce_speed_multiplier := 1.0
var _pounce_lift_peak_m := 0.0
var _pounce_forward_offset_m := 0.0
var _current_pounce_lift_m := 0.0
var _current_pounce_forward_offset_m := 0.0
var _pounce_total_count := 0
var _reference_body_visual_initialized := false
var _reference_last_solver_delta_seconds := REFERENCE_BODY_SMOOTHING_FALLBACK_DELTA_SECONDS
var _last_runtime_state: Dictionary = {}
var _last_leg_visual_state: Array = []
var _last_stable_body_target_transform := {
	"origin": Vector3.ZERO,
	"support_center": Vector3.ZERO,
	"up": Vector3.UP,
	"grounded_leg_count": 0,
}
var _upper_leg_segment_mesh: CylinderMesh = null
var _lower_leg_segment_mesh: CylinderMesh = null
var _upper_leg_material: StandardMaterial3D = null
var _lower_leg_material: StandardMaterial3D = null
var _knee_joint_mesh: SphereMesh = null
var _knee_joint_material: StandardMaterial3D = null
var _foot_tip_mesh: SphereMesh = null
var _foot_tip_material: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("city_spider_crawler")
	_ensure_unique_visual_materials()
	_initial_anchor_world_position = global_position
	_reference_last_body_anchor_world_position = global_position
	_apply_spider_variant()
	_reset_behavior_runtime_state()
	_cache_leg_socket_offsets()
	_initialize_reference_step_states()
	_ensure_leg_visual_nodes()
	_cache_foot_debug_nodes()
	_rebuild_runtime()
	reset_health_state()
	debug_force_replan_all_legs()
	_sync_visual_state_from_runtime()
	_sync_enemy_hurtbox_transform()

func _process(delta: float) -> void:
	if _dead:
		return
	if not _auto_step_enabled:
		return
	tick_crawler(delta)

func _physics_process(_delta: float) -> void:
	_sync_enemy_hurtbox_transform()

func set_auto_step_enabled(enabled: bool) -> void:
	_auto_step_enabled = enabled

func set_debug_motion_velocity(velocity: Vector3) -> void:
	_debug_motion_velocity = velocity

func set_behavior_seed(seed_value: int) -> void:
	behavior_seed = seed_value
	_apply_spider_variant()
	_reset_behavior_runtime_state()
	if not is_inside_tree():
		return
	_initialize_reference_step_states()
	_rebuild_runtime()
	debug_force_replan_all_legs()
	_sync_visual_state_from_runtime()
	_sync_enemy_hurtbox_transform()

func tick_crawler(delta: float) -> void:
	if _runtime == null or _dead:
		return
	var resolved_delta := maxf(delta, 0.0)
	_reference_last_solver_delta_seconds = resolved_delta
	if _hit_stun_remaining_seconds > 0.0:
		_hit_stun_remaining_seconds = maxf(_hit_stun_remaining_seconds - resolved_delta, 0.0)
		if _is_pounce_active():
			_cancel_pounce(false)
		_update_reference_motion_state(resolved_delta)
		_sync_visual_state_from_runtime()
		return
	_update_pounce_state(resolved_delta)
	var resolved_motion_velocity := _debug_motion_velocity
	if _is_pounce_active():
		resolved_motion_velocity *= _pounce_speed_multiplier
	global_position += resolved_motion_velocity * resolved_delta
	_update_reference_motion_state(resolved_delta)
	_reference_step_clock += resolved_delta
	_update_reference_step_manager(resolved_delta)
	_runtime.tick(resolved_delta)
	_sync_visual_state_from_runtime()

func reset_crawler_state() -> void:
	_auto_step_enabled = false
	_debug_motion_velocity = Vector3.ZERO
	global_position = _initial_anchor_world_position
	_reference_body_visual_initialized = false
	_reference_last_solver_delta_seconds = REFERENCE_BODY_SMOOTHING_FALLBACK_DELTA_SECONDS
	_reference_last_body_anchor_world_position = global_position
	_reset_behavior_runtime_state()
	_initialize_reference_step_states()
	_rebuild_runtime()
	debug_force_replan_all_legs()
	_sync_visual_state_from_runtime()
	_set_hurtbox_enabled(true)

func teleport_body_to_world_position(world_position: Vector3) -> void:
	global_position = world_position
	_reference_body_visual_initialized = false
	_reference_last_solver_delta_seconds = REFERENCE_BODY_SMOOTHING_FALLBACK_DELTA_SECONDS
	_reference_last_body_anchor_world_position = global_position
	_reset_behavior_runtime_state()
	_initialize_reference_step_states()
	_rebuild_runtime()
	debug_force_replan_all_legs()
	_sync_visual_state_from_runtime()

func debug_force_replan_all_legs() -> void:
	if _runtime == null:
		return
	for leg_id in LEG_ORDER:
		var desired_foothold := _compute_desired_foothold(leg_id, 0.0)
		_runtime.replan_leg_foothold(leg_id, desired_foothold)
	_sync_visual_state_from_runtime()

func get_debug_state() -> Dictionary:
	var state: Dictionary = _last_runtime_state.duplicate(true)
	state["species_id"] = "spider"
	state["variant_id"] = spider_variant_id
	state["visual_profile_id"] = str(_active_variant_contract.get("visual_profile_id", ""))
	state["step_controller_id"] = REFERENCE_STEP_CONTROLLER_ID
	state["step_scheduler_id"] = REFERENCE_STEP_SCHEDULER_ID
	state["active_step_group_id"] = _reference_active_group_id
	state["next_group_switch_time"] = _reference_next_group_switch_time
	state["group_step_time_seconds"] = _reference_group_step_time_seconds
	state["group_switch_count"] = _reference_group_switch_count
	state["step_clock_seconds"] = _reference_step_clock
	state["time_until_next_group_switch_seconds"] = maxf(_reference_next_group_switch_time - _reference_step_clock, 0.0)
	state["body_solver_id"] = REFERENCE_BODY_SOLVER_ID
	state["time_standing_still_seconds"] = _reference_time_standing_still_seconds
	state["stop_stepping_after_seconds_still"] = REFERENCE_STOP_STEPPING_AFTER_SECONDS_STILL
	state["body_is_moving"] = _reference_body_is_moving
	state["body_anchor_world_position"] = global_position
	state["body_visual_world_position"] = body_pivot.global_position if body_pivot != null else global_position
	state["debug_motion_velocity"] = _debug_motion_velocity
	state["auto_step_enabled"] = _auto_step_enabled
	state["socket_leg_count"] = _socket_offsets_by_leg_id.size()
	state["health_state"] = get_health_state()
	state["behavior_seed"] = behavior_seed
	state["gait_cycle_scale"] = _gait_cycle_scale
	state["step_duration_scale"] = _step_duration_scale
	state["step_cooldown_scale"] = _step_cooldown_scale
	state["reference_step_clock_bias_seconds"] = _reference_step_clock_bias_seconds
	state["hit_stun_remaining_seconds"] = _hit_stun_remaining_seconds
	state["pounce_active"] = _is_pounce_active()
	state["pounce_cooldown_remaining_seconds"] = _pounce_cooldown_remaining_seconds
	state["pounce_total_count"] = _pounce_total_count
	state["pounce_lift_m"] = _current_pounce_lift_m
	state["pounce_forward_offset_m"] = _current_pounce_forward_offset_m
	state["last_hit_world_position"] = _last_hit_world_position
	state["last_hit_impulse"] = _last_hit_impulse
	state["alive"] = not _dead
	state["hurtbox_enabled"] = enemy_hurtbox_shape != null and not enemy_hurtbox_shape.disabled
	state["leg_visuals"] = get_leg_visual_state()
	return state

func get_health_state() -> Dictionary:
	return {
		"current": maxf(_health, 0.0),
		"max": maxf(max_health, 0.0),
		"ratio": clampf(_health / maxf(max_health, 0.001), 0.0, 1.0),
		"alive": not _dead,
		"last_hit_world_position": _last_hit_world_position,
	}

func get_combat_target_world_position() -> Vector3:
	if enemy_hurtbox != null:
		return enemy_hurtbox.global_position
	if body_pivot != null:
		return body_pivot.global_position + body_pivot.global_basis.y * 0.18
	return global_position + Vector3.UP * 0.8

func is_alive() -> bool:
	return not _dead

func reset_health_state() -> void:
	_health = maxf(max_health, 1.0)
	_dead = false
	_last_hit_world_position = Vector3.ZERO
	_last_hit_impulse = Vector3.ZERO
	_hit_stun_remaining_seconds = 0.0
	_cancel_pounce(false)
	_set_hurtbox_enabled(true)
	_update_combat_visual_feedback()

func apply_projectile_hit(projectile_damage: float, hit_position: Vector3, impulse: Vector3) -> Dictionary:
	if _dead:
		return {
			"accepted": false,
			"reason": "already_dead",
		}
	var incoming_damage := maxf(projectile_damage, 0.0)
	if incoming_damage <= 0.0:
		return {
			"accepted": false,
			"reason": "non_positive_damage",
		}
	var resolved_damage := incoming_damage if incoming_damage <= 1.0 else incoming_damage * heavy_hit_damage_multiplier
	_last_hit_world_position = hit_position
	_last_hit_impulse = impulse
	_health = maxf(_health - resolved_damage, 0.0)
	if _health <= 0.0:
		_enter_dead_state()
	else:
		_hit_stun_remaining_seconds = maxf(_hit_stun_remaining_seconds, _compute_hit_stun_duration_seconds(resolved_damage))
		_cancel_pounce(true)
		_update_combat_visual_feedback()
	return {
		"accepted": true,
		"damage": resolved_damage,
		"current_health": _health,
		"alive": not _dead,
	}

func get_profile_contract() -> Dictionary:
	if _profile == null:
		return _build_profile_contract().duplicate(true)
	return _profile.get_contract()

func get_leg_visual_state() -> Array:
	var copy: Array = []
	for leg_variant in _last_leg_visual_state:
		if not (leg_variant is Dictionary):
			continue
		copy.append((leg_variant as Dictionary).duplicate(true))
	return copy

func get_portability_contract() -> Dictionary:
	return {
		"species_id": "spider",
		"wrapper_kind": "species_crawler",
		"shared_runtime_script_path": SHARED_RUNTIME_SCRIPT_PATH,
		"world_anchor": {
			"kind": "external_anchor_node3d",
			"default_mode": "species_root_transform",
		},
		"ground_resolver": {
			"kind": "callable",
			"default_mode": "species_wrapper_ground_query",
		},
		"activation_gate": {
			"kind": "bool_gate",
			"default_active": true,
		},
		"spawn_policy": {
			"kind": "external_chunk_gate",
			"default_mode": "lab_always_loaded",
		},
		"debug_passthrough": {
			"method": "get_debug_state",
			"profile_method": "get_profile_contract",
		},
	}.duplicate(true)

func _apply_spider_variant() -> void:
	_active_variant_contract = _build_spider_variant_contract(spider_variant_id)
	if _active_variant_contract.is_empty():
		spider_variant_id = DEFAULT_SPIDER_VARIANT_ID
		_active_variant_contract = _build_spider_variant_contract(spider_variant_id)
	var gait_contract: Dictionary = _active_variant_contract.get("gait", {}) as Dictionary
	_gait_profile_id = str(gait_contract.get("gait_profile_id", "tetrapod_ground"))
	gait_phase_duration_seconds = float(gait_contract.get("phase_duration_seconds", gait_phase_duration_seconds))
	gait_duty_factor = float(gait_contract.get("duty_factor", gait_duty_factor))
	body_clearance_m = float(gait_contract.get("body_clearance_m", body_clearance_m))
	step_height_m = float(gait_contract.get("step_height_m", step_height_m))
	replan_distance_m = float(gait_contract.get("replan_distance_m", replan_distance_m))
	_apply_body_visual_contract(_active_variant_contract.get("body", {}) as Dictionary)
	_apply_leg_layout_contract(_active_variant_contract.get("legs", {}) as Dictionary)
	_apply_behavior_profile_seed()

func _apply_behavior_profile_seed() -> void:
	_gait_cycle_scale = 1.0
	_step_duration_scale = 1.0
	_step_cooldown_scale = 1.0
	_reference_step_clock_bias_seconds = 0.0
	_initial_step_cooldown_by_leg_id.clear()
	_seed_behavior_profile_rng()
	if behavior_seed == 0:
		return
	_gait_cycle_scale = lerpf(BEHAVIOR_GAIT_CYCLE_SCALE_MIN, BEHAVIOR_GAIT_CYCLE_SCALE_MAX, _behavior_profile_rng.randf())
	_step_duration_scale = lerpf(BEHAVIOR_STEP_DURATION_SCALE_MIN, BEHAVIOR_STEP_DURATION_SCALE_MAX, _behavior_profile_rng.randf())
	_step_cooldown_scale = lerpf(BEHAVIOR_STEP_COOLDOWN_SCALE_MIN, BEHAVIOR_STEP_COOLDOWN_SCALE_MAX, _behavior_profile_rng.randf())
	gait_phase_duration_seconds *= _gait_cycle_scale
	_reference_step_clock_bias_seconds = gait_phase_duration_seconds * _behavior_profile_rng.randf_range(0.0, 0.42)
	for leg_id in LEG_ORDER:
		var base_phase: float = float(_phase_offsets_by_leg_id.get(leg_id, LEG_PHASE_OFFSETS.get(leg_id, 0.0)))
		_phase_offsets_by_leg_id[leg_id] = fposmod(base_phase + _behavior_profile_rng.randf_range(-BEHAVIOR_LEG_PHASE_JITTER_MAX, BEHAVIOR_LEG_PHASE_JITTER_MAX), 1.0)
		_initial_step_cooldown_by_leg_id[leg_id] = _behavior_profile_rng.randf_range(0.0, BEHAVIOR_INITIAL_COOLDOWN_MAX_SECONDS)
		var visual_contract: Dictionary = _leg_visual_contracts_by_leg_id.get(leg_id, {}) as Dictionary
		if visual_contract.is_empty():
			continue
		var adjusted_visual_contract := visual_contract.duplicate(true)
		var base_trigger_distance_m: float = float(adjusted_visual_contract.get("step_trigger_distance_m", 0.42))
		adjusted_visual_contract["step_trigger_distance_m"] = maxf(base_trigger_distance_m + _behavior_profile_rng.randf_range(-BEHAVIOR_STEP_TRIGGER_JITTER_M, BEHAVIOR_STEP_TRIGGER_JITTER_M), 0.16)
		var base_duration_gain: float = float(adjusted_visual_contract.get("step_duration_gain", 0.58))
		adjusted_visual_contract["step_duration_gain"] = maxf(base_duration_gain * lerpf(0.92, 1.08, _behavior_profile_rng.randf()), 0.18)
		_leg_visual_contracts_by_leg_id[leg_id] = adjusted_visual_contract

func _apply_body_visual_contract(body_contract: Dictionary) -> void:
	if prosoma_mesh != null:
		prosoma_mesh.position = body_contract.get("prosoma_position", Vector3(0.0, 0.02, 0.20))
		prosoma_mesh.scale = body_contract.get("prosoma_scale", Vector3(1.36, 0.58, 1.18))
	if abdomen_mesh != null:
		abdomen_mesh.position = body_contract.get("abdomen_position", Vector3(0.0, 0.02, -0.76))
		abdomen_mesh.scale = body_contract.get("abdomen_scale", Vector3(1.64, 0.88, 1.92))
	var socket_root_position: Vector3 = body_contract.get("socket_root_position", leg_socket_root.position if leg_socket_root != null else Vector3.ZERO)
	if leg_socket_root != null:
		leg_socket_root.position = socket_root_position
	if foot_debug_root != null:
		foot_debug_root.position = socket_root_position

func _apply_leg_layout_contract(legs_contract: Dictionary) -> void:
	_default_foothold_offsets_by_leg_id.clear()
	_leg_visual_contracts_by_leg_id.clear()
	_phase_offsets_by_leg_id.clear()
	for leg_id in LEG_ORDER:
		var leg_contract: Dictionary = legs_contract.get(leg_id, {}) as Dictionary
		_leg_visual_contracts_by_leg_id[leg_id] = leg_contract.duplicate(true)
		_default_foothold_offsets_by_leg_id[leg_id] = leg_contract.get("foothold_local", Vector3.ZERO)
		_phase_offsets_by_leg_id[leg_id] = float(leg_contract.get("phase_offset", LEG_PHASE_OFFSETS.get(leg_id, 0.0)))
		var socket_node := leg_socket_root.get_node_or_null(leg_id) as Marker3D
		if socket_node != null:
			socket_node.position = leg_contract.get("socket_local", socket_node.position)

func _build_spider_variant_contract(variant_id: String) -> Dictionary:
	match variant_id:
		"morphology_focus":
			return _build_spider_morphology_focus_contract()
		"gait_focus":
			return _build_spider_gait_focus_contract()
		"hybrid_focus":
			return _build_spider_hybrid_focus_contract()
		_:
			return {}

func _build_spider_morphology_focus_contract() -> Dictionary:
	var legs: Dictionary = {}
	_add_mirrored_leg_contracts(legs, "lf_front", "rf_front", 0.78, 0.76, 2.00, 1.58, 0.00, 0.50, 1.08, 0.62, 0.24, 0.20, 0.16, 0.02, 0.16, 0.08)
	_add_mirrored_leg_contracts(legs, "lf_mid_a", "rf_mid_a", 0.96, 0.30, 1.88, 0.98, 0.50, 0.00, 0.96, 0.54, 0.20, 0.24, 0.15, 0.02, 0.14, 0.04)
	_add_mirrored_leg_contracts(legs, "lf_mid_b", "rf_mid_b", 0.98, -0.24, 1.82, -0.82, 0.02, 0.52, 0.90, 0.50, 0.18, 0.26, 0.14, 0.02, 0.13, 0.04)
	_add_mirrored_leg_contracts(legs, "lf_rear", "rf_rear", 0.78, -0.76, 1.62, -1.38, 0.52, 0.02, 0.84, 0.44, 0.16, 0.30, 0.12, 0.02, 0.12, 0.08)
	return {
		"variant_id": "morphology_focus",
		"visual_profile_id": "spider_natural_proxy_morphology",
		"body": {
			"prosoma_position": Vector3(0.0, 0.03, 0.18),
			"prosoma_scale": Vector3(1.42, 0.60, 1.22),
			"abdomen_position": Vector3(0.0, 0.03, -0.80),
			"abdomen_scale": Vector3(1.78, 0.94, 2.02),
			"socket_root_position": Vector3(0.0, 0.32, 0.0),
		},
		"gait": {
			"gait_profile_id": "tetrapod_ground",
			"phase_duration_seconds": 1.54,
			"duty_factor": 0.68,
			"body_clearance_m": 0.58,
			"step_height_m": 0.22,
			"replan_distance_m": 0.64,
		},
		"legs": legs,
	}.duplicate(true)

func _build_spider_gait_focus_contract() -> Dictionary:
	var legs: Dictionary = {}
	_add_mirrored_leg_contracts(legs, "lf_front", "rf_front", 0.74, 0.72, 1.92, 1.46, 0.00, 0.44, 1.04, 0.72, 0.28, 0.22, 0.17, 0.02, 0.20, 0.08)
	_add_mirrored_leg_contracts(legs, "lf_mid_a", "rf_mid_a", 0.92, 0.26, 1.86, 0.90, 0.16, 0.60, 0.98, 0.60, 0.24, 0.26, 0.16, 0.02, 0.18, 0.04)
	_add_mirrored_leg_contracts(legs, "lf_mid_b", "rf_mid_b", 0.96, -0.22, 1.78, -0.72, 0.32, 0.76, 0.90, 0.56, 0.22, 0.28, 0.14, 0.02, 0.16, 0.04)
	_add_mirrored_leg_contracts(legs, "lf_rear", "rf_rear", 0.76, -0.72, 1.56, -1.28, 0.48, 0.92, 0.82, 0.46, 0.18, 0.32, 0.12, 0.02, 0.14, 0.08)
	return {
		"variant_id": "gait_focus",
		"visual_profile_id": "spider_natural_proxy_gait",
		"body": {
			"prosoma_position": Vector3(0.0, 0.03, 0.16),
			"prosoma_scale": Vector3(1.36, 0.58, 1.18),
			"abdomen_position": Vector3(0.0, 0.03, -0.76),
			"abdomen_scale": Vector3(1.68, 0.90, 1.96),
			"socket_root_position": Vector3(0.0, 0.32, 0.0),
		},
		"gait": {
			"gait_profile_id": "tetrapod_ground_async",
			"phase_duration_seconds": 1.38,
			"duty_factor": 0.72,
			"body_clearance_m": 0.56,
			"step_height_m": 0.24,
			"replan_distance_m": 0.46,
		},
		"legs": legs,
	}.duplicate(true)

func _build_spider_hybrid_focus_contract() -> Dictionary:
	var legs: Dictionary = {}
	_add_mirrored_leg_contracts(legs, "lf_front", "rf_front", 0.80, 0.76, 2.08, 1.54, 0.00, 0.46, 1.10, 0.74, 0.30, 0.20, 0.16, 0.02, 0.20, 0.08)
	_add_mirrored_leg_contracts(legs, "lf_mid_a", "rf_mid_a", 0.98, 0.30, 1.98, 0.96, 0.18, 0.62, 0.98, 0.62, 0.25, 0.24, 0.15, 0.02, 0.18, 0.04)
	_add_mirrored_leg_contracts(legs, "lf_mid_b", "rf_mid_b", 1.02, -0.24, 1.90, -0.78, 0.34, 0.80, 0.92, 0.58, 0.22, 0.26, 0.14, 0.02, 0.16, 0.04)
	_add_mirrored_leg_contracts(legs, "lf_rear", "rf_rear", 0.80, -0.78, 1.70, -1.38, 0.50, 0.96, 0.84, 0.48, 0.18, 0.30, 0.12, 0.02, 0.14, 0.08)
	return {
		"variant_id": "hybrid_focus",
		"visual_profile_id": "spider_natural_proxy_hybrid",
		"body": {
			"prosoma_position": Vector3(0.0, 0.03, 0.18),
			"prosoma_scale": Vector3(1.44, 0.60, 1.22),
			"abdomen_position": Vector3(0.0, 0.03, -0.82),
			"abdomen_scale": Vector3(1.84, 0.96, 2.06),
			"socket_root_position": Vector3(0.0, 0.32, 0.0),
		},
		"gait": {
			"gait_profile_id": "tetrapod_ground_async",
			"phase_duration_seconds": 1.46,
			"duty_factor": 0.70,
			"body_clearance_m": 0.58,
			"step_height_m": 0.24,
			"replan_distance_m": 0.50,
		},
		"legs": legs,
	}.duplicate(true)

func _add_mirrored_leg_contracts(
	legs: Dictionary,
	left_leg_id: String,
	right_leg_id: String,
	socket_x: float,
	socket_z: float,
	foothold_x: float,
	foothold_z: float,
	left_phase_offset: float,
	right_phase_offset: float,
	stride_scale: float,
	stride_length_m: float,
	step_height_for_leg_m: float,
	knee_projection_ratio: float,
	knee_lateral_scale: float,
	stance_knee_lift_m: float,
	swing_knee_lift_m: float,
	fore_aft_offset_scale: float
) -> void:
	legs[left_leg_id] = _make_leg_contract(
		Vector3(-socket_x, 0.0, socket_z),
		Vector3(-foothold_x, 0.0, foothold_z),
		left_phase_offset,
		stride_scale,
		stride_length_m,
		step_height_for_leg_m,
		knee_projection_ratio,
		knee_lateral_scale,
		stance_knee_lift_m,
		swing_knee_lift_m,
		fore_aft_offset_scale
	)
	legs[right_leg_id] = _make_leg_contract(
		Vector3(socket_x, 0.0, socket_z),
		Vector3(foothold_x, 0.0, foothold_z),
		right_phase_offset,
		stride_scale,
		stride_length_m,
		step_height_for_leg_m,
		knee_projection_ratio,
		knee_lateral_scale,
		stance_knee_lift_m,
		swing_knee_lift_m,
		fore_aft_offset_scale
	)

func _make_leg_contract(
	socket_local: Vector3,
	foothold_local: Vector3,
	phase_offset: float,
	stride_scale: float,
	stride_length_m: float,
	step_height_for_leg_m: float,
	knee_projection_ratio: float,
	knee_lateral_scale: float,
	stance_knee_lift_m: float,
	swing_knee_lift_m: float,
	fore_aft_offset_scale: float
) -> Dictionary:
	return {
		"socket_local": socket_local,
		"foothold_local": foothold_local,
		"phase_offset": fposmod(phase_offset, 1.0),
		"stride_scale": stride_scale,
		"stride_length_m": stride_length_m,
		"step_height_m": step_height_for_leg_m,
		"knee_projection_ratio": knee_projection_ratio,
		"knee_lateral_scale": knee_lateral_scale,
		"stance_knee_lift_m": stance_knee_lift_m,
		"swing_knee_lift_m": swing_knee_lift_m,
		"fore_aft_offset_scale": fore_aft_offset_scale,
	}.duplicate(true)

func _initialize_reference_step_states() -> void:
	_reset_reference_step_scheduler_state()
	_reference_step_states_by_leg_id.clear()
	for leg_id in LEG_ORDER:
		_reference_step_states_by_leg_id[leg_id] = {
			"is_stepping": false,
			"start_foothold": Vector3.ZERO,
			"goal_foothold": Vector3.ZERO,
			"predicted_target": Vector3.ZERO,
			"default_anchor": Vector3.ZERO,
			"progress": 0.0,
			"duration_seconds": 0.22,
			"cooldown_remaining": float(_initial_step_cooldown_by_leg_id.get(leg_id, 0.0)),
			"surface_normal": Vector3.UP,
		}

func _compute_reference_group_id(leg_id: String) -> String:
	if REFERENCE_GROUP_A.has(leg_id):
		return "A"
	return "B"

func _toggle_reference_group_id(group_id: String) -> String:
	return "B" if group_id == "A" else "A"

func _reset_reference_step_scheduler_state() -> void:
	_reference_step_clock = _reference_step_clock_bias_seconds
	_reference_active_group_id = "A" if (behavior_seed % 2) == 0 else "B"
	_reference_group_step_time_seconds = _compute_reference_max_step_time_seconds()
	_reference_next_group_switch_time = _reference_step_clock + _reference_group_step_time_seconds
	_reference_group_switch_count = 0
	_reference_time_standing_still_seconds = 0.0
	_reference_body_is_moving = false

func _update_reference_motion_state(delta: float) -> void:
	var body_delta := global_position - _reference_last_body_anchor_world_position
	_reference_body_is_moving = body_delta.length_squared() > 0.000001
	if _reference_body_is_moving:
		_reference_time_standing_still_seconds = 0.0
	else:
		_reference_time_standing_still_seconds += delta
	_reference_last_body_anchor_world_position = global_position

func _compute_reference_max_step_time_seconds() -> float:
	var max_duration_s := 0.18
	for leg_id in LEG_ORDER:
		var visual_contract: Dictionary = _leg_visual_contracts_by_leg_id.get(leg_id, {}) as Dictionary
		max_duration_s = maxf(max_duration_s, float(visual_contract.get("step_duration_max_s", 0.28)))
	return maxf(max_duration_s, 0.08)

func _compute_reference_group_step_time_seconds(group_id: String) -> float:
	var group_leg_ids: Array = REFERENCE_GROUP_A if group_id == "A" else REFERENCE_GROUP_B
	var total_duration_s := 0.0
	var leg_count := 0
	for leg_variant in group_leg_ids:
		var leg_id := str(leg_variant)
		if leg_id == "":
			continue
		total_duration_s += _compute_reference_step_duration_seconds(leg_id)
		leg_count += 1
	if leg_count <= 0:
		return _compute_reference_max_step_time_seconds()
	return maxf(total_duration_s / float(leg_count), 0.001)

func _update_reference_step_manager(delta: float) -> void:
	var runtime_state: Dictionary = _runtime.get_debug_state()
	var leg_states: Array = runtime_state.get("legs", [])
	for leg_id in LEG_ORDER:
		var step_state: Dictionary = _reference_step_states_by_leg_id.get(leg_id, {}) as Dictionary
		if step_state.is_empty():
			continue
		if bool(step_state.get("is_stepping", false)):
			_advance_reference_step(leg_id, step_state, delta)
			continue
		step_state["cooldown_remaining"] = maxf(float(step_state.get("cooldown_remaining", 0.0)) - delta, 0.0)
		_reference_step_states_by_leg_id[leg_id] = step_state
	if _reference_step_clock < _reference_next_group_switch_time:
		return
	if _has_any_reference_step_active():
		return
	var active_group_id := _toggle_reference_group_id(_reference_active_group_id)
	var group_step_time_seconds := _compute_reference_group_step_time_seconds(active_group_id)
	_reference_active_group_id = active_group_id
	_reference_group_step_time_seconds = group_step_time_seconds
	_reference_next_group_switch_time = _reference_step_clock + group_step_time_seconds
	_reference_group_switch_count += 1
	for leg_variant in leg_states:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		var leg_id: String = str(leg_state.get("leg_id", ""))
		if leg_id == "" or _compute_reference_group_id(leg_id) != active_group_id:
			continue
		var step_state: Dictionary = _reference_step_states_by_leg_id.get(leg_id, {}) as Dictionary
		if bool(step_state.get("is_stepping", false)):
			continue
		if float(step_state.get("cooldown_remaining", 0.0)) > 0.0:
			continue
		if not _leg_desires_reference_step(leg_id, leg_state):
			continue
		_begin_reference_step(leg_id, leg_state, group_step_time_seconds)

func _has_any_reference_step_active() -> bool:
	for leg_id in LEG_ORDER:
		var step_state: Dictionary = _reference_step_states_by_leg_id.get(leg_id, {}) as Dictionary
		if bool(step_state.get("is_stepping", false)):
			return true
	return false

func _advance_reference_step(leg_id: String, step_state: Dictionary, delta: float) -> void:
	var duration_seconds: float = maxf(float(step_state.get("duration_seconds", 0.22)), 0.001)
	var progress: float = clampf(float(step_state.get("progress", 0.0)) + delta / duration_seconds, 0.0, 1.0)
	step_state["progress"] = progress
	if progress < 1.0:
		_reference_step_states_by_leg_id[leg_id] = step_state
		return
	var goal_foothold: Vector3 = step_state.get("goal_foothold", Vector3.ZERO)
	_runtime.replan_leg_foothold(leg_id, goal_foothold)
	step_state["is_stepping"] = false
	step_state["progress"] = 1.0
	step_state["cooldown_remaining"] = duration_seconds * 0.55 * _step_cooldown_scale
	_reference_step_states_by_leg_id[leg_id] = step_state

func _leg_desires_reference_step(leg_id: String, leg_state: Dictionary) -> bool:
	var step_state: Dictionary = _reference_step_states_by_leg_id.get(leg_id, {}) as Dictionary
	if bool(step_state.get("is_stepping", false)):
		return false
	if _reference_time_standing_still_seconds > REFERENCE_STOP_STEPPING_AFTER_SECONDS_STILL:
		return false
	var anchor_world_position := _compute_default_anchor_world_position(leg_id)
	var locked_foothold: Vector3 = leg_state.get("locked_foothold", anchor_world_position)
	var root_world_position := _resolve_socket_world_position(_socket_offsets_by_leg_id.get(leg_id, Vector3.ZERO))
	var visual_contract: Dictionary = _leg_visual_contracts_by_leg_id.get(leg_id, {}) as Dictionary
	var trigger_distance_m: float = maxf(float(visual_contract.get("step_trigger_distance_m", 0.42)), 0.08)
	var min_root_distance_m: float = maxf(float(visual_contract.get("step_min_root_distance_m", 0.48)), 0.10)
	return locked_foothold.distance_to(anchor_world_position) > trigger_distance_m or locked_foothold.distance_to(root_world_position) < min_root_distance_m

func _begin_reference_step(leg_id: String, leg_state: Dictionary, duration_seconds: float) -> void:
	var step_state: Dictionary = _reference_step_states_by_leg_id.get(leg_id, {}) as Dictionary
	var locked_foothold: Vector3 = leg_state.get("locked_foothold", global_position)
	var default_anchor_world_position := _compute_default_anchor_world_position(leg_id)
	var prediction: Vector3 = _compute_reference_step_prediction(leg_id, locked_foothold, default_anchor_world_position, duration_seconds)
	var resolved: Dictionary = _resolve_reference_step_surface_target(leg_id, prediction, default_anchor_world_position)
	step_state["is_stepping"] = true
	step_state["start_foothold"] = locked_foothold
	step_state["goal_foothold"] = resolved.get("world_position", prediction)
	step_state["predicted_target"] = prediction
	step_state["default_anchor"] = default_anchor_world_position
	step_state["progress"] = 0.0
	step_state["duration_seconds"] = duration_seconds
	step_state["surface_normal"] = resolved.get("surface_normal", Vector3.UP)
	step_state["surface_search_source"] = str(resolved.get("source", "fallback_flat_ground"))
	step_state["surface_search_candidates"] = (resolved.get("candidate_ids", []) as Array).duplicate(true)
	_reference_step_states_by_leg_id[leg_id] = step_state

func _compute_reference_step_duration_seconds(leg_id: String) -> float:
	var speed_mps := _debug_motion_velocity.length()
	var visual_contract: Dictionary = _leg_visual_contracts_by_leg_id.get(leg_id, {}) as Dictionary
	var duration_gain: float = maxf(float(visual_contract.get("step_duration_gain", 0.58)), 0.01)
	var max_duration_s: float = maxf(float(visual_contract.get("step_duration_max_s", 0.28)), 0.08)
	var min_duration_s: float = clampf(float(visual_contract.get("step_duration_min_s", 0.14)), 0.05, max_duration_s)
	if speed_mps <= 0.05:
		return max_duration_s * _step_duration_scale
	var base_duration_s := clampf(duration_gain / speed_mps, min_duration_s, max_duration_s)
	return clampf(base_duration_s * _step_duration_scale, min_duration_s * 0.85, max_duration_s * 1.2)

func _compute_reference_step_prediction(leg_id: String, locked_foothold: Vector3, default_anchor_world_position: Vector3, duration_seconds: float) -> Vector3:
	var visual_contract: Dictionary = _leg_visual_contracts_by_leg_id.get(leg_id, {}) as Dictionary
	var step_frame_up := _get_reference_step_frame_up()
	var projected_start := locked_foothold - step_frame_up * (locked_foothold - default_anchor_world_position).dot(step_frame_up)
	var overshoot_multiplier: float = maxf(float(visual_contract.get("step_overshoot_multiplier", 1.25)), 1.0)
	var desired_position := projected_start + (default_anchor_world_position - projected_start) * overshoot_multiplier
	return desired_position + _debug_motion_velocity * duration_seconds

func _rebuild_runtime() -> void:
	if _runtime != null and is_instance_valid(_runtime):
		remove_child(_runtime)
		_runtime.queue_free()
	_profile = CityArthropodLocomotionProfileScript.new()
	_profile.configure(_build_profile_contract())
	_foothold_resolver = CityArthropodFootholdResolverScript.new()
	_foothold_resolver.configure(Callable(self, "_resolve_ground_foothold"))
	_body_solver = CityArthropodBodySolverScript.new()
	_runtime = CityArthropodCrawlerRuntimeScript.new()
	_runtime.name = "SharedRuntime"
	add_child(_runtime)
	_runtime.configure(_profile, _foothold_resolver, _body_solver)
	_last_runtime_state = _runtime.get_debug_state()

func _build_profile_contract() -> Dictionary:
	var legs: Array = []
	_stride_scale_by_leg_id.clear()
	_stride_length_by_leg_id.clear()
	for leg_id in LEG_ORDER:
		var leg_variant: Dictionary = _leg_visual_contracts_by_leg_id.get(leg_id, {}) as Dictionary
		var default_foothold: Vector3 = _default_foothold_offsets_by_leg_id.get(leg_id, _socket_offsets_by_leg_id.get(leg_id, Vector3.ZERO))
		var stride_scale: float = float(leg_variant.get("stride_scale", LEG_STRIDE_SCALES.get(leg_id, 1.0)))
		var stride_length_m: float = float(leg_variant.get("stride_length_m", step_height_m * 1.6))
		_stride_scale_by_leg_id[leg_id] = stride_scale
		_stride_length_by_leg_id[leg_id] = stride_length_m
		legs.append({
			"leg_id": leg_id,
			"phase_offset": float(_phase_offsets_by_leg_id.get(leg_id, LEG_PHASE_OFFSETS.get(leg_id, 0.0))),
			"default_foothold": default_foothold,
			"step_height_m": float(leg_variant.get("step_height_m", step_height_m)),
			"stride_scale": stride_scale,
		})
	return {
		"profile_id": "arthropod_spider_ground_v1",
		"species_id": "spider",
		"gait_profile_id": _gait_profile_id,
		"phase_duration_seconds": gait_phase_duration_seconds,
		"duty_factor": gait_duty_factor,
		"body_clearance_m": body_clearance_m,
		"legs": legs,
	}

func _request_runtime_replans(leg_states: Array) -> void:
	for leg_variant in leg_states:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		var leg_id: String = str(leg_state.get("leg_id", ""))
		if leg_id == "":
			continue
		var mode: String = str(leg_state.get("mode", "stance"))
		if mode == "stance":
			continue
		var locked_foothold: Vector3 = leg_state.get("locked_foothold", Vector3.ZERO)
		var desired_foothold := _compute_desired_foothold(leg_id, float(leg_state.get("phase", 0.0)))
		if locked_foothold.distance_to(desired_foothold) < replan_distance_m:
			continue
		_runtime.replan_leg_foothold(leg_id, desired_foothold)

func _compute_desired_foothold(leg_id: String, phase: float) -> Vector3:
	var foothold_offset: Vector3 = _default_foothold_offsets_by_leg_id.get(leg_id, _socket_offsets_by_leg_id.get(leg_id, Vector3.ZERO))
	var stride_scale: float = float(_stride_scale_by_leg_id.get(leg_id, 1.0))
	var stride_length_m: float = float(_stride_length_by_leg_id.get(leg_id, step_height_m * 1.6))
	var motion_direction := _debug_motion_velocity
	if motion_direction.length_squared() > 0.0001:
		motion_direction = motion_direction.normalized()
	else:
		motion_direction = Vector3.FORWARD
	var stride_offset := motion_direction * sin(phase * TAU) * stride_length_m * stride_scale
	return global_position + foothold_offset + stride_offset

func _resolve_ground_foothold(_leg_id: String, desired_foothold: Vector3) -> Dictionary:
	if get_world_3d() == null:
		var fallback_position := desired_foothold
		fallback_position.y = 0.0
		return {
			"success": true,
			"world_position": fallback_position,
			"surface_normal": Vector3.UP,
			"source": "fallback_flat_ground",
		}
	var ray_start := desired_foothold + Vector3.UP * 24.0
	var ray_end := desired_foothold + Vector3.DOWN * 24.0
	var hit: Dictionary = _intersect_environment_ray(ray_start, ray_end)
	if hit.is_empty():
		var projected := desired_foothold
		projected.y = 0.0
		return {
			"success": true,
			"world_position": projected,
			"surface_normal": Vector3.UP,
			"source": "fallback_flat_ground",
		}
	return {
		"success": true,
		"world_position": hit.get("position", desired_foothold),
		"surface_normal": hit.get("normal", Vector3.UP),
		"source": "physics_ray",
	}

func _resolve_reference_step_surface_target(leg_id: String, prediction: Vector3, default_anchor_world_position: Vector3) -> Dictionary:
	var candidate_specs := _build_reference_surface_search_candidates(leg_id, prediction, default_anchor_world_position)
	var candidate_ids: Array = []
	for candidate_variant in candidate_specs:
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant as Dictionary
		candidate_ids.append(str(candidate.get("id", "")))
	candidate_ids.append("fallback_flat_ground")
	for candidate_variant in candidate_specs:
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant as Dictionary
		var result := _cast_reference_surface_candidate(candidate)
		if bool(result.get("success", false)):
			result["candidate_ids"] = candidate_ids.duplicate(true)
			return result
	var fallback := _resolve_ground_foothold(leg_id, prediction)
	fallback["candidate_ids"] = candidate_ids.duplicate(true)
	fallback["source"] = "fallback_flat_ground"
	return fallback

func _build_reference_surface_search_candidates(leg_id: String, prediction: Vector3, default_anchor_world_position: Vector3) -> Array:
	var step_frame_up := _get_reference_step_frame_up()
	var body_center := global_position
	var top_focus := body_center + step_frame_up * maxf(body_clearance_m * 1.5, 0.9)
	var bottom_focus := body_center - step_frame_up * maxf(body_clearance_m * 1.8, 1.1)
	var frontal_height := maxf(body_clearance_m * 0.85, 0.6)
	var frontal_length := maxf(body_clearance_m * 2.8, 1.8)
	var down_height := maxf(body_clearance_m * 2.0, 1.2)
	var down_depth := maxf(body_clearance_m * 3.0, 1.8)
	var candidates: Array = []
	for target_spec in [
		{"family": "prediction", "target": prediction},
		{"family": "default", "target": default_anchor_world_position},
	]:
		var family := str((target_spec as Dictionary).get("family", "prediction"))
		var target := (target_spec as Dictionary).get("target", prediction) as Vector3
		var frontal_start := body_center + step_frame_up * frontal_height
		var frontal_direction := (target - frontal_start) - step_frame_up * (target - frontal_start).dot(step_frame_up)
		if frontal_direction.length_squared() <= 0.0001:
			frontal_direction = (target - body_center)
		frontal_direction = frontal_direction.normalized() if frontal_direction.length_squared() > 0.0001 else -global_basis.z.normalized()
		var frontal_origin := frontal_start.lerp(frontal_start + frontal_direction * frontal_length, 0.25)
		var top_end := top_focus + (target - top_focus) * 2.0
		var out_origin := top_focus.lerp(target, 0.22)
		var out_end := target.lerp(top_end, 0.28)
		var down_origin := target + step_frame_up * down_height
		var down_end := target - step_frame_up * down_depth
		var in_close_end := body_center - step_frame_up * maxf(body_clearance_m, 0.6)
		var in_mid_end := body_center - step_frame_up * maxf(body_clearance_m * 1.6, 1.0)
		var in_far_end := target.lerp(bottom_focus, 0.58)
		candidates.append({"id": "%s_frontal" % family, "start": frontal_origin, "end": frontal_start + frontal_direction * frontal_length})
		candidates.append({"id": "%s_out" % family, "start": out_origin, "end": out_end})
		candidates.append({"id": "%s_down" % family, "start": down_origin, "end": down_end})
		candidates.append({"id": "%s_in_far" % family, "start": target, "end": in_far_end})
		candidates.append({"id": "%s_in_mid" % family, "start": target, "end": in_mid_end})
		candidates.append({"id": "%s_in_close" % family, "start": target, "end": in_close_end})
	return candidates

func _cast_reference_surface_candidate(candidate: Dictionary) -> Dictionary:
	if get_world_3d() == null:
		return {"success": false}
	var start := candidate.get("start", Vector3.ZERO) as Vector3
	var end := candidate.get("end", Vector3.ZERO) as Vector3
	var hit: Dictionary = _intersect_environment_ray(start, end)
	if hit.is_empty():
		return {"success": false}
	return {
		"success": true,
		"world_position": hit.get("position", end),
		"surface_normal": hit.get("normal", Vector3.UP),
		"source": str(candidate.get("id", "")),
	}

func _sync_visual_state_from_runtime() -> void:
	if _runtime == null:
		return
	_last_runtime_state = _runtime.get_debug_state()
	if _dead:
		_last_runtime_state["body_target_transform"] = _last_runtime_state.get("body_target_transform", {})
		_sync_enemy_hurtbox_transform()
		return
	var postprocessed_leg_states := _build_reference_leg_states(_last_runtime_state.get("legs", []))
	_last_runtime_state["legs"] = postprocessed_leg_states
	_last_runtime_state["body_target_transform"] = _compute_reference_body_target(postprocessed_leg_states)
	var body_target_transform: Dictionary = _last_runtime_state.get("body_target_transform", {})
	var resolved_origin: Vector3 = body_target_transform.get("origin", global_position + Vector3.UP * body_clearance_m)
	var resolved_up: Vector3 = body_target_transform.get("up", Vector3.UP)
	if body_pivot != null:
		var smoothed_transform := _smooth_reference_body_visual_transform(resolved_origin, resolved_up)
		body_pivot.global_position = smoothed_transform.get("origin", resolved_origin)
		body_pivot.global_basis = smoothed_transform.get("basis", _build_basis_from_up(resolved_up))
	_sync_enemy_hurtbox_transform()
	_sync_foot_debug_nodes(postprocessed_leg_states)
	_sync_leg_visual_nodes(postprocessed_leg_states)

func _build_reference_leg_states(runtime_leg_states: Array) -> Array:
	var postprocessed: Array = []
	for leg_variant in runtime_leg_states:
		if not (leg_variant is Dictionary):
			continue
		var runtime_leg_state: Dictionary = (leg_variant as Dictionary).duplicate(true)
		var leg_id: String = str(runtime_leg_state.get("leg_id", ""))
		if leg_id == "":
			continue
		var default_anchor_world_position := _compute_default_anchor_world_position(leg_id)
		var step_state: Dictionary = _reference_step_states_by_leg_id.get(leg_id, {}) as Dictionary
		runtime_leg_state["default_anchor_world_position"] = default_anchor_world_position
		runtime_leg_state["step_controller_id"] = REFERENCE_STEP_CONTROLLER_ID
		runtime_leg_state["step_scheduler_id"] = REFERENCE_STEP_SCHEDULER_ID
		runtime_leg_state["step_desire"] = _leg_desires_reference_step(leg_id, runtime_leg_state)
		runtime_leg_state["step_duration_seconds"] = float(step_state.get("duration_seconds", 0.0))
		runtime_leg_state["step_surface_search_source"] = str(step_state.get("surface_search_source", ""))
		runtime_leg_state["step_surface_search_candidates"] = (step_state.get("surface_search_candidates", []) as Array).duplicate(true)
		if not bool(step_state.get("is_stepping", false)):
			runtime_leg_state["mode"] = "stance"
			runtime_leg_state["is_grounded"] = true
			runtime_leg_state["display_foot_world_position"] = runtime_leg_state.get("locked_foothold", default_anchor_world_position)
			runtime_leg_state["step_goal_world_position"] = runtime_leg_state.get("locked_foothold", default_anchor_world_position)
			runtime_leg_state["step_prediction_world_position"] = runtime_leg_state.get("locked_foothold", default_anchor_world_position)
			runtime_leg_state["step_progress"] = 0.0
			postprocessed.append(runtime_leg_state)
			continue
		var progress: float = clampf(float(step_state.get("progress", 0.0)), 0.0, 1.0)
		runtime_leg_state["mode"] = "lift" if progress < 0.2 else ("plant" if progress > 0.86 else "swing")
		runtime_leg_state["is_grounded"] = false
		runtime_leg_state["step_progress"] = progress
		runtime_leg_state["step_goal_world_position"] = step_state.get("goal_foothold", runtime_leg_state.get("locked_foothold", default_anchor_world_position))
		runtime_leg_state["step_prediction_world_position"] = step_state.get("predicted_target", runtime_leg_state.get("locked_foothold", default_anchor_world_position))
		runtime_leg_state["display_foot_world_position"] = _compute_reference_display_foot_world_position(leg_id, step_state)
		postprocessed.append(runtime_leg_state)
	return postprocessed

func _compute_reference_body_target(leg_states: Array) -> Dictionary:
	var grounded_positions: Array[Vector3] = []
	var display_positions: Array[Vector3] = []
	var normal_sum := Vector3.ZERO
	var default_centroid_world_position := _compute_reference_default_centroid_world_position()
	for leg_variant in leg_states:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		display_positions.append(leg_state.get("display_foot_world_position", leg_state.get("locked_foothold", Vector3.ZERO)))
		if not bool(leg_state.get("is_grounded", false)):
			continue
		grounded_positions.append(leg_state.get("locked_foothold", Vector3.ZERO))
		normal_sum += leg_state.get("surface_normal", Vector3.UP)
	var support_center := Vector3.ZERO
	for display_position in display_positions:
		support_center += display_position
	if not display_positions.is_empty():
		support_center /= float(display_positions.size())
	var plane_normal := _compute_reference_leg_plane_normal(leg_states)
	if plane_normal.length_squared() <= 0.0001:
		plane_normal = Vector3.UP if normal_sum.length_squared() <= 0.0001 else normal_sum.normalized()
	var centroid_components := _compute_reference_leg_centroid_components(display_positions, default_centroid_world_position)
	var leg_centroid_world_position := centroid_components.get("leg_centroid_world_position", default_centroid_world_position) as Vector3
	var clearance_adjustment_y := _compute_reference_body_obstacle_clearance_adjustment(leg_centroid_world_position, plane_normal)
	leg_centroid_world_position += Vector3.UP * clearance_adjustment_y
	var pounce_body_offset := _compute_pounce_body_offset(plane_normal)
	leg_centroid_world_position += pounce_body_offset
	if grounded_positions.is_empty():
		var fallback := _last_stable_body_target_transform.duplicate(true)
		if (fallback.get("origin", Vector3.ZERO) as Vector3).length_squared() <= 0.0001:
			var current_up: Vector3 = _get_reference_body_up()
			var fallback_origin := default_centroid_world_position
			fallback = {
				"origin": fallback_origin,
				"support_center": body_pivot.global_position if body_pivot != null else global_position,
				"up": current_up,
				"grounded_leg_count": 0,
				"default_centroid_world_position": default_centroid_world_position,
				"leg_centroid_world_position": leg_centroid_world_position,
				"plane_normal": plane_normal,
				"centroid_normal_offset": centroid_components.get("centroid_normal_offset", Vector3.ZERO),
				"centroid_tangent_offset": centroid_components.get("centroid_tangent_offset", Vector3.ZERO),
				"obstacle_clearance_adjustment_y": clearance_adjustment_y,
				"pounce_body_offset": pounce_body_offset,
				"pounce_lift_m": _current_pounce_lift_m,
			}
		return fallback
	var resolved := {
		"origin": leg_centroid_world_position,
		"support_center": support_center,
		"up": plane_normal,
		"grounded_leg_count": grounded_positions.size(),
		"default_centroid_world_position": default_centroid_world_position,
		"leg_centroid_world_position": leg_centroid_world_position,
		"plane_normal": plane_normal,
		"centroid_normal_offset": centroid_components.get("centroid_normal_offset", Vector3.ZERO),
		"centroid_tangent_offset": centroid_components.get("centroid_tangent_offset", Vector3.ZERO),
		"obstacle_clearance_adjustment_y": clearance_adjustment_y,
		"pounce_body_offset": pounce_body_offset,
		"pounce_lift_m": _current_pounce_lift_m,
	}
	_last_stable_body_target_transform = resolved.duplicate(true)
	return resolved

func _compute_pounce_body_offset(body_up: Vector3) -> Vector3:
	if _current_pounce_lift_m <= 0.0 and _current_pounce_forward_offset_m <= 0.0:
		return Vector3.ZERO
	var resolved_up := body_up.normalized()
	if resolved_up.length_squared() <= 0.0001:
		resolved_up = Vector3.UP
	var motion_forward := _resolve_body_forward_vector(resolved_up)
	return resolved_up * _current_pounce_lift_m + motion_forward * _current_pounce_forward_offset_m

func _resolve_body_forward_vector(up_vector: Vector3) -> Vector3:
	var resolved_up := up_vector.normalized()
	if resolved_up.length_squared() <= 0.0001:
		resolved_up = Vector3.UP
	var forward := _debug_motion_velocity
	if forward.length_squared() <= 0.0001:
		forward = -global_basis.z
	var planar_forward := forward - resolved_up * forward.dot(resolved_up)
	if planar_forward.length_squared() <= 0.0001:
		planar_forward = Vector3.FORWARD - resolved_up * Vector3.FORWARD.dot(resolved_up)
	if planar_forward.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return planar_forward.normalized()

func _get_reference_body_up() -> Vector3:
	return body_pivot.global_basis.y.normalized() if body_pivot != null else Vector3.UP

func _get_reference_step_frame_up() -> Vector3:
	return global_basis.y.normalized() if global_basis.y.length_squared() > 0.0001 else Vector3.UP

func _compute_reference_default_centroid_world_position() -> Vector3:
	var step_frame_up := _get_reference_step_frame_up()
	return global_position + step_frame_up * maxf(body_clearance_m, 0.0)

func _compute_reference_leg_centroid_components(display_positions: Array, default_centroid_world_position: Vector3) -> Dictionary:
	var body_up := _get_reference_step_frame_up()
	var leg_centroid := default_centroid_world_position
	if not display_positions.is_empty():
		leg_centroid = Vector3.ZERO
		for display_position in display_positions:
			leg_centroid += display_position
		leg_centroid /= float(display_positions.size())
	leg_centroid += body_up * maxf(body_clearance_m, 0.0)
	var centroid_delta := leg_centroid - default_centroid_world_position
	var centroid_normal_offset := body_up * centroid_delta.dot(body_up)
	var centroid_tangent_offset := centroid_delta - centroid_normal_offset
	return {
		"leg_centroid_world_position": default_centroid_world_position \
			+ centroid_normal_offset * REFERENCE_LEG_CENTROID_NORMAL_WEIGHT \
			+ centroid_tangent_offset * REFERENCE_LEG_CENTROID_TANGENT_WEIGHT,
		"centroid_normal_offset": centroid_normal_offset,
		"centroid_tangent_offset": centroid_tangent_offset,
	}

func _compute_reference_leg_plane_normal(leg_states: Array) -> Vector3:
	var body_up := _get_reference_step_frame_up()
	var new_normal := body_up
	for leg_variant in leg_states:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		var display_foot_world_position: Vector3 = leg_state.get("display_foot_world_position", leg_state.get("locked_foothold", global_position))
		var to_end := display_foot_world_position - global_position
		var current_tangent := to_end - body_up * to_end.dot(body_up)
		if current_tangent.length_squared() <= 0.0001 or to_end.length_squared() <= 0.0001:
			continue
		var from_direction := current_tangent.normalized()
		var to_direction := to_end.normalized()
		var axis := from_direction.cross(to_direction)
		if axis.length_squared() <= 0.0001:
			continue
		var angle := acos(clampf(from_direction.dot(to_direction), -1.0, 1.0)) * REFERENCE_LEG_NORMAL_WEIGHT
		new_normal = Quaternion(axis.normalized(), angle) * new_normal
	if new_normal.length_squared() <= 0.0001:
		return body_up
	return new_normal.normalized()

func _smooth_reference_body_visual_transform(target_origin: Vector3, target_up: Vector3) -> Dictionary:
	var resolved_target_up := target_up.normalized()
	if resolved_target_up.length_squared() <= 0.0001:
		resolved_target_up = Vector3.UP
	if not _reference_body_visual_initialized:
		_reference_body_visual_initialized = true
		return {
			"origin": target_origin,
			"basis": _build_basis_from_up(resolved_target_up),
		}
	var effective_delta := maxf(_reference_last_solver_delta_seconds, REFERENCE_BODY_SMOOTHING_FALLBACK_DELTA_SECONDS)
	var centroid_weight := _compute_reference_body_smoothing_weight(REFERENCE_BODY_CENTROID_ADJUST_SPEED, effective_delta)
	var normal_weight := _compute_reference_body_smoothing_weight(REFERENCE_BODY_NORMAL_ADJUST_SPEED, effective_delta)
	var current_origin := body_pivot.global_position
	var current_up := body_pivot.global_basis.y.normalized()
	if current_up.length_squared() <= 0.0001:
		current_up = Vector3.UP
	if current_up.dot(resolved_target_up) < 0.0:
		resolved_target_up = -resolved_target_up
	var smoothed_origin := current_origin.lerp(target_origin, centroid_weight)
	var blended_up := current_up.lerp(resolved_target_up, normal_weight)
	var smoothed_up := blended_up.normalized()
	if smoothed_up.length_squared() <= 0.0001 or not smoothed_up.is_finite():
		smoothed_up = resolved_target_up
	return {
		"origin": smoothed_origin,
		"basis": _build_basis_from_up(smoothed_up),
	}

func _compute_reference_body_smoothing_weight(speed: float, delta: float) -> float:
	return clampf(maxf(speed, 0.0) * maxf(delta, 0.0), 0.0, 1.0)

func _compute_reference_body_obstacle_clearance_adjustment(origin: Vector3, up: Vector3) -> float:
	if get_world_3d() == null:
		return 0.0
	var body_basis := _build_basis_from_up(up)
	var body_transform := Transform3D(body_basis, origin)
	var max_penetration_m := 0.0
	for mesh_instance in [prosoma_mesh, abdomen_mesh]:
		if not (mesh_instance is MeshInstance3D):
			continue
		max_penetration_m = maxf(max_penetration_m, _compute_reference_body_mesh_penetration(mesh_instance as MeshInstance3D, body_transform))
	if max_penetration_m <= 0.0:
		return 0.0
	return max_penetration_m + REFERENCE_BODY_OBSTACLE_CLEARANCE_MARGIN_M

func _compute_reference_body_mesh_penetration(mesh_instance: MeshInstance3D, body_transform: Transform3D) -> float:
	if mesh_instance == null or mesh_instance.mesh == null:
		return 0.0
	var local_aabb := mesh_instance.get_aabb()
	var part_transform := mesh_instance.transform
	var mesh_center_local := local_aabb.position + local_aabb.size * 0.5
	var mesh_center_world := body_transform * (part_transform * mesh_center_local)
	var bottom_world_y := INF
	for x_index in range(2):
		for y_index in range(2):
			for z_index in range(2):
				var corner := local_aabb.position + Vector3(
					local_aabb.size.x * float(x_index),
					local_aabb.size.y * float(y_index),
					local_aabb.size.z * float(z_index)
				)
				var world_corner := body_transform * (part_transform * corner)
				bottom_world_y = minf(bottom_world_y, world_corner.y)
	var ray_origin := mesh_center_world + Vector3.UP * 8.0
	var ray_end := mesh_center_world + Vector3.DOWN * 8.0
	var hit: Dictionary = _intersect_environment_ray(ray_origin, ray_end)
	if hit.is_empty():
		return 0.0
	var ground_y := float((hit.get("position", Vector3.ZERO) as Vector3).y)
	return maxf(ground_y - bottom_world_y, 0.0)

func _build_self_physics_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	if enemy_hurtbox != null:
		exclusions.append(enemy_hurtbox.get_rid())
	return exclusions

func _intersect_environment_ray(start: Vector3, end: Vector3, extra_exclusions: Array[RID] = []) -> Dictionary:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return {}
	var exclusions: Array[RID] = _build_self_physics_exclusions()
	for exclusion in extra_exclusions:
		if exclusions.has(exclusion):
			continue
		exclusions.append(exclusion)
	for _attempt in range(12):
		var query := PhysicsRayQueryParameters3D.create(start, end)
		query.exclude = exclusions
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider: Object = hit.get("collider", null)
		if not _should_ignore_environment_collider(collider):
			return hit
		if collider is CollisionObject3D:
			exclusions.append((collider as CollisionObject3D).get_rid())
			continue
		return {}
	return {}

func _should_ignore_environment_collider(collider: Object) -> bool:
	if collider == null:
		return false
	if collider == enemy_hurtbox:
		return true
	if collider is Node:
		var node: Node = collider as Node
		if node.is_in_group("city_enemy") or node.is_in_group("city_spider_crawler"):
			return true
	return false

func _sync_foot_debug_nodes(leg_states: Array) -> void:
	for leg_variant in leg_states:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		var leg_id: String = str(leg_state.get("leg_id", ""))
		var foot_node := _foot_debug_nodes_by_leg_id.get(leg_id) as Node3D
		if foot_node == null:
			continue
		foot_node.global_position = leg_state.get("locked_foothold", global_position)

func _sync_leg_visual_nodes(leg_states: Array) -> void:
	_last_leg_visual_state.clear()
	for leg_variant in leg_states:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		var leg_id: String = str(leg_state.get("leg_id", ""))
		if leg_id == "":
			continue
		var visual_nodes: Dictionary = _leg_visual_nodes_by_leg_id.get(leg_id, {}) as Dictionary
		if visual_nodes.is_empty():
			continue
		var socket_local: Vector3 = _socket_offsets_by_leg_id.get(leg_id, Vector3.ZERO)
		var socket_world_position: Vector3 = _resolve_socket_world_position(socket_local)
		var foot_world_position: Vector3 = leg_state.get("locked_foothold", global_position)
		var display_foot_world_position: Vector3 = _compute_display_foot_world_position(leg_id, leg_state, foot_world_position)
		var knee_world_position: Vector3 = _compute_knee_world_position(leg_id, socket_local, socket_world_position, display_foot_world_position, leg_state)
		var upper_segment_root: Node3D = visual_nodes.get("upper_segment_root", null) as Node3D
		var lower_segment_root: Node3D = visual_nodes.get("lower_segment_root", null) as Node3D
		var upper_segment_mesh: MeshInstance3D = visual_nodes.get("upper_segment_mesh", null) as MeshInstance3D
		var lower_segment_mesh: MeshInstance3D = visual_nodes.get("lower_segment_mesh", null) as MeshInstance3D
		var knee_joint: MeshInstance3D = visual_nodes.get("knee_joint", null) as MeshInstance3D
		var foot_tip: MeshInstance3D = visual_nodes.get("foot_tip", null) as MeshInstance3D
		_sync_leg_segment(upper_segment_root, upper_segment_mesh, socket_world_position, knee_world_position)
		_sync_leg_segment(lower_segment_root, lower_segment_mesh, knee_world_position, display_foot_world_position)
		if knee_joint != null:
			knee_joint.global_position = knee_world_position
		if foot_tip != null:
			foot_tip.global_position = display_foot_world_position
		var upper_length: float = socket_world_position.distance_to(knee_world_position)
		var lower_length: float = knee_world_position.distance_to(display_foot_world_position)
		var visual_contract: Dictionary = _leg_visual_contracts_by_leg_id.get(leg_id, {}) as Dictionary
		_last_leg_visual_state.append({
			"leg_id": leg_id,
			"mode": str(leg_state.get("mode", "")),
			"socket_world_position": socket_world_position,
			"knee_world_position": knee_world_position,
			"foot_world_position": foot_world_position,
			"display_foot_world_position": display_foot_world_position,
			"upper_length": upper_length,
			"lower_length": lower_length,
			"knee_projection_ratio": float(visual_contract.get("knee_projection_ratio", 0.5)),
			"knee_offset_m": _compute_knee_offset_m(socket_world_position, knee_world_position, foot_world_position),
		})

func _cache_leg_socket_offsets() -> void:
	_socket_offsets_by_leg_id.clear()
	for leg_id in LEG_ORDER:
		var socket_node := leg_socket_root.get_node_or_null(leg_id) as Marker3D
		if socket_node == null:
			continue
		_socket_offsets_by_leg_id[leg_id] = socket_node.position

func _cache_foot_debug_nodes() -> void:
	_foot_debug_nodes_by_leg_id.clear()
	for leg_id in LEG_ORDER:
		var foot_node := foot_debug_root.get_node_or_null(leg_id) as Node3D
		if foot_node == null:
			continue
		_foot_debug_nodes_by_leg_id[leg_id] = foot_node

func _ensure_leg_visual_nodes() -> void:
	if leg_visual_root == null:
		return
	_leg_visual_nodes_by_leg_id.clear()
	for leg_id in LEG_ORDER:
		var leg_root: Node3D = leg_visual_root.get_node_or_null(leg_id) as Node3D
		if leg_root == null:
			leg_root = Node3D.new()
			leg_root.name = leg_id
			leg_visual_root.add_child(leg_root)
		var upper_segment_root: Node3D = leg_root.get_node_or_null("UpperSegment") as Node3D
		if upper_segment_root == null:
			upper_segment_root = Node3D.new()
			upper_segment_root.name = "UpperSegment"
			leg_root.add_child(upper_segment_root)
		var lower_segment_root: Node3D = leg_root.get_node_or_null("LowerSegment") as Node3D
		if lower_segment_root == null:
			lower_segment_root = Node3D.new()
			lower_segment_root.name = "LowerSegment"
			leg_root.add_child(lower_segment_root)
		var knee_joint: MeshInstance3D = leg_root.get_node_or_null("KneeJoint") as MeshInstance3D
		if knee_joint == null:
			knee_joint = MeshInstance3D.new()
			knee_joint.name = "KneeJoint"
			leg_root.add_child(knee_joint)
		var foot_tip: MeshInstance3D = leg_root.get_node_or_null("FootTip") as MeshInstance3D
		if foot_tip == null:
			foot_tip = MeshInstance3D.new()
			foot_tip.name = "FootTip"
			leg_root.add_child(foot_tip)
		var upper_segment_mesh: MeshInstance3D = upper_segment_root.get_node_or_null("Mesh") as MeshInstance3D
		if upper_segment_mesh == null:
			upper_segment_mesh = MeshInstance3D.new()
			upper_segment_mesh.name = "Mesh"
			upper_segment_root.add_child(upper_segment_mesh)
		var lower_segment_mesh: MeshInstance3D = lower_segment_root.get_node_or_null("Mesh") as MeshInstance3D
		if lower_segment_mesh == null:
			lower_segment_mesh = MeshInstance3D.new()
			lower_segment_mesh.name = "Mesh"
			lower_segment_root.add_child(lower_segment_mesh)
		_configure_leg_segment_mesh(upper_segment_mesh, true)
		_configure_leg_segment_mesh(lower_segment_mesh, false)
		_configure_knee_joint_mesh(knee_joint)
		_configure_foot_tip_mesh(foot_tip)
		_leg_visual_nodes_by_leg_id[leg_id] = {
			"upper_segment_root": upper_segment_root,
			"upper_segment_mesh": upper_segment_mesh,
			"lower_segment_root": lower_segment_root,
			"lower_segment_mesh": lower_segment_mesh,
			"knee_joint": knee_joint,
			"foot_tip": foot_tip,
		}

func _configure_leg_segment_mesh(segment_mesh: MeshInstance3D, is_upper_segment: bool) -> void:
	if segment_mesh == null:
		return
	segment_mesh.mesh = _get_upper_leg_segment_mesh() if is_upper_segment else _get_lower_leg_segment_mesh()
	segment_mesh.material_override = _get_upper_leg_material() if is_upper_segment else _get_lower_leg_material()
	segment_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _configure_knee_joint_mesh(knee_joint: MeshInstance3D) -> void:
	if knee_joint == null:
		return
	knee_joint.mesh = _get_knee_joint_mesh()
	knee_joint.material_override = _get_knee_joint_material()
	knee_joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _configure_foot_tip_mesh(foot_tip: MeshInstance3D) -> void:
	if foot_tip == null:
		return
	foot_tip.mesh = _get_foot_tip_mesh()
	foot_tip.material_override = _get_foot_tip_material()
	foot_tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _sync_leg_segment(segment_root: Node3D, segment_mesh: MeshInstance3D, start_position: Vector3, end_position: Vector3) -> void:
	if segment_root == null or segment_mesh == null:
		return
	var segment_vector: Vector3 = end_position - start_position
	var segment_length: float = segment_vector.length()
	if segment_length <= 0.001:
		segment_mesh.visible = false
		return
	segment_mesh.visible = true
	segment_root.global_position = start_position.lerp(end_position, 0.5)
	segment_root.global_basis = _build_segment_basis(segment_vector.normalized())
	segment_mesh.scale = Vector3.ONE
	segment_mesh.scale = Vector3(1.0, segment_length, 1.0)

func _resolve_socket_world_position(socket_local: Vector3) -> Vector3:
	if body_pivot != null:
		return body_pivot.global_transform * socket_local
	return global_position + socket_local

func _compute_default_anchor_world_position(leg_id: String) -> Vector3:
	var foothold_offset: Vector3 = _default_foothold_offsets_by_leg_id.get(leg_id, _socket_offsets_by_leg_id.get(leg_id, Vector3.ZERO))
	return global_position + global_basis * foothold_offset

func _compute_reference_display_foot_world_position(leg_id: String, step_state: Dictionary) -> Vector3:
	var start_foothold: Vector3 = step_state.get("start_foothold", global_position)
	var goal_foothold: Vector3 = step_state.get("goal_foothold", start_foothold)
	var progress: float = clampf(float(step_state.get("progress", 0.0)), 0.0, 1.0)
	var body_up := _get_reference_step_frame_up()
	var visual_contract: Dictionary = _leg_visual_contracts_by_leg_id.get(leg_id, {}) as Dictionary
	var arc_height_m: float = maxf(float(visual_contract.get("step_height_m", step_height_m)), 0.06)
	var display_foot_world_position := start_foothold.lerp(goal_foothold, progress)
	display_foot_world_position += body_up * sin(progress * PI) * arc_height_m
	return display_foot_world_position

func _compute_display_foot_world_position(leg_id: String, leg_state: Dictionary, locked_foothold: Vector3) -> Vector3:
	var step_state: Dictionary = _reference_step_states_by_leg_id.get(leg_id, {}) as Dictionary
	if bool(step_state.get("is_stepping", false)):
		return _compute_reference_display_foot_world_position(leg_id, step_state)
	return leg_state.get("display_foot_world_position", locked_foothold)

func _compute_knee_world_position(leg_id: String, socket_local: Vector3, socket_world_position: Vector3, foot_world_position: Vector3, leg_state: Dictionary) -> Vector3:
	var visual_contract: Dictionary = _leg_visual_contracts_by_leg_id.get(leg_id, {}) as Dictionary
	var span_vector: Vector3 = foot_world_position - socket_world_position
	var span_length: float = maxf(span_vector.length(), 0.001)
	var knee_projection_ratio: float = clampf(float(visual_contract.get("knee_projection_ratio", 0.5)), 0.18, 0.82)
	var knee_anchor: Vector3 = socket_world_position.lerp(foot_world_position, knee_projection_ratio)
	var body_right: Vector3 = body_pivot.global_basis.x.normalized() if body_pivot != null else Vector3.RIGHT
	var body_up: Vector3 = body_pivot.global_basis.y.normalized() if body_pivot != null else Vector3.UP
	var body_longitudinal: Vector3 = body_pivot.global_basis.z.normalized() if body_pivot != null else Vector3.BACK
	var side_sign: float = -1.0 if leg_id.begins_with("l") else 1.0
	var fore_aft_sign: float = signf(socket_local.z)
	var lateral_offset_m: float = clampf(span_length * float(visual_contract.get("knee_lateral_scale", 0.32)), 0.12, 0.62)
	var is_stance := str(leg_state.get("mode", "stance")) == "stance"
	var lift_offset_m: float = float(visual_contract.get("stance_knee_lift_m", 0.03)) if is_stance else float(visual_contract.get("swing_knee_lift_m", 0.16))
	var fore_aft_offset_m: float = clampf(absf(socket_local.z) * float(visual_contract.get("fore_aft_offset_scale", 0.04)), 0.0, 0.18)
	return knee_anchor + body_right * side_sign * lateral_offset_m + body_up * lift_offset_m + body_longitudinal * fore_aft_sign * fore_aft_offset_m

func _compute_knee_offset_m(socket_world_position: Vector3, knee_world_position: Vector3, foot_world_position: Vector3) -> float:
	var leg_axis: Vector3 = foot_world_position - socket_world_position
	var leg_axis_length: float = leg_axis.length()
	if leg_axis_length <= 0.001:
		return 0.0
	var projection_distance: float = (knee_world_position - socket_world_position).dot(leg_axis / leg_axis_length)
	var projected_point: Vector3 = socket_world_position + leg_axis.normalized() * projection_distance
	return knee_world_position.distance_to(projected_point)

func _build_segment_basis(direction: Vector3) -> Basis:
	var segment_up: Vector3 = direction.normalized()
	var reference_axis: Vector3 = body_pivot.global_basis.x.normalized() if body_pivot != null else Vector3.RIGHT
	if absf(segment_up.dot(reference_axis)) >= 0.96:
		reference_axis = body_pivot.global_basis.z.normalized() if body_pivot != null else Vector3.FORWARD
	var segment_right: Vector3 = reference_axis.cross(segment_up).normalized()
	if segment_right.length_squared() <= 0.0001:
		segment_right = Vector3.RIGHT
	var segment_forward: Vector3 = segment_up.cross(segment_right).normalized()
	return Basis(segment_right, segment_up, segment_forward).orthonormalized()

func _get_upper_leg_segment_mesh() -> CylinderMesh:
	if _upper_leg_segment_mesh == null:
		_upper_leg_segment_mesh = CylinderMesh.new()
		_upper_leg_segment_mesh.top_radius = UPPER_LEG_SEGMENT_RADIUS_M
		_upper_leg_segment_mesh.bottom_radius = UPPER_LEG_SEGMENT_RADIUS_M * 0.92
		_upper_leg_segment_mesh.height = 1.0
		_upper_leg_segment_mesh.radial_segments = 12
	return _upper_leg_segment_mesh

func _get_lower_leg_segment_mesh() -> CylinderMesh:
	if _lower_leg_segment_mesh == null:
		_lower_leg_segment_mesh = CylinderMesh.new()
		_lower_leg_segment_mesh.top_radius = LOWER_LEG_SEGMENT_TOP_RADIUS_M
		_lower_leg_segment_mesh.bottom_radius = LOWER_LEG_SEGMENT_BOTTOM_RADIUS_M
		_lower_leg_segment_mesh.height = 1.0
		_lower_leg_segment_mesh.radial_segments = 12
	return _lower_leg_segment_mesh

func _get_upper_leg_material() -> StandardMaterial3D:
	if _upper_leg_material == null:
		_upper_leg_material = StandardMaterial3D.new()
		_upper_leg_material.albedo_color = UPPER_LEG_BASE_COLOR
		_upper_leg_material.roughness = 0.94
	return _upper_leg_material

func _get_lower_leg_material() -> StandardMaterial3D:
	if _lower_leg_material == null:
		_lower_leg_material = StandardMaterial3D.new()
		_lower_leg_material.albedo_color = LOWER_LEG_BASE_COLOR
		_lower_leg_material.roughness = 0.92
	return _lower_leg_material

func _get_knee_joint_mesh() -> SphereMesh:
	if _knee_joint_mesh == null:
		_knee_joint_mesh = SphereMesh.new()
		_knee_joint_mesh.radius = KNEE_JOINT_RADIUS_M
		_knee_joint_mesh.height = KNEE_JOINT_RADIUS_M * 2.0
	return _knee_joint_mesh

func _get_knee_joint_material() -> StandardMaterial3D:
	if _knee_joint_material == null:
		_knee_joint_material = StandardMaterial3D.new()
		_knee_joint_material.albedo_color = KNEE_BASE_COLOR
		_knee_joint_material.roughness = 0.88
	return _knee_joint_material

func _get_foot_tip_mesh() -> SphereMesh:
	if _foot_tip_mesh == null:
		_foot_tip_mesh = SphereMesh.new()
		_foot_tip_mesh.radius = FOOT_TIP_RADIUS_M
		_foot_tip_mesh.height = FOOT_TIP_RADIUS_M * 2.0
	return _foot_tip_mesh

func _get_foot_tip_material() -> StandardMaterial3D:
	if _foot_tip_material == null:
		_foot_tip_material = StandardMaterial3D.new()
		_foot_tip_material.albedo_color = FOOT_BASE_COLOR
		_foot_tip_material.roughness = 0.96
	return _foot_tip_material

func _ensure_unique_visual_materials() -> void:
	if prosoma_mesh != null and prosoma_mesh.material_override is StandardMaterial3D:
		prosoma_mesh.material_override = (prosoma_mesh.material_override as StandardMaterial3D).duplicate()
	if abdomen_mesh != null and abdomen_mesh.material_override is StandardMaterial3D:
		abdomen_mesh.material_override = (abdomen_mesh.material_override as StandardMaterial3D).duplicate()

func _reset_behavior_runtime_state() -> void:
	_hit_stun_remaining_seconds = 0.0
	_seed_behavior_runtime_rng()
	_reference_step_clock = _reference_step_clock_bias_seconds
	_reset_pounce_state()

func _seed_behavior_profile_rng() -> void:
	_behavior_profile_rng.seed = _resolve_behavior_rng_seed(17)

func _seed_behavior_runtime_rng() -> void:
	_behavior_runtime_rng.seed = _resolve_behavior_rng_seed(29)

func _resolve_behavior_rng_seed(offset: int) -> int:
	return int(maxi(behavior_seed, 0) + offset + 1)

func _compute_hit_stun_duration_seconds(resolved_damage: float) -> float:
	return clampf(HIT_STUN_MIN_SECONDS + resolved_damage * HIT_STUN_DAMAGE_DURATION_SCALE, HIT_STUN_MIN_SECONDS, HIT_STUN_MAX_SECONDS)

func _reset_pounce_state() -> void:
	_pounce_total_count = 0
	_cancel_pounce(false)
	_schedule_next_pounce(true)

func _schedule_next_pounce(is_initial_schedule: bool = false) -> void:
	var interval_scale := 0.55 if is_initial_schedule else 1.0
	_pounce_cooldown_remaining_seconds = lerpf(POUNCE_INTERVAL_MIN_SECONDS, POUNCE_INTERVAL_MAX_SECONDS, _behavior_runtime_rng.randf()) * interval_scale

func _begin_pounce() -> void:
	_pounce_elapsed_seconds = 0.0
	_pounce_duration_seconds = lerpf(POUNCE_DURATION_MIN_SECONDS, POUNCE_DURATION_MAX_SECONDS, _behavior_runtime_rng.randf())
	_pounce_speed_multiplier = lerpf(POUNCE_SPEED_MULTIPLIER_MIN, POUNCE_SPEED_MULTIPLIER_MAX, _behavior_runtime_rng.randf())
	_pounce_lift_peak_m = lerpf(POUNCE_LIFT_MIN_M, POUNCE_LIFT_MAX_M, _behavior_runtime_rng.randf())
	_pounce_forward_offset_m = lerpf(POUNCE_FORWARD_OFFSET_MIN_M, POUNCE_FORWARD_OFFSET_MAX_M, _behavior_runtime_rng.randf())
	_current_pounce_lift_m = 0.0
	_current_pounce_forward_offset_m = 0.0
	_pounce_total_count += 1

func _cancel_pounce(schedule_next: bool = true) -> void:
	_pounce_elapsed_seconds = 0.0
	_pounce_duration_seconds = 0.0
	_pounce_speed_multiplier = 1.0
	_pounce_lift_peak_m = 0.0
	_pounce_forward_offset_m = 0.0
	_current_pounce_lift_m = 0.0
	_current_pounce_forward_offset_m = 0.0
	if schedule_next:
		_schedule_next_pounce()

func _is_pounce_active() -> bool:
	return _pounce_duration_seconds > 0.0 and _pounce_elapsed_seconds < _pounce_duration_seconds

func _update_pounce_state(delta: float) -> void:
	if _debug_motion_velocity.length() < POUNCE_MIN_TRIGGER_SPEED_MPS:
		_current_pounce_lift_m = 0.0
		_current_pounce_forward_offset_m = 0.0
		return
	if _is_pounce_active():
		_pounce_elapsed_seconds = minf(_pounce_elapsed_seconds + delta, _pounce_duration_seconds)
		var progress := clampf(_pounce_elapsed_seconds / maxf(_pounce_duration_seconds, 0.001), 0.0, 1.0)
		var spring_wave := sin(progress * PI)
		_current_pounce_lift_m = spring_wave * _pounce_lift_peak_m
		_current_pounce_forward_offset_m = spring_wave * _pounce_forward_offset_m
		if progress >= 1.0:
			_cancel_pounce(true)
		return
	_current_pounce_lift_m = 0.0
	_current_pounce_forward_offset_m = 0.0
	if _reference_time_standing_still_seconds > 0.24:
		return
	_pounce_cooldown_remaining_seconds = maxf(_pounce_cooldown_remaining_seconds - delta, 0.0)
	if _pounce_cooldown_remaining_seconds > 0.0:
		return
	_begin_pounce()

func _enter_dead_state() -> void:
	_dead = true
	_health = 0.0
	_auto_step_enabled = false
	_debug_motion_velocity = Vector3.ZERO
	_hit_stun_remaining_seconds = 0.0
	_cancel_pounce(false)
	_set_hurtbox_enabled(false)
	_update_combat_visual_feedback()

func _set_hurtbox_enabled(enabled: bool) -> void:
	if enemy_hurtbox_shape != null:
		enemy_hurtbox_shape.disabled = not enabled

func _sync_enemy_hurtbox_transform() -> void:
	if enemy_hurtbox == null:
		return
	if body_pivot != null:
		body_pivot.force_update_transform()
		enemy_hurtbox.global_transform = Transform3D(body_pivot.global_basis, body_pivot.to_global(HURTBOX_LOCAL_OFFSET))
	else:
		enemy_hurtbox.global_position = global_position + HURTBOX_LOCAL_OFFSET
	enemy_hurtbox.force_update_transform()
	if enemy_hurtbox_shape != null:
		enemy_hurtbox_shape.force_update_transform()

func _update_combat_visual_feedback() -> void:
	var health_ratio := clampf(_health / maxf(max_health, 0.001), 0.0, 1.0)
	var wound_mix := 1.0 - health_ratio
	if _dead:
		wound_mix = 1.0
	var prosoma_material: StandardMaterial3D = null
	var abdomen_material: StandardMaterial3D = null
	if prosoma_mesh != null:
		prosoma_material = prosoma_mesh.material_override as StandardMaterial3D
	if abdomen_mesh != null:
		abdomen_material = abdomen_mesh.material_override as StandardMaterial3D
	_apply_material_tint(prosoma_material, PROSOMA_BASE_COLOR, wound_mix)
	_apply_material_tint(abdomen_material, ABDOMEN_BASE_COLOR, wound_mix)
	_apply_material_tint(_upper_leg_material, UPPER_LEG_BASE_COLOR, wound_mix)
	_apply_material_tint(_lower_leg_material, LOWER_LEG_BASE_COLOR, wound_mix)
	_apply_material_tint(_knee_joint_material, KNEE_BASE_COLOR, wound_mix)
	_apply_material_tint(_foot_tip_material, FOOT_BASE_COLOR, wound_mix)

func _apply_material_tint(material: StandardMaterial3D, base_color: Color, wound_mix: float) -> void:
	if material == null:
		return
	var target_color := WOUNDED_TINT_COLOR if not _dead else DEAD_TINT_COLOR
	material.albedo_color = base_color.lerp(target_color, clampf(wound_mix, 0.0, 1.0))

func _build_basis_from_up(up_vector: Vector3) -> Basis:
	var up := up_vector.normalized()
	if up.length_squared() <= 0.0001:
		up = Vector3.UP
	var forward := -global_basis.z
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	var right := forward.cross(up).normalized()
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	forward = up.cross(right).normalized()
	return Basis(right, up, forward).orthonormalized()
