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
		"tier2_radius_m": 96.0,
		"tier3_radius_m": 30.0,
		"inspection_midfield_radius_m": 128.0,
		"inspection_tier2_radius_m": 128.0,
		"player_near_radius_m": 6.5,
		"player_personal_space_m": 3.25,
		"player_fast_speed_mps": 10.0,
		"violent_witness_core_radius_m": 120.0,
		"violent_witness_outer_response_ratio": 0.32,
		"gunshot_radius_m": 220.0,
		"projectile_reaction_radius_m": 4.5,
		"projectile_range_m": 36.0,
		"explosion_reaction_radius_m": 220.0,
		"casualty_witness_radius_m": 180.0,
		"explosion_witness_radius_m": 220.0,
		"vehicle_impact_hit_radius_m": 1.4,
		"vehicle_impact_front_reach_m": 4.6,
		"vehicle_impact_speed_threshold_mps": 6.0,
		"vehicle_impact_panic_radius_m": 10.0,
		"vehicle_impact_panic_response_ratio": 0.6,
		"vehicle_impact_launch_distance_min_m": 3.5,
		"vehicle_impact_launch_distance_max_m": 7.0,
		"vehicle_impact_launch_duration_sec": 0.42,
		"casualty_reaction_duration_sec": 2.8,
		"flee_duration_min_sec": 20.0,
		"flee_duration_max_sec": 35.0,
		"flee_scatter_angle_deg": 42.0,
		"page_cache_capacity": 160,
	}
