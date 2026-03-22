extends Node3D
class_name CityLobsterCrawler

const CityArthropodLocomotionProfileScript := preload("res://city_game/world/creatures/arthropods/CityArthropodLocomotionProfile.gd")
const CityArthropodCrawlerRuntimeScript := preload("res://city_game/world/creatures/arthropods/CityArthropodCrawlerRuntime.gd")
const CityArthropodFootholdResolverScript := preload("res://city_game/world/creatures/arthropods/CityArthropodFootholdResolver.gd")
const CityArthropodBodySolverScript := preload("res://city_game/world/creatures/arthropods/CityArthropodBodySolver.gd")
const SHARED_RUNTIME_SCRIPT_PATH := "res://city_game/world/creatures/arthropods/CityArthropodCrawlerRuntime.gd"

const LEG_ORDER := [
	"lf_rear",
	"rf_rear",
	"lf_mid_b",
	"rf_mid_b",
	"lf_mid_a",
	"rf_mid_a",
	"lf_front",
	"rf_front",
	"lf_claw",
	"rf_claw",
]

const LEG_PHASE_OFFSETS := {
	"lf_rear": 0.00,
	"rf_rear": 0.10,
	"lf_mid_b": 0.20,
	"rf_mid_b": 0.30,
	"lf_mid_a": 0.40,
	"rf_mid_a": 0.50,
	"lf_front": 0.60,
	"rf_front": 0.70,
	"lf_claw": 0.80,
	"rf_claw": 0.90,
}

const LEG_STRIDE_SCALES := {
	"lf_rear": 1.00,
	"rf_rear": 1.00,
	"lf_mid_b": 0.92,
	"rf_mid_b": 0.92,
	"lf_mid_a": 0.82,
	"rf_mid_a": 0.82,
	"lf_front": 0.72,
	"rf_front": 0.72,
	"lf_claw": 0.35,
	"rf_claw": 0.35,
}

@export var gait_phase_duration_seconds := 1.9
@export var gait_duty_factor := 0.82
@export var body_clearance_m := 0.34
@export var step_height_m := 0.12
@export var replan_distance_m := 0.30

@onready var body_pivot: Node3D = $BodyPivot
@onready var model_root: Node3D = $BodyPivot/Model
@onready var leg_socket_root: Node3D = $LegSockets
@onready var foot_debug_root: Node3D = $FootDebugRoot

var _profile: CityArthropodLocomotionProfile = null
var _runtime: CityArthropodCrawlerRuntime = null
var _foothold_resolver: CityArthropodFootholdResolver = null
var _body_solver: CityArthropodBodySolver = null
var _socket_offsets_by_leg_id: Dictionary = {}
var _stride_scale_by_leg_id: Dictionary = {}
var _foot_debug_nodes_by_leg_id: Dictionary = {}
var _initial_anchor_world_position := Vector3.ZERO
var _auto_step_enabled := false
var _debug_motion_velocity := Vector3.ZERO
var _last_runtime_state: Dictionary = {}
var _model_ground_offset_y := 0.0

func _ready() -> void:
	_initial_anchor_world_position = global_position
	_ground_model_to_body_origin()
	_cache_leg_socket_offsets()
	_cache_foot_debug_nodes()
	_rebuild_runtime()
	debug_force_replan_all_legs()
	_sync_visual_state_from_runtime()

func _process(delta: float) -> void:
	if not _auto_step_enabled:
		return
	tick_crawler(delta)

func set_auto_step_enabled(enabled: bool) -> void:
	_auto_step_enabled = enabled

func set_debug_motion_velocity(velocity: Vector3) -> void:
	_debug_motion_velocity = velocity

func tick_crawler(delta: float) -> void:
	if _runtime == null:
		return
	var resolved_delta := maxf(delta, 0.0)
	global_position += _debug_motion_velocity * resolved_delta
	_request_runtime_replans(_runtime.get_debug_state().get("legs", []))
	_runtime.tick(resolved_delta)
	_sync_visual_state_from_runtime()

func reset_crawler_state() -> void:
	_auto_step_enabled = false
	_debug_motion_velocity = Vector3.ZERO
	global_position = _initial_anchor_world_position
	_rebuild_runtime()
	debug_force_replan_all_legs()
	_sync_visual_state_from_runtime()

func teleport_body_to_world_position(world_position: Vector3) -> void:
	global_position = world_position
	_rebuild_runtime()
	debug_force_replan_all_legs()
	_sync_visual_state_from_runtime()

func debug_force_replan_all_legs() -> void:
	if _runtime == null:
		return
	for leg_id in LEG_ORDER:
		var desired_foothold: Vector3 = _compute_desired_foothold(leg_id, 0.0)
		_runtime.replan_leg_foothold(leg_id, desired_foothold)
	_sync_visual_state_from_runtime()

func get_debug_state() -> Dictionary:
	var state: Dictionary = _last_runtime_state.duplicate(true)
	state["species_id"] = "lobster"
	state["body_anchor_world_position"] = global_position
	state["body_visual_world_position"] = body_pivot.global_position if body_pivot != null else global_position
	state["debug_motion_velocity"] = _debug_motion_velocity
	state["auto_step_enabled"] = _auto_step_enabled
	state["socket_leg_count"] = _socket_offsets_by_leg_id.size()
	state["model_ground_offset_y"] = _model_ground_offset_y
	return state

func get_profile_contract() -> Dictionary:
	if _profile == null:
		return _build_profile_contract().duplicate(true)
	return _profile.get_contract()

func get_portability_contract() -> Dictionary:
	return {
		"species_id": "lobster",
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
	for leg_id in LEG_ORDER:
		var default_foothold: Vector3 = _socket_offsets_by_leg_id.get(leg_id, Vector3.ZERO)
		var stride_scale: float = float(LEG_STRIDE_SCALES.get(leg_id, 1.0))
		_stride_scale_by_leg_id[leg_id] = stride_scale
		legs.append({
			"leg_id": leg_id,
			"phase_offset": float(LEG_PHASE_OFFSETS.get(leg_id, 0.0)),
			"default_foothold": default_foothold,
			"step_height_m": step_height_m,
			"stride_scale": stride_scale,
		})
	return {
		"profile_id": "arthropod_lobster_ground_v1",
		"species_id": "lobster",
		"gait_profile_id": "metachronal_forward",
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
		var desired_foothold: Vector3 = _compute_desired_foothold(leg_id, float(leg_state.get("phase", 0.0)))
		if locked_foothold.distance_to(desired_foothold) < replan_distance_m:
			continue
		_runtime.replan_leg_foothold(leg_id, desired_foothold)

func _compute_desired_foothold(leg_id: String, phase: float) -> Vector3:
	var socket_offset: Vector3 = _socket_offsets_by_leg_id.get(leg_id, Vector3.ZERO)
	var stride_scale: float = float(_stride_scale_by_leg_id.get(leg_id, 1.0))
	var motion_direction := _debug_motion_velocity
	if motion_direction.length_squared() > 0.0001:
		motion_direction = motion_direction.normalized()
	else:
		motion_direction = Vector3.FORWARD
	var stride_offset := motion_direction * sin(phase * TAU) * step_height_m * 1.25 * stride_scale
	return global_position + socket_offset + stride_offset

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
	var ray_query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
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

func _sync_visual_state_from_runtime() -> void:
	if _runtime == null:
		return
	_last_runtime_state = _runtime.get_debug_state()
	var body_target_transform: Dictionary = _last_runtime_state.get("body_target_transform", {})
	var resolved_origin: Vector3 = body_target_transform.get("origin", global_position + Vector3.UP * body_clearance_m)
	var resolved_up: Vector3 = body_target_transform.get("up", Vector3.UP)
	if body_pivot != null:
		body_pivot.global_position = resolved_origin
		body_pivot.global_basis = _build_basis_from_up(resolved_up)
	_sync_foot_debug_nodes(_last_runtime_state.get("legs", []))

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

func _ground_model_to_body_origin() -> void:
	if model_root == null:
		return
	var visual_bounds: Dictionary = _collect_visual_bounds(model_root)
	if visual_bounds.is_empty():
		return
	var model_position := model_root.position
	var bottom_y: float = float(visual_bounds.get("bottom_y", 0.0))
	model_position.y -= bottom_y
	model_root.position = model_position
	_model_ground_offset_y = -bottom_y

func _collect_visual_bounds(root_node: Node3D) -> Dictionary:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	var visual_count := 0
	var root_inverse := root_node.global_transform.affine_inverse()
	for child in root_node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.visible:
			continue
		var local_transform := root_inverse * visual.global_transform
		var aabb := visual.get_aabb()
		for corner in _aabb_corners(aabb):
			var local_corner := local_transform * corner
			min_corner.x = minf(min_corner.x, local_corner.x)
			min_corner.y = minf(min_corner.y, local_corner.y)
			min_corner.z = minf(min_corner.z, local_corner.z)
			max_corner.x = maxf(max_corner.x, local_corner.x)
			max_corner.y = maxf(max_corner.y, local_corner.y)
			max_corner.z = maxf(max_corner.z, local_corner.z)
		visual_count += 1
	if visual_count <= 0:
		return {}
	return {
		"bottom_y": min_corner.y,
		"top_y": max_corner.y,
	}

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
	return Basis(right, up, -forward).orthonormalized()
