extends Node3D
class_name CityArthropodCrawlerRuntime

var _profile: CityArthropodLocomotionProfile = null
var _foothold_resolver: CityArthropodFootholdResolver = null
var _body_solver: CityArthropodBodySolver = null
var _legs_by_id: Dictionary = {}
var _leg_order: Array[String] = []
var _phase_time := 0.0
var _failed_replan_count := 0
var _body_target_transform: Dictionary = {
	"origin": Vector3.ZERO,
	"support_center": Vector3.ZERO,
	"up": Vector3.UP,
	"grounded_leg_count": 0,
}

func configure(
	profile: CityArthropodLocomotionProfile,
	foothold_resolver: CityArthropodFootholdResolver = null,
	body_solver: CityArthropodBodySolver = null
) -> void:
	_profile = profile
	_phase_time = 0.0
	_failed_replan_count = 0
	_legs_by_id.clear()
	_leg_order.clear()
	_foothold_resolver = foothold_resolver if foothold_resolver != null else CityArthropodFootholdResolver.new()
	_body_solver = body_solver if body_solver != null else CityArthropodBodySolver.new()
	if foothold_resolver == null:
		_foothold_resolver.configure()
	for leg_contract_variant in _profile.get_leg_contracts():
		var leg_contract: Dictionary = leg_contract_variant as Dictionary
		var leg_id: String = str(leg_contract.get("leg_id", ""))
		if leg_id == "":
			continue
		var leg_runtime: CityArthropodLegRuntime = CityArthropodLegRuntime.new()
		leg_runtime.configure(leg_contract)
		_leg_order.append(leg_id)
		_legs_by_id[leg_id] = leg_runtime
	_update_body_target()

func tick(delta: float) -> void:
	if _profile == null:
		return
	_phase_time += maxf(delta, 0.0)
	var phase_duration := maxf(_profile.get_phase_duration_seconds(), 0.001)
	var global_phase := fposmod(_phase_time / phase_duration, 1.0)
	var duty_factor := _profile.get_duty_factor()
	for leg_id in _leg_order:
		var leg_runtime: CityArthropodLegRuntime = _legs_by_id.get(leg_id) as CityArthropodLegRuntime
		if leg_runtime == null:
			continue
		leg_runtime.tick(global_phase, duty_factor)
	_update_body_target()

func replan_leg_foothold(leg_id: String, desired_foothold: Vector3) -> Dictionary:
	var leg_runtime: CityArthropodLegRuntime = _legs_by_id.get(leg_id) as CityArthropodLegRuntime
	if leg_runtime == null:
		return {
			"success": false,
			"error": "unknown_leg_id",
			"leg_id": leg_id,
		}
	var result: Dictionary = _foothold_resolver.resolve_foothold(leg_id, desired_foothold, leg_runtime.get_surface_normal())
	if not bool(result.get("success", false)):
		_failed_replan_count += 1
		return result.duplicate(true)
	leg_runtime.apply_foothold_resolution(result)
	_update_body_target()
	return result.duplicate(true)

func get_debug_state() -> Dictionary:
	if _profile == null:
		return {}
	var leg_states: Array = []
	for leg_id in _leg_order:
		var leg_runtime: CityArthropodLegRuntime = _legs_by_id.get(leg_id) as CityArthropodLegRuntime
		if leg_runtime == null:
			continue
		leg_states.append(leg_runtime.get_state())
	return {
		"profile_id": _profile.get_profile_id(),
		"species_id": _profile.get_species_id(),
		"gait_profile_id": _profile.get_gait_profile_id(),
		"phase_time": _phase_time,
		"leg_count": leg_states.size(),
		"legs": leg_states,
		"body_target_transform": _body_target_transform.duplicate(true),
		"failed_replan_count": _failed_replan_count,
	}.duplicate(true)

func _update_body_target() -> void:
	if _profile == null or _body_solver == null:
		_body_target_transform = {
			"origin": Vector3.ZERO,
			"support_center": Vector3.ZERO,
			"up": Vector3.UP,
			"grounded_leg_count": 0,
		}
		return
	var leg_states: Array = []
	for leg_id in _leg_order:
		var leg_runtime: CityArthropodLegRuntime = _legs_by_id.get(leg_id) as CityArthropodLegRuntime
		if leg_runtime == null:
			continue
		leg_states.append(leg_runtime.get_state())
	_body_target_transform = _body_solver.solve_body_target(leg_states, _profile.get_body_clearance_m()).duplicate(true)
