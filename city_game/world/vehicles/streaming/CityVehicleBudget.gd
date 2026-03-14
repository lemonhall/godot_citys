extends RefCounted

const PRESET_LITE := "lite"

var _contract := {}

func _init() -> void:
	setup()

func setup(_config = null, preset: String = PRESET_LITE) -> void:
	_contract = _build_contract(preset)

func get_contract() -> Dictionary:
	return _contract.duplicate(true)

func _build_contract(preset: String) -> Dictionary:
	var resolved_preset := PRESET_LITE if preset != PRESET_LITE else preset
	return {
		"preset": resolved_preset,
		"tier1_budget": 4,
		"tier2_budget": 2,
		"tier3_budget": 1,
		"nearfield_budget": 3,
		"tier2_radius_m": 240.0,
		"tier3_radius_m": 72.0,
		"page_cache_capacity": 160,
	}
