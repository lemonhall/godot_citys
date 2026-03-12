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
		"tier1_budget": 768,
		"tier2_budget": 96,
		"tier3_budget": 24,
		"nearfield_budget": 96,
		"tier2_radius_m": 110.0,
		"tier3_radius_m": 30.0,
		"player_near_radius_m": 6.5,
		"player_personal_space_m": 3.25,
		"player_fast_speed_mps": 10.0,
		"gunshot_radius_m": 24.0,
		"projectile_reaction_radius_m": 4.5,
		"projectile_range_m": 36.0,
		"explosion_reaction_radius_m": 18.0,
		"page_cache_capacity": 96,
	}
