extends RefCounted

const CityWorldOrientationScript := preload("res://city_game/world/navigation/CityWorldOrientation.gd")

const DEFAULT_SHELL_TYPE_ID := "m795_he"
const DEFAULT_GRAVITY_MPS2 := 9.81

var _world_orientation = CityWorldOrientationScript.new()

func get_shell_profile(shell_type_id: String = DEFAULT_SHELL_TYPE_ID) -> Dictionary:
	var resolved_shell_type_id := shell_type_id.strip_edges()
	if resolved_shell_type_id == "":
		resolved_shell_type_id = DEFAULT_SHELL_TYPE_ID
	match resolved_shell_type_id:
		"m795_he":
			return _build_m795_he_profile()
	return {}

func get_default_shell_type_id() -> String:
	return DEFAULT_SHELL_TYPE_ID

func build_firing_solution_from_angles(origin_world_position: Vector3, world_bearing_deg: float, pitch_deg: float, shell_type_id: String = DEFAULT_SHELL_TYPE_ID, extra: Dictionary = {}) -> Dictionary:
	var shell_profile := _resolve_shell_profile_from_sources(extra, shell_type_id)
	if shell_profile.is_empty():
		return {}
	var resolved_pitch_deg := clampf(pitch_deg, float(shell_profile.get("pitch_min_deg", 0.0)), float(shell_profile.get("pitch_max_deg", 71.0)))
	var resolved_world_bearing_deg := _world_orientation.normalize_bearing_deg(world_bearing_deg) if _world_orientation != null else world_bearing_deg
	var world_bearing_state := _world_orientation.build_compass_state_from_bearing_deg(resolved_world_bearing_deg, true) if _world_orientation != null else {}
	var firing_solution: Dictionary = extra.duplicate(true)
	firing_solution["origin_world_position"] = origin_world_position
	firing_solution["platform_world_position"] = extra.get("platform_world_position", origin_world_position)
	firing_solution["muzzle_direction_world"] = _build_world_direction_from_bearing_and_pitch(resolved_world_bearing_deg, resolved_pitch_deg)
	firing_solution["world_bearing_deg"] = resolved_world_bearing_deg
	firing_solution["world_bearing_text"] = str(world_bearing_state.get("bearing_text", "000°"))
	firing_solution["world_cardinal_text"] = str(world_bearing_state.get("cardinal_text", "N"))
	firing_solution["yaw_deg"] = float(extra.get("yaw_deg", resolved_world_bearing_deg))
	firing_solution["pitch_deg"] = resolved_pitch_deg
	firing_solution["pitch_min_deg"] = float(shell_profile.get("pitch_min_deg", 0.0))
	firing_solution["pitch_max_deg"] = float(shell_profile.get("pitch_max_deg", 71.0))
	firing_solution["shell_type_id"] = str(shell_profile.get("shell_type_id", shell_type_id))
	firing_solution["shell_profile"] = shell_profile.duplicate(true)
	firing_solution["reference_muzzle_velocity_mps"] = float(shell_profile.get("reference_muzzle_velocity_mps", 0.0))
	firing_solution["muzzle_velocity_mps"] = float(shell_profile.get("solver_muzzle_velocity_mps", 0.0))
	return firing_solution

func build_launch_velocity_world(firing_solution: Dictionary) -> Vector3:
	var direction := _resolve_launch_direction_world(firing_solution)
	if direction.length_squared() <= 0.000001:
		return Vector3.ZERO
	return direction * resolve_solver_muzzle_velocity_mps(firing_solution)

func resolve_solver_muzzle_velocity_mps(firing_solution: Dictionary) -> float:
	var shell_profile := _resolve_shell_profile_from_sources(firing_solution, str(firing_solution.get("shell_type_id", DEFAULT_SHELL_TYPE_ID)))
	if not shell_profile.is_empty() and shell_profile.has("solver_muzzle_velocity_mps"):
		return maxf(float(shell_profile.get("solver_muzzle_velocity_mps", 0.0)), 0.0)
	if firing_solution.has("solver_muzzle_velocity_mps"):
		return maxf(float(firing_solution.get("solver_muzzle_velocity_mps", 0.0)), 0.0)
	return maxf(float(firing_solution.get("muzzle_velocity_mps", 0.0)), 0.0)

func predict_impact_from_firing_solution(firing_solution: Dictionary, options: Dictionary = {}) -> Dictionary:
	if firing_solution.is_empty():
		return _build_invalid_prediction_result("missing_firing_solution")
	var shell_profile := _resolve_shell_profile_from_sources(firing_solution, str(firing_solution.get("shell_type_id", DEFAULT_SHELL_TYPE_ID)))
	if shell_profile.is_empty():
		return _build_invalid_prediction_result("missing_shell_profile")
	var origin_world_position := firing_solution.get("origin_world_position", Vector3.ZERO) as Vector3
	var launch_velocity_world := build_launch_velocity_world(firing_solution)
	if launch_velocity_world.length_squared() <= 0.000001:
		return _build_invalid_prediction_result("missing_launch_velocity")
	var gravity_mps2 := maxf(float(options.get("gravity_mps2", DEFAULT_GRAVITY_MPS2)), 0.0001)
	var impact_plane_y := float(options.get("impact_plane_y", origin_world_position.y))
	var flight_time_sec := _solve_plane_intersection_time_sec(origin_world_position.y, launch_velocity_world.y, impact_plane_y, gravity_mps2)
	if flight_time_sec <= 0.0:
		return _build_invalid_prediction_result("no_plane_intersection")
	var impact_world_position := origin_world_position + launch_velocity_world * flight_time_sec + Vector3.DOWN * 0.5 * gravity_mps2 * flight_time_sec * flight_time_sec
	var horizontal_distance_m := Vector2(impact_world_position.x - origin_world_position.x, impact_world_position.z - origin_world_position.z).length()
	var slant_distance_m := origin_world_position.distance_to(impact_world_position)
	var range_state := _resolve_range_state(horizontal_distance_m, shell_profile)
	return {
		"valid": range_state == "within_range",
		"reason": "",
		"shell_type_id": str(shell_profile.get("shell_type_id", DEFAULT_SHELL_TYPE_ID)),
		"shell_profile": shell_profile.duplicate(true),
		"impact_world_position": impact_world_position,
		"horizontal_distance_m": horizontal_distance_m,
		"slant_distance_m": slant_distance_m,
		"flight_time_sec": flight_time_sec,
		"launch_velocity_world": launch_velocity_world,
		"range_state": range_state,
	}

func solve_firing_solution_to_target(origin_world_position: Vector3, target_world_position: Vector3, options: Dictionary = {}) -> Dictionary:
	var shell_type_id := str(options.get("shell_type_id", DEFAULT_SHELL_TYPE_ID))
	var shell_profile := _resolve_shell_profile_from_sources(options, shell_type_id)
	if shell_profile.is_empty():
		return _build_unsolved_target_result("missing_shell_profile")
	var horizontal_vector := Vector3(
		target_world_position.x - origin_world_position.x,
		0.0,
		target_world_position.z - origin_world_position.z
	)
	var horizontal_distance_m := horizontal_vector.length()
	var range_state := _resolve_range_state(horizontal_distance_m, shell_profile)
	if range_state != "within_range":
		return _build_unsolved_target_result(range_state)
	if horizontal_distance_m <= 0.0001:
		return _build_unsolved_target_result("target_over_origin")
	var gravity_mps2 := maxf(float(options.get("gravity_mps2", DEFAULT_GRAVITY_MPS2)), 0.0001)
	var velocity_mps := maxf(float(shell_profile.get("solver_muzzle_velocity_mps", 0.0)), 0.0)
	if velocity_mps <= 0.0:
		return _build_unsolved_target_result("missing_solver_velocity")
	var vertical_delta_m := target_world_position.y - origin_world_position.y
	var speed_sq := velocity_mps * velocity_mps
	var discriminant := speed_sq * speed_sq - gravity_mps2 * (gravity_mps2 * horizontal_distance_m * horizontal_distance_m + 2.0 * vertical_delta_m * speed_sq)
	if discriminant < 0.0:
		return _build_unsolved_target_result("no_ballistic_solution")
	var sqrt_discriminant := sqrt(discriminant)
	var denominator := gravity_mps2 * horizontal_distance_m
	if absf(denominator) <= 0.000001:
		return _build_unsolved_target_result("target_over_origin")
	var low_pitch_deg := rad_to_deg(atan((speed_sq - sqrt_discriminant) / denominator))
	var high_pitch_deg := rad_to_deg(atan((speed_sq + sqrt_discriminant) / denominator))
	var low_valid := _is_pitch_inside_profile(low_pitch_deg, shell_profile)
	var high_valid := _is_pitch_inside_profile(high_pitch_deg, shell_profile)
	var prefer_high_arc := bool(options.get("prefer_high_arc", false))
	var resolved_pitch_deg := 0.0
	var arc_kind := ""
	if prefer_high_arc and high_valid:
		resolved_pitch_deg = high_pitch_deg
		arc_kind = "high"
	elif not prefer_high_arc and low_valid:
		resolved_pitch_deg = low_pitch_deg
		arc_kind = "low"
	elif high_valid:
		resolved_pitch_deg = high_pitch_deg
		arc_kind = "high"
	elif low_valid:
		resolved_pitch_deg = low_pitch_deg
		arc_kind = "low"
	else:
		return _build_unsolved_target_result("pitch_out_of_limits")
	var world_bearing_deg := _world_orientation.bearing_deg_from_world_vector(horizontal_vector) if _world_orientation != null else 0.0
	var firing_solution := build_firing_solution_from_angles(origin_world_position, world_bearing_deg, resolved_pitch_deg, shell_type_id, {
		"platform_world_position": options.get("platform_world_position", origin_world_position),
	})
	var predicted := predict_impact_from_firing_solution(firing_solution, {
		"impact_plane_y": target_world_position.y,
		"gravity_mps2": gravity_mps2,
	})
	return {
		"solved": true,
		"reason": "",
		"range_state": str(predicted.get("range_state", "within_range")),
		"world_bearing_deg": world_bearing_deg,
		"pitch_deg": resolved_pitch_deg,
		"arc_kind": arc_kind,
		"horizontal_distance_m": horizontal_distance_m,
		"flight_time_sec": float(predicted.get("flight_time_sec", 0.0)),
		"predicted_impact_world_position": predicted.get("impact_world_position", Vector3.ZERO),
		"firing_solution": firing_solution.duplicate(true),
		"shell_profile": shell_profile.duplicate(true),
	}

func step_point_mass(position_world: Vector3, velocity_world: Vector3, simulated_delta: float, gravity_mps2: float = DEFAULT_GRAVITY_MPS2) -> Dictionary:
	var next_velocity := velocity_world + Vector3.DOWN * maxf(gravity_mps2, 0.0) * simulated_delta
	var next_position := position_world + (velocity_world + next_velocity) * 0.5 * simulated_delta
	return {
		"next_position": next_position,
		"next_velocity": next_velocity,
	}

func _build_world_direction_from_bearing_and_pitch(world_bearing_deg: float, pitch_deg: float) -> Vector3:
	var heading_rad := _world_orientation.heading_rad_from_bearing_deg(world_bearing_deg) if _world_orientation != null else deg_to_rad(world_bearing_deg)
	var pitch_rad := deg_to_rad(pitch_deg)
	var horizontal_scale := cos(pitch_rad)
	return Vector3(
		sin(heading_rad) * horizontal_scale,
		sin(pitch_rad),
		-cos(heading_rad) * horizontal_scale
	).normalized()

func _resolve_launch_direction_world(firing_solution: Dictionary) -> Vector3:
	var direction := firing_solution.get("muzzle_direction_world", Vector3.ZERO) as Vector3
	if direction.length_squared() > 0.000001:
		return direction.normalized()
	return _build_world_direction_from_bearing_and_pitch(
		float(firing_solution.get("world_bearing_deg", 0.0)),
		float(firing_solution.get("pitch_deg", 0.0))
	)

func _resolve_shell_profile_from_sources(source: Dictionary, fallback_shell_type_id: String = DEFAULT_SHELL_TYPE_ID) -> Dictionary:
	if source.get("shell_profile", null) is Dictionary:
		var provided_profile := (source.get("shell_profile", {}) as Dictionary).duplicate(true)
		if not provided_profile.is_empty():
			return provided_profile
	return get_shell_profile(str(source.get("shell_type_id", fallback_shell_type_id)))

func _solve_plane_intersection_time_sec(origin_y: float, launch_velocity_y: float, plane_y: float, gravity_mps2: float) -> float:
	var a := 0.5 * gravity_mps2
	var b := -launch_velocity_y
	var c := plane_y - origin_y
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var sqrt_discriminant := sqrt(discriminant)
	var root_a := (-b - sqrt_discriminant) / (2.0 * a)
	var root_b := (-b + sqrt_discriminant) / (2.0 * a)
	var best_root := -1.0
	for root_variant in [root_a, root_b]:
		var root_value := float(root_variant)
		if root_value <= 0.0001:
			continue
		if root_value > best_root:
			best_root = root_value
	return best_root

func _resolve_range_state(horizontal_distance_m: float, shell_profile: Dictionary) -> String:
	var min_range_m := float(shell_profile.get("min_range_m", 0.0))
	var max_range_m := float(shell_profile.get("max_range_m", 0.0))
	if horizontal_distance_m < min_range_m:
		return "below_min_range"
	if horizontal_distance_m > max_range_m:
		return "above_max_range"
	return "within_range"

func _is_pitch_inside_profile(pitch_deg: float, shell_profile: Dictionary) -> bool:
	var pitch_min_deg := float(shell_profile.get("pitch_min_deg", 0.0))
	var pitch_max_deg := float(shell_profile.get("pitch_max_deg", 71.0))
	return pitch_deg >= pitch_min_deg - 0.0001 and pitch_deg <= pitch_max_deg + 0.0001

func _build_invalid_prediction_result(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"shell_type_id": "",
		"shell_profile": {},
		"impact_world_position": Vector3.ZERO,
		"horizontal_distance_m": 0.0,
		"slant_distance_m": 0.0,
		"flight_time_sec": 0.0,
		"launch_velocity_world": Vector3.ZERO,
		"range_state": reason,
	}

func _build_unsolved_target_result(reason: String) -> Dictionary:
	return {
		"solved": false,
		"reason": reason,
		"range_state": reason,
		"world_bearing_deg": 0.0,
		"pitch_deg": 0.0,
		"arc_kind": "",
		"horizontal_distance_m": 0.0,
		"flight_time_sec": 0.0,
		"predicted_impact_world_position": Vector3.ZERO,
		"firing_solution": {},
		"shell_profile": {},
	}

func _build_m795_he_profile() -> Dictionary:
	var max_range_m := 22500.0
	return {
		"shell_type_id": "m795_he",
		"display_name": "M795 HE",
		"min_range_m": 1500.0,
		"max_range_m": max_range_m,
		"reference_muzzle_velocity_mps": 827.0,
		"solver_muzzle_velocity_mps": sqrt(max_range_m * DEFAULT_GRAVITY_MPS2),
		"pitch_min_deg": 0.0,
		"pitch_max_deg": 71.0,
	}
