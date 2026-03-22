extends RefCounted
class_name CityArthropodLocomotionProfile

const DEFAULT_PROFILE_ID := "arthropod_profile"
const DEFAULT_SPECIES_ID := "arthropod"
const DEFAULT_GAIT_PROFILE_ID := "ground"
const DEFAULT_PHASE_DURATION_SECONDS := 1.0
const DEFAULT_DUTY_FACTOR := 0.6
const DEFAULT_BODY_CLEARANCE_M := 0.5

var _contract: Dictionary = {
	"profile_id": DEFAULT_PROFILE_ID,
	"species_id": DEFAULT_SPECIES_ID,
	"gait_profile_id": DEFAULT_GAIT_PROFILE_ID,
	"phase_duration_seconds": DEFAULT_PHASE_DURATION_SECONDS,
	"duty_factor": DEFAULT_DUTY_FACTOR,
	"body_clearance_m": DEFAULT_BODY_CLEARANCE_M,
	"legs": [],
}

func configure(contract: Dictionary) -> void:
	_contract = _normalize_contract(contract)

func get_contract() -> Dictionary:
	return _contract.duplicate(true)

func get_profile_id() -> String:
	return str(_contract.get("profile_id", DEFAULT_PROFILE_ID))

func get_species_id() -> String:
	return str(_contract.get("species_id", DEFAULT_SPECIES_ID))

func get_gait_profile_id() -> String:
	return str(_contract.get("gait_profile_id", DEFAULT_GAIT_PROFILE_ID))

func get_phase_duration_seconds() -> float:
	return float(_contract.get("phase_duration_seconds", DEFAULT_PHASE_DURATION_SECONDS))

func get_duty_factor() -> float:
	return float(_contract.get("duty_factor", DEFAULT_DUTY_FACTOR))

func get_body_clearance_m() -> float:
	return float(_contract.get("body_clearance_m", DEFAULT_BODY_CLEARANCE_M))

func get_leg_contracts() -> Array:
	var resolved: Array = []
	for leg_variant in _contract.get("legs", []):
		if not (leg_variant is Dictionary):
			continue
		resolved.append((leg_variant as Dictionary).duplicate(true))
	return resolved

func get_leg_count() -> int:
	return get_leg_contracts().size()

func _normalize_contract(contract: Dictionary) -> Dictionary:
	var normalized_legs: Array = []
	for leg_variant in contract.get("legs", []):
		if not (leg_variant is Dictionary):
			continue
		var leg_contract: Dictionary = leg_variant as Dictionary
		var leg_id: String = str(leg_contract.get("leg_id", "")).strip_edges()
		if leg_id == "":
			continue
		normalized_legs.append({
			"leg_id": leg_id,
			"phase_offset": fposmod(float(leg_contract.get("phase_offset", 0.0)), 1.0),
			"default_foothold": leg_contract.get("default_foothold", Vector3.ZERO),
			"step_height_m": float(leg_contract.get("step_height_m", contract.get("step_height_m", 0.18))),
			"stride_scale": clampf(float(leg_contract.get("stride_scale", contract.get("stride_scale", 1.0))), 0.0, 2.0),
		})
	return {
		"profile_id": str(contract.get("profile_id", DEFAULT_PROFILE_ID)),
		"species_id": str(contract.get("species_id", DEFAULT_SPECIES_ID)),
		"gait_profile_id": str(contract.get("gait_profile_id", DEFAULT_GAIT_PROFILE_ID)),
		"phase_duration_seconds": maxf(float(contract.get("phase_duration_seconds", DEFAULT_PHASE_DURATION_SECONDS)), 0.001),
		"duty_factor": clampf(float(contract.get("duty_factor", DEFAULT_DUTY_FACTOR)), 0.05, 0.95),
		"body_clearance_m": maxf(float(contract.get("body_clearance_m", DEFAULT_BODY_CLEARANCE_M)), 0.0),
		"legs": normalized_legs,
	}
