extends RefCounted
class_name CityArthropodLegRuntime

var _leg_contract: Dictionary = {}
var _phase := 0.0
var _mode := "stance"
var _locked_foothold := Vector3.ZERO
var _desired_foothold := Vector3.ZERO
var _surface_normal := Vector3.UP
var _is_grounded := true
var _replan_count := 0

func configure(leg_contract: Dictionary) -> void:
	_leg_contract = leg_contract.duplicate(true)
	_phase = float(_leg_contract.get("phase_offset", 0.0))
	_mode = "stance"
	_locked_foothold = _leg_contract.get("default_foothold", Vector3.ZERO)
	_desired_foothold = _locked_foothold
	_surface_normal = Vector3.UP
	_is_grounded = true
	_replan_count = 0

func tick(global_phase: float, duty_factor: float) -> void:
	_phase = fposmod(global_phase + float(_leg_contract.get("phase_offset", 0.0)), 1.0)
	var clamped_duty := clampf(duty_factor, 0.05, 0.95)
	if _phase < clamped_duty:
		_mode = "stance"
		_is_grounded = true
	elif _phase < minf(clamped_duty + 0.12, 1.0):
		_mode = "lift"
		_is_grounded = false
	elif _phase < 0.98:
		_mode = "swing"
		_is_grounded = false
	else:
		_mode = "plant"
		_is_grounded = false

func apply_foothold_resolution(result: Dictionary) -> void:
	if not bool(result.get("success", false)):
		return
	var world_position: Vector3 = result.get("world_position", _desired_foothold)
	_desired_foothold = world_position
	_locked_foothold = world_position
	_surface_normal = result.get("surface_normal", Vector3.UP)
	_replan_count += 1

func get_surface_normal() -> Vector3:
	return _surface_normal

func get_state() -> Dictionary:
	return {
		"leg_id": str(_leg_contract.get("leg_id", "")),
		"phase_offset": float(_leg_contract.get("phase_offset", 0.0)),
		"stride_scale": float(_leg_contract.get("stride_scale", 1.0)),
		"step_height_m": float(_leg_contract.get("step_height_m", 0.18)),
		"phase": _phase,
		"mode": _mode,
		"locked_foothold": _locked_foothold,
		"desired_foothold": _desired_foothold,
		"surface_normal": _surface_normal,
		"is_grounded": _is_grounded,
		"replan_count": _replan_count,
	}
